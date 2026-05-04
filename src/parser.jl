# parser

#__ lexis operators

struct Comma <: AbstractLexisOperator end
struct LPar  <: AbstractLexisOperator end
struct RPar  <: AbstractLexisOperator end

Base.show(io::IO, ::LPar)  = print(io, "(")
Base.show(io::IO, ::RPar)  = print(io, ")")
Base.show(io::IO, ::Comma) = print(io, ",")

#__ parametric operators

struct Logic{x} <: AbstractLogicOperator
    Logic{x}() where {x} = new{x}()
end

Logic(x::Symbol) = Logic{x}()
Logic(x::Char...) = Logic(Symbol(x...))
operator(::Logic{x}) where {x} = x

struct Arithmetic{x} <: AbstractArithmeticOperator
    Arithmetic{x}() where {x} = new{x}()
end

Arithmetic(x::Symbol) = Arithmetic{x}()
Arithmetic(x::Char...) = Arithmetic(Symbol(x...))
operator(::Arithmetic{x}) where {x} = x

struct Func{x} <: AbstractFuncOperator
    Func{x}() where {x} = new{x}()
end

Func(x::Symbol) = Func{x}()
Func(x::Char...) = Func(Symbol(x...))
operator(::Func{x}) where {x} = x

Base.show(io::IO, n::AbstractOperator) = print(io, operator(n))

#__ value types

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

var_name(x::Variable)::String = x.name
var_tags(x::Variable)::Dict{String,String} = x.tags
Base.getindex(x::AbstractValue) = getfield(x, :val)
Base.show(io::IO, n::AbstractValue) = print(io, n[])

#__ variable parsing

function parse_var_format1(::Type{S}, chars::Vector{Char})::Variable{S} where {S<:AbstractScope}
    str_val = String(chars)
    return Variable{S}(str_val, str_val, Dict{String,String}())
end

function parse_var_format2(::Type{S}, chars::Vector{Char})::Variable{S} where {S<:AbstractScope}
    tags = Dict{String,String}()
    len = length(chars)
    key = ""
    index = 1
    name_chars = Char[]
    while index <= len && !isopenbracket(S, chars[index])
        c = chars[index]
        if isletter(c) || isunderline(c)
            push!(name_chars, c)
        end
        index += 1
    end
    name = String(name_chars)
    isempty(name) && @err_syntax "invalid indicator: $(String(chars))"
    index += 1
    while index <= len && !isclosebracket(S, chars[index])
        if isletter(chars[index])
            key_start = index
            while index <= len && (isletter(chars[index]) || isdigit(chars[index]))
                index += 1
            end
            key = String(chars[key_start:index-1])
        elseif isquote(chars[index])
            key == "" && @err_syntax "no key for value at index $index: $(String(chars[index:end]))"
            value_start = index + 1
            index = value_start
            while index <= len && !isquote(chars[index])
                index += 1
            end
            index > len && @err_syntax "unterminated string in $(String(chars))"
            tags[key] = String(chars[value_start:index-1])
            key = ""
            index += 1
        elseif iseqsign(chars[index])
            index += 1
        elseif iscomma(chars[index])
            index += 1
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

#__ tokenizer

function skip_while(condition, chars::Vector{Char}, index::Int, len::Int)::Int
    while condition(chars[index]) && index != len
        index += 1
    end
    return index
end

function tokenize(chars::Vector{Char})::Vector{AbstractExpr}
    len::Int = length(chars)
    exprs::Vector{AbstractExpr} = AbstractExpr[]
    l::Int, r::Int = 1, 1
    lpar::Int, rpar::Int = 0, 0

    while r <= len
        l = r
        if isspace(chars[r])
            r += 1
        elseif isnumber(chars[r])
            r = skip_while(x -> isnumber(x) || isunderline(x), chars, r + 1, len)
            if isdot(chars[r])
                r = skip_while(x -> isnumber(x) || isunderline(x), chars, r + 1, len)
            end
            if isexponent(chars[r])
                r += 1
                isplusmin(chars[r]) && (r += 1)
                prev = r
                r = skip_while(x -> isnumber(x) || isunderline(x), chars, r, len)
                r == prev && @err_syntax "invalid number in e notation"
            end
            push!(exprs, NumVal{Float64}(chars[l:r-1]))
        elseif islsquare(chars[r])
            r = skip_while(x -> !isrsquare(x) && !islsquare(x), chars, r + 1, len)
            r == len && @err_syntax "space before ']' not allowed"
            islsquare(chars[r]) && @err_syntax "extra token '[' after end of expression"
            push!(exprs, parse_var_format1(GlobalScope, chars[l+1:r-1]))
            r += 1
        elseif islbrace(chars[r])
            r = skip_while(x -> !isrbrace(x) && !islbrace(x), chars, r + 1, len)
            r == len && @err_syntax "space before '}' not allowed"
            islbrace(chars[r]) && @err_syntax "extra token '{' after end of expression"
            push!(exprs, parse_var_format1(LocalScope, chars[l+1:r-1]))
            r += 1
        elseif isquote(chars[r])
            r + 1 == len && @err_syntax "quote symbol after end of expression"
            r = skip_while(x -> !isquote(x), chars, r + 1, len)
            r == len && @err_syntax "quote expression is not properly closed"
            push!(exprs, StrVal(chars[l+1:r-1]))
            r += 1
        elseif isalphabetic(chars[r])
            r = skip_while(x -> isalphabetic(x) ||
                                isnumber(x)     ||
                                isunderline(x), chars, r + 1, len)
            if isdot(chars[r]) && (r < len) && islpar(chars[r+1])
                @err_syntax "broadcasting prohibited"
            end
            r = skip_while(x -> isalphabetic(x) ||
                                isnumber(x)     ||
                                isunderline(x)  ||
                                isdot(x), chars, r, len)
            tok = chars[l:r-1]
            tok_length = r - l
            expr = if islpar(chars[r])
                Func(tok...)
            elseif islsquare(chars[r])
                l = r + 1
                r = skip_while(x -> !isrsquare(x) && !islsquare(x), chars, r + 1, len)
                r == len && @err_syntax "space before ']' not allowed"
                islsquare(chars[r]) && @err_syntax "extra token '[' after end of expression"
                r += 1
                parse_var_format2(GlobalScope, [tok; chars[l-1:r-1]])
            elseif islbrace(chars[r])
                l = r + 1
                r = skip_while(x -> !isrbrace(x) && !islbrace(x), chars, r + 1, len)
                r == len && @err_syntax "space before '}' not allowed"
                islbrace(chars[r]) && @err_syntax "extra token '{' after end of expression"
                r += 1
                parse_var_format2(LocalScope, [tok; chars[l-1:r-1]])
            elseif tok_length == 3 && isnannumber(tok...)
                NumVal{Float64}(tok)
            elseif (tok_length == 4 && istruenumber(tok...)) ||
                   (tok_length == 5 && isfalsenumber(tok...))
                NumVal{Bool}(tok)
            else
                parse_var_format1(LocalScope, tok)
            end
            push!(exprs, expr)
        elseif iscomma(chars[r])
            push!(exprs, Comma())
            r += 1
        elseif islpar(chars[r])
            push!(exprs, LPar())
            r += 1
            lpar += 1
        elseif isrpar(chars[r])
            push!(exprs, RPar())
            r += 1
            rpar += 1
        elseif ismultilogical(chars[r], chars[r+1])
            push!(exprs, Logic(chars[r], chars[r+1]))
            r += 2
        elseif issimplelogical(chars[r])
            push!(exprs, Logic(chars[r]))
            r += 1
        elseif isarithmetic(chars[r])
            push!(exprs, Arithmetic(chars[r]))
            r += 1
        else
            @err_syntax "invalid identifier name '$(chars[r])'"
        end
    end

    (rpar > lpar) &&
        @err_syntax "extra token ')' after end of expression"

    (lpar > rpar) &&
        @err_syntax "extra token '(' after end of expression"

    return exprs
end

#__ operator priority

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

function Base.:(==)(l::L, r::R)::Bool where {L<:Variable,R<:Variable}
    return l[] == r[]
end

#__ expression tree

mutable struct ExprTree
    const exprs::Vector{AbstractExpr}
    position::Int

    ExprTree(exprs::Vector{AbstractExpr}) = new(exprs, 1)
end

"""
    ExprNode

Represents a transitional nested object obtained after parsing by [`parse_expr`](@ref) function.
Used by [`eval_expr`](@ref) function for evaluations an expression.

## Fields
- `head::AbstractExpr`: Leading variable or operation of current expression layer.
- `args::Vector{Union{AbstractExpr,ExprNode}}`: Elements of current expression node such as variables or another operations.
"""
struct ExprNode
    head::AbstractExpr
    args::Vector{Union{AbstractExpr,ExprNode}}
end

function expr(::Type{AbstractExpr}, tree::ExprTree)::Union{AbstractExpr,ExprNode}
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

function expr(::Type{Func}, tree::ExprTree)::ExprNode
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

function expr(tree::ExprTree, precedence::Int = 0)::Union{AbstractExpr,ExprNode}
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

#__ public API

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
