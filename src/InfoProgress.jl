export InfoProgress
"""
    InfoProgress(nlogs::Int = 10)

A progress logger that displays progress information using `@info` messages.
Shows periodic updates during mapping operations.

## Arguments
- `nlogs::Int`: Number of progress messages to display (default: 10)

## Usage

```julia-repl
julia> using MoreMaps

julia> C = Chart(InfoProgress(3))

julia> data = [1, 2, 3, 4, 5, 6];

julia> result = map(x -> x^2, C, data); # Will show progress messages during execution

julia> result

julia> # Combine with different backends
       C_threaded = Chart(Threaded(), InfoProgress(2));

julia> map(x -> x + 1, C_threaded, [1, 2, 3, 4]); # Threaded with progress
```
"""
mutable struct InfoProgress <: Progress
    nlogs::Int
    current::Atomic{Int}
    total::Int
    lck::AbstractLock
    channel::Union{Nothing, RemoteChannel{Channel{Bool}}}
    function InfoProgress(nlogs::Int = 10,
                          current = Atomic{Int}(0),
                          total = 0 ÷ nlogs,
                          lck = ReentrantLock(),
                          channel = nothing)
        new(nlogs, current, total, lck, channel)
    end
end
function init_log!(P::InfoProgress, total)
    P.total = total
    P.current = Atomic{Int}(0)
    P.channel = RemoteChannel(() -> Channel{Bool}(total), 1)
    P.lck = ReentrantLock()

    every = max(1, div(P.total, P.nlogs))
    @async while take!(P.channel)
        Threads.lock(P.lck) do
            Threads.atomic_add!(P.current, 1)
            @info "Progress: $(P.current[]*every) / $(P.total)"
        end
    end
end
function log_log!(P::InfoProgress, i)
    every = max(1, div(P.total, P.nlogs))
    i % every == 0 && put!(P.channel, true)
end
close_log!(P::InfoProgress) = put!(P.channel, false)
