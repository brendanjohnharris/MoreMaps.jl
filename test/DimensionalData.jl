@testitem "DimensionalData" setup=[Setup] begin
    using DimensionalData

    x = DimArray(x -> rand(), X(1:10))
    C = Chart()
    y = @inferred map(sqrt, C, x)
    @test y == sqrt.(x)

    f = +
    y = map(f, C, x, x)
    @test y == x .+ x

    C = Chart(Cartographer.Sequential(), Union{}) # * Generic map. Must specify a leaf other than Union{} for type stability
    @test_throws "return type" (@inferred map(identity, C, x))
    @test map(identity, C, x) == x

    # * Expand dims
    C = Chart(Iterators.product)
    @test_throws "return type" (@inferred map((x...) -> x, C, X(1:10), Y(1:10)))
    y = map((x...) -> x, C, X(1:10), Y(1:10))
    @test y == Iterators.product(1:10, 1:10) |> collect
end

@testitem "DimensionalData generic" setup=[Setup] begin
    using DimensionalData
    x = DimArray(x -> rand(), X(1:10))
    test_generic_input(x)

    x = map((x...) -> rand(), Chart(Iterators.product), X(1:10), Y(1:5))

    test_generic_input(x)
end
