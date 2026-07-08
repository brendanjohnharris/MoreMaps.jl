module DaggerExt

using Distributed
using Dagger
using MoreMaps
import MoreMaps: Daggermap, Chart, backend

"""
    Daggermap(; batchsize = 0, kwargs...)

Maps concurrently over elements of an array using Dagger.jl's task-based parallelism.
`Daggermap` creates a distributed computation graph that can execute across multiple processes and threads.

Elements are grouped into batches of `batchsize` and one Dagger task is spawned per batch,
amortizing the per-task scheduler overhead. `batchsize = 0` (the default) picks
`cld(N, 4 * nprocs())`, giving each process about four batches for load balancing.
The remaining `kwargs` are passed to `Dagger.Options` and apply to each batch task
(e.g. `scope`, `single`, `occupancy`).

Best for:
- Very large computations
- Heterogeneous computing resources
- Complex dependency graphs
- Dynamic load balancing

## Usage

```jldoctest
julia> using MoreMaps, Dagger

julia> C = Chart(Daggermap())
Chart{MoreMaps.All, Daggermap{@NamedTuple{}}, NoProgress, NoExpansion}(Daggermap{@NamedTuple{}}(NamedTuple(), 0), NoProgress(), NoExpansion())

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

julia> C_opts = Chart(Daggermap(; single = 1, batchsize = 2)); # Options for Dagger tasks

julia> result = map(x -> x + 10, C_opts, [1, 2, 3])
3-element Vector{Int64}:
 11
 12
 13
```

**Note**: Uses Dagger.jl's task scheduling, which provides dynamic load balancing and can work across
multiple processes. Keyword options are forwarded as `Dagger.Options` to each spawned batch task.

See also: [`MoreMaps.Sequential`](@ref), [`MoreMaps.Threaded`](@ref), [`MoreMaps.Pmap`](@ref), [`MoreMaps.Chart`](@ref)
"""
MoreMaps.Daggermap

const DaggermapChart = Chart{L, B} where {L, B <: Daggermap}

# Top-level so it serializes by name to workers. Calls g per element, so progress fires.
function _g_batch(g, is, args...)
    return [g(i, map(Base.Fix2(getindex, j), args)...) for (j, i) in enumerate(is)]
end

function MoreMaps._map(f, C::DaggermapChart, itrs...)
    b = backend(C)
    return MoreMaps._run_map(f, C, itrs) do g, ys, idxs, xs
        # Detach views from their parents so task arguments do not serialize
        # the full parent buffer with every spawned task.
        xs_owned = map(vs -> map(copy, vs), xs)
        N = length(idxs)
        # ponytail: 4 batches per proc; expose a smarter heuristic if benchmarks demand it
        bs = b.batchsize > 0 ? b.batchsize : max(1, cld(N, 4 * nprocs()))
        opts = Dagger.Options(; b.options...)
        batches = collect(Iterators.partition(1:N, bs))
        tasks = map(batches) do batch
            args = map(vs -> vs[batch], xs_owned)
            Dagger.spawn(_g_batch, opts, g, collect(batch), args...)
        end
        for (batch, res) in zip(batches, map(fetch, tasks))
            for (j, i) in enumerate(batch)
                @inbounds ys[i][] = res[j]
            end
        end
    end
end
end
