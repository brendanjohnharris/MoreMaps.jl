# * Asyncmap
"""
    Asyncmap(; ntasks = 100)

Maps concurrently over elements of an array using `Base.asyncmap`: up to `ntasks`
cooperative tasks in a single process and thread.

Best for:
- IO-bound work (file loading, network requests) where tasks spend most of their time
  waiting; `Threaded` wastes cores on such workloads
- Any `f` that yields (via IO or `sleep`); CPU-bound `f` gains nothing here

## Usage

```jldoctest
julia> using MoreMaps

julia> C = Chart(Asyncmap())
Chart{MoreMaps.All, Asyncmap, NoProgress, NoExpansion}(Asyncmap(100), NoProgress(), NoExpansion())

julia> data = [1, 2, 3, 4, 5];

julia> result = map(x -> x^2, C, data)
5-element Vector{Int64}:
  1
  4
  9
 16
 25

julia> nested_data = [[1, 2], [3, 4], [5, 6]]; # Works with nested arrays

julia> C_nested = Chart(Vector{Int}, Asyncmap(; ntasks = 10));

julia> result = map(sum, C_nested, nested_data)
3-element Vector{Int64}:
  3
  7
 11
```

**Note**: Concurrency without parallelism; tasks interleave on one thread whenever `f`
yields. If `f` never yields, execution is effectively sequential.

See also: [`Sequential`](@ref), [`Threaded`](@ref), [`Chart`](@ref)
"""
Asyncmap
export Asyncmap
const AsyncmapChart = Chart{L, B} where {L, B <: Asyncmap}
function MoreMaps._map(f, C::AsyncmapChart, itrs...)
    ntasks = backend(C).ntasks
    return MoreMaps._run_map(f, C, itrs) do g, ys, idxs, xs
        asyncmap(eachindex(idxs); ntasks) do i
            @inbounds ys[i][] = g(i, map(Base.Fix2(getindex, i), xs)...)
        end
    end
end
