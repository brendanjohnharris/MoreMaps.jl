module DaggerExt
using Distributed
import Cartographer: Daggermap, init_log!, log_log!, close_log!, Chart, backend,
                     preallocate, nviews
using Dagger
const DaggermapChart = Chart{L, B} where {L, B <: Daggermap}

function Base.map(f, C::DaggermapChart, itrs...)
    options = backend(C).options
    # * Get preallocated array, with indices, and a data view
    out, idxs, xs = preallocate(C, f, itrs)

    # * Initialize logger
    init_log!(C, length(idxs))
    function g(i, x...)
        y = f(map(getindex, x)...)
        log_log!(C, i)
        return y
    end

    # * Run loop
    ys = nviews(out, idxs)

    _ys = map(eachindex(idxs)) do i
        x = map(Base.Fix2(getindex, i), xs)
        Dagger.@spawn options... g(i, x...)
    end

    for (i, y) in enumerate(fetch.(_ys))
        @inbounds ys[i][] = y
    end

    # * Finalize log
    close_log!(C)
    return out
end
end
