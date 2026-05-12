import Serialization: serialize, AbstractSerializer, serialize_type

export QualityLogger

const _QL_RED = "\e[31m"
const _QL_GREEN = "\e[32m"
const _QL_BRIGHT_RED = "\e[91m"
const _QL_BRIGHT_GREEN = "\e[92m"
const _QL_ORANGE = "\e[38;5;208m"
const _QL_BRIGHT_YELLOW = "\e[93m"
const _QL_CYAN = "\e[36m"
const _QL_YELLOW = "\e[33m"
const _QL_BLACK = "\e[30m"
const _QL_BRIGHT_BLUE = "\e[94m"
const _QL_DIM = "\e[2m"
const _QL_BOLD = "\e[1m"
const _QL_RESET = "\e[0m"
const _QL_BLOCK = "█"

_default_quality(y::AbstractFloat) = !isnan(y)
_default_quality(y::Number) = true
_default_quality(y::Tuple) = sum(_default_quality, y) / length(y)
_default_quality(y::AbstractArray) = sum(_default_quality, y) / length(y)
_default_quality(y) = true

_type_label(x) = string(nameof(typeof(x)))

function _chart_summary(C)
    leaf_label = string(leaf(C))
    backend_label = _type_label(backend(C))
    progress_label = _type_label(progress(C))
    expansion_label = _type_label(expansion(C))
    return "Chart(leaf=$(leaf_label), backend=$(backend_label), progress=$(progress_label), expansion=$(expansion_label))"
end

const _fmt_human_time = _format_human_time

"""
    QualityLogger(; nlogs = 0, width = 0, status_width = 20, quality = _default_quality, io = stdout)

Terminal logger that prints rows of colored blocks.

`quality(y)` may return either:
- `Bool` (`true -> 1.0`, `false -> 0.0`)
- A real-valued score, interpreted in `[0, 1]` (values are clamped)

Block color bands:
- `0.0`: black
- `(0.0, 0.25)`: red
- `[0.25, 0.5)`: orange
- `[0.5, 0.75)`: yellow
- `[0.75, 1.0)`: green
- `1.0`: blue

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
    row_index::Int = 1
    row_pos::Int = 0
    block_width::Int = 50
    started_at::Float64 = 0.0
    channel::Union{Nothing, RemoteChannel{Channel{Float64}}} = nothing
    consumer::Union{Nothing, Task} = nothing
end

function serialize(s::AbstractSerializer, P::QualityLogger)
    Serialization.serialize_cycle(s, P) && return
    Serialization.serialize_type(s, QualityLogger, true)
    for f in fieldnames(QualityLogger)
        v = getfield(P, f)
        serialize(s, f === :consumer ? nothing : v)
    end
    return
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
    if score == 0
        return :black
    elseif score == 1
        return :blue
    elseif score < 0.25
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

    return if bucket === :black
        print(io, _QL_BLACK, _QL_BLOCK, _QL_RESET)
    elseif bucket === :red
        print(io, _QL_BRIGHT_RED, _QL_BLOCK, _QL_RESET)
    elseif bucket === :orange
        print(io, _QL_ORANGE, _QL_BLOCK, _QL_RESET)
    elseif bucket === :yellow
        print(io, _QL_BRIGHT_YELLOW, _QL_BLOCK, _QL_RESET)
    elseif bucket === :blue
        print(io, _QL_BRIGHT_BLUE, _QL_BLOCK, _QL_RESET)
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

    return if P.use_color
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

    return if P.use_color
        print(io, _QL_DIM, repeat(" ", left_pad), bracket, _QL_RESET, '\n')
    else
        print(io, repeat(" ", left_pad), bracket, '\n')
    end
end

function _ql_print_legend!(io::IO, P::QualityLogger)
    entries = (
        (:black, "0%"),
        (:red, "<25%"),
        (:orange, "<50%"),
        (:yellow, "<75%"),
        (:green, "<100%"),
        (:blue, "100%"),
    )
    gap = 2
    legend_width = sum(length(label) for (_, label) in entries) + gap * (length(entries) - 1)
    bracket_span = max(P.block_width, 1) + 2
    bracket_left = max(P.status_width - 1, 0)
    left_pad = if legend_width <= bracket_span
        bracket_left + div(bracket_span - legend_width, 2)
    else
        max(0, bracket_left + bracket_span - legend_width)
    end
    pad_str = repeat(" ", left_pad)

    print(io, pad_str)
    for (i, (bucket, label)) in enumerate(entries)
        for _ in 1:length(label)
            _ql_print_block!(io, bucket, P.use_color)
        end
        i < length(entries) && print(io, repeat(" ", gap))
    end
    print(io, '\n')
    print(io, pad_str)
    for (i, (_, label)) in enumerate(entries)
        if P.use_color
            print(io, _QL_DIM, label, _QL_RESET)
        else
            print(io, label)
        end
        i < length(entries) && print(io, repeat(" ", gap))
    end
    print(io, '\n')
    return
end

function _ql_print_block_bracket_bottom!(io::IO, P::QualityLogger)
    w = max(P.block_width, 1)
    bracket = "└" * repeat("─", w) * "┘"
    left_pad = max(P.status_width - 1, 0)

    return if P.use_color
        print(io, _QL_DIM, repeat(" ", left_pad), bracket, _QL_RESET, '\n')
    else
        print(io, repeat(" ", left_pad), bracket, '\n')
    end
end

function _print_prefix(P::QualityLogger)
    return _ql_print_prefix!(_ql_active_io(P), P)
end

function _ql_consume!(P::QualityLogger)
    io = _ql_active_io(P)
    pending = IOBuffer()
    every = _ql_every(P)
    ch = P.channel::RemoteChannel{Channel{Float64}}
    while true
        score = take!(ch)
        if isnan(score)
            chunk = String(take!(pending))
            !isempty(chunk) && print(io, chunk)
            if P.done > 0
                print(io, '\n')
                _ql_print_block_bracket_bottom!(io, P)
            end
            print(io, '\n')
            flush(io)
            return
        end

        bucket = _ql_bucket(score)
        P.done += 1
        P.row_pos += 1

        _ql_print_block!(pending, bucket, P.use_color)

        if P.row_pos >= P.block_width && P.done < P.total
            P.row_index += 1
            P.row_pos = 0
            print(pending, '\n')
            _ql_print_prefix!(pending, P)
        end

        if (P.done == P.total) || (P.done % every == 0)
            chunk = String(take!(pending))
            !isempty(chunk) && print(io, chunk)
            flush(io)
        end
    end
    return
end

function init_log!(P::QualityLogger, total, C = nothing)
    P.total = total
    P.done = 0
    P.row_index = 1
    P.row_pos = 0
    P.block_width = P.width > 0 ? P.width : min(floor(Int, sqrt(max(total, 1)) * 2), 50)
    P.started_at = time()
    P.channel = RemoteChannel(() -> Channel{Float64}(max(total, 1) + 1), 1)

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
    _ql_print_legend!(io, P)
    _ql_print_block_bracket!(io, P)
    _ql_print_prefix!(io, P)
    flush(io)

    return P.consumer = @async _ql_consume!(P)
end

function log_log!(P::QualityLogger, i, y)
    q = try
        P.quality(y)
    catch
        false
    end
    return put!(P.channel::RemoteChannel{Channel{Float64}}, _ql_score(q))
end

log_log!(P::QualityLogger, i) = put!(P.channel::RemoteChannel{Channel{Float64}}, _ql_score(P.quality(nothing)))

function close_log!(P::QualityLogger)
    put!(P.channel::RemoteChannel{Channel{Float64}}, NaN)
    consumer = P.consumer
    consumer === nothing || wait(consumer::Task)
    return
end
