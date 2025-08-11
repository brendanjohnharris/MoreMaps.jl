using Cartographer
using Documenter

DocMeta.setdocmeta!(Cartographer, :DocTestSetup, :(using Cartographer); recursive=true)

makedocs(;
    modules=[Cartographer],
    authors="brendanjohnharris <bhar9988@uni.sydney.edu.au> and contributors",
    sitename="Cartographer.jl",
    format=Documenter.HTML(;
        canonical="https://brendanjohnharris.github.io/Cartographer.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/brendanjohnharris/Cartographer.jl",
    devbranch="main",
)
