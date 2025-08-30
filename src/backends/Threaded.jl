# * Threaded map
export Threaded
const ThreadedChart = Chart{L, B} where {L, B <: Threaded}
function Base.map(f, C::ThreadedChart, itrs...)
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

        @static if VERSION >= v"1.11"
            Threads.@threads :greedy for i in eachindex(idxs)
                @inbounds ys[i][] = g(i, map(Base.Fix2(getindex, i), xs)...)
            end
        else
            Threads.@threads for i in eachindex(idxs)
                @inbounds ys[i][] = g(i, map(Base.Fix2(getindex, i), xs)...)
            end
        end
    finally # * Finalize log
        close_log!(C)
    end
    return out
end
