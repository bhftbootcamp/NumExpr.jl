# [Expression Syntax](@id syntax)

This section outlines the basic syntax rules that expressions must adhere to.

## [Numeric values](@id numeric_vals)

Integer values, floating-point values, and exponential notation values can be used in expressions.
```julia-repl
julia> expr = parse_expr("42")
42.0

julia> typeof(expr)
NumVal{Float64}

julia> eval_expr(expr)
42.0
```
During parsing, numeric values correspond to the `Number` type.

### Operations on Numbers

The following operations are defined for numeric values:
- Arithmetic:
  - `+`: addition
  - `-`: subtraction
  - `*`: multiplication
  - `/`: division
  - `^`: exponentiation


```julia-repl
julia> expr = parse_expr("1 + 2 * 3")
ExprNode(
  +,
  Union{AbstractExpr, ExprNode}[
    1.0,
    ExprNode(
      *,
      Union{AbstractExpr, ExprNode}[
        2.0,
        3.0
      ],
    ),
  ],
)

julia> typeof(expr)
ExprNode

julia> eval_expr(expr)
7.0
```

- Logical:
  - `>`: greater than
  - `<`: less than
  - `>=`: greater than or equal to
  - `<=`: less than or equal to
  - `!=`: not equal to
  - `==`: equal to

```julia-repl
julia> expr = parse_expr("1 < 3")
ExprNode(
  <,
  Union{AbstractExpr, ExprNode}[
    1.0,
    3.0
  ],
)

julia> typeof(expr)
ExprNode

julia> eval_expr(expr)
true
```

- Mathematical:
  - `abs`: absolute value
  - `sqrt`: square root
  - `sin`: sine
  - `cos`: cosine
  - `atan`: arctangent
  - `exp`: exponent
  - `log`: logarithm

```julia-repl
julia> expr = parse_expr("abs(-1) + cos(0)")
ExprNode(+
  Union{AbstractExpr, ExprNode}[
    ExprNode(
      abs,
      Union{AbstractExpr, ExprNode}[
        ExprNode(
          -,
          Union{AbstractExpr, ExprNode}[
            1.0
          ],
        ),
      ],
    ), 
    ExprNode(
      cos,
      Union{AbstractExpr, ExprNode}[
        0.0
      ],
    ),
  ],
)

julia> typeof(expr)
ExprNode

julia> eval_expr(expr)
2.0
```

## [String values](@id string_vals)

Expressions can also contain string values by enclosing them with single quotes (`'`) on both sides.
```julia-repl
julia> expr = parse_expr(" 'its my string' ")
its my string

julia> typeof(expr)
StrVal

julia> eval_expr(expr)
"its my string"
```
Inside such a string, no other single quote characters can be present.
During parsing, string values correspond to the `String` type.

### Operations on Strings

The following operations are defined for string values:
- `*`: concatenation
- `^`: repetition
- Logical:
  - `>`: greater than
  - `<`: less than
  - `>=`: greater than or equal to
  - `<=`: less than or equal to
  - `!=`: not equal to
  - `==`: equal to

```julia-repl
julia> expr = parse_expr("'Julia' * 'Lang' * '❤️'")
ExprNode(
  *,
  Union{AbstractExpr, ExprNode}[
    Julia,
    Lang,
    ❤️,
  ],
)

julia> eval_expr(expr)
"JuliaLang❤️"
```

## [Variables](@id variable_vals)

Finally, the most important type of values are variable values. Referring to them within an expression can consist of two parts:
- (required) the regular variable name according to the [variable naming rules](https://docs.julialang.org/en/v1/manual/variables/#man-allowed-variable-names).
- (optional) tags related to this variable.

Let's take a closer look at the syntax for the tag system:
- Tags are specified inside curly braces `{}` or square brackets `[]` immediately following the variable name.
- Tags can be specified in any order and are listed with commas without spaces.
- Tags consist of a key-value pairs in the form of `key='value'`.
- The name should contain only letters and numbers without spaces, and the first character of the name should be a letter.
- The tag value must be a [string value](@ref string_vals).

!!! note
    Tags can be used as an extended variable name.

### Variable scopes



For convenience, variables can be classified into local and global ones.
The user can define which variables belong to which of such formats.

For the following examples, we will declare two dictionaries that will be responsible for global and local variables:
```julia
const local_vars = Dict{String,Float64}(
    "var"              => 1,
    "var{tag='value'}" => 2,
)

const global_vars = Dict{String,Float64}(
    "var"              => 3,
    "var[tag='value']" => 4,
)
```

As well as a function that will extract the values of variables in the process of calculating expressions
```julia
function ExprParser.eval_expr(var::ExprParser.Variable)
    return get(isglobal_scope(var) ? global_vars : local_vars, var[], NaN)
end
```

!!! note
    Currently, this is done only to facilitate the separation of variables into two formats and is not related to scope.
    This division is intended for implementing additional functionality.

During parsing, local variables correspond to the type `Variable{LocalScope}`, and global ones to `Variable{GlobalScope}`.

#### Local variables

Local variables specified when using `{}` brackets for tags or in the absence of a tag.

By default:
```julia-repl
julia> expr = parse_expr("var")
var

julia> typeof(expr)
Variable{LocalScope}

julia> var = eval_expr(expr)
1.0

julia> typeof(var)
Float64
```

By local tag:
```julia-repl
julia> expr = parse_expr("var{tag='value'}")
var{tag='value'}

julia> typeof(expr)
Variable{LocalScope}

julia> var = eval_expr(expr)
2.0
```

Calling a local variable without tags:
```julia-repl
julia> expr = parse_expr("{var}")
var

julia> eval_expr(expr)
1.0
```

#### Global variables

Global variables specified when using `[]` brackets for tags.

Calling a global variable without tags:
```julia-repl
julia> expr = parse_expr("[var]")
var

julia> typeof(expr)
Variable{GlobalScope}

julia> eval_expr(expr)
3.0
```

By global tag:
```julia-repl
julia> expr = parse_expr("var[tag='value']")
var[tag='value']

julia> typeof(expr)
Variable{GlobalScope}

julia> eval_expr(expr)
4.0
```

### Variable values

To interpret the variables specified in the expression as concrete values during the calculation process, the following steps need to be taken:
- Determine the data source from which variables can be extracted using their full name (including tags, which should be sorted in alphabetical order). For example, a dictionary:
```julia
colors = Dict{String, UInt32}(
    "color"                 => 0xffffff,
    "color[name='red']"     => 0xff0000,
    "color[name='green']"   => 0x00ff00,
    "color[name='blue']"    => 0x0000ff,
    "color[name='yellow']"  => 0xffff00,
    "color[name='cyan']"    => 0x00ffff,
    "color[name='magenta']" => 0xff00ff,
)
```

!!! note
    The full name of a `Variable` type variable can be obtained by applying the unary operator `[]` to the object.

- Then, it is necessary to overload the function that will extract variable values from their source.
For example, let's request the value for the variable name `var` from the `colors` dictionary:
```julia
ExprParser.eval_expr(var::ExprParser.Variable) = get(colors, var[], NaN)
```

Now, during the evaluation of the expression, variables will be interpreted as numbers.
```julia-repl
julia> expr = parse_expr("color");

julia> eval_expr(expr)
0x00ffffff

julia> expr = parse_expr("color[name='red'] + color[name='green'] + color[name='blue']");

julia> eval_expr(expr)
0x0000000000ffffff
```

## [Custom Functions](@id custom_func)

In addition to predefined functions, users can define their own.
To define a new operation on the elements mentioned earlier, you need to define a new method for the `ExprParser.call` function.
- The first argument of such a method should be of type `::ExprParser.Func{:S}`, where `S` is the name of the new function.
- Subsequent arguments should correspond to the required arguments of the defined function.

For example, for a function `max(x::Number, y::Number)`, you need to define the following method:
```julia
function ExprParser.call(::ExprParser.Func{:max}, x::Number, y::Number)
    return max(x, y)
end
```

Now, expressions containing such a function can be correctly processed.
```julia-repl
julia> expr = parse_expr("max(5, 10) + max(20, 3)");

julia> eval_expr(expr)
30.0
```

For functions with an unknown number of arguments the method can look like this:
```julia
function ExprParser.call(::ExprParser.Func{:sum}, x::Number...)
    return sum(x)
end
```
Now we can call the `sum` function with any number of arguments.
```julia-repl
julia> expr = parse_expr("sum(6, 4) + sum(5, 15, 10)");

julia> eval_expr(expr)
40.0
```
