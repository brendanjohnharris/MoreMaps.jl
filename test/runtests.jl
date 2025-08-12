using Cartographer
using TestItems
using TestItemRunner

@run_package_tests

@testsnippet Setup begin
    using Test
    using Cartographer
    using Random
    using Logging
end

@testitem "Aqua" begin
    using Aqua
    Aqua.test_all(Cartographer; unbound_args = false) # unbound_args=true
end

# @testset "Cartographer.jl" begin
#     # Write your tests here.
# end
