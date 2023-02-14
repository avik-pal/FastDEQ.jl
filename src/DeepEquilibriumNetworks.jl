module DeepEquilibriumNetworks

using LinearAlgebra, OrdinaryDiffEq, SciMLBase, SciMLOperators, SteadyStateDiffEq
using SteadyStateDiffEq: SteadyStateDiffEqAlgorithm

const DEQs = DeepEquilibriumNetworks

include("solvers/solvers.jl")
include("solvers/discrete/broyden.jl")
include("solvers/discrete/limited_memory_broyden.jl")
include("solvers/termination.jl")

include("solve.jl")
include("utils.jl")

include("layers/core.jl")
include("layers/jacobian_stabilization.jl")
include("layers/deq.jl")
include("layers/mdeq.jl")
include("layers/neuralode.jl")

include("adjoint.jl")

# Useful Shorthand
export DEQs

# DEQ Solvers
export ContinuousDEQSolver, DiscreteDEQSolver, BroydenSolver, LimitedMemoryBroydenSolver

# Utils
export DeepEquilibriumAdjoint, DeepEquilibriumSolution, estimate_jacobian_trace

# Networks
export DeepEquilibriumNetwork, SkipDeepEquilibriumNetwork
export MultiScaleDeepEquilibriumNetwork, MultiScaleSkipDeepEquilibriumNetwork

end
