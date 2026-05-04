module NumExpr

export parse_expr,
    eval_expr,
    isglobal_scope,
    islocal_scope,
    var_has_tags,
    VarContext,
    compile_expr,
    eval_compiled

#__ exceptions

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

#__ abstract types

abstract type AbstractExpr end

abstract type AbstractValue <: AbstractExpr end
abstract type AbstractOperator <: AbstractExpr end

abstract type AbstractLexisOperator <: AbstractOperator end
abstract type AbstractLogicOperator <: AbstractOperator end
abstract type AbstractArithmeticOperator <: AbstractOperator end
abstract type AbstractFuncOperator <: AbstractOperator end

#__ scope

abstract type AbstractScope end
struct GlobalScope <: AbstractScope end
struct LocalScope <: AbstractScope end

#__ includes

include("utils.jl")
include("parser.jl")
include("eval.jl")
include("opcodes.jl")
include("context.jl")
include("compiler.jl")
include("vm.jl")

end
