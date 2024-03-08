# parser

struct Comma <: AbstractLexisOperator end
struct LPar  <: AbstractLexisOperator end
struct RPar  <: AbstractLexisOperator end

Base.show(io::IO, ::LPar) = print(io, "(")
Base.show(io::IO, ::RPar) = print(io, ")")
Base.show(io::IO, ::Comma) = print(io, ",")

struct Logic{x} <: AbstractLogicOperator
    Logic{x}() where {x} = new{x}()
end

Logic(x::Symbol) = Logic{x}()
Logic(x::Char...) = Logic(Symbol(x...))
Logic(x::String) = Logic(Symbol(x))
operator(::Logic{x}) where {x} = x

struct Arithmetic{x} <: AbstractArithmeticOperator
    Arithmetic{x}() where {x} = new{x}()
end

Arithmetic(x::Symbol) = Arithmetic{x}()
Arithmetic(x::Char...) = Arithmetic(Symbol(x...))
Arithmetic(x::String) = Arithmetic(Symbol(x))
operator(::Arithmetic{x}) where {x} = x

struct Func{x} <: AbstractFuncOperator
    Func{x}() where {x} = new{x}()
end

Func(x::Char...) = Func{Symbol(x...)}()
operator(::Func{x}) where {x} = x

Base.show(io::IO, n::AbstractOperator) = print(io, operator(n))

"""
    Variable{S<:AbstractScope}

Represents custom user defined variable in expression after parsing.
Type `S` must be one of `LocalScope` or `GlobalScope`.

!!! note
    Full name of the variable can be obtain by empty operator of getting index e.g `[]`.
    It may be usefull in some function overloadings.

For more information see section [Variables](@ref variable_vals).

## Fields
- `val::String`: Full name of the variable including its tags.
- `name::String`: The variable name without tags
- `tags::Dict{String,String}`: Tags of the variable.

## Examples

```julia-repl
julia> const vars = Dict{String,Float64}(
           "var"              => 1,
           "var{tag='value'}" => 2,
       );

julia> NumExpr.eval_expr(var::NumExpr.Variable) = get(vars, var[], NaN)

julia> var = parse_expr("var{tag='value'}")
var{tag='value'}

julia> typeof(var)
NumExpr.Variable{NumExpr.LocalScope}

julia> var_name(var)
"var"

julia> var_tags(var)
Dict{String, String} with 1 entry:
  "tag" => "value"

julia> var[]
"var{tag='value'}"
```
"""
struct Variable{S<:AbstractScope} <: AbstractValue
    val::String
    name::String
    tags::Dict{String,String}
end

(isglobal_scope(::Variable{S})::Bool) where {S<:AbstractScope} = S <: GlobalScope
(islocal_scope(::Variable{S})::Bool) where {S<:AbstractScope} = S <: LocalScope

struct StrVal <: AbstractValue
    val::String

    StrVal(v::Vector{Char}) = new(String(v))
end

struct NumVal{T<:Real} <: AbstractValue
    val::T

    NumVal{T}(v::Vector{Char}) where {T<:Real} = new{T}(Base.parse(T, String(v)))
end

var_name(x::Variable) = x.name
var_tags(x::Variable) = x.tags
Base.getindex(x::AbstractValue) = getfield(x, :val)
Base.show(io::IO, n::AbstractValue) = print(io, n[])

#__ Variable Parsing

function parse_var_format1(::Type{S}, chars::Vector{Char}) where {S<:AbstractScope}
    str_val = String(chars)
    return Variable{S}(str_val, str_val, Dict{String,String}())
end

function parse_var_format2(::Type{S}, chars::Vector{Char}) where {S<:AbstractScope}
    tags = Dict{String,String}()
    len = length(chars)
    name, key, value = "", "", ""
    index = 1
    # find the variable name before the '[' or '{'
    while index <= len && !isopenbracket(S, chars[index])
        if isletter(chars[index]) || isunderline(chars[index])
            name *= chars[index]
        end
        index += 1
    end
    isempty(name) && @err_syntax "invalid indicator: $(String(chars))"
    # skip the '[' or '{'
    index += 1
    # parse the key-value pairs
    while index <= len && !isclosebracket(S, chars[index])
        if isletter(chars[index])
            key_start = index
            while index <= len && (isletter(chars[index]) || isdigit(chars[index]))
                index += 1
            end
            key = String(chars[key_start:index-1])
        elseif isquote(chars[index])
            if key == ""
                @err_syntax "no key for value at index $index: $(String(chars[index:end]))"
            end
            value_start = index + 1 # skip the opening quote
            index = value_start
            while index <= len && !isquote(chars[index])
                index += 1
            end
            index > len && @err_syntax "unterminated string in $(String(chars))"
            value = String(chars[value_start:index-1])
            tags[key] = value
            key = ""    # clear the key
            index += 1  # skip the closing quote
        elseif isequal(chars[index])
            index += 1  # skip the delimiter
        elseif iscomma(chars[index])
            index += 1  # skip the comma and whitespace
            while index <= len && isspace(chars[index])
                index += 1
            end
        else
            @err_syntax "unrecognized character '$(chars[index])'\
                         in $(String(chars)) at index $index"
        end
    end
    if (index > len) || !isclosebracket(S, chars[index])
        @err_syntax "missing closing bracket in $(String(chars))"
    end
    return Variable{S}(to_var(S, name, tags), name, tags)
end

#__ Tokenize

function skip_while(
    condition::Function,
    chars::Vector{Char},
    index::UInt64,
    len::UInt64,
)::UInt64
    while condition(chars[index]) && index != len
        index += 1
    end
    return index
end

function tokenize(h::Vector{Char})::Vector{AbstractExpr}
    len::UInt64 = length(h)
    exprs::Vector{AbstractExpr} = AbstractExpr[]
    l::UInt64, r::UInt64 = 1, 1
    lpar::UInt64, rpar::UInt64 = 0, 0

    while r <= len
        l = r
        if isspace(h[r])
            r += 1
        elseif isnumber(h[r])
            r = skip_while(x -> isnumber(x) || isunderline(x), h, r + 1, len)
            if isdot(h[r])
                r = skip_while(x -> isnumber(x) || isunderline(x), h, r + 1, len)
            end
            if isexponent(h[r])
                r += 1
                isplusmin(h[r]) && (r += 1)
                prev = r
                r = skip_while(x -> isnumber(x) || isunderline(x), h, r, len)
                r == prev && @err_syntax "invalid number in e notation"
            end
            push!(exprs, NumVal{Float64}(h[l:r-1]))
        elseif islsquare(h[r])
            r = skip_while(x -> !isrsquare(x) && !islsquare(x), h, r + 1, len)
            r == len && @err_syntax "space before ']' not allowed"
            islsquare(h[r]) && @err_syntax "extra token '[' after end of expression"
            push!(exprs, parse_var_format1(GlobalScope, h[l+1:r-1]))
            r += 1
        elseif islbrace(h[r])
            r = skip_while(x -> !isrbrace(x) && !islbrace(x), h, r + 1, len)
            r == len && @err_syntax "space before '}' not allowed"
            islbrace(h[r]) && @err_syntax "extra token '{' after end of expression"
            push!(exprs, parse_var_format1(LocalScope, h[l+1:r-1]))
            r += 1
        elseif issinglequote(h[r])
            r + 1 == len && @err_syntax "quote symbol after end of expression"
            r = skip_while(x -> !issinglequote(x), h, r + 1, len)
            r == len && @err_syntax "quote expression is not properly closed"
            push!(exprs, StrVal(h[l+1:r-1]))
            r += 1
        elseif isalphabetic(h[r])
            r = skip_while(x -> isalphabetic(x) ||
                                isnumber(x)     ||
                                isunderline(x), h, r + 1, len)
            if isdot(h[r]) && (r < len) && islpar(h[r+1])
                @err_syntax "broadcasting prohibited"
            end
            r = skip_while(x -> isalphabetic(x) ||
                                isnumber(x)     ||
                                isunderline(x)  ||
                                isdot(x), h, r, len)
            chars = h[l:r-1]
            char_length = r - l
            expr = if islpar(h[r])
                Func(chars...)
            elseif islsquare(h[r])
                l = r + 1
                r = skip_while(x -> !isrsquare(x) && !islsquare(x), h, r + 1, len)
                r == len && @err_syntax "space before ']' not allowed"
                islsquare(h[r]) && @err_syntax "extra token '[' after end of expression"
                r += 1
                parse_var_format2(GlobalScope, [chars; h[l-1:r-1]])
            elseif islbrace(h[r])
                l = r + 1
                r = skip_while(x -> !isrbrace(x) && !islbrace(x), h, r + 1, len)
                r == len && @err_syntax "space before '}' not allowed"
                islbrace(h[r]) && @err_syntax "extra token '{' after end of expression"
                r += 1
                parse_var_format2(LocalScope, [chars; h[l-1:r-1]])
            elseif char_length == 3 && isnannumber(chars...)
                NumVal{Float64}(chars)
            elseif (char_length == 4 && istruenumber(chars...)) ||
                   (char_length == 5 && isfalsenumber(chars...))
                NumVal{Bool}(chars)
            else
                parse_var_format1(LocalScope, chars)
            end
            push!(exprs, expr)
        elseif iscomma(h[r])
            push!(exprs, Comma())
            r += 1
        elseif islpar(h[r])
            push!(exprs, LPar())
            r += 1
            lpar += 1
        elseif isrpar(h[r])
            push!(exprs, RPar())
            r += 1
            rpar += 1
        elseif ismultilogical(h[r], h[r+1])
            push!(exprs, Logic(h[r], h[r+1]))
            r += 2
        elseif issimplelogical(h[r])
            push!(exprs, Logic(h[r]))
            r += 1
        elseif isarithmetic(h[r])
            push!(exprs, Arithmetic(h[r]))
            r += 1
        else
            @err_syntax "invalid identifier name '$(h[r])'"
        end
    end

    (rpar > lpar) &&
        @err_syntax "extra token ')' after end of expression"

    (lpar > rpar) &&
        @err_syntax "extra token '(' after end of expression"

    return exprs
end

#__ ExprTree

priority(::RPar)               = -1
priority(::LPar)               = -1
priority(::Comma)              = -1

priority(::Logic{:||})         = 0
priority(::Logic{:&&})         = 1

priority(::Logic{:>})          = 2
priority(::Logic{:<})          = 2
priority(::Logic{:<=})         = 2
priority(::Logic{:>=})         = 2
priority(::Logic{:!=})         = 2
priority(::Logic{:(==)})       = 2

priority(::Arithmetic{:+})     = 3
priority(::Arithmetic{:-})     = 3
priority(::Arithmetic{:%})     = 4
priority(::Arithmetic{:/})     = 5
priority(::Arithmetic{:*})     = 5
priority(::Arithmetic{:^})     = 6

priority(::Type{AbstractExpr}) = 7
priority(::Type{Func})         = 8

function Base.isless(l::L, r::R)::Bool where {L<:AbstractExpr,R<:AbstractExpr}
    return isless(priority(l), priority(r))
end

function Base.:(==)(l::L, r::R)::Bool where {L<:AbstractExpr,R<:AbstractExpr}
    return priority(l) == priority(r)
end

function Base.:(==)(l::L, r::R)::Bool where {L<:Variable,R<:Variable}
    return l[] == r[]
end

mutable struct ExprTree
    const exprs::Vector{AbstractExpr}
    const length::Int64
    position::Int64

    ExprTree(exprs::Vector{AbstractExpr}) = new(exprs, length(exprs), 1)
end

"""
    ExprNode

Represents a transitional nested obejct obtained after parsing by [`parse_expr`](@ref) function.
Used by [`eval_expr`](@ref) function for evaluations an expression.

## Fields
- `head::AbstractExpr`: Leading variable or operation of current expression layer.
- `args::Vector{Union{AbstractExpr,ExprNode}}`: Elements of current expression node such as variables or another operations.
"""
struct ExprNode
    head::AbstractExpr
    args::Vector{Union{AbstractExpr,ExprNode}}
end

function expr(::Type{AbstractExpr}, tree::ExprTree)
    next = tree.exprs[tree.position]
    if next isa Arithmetic{:+} || next isa Arithmetic{:-}
        tree.position += 1
        result = expr(AbstractExpr, tree)
        return ExprNode(next, Union{AbstractExpr,ExprNode}[result])
    elseif next isa Func
        result = expr(Func, tree)
        tree.position += 1
        return result
    elseif next isa LPar
        tree.position += 1
        result = expr(tree)
        tree.position += 1
        return result
    end
    tree.position += 1
    return next
end

function expr(::Type{Func}, tree::ExprTree)
    func::Func = tree.exprs[tree.position]
    tree.position += 2
    args = Union{AbstractExpr,ExprNode}[]

    while !(tree.exprs[tree.position] isa RPar)
        if tree.exprs[tree.position] isa Comma
            tree.position += 1
            continue
        end
        push!(args, expr(tree))
    end

    return ExprNode(func, args)
end

function expr(tree::ExprTree, precedence::Int64 = 0)
    priority(AbstractExpr) == precedence && return expr(AbstractExpr, tree)
    priority(Func)         == precedence && return expr(Func, tree)

    left = expr(tree, precedence + 1)
    while tree.position <= length(tree.exprs)
        head = tree.exprs[tree.position]
        if priority(head) == precedence
            tree.position += 1
        else
            break
        end
        right = expr(tree, precedence + 1)
        if (left isa ExprNode) && (left.head === head) && length(left.args) > 1
            push!(left.args, right)
        else
            left = ExprNode(head, Union{AbstractExpr,ExprNode}[left, right])
        end
    end

    return left
end

"""
    parse_expr(str::AbstractString) -> ExprNode

Parse the string expression `x` and turn it into nested [`ExprNode`](@ref) that can be evaluated by [`eval_expr`](@ref).

For more information see [syntax guide](@ref syntax).

## Examples

```julia-repl
julia> colors = Dict{String,UInt32}(
           "color[name='red']"   => 0xff0000,
           "color[name='green']" => 0x00ff00,
           "color[name='blue']"  => 0x0000ff,
       );

julia> NumExpr.eval_expr(var::NumExpr.Variable) = get(colors, var[], NaN)

julia> expr = parse_expr("color[name='red'] + color[name='blue']")
NumExpr.ExprNode(
    +,
    Union{NumExpr.AbstractExpr, NumExpr.ExprNode}[
        color[name='red'],
        color[name='blue'],
    ],
)
```
"""
function parse_expr(str::AbstractString)::Union{AbstractExpr,ExprNode}
    chars = Vector{Char}(str * "\n")
    exprs = tokenize(chars)
    isempty(exprs) && @err_syntax "got empty expression"
    return expr(ExprTree(exprs))
end
