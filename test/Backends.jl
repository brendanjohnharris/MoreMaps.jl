@testitem "Sequential" setup = [Setup] begin
    x = randn(10)
    f = Base.Fix1(^, 2)
    C = Chart(MoreMaps.Sequential())
    y = @inferred map(f, C, x)
    @test y == map(f, x)

    C = Chart(MoreMaps.Sequential(), Float64)
    y = @inferred map(f, C, x)
    @test y == map(f, x)

    C = Chart(MoreMaps.Sequential(), Union{}) # * Generic map. Must specify a leaf other than Union{} for type stability
    @test_throws "return type" (@inferred map(f, C, x))
    @test map(f, C, x) == map(f, x)

    # * Test passing jus ta backend, no Chart
    @test map(f, MoreMaps.Sequential(), x) == map(f, x)
end

@testitem "Threaded" setup = [Setup] begin
    x = randn(10)
    C = Chart(MoreMaps.Threaded())
    f = Base.Fix1(^, 2)
    @inferred map(f, C, x) # Regular map.
    @test map(f, C, x) == map(f, x)

    C = Chart(MoreMaps.Threaded(), Float64)
    y = @inferred map(f, C, x)
    @test y == map(f, x)

    C = Chart(MoreMaps.Threaded(), Union{}) # * Generic map. Must specify a leaf other than Union{} for type stability
    @test_throws "return type" (@inferred map(f, C, x))
    @test map(f, C, x) == map(f, x)
end

@testitem "Distributed" setup = [Setup] begin
    using Distributed

    try
        x = randn(10)
        C = Chart(MoreMaps.Pmap())
        f = Base.Fix1(^, 2)
        @inferred map(f, C, x) # Regular map.
        @test map(f, C, x) == map(f, x)

        C = Chart(MoreMaps.Pmap(), Float64)
        y = @inferred map(f, C, x)
        @test y == map(f, x)

        C = Chart(MoreMaps.Pmap(), Union{}) # * Generic map. Must specify a leaf other than Union{} for type stability
        @test_throws "return type" (@inferred map(f, C, x))
        @test map(f, C, x) == map(f, x)
    catch e
        rethrow(e)
    finally
        rmprocs()
    end
end

@testitem "Daggermap" setup = [Setup] begin
    using Distributed
    using MoreMaps
    using Dagger

    try
        addprocs(4)
        @everywhere using MoreMaps
        @everywhere using Dagger

        x = randn(10)
        C = Chart(MoreMaps.Daggermap())
        f = Base.Fix1(^, 2)
        @inferred map(f, C, x) # Regular map.
        @test map(f, C, x) == map(f, x)

        C = Chart(MoreMaps.Daggermap(), Float64)
        y = @inferred map(f, C, x)
        @test y == map(f, x)

        C = Chart(MoreMaps.Daggermap(), Union{}) # * Generic map. Must specify a leaf other than Union{} for type stability
        @test_throws "return type" (@inferred map(f, C, x))
        @test map(f, C, x) == map(f, x)

        # * Batch size edge cases
        x10 = randn(10)
        for bs in (0, 1, 3, 100) # auto, minimal, non-divisible, > N
            C = Chart(MoreMaps.Daggermap(; batchsize = bs))
            @test map(f, C, x10) == map(f, x10)
        end

        # * Options take effect: pin all tasks to a single worker. Use a named function;
        #   testitem-local closures cannot deserialize on workers.
        w = first(Distributed.workers())
        C = Chart(MoreMaps.Daggermap(; single = w, batchsize = 2))
        ids = getfield.(map(MoreMaps.cpu_intensive_task, C, fill(10, 6)), :worker_id)
        @test all(==(w), ids)

        x = 1:1000:1000000
        C = Chart(MoreMaps.Daggermap(), LogLogger(10))
        @inferred map(MoreMaps.cpu_intensive_task, C, x)
        y_dagger = map(MoreMaps.cpu_intensive_task, C, x)
        y_seq = map(MoreMaps.cpu_intensive_task, x)

        # Worker assignment is backend-dependent; only numeric results must match.
        @test getfield.(y_dagger, :result) == getfield.(y_seq, :result)
        @test all(r -> r.worker_id > 0, y_dagger)

        c = Chart(Sequential())
        tc = @timed map(MoreMaps.cpu_intensive_task, c, x)
        C = Chart(MoreMaps.Daggermap())
        tC = @timed map(MoreMaps.cpu_intensive_task, C, x)
        if Threads.nthreads() > 3
            @test tC.time < tc.time / 2
        end
    catch e
        rethrow(e)
    finally
        rmprocs()
    end
end

@testitem "Asyncmap" setup = [Setup] begin
    x = randn(10)
    f = Base.Fix1(^, 2)
    C = Chart(MoreMaps.Asyncmap())
    y = @inferred map(f, C, x)
    @test y == map(f, x)

    C = Chart(MoreMaps.Asyncmap(; ntasks = 2), Float64)
    y = @inferred map(f, C, x)
    @test y == map(f, x)

    C = Chart(MoreMaps.Asyncmap(), Union{}) # * Generic map
    @test_throws "return type" (@inferred map(f, C, x))
    @test map(f, C, x) == map(f, x)

    # * Concurrency: 20 sleeps of 50 ms should overlap, not serialize (~1 s serialized)
    map(_ -> sleep(0.05), Chart(MoreMaps.Asyncmap()), 1:20) # warmup: exclude compilation
    t = @elapsed map(_ -> sleep(0.05), Chart(MoreMaps.Asyncmap()), 1:20)
    @test t < 20 * 0.05 / 2

    # * Loggers work (single process, channel put! yields fine)
    logger = TestLogger()
    y = with_logger(logger) do
        map(f, Chart(MoreMaps.Asyncmap(), MoreMaps.LogLogger(0)), x)
    end
    @test y == map(f, x)
    @test length(logger.logs) == length(x) + 1
end

@testitem "OhMyThreaded" setup = [Setup] begin
    using OhMyThreads
    x = randn(10)
    f = Base.Fix1(^, 2)
    C = Chart(MoreMaps.OhMyThreaded())
    y = @inferred map(f, C, x)
    @test y == map(f, x)

    C = Chart(MoreMaps.OhMyThreaded(; ntasks = 2), Float64) # tforeach options
    y = @inferred map(f, C, x)
    @test y == map(f, x)

    C = Chart(MoreMaps.OhMyThreaded(), Union{}) # * Generic map
    @test_throws "return type" (@inferred map(f, C, x))
    @test map(f, C, x) == map(f, x)

    logger = TestLogger()
    y = with_logger(logger) do
        map(f, Chart(MoreMaps.OhMyThreaded(), MoreMaps.LogLogger(0)), x)
    end
    @test y == map(f, x)
    @test length(logger.logs) == length(x) + 1
end

@testitem "Polyestered" setup = [Setup] begin
    using Polyester
    x = randn(10)
    f = Base.Fix1(^, 2)
    C = Chart(MoreMaps.Polyestered())
    y = @inferred map(f, C, x)
    @test y == map(f, x)

    C = Chart(MoreMaps.Polyestered(), Float64)
    y = @inferred map(f, C, x)
    @test y == map(f, x)

    # * Channel-backed loggers are rejected (Polyester tasks must not yield)
    @test_throws ArgumentError map(f, Chart(MoreMaps.Polyestered(), MoreMaps.LogLogger()), x)

    # * Monitor is allowed (per-element no-op)
    M = Monitor()
    y = map(f, Chart(MoreMaps.Polyestered(), M), x)
    @test y == map(f, x)
    @test M.n == length(x)
end

@testitem "Tuples" setup = [Setup] begin
    x = (1, 2, 3)
    y = (4, 5, 6)

    _z = map(+, x, y)
    z = @inferred map(+, Chart(), x, y)
    @test z == _z
end
@testitem "NamedTuples" setup = [Setup] begin
    x = (; a = 1, b = 2, c = 3)
    y = (; a = 4, b = 5, c = 6)

    _z = map(+, x, y)
    z = @inferred map(+, Chart(), x, y)
    @test z == _z
end
