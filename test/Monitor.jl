@testitem "Monitor" setup = [Setup] begin
    # * Stats populated on an allocating job
    M = Monitor()
    x = [rand(100) for _ in 1:50]
    y = map(x -> x .^ 2, Chart(M), x)
    @test y == map(x -> x .^ 2, x)
    @test M.n == 50
    @test M.time > 0
    @test M.bytes > 0
    @test M.allocs > 0
    @test M.backend isa Sequential
    @test MoreMaps.pertime(M) ≈ M.time / M.n

    # * Reused across jobs; fields refresh
    map(identity, Chart(Threaded(), M), 1:10)
    @test M.n == 10
    @test M.backend isa Threaded

    # * Composes with a real logger via CompositeLogger
    M2 = Monitor()
    logger = TestLogger()
    y = with_logger(logger) do
        map(identity, Chart(CompositeLogger(M2, MoreMaps.LogLogger(0))), 1:10)
    end
    @test y == collect(1:10)
    @test M2.n == 10
    @test length(logger.logs) == 11

    io = IOBuffer()
    show(io, MIME"text/plain"(), M)
    @test occursin("Monitor(n = 10", String(take!(io)))
end

@testitem "Monitor Pmap backend" setup = [Setup] begin
    using Distributed
    try
        addprocs(2)
        @everywhere using MoreMaps

        M = Monitor()
        x = randn(10)
        y = map(identity, Chart(MoreMaps.Pmap(), M), x)
        @test y == x
        @test M.n == length(x)
        @test M.time > 0 # bytes/allocs are driver-only for distributed backends
        @test M.backend isa MoreMaps.Pmap
    finally
        nprocs() > 1 && rmprocs()
    end
end
