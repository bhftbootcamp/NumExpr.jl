using ExprParser
using Documenter

DocMeta.setdocmeta!(ExprParser, :DocTestSetup, :(using ExprParser); recursive=true)

makedocs(;
    modules=[ExprParser],
    authors="",
    sitename="ExprParser.jl",
    format=Documenter.HTML(;
        canonical="https://bhftbootcamp.github.io/ExprParser.jl",
        edit_link="master",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/bhftbootcamp/ExprParser.jl",
    devbranch="master",
)
