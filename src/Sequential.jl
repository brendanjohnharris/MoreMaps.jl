# * Regular map
const SequentialChart = Chart{L, B, P, E} where {L, B <: Sequential, P, E}
function Base.map(C::SequentialChart, f::Function, itrs...)
    # * Generate leaf iterator
    idxs = nindices(leaf(C), first(itrs))
    xs = map(Base.Fix2(nviews, idxs), itrs)

    # * Preallocate output
    T = typejoin(Base.return_types(f, map(eltype ∘ eltype ∘ first, xs))...)
    out = nsimilar(leaf(C), T, first(itrs))

    # * Initialize logger
    init_log!(C, length(idxs))
    function g(i, x...)
        y = f(map(getindex, x)...)
        log_log!(C, i)
        return y
    end

    # * Run loop
    res = @sync Base.map(g, eachindex(idxs), xs...)

    # * Collect results
    map(nviews(out, idxs), res) do y, x
        @inbounds y .= x
    end
    return out
end
