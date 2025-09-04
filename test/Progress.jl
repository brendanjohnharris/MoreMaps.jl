@testitem "ProgressLogging" setup=[Setup] begin
    x = randn(10)

    N = 10
    name = "testname"
    C = Chart(MoreMaps.ProgressLogger(N; name))
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
    C = Chart(MoreMaps.ProgressLogger(N; name))
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
    @test length(logger.logs) ≥ N + 1
end
@testitem "LogLogger" setup=[Setup] begin
    x = randn(10)

    N = 10
    C = Chart(MoreMaps.LogLogger(N))
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
    C = Chart(MoreMaps.LogLogger(N))
    logger = TestLogger()
    y = with_logger(logger) do
        map(f, C, x)
    end
    @test y == map(f, x)
    @test length(logger.logs) ≥ N
end

@testitem "Expansion progress" setup=[Setup] begin
    x = randn(10)
    y = randn(10)
    N = 10
    C = Chart(MoreMaps.LogLogger(N), Iterators.product)
    f = (x...) -> (sleep(0.01); +(x...))

    logger = TestLogger()
    z = with_logger(logger) do
        map(f, C, x, y)
    end
    @test z == map(sum, Iterators.product(x, y))
    @test map(logger.logs) do l
        occursin("Progress: ", string(l))
    end |> all
    @test length(logger.logs) ≥ N - 1
end

@testitem "Term" setup=[Setup] begin
    using Term
    x = randn(10)

    C = Chart(MoreMaps.TermLogger())
    f = x -> (sleep(0.3); x^2)
    map(f, C, x)

    N = 10
    name = "testname"
    C = Chart(MoreMaps.TermLogger(N))
    f = x -> (sleep(0.3); x^2)
end
