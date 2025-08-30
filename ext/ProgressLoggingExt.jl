module ProgressLoggingExt
import ProgressLogging as PLG
import ProgressLogging: @logmsg, Progress
import MoreMaps
import MoreMaps: InfoProgress, init_log!, log_log!, close_log!
using UUIDs
import Base.Threads: Atomic, ReentrantLock
import Distributed: RemoteChannel

function MoreMaps.ProgressLogger(args...; id = UUIDs.uuid4(), kwargs...)
    MoreMaps.ProgressLogger(MoreMaps.InfoProgress(args...),
                            PLG.Progress(id; kwargs...))
end

function init_log!(P::MoreMaps.ProgressLogger, total)
    P.info.total = total
    P.info.current = Atomic{Int}(0)
    P.info.channel = RemoteChannel(() -> Channel{Bool}(total), 1)
    P.info.lck = ReentrantLock()

    every = max(1, div(P.info.total, P.info.nlogs))
    @async while take!(P.info.channel)
        Threads.lock(P.info.lck) do
            Threads.atomic_add!(P.info.current, 1)
            progress = P.info.current[] * every / P.info.total
            @logmsg PLG.ProgressLevel P.Progress.name progress _id=P.Progress.id
        end
    end
end
log_log!(P::MoreMaps.ProgressLogger, i) = log_log!(P.info, i)

function close_log!(P::MoreMaps.ProgressLogger)
    @logmsg PLG.ProgressLevel progress="done" _id=P.Progress.id
end

end
