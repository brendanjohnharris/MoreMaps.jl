@testitem "Sequential" setup=[Setup] begin
    x = randn(10)
    f = Base.Fix1(^, 2)
    C = Chart(Cartographer.Sequential())
    y = @inferred map(f, C, x)
    @test y == map(f, x)

    C = Chart(Cartographer.Sequential(), Float64)
    y = @inferred map(f, C, x)
    @test y == map(f, x)

    C = Chart(Cartographer.Sequential(), Union{}) # * Generic map. Must specify a leaf other than Union{} for type stability
    @test_throws "return type" (@inferred map(f, C, x))
    @test map(f, C, x) == map(f, x)
end

@testitem "Threaded" setup=[Setup] begin
    x = randn(10)
    C = Chart(Cartographer.Threaded())
    f = Base.Fix1(^, 2)
    @inferred map(f, C, x) # Regular map.
    @test map(f, C, x) == map(f, x)

    C = Chart(Cartographer.Threaded(), Float64)
    y = @inferred map(f, C, x)
    @test y == map(f, x)

    C = Chart(Cartographer.Threaded(), Union{}) # * Generic map. Must specify a leaf other than Union{} for type stability
    @test_throws "return type" (@inferred map(f, C, x))
    @test map(f, C, x) == map(f, x)
end

@testitem "Distributed" setup=[Setup] begin
    using Distributed

    x = randn(10)
    C = Chart(Cartographer.Pmap())
    f = Base.Fix1(^, 2)
    @inferred map(f, C, x) # Regular map.
    @test map(f, C, x) == map(f, x)

    C = Chart(Cartographer.Pmap(), Float64)
    y = @inferred map(f, C, x)
    @test y == map(f,us x)

    C = Chart(Cartographer.Pmap(), Union{}) # * Generic map. Must specify a leaf other than Union{} for type stability
    @test_throws "return type" (@inferred map(f, C, x))
    @test map(f, C, x) == map(f, x)

    # * With workers
    addprocs(3)
    @everywhere using Cartographer
    x = randn(100)
    C = Chart(Cartographer.Pmap(), InfoProgress(10))
    @everywhere g(x) = (sleep(0.01); x^2) # g must be defined on the workers
    @inferred map(g, C, x)
    @test map(g, C, x) == map(g, x)

    c = Chart(Sequential())
    tc = @timed map(g, c, x);
    C = Chart(Cartographer.Pmap())
    tC = @timed map(g, C, x);
    if Threads.nthreads() > 3
        @test tC.time < tc.time/2
    end
end

@testitem "Daggermap" setup=[Setup] begin
    using Distributed
    using Cartographer
    addprocs(3)
    @everywhere using Dagger

    x = randn(10)
    C = Chart(Cartographer.Daggermap())
    f = Base.Fix1(^, 2)
    @inferred map(f, C, x) # Regular map.
    @test map(f, C, x) == map(f, x)

    C = Chart(Cartographer.Daggermap(), Float64)
    y = @inferred map(f, C, x)
    @test y == map(f, x)

    C = Chart(Cartographer.Daggermap(), Union{}) # * Generic map. Must specify a leaf other than Union{} for type stability
    @test_throws "return type" (@inferred map(f, C, x))
    @test map(f, C, x) == map(f, x)

    @everywhere begin
        function cpu_intensive_task(n)
            result = 0.0
            for i in 1:n
                result += sin(i) * cos(i) * sqrt(i)
            end
            return (result = result, worker_id = Distributed.myid())
        end
    end

    x = 1:1000:1000000
    C = Chart(Cartographer.Daggermap(), InfoProgress(10))
    @inferred map(cpu_intensive_task, C, x)
    @test map(cpu_intensive_task, C, x) == map(cpu_intensive_task, x)

    c = Chart(Sequential())
    tc = @timed map(cpu_intensive_task, c, x);
    C = Chart(Cartographer.Daggermap())
    tC = @timed map(cpu_intensive_task, C, x);
    if Threads.nthreads() > 3
        @test tC.time < tc.time/2
    end
end
