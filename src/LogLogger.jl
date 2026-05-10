using Logging

export LogLogger
"""
    LogLogger(; nlogs::Int = 10, level::LogLevel=Info)
    LogLogger(nlogs::Int = 10, level::LogLevel=Info)

A progress logger that displays progress information using `@info` messages.
Shows periodic updates during mapping operations.

## Arguments
- `nlogs::Int`: Number of progress messages to display (default: 10)

## Usage

```julia-repl
julia> using MoreMaps

julia> C = Chart(LogLogger(3))

julia> data = [1, 2, 3, 4, 5, 6];

julia> result = map(x -> (sleep(0.5); x^2), C, data); # Will show progress messages during execution

julia> result

julia> using Logging # Choose a log level

julia> C = Chart(LogLogger(4, Warn));

julia> map(x -> (sleep(0.5); x + 1), C, [1, 2, 3, 4]);
```
"""
Base.@kwdef mutable struct LogLogger <: Progress
    nlogs::Int = 10
    level::LogLevel = Info
    current::Atomic{Int} = Atomic{Int}(0)
    total::Int = 0
    started_at::Float64 = 0.0
    lck::AbstractLock = ReentrantLock()
    channel::Union{Nothing, RemoteChannel{Channel{Bool}}} = nothing
    consumer::Union{Nothing, Task} = nothing
    function LogLogger(nlogs::Int,
                       level::LogLevel = Info,
                       current = Atomic{Int}(0),
                       total = 0,
                       started_at = 0.0,
                       lck = ReentrantLock(),
                       channel = nothing,
                       consumer = nothing)
        new(nlogs, level, current, total, started_at, lck, channel, consumer)
    end
end

function Serialization.serialize(s::Serialization.AbstractSerializer, P::LogLogger)
    Serialization.serialize_cycle(s, P) && return
    Serialization.serialize_type(s, LogLogger, true)
    for f in fieldnames(LogLogger)
        v = getfield(P, f)
        Serialization.serialize(s, f === :consumer ? nothing : v)
    end
end

function _format_elapsed_total(elapsed::Real, estimated_total::Real)
    "$(_format_human_time(elapsed)) / $(_format_human_time(estimated_total))"
end

function init_log!(P::LogLogger, total)
    P.total = total
    P.current = Atomic{Int}(0)
    P.started_at = time()
    P.channel = RemoteChannel(() -> Channel{Bool}(max(P.nlogs, 1) + 1), 1)
    P.lck = ReentrantLock()

    @logmsg P.level "Progress: 0 / $(P.total) (??s / ??s)"

    every = _progress_every(P.total, P.nlogs)
    ch = P.channel::RemoteChannel{Channel{Bool}}
    P.consumer = @async while take!(ch)
        Threads.lock(P.lck) do
            Threads.atomic_add!(P.current, 1)
            done = min(P.current[] * every, P.total)
            elapsed = max(time() - P.started_at, eps())
            estimated_total = if done > 0
                elapsed * P.total / done
            else
                Inf
            end
            @logmsg P.level "Progress: $(done) / $(P.total) ($(_format_elapsed_total(elapsed, estimated_total)))"
        end
    end
end
function log_log!(P::LogLogger, i)
    every = _progress_every(P.total, P.nlogs)
    i % every == 0 && put!(P.channel::RemoteChannel{Channel{Bool}}, true)
end
function close_log!(P::LogLogger)
    put!(P.channel::RemoteChannel{Channel{Bool}}, false)
    consumer = P.consumer
    consumer === nothing || wait(consumer::Task)
    return
end
