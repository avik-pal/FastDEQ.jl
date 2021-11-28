struct MultiScaleSkipDeepEquilibriumNetwork{
    M3<:Union{Nothing,Parallel},
    N,
    M1<:Parallel,
    M2<:MultiParallelNet,
    RE1,
    RE2,
    RE3,
    P,
    A,
    K,
    S,
} <: AbstractDeepEquilibriumNetwork
    main_layers::M1
    mapping_layers::M2
    shortcut_layers::M3
    main_layers_re::RE1
    mapping_layers_re::RE2
    shortcut_layers_re::RE3
    p::P
    ordered_split_idxs::NTuple{N,Int}
    args::A
    kwargs::K
    sensealg::S
    stats::DEQTrainingStats
end

Flux.@functor MultiScaleSkipDeepEquilibriumNetwork (p,)

function MultiScaleSkipDeepEquilibriumNetwork(
    main_layers::Tuple,
    mapping_layers::Matrix,
    shortcut_layers::Tuple,
    solver;
    p = nothing,
    sensealg = get_default_ssadjoint(0.1f0, 0.1f0, 10),
    kwargs...,
)
    @assert size(mapping_layers, 1) ==
            size(mapping_layers, 2) ==
            length(main_layers) ==
            length(shortcut_layers)

    main_layers = Parallel(flatten_merge, main_layers...)
    mapping_layers = MultiParallelNet(
        Parallel.(+, map(x -> tuple(x...), eachcol(mapping_layers)))...,
    )
    shortcut_layers = Parallel(flatten_merge, shortcut_layers...)

    p_main_layers, re_main_layers = Flux.destructure(main_layers)
    p_mapping_layers, re_mapping_layers = Flux.destructure(mapping_layers)
    p_shortcut_layers, re_shortcut_layers = Flux.destructure(shortcut_layers)

    ordered_split_idxs = tuple(
        cumsum([
            0,
            length(p_main_layers),
            length(p_mapping_layers),
            length(p_shortcut_layers),
        ])...,
    )

    p =
        p === nothing ?
        vcat(p_main_layers, p_mapping_layers, p_shortcut_layers) : p

    return MultiScaleSkipDeepEquilibriumNetwork(
        main_layers,
        mapping_layers,
        shortcut_layers,
        re_main_layers,
        re_mapping_layers,
        re_shortcut_layers,
        p,
        ordered_split_idxs,
        (solver,),
        kwargs,
        sensealg,
        DEQTrainingStats(0),
    )
end

function MultiScaleSkipDeepEquilibriumNetwork(
    main_layers::Tuple,
    mapping_layers::Matrix,
    solver;
    p = nothing,
    sensealg = get_default_ssadjoint(0.1f0, 0.1f0, 10),
    kwargs...,
)
    @assert size(mapping_layers, 1) ==
            size(mapping_layers, 2) ==
            length(main_layers)

    main_layers = Parallel(flatten_merge, main_layers...)
    mapping_layers = MultiParallelNet(
        Parallel.(+, map(x -> tuple(x...), eachcol(mapping_layers)))...,
    )

    p_main_layers, re_main_layers = Flux.destructure(main_layers)
    p_mapping_layers, re_mapping_layers = Flux.destructure(mapping_layers)

    ordered_split_idxs = tuple(
        cumsum([
            0,
            length(p_main_layers),
            length(p_mapping_layers),
        ])...,
    )

    p =
        p === nothing ?
        vcat(p_main_layers, p_mapping_layers) : p

    return MultiScaleSkipDeepEquilibriumNetwork(
        main_layers,
        mapping_layers,
        nothing,
        re_main_layers,
        re_mapping_layers,
        nothing,
        p,
        ordered_split_idxs,
        (solver,),
        kwargs,
        sensealg,
        DEQTrainingStats(0),
    )
end

function Flux.gpu(deq::MultiScaleSkipDeepEquilibriumNetwork)
    return MultiScaleSkipDeepEquilibriumNetwork(
        deq.main_layers |> gpu,
        deq.mapping_layers |> gpu,
        deq.shortcut_layers |> gpu,
        deq.main_layers_re,
        deq.mapping_layers_re,
        deq.shortcut_layers_re,
        deq.p |> gpu,
        deq.ordered_split_idxs,
        deq.args,
        deq.kwargs,
        deq.sensealg,
        deq.stats,
    )
end

function Flux.cpu(deq::MultiScaleSkipDeepEquilibriumNetwork)
    return MultiScaleSkipDeepEquilibriumNetwork(
        deq.main_layers |> cpu,
        deq.mapping_layers |> cpu,
        deq.shortcut_layers |> cpu,
        deq.main_layers_re,
        deq.mapping_layers_re,
        deq.shortcut_layers_re,
        deq.p |> cpu,
        deq.ordered_split_idxs,
        deq.args,
        deq.kwargs,
        deq.sensealg,
        deq.stats,
    )
end

function (mdeq::MultiScaleSkipDeepEquilibriumNetwork)(
    x::AbstractArray{T},
    p = mdeq.p,
) where {T}
    p1, p2, p3 = split_array_by_indices(p, mdeq.ordered_split_idxs)
    initial_conditions = mdeq.shortcut_layers_re(p3)(x)
    u_sizes = size.(initial_conditions)
    u_split_idxs =
        vcat(0, cumsum(length.(initial_conditions) .÷ size(x, ndims(x)))...)
    u0 = vcat(Flux.flatten.(initial_conditions)...)

    N = length(u_sizes)

    function dudt_(u, _p)
        mdeq.stats.nfe += 1

        uₛ = split_array_by_indices(u, u_split_idxs)
        p1, p2, p3 = split_array_by_indices(_p, mdeq.ordered_split_idxs)

        u_reshaped = ntuple(i -> reshape(uₛ[i], u_sizes[i]), N)

        main_layers_output =
            mdeq.main_layers_re(p1)((u_reshaped[1], x), u_reshaped[2:end]...)

        return vcat(
            Flux.flatten.(mdeq.mapping_layers_re(p2)(main_layers_output))...,
        )
    end

    dudt(u, _p, t) = dudt_(u, _p) .- u

    ssprob = SteadyStateProblem(dudt, u0, p)
    sol =
        solve(
            ssprob,
            mdeq.args...;
            u0 = u0,
            sensealg = mdeq.sensealg,
            mdeq.kwargs...,
        ).u
    res = map(
        xs -> reshape(xs[1], xs[2]),
        zip(split_array_by_indices(dudt_(sol, p), u_split_idxs), u_sizes),
    )

    return res, initial_conditions
end

function (mdeq::MultiScaleSkipDeepEquilibriumNetwork{Nothing})(
    x::AbstractArray{T},
    p = mdeq.p,
) where {T}
    p1, p2 = split_array_by_indices(p, mdeq.ordered_split_idxs)

    _initial_conditions = Zygote.@ignore map(
        l -> l(x),
        map(l -> l.layers[1], mdeq.mapping_layers.layers)
    )
    _initial_conditions = mdeq.mapping_layers_re(p2)(
        (x, zero.(_initial_conditions[2:end])...)
    )
    initial_conditions = mdeq.main_layers_re(p1)(
        (zero(_initial_conditions[1]), _initial_conditions[1]),
        _initial_conditions[2:end]...
    )
    u_sizes = size.(initial_conditions)
    u_split_idxs =
        vcat(0, cumsum(length.(initial_conditions) .÷ size(x, ndims(x)))...)
    u0 = vcat(Flux.flatten.(initial_conditions)...)

    N = length(u_sizes)

    function dudt_(u, _p)
        mdeq.stats.nfe += 1

        uₛ = split_array_by_indices(u, u_split_idxs)
        p1, p2 = split_array_by_indices(_p, mdeq.ordered_split_idxs)

        u_reshaped = ntuple(i -> reshape(uₛ[i], u_sizes[i]), N)

        main_layers_output =
            mdeq.main_layers_re(p1)((u_reshaped[1], x), u_reshaped[2:end]...)

        return vcat(
            Flux.flatten.(mdeq.mapping_layers_re(p2)(main_layers_output))...,
        )
    end

    dudt(u, _p, t) = dudt_(u, _p) .- u

    ssprob = SteadyStateProblem(dudt, u0, p)
    sol =
        solve(
            ssprob,
            mdeq.args...;
            u0 = u0,
            sensealg = mdeq.sensealg,
            mdeq.kwargs...,
        ).u
    res = map(
        xs -> reshape(xs[1], xs[2]),
        zip(split_array_by_indices(dudt_(sol, p), u_split_idxs), u_sizes),
    )

    return res, initial_conditions
end
