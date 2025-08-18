@testitem "ProgressLogging" setup=[Setup] begin
    x = randn(10)

    N = 10
    name = "testname"
    C = Chart(Cartographer.ProgressLogging(N; name))
    f = x -> (sleep(0.3); x^2)

    logger = TestLogger(; min_level = ProgressLogging.ProgressLevel)
    y = with_logger(logger) do
        @inferred map(f, C, x)
    end
    @test y == map(f, x)
    map(logger.logs) do l
        @test l.level == ProgressLogging.ProgressLevel
        @test l.message ∈ [name, "done"]
        @test l.id == C.progress.Progress.id
    end
    @test length(logger.logs) == N + 1

    N = 4 # Not divisible
    C = Chart(Cartographer.ProgressLogging(N; name))
    logger = TestLogger(; min_level = ProgressLogging.ProgressLevel)
    y = with_logger(logger) do
        @inferred map(f, C, x)
    end
    map(logger.logs) do l
        @test l.level == ProgressLogging.ProgressLevel
        @test l.message ∈ [name, "done"]
        @test l.id == C.progress.Progress.id
    end
    @test y == map(f, x)
    @test length(logger.logs) == N + 2
end
@testitem "InfoProgress" setup=[Setup] begin
    x = randn(10)

    N = 10
    C = Chart(Cartographer.InfoProgress(N))
    f = x -> (sleep(0.1); x^2)

    logger = TestLogger()
    y = with_logger(logger) do
        map(f, C, x)
    end
    @test y == map(f, x)
    @test map(logger.logs) do l
        occursin("Progress: ", string(l))
    end |> all
    @test length(logger.logs) == N

    N = 4 # Not divisible
    C = Chart(Cartographer.InfoProgress(N))
    logger = TestLogger()
    y = with_logger(logger) do
        map(f, C, x)
    end
    @test y == map(f, x)
    @test length(logger.logs) == N + 1
end
