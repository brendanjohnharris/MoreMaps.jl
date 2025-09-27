# * Regular map
"""
    Sequential()

A backend for sequential (single-threaded) execution.
Maps one-at-a-time over elements of an array, in order
`Sequential` is the default `Chart` backend.

Best for:
- Small arrays
- Operations with minimal computational cost
- Debugging and development


## Usage

```jldoctest
julia> using MoreMaps

julia> C = Chart(Sequential())
Chart{MoreMaps.All, Sequential, NoProgress, NoExpansion}(Sequential(), NoProgress(), NoExpansion())

julia> C = Chart() # Defaults to `Sequential`
Chart{MoreMaps.All, Sequential, NoProgress, NoExpansion}(Sequential(), NoProgress(), NoExpansion())

julia> data = [1, 2, 3, 4, 5];

julia> result = map(x -> x^2, C, data)
5-element Vector{Int64}:
  1
  4
  9
 16
 25


julia> nested_data = [[1, 2], [3, 4], [5, 6]]; # Works with nested arrays

julia> C_nested = Chart(Vector{Int}, Sequential());

julia> result = map(sum, C_nested, nested_data)
3-element Vector{Int64}:
  3
  7
 11
```

See also: [`Threaded`](@ref), [`Chart`](@ref), [`map`](@ref)
"""
Sequential

export Sequential
const SequentialChart = Chart{L, B, P, E} where {L, B <: Sequential, P, E}

function MoreMaps._map(f, C::SequentialChart, itrs...)
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
        res = @sync Base.map(g, eachindex(idxs), xs...)

        # * Collect results
        map(nviews(out, idxs), res) do y, x
            @inbounds y[] = x
        end

    finally # * Finalize log
        close_log!(C)
    end
    return out
end
