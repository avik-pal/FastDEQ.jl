# Building Blocks
## Helpful Functional Wrappers
function conv1x1(mapping, activation=identity; stride::Int=1, bias=false, kwargs...)
    return Conv(
        (1, 1), mapping, activation; stride=stride, pad=0, bias=bias, init_weight=NormalInitializer(), kwargs...
    )
end

function conv3x3(mapping, activation=identity; stride::Int=1, bias=false, kwargs...)
    return Conv(
        (3, 3), mapping, activation; stride=stride, pad=1, bias=bias, init_weight=NormalInitializer(), kwargs...
    )
end

function conv5x5(mapping, activation=identity; stride::Int=1, bias=false, kwargs...)
    return Conv(
        (5, 5), mapping, activation; stride=stride, pad=2, bias=bias, init_weight=NormalInitializer(), kwargs...
    )
end

addrelu(x, y) = @. relu(x + y)

reassociate(x::NTuple{2,<:AbstractArray}, y) = (x[1], (x[2], y))

addtuple(y) = y[1] .+ y[2]

## Downsample Module
function downsample_module(mapping, level_diff, activation; group_count=8)
    in_channels, out_channels = mapping

    function intermediate_mapping(i)
        if in_channels * (2^level_diff) == out_channels
            return (in_channels * (2^(i - 1))) => (in_channels * (2^i))
        else
            return i == level_diff ? in_channels => out_channels : in_channels => in_channels
        end
    end

    layers = Lux.AbstractExplicitLayer[]
    for i in 1:level_diff
        inchs, outchs = intermediate_mapping(i)
        push!(layers, conv3x3(inchs => outchs; stride=2))
        # push!(layers, GroupNorm(outchs, group_count, activation; affine=true, track_stats=false))
        push!(layers, BatchNorm(outchs, activation; affine=true, track_stats=false))
    end
    return Chain(layers...)
end

## Upsample Module
function upsample_module(mapping, level_diff, activation; upsample_mode::Symbol=:nearest, group_count=8)
    in_channels, out_channels = mapping

    function intermediate_mapping(i)
        if out_channels * (2^level_diff) == in_channels
            (in_channels ÷ (2^(i - 1))) => (in_channels ÷ (2^i))
        else
            i == level_diff ? in_channels => out_channels : in_channels => in_channels
        end
    end

    layers = Lux.AbstractExplicitLayer[]
    for i in 1:level_diff
        inchs, outchs = intermediate_mapping(i)
        push!(layers, conv1x1(inchs => outchs))
        # push!(layers, GroupNorm(outchs, group_count, activation; affine=true, track_stats=false))
        push!(layers, BatchNorm(outchs, activation; affine=true, track_stats=false))
        push!(layers, Upsample(upsample_mode; scale=2))
    end
    return Chain(layers...)
end

## Residual Block
struct ResidualBlock{C1,C2,Dr,Do,N1,N2,N3} <:
       Lux.AbstractExplicitContainerLayer{(:conv1, :conv2, :dropout, :downsample, :norm1, :norm2, :norm3)}
    conv1::C1
    conv2::C2
    dropout::Dr
    downsample::Do
    norm1::N1
    norm2::N2
    norm3::N3
end

function ResidualBlock(
    mapping;
    deq_expand::Int=5,
    num_gn_groups::Int=4,
    downsample=NoOpLayer(),
    n_big_kernels::Int=0,
    dropout_rate::Real=0.0f0,
    gn_affine::Bool=true,
    weight_norm::Bool=true,
    gn_track_stats::Bool=false,
)
    inplanes, outplanes = mapping
    inner_planes = outplanes * deq_expand
    conv1 = (n_big_kernels >= 1 ? conv5x5 : conv3x3)(inplanes => inner_planes; bias=false)
    conv2 = (n_big_kernels >= 2 ? conv5x5 : conv3x3)(inner_planes => outplanes; bias=false)

    conv1, conv2 = if weight_norm
        WeightNorm(conv1, (:weight,), (4,)), WeightNorm(conv2, (:weight,), (4,))
    else
        conv1, conv2
    end

    # norm1 = GroupNorm(inner_planes, num_gn_groups, relu; affine=gn_affine, track_stats=gn_track_stats)
    # norm2 = GroupNorm(outplanes, num_gn_groups; affine=gn_affine, track_stats=gn_track_stats)
    # norm3 = GroupNorm(outplanes, num_gn_groups; affine=gn_affine, track_stats=gn_track_stats)
    norm1 = BatchNorm(inner_planes, relu; affine=gn_affine, track_stats=gn_track_stats)
    norm2 = BatchNorm(outplanes; affine=gn_affine, track_stats=gn_track_stats)
    norm3 = BatchNorm(outplanes; affine=gn_affine, track_stats=gn_track_stats)

    dropout = VariationalHiddenDropout(dropout_rate)

    return ResidualBlock(conv1, conv2, dropout, downsample, norm1, norm2, norm3)
end

function (rb::ResidualBlock)((x, y)::NTuple{2,<:AbstractArray}, ps, st)
    x, st_conv1 = rb.conv1(x, ps.conv1, st.conv1)
    x, st_norm1 = rb.norm1(x, ps.norm1, st.norm1)
    x, st_conv2 = rb.conv2(x, ps.conv2, st.conv2)

    x_do, st_downsample = rb.downsample(x, ps.downsample, st.downsample)
    x_dr, st_dropout = rb.dropout(x, ps.dropout, st.dropout)

    y_ = x_dr .+ y
    y_, st_norm2 = rb.norm2(y_, ps.norm2, st.norm2)

    y__ = relu.(y_ .+ x_do)
    y__, st_norm3 = rb.norm3(y__, ps.norm3, st.norm3)

    return (
        y__,
        (
            conv1=st_conv1,
            conv2=st_conv2,
            dropout=st_dropout,
            downsample=st_downsample,
            norm1=st_norm1,
            norm2=st_norm2,
            norm3=st_norm3,
        ),
    )
end

function (rb::ResidualBlock)(x::AbstractArray, ps, st)
    x, st_conv1 = rb.conv1(x, ps.conv1, st.conv1)
    x, st_norm1 = rb.norm1(x, ps.norm1, st.norm1)
    x, st_conv2 = rb.conv2(x, ps.conv2, st.conv2)

    x_do, st_downsample = rb.downsample(x, ps.downsample, st.downsample)
    
    x_dr, st_dropout = rb.dropout(x, ps.dropout, st.dropout)
    x_dr, st_norm2 = rb.norm2(x_dr, ps.norm2, st.norm2)

    y__ = relu.(x_dr .+ x_do)
    y__, st_norm3 = rb.norm3(y__, ps.norm3, st.norm3)

    return (
        y__,
        (
            conv1=st_conv1,
            conv2=st_conv2,
            dropout=st_dropout,
            downsample=st_downsample,
            norm1=st_norm1,
            norm2=st_norm2,
            norm3=st_norm3,
        ),
    )
end

# Bottleneck Block
struct BottleneckBlock{R,C,M} <: Lux.AbstractExplicitContainerLayer{(:rescale, :conv, :mapping)}
    rescale::R
    conv::C
    mapping::M
end

function BottleneckBlock(mapping::Pair, expansion::Int=4; bn_track_stats::Bool=true, bn_affine::Bool=true)
    rescale = if first(mapping) != last(mapping) * expansion
        Chain(
            conv1x1(first(mapping) => last(mapping) * expansion),
            BatchNorm(last(mapping) * expansion; track_stats=bn_track_stats, affine=bn_affine),
        )
    else
        NoOpLayer()
    end

    return BottleneckBlock(
        rescale,
        conv1x1(mapping),
        Chain(
            BatchNorm(last(mapping), relu; affine=bn_affine, track_stats=bn_track_stats),
            conv3x3(last(mapping) => last(mapping)),
            BatchNorm(last(mapping), relu; track_stats=bn_track_stats, affine=bn_affine),
            conv1x1(last(mapping) => last(mapping) * expansion),
            BatchNorm(last(mapping) * expansion; track_stats=bn_track_stats, affine=bn_affine)
        )
    )
end

function (bn::BottleneckBlock)((x, y)::NTuple{2,<:AbstractArray}, ps, st)
    x_r, st_rescale = bn.rescale(x, ps.rescale, st.rescale)
    x_m, st_conv1 = bn.conv(x_r, ps.conv, st.conv)

    x_m = y .+ x_m
    x_m, st_mapping = bn.mapping(x_m, ps.mapping, st.mapping)

    return (
        relu.(x_m .+ x_r),
        (
            rescale=st_rescale,
            conv=st_conv1,
            mapping=st_mapping,
        )
    )
end

function (bn::BottleneckBlock)(x::AbstractArray, ps, st)
    x_r, st_rescale = bn.rescale(x, ps.rescale, st.rescale)
    x_m, st_conv1 = bn.conv(x_r, ps.conv, st.conv)
    x_m, st_mapping = bn.mapping(x_m, ps.mapping, st.mapping)

    return (
        relu.(x_m .+ x_r),
        (
            rescale=st_rescale,
            conv=st_conv1,
            mapping=st_mapping,
        )
    )
end

# Dataset Specific Models
function get_model(
    config::NamedTuple;
    device=gpu,
    warmup::Bool=true,  # Helps reduce Zygote compile times
    loss_function=nothing,
)
    @assert !warmup || loss_function !== nothing

    init_channel_size = config.num_channels[1]

    downsample_layers = [
        conv3x3(3 => init_channel_size; stride=config.downsample_times >= 1 ? 2 : 1),
        BatchNorm(init_channel_size, relu; affine=true, track_stats=true),
        conv3x3(init_channel_size => init_channel_size; stride=config.downsample_times >= 2 ? 2 : 1),
        BatchNorm(init_channel_size, relu; affine=true, track_stats=true),
    ]
    for _ in 3:(config.downsample_times)
        append!(
            downsample_layers,
            [
                conv3x3(init_channel_size => init_channel_size; stride=2),
                BatchNorm(init_channel_size, relu; affine=true, track_stats=true),
            ],
        )
    end
    downsample = Chain(downsample_layers...)

    stage0 = if config.downsample_times == 0 && config.num_branches <= 2
        NoOpLayer()
    else
        Chain(
            conv1x1(init_channel_size => init_channel_size; bias=false),
            BatchNorm(init_channel_size, relu; affine=true, track_stats=true),
        )
    end

    initial_layers = Chain(downsample, stage0)

    main_layers = Tuple(
        ResidualBlock(
            config.num_channels[i] => config.num_channels[i];
            deq_expand=config.expansion_factor,
            dropout_rate=config.dropout_rate,
            num_gn_groups=config.group_count,
            n_big_kernels=config.big_kernels[i],
        ) for i in 1:(config.num_branches)
    )

    mapping_layers = Matrix{Lux.AbstractExplicitLayer}(undef, config.num_branches, config.num_branches)
    for i in 1:(config.num_branches)
        for j in 1:(config.num_branches)
            if i == j
                mapping_layers[i, j] = NoOpLayer()
            elseif i < j
                mapping_layers[i, j] = downsample_module(
                    config.num_channels[i] => config.num_channels[j], j - i, relu; group_count=config.group_count
                )
            else
                mapping_layers[i, j] = upsample_module(
                    config.num_channels[i] => config.num_channels[j],
                    i - j,
                    relu;
                    group_count=config.group_count,
                    upsample_mode=:nearest,
                )
            end
        end
    end

    post_fuse_layers = Tuple(
        Chain(
            ActivationFunction(relu),
            conv1x1(config.num_channels[i] => config.num_channels[i]),
            # GroupNorm(config.num_channels[i], config.group_count ÷ 2; affine=false, track_stats=false),
            BatchNorm(config.num_channels[i]; affine=false, track_stats=false),
        ) for i in 1:(config.num_branches)
    )

    increment_modules = Parallel(
        nothing,
        [BottleneckBlock(config.num_channels[i] => config.head_channels[i]) for i in 1:(config.num_branches)]...,
    )

    downsample_modules = PairwiseFusion(
        config.fuse_method == :sum ? (+) : error("Only `fuse_method` = `:sum` is supported"),
        [
            Chain(
                conv3x3(config.head_channels[i] * 4 => config.head_channels[i + 1] * 4; stride=2, bias=true),
                BatchNorm(config.head_channels[i + 1] * 4, relu; track_stats=true, affine=true),
            ) for i in 1:(config.num_branches - 1)
        ]...,
    )

    final_layers = Chain(
        increment_modules,
        downsample_modules,
        conv1x1(config.head_channels[config.num_branches] * 4 => config.final_channelsize; bias=true),
        BatchNorm(config.final_channelsize, relu; track_stats=true, affine=true),
        GlobalMeanPool(),
        FlattenLayer(),
        Dense(config.final_channelsize, config.num_classes),
    )

    solver = if config.continuous
        ContinuousDEQSolver(
            config.ode_solver;
            mode=config.stop_mode,
            abstol=config.abstol,
            reltol=config.reltol,
            abstol_termination=config.abstol,
            reltol_termination=config.reltol,
        )
    else
        DiscreteDEQSolver(
            LimitedMemoryBroydenSolver();
            mode=config.stop_mode,
            abstol_termination=config.abstol,
            reltol_termination=config.reltol,
        )
    end

    sensealg = DeepEquilibriumAdjoint(
        config.abstol, config.reltol, config.bwd_maxiters; mode=config.jfb ? :jfb : :vanilla
    )

    deq = if config.model_type ∈ (:SKIP, :SKIPV2)
        shortcut = if config.model_type == :SKIP
            slayers = Lux.AbstractExplicitLayer[ResidualBlock(
                config.num_channels[1] => config.num_channels[1]; weight_norm=true
            )]
            for i in 1:(config.num_branches - 1)
                push!(
                    slayers,
                    downsample_module(
                        config.num_channels[1] => config.num_channels[i + 1],
                        i,
                        relu;
                        group_count=config.group_count,
                    ),
                )
            end
            tuple(slayers...)
        else
            nothing
        end
        MultiScaleSkipDeepEquilibriumNetwork(
            main_layers,
            mapping_layers,
            post_fuse_layers,
            shortcut,
            solver,
            compute_feature_scales(config);
            maxiters=config.fwd_maxiters,
            sensealg=sensealg,
            verbose=false,
        )
    elseif config.model_type == :VANILLA
        MultiScaleDeepEquilibriumNetwork(
            main_layers,
            mapping_layers,
            post_fuse_layers,
            solver,
            compute_feature_scales(config);
            maxiters=config.fwd_maxiters,
            sensealg=sensealg,
            verbose=false,
        )
    else
        throw(ArgumentError("`model_type` must be one of `[:SKIP, :SKIPV2, :VANILLA]`"))
    end

    model = DEQChain(initial_layers, deq, final_layers)
    rng = Random.default_rng()
    Random.seed!(rng, config.seed)
    ps, st = device.(Lux.setup(rng, model))

    ps, st = if is_distributed()
        ps_ = FluxMPI.synchronize!(ps; root_rank=0)
        should_log() && println("$(now()) ===> synchronized model parameters across all processes")
        st_ = FluxMPI.synchronize!(st; root_rank=0)
        should_log() && println("$(now()) ===> synchronized model state across all processes")
        ps_, st_
    else
        ps, st
    end

    if warmup
        should_log() && println("$(now()) ==> starting model warmup")
        x__ = device(randn(Float32, config.image_size..., 3, 2))
        y__ = device(Float32.(onehotbatch([1, 2], 0:(config.num_classes - 1))))
        model(x__, ps, st)
        should_log() && println("$(now()) ==> forward pass warmup completed")

        st_ = Lux.update_state(st, :fixed_depth, Val(2))
        model(x__, ps, st_)
        should_log() && println("$(now()) ==> forward pass (pretraining) warmup completed")

        (l, _, _), back = pullback(p -> loss_function(x__, y__, model, p, st), ps)
        back((one(l), nothing, nothing))
        should_log() && println("$(now()) ==> backward pass warmup completed")

        (l, _, _), back = pullback(p -> loss_function(x__, y__, model, p, st_), ps)
        back((one(l), nothing, nothing))
        should_log() && println("$(now()) ==> backward pass (pretraining) warmup completed")

        invoke_gc()
    end

    return model, ps, st
end

# Optimisers
function construct_optimiser(config::NamedTuple)
    opt = if config.optimiser == :ADAM
        Optimisers.ADAM(config.eta)
    elseif config.optimiser == :SGD
        if config.nesterov
            Optimisers.Nesterov(config.eta, config.momentum)
        else
            if iszero(config.momentum)
                Optimisers.Descent(config.eta)
            else
                Optimisers.Momentum(config.eta, config.momentum)
            end
        end
    else
        throw(ArgumentError("`config.optimiser` must be either `:ADAM` or `:SGD`"))
    end
    if hasproperty(config, :weight_decay) && !iszero(config.weight_decay)
        opt = Optimisers.OptimiserChain(opt, Optimisers.WeightDecay(config.weight_decay))
    end

    sched = if config.lr_scheduler == :COSINE
        ParameterSchedulers.Stateful(ParameterSchedulers.Cos(config.eta, 1.0f-6, config.nepochs))
    elseif config.lr_scheduler == :CONSTANT
        ParameterSchedulers.Stateful(ParameterSchedulers.Constant(config.eta))
    else
        throw(ArgumentError("`config.lr_scheduler` must be either `:COSINE` or `:CONSTANT`"))
    end

    return opt, sched
end
