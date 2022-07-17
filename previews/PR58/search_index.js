var documenterSearchIndex = {"docs":
[{"location":"references/#References","page":"References","title":"References","text":"","category":"section"},{"location":"references/","page":"References","title":"References","text":"","category":"page"},{"location":"manual/deqs/#Deep-Equilibrium-Models","page":"DEQ Layers","title":"Deep Equilibrium Models","text":"","category":"section"},{"location":"manual/deqs/#Standard-Models","page":"DEQ Layers","title":"Standard Models","text":"","category":"section"},{"location":"manual/deqs/","page":"DEQ Layers","title":"DEQ Layers","text":"DeepEquilibriumNetwork\nSkipDeepEquilibriumNetwork","category":"page"},{"location":"manual/deqs/#DeepEquilibriumNetworks.DeepEquilibriumNetwork","page":"DEQ Layers","title":"DeepEquilibriumNetworks.DeepEquilibriumNetwork","text":"DeepEquilibriumNetwork(model, solver; jacobian_regularization::Bool=false,\n                       sensealg=DeepEquilibriumAdjoint(0.1f0, 0.1f0, 10), kwargs...)\n\nDeep Equilibrium Network as proposed in Shaojie Bai, J. Zico Kolter, Vladlen Koltun (2019).\n\nArguments\n\nmodel:Lux Neural Network.\nsolver: Solver for the optimization problem (See: ContinuousDEQSolver & DiscreteDEQSolver).\njacobian_regularization: If true, Jacobian Loss is computed and stored in the DeepEquilibriumSolution.\nsensealg: See DeepEquilibriumAdjoint.\nkwargs: Additional Parameters that are directly passed to SciMLBase.solve.\n\nExample\n\nimport DeepEquilibriumNetworks as DEQs\nimport Lux\nimport Random\nimport OrdinaryDiffEq\n\nmodel = DEQs.DeepEquilibriumNetwork(Lux.Parallel(+, Lux.Dense(2, 2; bias=false),\n                                                 Lux.Dense(2, 2; bias=false)),\n                                    DEQs.ContinuousDEQSolver(OrdinaryDiffEq.VCABM3();\n                                                             abstol=0.01f0, reltol=0.01f0))\n\nrng = Random.default_rng()\nps, st = Lux.setup(rng, model)\n\nmodel(rand(rng, Float32, 2, 1), ps, st)\n\nSee also: SkipDeepEquilibriumNetwork, MultiScaleDeepEquilibriumNetwork, MultiScaleSkipDeepEquilibriumNetwork.\n\n\n\n\n\n","category":"type"},{"location":"manual/deqs/#DeepEquilibriumNetworks.SkipDeepEquilibriumNetwork","page":"DEQ Layers","title":"DeepEquilibriumNetworks.SkipDeepEquilibriumNetwork","text":"SkipDeepEquilibriumNetwork(model, shortcut, solver; jacobian_regularization::Bool=false,\n                           sensealg=DeepEquilibriumAdjoint(0.1f0, 0.1f0, 10), kwargs...)\n\nSkip Deep Equilibrium Network as proposed in Avik Pal, Alan Edelman, Christopher Rackauckas (2022)\n\nArguments\n\nmodel: Neural Network.\nshortcut: Shortcut for the network (pass nothing for SkipDEQV2).\nsolver: Solver for the optimization problem (See: ContinuousDEQSolver & DiscreteDEQSolver).\njacobian_regularization: If true, Jacobian Loss is computed and stored in the DeepEquilibriumSolution.\nsensealg: See DeepEquilibriumAdjoint.\nkwargs: Additional Parameters that are directly passed to SciMLBase.solve.\n\nExample\n\nimport DeepEquilibriumNetworks as DEQs\nimport Lux\nimport Random\nimport OrdinaryDiffEq\n\n## SkipDEQ\nmodel = DEQs.SkipDeepEquilibriumNetwork(Lux.Parallel(+, Lux.Dense(2, 2; bias=false),\n                                                     Lux.Dense(2, 2; bias=false)),\n                                        Lux.Dense(2, 2),\n                                        DEQs.ContinuousDEQSolver(OrdinaryDiffEq.VCABM3();\n                                                                 abstol=0.01f0,\n                                                                 reltol=0.01f0))\n\nrng = Random.default_rng()\nps, st = Lux.setup(rng, model)\n\nmodel(rand(rng, Float32, 2, 1), ps, st)\n\n## SkipDEQV2\nmodel = DEQs.SkipDeepEquilibriumNetwork(Lux.Parallel(+, Lux.Dense(2, 2; bias=false),\n                                                     Lux.Dense(2, 2; bias=false)), nothing,\n                                        DEQs.ContinuousDEQSolver(OrdinaryDiffEq.VCABM3();\n                                                                 abstol=0.01f0,\n                                                                 reltol=0.01f0))\n\nrng = Random.default_rng()\nps, st = Lux.setup(rng, model)\n\nmodel(rand(rng, Float32, 2, 1), ps, st)\n\nSee also: DeepEquilibriumNetwork, MultiScaleDeepEquilibriumNetwork, MultiScaleSkipDeepEquilibriumNetwork\n\n\n\n\n\n","category":"type"},{"location":"manual/deqs/#MultiScale-Models","page":"DEQ Layers","title":"MultiScale Models","text":"","category":"section"},{"location":"manual/deqs/","page":"DEQ Layers","title":"DEQ Layers","text":"MultiScaleDeepEquilibriumNetwork\nMultiScaleSkipDeepEquilibriumNetwork","category":"page"},{"location":"manual/misc/#Miscellaneous","page":"Miscellaneous","title":"Miscellaneous","text":"","category":"section"},{"location":"manual/misc/","page":"Miscellaneous","title":"Miscellaneous","text":"DeepEquilibriumAdjoint\nDeepEquilibriumSolution\nNormalInitializer","category":"page"},{"location":"manual/misc/#DeepEquilibriumNetworks.DeepEquilibriumAdjoint","page":"Miscellaneous","title":"DeepEquilibriumNetworks.DeepEquilibriumAdjoint","text":"DeepEquilibriumAdjoint(reltol, abstol, maxiters; autojacvec=ZygoteVJP(),\n                       linsolve=KrylovJL_GMRES(; rtol=reltol, atol=abstol,\n                                               itmax=maxiters),\n                       mode=:vanilla)\n\nCreates DeepEquilibriumAdjoint (Steven G Johnson (2006)) with sensible defaults.\n\nArguments\n\nreltol: Relative tolerance.\nabstol: Absolute tolerance.\nmaxiters: Maximum number of iterations.\nautojacvec: Which backend to use for VJP.\nlinsolve: Linear Solver from LinearSolve.jl.\nmode: Adjoint mode. Currently only :vanilla & :jfb are supported.\n\n\n\n\n\n","category":"type"},{"location":"manual/misc/#DeepEquilibriumNetworks.DeepEquilibriumSolution","page":"Miscellaneous","title":"DeepEquilibriumNetworks.DeepEquilibriumSolution","text":"DeepEquilibriumSolution(z_star, u₀, residual, jacobian_loss, nfe)\n\nStores the solution of a DeepEquilibriumNetwork and its variants.\n\nFields\n\nz_star: Steady-State or the value reached due to maxiters\nu0: Initial Condition\nresidual: Difference of the z^* and f(z^* x)\njacobian_loss: Jacobian Stabilization Loss (see individual networks to see how it can be computed).\nnfe: Number of Function Evaluations\n\nAccessors\n\nWe recommend not accessing the fields directly, rather use the functions equilibrium_solution, initial_condition, residual, jacobian_loss and number_of_function_evaluations.\n\n\n\n\n\n","category":"type"},{"location":"manual/solvers/#Dynamical-System-Variants","page":"Dynamical Systems","title":"Dynamical System Variants","text":"","category":"section"},{"location":"manual/solvers/","page":"Dynamical Systems","title":"Dynamical Systems","text":"Shaojie Bai, J. Zico Kolter, Vladlen Koltun (2019) introduced Discrete Deep Equilibrium Models which drives a Discrete Dynamical System to its steady-state. Avik Pal, Alan Edelman, Christopher Rackauckas (2022) extends this framework to Continuous Dynamical Systems which converge to the steady-stable in a more stable fashion. For a detailed discussion refer to Avik Pal, Alan Edelman, Christopher Rackauckas (2022).","category":"page"},{"location":"manual/solvers/#Continuous-DEQs","page":"Dynamical Systems","title":"Continuous DEQs","text":"","category":"section"},{"location":"manual/solvers/","page":"Dynamical Systems","title":"Dynamical Systems","text":"ContinuousDEQSolver","category":"page"},{"location":"manual/solvers/#DeepEquilibriumNetworks.ContinuousDEQSolver","page":"Dynamical Systems","title":"DeepEquilibriumNetworks.ContinuousDEQSolver","text":"ContinuousDEQSolver(alg=OrdinaryDiffEq.VCABM3(); mode::Symbol=:rel_deq_default,\n                    abstol=1f-8, reltol=1f-8, abstol_termination=1f-8,\n                    reltol_termination=1f-8, tspan=Inf32)\n\nSolver for Continuous DEQ Problem (Avik Pal, Alan Edelman, Christopher Rackauckas (2022)). Similar to DynamicSS but provides more flexibility needed for solving DEQ problems.\n\nArguments\n\nalg: Algorithm to solve the ODEProblem. (Default: VCABM3())\nmode: Termination Mode of the solver. See below for a description of the various termination conditions (Default: :rel_deq_default)\nabstol: Absolute tolerance for time stepping. (Default: 1f-8)\nreltol: Relative tolerance for time stepping. (Default: 1f-8)\nabstol_termination: Absolute tolerance for termination. (Default: 1f-8)\nreltol_termination: Relative tolerance for termination. (Default: 1f-8)\ntspan: Time span. Users should not change this value, instead control termination through maxiters in solve (Default: Inf32)\n\nSee also: DiscreteDEQSolver\n\n\n\n\n\n","category":"type"},{"location":"manual/solvers/#Discrete-DEQs","page":"Dynamical Systems","title":"Discrete DEQs","text":"","category":"section"},{"location":"manual/solvers/","page":"Dynamical Systems","title":"Dynamical Systems","text":"DiscreteDEQSolver","category":"page"},{"location":"manual/solvers/#DeepEquilibriumNetworks.DiscreteDEQSolver","page":"Dynamical Systems","title":"DeepEquilibriumNetworks.DiscreteDEQSolver","text":"DiscreteDEQSolver(alg=LimitedMemoryBroydenSolver(); mode::Symbol=:rel_deq_default,\n                  abstol_termination::T=1.0f-8, reltol_termination::T=1.0f-8)\n\nSolver for Discrete DEQ Problem (Shaojie Bai, J. Zico Kolter, Vladlen Koltun (2019)). Similar to SSrootfind but provides more flexibility needed for solving DEQ problems.\n\nArguments\n\nalg: Algorithm to solve the Nonlinear Problem. (Default: LimitedMemoryBroydenSolver)\nmode: Termination Mode of the solver. See below for a description of the various termination conditions. (Default: :rel_deq_default)\nabstol_termination: Absolute tolerance for termination. (Default: 1f-8)\nreltol_termination: Relative tolerance for termination. (Default: 1f-8)\n\nSee also: ContinuousDEQSolver\n\n\n\n\n\n","category":"type"},{"location":"manual/solvers/#Termination-Conditions","page":"Dynamical Systems","title":"Termination Conditions","text":"","category":"section"},{"location":"manual/solvers/#Termination-on-Absolute-Tolerance","page":"Dynamical Systems","title":"Termination on Absolute Tolerance","text":"","category":"section"},{"location":"manual/solvers/","page":"Dynamical Systems","title":"Dynamical Systems","text":":abs: Terminates if all left(  fracpartial upartial t  leq abstol right)\n:abs_norm: Terminates if  fracpartial upartial t  leq abstol\n:abs_deq_default: Essentially abs_norm + terminate if there has been no improvement for the last 30 steps + terminate if the solution blows up (diverges)\n:abs_deq_best: Same as :abs_deq_default but uses the best solution found so far, i.e. deviates only if the solution has not converged","category":"page"},{"location":"manual/solvers/#Termination-on-Relative-Tolerance","page":"Dynamical Systems","title":"Termination on Relative Tolerance","text":"","category":"section"},{"location":"manual/solvers/","page":"Dynamical Systems","title":"Dynamical Systems","text":":rel: Terminates if all left( fracpartial upartial t  leq reltol times  u  right)\n:rel_norm: Terminates if  fracpartial upartial t  leq reltol times  fracpartial upartial t + u \n:rel_deq_default: Essentially rel_norm + terminate if there has been no improvement for the last 30 steps + terminate if the solution blows up (diverges)\n:rel_deq_best: Same as :rel_deq_default but uses the best solution found so far, i.e. deviates only if the solution has not converged","category":"page"},{"location":"manual/solvers/#Termination-using-both-Absolute-and-Relative-Tolerances","page":"Dynamical Systems","title":"Termination using both Absolute and Relative Tolerances","text":"","category":"section"},{"location":"manual/solvers/","page":"Dynamical Systems","title":"Dynamical Systems","text":":norm: Terminates if  fracpartial upartial t  leq reltol times  fracpartial upartial t + u  &           fracpartial upartial t  leq abstol\nfallback: Check if all values of the derivative is close to zero wrt both relative and absolute tolerance. This is usable for small problems             but doesn't scale well for neural networks, and should be avoided unless absolutely necessary","category":"page"},{"location":"#DeepEquilibriumNetworks:-(Fast)-Deep-Equlibrium-Networks","page":"Home","title":"DeepEquilibriumNetworks: (Fast) Deep Equlibrium Networks","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"DeepEquilibriumNetworks.jl is a framework built on top of DifferentialEquations.jl and Lux.jl enabling the efficient training and inference for Deep Equilibrium Networks (Infinitely Deep Neural Networks).","category":"page"},{"location":"#Installation","page":"Home","title":"Installation","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"] add DeepEquilibriumNetworks","category":"page"},{"location":"#Quickstart","page":"Home","title":"Quickstart","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"using Lux, DeepEquilibriumNetworks, Random\n\nseed = 0\nrng = Random.default_rng()\nRandom.seed!(rng, seed)\n\nmodel = DEQChain(Dense(2, 2),\n                 DeepEquilibriumNetwork(Parallel(+, Dense(2, 2; bias=false),\n                                                 Dense(2, 2; bias=false)),\n                                        ContinuousDEQSolver(; abstol=0.1f0,\n                                                            reltol=0.1f0,\n                                                            abstol_termination=0.1f0,\n                                                            reltol_termination=0.1f0)))\n\nps, st = gpu.(Lux.setup(rng, model))\nx = gpu(rand(rng, Float32, 2, 1))\ny = gpu(rand(rng, Float32, 2, 1))\n\ngs = gradient(p -> sum(abs2, model(x, p, st)[1][1] .- y), ps)[1]","category":"page"},{"location":"#Citation","page":"Home","title":"Citation","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"If you are using this project for research or other academic purposes consider citing our paper:","category":"page"},{"location":"","page":"Home","title":"Home","text":"@misc{pal2022mixing,\n      title={Mixing Implicit and Explicit Deep Learning with Skip DEQs and Infinite Time Neural ODEs (Continuous DEQs)}, \n      author={Avik Pal and Alan Edelman and Christopher Rackauckas},\n      year={2022},\n      eprint={2201.12240},\n      archivePrefix={arXiv},\n      primaryClass={cs.LG}\n}","category":"page"},{"location":"","page":"Home","title":"Home","text":"For specific algorithms, check the respective documentations and cite the corresponding papers.","category":"page"},{"location":"manual/layers/#Layers","page":"General Purpose Layers","title":"Layers","text":"","category":"section"},{"location":"manual/layers/","page":"General Purpose Layers","title":"General Purpose Layers","text":"DEQChain","category":"page"},{"location":"manual/nlsolve/#NonLinear-Solvers","page":"Non Linear Solvers","title":"NonLinear Solvers","text":"","category":"section"},{"location":"manual/nlsolve/","page":"Non Linear Solvers","title":"Non Linear Solvers","text":"We provide the following NonLinear Solvers for DEQs. These are compatible with GPUs.","category":"page"},{"location":"manual/nlsolve/","page":"Non Linear Solvers","title":"Non Linear Solvers","text":"note: Note\nIf you are looking for general purpose nonlinear solvers, we recommend checking out NonlinearSolve.jl","category":"page"},{"location":"manual/nlsolve/","page":"Non Linear Solvers","title":"Non Linear Solvers","text":"BroydenSolver\nLimitedMemoryBroydenSolver","category":"page"},{"location":"manual/nlsolve/#DeepEquilibriumNetworks.BroydenSolver","page":"Non Linear Solvers","title":"DeepEquilibriumNetworks.BroydenSolver","text":"BroydenSolver()\n\nBroyden Solver (Charles G Broyden (1965)) for solving Discrete DEQs. It is recommended to use LimitedMemoryBroydenSolver for better performance.\n\nSee also: LimitedMemoryBroydenSolver\n\n\n\n\n\n","category":"type"},{"location":"manual/nlsolve/#DeepEquilibriumNetworks.LimitedMemoryBroydenSolver","page":"Non Linear Solvers","title":"DeepEquilibriumNetworks.LimitedMemoryBroydenSolver","text":"LimitedMemoryBroydenSolver()\n\nLimited Memory Broyden Solver (Shaojie Bai, Vladlen Koltun, J. Zico Kolter (2020)) for solving Discrete DEQs.\n\nSee also: BroydenSolver\n\n\n\n\n\n","category":"type"}]
}
