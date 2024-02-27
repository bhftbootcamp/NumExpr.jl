# [Examples](@id base_examples)

Here you can find various examples of how you can utilize this package.

## Basic use

```julia
using ExprParser
using ExprParser: Func, Arithmetic, Variable

const local_vars = Dict{String,Float64}(
    "y"               => 100,
    "y{local='true'}" => 300,
)

const global_vars = Dict{String,Float64}(
    "x"              => 100,
    "x[test='a']"    => 150,
    "x[a='a',b='b']" => 200,
)

function ExprParser.eval_expr(var::Variable)
    return get(isglobal_scope(var) ? global_vars : local_vars, var[], NaN)
end

function ExprParser.call(::Func{:sum}, x::Number...)
    return sum(x)
end

function ExprParser.call(::Func{:sin}, x::Number)
    return sin(x)
end

function ExprParser.call(::Func{:argsmax}, x::Number...)
    return maximum(x)
end

function ExprParser.call(::Func{:log}, x::String, y::Number...)
    return reduce((s, v) -> replace(s, "%s" => string(v), count = 1), y, init = x)
end

function ExprParser.call(::Func{:firstnotnan}, x::Number...)
    for v in x
        !isnan(v) && return v
    end
    return NaN
end

node = parse_expr("2.0 * sin(1) + 2/2.0 * (2.1) * sin(1)")
eval_expr(node)

node = parse_expr("1 + 3 * 2 + 4 + sum(1,2,4,5,6,7,) - 10")
eval_expr(node)

node = parse_expr("firstnotnan(NaN, NaN, 11, 23)")
eval_expr(node)

node = parse_expr("1 + 2^3 + 4")
eval_expr(node)

node = parse_expr("[x] + y + 1")
eval_expr(node)

node = parse_expr("2 + + 1")
eval_expr(node)

node = parse_expr("1 + 3 * 2 == 3")
eval_expr(node)

node = parse_expr("-(3+1)")
eval_expr(node)

node = parse_expr("'a' * 'b'")
eval_expr(node)

node = parse_expr("'a' ^ 10")
eval_expr(node)

node = parse_expr("argsmax(1,2,3,5555)")
eval_expr(node)

node = parse_expr("log('lol %s %s %s', 1, 2, 3) ^ 10")
eval_expr(node)

node = parse_expr("x[b='b', a='a'] + y + 3")
eval_expr(node)

node = parse_expr("x[a='a',b='b'] + y + 3")
eval_expr(node)

node = parse_expr("y{local='true'} + 0")
eval_expr(node)

node = parse_expr("x[] + 0")
eval_expr(node)
```

## Color mixer

```julia
using ExprParser
using ExprParser: Func, Variable

colors = Dict{String,UInt32}(
    "color"                 => 0xffffff,
    "color[name='red']"     => 0xff0000,
    "color[name='green']"   => 0x00ff00,
    "color[name='blue']"    => 0x0000ff,
    "color[name='yellow']"  => 0xffff00,
    "color[name='cyan']"    => 0x00ffff,
    "color[name='magenta']" => 0xff00ff,
)

ExprParser.eval_expr(var::Variable) = get(colors, var[], NaN)

function ExprParser.call(::Func{:mix_colors}, c1::UInt32, c2::UInt32)
    r = ((c1 >> 16) & 0xFF + (c2 >> 16) & 0xFF) >> 1
    g = ((c1 >> 8)  & 0xFF + (c2 >> 8)  & 0xFF) >> 1
    b = (c1         & 0xFF +  c2        & 0xFF) >> 1
    return (r << 16) | (g << 8) | b
end

"mix_colors(color[name='red'], color[name='green'])" |> parse_expr |> eval_expr
```

## Requesting `avgPrice` data from some API

```julia
using Serde
using EasyCurl

using ExprParser
using ExprParser: Func, Variable, NumVal, StrVal, ExprNode, GlobalScope, LocalScope

# First, we define a context for the variables used
struct VarCtx
    base_url::String
end

# Then, let's declare a structure that will hold API response data
struct AvgPrice
    price::Float64
end

# And define a method for loading data by trading pair names
# Note that this function will only be called when the expression is evaluated
function my_eval(ctx::VarCtx, var::Variable{GlobalScope})
    http_request = curl_get(ctx.base_url, query = "symbol=" * var[])
    return deser_json(AvgPrice, curl_body(http_request)).price
end

# Support functions that evaluate string and numeric values of the expression
my_eval(::VarCtx, x::NumVal) = x[]
my_eval(::VarCtx, x::StrVal) = x[]

# The main method of the 'my_eval' function which will evaluate the parsed expression
function my_eval(ctx::VarCtx, node::ExprNode)
    args = map(x -> my_eval(ctx, x), node.args)
    return call(ctx, node.head, args...)
end

call(::VarCtx, x...) = ExprParser.call(x...)

# We can also define our own local variables for the evaluation process
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

# Now we can initialise the context for our expression
vars_context = VarCtx("https://api.binance.com/api/v3/avgPrice")

# Then we parse it
node = parse_expr("isapprox([ADABTC] * [BTCUSDT], [ADAUSDT], atol, rtol)")

# And finally evaluate it
my_eval(vars_context, node)
```
