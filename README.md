# Cartographer

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://brendanjohnharris.github.io/TimeseriesDocs.jl/dev/Cartographer/)
[![Build Status](https://github.com/brendanjohnharris/Cartographer.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/brendanjohnharris/Cartographer.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/brendanjohnharris/Cartographer.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/brendanjohnharris/Cartographer.jl)


A flexible mapping framework for Julia that provides different parallel backends, progress tracking, and iteration patterns.

## Features

- **Multiple backends**: Sequential, Threads, Distributed, and Dagger execution
- **Progress tracking**: Support for various progress-logging backends
- **Nested array support**: Map over specific leaf types in nested array structures
- **Cartesian expansions**: Easy cartesian product iterations

## Quick Start

```julia
using Cartographer

# Basic usage with default sequential backend
x = rand(100)
C = Chart()
y = map(sqrt, C, x)

# Use threading for parallel execution
C_threaded = Chart(Threaded())
y_threaded = map(sqrt, C_threaded, x)

# Add progress tracking
C_progress = Chart(Threaded(), InfoProgress(10))
y_progress = map(sqrt, C_progress, x)
```

## Basics

The basis of a `Cartographer` map is the `Chart` type, which configures how mapping operations are executed.

A `Chart` has the following fields:
- `backend`: Specifies the execution backend
- `progress`: Configures the progress logging behavior
- `leaf`: Defines the element type where recursion terminates, for mapping nested arrays
- `expansion`: Determines the expansion strategy (e.g. Cartesian product)

A chart can be constructed using keywords or arbitrary-order positional arguments. The default `Chart()` reproduces `Base.map()`, and is constructed as:

```julia
C = Chart(backend=Sequential(),    # No parallel execution; similar to Base.map
          progress=NoProgress(),   # No progress logging
          leaf=Cartographer.All,                # Map over each element of the root array, like Base.map
          expansion=NoExpansion()) # Map over the original input arrays, as for Base.map

# Or
C = Chart(Sequential(), NoProgress(), Cartographer.All, NoExpansion()) # In any order

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

- `Sequential`: Default, no parallelism
- `Threads`: Uses `Threads.jl`
- `Distributed`: Uses `Distributed.jl` (pmap)
- `Daggermap`: Uses `Dagger.jl`

## Progress loggers
- `NoProgress`: No progress logging
- `InfoProgress`: Logs progress information with `@info`
- `ProgressLogger`: Uses `ProgressLogging.jl`
- `TermLogger`: Uses `Term.jl`

## Leaf types

- `Cartographer.All`: Matches all element types; maps over each element of the root array
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

