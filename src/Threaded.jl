# * Threaded map
const ThreadedChart = Chart{L, B} where {L, B <: Threaded}

function Base.map(C::ThreadedChart, f, As...)
    T = typejoin(Base.return_types(f, Base.eltype.(As))...)
    out = similar(first(As), T)
    init_log!(C, length(out))
    Threads.@threads :greedy for i in eachindex(out)
        @inbounds out[i] = f(map(Base.Fix2(getindex, i), As)...)
        log_log!(C, i)
    end
    return out
end
