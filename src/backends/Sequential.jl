# * Regular map
export Sequential
const SequentialChart = Chart{L, B, P, E} where {L, B <: Sequential, P, E}
function Base.map(f, C::SequentialChart, itrs...)
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
        res = @sync Base.map(g, eachindex(idxs), xs...)

        # * Collect results
        map(nviews(out, idxs), res) do y, x
            @inbounds y[] = x
        end

    finally # * Finalize log
        close_log!(C)
    end
    return out
end
