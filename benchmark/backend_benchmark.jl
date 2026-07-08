#! /bin/bash
#=
exec julia +1.12 -t auto --project="$(dirname "${BASH_SOURCE[0]}")" "${BASH_SOURCE[0]}" "$@"
=#
# Unified backend benchmark (not part of the test suite). Measures per-element overhead
# and crossover behavior for every MoreMaps backend; the results inform the backend
# comparison table in the README (update it when re-running on new hardware or Julia
# versions). Setup:
#   julia --project=benchmark -e 'using Pkg; Pkg.develop(path="."); Pkg.instantiate()'
#   ./benchmark/backend_benchmark.jl

using Distributed
nprocs() == 1 && addprocs(4)
@everywhere using MoreMaps
@everywhere using Dagger
using OhMyThreads, Polyester
using Printf

@everywhere begin # CPU-busy for a target duration; the unit of tunable per-element cost
    function busy(seconds)
        t0 = time_ns()
        x = 0.0
        while (time_ns() - t0) < seconds * 1.0e9
            x += sin(x + 1.0)
        end
        return x
    end
end

const BACKENDS = [
    "Sequential" => Sequential(),
    "Threaded" => Threaded(),
    "OhMyThreaded" => OhMyThreaded(),
    "Polyestered" => Polyestered(),
    "Asyncmap" => Asyncmap(),
    "Pmap" => Pmap(),
    "Daggermap" => Daggermap(),
]

runone(f, b, x) = (map(f, Chart(b), x); @elapsed map(f, Chart(b), x)) # warm, then time

begin # * Per-element overhead: trivial f over large N (README table: overhead column)
    println("\n## Per-element overhead (trivial f, N = 10_000; seconds/element)")
    N = 10_000
    x = collect(1.0:N)
    for (name, b) in BACKENDS
        t = runone(sqrt, b, x)
        @printf "%-14s %.3g\n" name t / N
    end
end

begin # * CPU-bound sweep (crossovers between threading and distribution)
    println("\n## CPU-bound sweep (seconds; nthreads=$(Threads.nthreads()), nworkers=$(nworkers()))")
    grid = [(1000, 1.0e-5), (100, 1.0e-3), (20, 5.0e-2)]
    @printf "%-14s" "backend"
    for (N, c) in grid
        @printf " %12s" "N=$N,c=$c"
    end
    println()
    for (name, b) in BACKENDS
        @printf "%-14s" name
        for (N, c) in grid
            t = runone(_ -> busy(c), b, fill(1.0, N))
            @printf " %12.4f" t
        end
        println()
    end
end

begin # * IO-bound sweep: sleep instead of spin (Asyncmap territory)
    println("\n## IO-bound sweep (f = sleep; seconds)")
    grid = [(100, 1.0e-2), (500, 1.0e-3)]
    @printf "%-14s" "backend"
    for (N, c) in grid
        @printf " %12s" "N=$N,c=$c"
    end
    println()
    for (name, b) in BACKENDS
        name == "Polyestered" && continue # sleep yields; not allowed in Polyester tasks
        @printf "%-14s" name
        for (N, c) in grid
            t = runone(_ -> sleep(c), b, fill(1.0, N))
            @printf " %12.4f" t
        end
        println()
    end
end

begin # * Notes on costs the sweeps exclude
    println("\n## Notes")
    println("- Startup costs (scheduler warmup, worker code loading) are excluded by the")
    println("  warmup run; measure them in a fresh session if they matter.")
    println("- Pmap/Daggermap columns include serialization of inputs/outputs.")
end
