# MoreMaps

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://brendanjohnharris.github.io/TimeseriesDocs.jl/dev/MoreMaps/)
[![Build Status](https://github.com/brendanjohnharris/MoreMaps.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/brendanjohnharris/MoreMaps.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/brendanjohnharris/MoreMaps.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/brendanjohnharris/MoreMaps.jl)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)
[![](https://img.shields.io/badge/%F0%9F%9B%A9%EF%B8%8F_tested_with-JET.jl-233f9a)](https://github.com/aviatesk/JET.jl)
[![code style: runic](https://img.shields.io/badge/code_style-%E1%9A%B1%E1%9A%A2%E1%9A%BE%E1%9B%81%E1%9A%B2-black)](https://github.com/fredrikekre/Runic.jl)

A flexible mapping framework for Julia that provides different parallel backends, progress tracking, and iteration patterns.

## Features

- **Multiple backends**: Sequential, Threads, Distributed, and Dagger execution
- **Progress tracking**: Support for various progress-logging backends
- **Nested array support**: Map over specific leaf types in nested array structures
- **Cartesian expansions**: Easy cartesian product iterations

## Quick Start

```julia
using MoreMaps

# Basic usage with default sequential backend
x = rand(100)
C = Chart()
y = map(sqrt, C, x)

# Use threading for parallel execution
C_threaded = Chart(Threaded())
y_threaded = map(sqrt, C_threaded, x)

# Add progress tracking
C_progress = Chart(Threaded(), LogLogger(10))
y_progress = map(sqrt, C_progress, x)
```

## Basics

The basis of a `MoreMaps` map is the `Chart` type, which configures how mapping operations are executed.

A `Chart` has the following fields:

- `backend`: Specifies the execution backend
- `progress`: Configures the progress logging behavior
- `leaf`: Defines the element type where recursion terminates, for mapping nested arrays
- `expansion`: Determines the expansion strategy (e.g. Cartesian product)

A chart can be constructed using keywords or arbitrary-order positional arguments. The default `Chart()` reproduces `Base.map()`, and is constructed as:

```julia
C = Chart(backend=Sequential(),    # No parallel execution; similar to Base.map
          progress=NoProgress(),   # No progress logging
          leaf=MoreMaps.All,                # Map over each element of the root array, like Base.map
          expansion=NoExpansion()) # Map over the original input arrays, as for Base.map

# Or
C = Chart(Sequential(), NoProgress(), MoreMaps.All, NoExpansion()) # In any order

# Default behavior
C == Chart()
```

Once you have a Chart, pass it to the standard `Base.map` function:

```julia
x = rand(10)
C = Chart()
y = map(sqrt, C, x)
y == map(sqrt, x) # Default behavior reproduces Base.map
```

## Backends

| Backend | Requires | Overhead per element\* | Use when |
|----|----|----|----|
| `Sequential` | — | ~0.2 µs | Default; small or fast maps, debugging, deterministic execution order |
| `Threaded` | `julia -t` | ~4 µs | CPU-bound elements on one machine; `Threads.@threads` |
| `OhMyThreaded` | OhMyThreads.jl, `julia -t` | ~0.2 µs | Uneven per-element cost; chunked, load-balanced scheduling. Prefer over `Threaded` |
| `Polyestered` | Polyester.jl, `julia -t` | ~1 µs | Very cheap elements at large N. Supports only `NoProgress` and `Monitor` (Polyester tasks must not yield) |
| `Asyncmap` | — | ~5 µs | IO-bound elements (file loading, network): tasks overlap while waiting. No gain for CPU-bound work |
| `Pmap` | `addprocs` | ~100 µs | Expensive elements (more than ~10 ms each) across processes; below that, serialization dominates |
| `Daggermap` | Dagger.jl, `addprocs` | ~3 µs (batched) | Heterogeneous or multi-node resources; per-task scheduler options (`scope`, `occupancy`) via `Daggermap(; kwargs...)` |

\*Scheduling and writeback floor for a trivial `f`, measured by `benchmark/backend_benchmark.jl` (Julia 1.12, 20 threads, 4 workers); re-run that script on your own machine for local numbers.

## Progress loggers

- `NoProgress`: No progress logging
- `LogLogger`: Logs progress information with `@info`
- `ProgressLogger`: Uses `ProgressLogging.jl`
- `TermLogger`: Uses `Term.jl`
- `QualityLogger`: Shows a quality metric (e.g. percentage of NaN values) in a progress array
- `CallbackLogger`: Calls a user function per completed element (a programmatic sink)
- `CompositeLogger`: Forwards progress events to multiple child loggers

## Monitoring

`Monitor` occupies the progress slot and cheaply records each job (two clock and GC
snapshots, nothing per element):

```julia
M = Monitor()
map(f, Chart(Threaded(), M), x)
M.time, M.bytes, M.allocs, M.gctime, M.n
```

Combine with a logger via `CompositeLogger(Monitor(), LogLogger())`. For distributed
backends the allocation counters cover the driver process only.

## Leaf types

- `MoreMaps.All`: Matches all element types; maps over each element of the root array
- `Union{}`: Matches no element types; always recurses to the last non-iterable type
- Specific types: Recurse until the first element of a given type is found

# Related packages

- [`ThreadsX`](https://github.com/tkf/ThreadsX.jl): Provides Base-compatible parallel APIs with deterministic results, supports generators and transducers
- [`FLoops`](https://github.com/JuliaFolds/FLoops.jl): Flexible for-loops with threading support, cache-friendly, composable with different executors
- [`Strided`](https://github.com/Jutho/Strided.jl): Cache-friendly multithreaded operations for strided arrays with optimized memory access patterns
- [`LoopVectorization`](https://github.com/JuliaSIMD/LoopVectorization.jl): SIMD vectorization and multi-threading for numerical loops with near-optimal CPU utilization
- [`Polyester`](https://github.com/JuliaSIMD/Polyester.jl).@batch: Lightweight threading with lower overhead than Threads.@threads
- [`Dagger`](https://github.com/JuliaParallel/Dagger.jl): Dynamic task scheduling with DAG-based execution for out-of-core and distributed computing
- [`ParallelUtilities`](https://github.com/jishnub/ParallelUtilities.jl): HPC-focused utilities for embarrassingly parallel operations with efficient work distribution
- [`Transducers`](https://github.com/JuliaFolds/Transducers.jl): Composable algorithmic transformations with automatic parallelization support
- [`Folds`](https://github.com/JuliaFolds/Folds.jl): High-level parallel APIs (mapreduce, sum, etc.) with multiple executor backends
- [`SplittablesBase`](https://github.com/JuliaFolds/SplittablesBase.jl): Interface for defining splittable collections for parallel processing
- [`ParallelProgressMeter`](https://github.com/jekyllstein/ParallelProgressMeter.jl): Multiple progress bars for parallel tasks
- [`PmapProgressMeter`](https://github.com/slundberg/PmapProgressMeter.jl): Progress tracking specifically for pmap operations
- [`MappedArrays`](https://github.com/JuliaArrays/MappedArrays.jl): Lazy element-wise transformations without memory allocation
- [`FoldsThreads`](https://github.com/JuliaFolds/FoldsThreads.jl): Multiple threading executors (WorkStealingEx, DepthFirstEx, NondeterministicEx)

# Gallery

### InfoProgress

```julia {cast="true"}
using MoreMaps; x = rand(10); f(x) = (sleep(0.1); x^2);
map(f, LogLogger() |> Chart, x)
```

![](https://github.com/brendanjohnharris/MoreMaps.jl/releases/download/v0.3.0/output_1_@cast.gif)

### TermLogger

```julia {cast="true"}
using MoreMaps; using Term; import MoreMaps: TermLogger

x = randn(100); f(x) = (sleep(0.05); x^2);
map(f, TermLogger() |> Chart, x)
```

![](https://github.com/brendanjohnharris/MoreMaps.jl/releases/download/v0.3.0/output_2_@cast.gif)

### QualityLogger

```julia {cast="true"}
using MoreMaps; x = randn(100)
f(x) = (sleep(0.05); x > 0.5 ? NaN : x^2);
map(f, QualityLogger() |> Chart, x)
```

![](https://github.com/brendanjohnharris/MoreMaps.jl/releases/download/v0.3.0/output_3_@cast.gif)

```julia {cast="true"}
using MoreMaps ;x = randn(100);
function f(x)
    sleep(0.05)
    x = randn(10)
    N = rand(0:10)
    x[1:N] .= NaN
    return x
end
map(f, QualityLogger() |> Chart, x)
```

![](https://github.com/brendanjohnharris/MoreMaps.jl/releases/download/v0.3.0/output_4_@cast.gif)

# Interface

`MoreMaps` is extensible: you can add new backends or progress loggers by implementing a small set of methods. The internal scaffolding (`MoreMaps._run_map`) handles preallocation, logger lifecycle, and the per-element closure, so your implementation only needs to describe how work is dispatched and how results are written back.

## Backend interface

A backend is a subtype of `MoreMaps.Backend`. To add a new backend `MyBackend`:

1.  Define the type and a `Chart` alias:

    ``` julia
    struct MyBackend <: MoreMaps.Backend end
    const MyChart = Chart{L, B} where {L, B <: MyBackend}
    ```

2.  Implement `MoreMaps._map(f, C::MyChart, itrs...)`. The recommended pattern is to delegate to `MoreMaps._run_map` and supply only the kernel:

    ``` julia
    function MoreMaps._map(f, C::MyChart, itrs...)
        return MoreMaps._run_map(f, C, itrs) do g, ys, idxs, xs
            # Drive `g` over eachindex(idxs); write results into ys[i][].
            for i in eachindex(idxs)
                @inbounds ys[i][] = g(i, map(Base.Fix2(getindex, i), xs)...)
            end
        end
    end
    ```

    The kernel receives:

    - `g(i, x...)`: calls the user function and emits a progress log. Always call this rather than `f` directly.
    - `ys`: a vector of zero-dimensional views into the preallocated output. Assign with `ys[i][] = value`.
    - `idxs`: the iteration indices (length is the total work count).
    - `xs`: leaf views over each input iterable.

    The logger lifecycle (`init_log!` / `close_log!`) and exception safety are handled by `_run_map`.

## Progress logger interface

A progress logger is a subtype of `MoreMaps.Progress`. To add a new logger `MyLogger`:

1.  Define the type. If it owns a `RemoteChannel` and consumer `Task`, type those fields concretely (or as `Union{Nothing, ...}` if construction precedes initialization, but assert concretely at use sites):

    ``` julia
    mutable struct MyLogger <: MoreMaps.Progress
        # ...your fields...
    end
    ```

2.  Implement three methods:

    ``` julia
    MoreMaps.init_log!(P::MyLogger, total::Int) # called once before mapping
    MoreMaps.log_log!(P::MyLogger, i::Int) # called per element
    MoreMaps.close_log!(P::MyLogger) # called once after mapping (in a finally block)
    ```

    Optional extensions:

    - `MoreMaps.log_log!(P::MyLogger, i::Int, y)`: receive the produced value (e.g. for `QualityLogger`-style scoring). The default forwards to the two-argument form.
    - `MoreMaps.init_log!(P::MyLogger, total::Int, C::Chart)`: receive the Chart for richer summaries. The default forwards to the two-argument form.

3.  If the logger ships events over a `RemoteChannel` to a driver-side consumer `Task`, subtype `MoreMaps.ChannelProgress` instead of `MoreMaps.Progress` and name the fields `channel` and `consumer`: this provides `MoreMaps._open_channel!(P, T)`, `MoreMaps._close_consumer!(P, sentinel)`, and a `Serialization.serialize` method that nulls the consumer so the logger can cross worker boundaries (see `LogLogger.jl` or `CallbackLogger.jl` for the pattern).

## Shared helpers

Useful utilities exported internally for logger implementations:

- `MoreMaps._progress_every(total, nlogs)`: compute update granularity.
- `MoreMaps._format_human_time(seconds)`: pretty-print a duration.
