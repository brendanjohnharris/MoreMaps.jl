export InfoProgress
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
