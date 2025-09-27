module ProgressLoggingExt

import ProgressLogging as PLG
import ProgressLogging: @logmsg, Progress
import MoreMaps
import MoreMaps: LogLogger, init_log!, log_log!, close_log!
using UUIDs
import Base.Threads: Atomic, ReentrantLock
import Distributed: RemoteChannel

"""
    ProgressLogger(nlogs::Int = 10; id = UUIDs.uuid4(), kwargs...)

A progress logger that integrates with the ProgressLogging.jl ecosystem.
Combines `LogLogger` functionality with ProgressLogging.jl's structured progress reporting.
Useful for applications that need standardized progress reporting (e.g., Pluto.jl notebooks, IDEs).

## Arguments
- `nlogs::Int`: Number of progress update intervals (default: 10)
- `id`: Unique identifier for the progress logger (default: auto-generated UUID)
- `kwargs...`: Additional keyword arguments passed to `ProgressLogging.Progress`

## Usage

```jldoctest; output = false
julia> using MoreMaps, ProgressLogging

julia> P = ProgressLogger(5)
ProgressLogger(LogLogger(5), ProgressLogging.Progress(UUIDs.UUID("00000000-0000-0000-0000-000000000000"), "Progress", 1.0, false, :normal, 0, 1.0, Dict{String, Any}(), Any[]))

julia> C = Chart(P)
Chart{MoreMaps.All, Sequential, ProgressLogger, NoExpansion}(Sequential(), ProgressLogger(LogLogger(5), ProgressLogging.Progress(UUIDs.UUID("00000000-0000-0000-0000-000000000000"), "Progress", 1.0, false, :normal, 0, 1.0, Dict{String, Any}(), Any[])), NoExpansion())

julia> data = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

julia> result = map(x -> x^2, C, data); # Will emit ProgressLogging.jl messages

julia> result
10-element Vector{Int64}:
   1
   4
   9
  16
  25
  36
  49
  64
  81
 100

julia> # Works with any backend
       C_threaded = Chart(Threaded(), ProgressLogger(3));
```

Best with:
- VSCode's progress indicator
- Jupyter notebooks
- Pluto.jl notebooks
- [TerminalLoggers.jl](https://github.com/JuliaLogging/TerminalLoggers.jl)

**Note**: Requires ProgressLogging.jl to be loaded. Progress messages are emitted as structured logs
that can be captured by compatible logging systems. Use `LogLogger` for simple console output
or `NoProgress` to disable progress reporting entirely.

See also: [`LogLogger`](@ref), [`NoProgress`](@ref), [`Chart`](@ref)
"""
function MoreMaps.ProgressLogger(args...; id = UUIDs.uuid4(), kwargs...)
    MoreMaps.ProgressLogger(MoreMaps.LogLogger(args...),
                            PLG.Progress(id; kwargs...))
end

function init_log!(P::MoreMaps.ProgressLogger, total)
    P.info.total = total
    P.info.current = Atomic{Int}(0)
    P.info.channel = RemoteChannel(() -> Channel{Bool}(total), 1)
    P.info.lck = ReentrantLock()

    # * Start progress
    @logmsg PLG.ProgressLevel Progress(P.Progress.id, 0.0; name = P.Progress.name)

    every = max(1, div(P.info.total, P.info.nlogs))
    @async while take!(P.info.channel)
        Threads.lock(P.info.lck) do
            Threads.atomic_add!(P.info.current, 1)
            progress = P.info.current[] * every / P.info.total
            @logmsg PLG.ProgressLevel Progress(P.Progress.id, progress;
                                               name = P.Progress.name)
        end
    end
end
log_log!(P::MoreMaps.ProgressLogger, i) = log_log!(P.info, i)

function close_log!(P::MoreMaps.ProgressLogger)
    close_log!(P.info)
    @logmsg PLG.ProgressLevel Progress(P.Progress.id; name = P.Progress.name, done = true)
end

end




