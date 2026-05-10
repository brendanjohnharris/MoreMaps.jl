@testitem "ProgressLogging" setup = [Setup] begin
    x = randn(10)

    N = 10
    name = "testname"
    C = Chart(MoreMaps.ProgressLogger(N; name))
    f = x -> (sleep(0.3); x^2)

    logger = TestLogger(; min_level = ProgressLogging.ProgressLevel)
    y = with_logger(logger) do
        @inferred map(f, C, x)
    end
    @test sum(map(x -> x.message.done, logger.logs)) == 1
    map(logger.logs) do l
        @test l.level == ProgressLogging.ProgressLevel
        @test l.message isa ProgressLogging.Progress
        @test l.message.name == name
        @test l.message.id == C.progress.Progress.id
    end
    # @test length(logger.logs) == N + 1
    @test y == map(f, x)

    N = 4 # Not divisible
    C = Chart(MoreMaps.ProgressLogger(N; name))
    logger = TestLogger(; min_level = ProgressLogging.ProgressLevel)
    y = with_logger(logger) do
        @inferred map(f, C, x)
    end
    @test sum(map(x -> x.message.done, logger.logs)) == 1
    map(logger.logs) do l
        @test l.level == ProgressLogging.ProgressLevel
        @test l.message isa ProgressLogging.Progress
        @test l.message.name == name
        @test l.message.id == C.progress.Progress.id
    end
    @test y == map(f, x)
    # @test length(logger.logs) ≥ N + 1
end
@testitem "LogLogger" setup = [Setup] begin
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

    @test length(logger.logs) == N + 1

    N = 4 # Not divisible
    C = Chart(MoreMaps.LogLogger(N))
    logger = TestLogger()
    y = with_logger(logger) do
        map(f, C, x)
    end
    @test y == map(f, x)
    @test length(logger.logs) ≥ N + 1

    # * Different log level
    N = 10
    C = Chart(MoreMaps.LogLogger(N, Warn))
    f = x -> (sleep(0.1); x^2)

    logger = TestLogger()
    y = with_logger(logger) do
        map(f, C, x)
    end
    @test y == map(f, x)
    @test map(logger.logs) do l
        occursin("Progress: ", string(l)) && l.level == Warn
    end |> all
    @test length(logger.logs) == N + 1

    # nlogs = 0 means log every iteration
    C = Chart(MoreMaps.LogLogger(0))
    logger = TestLogger()
    y = with_logger(logger) do
        map(identity, C, x)
    end
    @test y == map(identity, x)
    @test length(logger.logs) == length(x) + 1
    @test occursin(
        "Progress: 0 / $(length(x)) (??s / ??s)",
        string(first(logger.logs).message)
    )

    # * Test passing progress only, no Chart
    @test_nowarn map(f, MoreMaps.LogLogger(), x)
end

@testitem "LogLogger Pmap backend" setup = [Setup] begin
    using Distributed

    workers = Int[]
    try
        workers = addprocs(2)
        @everywhere workers using MoreMaps

        x = randn(10)
        C = Chart(MoreMaps.Pmap(), MoreMaps.LogLogger(0))

        logger = TestLogger()
        y = with_logger(logger) do
            map(identity, C, x)
        end

        @test y == map(identity, x)
        @test length(logger.logs) == length(x) + 1
        @test map(logger.logs) do l
            occursin("Progress: ", string(l))
        end |> all
        @test occursin(
            "Progress: 0 / $(length(x)) (??s / ??s)",
            string(first(logger.logs).message)
        )
    finally
        !isempty(workers) && rmprocs(workers)
    end
end

@testitem "Expansion progress" setup = [Setup] begin
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

@testitem "Term" setup = [Setup] begin
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

@testitem "Term Pmap" setup = [Setup] begin
    using Term
    using Distributed

    try
        workers = addprocs(2)
        @everywhere using MoreMaps, Term
        x = randn(10)
        C = Chart(MoreMaps.Pmap(), MoreMaps.TermLogger())
        y = map(abs, C, x)
        @test y == map(abs, x)

        C = Chart(MoreMaps.Pmap(), MoreMaps.TermLogger(5))
        y = map(abs, C, x)
        @test y == map(abs, x)
    finally
        !isempty(workers) && rmprocs(workers)
    end
end

@testitem "QualityLogger" setup = [Setup] begin
    x = randn(1000)
    _f(x) = (y = sqrt(complex(x)); real(y) > 0 ? NaN : y)
    f(x) = (sleep(0.01); _f(x))
    y = map(_f, x)

    io = IOBuffer()
    q = MoreMaps.QualityLogger(; io = io, width = 3, quality = z -> imag(z) == 0)
    C = Chart(q)

    out = map(f, C, x)
    out = map(f, Chart(QualityLogger()), x)

    @test filter(!isnan, out) == filter(!isnan, y)
    @test q.done == length(x)

    printed = String(take!(io))
    @test occursin("█", printed)
end

@testitem "QualityLogger 6-color bands" setup = [Setup] begin
    x = randn(1000)

    q = MoreMaps.QualityLogger(; width = 16, quality = z -> z)
    out = map(identity, Chart(q), x)

    io = IOBuffer()
    q = MoreMaps.QualityLogger(; io = io, width = 16, quality = z -> z)
    C = Chart(q)

    out = map(identity, C, x)

    @test filter(!isnan, out) == filter(!isnan, x)
    @test q.done == length(x)

    printed = String(take!(io))
    @test occursin("█", printed)
end

@testitem "QualityLogger Pmap" setup = [Setup] begin
    using Distributed
    x = rand(1000)

    try
        workers = addprocs(3)
        @everywhere using MoreMaps

        out = map(abs, Chart(Pmap(), QualityLogger()), x)

        io = IOBuffer()
        q = MoreMaps.QualityLogger(; io = io, width = 16, quality = z -> z)
        C = Chart(q)

        out = map(identity, C, x)

        @test filter(!isnan, out) == filter(!isnan, x)
        @test q.done == length(x)

        printed = String(take!(io))
        @test occursin("█", printed)
    finally
        !isempty(workers) && rmprocs(workers)
    end
end
