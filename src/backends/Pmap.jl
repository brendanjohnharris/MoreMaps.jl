# * Distributed map
"""
    Pmap()

Maps concurrently over elements across multiple Julia processes using `Distributed.pmap`.

Best for:
- Very large arrays
- Memory-intensive operations
- Multi-machine clusters

## Usage

```jldoctest
julia> using MoreMaps # @everywhere

julia> C = Chart(Pmap())
Chart{MoreMaps.All, Pmap, NoProgress, NoExpansion}(Pmap(), NoProgress(), NoExpansion())

julia> data = [1, 2, 3, 4, 5];

julia> result = map(x -> x^2, C, data)
5-element Vector{Int64}:
  1
  4
  9
 16
 25

julia> result = map(sum, Chart(Vector{Int}, Pmap()), [[1, 2], [3, 4], [5, 6]])
3-element Vector{Int64}:
  3
  7
 11
```

**Note**: Use `addprocs()` to add worker processes, and @everywhere to load `MoreMaps` and
any functions to be mapped.
Functions and data are serialized across processes, which adds overhead.

See also: [`Sequential`](@ref), [`Threaded`](@ref), [`Chart`](@ref), [`map`](@ref)
"""
Pmap

import Distributed: pmap
export Pmap
const PmapChart = Chart{L, B} where {L, B <: Pmap}
function MoreMaps._map(f, C::PmapChart, itrs...)
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
        _ys = pmap(enumerate(zip(xs...))) do (i, xs) # Dirty copy...
            g(i, xs...)
        end
        for (i, y) in enumerate(_ys)
            @inbounds ys[i][] = y
        end
    finally # * Finalize log
        close_log!(C)
    end
    return out
end
