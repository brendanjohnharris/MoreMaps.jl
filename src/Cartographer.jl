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
struct ProgressLogging <: Progress end # ? See extension for methods
struct Term <: Progress end # ? See extension for methods
struct NoProgress <: Progress end # ? No progress logging
init_log!(P::NoProgress, N) = nothing
log_log!(P::NoProgress, i) = nothing

# * So for ramap we want to flatten the iterator

# * Expand inputs
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
function Chart(; leaf::Type = Union{},
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

function Base.map(c::C, args...; kwargs...) where {C <: AbstractChart}
    throw(ArgumentError("No map method defined for Chart type $C"))
end

# * Traversal methods
function nindex(arr, idxs)
    if isempty(idxs)
        return arr
    end
    nindex(getindex(arr, popfirst!(idxs)), idxs)
end
function nview(arr, idxs)
    view(nindex(arr, idxs[1:(end - 1)]), idxs[end])
end

function nindices(leaf_type::Type, arr::AbstractArray,
                  current_path::Vector{Int} = Vector{Int}())
    indices_found = Vector{Vector{Int}}()

    for (i, elem) in enumerate(arr)
        new_path = vcat(current_path, i)

        if isa(elem, AbstractArray) && !isa(elem, leaf_type)
            append!(indices_found, nindices(leaf_type, elem, new_path))
        else
            push!(indices_found, new_path)
        end
    end

    return indices_found
end
function nviews(x, indices)
    return map(Base.Fix1(nview, x), indices)
end
function nviews(leaf::Type, x)
    indices = nestedindices(leaf, x)
    return nviews(x, indices), indices
end

"""
Construct a similar nested array to `x` with new leaves of type outleaf, for original leaves
of type inleaf
"""
function nsimilar(inleaf::Type, outleaf::Type, x::AbstractArray{<:AbstractArray})
    if x isa AbstractArray{<:inleaf}
        return similar(x, outleaf)
    else
        return map(x) do y
            nsimilar(inleaf, outleaf, y)
        end
    end
end
function nsimilar(inleaf::Type, outleaf::Type, x::AbstractArray) # Catches uncaught leaves
    return similar(x, outleaf)
end

# * Component methods
include("Sequential.jl")
include("Threaded.jl")
include("InfoProgress.jl")
end
