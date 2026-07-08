module OhMyThreadsExt

using OhMyThreads
using MoreMaps
import MoreMaps: OhMyThreaded, Chart, backend

"""
    OhMyThreaded(; kwargs...)

Maps concurrently over elements of an array using `OhMyThreads.tforeach`: chunked,
load-balanced task-based threading. Keyword options are forwarded to `tforeach`
(e.g. `scheduler`, `ntasks`, `chunksize`, `chunking`).

Best for:
- Uneven per-element cost, where chunked scheduling load-balances better than
  `Threads.@threads`
- Tuning task granularity without changing backends

## Usage

```jldoctest
julia> using MoreMaps, OhMyThreads

julia> C = Chart(OhMyThreaded())
Chart{MoreMaps.All, OhMyThreaded{@NamedTuple{}}, NoProgress, NoExpansion}(OhMyThreaded{@NamedTuple{}}(NamedTuple()), NoProgress(), NoExpansion())

julia> data = [1, 2, 3, 4, 5];

julia> result = map(x -> x^2, C, data)
5-element Vector{Int64}:
  1
  4
  9
 16
 25

julia> C_opts = Chart(OhMyThreaded(; ntasks = 2)); # Options for tforeach

julia> result = map(x -> x + 10, C_opts, [1, 2, 3])
3-element Vector{Int64}:
 11
 12
 13
```

**Note**: Requires OhMyThreads.jl to be loaded. Start Julia with multiple threads
(`julia -t auto`) for parallel execution.

See also: [`Threaded`](@ref), [`Polyestered`](@ref), [`MoreMaps.Chart`](@ref)
"""
MoreMaps.OhMyThreaded

const OhMyThreadedChart = Chart{L, B} where {L, B <: OhMyThreaded}

function MoreMaps._map(f, C::OhMyThreadedChart, itrs...)
    opts = backend(C).options
    return MoreMaps._run_map(f, C, itrs) do g, ys, idxs, xs
        OhMyThreads.tforeach(eachindex(idxs); opts...) do i
            @inbounds ys[i][] = g(i, map(Base.Fix2(getindex, i), xs)...)
        end
    end
end

end # module
