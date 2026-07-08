export CallbackLogger

"""
    CallbackLogger(callback)

A progress logger that calls `callback` once per completed element. The callback receives a
single `NamedTuple` with fields:

- `i`: the element index
- `done`: number of elements completed so far
- `total`: total number of elements
- `y`: the value produced for element `i`
- `elapsed`: seconds since the map started

The callback always runs on the driver process (on the logger's consumer task), so it can
safely mutate driver-local state even under distributed backends.

## Usage

```jldoctest
julia> using MoreMaps

julia> count = Ref(0);

julia> C = Chart(CallbackLogger(info -> count[] += 1));

julia> map(x -> x^2, C, [1, 2, 3])
3-element Vector{Int64}:
 1
 4
 9

julia> count[]
3
```

**Notes for distributed backends** (`Pmap`, `Daggermap`): the callback is never shipped to
workers (serialization replaces it with a placeholder), so any callback works, including
closures over driver-local state. The produced value `y` is shipped back over the progress
channel, so results are serialized twice; if `y` is large, compute a summary inside `f` or
use [`QualityLogger`](@ref)-style worker-side scoring instead.

See also: [`MoreMaps.LogLogger`](@ref), [`MoreMaps.CompositeLogger`](@ref), [`MoreMaps.Chart`](@ref)
"""
mutable struct CallbackLogger <: ChannelProgress
    callback::Function # Only invoked on the driver's consumer task
    total::Int
    done::Int
    started_at::Float64
    channel::Union{Nothing, RemoteChannel{Channel{Any}}}
    consumer::Union{Nothing, Task}
end
CallbackLogger(f) = CallbackLogger(f, 0, 0, 0.0, nothing, nothing)

# Workers only put! to the channel; replace the callback so closures over driver-local
# state (or function types unknown to the worker) never cross process boundaries.
function Serialization.serialize(s::Serialization.AbstractSerializer, P::CallbackLogger)
    Serialization.serialize_cycle(s, P) && return
    Serialization.serialize_type(s, CallbackLogger, true)
    for f in fieldnames(CallbackLogger)
        v = f === :consumer ? nothing : (f === :callback ? identity : getfield(P, f))
        Serialization.serialize(s, v)
    end
    return
end

function init_log!(P::CallbackLogger, total)
    P.total = total
    P.done = 0
    P.started_at = time()
    ch = _open_channel!(P, Any)
    return P.consumer = @async while true
        v = take!(ch)
        v === nothing && break
        (i, y) = v
        P.done += 1
        P.callback((; i, done = P.done, total = P.total, y, elapsed = time() - P.started_at))
    end
end

log_log!(P::CallbackLogger, i, y) = put!(P.channel::RemoteChannel{Channel{Any}}, (i, y))
log_log!(P::CallbackLogger, i) = put!(P.channel::RemoteChannel{Channel{Any}}, (i, nothing))

close_log!(P::CallbackLogger) = _close_consumer!(P, nothing)
