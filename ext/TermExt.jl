module TermExt
using Term
import MoreMaps
import MoreMaps: InfoLogger, init_log!, log_log!, close_log!
import Base.Threads: Atomic, ReentrantLock
import Distributed: RemoteChannel

const DEFAULT_TERM_PROGRESS = (; columns = :detailed, width = 92, transient = true)

"""
    TermLogger(nlogs::Int = 0; kwargs...)

A progress logger that creates rich terminal progress bars using Term.jl.

## Arguments
- `nlogs::Int`: Number of update intervals for progress rendering (default: 0, which updates every iteration)
- `kwargs...`: Additional keyword arguments passed to `Term.ProgressBar`

## Usage

```jldoctest
julia> using MoreMaps, Term

julia> P = TermLogger(5);

julia> C = Chart(P);

julia> data = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

julia> result = map(x -> (sleep(0.5); x^2), C, data); # Will display a progress bar

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

```

**Note**: Requires Term.jl to be loaded. Creates visual progress bars in the terminal with customizable
appearance. Set `nlogs = 0` for maximum update frequency, or higher values to reduce rendering overhead.
The progress bar will be transient by default (disappears when complete).
Once constructed, a re-used `TermLogger` will accumulate progress bars from subsequent maps.

See also: [`InfoLogger`](@ref), [`ProgressLogger`](@ref), [`NoProgress`](@ref), [`Chart`](@ref)
"""
function MoreMaps.TermLogger(N = 0, args...; kwargs...)
    MoreMaps.TermLogger(N, Term.ProgressBar(; DEFAULT_TERM_PROGRESS..., kwargs...))
end

function init_log!(P::MoreMaps.TermLogger, N)
    Term.Progress.addjob!(P.Progress; N)
    Term.Progress.start!(P.Progress)
end
function log_log!(P::MoreMaps.TermLogger, i)
    job = last(P.Progress.jobs)
    Term.Progress.update!(job)

    every = P.nlogs == 0 ? 1 : max(1, div(job.N, P.nlogs))
    i % every == 0 && Term.Progress.render(P.Progress)
end

function close_log!(P::MoreMaps.TermLogger)
    Term.Progress.stop!(P.Progress)
end

end # module
