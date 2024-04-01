<img src=docs/src/assets/readme_logo.png height=100 width=auto>

# NumExpr

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://bhftbootcamp.github.io/NumExpr.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://bhftbootcamp.github.io/NumExpr.jl/dev/)
[![Build Status](https://github.com/bhftbootcamp/NumExpr.jl/actions/workflows/Coverage.yml/badge.svg?branch=master)](https://github.com/bhftbootcamp/NumExpr.jl/actions/workflows/Coverage.yml?query=branch%3Amaster)
[![Coverage](https://codecov.io/gh/bhftbootcamp/NumExpr.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/bhftbootcamp/NumExpr.jl)
[![Registry](https://img.shields.io/badge/registry-Green-green)](https://github.com/bhftbootcamp/Green)

The NumExpr library is designed to handle and evaluate arithmetic expressions. It enables parsing and analyzing expressions, as well as performing calculations with user-defined functions.

## Installation
If you haven't installed our [local registry](https://github.com/bhftbootcamp/Green) yet, do that first:
```
] registry add https://github.com/bhftbootcamp/Green.git
```

Then, to install NumExpr, simply use the Julia package manager:
```
] add NumExpr
```

## Usage

Here is an example usage of NumExpr:

```julia
using NumExpr
using NumExpr: Func, Variable

const local_vars = Dict{String,Float64}(
    "my_var"           => 1,
    "my_var{tag1='x'}" => 2,
)

const global_vars = Dict{String,Float64}(
    "my_var"           => 3,
    "my_var[tag1='x']" => 4,
)

function NumExpr.eval_expr(var::Variable)
    return get(isglobal_scope(var) ? global_vars : local_vars, var[], NaN)
end

function NumExpr.call(::Func{:maximum}, x::Number...)
    return maximum(x)
end

function NumExpr.call(::Func{:sin}, x::Number)
    return sin(x)
end

expr = parse_expr("sin(maximum({my_var}, [my_var], my_var{tag1='x'}, my_var[tag1='x'])) + 10");

julia> eval_expr(expr)
9.243197504692072
```

The package lets you set up an expression and then calculate it using data from anywhere, like databases or APIs.

```julia
using Serde
using EasyCurl

using NumExpr
using NumExpr: Func, Variable, NumVal, StrVal, ExprNode, GlobalScope, LocalScope

struct VarCtx
    base_url::String
end

struct avgPrice
    price::Float64
end

function my_eval(ctx::VarCtx, var::Variable{GlobalScope})
    http_request = curl_get(ctx.base_url, query = "symbol=" * var[])
    return deser_json(avgPrice, curl_body(http_request)).price
end

my_eval(::VarCtx, x::NumVal) = x[]
my_eval(::VarCtx, x::StrVal) = x[]

function my_eval(ctx::VarCtx, node::ExprNode)
    args = map(x -> my_eval(ctx, x), node.args)
    return call(ctx, node.head, args...)
end

call(::VarCtx, x...) = NumExpr.call(x...)

const local_parameters = Dict{String,Float64}(
    "rtol" => 1e-3, 
    "atol" => 1e-2
)

function my_eval(::VarCtx, var::Variable{LocalScope})
    return get(local_parameters, var[], NaN)
end

function NumExpr.call(::Func{:isapprox}, x::Number, y::Number, atol::Number, rtol::Number)
    return isapprox(x, y; atol, rtol)
end

vars_context = VarCtx("https://api.binance.com/api/v3/avgPrice")

node = parse_expr("isapprox([ADABTC] * [BTCUSDT], [ADAUSDT], atol, rtol)")

julia> my_eval(vars_context, node)
true
```

## Contributing
Contributions to NumExpr are welcome! If you encounter a bug, have a feature request, or would like to contribute code, please open an issue or a pull request on GitHub.
