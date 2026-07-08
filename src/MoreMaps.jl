module MoreMaps
export Chart
import Distributed: RemoteChannel
import Base.Threads: Atomic, ReentrantLock, AbstractLock
using Serialization
import Distributed: myid

# Must have functionality:
# - Option to thread the map
# - Option to distribute the map over workers (pmap)
# - Option to supply a leaf type and map recursively
# - ProgressLogging and Term backend for progress bar
# - Option to map over cartesian product of inputs

# * Interface
# * A Chart is characterized by a set of Type options/traits

# * Distributed backends
abstract type Backend end
struct Sequential <: Backend end # ? Regular sequential map
struct Threaded <: Backend end # ? Threads.@threads
struct Pmap <: Backend end
struct Daggermap{O <: NamedTuple} <: Backend
    options::O # Forwarded to Dagger.Options
    batchsize::Int # Elements per Dagger task; 0 = auto
end
Daggermap(; batchsize::Int = 0, kwargs...) = Daggermap(NamedTuple(kwargs), batchsize)
export Daggermap

# * Logging backends
abstract type Progress end

# Loggers that ship per-element events over a RemoteChannel to a driver-side consumer Task.
# Concrete subtypes are mutable with fields channel::Union{Nothing, RemoteChannel{Channel{T}}}
# and consumer::Union{Nothing, Task}.
abstract type ChannelProgress <: Progress end

const _CHANNEL_BUFFER = 256 # Bounded; producers block briefly under burst, consumer drains

function _open_channel!(P::ChannelProgress, ::Type{T}, buffer::Int = _CHANNEL_BUFFER) where {T}
    return P.channel = RemoteChannel(() -> Channel{T}(buffer), 1)
end

function _close_consumer!(P::ChannelProgress, sentinel) # in-band close signal, then drain
    put!(P.channel::RemoteChannel, sentinel)
    c = P.consumer
    c === nothing || wait(c::Task)
    return
end

# Tasks are not serializable; null the consumer when shipping a logger to workers.
function Serialization.serialize(s::Serialization.AbstractSerializer, P::T) where {T <: ChannelProgress}
    Serialization.serialize_cycle(s, P) && return
    Serialization.serialize_type(s, T, true)
    for f in fieldnames(T)
        Serialization.serialize(s, f === :consumer ? nothing : getfield(P, f))
    end
    return
end

_progress_every(total::Int, nlogs::Int) = nlogs <= 0 ? 1 : max(1, div(total, nlogs))

function _format_human_time(seconds::Real)
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

include("LogLogger.jl")
include("QualityLogger.jl")
include("CallbackLogger.jl")
include("CompositeLogger.jl")
mutable struct ProgressLogger <: Progress # ? See extension for methods
    info::LogLogger
    Progress::Any
end
export ProgressLogger
mutable struct TermLogger <: ChannelProgress # ? See extension for methods
    nlogs::Int
    Progress::Any
    channel::Union{Nothing, RemoteChannel{Channel{Bool}}}
    consumer::Union{Nothing, Task}
end
export TermLogger

"""
    NoProgress()

The default progress logger that performs no logging.
"""
struct NoProgress <: Progress end
export NoProgress
init_log!(P::NoProgress, N) = nothing
init_log!(P::NoProgress, N, C) = nothing
log_log!(P::NoProgress, i) = nothing
close_log!(P::NoProgress) = nothing
log_log!(P::Progress, i, y) = log_log!(P, i) # Compatibility
init_log!(P::Progress, N, C) = init_log!(P, N) # Compatibility

# * So for ramap we want to flatten the iterator

# * Expand inputs
export NoExpansion
struct NoExpansion end

abstract type AbstractChart end

# * User-oriented charts
"""

"""
struct Chart{
        L <: Any,
        B <: Backend,
        P <: Union{Progress, NoProgress},
        E <: Union{NoExpansion, Function},
    } <: AbstractChart
    backend::B
    progress::P
    expansion::E
end

function Chart{L}(
        backend::B, progress::P,
        expansion::E
    ) where {
        L <: Any, B <: Backend, P <: Progress,
        E <: Union{NoExpansion, Function},
    }
    return Chart{L, B, P, E}(backend, progress, expansion)
end
abstract type All end # * For default behavior, all element types are considered leaves
function Chart(;
        leaf::Type = All,
        backend::B = Sequential(),
        progress::P = NoProgress(),
        expansion::E = NoExpansion()
    ) where {B <: Backend, P <: Progress, E}
    return Chart{leaf}(backend, progress, expansion)
end

function Chart(args...)
    kwargs = Base.map(args) do arg
        if arg isa Backend
            :backend => arg
        elseif arg isa Progress
            :progress => arg
        elseif arg isa Type
            :leaf => arg
        else
            :expansion => arg
        end
    end
    return Chart(; kwargs...)
end

leaf(C::Chart{L}) where {L} = L
backend(C::Chart) = C.backend
progress(C::Chart) = C.progress
expansion(C::Chart) = C.expansion
hasexpansion(C::Chart{L, B, P, E}) where {L, B, P, E} = !(E <: NoExpansion)

init_log!(C::Chart, N) = init_log!(progress(C), N, C) # * Specialized when defining a logger type
log_log!(C::Chart, args...) = log_log!(progress(C), args...)
close_log!(C::Chart) = close_log!(progress(C))

# * Traversal methods
function nindex(arr, idxs::Tuple)
    if isempty(idxs)
        return arr
    else
        return nindex(getindex(arr, first(idxs)), Base.tail(idxs))
    end
end
function nindices(
        ::Type{All}, arr::AbstractArray,
        current_path::NTuple{N, Int} where {N} = ()
    )
    return nindices(Any, arr, current_path)
end
function nindices(
        leaf_type::Type, arr::AbstractArray,
        current_path::NTuple{N, Int} where {N} = ()
    )
    indices_found = Vector{NTuple{N, Int} where {N}}()

    for (i, elem) in enumerate(arr)
        new_path = (current_path..., i)

        if isa(elem, AbstractArray) && !isa(elem, leaf_type)
            append!(indices_found, nindices(leaf_type, elem, new_path))
        else
            push!(indices_found, new_path)
        end
    end

    return indices_found
end
function nview(arr, idxs::Tuple)
    return view(nindex(arr, idxs[1:(end - 1)]), idxs[end])
end
function nviews(x, indices)
    return map(Base.Fix1(nview, x), indices)
end

function sniff_leaf(::Type{L}, ::Type{T}) where {L, T}
    if _is_leaf(T, L)
        return true
    elseif T <: AbstractArray
        return sniff_leaf(L, eltype(T))
    else
        return false
    end
end

"""
Construct a similar nested array to `x` with new leaves of type outleaf, for original leaves of type inleaf
"""
function nsimilar(inleaf::Type{In}, outleaf::Type{Out}, x::T) where {In, Out, T}
    if _is_leaf(T, In)
        return similar(x, outleaf)
    else
        return map(y -> nsimilar(inleaf, outleaf, y), x)
    end
end

# Helper to determine if this is a leaf array at compile time
_is_leaf(::Type{<:AbstractArray{E}}, inleaf::Type) where {E} = E <: inleaf
_is_leaf(::Type, inleaf::Type) = false

# Handle inleaf=Union{}
_is_leaf(::Type{<:AbstractArray{T}}, ::Type{Union{}}) where {T} = true
function _is_leaf(
        ::Type{<:AbstractArray{T}},
        ::Type{Union{}}
    ) where {T <: AbstractArray}
    return false
end

# * Shortcuts for type stability with common arrays, up to a few iterative depths. Can these
#   be generated?
# When the array is flat, fall back to similar
nsimilar(::Type{In}, ::Type{Out}, x::AbstractArray{<:In}) where {In, Out} = similar(x, Out)
nsimilar(::Type{All}, ::Type{Out}, x::AbstractArray) where {Out} = similar(x, Out) # Have to handle all the anys individually unfortunately

# Similar nested arrays can be inferred recursively
function nsimilar(
        ::Type{In}, ::Type{Out},
        x::AbstractArray{<:AbstractArray{<:In}}
    ) where {In, Out}
    return [nsimilar(In, Out, y) for y in x]
end
function nsimilar(
        ::Type{All}, ::Type{Out},
        x::AbstractArray{<:AbstractArray}
    ) where {Out}
    return similar(x, Out)
end

function nsimilar(
        ::Type{In}, ::Type{Out},
        x::AbstractArray{<:AbstractArray{<:AbstractArray{<:In}}}
    ) where {
        In,
        Out,
    }
    return [nsimilar(In, Out, y) for y in x]
end
function nsimilar(
        ::Type{All}, ::Type{Out},
        x::AbstractArray{<:AbstractArray{<:AbstractArray}}
    ) where {Out}
    return similar(x, Out)
end

# # * Handle the Union{} case
# function nsimilar(::Type{Union{}}, ::Type{Out},
#                   x::AbstractArray{<:AbstractArray}) where {Out}
#     y = similar(x, eltype(x))
#     map!(x -> nsimilar(Union{}, Out, x), y, x)
# end
# function nsimilar(::Type{Union{}}, ::Type{Out}, x::AbstractArray) where {Out}
#     similar(x, Out)
# end

# nsimilar(::Type{Union{}}, ::Type{T}, x::AbstractArray{T}) where {T} = deepcopy(x)

# # Dispatch for validated leaf arrays
# function nsimilar(::Val{true}, inleaf::Type{In}, outleaf::Type{Out},
#                   x::AbstractArray{E}) where {In, Out, E}
#     return similar(x, outleaf)
# end

# # Dispatch for non-leaf arrays
# function nsimilar(::Val{false}, inleaf::Type{In}, outleaf::Type{Out},
#                   x::AbstractArray) where {In, Out}
#     return map(y -> nsimilar(inleaf, outleaf, y), x)
# end

# * Expansions
function expand(C::Chart{L, B, P, E}, itrs) where {L, B <: Backend, P, E <: NoExpansion}
    return itrs
end
function expand(C::Chart{L, B, P, E}, itrs) where {L, B <: Backend, P, E}
    out = expand(expansion(C), L, itrs)
    return map(eachindex(itrs)) do i
        map(Base.Fix2(getindex, i), out)
    end |> Tuple
end

function preallocate(C, f, itrs)
    itrs = expand(C, itrs)
    # * Generate leaf iterator
    idxs = nindices(leaf(C), first(itrs))
    xs = map(Base.Fix2(nviews, idxs), itrs)

    # * Preallocate output
    if leaf(C) === Union{} # This option is NOT type stable... yet.
        T = Core.Compiler.return_type(f, Tuple{map(eltype ∘ eltype, xs)...})
    elseif leaf(C) === All # Stable; regular map
        T = Core.Compiler.return_type(f, map(first, itrs) |> typeof)
    else # Stable
        T = Core.Compiler.return_type(f, NTuple{length(itrs), leaf(C)})
    end

    if leaf(C) !== All && !sniff_leaf(leaf(C), typeof(first(itrs)))
        throw(ArgumentError("Leaf type $(leaf(C)) not found in input of type $(typeof(first(itrs)))"))
    end
    out = nsimilar(leaf(C), T, first(itrs))

    return out, idxs, xs
end

function _map(f, c::C, args...; kwargs...) where {C <: AbstractChart}
    throw(ArgumentError("No map method defined for Chart type $C"))
end

"""
    _run_map(kernel!, f, C, itrs)

Shared scaffolding for `_map` implementations. Preallocates the output, initializes the
logger, builds the per-element closure `g` (which calls `f` and emits a progress log), then
invokes `kernel!(g, ys, idxs, xs)` where `ys = nviews(out, idxs)` is the writeable view of
output leaves. Backends only need to provide `kernel!`, which drives `g` over `eachindex(idxs)`
and writes results into `ys`. Logger lifecycle and exception safety are handled here.
"""
function _run_map(kernel!::F, f::G, C::AbstractChart, itrs::Tuple) where {F, G}
    out, idxs, xs = preallocate(C, f, itrs)
    init_log!(C, length(idxs))
    g = (i, x...) -> begin
        y = f(map(getindex, x)...)
        log_log!(C, i, y)
        return y
    end
    try
        ys = nviews(out, idxs)
        kernel!(g, ys, idxs, xs)
    finally
        close_log!(C)
    end
    return out
end


function Base.map(f, c::C, itrs...) where {C <: AbstractChart}
    return _map(f, c, itrs...)
end

function Base.map(f, c::C, args...; kwargs...) where {C <: Union{Progress, Backend}}
    return Base.map(f, Chart(c), args...; kwargs...)
end

function Base.map(f, c::C, tp::Tuple{Vararg{Any, N}}, tps...) where {N, C <: AbstractChart}
    itr = collect(tp)
    itrs = map(collect, tps)
    out = map(f, c, itr, itrs...)
    return NTuple{N, eltype(out)}(out)
end

function Base.map(
        f, c::C, nt::NamedTuple{names},
        nts::NamedTuple...
    ) where {names, C <: AbstractChart}
    if !Base.same_names(nt, nts...)
        throw(ArgumentError("Named tuple names do not match."))
    end
    itr = values(nt)
    itrs = map(values, nts)
    return map(f, c, itr, itrs...) |> NamedTuple{names}
end

# * Component methods
include("Expansion.jl")
include("backends/Sequential.jl")
include("backends/Threaded.jl")
include("backends/Pmap.jl")


# * Test utilities
function cpu_intensive_task(n)
    result = 0.0
    for i in 1:n
        result += sin(i) * cos(i) * sqrt(i)
    end
    return (result = result, worker_id = myid())
end

end
