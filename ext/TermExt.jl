module TermExt
using Term
import Cartographer
import Cartographer: InfoProgress, init_log!, log_log!, close_log!
import Base.Threads: Atomic, ReentrantLock
import Distributed: RemoteChannel

const DEFAULT_TERM_PROGRESS = (; columns = :detailed, width = 92, transient = true)

function Cartographer.TermLogger(N = 0, args...; kwargs...)
    Cartographer.TermLogger(N, Term.ProgressBar(; DEFAULT_TERM_PROGRESS..., kwargs...))
end

function init_log!(P::Cartographer.TermLogger, N)
    Term.Progress.addjob!(P.Progress; N)
    Term.Progress.start!(P.Progress)
end
function log_log!(P::Cartographer.TermLogger, i)
    job = last(P.Progress.jobs)
    Term.Progress.update!(job)

    every = P.nlogs == 0 ? 1 : max(1, div(job.N, P.nlogs))
    i % every == 0 && Term.Progress.render(P.Progress)
end

function close_log!(P::Cartographer.TermLogger)
    Term.Progress.stop!(P.Progress)
end

end # module
