# * Threaded map
"""
    Threaded()

Maps concurrently over elements of an array using `Threads.@threads`.

## Usage

```jldoctest
julia> using MoreMaps

julia> C = Chart(Threaded())
Chart{All, Threaded, NoProgress, NoExpansion}(Threaded(), NoProgress(), NoExpansion())

julia> data = [1, 2, 3, 4, 5];

julia> result = map(x -> x^2, C, data)
5-element Vector{Int64}:
  1
  4
  9
 16
 25

julia> nested_data = [[1, 2], [3, 4], [5, 6]]; # Works with nested arrays

julia> C_nested = Chart(Vector{Int}, Threaded());

julia> result = map(sum, C_nested, nested_data)
3-element Vector{Int64}:
  3
  7
 11
```

**Note**: Results may not be in deterministic order due to parallel execution.
Use `Sequential()` if order matters or for debugging.

See also: [`Sequential`](@ref), [`Chart`](@ref), [`map`](@ref)
"""
Threaded
export Threaded
const ThreadedChart = Chart{L, B} where {L, B <: Threaded}
function Base.map(f, C::ThreadedChart, itrs...)
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

        @static if VERSION >= v"1.11"
            Threads.@threads :greedy for i in eachindex(idxs)
                @inbounds ys[i][] = g(i, map(Base.Fix2(getindex, i), xs)...)
            end
        else
            Threads.@threads for i in eachindex(idxs)
                @inbounds ys[i][] = g(i, map(Base.Fix2(getindex, i), xs)...)
            end
        end
    finally # * Finalize log
        close_log!(C)
    end
    return out
end
