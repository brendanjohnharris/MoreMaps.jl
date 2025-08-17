@testitem "DimensionalData" setup=[Setup] begin
    using DimensionalData

    x = DimArray(x -> rand(), X(1:10))
    C = Chart()
    y = @inferred map(C, sqrt, x)
    @test y == sqrt.(x)

    f = +
    y = map(C, f, x, x)
    @test y == x .+ x

    C = Chart(Cartographer.Sequential(), Union{}) # * Generic map. Must specify a leaf other than Union{} for type stability
    @test_throws "return type" (@inferred map(C, identity, x))
    @test map(C, identity, x) == x

    # * Expand dims
    C = Chart(Iterators.product)
    @test_throws "return type" (@inferred map(C, (x...) -> x, X(1:10), Y(1:10)))
    y = map(C, (x...) -> x, X(1:10), Y(1:10))
    @test y == Iterators.product(1:10, 1:10) |> collect
end

