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
    total::Int = 0 ÷ nlogs
    lck::AbstractLock = ReentrantLock()
    channel::Union{Nothing, RemoteChannel{Channel{Bool}}} = nothing
    function LogLogger(nlogs::Int = 10,
                       level::LogLevel = Info,
                       current = Atomic{Int}(0),
                       total = 0 ÷ nlogs,
                       lck = ReentrantLock(),
                       channel = nothing)
        new(nlogs, level, current, total, lck, channel)
    end
end
function init_log!(P::LogLogger, total)
    P.total = total
    P.current = Atomic{Int}(0)
    P.channel = RemoteChannel(() -> Channel{Bool}(total), 1)
    P.lck = ReentrantLock()

    every = max(1, div(P.total, P.nlogs))
    @async while take!(P.channel)
        Threads.lock(P.lck) do
            Threads.atomic_add!(P.current, 1)
            @logmsg P.level "Progress: $(P.current[]*every) / $(P.total)"
        end
    end
end
function log_log!(P::LogLogger, i)
    every = max(1, div(P.total, P.nlogs))
    i % every == 0 && put!(P.channel, true)
end
close_log!(P::LogLogger) = put!(P.channel, false)
