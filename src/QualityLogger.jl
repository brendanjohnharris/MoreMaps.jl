export QualityLogger

const _QL_RED = "\e[31m"
const _QL_GREEN = "\e[32m"
const _QL_BRIGHT_RED = "\e[91m"
const _QL_BRIGHT_GREEN = "\e[92m"
const _QL_ORANGE = "\e[38;5;208m"
const _QL_BRIGHT_YELLOW = "\e[93m"
const _QL_CYAN = "\e[36m"
const _QL_YELLOW = "\e[33m"
const _QL_DIM = "\e[2m"
const _QL_BOLD = "\e[1m"
const _QL_RESET = "\e[0m"
const _QL_BLOCK = "█"

_default_quality(y) = !_has_nan(y)

_has_nan(y::AbstractFloat) = isnan(y)
_has_nan(y::Number) = false
_has_nan(y::Tuple) = sum(_has_nan, y) / length(y)
_has_nan(y::AbstractArray) = sum(_has_nan, y) / length(y)
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
    QualityLogger(; nlogs = 0, width = 0, status_width = 20, quality = _default_quality, io = stdout)

Terminal logger that prints rows of colored blocks.

`quality(y)` may return either:
- `Bool` (`true -> 1.0`, `false -> 0.0`)
- A real-valued score, interpreted in `[0, 1]` (values are clamped)

Block color bands:
- `[0.0, 0.25)`: red
- `[0.25, 0.5)`: orange
- `[0.5, 0.75)`: yellow
- `[0.75, 1.0]`: green

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
    red_count::Int = 0
    orange_count::Int = 0
    yellow_count::Int = 0
    green_count::Int = 0
    row_index::Int = 1
    row_pos::Int = 0
    block_width::Int = 50
    started_at::Float64 = 0.0
    pending::IOBuffer = IOBuffer()
    lck::AbstractLock = ReentrantLock()
end

_ql_every(P::QualityLogger) = P.nlogs == 0 ? 1 : max(1, div(max(P.total, 1), P.nlogs))

function _ql_score(x)
    if x isa Bool
        return x ? 1.0 : 0.0
    elseif x isa Real
        y = float(x)
        return isnan(y) ? 0.0 : clamp(y, 0.0, 1.0)
    else
        return 0.0
    end
end

function _ql_bucket(score::Real)
    if score < 0.25
        return :red
    elseif score < 0.5
        return :orange
    elseif score < 0.75
        return :yellow
    else
        return :green
    end
end

function _ql_print_block!(io::IO, bucket::Symbol, use_color::Bool)
    if !use_color
        print(io, _QL_BLOCK)
        return
    end

    if bucket === :red
        print(io, _QL_BRIGHT_RED, _QL_BLOCK, _QL_RESET)
    elseif bucket === :orange
        print(io, _QL_ORANGE, _QL_BLOCK, _QL_RESET)
    elseif bucket === :yellow
        print(io, _QL_BRIGHT_YELLOW, _QL_BLOCK, _QL_RESET)
    else
        print(io, _QL_BRIGHT_GREEN, _QL_BLOCK, _QL_RESET)
    end
end

function _ql_active_io(P::QualityLogger)
    try
        return isopen(P.io) ? P.io : stdout
    catch
        return stdout
    end
end

function _ql_flush_pending!(P::QualityLogger, io::IO)
    chunk = String(take!(P.pending))
    isempty(chunk) && return
    print(io, chunk)
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

function _ql_print_block_bracket!(io::IO, P::QualityLogger)
    w = max(P.block_width, 1)
    bracket = "┌" * repeat("─", w) * "┐"
    left_pad = max(P.status_width - 1, 0)

    if P.use_color
        print(io, _QL_DIM, repeat(" ", left_pad), bracket, _QL_RESET, '\n')
    else
        print(io, repeat(" ", left_pad), bracket, '\n')
    end
end

function _ql_print_block_bracket_bottom!(io::IO, P::QualityLogger)
    w = max(P.block_width, 1)
    bracket = "└" * repeat("─", w) * "┘"
    left_pad = max(P.status_width - 1, 0)

    if P.use_color
        print(io, _QL_DIM, repeat(" ", left_pad), bracket, _QL_RESET, '\n')
    else
        print(io, repeat(" ", left_pad), bracket, '\n')
    end
end

function _print_prefix(P::QualityLogger)
    _ql_print_prefix!(_ql_active_io(P), P)
end

function init_log!(P::QualityLogger, total, C = nothing)
    P.total = total
    P.done = 0
    P.red_count = 0
    P.orange_count = 0
    P.yellow_count = 0
    P.green_count = 0
    P.row_index = 1
    P.row_pos = 0
    P.block_width = P.width > 0 ? P.width : min(floor(Int, sqrt(max(total, 1)) * 2), 50)
    P.started_at = time()
    P.pending = IOBuffer()
    P.lck = ReentrantLock()

    Threads.lock(P.lck) do
        io = _ql_active_io(P)
        if !isnothing(C)
            print(io, "N=$(total) with ")
            if P.use_color
                print(io, _QL_DIM, _chart_summary(C), _QL_RESET)
            else
                print(io, _chart_summary(C))
            end
            print(io, '\n')
        end
        _ql_print_block_bracket!(io, P)
        _ql_print_prefix!(io, P)
        flush(io)
    end
end

function log_log!(P::QualityLogger, i, y)
    Threads.lock(P.lck) do
        q = try
            P.quality(y)
        catch
            false
        end
        score = _ql_score(q)
        bucket = _ql_bucket(score)

        P.done += 1
        P.row_pos += 1

        if bucket === :red
            P.red_count += 1
        elseif bucket === :orange
            P.orange_count += 1
        elseif bucket === :yellow
            P.yellow_count += 1
        else
            P.green_count += 1
        end

        _ql_print_block!(P.pending, bucket, P.use_color)

        if P.row_pos >= P.block_width && P.done < P.total
            P.row_index += 1
            P.row_pos = 0
            print(P.pending, '\n')
            _ql_print_prefix!(P.pending, P)
        end

        should_flush = (P.done == P.total) || (P.done % _ql_every(P) == 0)
        if should_flush
            io = _ql_active_io(P)
            _ql_flush_pending!(P, io)
            flush(io)
        end
    end
end

log_log!(P::QualityLogger, i) = log_log!(P, i, nothing)

function close_log!(P::QualityLogger)
    Threads.lock(P.lck) do
        io = _ql_active_io(P)
        _ql_flush_pending!(P, io)
        if P.done > 0
            print(io, '\n')
            _ql_print_block_bracket_bottom!(io, P)
        end
        print(io, _QL_BOLD)
        print(io, rpad("summary", P.status_width))
        if P.use_color
            print(io, _QL_DIM, "done=", _QL_RESET)
            print(io, "$(P.done)/$(P.total) ")
            print(io, _QL_BRIGHT_RED, "red=$(P.red_count) ", _QL_RESET)
            print(io, _QL_ORANGE, "orange=$(P.orange_count) ", _QL_RESET)
            print(io, _QL_BRIGHT_YELLOW, "yellow=$(P.yellow_count) ", _QL_RESET)
            print(io, _QL_BRIGHT_GREEN, "green=$(P.green_count)", _QL_RESET)
        else
            print(io,
                  "done=$(P.done)/$(P.total) red=$(P.red_count) orange=$(P.orange_count) yellow=$(P.yellow_count) green=$(P.green_count)")
        end
        print(io, _QL_RESET)
        print(io, "\n\n")
        flush(io)
    end
end
