using NumExpr
using Documenter

DocMeta.setdocmeta!(NumExpr, :DocTestSetup, :(using NumExpr); recursive = true)

makedocs(;
    modules = [NumExpr],
    sitename = "NumExpr.jl",
    format = Documenter.HTML(;
        repolink = "https://github.com/bhftbootcamp/NumExpr.jl.git",
        canonical = "https://bhftbootcamp.github.io/NumExpr.jl",
        edit_link = "master",
        assets = String["assets/favicon.ico"],
        sidebar_sitename = false,
    ),
    pages = [
        "Home" => "index.md",
        "pages/expr_syntax.md",
        "pages/api_reference.md",
    ],
    warnonly = [:doctest, :missing_docs],
)

deploydocs(;
    repo = "github.com/bhftbootcamp/NumExpr.jl",
    devbranch = "master",
    push_preview = true,
)
