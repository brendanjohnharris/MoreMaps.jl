# * Distributed map
import Distributed: pmap
export Pmap
const PmapChart = Chart{L, B} where {L, B <: Pmap}
function Base.map(f, C::PmapChart, itrs...)
    # * Get preallocated array, with indices, and a data view
    out, idxs, xs = preallocate(C, f, itrs)

    # * Initialize logger
    init_log!(C, length(idxs))
    function g(i, x...)
        y = f(map(getindex, x)...)
        log_log!(C, i)
        return y
    end

    try # * Run loop
        ys = nviews(out, idxs)
        _ys = pmap(enumerate(zip(xs...))) do (i, xs) # Dirty copy...
            g(i, xs...)
        end
        for (i, y) in enumerate(_ys)
            @inbounds ys[i][] = y
        end
    finally # * Finalize log
        close_log!(C)
    end
    return out
end
