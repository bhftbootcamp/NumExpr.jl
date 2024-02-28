module NumExpr

export parse_expr,
    eval_expr,
    isglobal_scope,
    islocal_scope

"""
    SyntaxError

Exception thrown when a [`parse_expr`](@ref) fails due to incorrect expression syntax or any underlying error that occurs during parsing.

## Fields
- `message::String`: The error message.
"""
struct SyntaxError <: Exception
    message::String

    SyntaxError(message::String) = new("syntax: $message")
end

macro err_syntax(err)
    return esc(:(throw(SyntaxError($err))))
end

abstract type AbstractExpr end

abstract type AbstractScope end
struct GlobalScope <: AbstractScope end
struct LocalScope <: AbstractScope end

abstract type AbstractValue <: AbstractExpr end
abstract type AbstractOperator <: AbstractExpr end

abstract type AbstractLexisOperator <: AbstractOperator end
abstract type AbstractLogicOperator <: AbstractOperator end
abstract type AbstractArithmeticOperator <: AbstractOperator end
abstract type AbstractFuncOperator <: AbstractOperator end

include("utils.jl")
include("parser.jl")
include("eval.jl")

end
