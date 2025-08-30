using BenchmarkTools
using Distributed
using Dagger
using MoreMaps
using CairoMakie

begin # * Setup
    addprocs(8)

    proj = Base.active_project()
    @everywhere using Pkg
    @everywhere Pkg.activate($proj)
    @everywhere using Distributed
    @everywhere using MoreMaps
    @everywhere using Dagger
end

@everywhere begin # * Define a fair cpu-intensive task
    function cpu_task(n::Int, iterations::Int = 1000)
        total_factors = 0

        for i in 1:iterations
            num = n + i
            factors = 0

            # Trial division factorization
            d = 2
            temp = num
            while d * d <= temp
                while temp % d == 0
                    factors += d
                    temp ÷= d
                end
                d += (d == 2) ? 1 : 2  # Skip even numbers after 2
            end
            if temp > 1
                factors += temp
            end

            total_factors += factors
        end

        return total_factors
    end
end

begin # * Define a fair memory-intensive task
    function memory_task(task_id::Int)
        """
        Simple memory-intensive task that allocates ~1/4 of available memory
        Minimal CPU usage, maximum memory allocation
        """

        # Calculate target memory (1/4 of available system memory)
        total_memory = Sys.total_memory()
        target_bytes = Int(total_memory * 0.8 / 4)  # 80% of total, then 1/4 of that
        target_gb = target_bytes / (1024^3)

        println("Worker $(myid()): Task $task_id allocating $(round(target_gb, digits=2)) GB")

        # Allocate large array of Float64 (8 bytes each)
        num_elements = target_bytes ÷ 8

        # Create the large array with minimal computation
        data = Vector{Float64}(undef, num_elements)

        # Fill with simple pattern (very low CPU cost)
        for i in 1:num_elements
            data[i] = Float64(i % 1000) * 0.001
        end

        actual_gb = sizeof(data) / (1024^3)
        println("Worker $(myid()): Task $task_id allocated $(round(actual_gb, digits=2)) GB")

        # Hold memory and do minimal computation
        sleep(1.0)  # Hold for 1 second

        # Minimal computation - just touch a few elements
        checksum = data[1] + data[end] + data[num_elements ÷ 2]

        return actual_gb
    end
end

begin # * Backends
    backends = (MoreMaps.Sequential(),
                MoreMaps.Daggermap(),
                MoreMaps.Pmap(),
                MoreMaps.Threaded())
end
begin # * Run cpu task for varying N
    N = 1e7:1e7:1e10 .|> Int
    cpu = map(backends) do B
        C = Chart(B)
        println("Benchmarking CPU task with backend: $(typeof(B))")
        @benchmark map(cpu_task, $C, $N) samples=10 seconds=30
    end
end
begin # * Violin plot of times for each backend
    f = Figure()
    ax = Axis(f[1, 1]; ylabel = "Time (s)", xlabel = "Backend",
              title = "CPU Task Benchmark",
              xticks = (1:length(backends), collect(string.(typeof.(backends)))))
    map(eachindex(backends)) do i
        c = cpu[i]
        b = backends[i] |> typeof |> string
        times = c.times ./ 1e9
        rainclouds!(ax, fill(i, length(c.times)), times; label = b)
    end
    f |> display
end
