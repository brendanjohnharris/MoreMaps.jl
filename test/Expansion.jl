@testitem "Expansion" setup=[Setup] begin
    x = 1:2
    y = 3:4
    f = identity
    C = Chart(Iterators.product)
    @test_throws "return type" (@inferred map(f, C, x))
    @test map(f, C, x) == map(f, x)

    f = +
    @test map(f, C, x, y) == [4 5; 5 6]

    C = Chart(Cartographer.Sequential(), Float64) # Wrong leaf gives error
    @test_throws ArgumentError map(f, C, x)

    C = Chart(Cartographer.Sequential(), Integer)
    y = @inferred map(f, C, x)
    @test y == map(f, x)

    C = Chart(Cartographer.Sequential(), Union{}) # * Generic map. Must specify a leaf other than Union{} for type stability
    @test_throws "return type" (@inferred map(f, C, x))
    @test map(f, C, x) == map(f, x)
end
