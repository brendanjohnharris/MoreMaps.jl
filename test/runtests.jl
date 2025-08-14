using Cartographer
using TestItems
using TestItemRunner

@run_package_tests

@testsnippet Setup begin
    using Test
    using Cartographer
    using Random
    using Logging
    using ProgressLogging
end

@testitem "Aqua" begin
    using Aqua
    Aqua.test_all(Cartographer; unbound_args = false) # unbound_args=true
end

@testitem "nsimilar stability" setup=[Setup] begin
    x = randn(100)
    inleaf = Float64
    outleaf = Float32
    y = @inferred Cartographer.nsimilar(inleaf, outleaf, x)
    @test y isa Vector{Float32}

    x = [randn(2) for _ in 1:2]
    inleaf = Vector{Float64}
    outleaf = Vector{Float32}
    y = @inferred Cartographer.nsimilar(inleaf, outleaf, x)
    @test y isa Vector{Vector{Float32}}

    inleaf = Float64
    outleaf = Int32
    y = @inferred Cartographer.nsimilar(inleaf, outleaf, x)
    @test y isa Vector{Vector{Int32}}

    x = [randn(2) for _ in 1:2]
    inleaf = Float64
    outleaf = Float32
    y = @inferred Cartographer.nsimilar(inleaf, outleaf, x)
    @test y isa Vector{Vector{Float32}}
    outleaf = Vector{Float32}
    y = @inferred Cartographer.nsimilar(inleaf, outleaf, x)
    @test y isa Vector{Vector{Vector{Float32}}}

    x = [[randn(2) for _ in 1:2] for _ in 1:2]
    inleaf = Float64
    outleaf = Int32
    y = @inferred Cartographer.nsimilar(inleaf, outleaf, x)
    @test y isa Vector{Vector{Vector{Int32}}}

    x = [[randn(2) for _ in 1:2, _ in 1:2] for _ in 1:2, _ in 1:2]
    inleaf = Float64
    outleaf = Int32
    y = @inferred Cartographer.nsimilar(inleaf, outleaf, x)
    @test y isa Matrix{Matrix{Vector{Int32}}}

    # ! It breaks at some stage
    x = [[[randn(2) for _ in 1:2] for _ in 1:2] for _ in 1:2]
    inleaf = Float64
    outleaf = Int32
    @test_throws "return type" (@inferred Cartographer.nsimilar(inleaf, outleaf, x))
    y = @test_nowarn Cartographer.nsimilar(inleaf, outleaf, x)
    @test y isa Vector{Vector{Vector{Vector{Int32}}}}

    x = [[Dict() for _ in 1:2] for _ in 1:2]
    inleaf = Dict
    outleaf = String
    y = @inferred Cartographer.nsimilar(inleaf, outleaf, x)
    @test y isa Vector{Vector{String}}
end

@testitem "nviews stability" setup=[Setup] begin
    x = randn(100)
    leaf = Float64
    idxs = @inferred Cartographer.nindices(leaf, x)
    @inferred Cartographer.nview(x, first(idxs))
    @test_throws "return type" (@inferred Cartographer.nviews(x, idxs))

    x = [randn(2) for _ in 1:2]
    leaf = Float64
    idxs = @inferred Cartographer.nindices(leaf, x)
    @inferred Cartographer.nindex(x, first(idxs))
    @test_throws "return type" (@inferred Cartographer.nviews(x, idxs))
end
# @testset "Cartographer.jl" begin
#     # Write your tests here.
# end
