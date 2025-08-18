module Cartographer
export Chart
import Distributed: RemoteChannel
import Base.Threads: Atomic, ReentrantLock, AbstractLock

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
struct Distributed <: Backend end # ? pmap. See extension for methods

# * Logging backends
abstract type Progress end
include("InfoProgress.jl")
mutable struct ProgressLogging <: Progress # ? See extension for methods
    info::InfoProgress
    Progress::Any
end
struct Term <: Progress end # ? See extension for methods
export Term
struct NoProgress <: Progress end # ? No progress logging
export NoProgress
init_log!(P::NoProgress, N) = nothing
log_log!(P::NoProgress, i) = nothing
close_log!(P::NoProgress) = nothing

# * So for ramap we want to flatten the iterator

# * Expand inputs
export NoExpansion
struct NoExpansion end

abstract type AbstractChart end

# * User-oriented charts
struct Chart{L <: Any,
             B <: Backend,
             P <: Union{Progress, NoProgress},
             E <: Union{NoExpansion, Function}} <: AbstractChart
    backend::B
    progress::P
    expansion::E
end

function Chart{L}(backend::B, progress::P,
                  expansion::E) where {L <: Any, B <: Backend, P <: Progress,
                                       E <: Union{NoExpansion, Function}}
    Chart{L, B, P, E}(backend, progress, expansion)
end
abstract type All end # * For default behavior, all element types are considered leaves
function Chart(; leaf::Type = All,
               backend::B = Sequential(),
               progress::P = NoProgress(),
               expansion::E = NoExpansion()) where {B <: Backend, P <: Progress, E}
    Chart{leaf}(backend, progress, expansion)
end

function Chart(args...)
    kwargs = map(args) do arg
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
    Chart(; kwargs...)
end

leaf(C::Chart{L}) where {L} = L
backend(C::Chart) = C.backend
progress(C::Chart) = C.progress
expansion(C::Chart) = C.expansion
hasexpansion(C::Chart{B, P, L, E}) where {B, P, L, E} = !(E <: NoExpansion)

init_log!(C::Chart, N) = init_log!(progress(C), N) # * Specialized when defining a logger type
log_log!(C::Chart, i) = log_log!(progress(C), i)
close_log!(C::Chart) = close_log!(progress(C))

function Base.map(f, c::C, args...; kwargs...) where {C <: AbstractChart}
    throw(ArgumentError("No map method defined for Chart type $C"))
end

# * Traversal methods
function nindex(arr, idxs::Tuple)
    if isempty(idxs)
        return arr
    else
        return nindex(getindex(arr, first(idxs)), Base.tail(idxs))
    end
end
function nindices(::Type{All}, arr::AbstractArray,
                  current_path::NTuple{N, Int} where {N} = ())
    nindices(Any, arr, current_path)
end
function nindices(leaf_type::Type, arr::AbstractArray,
                  current_path::NTuple{N, Int} where {N} = ())
    indices_found = Vector{NTuple{N, Int} where N}()

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
    view(nindex(arr, idxs[1:(end - 1)]), idxs[end])
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
function _is_leaf(::Type{<:AbstractArray{T}},
                  ::Type{Union{}}) where {T <: AbstractArray}
    false
end

# * Shortcuts for type stability with common arrays, up to a few iterative depths. Can these
#   be generated?
# When the array is flat, fall back to similar
nsimilar(::Type{In}, ::Type{Out}, x::AbstractArray{<:In}) where {In, Out} = similar(x, Out)
nsimilar(::Type{All}, ::Type{Out}, x::AbstractArray) where {Out} = similar(x, Out) # Have to handle all the anys individually unfortunately

@static if VERSION < v"1.12"
    # Similar nested arrays can be inferred recursively
    function nsimilar(::Type{In}, ::Type{Out},
                      x::AbstractArray{<:AbstractArray{<:In}}) where {In, Out}
        [nsimilar(In, Out, y) for y in x]
    end
    function nsimilar(::Type{All}, ::Type{Out},
                      x::AbstractArray{<:AbstractArray}) where {Out}
        similar(x, Out)
    end

    function nsimilar(::Type{In}, ::Type{Out},
                      x::AbstractArray{<:AbstractArray{<:AbstractArray{<:In}}}) where {In,
                                                                                       Out}
        [nsimilar(In, Out, y) for y in x]
    end
    function nsimilar(::Type{All}, ::Type{Out},
                      x::AbstractArray{<:AbstractArray{<:AbstractArray}}) where {Out}
        similar(x, Out)
    end
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
    itrs
end
function expand(C::Chart{L, B, P, E}, itrs) where {L, B <: Backend, P, E}
    out = expand(expansion(C), L, itrs)
    map(eachindex(itrs)) do i
        map(Base.Fix2(getindex, i), out)
    end |> Tuple
end

function preallocate(C, f, itrs)
    itrs = expand(C, itrs) # ! Need to think about this....
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

# * Component methods
include("Expansion.jl")
include("Sequential.jl")
include("Threaded.jl")
end
