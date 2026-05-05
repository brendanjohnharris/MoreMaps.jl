export QualityLogger

const _QL_RED = "\e[31m"
const _QL_GREEN = "\e[32m"
const _QL_BRIGHT_RED = "\e[91m"
const _QL_BRIGHT_GREEN = "\e[92m"
const _QL_CYAN = "\e[36m"
const _QL_YELLOW = "\e[33m"
const _QL_DIM = "\e[2m"
const _QL_BOLD = "\e[1m"
const _QL_RESET = "\e[0m"
const _QL_BLOCK = "█"

_default_quality(y) = !_has_nan(y)

_has_nan(y::AbstractFloat) = isnan(y)
_has_nan(y::Number) = false
_has_nan(y::Tuple) = any(_has_nan, y)
_has_nan(y::AbstractArray) = any(_has_nan, y)
_has_nan(y) = false

_type_label(x) = string(nameof(typeof(x)))

function _chart_summary(C)
    leaf_label = string(leaf(C))
    backend_label = _type_label(backend(C))
    progress_label = _type_label(progress(C))
    expansion_label = _type_label(expansion(C))
    "Chart(leaf=$(leaf_label), backend=$(backend_label), progress=$(progress_label), expansion=$(expansion_label))"
end

function _fmt_human_time(seconds::Real)
    t = max(0.0, float(seconds))
    if t < 60
        return "$(round(Int, t))s"
    elseif t < 3600
        return "$(round(Int, t / 60))m"
    elseif t < 86400
        return "$(round(Int, t / 3600))h"
    else
        return "$(round(Int, t / 86400))d"
    end
end

"""
    QualityLogger(; nlogs = 10, width = 0, status_width = 20, quality = _default_quality, io = stdout)

Terminal logger that prints rows of colored blocks.

- Green block: `quality(y) == true`
- Red block: `quality(y) == false`

If `width == 0`, row width defaults to `max(floor(Int, sqrt(total)), 50)` at runtime.
The first `status_width` characters of each row are reserved for row number + ETA.
Set `nlogs = 0` to flush every update, or a positive value to flush at that granularity.
"""
Base.@kwdef mutable struct QualityLogger <: Progress
    nlogs::Int = 0
    width::Int = 0
    status_width::Int = 20
    quality::Function = _default_quality
    io::IO = stdout
    use_color::Bool = true

    total::Int = 0
    done::Int = 0
    passed::Int = 0
    failed::Int = 0
    row_index::Int = 1
    row_pos::Int = 0
    block_width::Int = 50
    started_at::Float64 = 0.0
    pending::IOBuffer = IOBuffer()
    lck::AbstractLock = ReentrantLock()
end

_ql_every(P::QualityLogger) = P.nlogs == 0 ? 1 : max(1, div(max(P.total, 1), P.nlogs))

function _ql_flush_pending!(P::QualityLogger)
    chunk = String(take!(P.pending))
    isempty(chunk) && return
    print(P.io, chunk)
end

function _ql_print_prefix!(io::IO, P::QualityLogger)
    elapsed_s = time() - P.started_at
    total_est_s = if P.done == 0
        "?"
    else
        rate = P.done / max(elapsed_s, eps())
        total_est = P.total / max(rate, eps())
        _fmt_human_time(total_est)
    end

    pct = P.total == 0 ? 0 : round(Int, 100 * P.done / P.total)
    prefix_plain = "$(P.row_index)/$(cld(P.total, P.block_width))  $(pct)%  $(_fmt_human_time(elapsed_s))/$total_est_s"

    if P.use_color
        print(io, _QL_CYAN, _QL_BOLD)
        print(io, "$(P.row_index)/$(cld(P.total, P.block_width))")
        print(io, _QL_RESET, "  ")
        print(io, _QL_DIM, "$(pct)%", _QL_RESET, "  ")
        print(io, _QL_YELLOW, "$(_fmt_human_time(elapsed_s))/$total_est_s", _QL_RESET)
        pad = max(0, P.status_width - ncodeunits(prefix_plain))
        print(io, repeat(" ", pad))
    else
        print(io, rpad(prefix_plain, P.status_width))
    end
end

function _print_prefix(P::QualityLogger)
    _ql_print_prefix!(P.io, P)
end

function init_log!(P::QualityLogger, total)
    P.total = total
    P.done = 0
    P.passed = 0
    P.failed = 0
    P.row_index = 1
    P.row_pos = 0
    P.block_width = P.width > 0 ? P.width : max(floor(Int, sqrt(max(total, 1))), 50)
    P.started_at = time()
    P.pending = IOBuffer()
    P.lck = ReentrantLock()

    Threads.lock(P.lck) do
        _print_prefix(P)
        flush(P.io)
    end
end

function init_log!(P::QualityLogger, total, C)
    P.total = total
    P.done = 0
    P.passed = 0
    P.failed = 0
    P.row_index = 1
    P.row_pos = 0
    P.block_width = P.width > 0 ? P.width : max(floor(Int, sqrt(max(total, 1))), 50)
    P.started_at = time()
    P.pending = IOBuffer()
    P.lck = ReentrantLock()

    Threads.lock(P.lck) do
        print(P.io, "N=$(total) with ")
        if P.use_color
            print(P.io, _QL_DIM, _chart_summary(C), _QL_RESET)
        else
            print(P.io, _chart_summary(C))
        end
        print(P.io, '\n')
        _print_prefix(P)
        flush(P.io)
    end
end

function log_log!(P::QualityLogger, i, y)
    Threads.lock(P.lck) do
        ok = try
            P.quality(y)
        catch
            false
        end

        P.done += 1
        P.row_pos += 1
        if ok
            P.passed += 1
            P.use_color ? print(P.pending, _QL_BRIGHT_GREEN, _QL_BLOCK, _QL_RESET) :
            print(P.pending, _QL_BLOCK)
        else
            P.failed += 1
            P.use_color ? print(P.pending, _QL_BRIGHT_RED, _QL_BLOCK, _QL_RESET) :
            print(P.pending, _QL_BLOCK)
        end

        if P.row_pos >= P.block_width && P.done < P.total
            P.row_index += 1
            P.row_pos = 0
            print(P.pending, '\n')
            _ql_print_prefix!(P.pending, P)
        end

        should_flush = (P.done == P.total) || (P.done % _ql_every(P) == 0)
        if should_flush
            _ql_flush_pending!(P)
            flush(P.io)
        end
    end
end

log_log!(P::QualityLogger, i) = log_log!(P, i, nothing)

function close_log!(P::QualityLogger)
    Threads.lock(P.lck) do
        _ql_flush_pending!(P)
        if P.done > 0
            print(P.io, '\n')
        end
        print(P.io, _QL_BOLD)
        print(P.io, rpad("summary", P.status_width))
        if P.use_color
            print(P.io, _QL_DIM, "done=", _QL_RESET)
            print(P.io, "$(P.done)/$(P.total) ")
            print(P.io, _QL_BRIGHT_GREEN, "ok=$(P.passed) ", _QL_RESET)
            print(P.io, _QL_BRIGHT_RED, "fail=$(P.failed)", _QL_RESET)
        else
            print(P.io, "done=$(P.done)/$(P.total) ok=$(P.passed) fail=$(P.failed)")
        end
        print(P.io, _QL_RESET)
        print(P.io, "\n\n")
        flush(P.io)
    end
end
