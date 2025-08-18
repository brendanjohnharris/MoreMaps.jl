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

    C = Chart(Cartographer.Sequential(), Union{}) # * Generic map. Must specify a leaf other than Union{} for type stability
    @test_throws "return type" (@inferred map(f, C, x))
    @test map(f, C, x) == map(f, x)
end
