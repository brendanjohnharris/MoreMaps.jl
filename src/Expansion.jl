# * Goal is the recursively take cartesian products
function expand(f::Function, ::Type{Union{}},
                itrs::Union{NTuple{N, T}, AbstractArray{T, N}}) where {N,
                                                                       T <:
                                                                       AbstractArray}
    out = Base.Splat(f)(itrs)
    return map(x -> expand(f, Union{}, x), out)
end
function expand(f::Function, ::Type{Union{}},
                itrs::Union{NTuple{N, T}, AbstractArray{T, N}}) where {N, T}
    return itrs
end
function expand(f::Function, ::Type{All},
                itrs::Union{Tuple, AbstractArray})
    return Base.Splat(f)(itrs) #|> collect
end
function expand(f::Function, ::Type{L},
                itrs::Union{NTuple{N, <:L}, AbstractArray{<:L, N}}) where {L, N}
    return itrs
end
function expand(f::Function, ::Type{L},
                itrs::Union{NTuple{N, T}, AbstractArray{T, N}}) where {L, N, T}
    out = Base.Splat(f)(itrs) #|> collect
    return map(x -> expand(f, L, x), out)
end

# * Noop to remove method ambiguity
function expand(f::Function, ::Type{MoreMaps.All},
                ::Union{AbstractArray{<:MoreMaps.All, N},
                        NTuple{N, <:MoreMaps.All}}) where {N}
    nothing
end
