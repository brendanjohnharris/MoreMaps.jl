@testitem "Sequential" setup=[Setup] begin
    x = randn(10)
    C = Chart(Cartographer.Sequential())
    f = Base.Fix1(^, 2)
    @inferred map(C, f, x) # Regular map
    @test map(C, f, x) == map(f, x)
end

@testitem "Threaded" setup=[Setup] begin
    x = randn(10)
    C = Chart(Cartographer.Threaded())
    f = Base.Fix1(^, 2)
    # @inferred map(C, f, x) # Threaded map. Not type stable yet
    @test map(C, f, x) == map(f, x)
end
