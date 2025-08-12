@testitem "InfoProgress" setup=[Setup] begin
    x = randn(10)

    N = 10
    C = Chart(Cartographer.InfoProgress(N))
    f = x -> (sleep(0.1); x^2)

    logger = TestLogger()
    y = with_logger(logger) do
        @inferred map(C, f, x)
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
        @inferred map(C, f, x)
    end
    @test y == map(f, x)
    @test length(logger.logs) == N + 1
end
