export CompositeLogger

"""
    CompositeLogger(loggers...)

A progress logger that forwards every logging event to each of its child loggers, so
several outputs can track the same map (e.g. a terminal bar plus a callback).

## Usage

```jldoctest
julia> using MoreMaps

julia> counts = Ref(0); values = Float64[];

julia> P = CompositeLogger(
           CallbackLogger(info -> counts[] += 1),
           CallbackLogger(info -> push!(values, info.y))
       );

julia> map(x -> x / 2, Chart(P), [1.0, 2.0, 3.0])
3-element Vector{Float64}:
 0.5
 1.0
 1.5

julia> counts[], sort(values)
(3, [0.5, 1.0, 1.5])
```

See also: [`MoreMaps.CallbackLogger`](@ref), [`MoreMaps.LogLogger`](@ref), [`MoreMaps.Chart`](@ref)
"""
struct CompositeLogger{T <: Tuple} <: Progress
    loggers::T
end
CompositeLogger(ls...) = CompositeLogger(ls)

# Explicit 3-arg init_log! and log_log!(P, i, y) forwarding is load-bearing: the generic
# Progress fallbacks would strip `C` and `y` before children (e.g. QualityLogger) see them.
init_log!(P::CompositeLogger, N) = foreach(l -> init_log!(l, N), P.loggers)
init_log!(P::CompositeLogger, N, C) = foreach(l -> init_log!(l, N, C), P.loggers)
log_log!(P::CompositeLogger, i) = foreach(l -> log_log!(l, i), P.loggers)
log_log!(P::CompositeLogger, i, y) = foreach(l -> log_log!(l, i, y), P.loggers)
close_log!(P::CompositeLogger) = foreach(close_log!, P.loggers)
