module PolyesterExt

using Polyester
using MoreMaps
import MoreMaps: Polyestered, Chart, backend, progress, NoProgress, Monitor

"""
    Polyestered()

Maps over elements of an array using `Polyester.@batch`: threading with very low
per-iteration overhead.

Best for:
- Large arrays of cheap elements, where the per-task overhead of `Threaded` or
  `OhMyThreaded` dominates the work itself

## Usage

```jldoctest
julia> using MoreMaps, Polyester

julia> C = Chart(Polyestered())
Chart{MoreMaps.All, Polyestered, NoProgress, NoExpansion}(Polyestered(), NoProgress(), NoExpansion())

julia> data = [1, 2, 3, 4, 5];

julia> result = map(x -> x^2, C, data)
5-element Vector{Int64}:
  1
  4
  9
 16
 25
```

**Note**: Requires Polyester.jl to be loaded. Polyester tasks must not yield, and every
channel-backed progress logger yields on `put!`, so `Polyestered` supports only
`NoProgress` and [`Monitor`](@ref) (which does nothing per element); attaching any other
logger throws an `ArgumentError`. Use [`Threaded`](@ref) or [`OhMyThreaded`](@ref) when
progress logging is needed.

See also: [`Threaded`](@ref), [`OhMyThreaded`](@ref), [`MoreMaps.Chart`](@ref)
"""
MoreMaps.Polyestered

const PolyesteredChart = Chart{L, B} where {L, B <: Polyestered}

function MoreMaps._map(f, C::PolyesteredChart, itrs...)
    if !(progress(C) isa Union{NoProgress, Monitor}) # Monitor is a per-element no-op
        throw(
            ArgumentError(
                "Polyestered does not support progress loggers: Polyester tasks must not \
                 yield, and loggers yield on channel put!. Use Threaded() or \
                 OhMyThreaded() instead."
            )
        )
    end
    return MoreMaps._run_map(f, C, itrs) do g, ys, idxs, xs
        Polyester.@batch for i in eachindex(idxs)
            @inbounds ys[i][] = g(i, map(Base.Fix2(getindex, i), xs)...)
        end
    end
end

end # module
