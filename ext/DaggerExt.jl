module DaggerExt

using Distributed
import MoreMaps: Daggermap, init_log!, log_log!, close_log!, Chart, backend,
                 preallocate, nviews
using Dagger

"""
    Daggermap(; kwargs...)

Maps concurrently over elements of an array using Dagger.jl's task-based parallelism.
`Daggermap` creates a distributed computation graph that can execute across multiple processes and threads.

Best for:
- Very large computations
- Heterogeneous computing resources
- Complex dependency graphs
- Dynamic load balancing

## Usage

```jldoctest
julia> using MoreMaps, Dagger

julia> C = Chart(Daggermap())
Chart{All, Daggermap, NoProgress, NoExpansion}(Daggermap(Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}}()), NoProgress(), NoExpansion())

julia> data = [1, 2, 3, 4, 5];

julia> result = map(x -> x^2, C, data)
5-element Vector{Int64}:
  1
  4
  9
 16
 25

julia> nested_data = [[1, 2], [3, 4], [5, 6]]; # Works with nested arrays

julia> C_nested = Chart(Vector{Int}, Daggermap());

julia> result = map(sum, C_nested, nested_data)
3-element Vector{Int64}:
  3
  7
 11

julia> C_opts = Chart(Daggermap(; single=1)); # Pass options to Dagger.@spawn

julia> result = map(x -> x + 10, C_opts, [1, 2, 3])
3-element Vector{Int64}:
 11
 12
 13
```

**Note**: Uses Dagger.jl's task scheduling, which provides dynamic load balancing and can work across
multiple processes. Tasks are spawned lazily and executed based on resource availability.
The `options` keyword arguments are passed to `Dagger.@spawn`.

See also: [`Sequential`](@ref), [`Threaded`](@ref), [`Pmap`](@ref), [`Chart`](@ref), [`map`](@ref)
"""
Daggermap

const DaggermapChart = Chart{L, B} where {L, B <: Daggermap}

function Base.map(f, C::DaggermapChart, itrs...)
    options = backend(C).options
    # * Get preallocated array, with indices, and a data view
    out, idxs, xs = preallocate(C, f, itrs)

    # * Initialize logger
    init_log!(C, length(idxs))
    function g(i, x...)
        y = f(map(getindex, x)...)
        log_log!(C, i)
        return y
    end

    try # * Run loop
        ys = nviews(out, idxs)

        _ys = map(eachindex(idxs)) do i
            x = map(Base.Fix2(getindex, i), xs)
            Dagger.@spawn options... g(i, x...)
        end

        for (i, y) in enumerate(fetch.(_ys))
            @inbounds ys[i][] = y
        end
    finally # * Finalize log
        close_log!(C)
    end
    return out
end
end
