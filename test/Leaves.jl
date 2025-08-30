@testitem "Default leaf map" setup=[Setup] begin
    x = [1:NN for NN in 1:5]
    y = [sum(1:NN) for NN in 1:5]
    C = MoreMaps.Chart()
    @test MoreMaps.leaf(C) === MoreMaps.All
    @test map(sum, C, x) == y
end
@testitem "Nested array map" setup=[Setup] begin
    x = [[1:n for n in 1:NN] for NN in 1:5]
    y = [[sqrt.(1:n) for n in 1:NN] for NN in 1:5]
    C = MoreMaps.Chart(Union{})
    @test map(sqrt, C, x) == y
end
@testitem "Nested array map" setup=[Setup] begin
    x = [[1:n for n in 1:NN] for NN in 1:5]
    y = [[extrema(1:n) for n in 1:NN] for NN in 1:5]
    C = MoreMaps.Chart(Union{})
    @test map(extrema, C, x) !== y
    C = MoreMaps.Chart(UnitRange)
    @test map(extrema, C, x) !== y
end
