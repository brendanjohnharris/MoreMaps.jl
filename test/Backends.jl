@testitem "Sequential" setup=[Setup] begin
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
end

@testitem "Threaded" setup=[Setup] begin
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

@testitem "Distributed" setup=[Setup] begin
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

@testitem "Daggermap" setup=[Setup] begin
    using Distributed
    using MoreMaps
    using Dagger

    try
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

        function cpu_intensive_task(n)
            result = 0.0
            for i in 1:n
                result += sin(i) * cos(i) * sqrt(i)
            end
            return (result = result, worker_id = Distributed.myid())
        end

        x = 1:1000:1000000
        C = Chart(MoreMaps.Daggermap(), LogLogger(10))
        @inferred map(cpu_intensive_task, C, x)
        @test map(cpu_intensive_task, C, x) == map(cpu_intensive_task, x)

        c = Chart(Sequential())
        tc = @timed map(cpu_intensive_task, c, x)
        C = Chart(MoreMaps.Daggermap())
        tC = @timed map(cpu_intensive_task, C, x)
        if Threads.nthreads() > 3
            @test tC.time < tc.time / 2
        end
    catch e
        rethrow(e)
    finally
        rmprocs()
    end
end

@testitem "Tuples" setup=[Setup] begin
    x = (1, 2, 3)
    y = (4, 5, 6)

    _z = map(+, x, y)
    z = @inferred map(+, Chart(), x, y)
    @test z == _z
end
@testitem "NamedTuples" setup=[Setup] begin
    x = (; a = 1, b = 2, c = 3)
    y = (; a = 4, b = 5, c = 6)

    _z = map(+, x, y)
    z = @inferred map(+, Chart(), x, y)
    @test z == _z
end
