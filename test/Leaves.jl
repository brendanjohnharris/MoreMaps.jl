@testitem "Default leaf map" setup=[Setup] begin
    x = [1:NN for NN in 1:5]
    y = [sum(1:NN) for NN in 1:5]
    C = Cartographer.Chart()
    @test Cartographer.leaf(C) === Cartographer.All
    @test map(C, sum, x) == y
end
@testitem "Nested array map" setup=[Setup] begin
    x = [[1:n for n in 1:NN] for NN in 1:5]
    y = [[sqrt.(1:n) for n in 1:NN] for NN in 1:5]
    C = Cartographer.Chart(Union{})
    @test map(C, sqrt, x) == y
end
@testitem "Nested array map" setup=[Setup] begin
    x = [[1:n for n in 1:NN] for NN in 1:5]
    y = [[extrema(1:n) for n in 1:NN] for NN in 1:5]
    C = Cartographer.Chart(Union{})
    @test map(C, extrema, x) !== y
    C = Cartographer.Chart(UnitRange)
    @test map(C, extrema, x) !== y
end
