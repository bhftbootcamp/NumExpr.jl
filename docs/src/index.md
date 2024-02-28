# NumExpr.jl

The NumExpr library is designed to parse and evaluate arithmetic expressions. It allows for the analysis of these expressions and can perform calculations using user-defined functions.

## Quickstart

Simple example of basic usage.

```julia
using NumExpr
using NumExpr: Func, Variable

colors = Dict{String,UInt32}(
    "color"                 => 0xffffff,
    "color[name='red']"     => 0xff0000,
    "color[name='green']"   => 0x00ff00,
    "color[name='blue']"    => 0x0000ff,
    "color[name='yellow']"  => 0xffff00,
    "color[name='cyan']"    => 0x00ffff,
    "color[name='magenta']" => 0xff00ff,
)

NumExpr.eval_expr(var::Variable) = get(colors, var[], NaN)

function NumExpr.call(::Func{:mix_colors}, c1::UInt32, c2::UInt32)
    r = ((c1 >> 16) & 0xFF + (c2 >> 16) & 0xFF) >> 1
    g = ((c1 >> 8)  & 0xFF + (c2 >> 8)  & 0xFF) >> 1
    b = (c1         & 0xFF +  c2        & 0xFF) >> 1
    return (r << 16) | (g << 8) | b
end

expr = parse_expr("mix_colors(color[name='red'], color[name='green'])")

eval_expr(expr)
```
