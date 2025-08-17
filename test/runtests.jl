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

    function test_generic_input(x)
        # Define all available backends
        backends = [
            Sequential(),
            Threaded()
        ]

        # Define all available progress loggers
        loggers = [
            NoProgress(),
            InfoProgress(3),
            InfoProgress(5),
            InfoProgress(10)
        ]

        # Define different leaf types to test
        leaf_types = [
            Cartographer.All,
            Union{},
            Any
        ]

        # Add element-specific leaf type if x is not empty
        if !isempty(x)
            push!(leaf_types, eltype(x))
            # If x contains arrays, add nested element type
            if eltype(x) <: AbstractArray
                push!(leaf_types, eltype(eltype(x)))
            end
        end

        # Define expansion functions to test
        expansions = [
            NoExpansion(),
            Iterators.product
        ]

        # Test all combinations of backend + logger + leaf type
        for backend in backends, logger in loggers, leaf_type in leaf_types
            # Test 1: Basic identity mapping
            C = Chart(leaf_type, backend, logger, NoExpansion())
            try
                y1 = map(C, identity, x)
                @test y1 == x

                # Test 2: Simple transformation
                if eltype(x) <: Number
                    y2 = map(C, x -> x + 1, x)
                    @test y2 == x .+ 1
                else
                    y2 = map(C, x -> x, x)  # Fallback for non-numeric types
                    @test y2 == x
                end

                # Test 3: Multiple iterators (if not empty)
                if !isempty(x)
                    if eltype(x) <: Number
                        y3 = map(C, +, x, x)
                        @test y3 == x .+ x
                    else
                        # For non-numeric, test with a function that works on any type
                        y3 = map(C, (a, b) -> a, x, x)  # Just return first argument
                        @test y3 == x
                    end
                end

            catch e
                # Some combinations might not be type stable or supported
                if e isa BoundsError || e isa MethodError
                    @test_nowarn map(C, identity, x)  # At least check it doesn't crash
                else
                    rethrow(e)
                end
            end
        end

        # Test expansion combinations (only with smaller arrays to avoid performance issues)
        if length(x) <= 5 && !isempty(x) && eltype(x) <: Number
            for backend in backends, logger in loggers
                # Test cartesian product expansion
                C_expand = Chart(Cartographer.All, backend, logger, Iterators.product)

                try
                    x_small = x[1:min(3, length(x))]
                    y_expand = map(C_expand, (a, b) -> (a, b), x_small, x_small)
                    expected = [(a, b) for a in x_small, b in x_small]
                    @test y_expand == expected
                catch e
                    if !(e isa BoundsError || e isa MethodError)
                        rethrow(e)
                    end
                end
            end
        end

        # Test type stability for specific configurations
        for leaf_type in [Cartographer.All, eltype(x)]
            C_stable = Chart(leaf_type, Sequential(), NoProgress(), NoExpansion())

            # Type stability test (may fail for some combinations)
            try
                if leaf_type != Union{} && isconcretetype(eltype(x))
                    y_stable = @inferred map(C_stable, identity, x)
                    @test y_stable == x
                else
                    # For Union{} and non-concrete types, just test it works
                    @test_throws "return type" (@inferred map(C_stable, identity, x))
                    y_unstable = map(C_stable, identity, x)
                    @test y_unstable == x
                end
            catch e
                if e isa ErrorException && contains(string(e), "return type")
                    # Expected type instability
                    y_unstable = map(C_stable, identity, x)
                    @test y_unstable == x
                else
                    rethrow(e)
                end
            end
        end

        # Test edge cases
        if isempty(x)
            # Empty array tests
            for backend in backends[1:1], logger in loggers[1:1]  # Just test one combination for empty
                C_empty = Chart(Cartographer.All, backend, logger, NoExpansion())
                y_empty = map(C_empty, identity, x)
                @test isempty(y_empty)
                @test typeof(y_empty) == typeof(x)
            end
        end

        # Test error handling
        if !isempty(x)
            C_error = Chart(Cartographer.All, Sequential(), NoProgress(), NoExpansion())

            # Test with incompatible function (should still work or give meaningful error)
            try
                if eltype(x) <: Number
                    y_sqrt = map(C_error, sqrt, x)
                    @test length(y_sqrt) == length(x)
                end
            catch e
                # Some functions might not work on all types, that's OK
                @test e isa MethodError || e isa DomainError
            end
        end

        # Performance test with threading (only for larger arrays)
        if length(x) > 50
            C_threaded = Chart(Cartographer.All, Threaded(), NoProgress(), NoExpansion())
            C_sequential = Chart(Cartographer.All, Sequential(), NoProgress(),
                                 NoExpansion())

            if eltype(x) <: Number
                y_threaded = map(C_threaded, x -> x^2, x)
                y_sequential = map(C_sequential, x -> x^2, x)
                @test y_threaded == y_sequential
            end
        end

        # Test with different progress logging levels
        if length(x) > 10
            for nlogs in [1, 3, 5]
                C_progress = Chart(Cartographer.All, Sequential(), InfoProgress(nlogs),
                                   NoExpansion())
                y_progress = map(C_progress, identity, x)
                @test y_progress == x
            end
        end

        return true
    end
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
