@testitem "Expansion" setup=[Setup] begin
    x = 1:2
    y = 3:4
    f = identity
    C = Chart(Iterators.product)

    y = @inferred map(C, f, x)
    @test y == map(f, x)

    f = +
    map(C, f, x, y)

    C = Chart(Cartographer.Sequential(), Float64)
    y = @inferred map(C, f, x)
    @test y == map(f, x)

    C = Chart(Cartographer.Sequential(), Union{}) # * Generic map. Must specify a leaf other than Union{} for type stability
    @test_throws "return type" (@inferred map(C, f, x))
    @test map(C, f, x) == map(f, x)
end
