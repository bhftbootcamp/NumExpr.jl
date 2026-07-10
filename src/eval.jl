# eval

#__ Logic

call(::Logic{:(>)}, x::Number, y::Number)  = x > y
call(::Logic{:(<)}, x::Number, y::Number)  = x < y
call(::Logic{:(<=)}, x::Number, y::Number) = x <= y
call(::Logic{:(>=)}, x::Number, y::Number) = x >= y
call(::Logic{:(!=)}, x::Number, y::Number) = x != y
call(::Logic{:(==)}, x::Number, y::Number) = x == y

call(::Logic{:&&}, x::Number, y::Number) = (x != 0) && (y != 0)
call(::Logic{:||}, x::Number, y::Number) = (x != 0) || (y != 0)

call(::Logic{:(>)}, x::String, y::String)  = x > y
call(::Logic{:(<)}, x::String, y::String)  = x < y
call(::Logic{:(<=)}, x::String, y::String) = x <= y
call(::Logic{:(>=)}, x::String, y::String) = x >= y
call(::Logic{:(!=)}, x::String, y::String) = x != y
call(::Logic{:(==)}, x::String, y::String) = x == y

#__ Arithmetic

call(::Arithmetic{:(+)}, x::Number, y::Number) = x + y
call(::Arithmetic{:(-)}, x::Number, y::Number) = x - y
call(::Arithmetic{:(*)}, x::Number, y::Number) = x * y
call(::Arithmetic{:(/)}, x::Number, y::Number) = x / y
call(::Arithmetic{:(^)}, x::Number, y::Number) = x^y
call(::Arithmetic{:(%)}, x::Number, y::Number) = x % y

call(::Arithmetic{:(+)}, x::Number...) = sum(x)
call(::Arithmetic{:(-)}, x::Number...) = foldl(-, x)
call(::Arithmetic{:(*)}, x::Number...) = foldl(*, x)
call(::Arithmetic{:(/)}, x::Number...) = foldl(/, x)
call(::Arithmetic{:(^)}, x::Number...) = foldl(^, x)
call(::Arithmetic{:(%)}, x::Number...) = foldl(%, x)

call(::Arithmetic{:(+)}, x::Number) = +x
call(::Arithmetic{:(-)}, x::Number) = -x

call(::Arithmetic{:(*)}, x::String...) = *(x...)
call(::Arithmetic{:(^)}, x::String, y::Number) = x^Int64(y)

#__ Functions

call(::Func{:sqrt}, x::Number) = sqrt(x)
call(::Func{:abs}, x::Number)  = abs(x)
call(::Func{:sin}, x::Number)  = sin(x)
call(::Func{:cos}, x::Number)  = cos(x)
call(::Func{:tg}, x::Number)   = tan(x)
call(::Func{:ctg}, x::Number)  = cot(x)
call(::Func{:atan}, x::Number) = atan(x)
call(::Func{:exp}, x::Number)  = exp(x)
call(::Func{:log}, x::Number)  = log(x)
call(::Func{:div}, x::Number, y::Number) = div(x, y)
call(::Func{:rem}, x::Number, y::Number) = rem(x, y)
call(::Func{:mean}, x::Number...) = sum(x) / length(x)

call(::Func{:isnan}, x::Number)  = Float64(isnan(x))
call(::Func{:not}, x::Number)    = isnan(x) ? NaN : Float64(x == 0)
call(::Func{:iszero}, x::Number) = Float64(x == 0)
call(::Func{:isone}, x::Number)  = Float64(x == 1)
call(::Func{:floor}, x::Number)  = floor(x)
call(::Func{:ceil}, x::Number)   = ceil(x)
call(::Func{:max}, a::Number, b::Number)    = max(a, b)
call(::Func{:min}, a::Number, b::Number)    = min(a, b)
call(::Func{:ifelse}, c::Number, a::Number, b::Number) = isnan(c) ? NaN : (c != 0 ? a : b)
call(::Func{:get}, a::Number, b::Number)    = isnan(a) ? b : a
call(::Func{:round}, a::Number, b::Number)  = isnan(b) ? NaN : round(a; digits = Int(b))
call(::Func{:isless}, a::Number, b::Number) = Float64(isless(a, b))

#__ convert

Base.convert(::Type{Number}, x::NumVal) = x[]
Base.convert(::Type{String}, x::StrVal) = x[]

#__ eval_expr

"""
    eval_expr(x::Variable)

This function defines the behavior when evaluating the values of variables in a parsed expression.

!!! note
    Initially, this function simply returns the value `x`, but can be overloaded to define new behavior for retrieving variable data from a new source.

For more information see [variables](@ref variable_vals).

## Examples

```julia-repl
julia> colors = Dict{String,UInt32}(
           "color[name='red']"   => 0xff0000,
           "color[name='green']" => 0x00ff00,
           "color[name='blue']"  => 0x0000ff,
       );

julia> NumExpr.eval_expr(var::NumExpr.Variable) = get(colors, var[], NaN)

julia> expr = parse_expr("color[name='red'] + color[name='blue']");

julia> eval_expr(expr)
0x00ff00ff
```
"""
eval_expr(x::Variable) = x
eval_expr(x::NumVal) = x[]
eval_expr(x::StrVal) = x[]

"""
    eval_expr(expr::ExprNode)

Evaluate the expression object `expr` obtained after parsing by the function [`parse_expr`](@ref).

For more information see [syntax guide](@ref syntax).

## Examples

```julia-repl
julia> expr = parse_expr("1 + 2^3 + 4");

julia> eval_expr(expr)
13.0

julia> expr = parse_expr("sin(10)^2 + cos(10)^2");

julia> eval_expr(expr)
1.0

julia> expr = parse_expr("'a' * 'b'");

julia> eval_expr(expr)
"ab"
```
"""
function eval_expr(node::ExprNode)
    args = map(eval_expr, node.args)
    return call(node.head, args...)
end
