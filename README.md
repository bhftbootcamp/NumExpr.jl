<img src=docs/src/assets/readme_logo.png height=70 width=auto>

# ExprParser

The ExprParser library is designed to handle and evaluate arithmetic expressions. It enables parsing and analyzing expressions, as well as performing calculations with user-defined functions.

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://bhftbootcamp.github.io/ExprParser.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://bhftbootcamp.github.io/ExprParser.jl/dev/)
[![Build Status](https://github.com/bhftbootcamp/ExprParser.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/bhftbootcamp/ExprParser.jl/actions/workflows/CI.yml?query=branch%3Amaster)
[![Coverage](https://codecov.io/gh/bhftbootcamp/ExprParser.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/bhftbootcamp/ExprParser.jl)

## Installation
To install ExprParser, simply use the Julia package manager:

```julia
] add ExprParser
```

## Usage

Here is an example usage of ExprParser:

```julia
using ExprParser
using ExprParser: Func, Variable

const local_vars = Dict{String,Float64}(
    "my_var"           => 1,
    "my_var{tag1='x'}" => 2,
)

const global_vars = Dict{String,Float64}(
    "my_var"           => 3,
    "my_var[tag1='x']" => 4,
)

function ExprParser.eval_expr(var::Variable)
    return get(isglobal_scope(var) ? global_vars : local_vars, var[], NaN)
end

function ExprParser.call(::Func{:maximum}, x::Number...)
    return maximum(x)
end

function ExprParser.call(::Func{:sin}, x::Number)
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

using ExprParser
using ExprParser: Func, Variable, NumVal, StrVal, ExprNode, GlobalScope, LocalScope

# First, we define a structure that will define the context of the variables used
struct VarCtx
    base_url::String
end

# Let's declare a structure for which data from some API will be deserialized
struct avgPrice
    price::Float64
end

# And define a method for loading data by trading pair name
# Note that this function will only be called when the expression is evaluated
function my_eval(ctx::VarCtx, var::Variable{GlobalScope})
    http_request = curl_get(ctx.base_url, query = "symbol=" * var[])
    return deser_json(avgPrice, curl_body(http_request)).price
end

# Support function that will evaluate string or numeric values of the expression
my_eval(::VarCtx, x::NumVal) = x[]
my_eval(::VarCtx, x::StrVal) = x[]

# The main method of the 'my_eval' function which will evaluate the parsed expression
function my_eval(ctx::VarCtx, node::ExprNode)
    args = map(x -> my_eval(ctx, x), node.args)
    return call(ctx, node.head, args...)
end

call(::VarCtx, x...) = ExprParser.call(x...)

# We can also define our own local variables needed in the process of evaluating the expression
const local_parameters = Dict{String, Float64}(
    "rtol" => 1e-3,
    "atol" => 1e-2,
)

# Let's also define a method that will retrieve these internal variables.
function my_eval(::VarCtx, var::Variable{LocalScope})
    return get(local_parameters, var[], NaN)
end

# Finally, for all of the above, we can define a new function that will be called during the evaluation of the expression
function ExprParser.call(::Func{:isapprox}, x::Number, y::Number, atol::Number, rtol::Number)
    return isapprox(x, y; atol, rtol)
end

# Now we can make required context with variables ctx
vars_context = VarCtx("https://api.binance.com/api/v3/avgPrice")

# This line will parse the passed expression
node = parse_expr("isapprox([ADABTC] * [BTCUSDT], [ADAUSDT], atol, rtol)")

# This line will evaluate the parsed expression
my_eval(vars_context, node)
```


## Contributing
Contributions to ExprParser are welcome! If you encounter a bug, have a feature request, or would like to contribute code, please open an issue or a pull request on GitHub.
