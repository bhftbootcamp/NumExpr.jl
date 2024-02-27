using ExprParser
using Documenter

DocMeta.setdocmeta!(ExprParser, :DocTestSetup, :(using ExprParser); recursive=true)

makedocs(;
    modules = [ExprParser],
    authors = "",
    sitename = "ExprParser.jl",
    format = Documenter.HTML(;
        repolink = "https://github.com/bhftbootcamp/ExprParser.jl.git",
        canonical = "https://bhftbootcamp.github.io/ExprParser.jl",
        edit_link = "master",
        assets = String[],
    ),
    pages = [
        "Home" => "index.md",
        "pages/examples.md",
        "pages/expr_syntax.md",
        "pages/api_reference.md",
    ],
    checkdocs = :missing_docs,
)

deploydocs(;
    repo="github.com/bhftbootcamp/ExprParser.jl",
    devbranch="master",
)
