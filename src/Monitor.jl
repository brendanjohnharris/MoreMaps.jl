export Monitor

"""
    Monitor()

A progress component that cheaply records resource usage for each map: two clock and GC
snapshots per job, nothing per element. Occupies the Chart's progress slot; combine with a
real logger via [`CompositeLogger`](@ref).

After a map, the fields hold the last job's stats:

- `n`: number of elements mapped
- `time`: wall-clock seconds
- `bytes`: bytes allocated (GC-tracked)
- `allocs`: number of allocations
- `gctime`: seconds spent in garbage collection
- `backend`: the backend instance that ran the job

## Usage

```jldoctest
julia> using MoreMaps

julia> M = Monitor();

julia> map(x -> x^2, Chart(M), [1, 2, 3]);

julia> M.n
3

julia> M.time >= 0
true
```

**Note**: For distributed backends (`Pmap`, `Daggermap`), `bytes`, `allocs`, and `gctime`
cover the driver process only; worker allocations are not visible. `time` and `n` are
always faithful.

See also: [`CompositeLogger`](@ref), [`MoreMaps.Chart`](@ref)
"""
mutable struct Monitor <: Progress
    n::Int
    time::Float64
    bytes::Int
    allocs::Int
    gctime::Float64
    backend::Any
    _t0::Float64
    _gc0::Base.GC_Num
end
Monitor() = Monitor(0, 0.0, 0, 0, 0.0, nothing, 0.0, Base.gc_num())

function init_log!(M::Monitor, total, C = nothing)
    M.n = total
    M.backend = C === nothing ? nothing : backend(C)
    M._gc0 = Base.gc_num()
    M._t0 = time()
    return M
end
log_log!(M::Monitor, i) = nothing # Zero per-element cost
log_log!(M::Monitor, i, y) = nothing

function close_log!(M::Monitor)
    M.time = time() - M._t0
    d = Base.GC_Diff(Base.gc_num(), M._gc0)
    M.bytes = d.allocd
    M.allocs = Base.gc_alloc_count(d)
    M.gctime = d.total_time / 1.0e9
    return
end

pertime(M::Monitor) = M.time / max(M.n, 1) # Seconds per element

function Base.show(io::IO, ::MIME"text/plain", M::Monitor)
    print(io, "Monitor(n = $(M.n), time = $(round(M.time; sigdigits = 3)) s, ")
    print(io, "bytes = $(Base.format_bytes(M.bytes)), allocs = $(M.allocs), ")
    return print(io, "gctime = $(round(M.gctime; sigdigits = 3)) s)")
end
