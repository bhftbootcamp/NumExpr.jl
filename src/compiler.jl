# compiler

"""
    CompiledExpr

Compact bytecode representation of a numeric expression.
Created by [`compile_expr`](@ref) and evaluated by [`eval_compiled`](@ref).

## Fields
- `code::Vector{UInt8}`: Bytecode in postfix (RPN) order.
- `constants::Vector{Float64}`: Constant pool for numeric literals.
- `nvars::Int`: Maximum variable index referenced.
- `max_stack::Int`: Stack depth required for evaluation.
"""
struct CompiledExpr
    code::Vector{UInt8}
    constants::Vector{Float64}
    nvars::Int
    max_stack::Int
end

function Base.show(io::IO, expr::CompiledExpr)
    print(
        io,
        "CompiledExpr(",
        length(expr.code), " bytes, ",
        length(expr.constants), " consts, ",
        "stack=", expr.max_stack, ")",
    )
end

#__ emitter

mutable struct Emitter
    const code::Vector{UInt8}
    const constants::Vector{Float64}
    const const_index::Dict{Float64,Int}
    const ctx::VarContext
    nvars::Int
    depth::Int
    max_depth::Int

    Emitter(ctx::VarContext) = new(UInt8[], Float64[], Dict{Float64,Int}(), ctx, 0, 0, 0)
end

function emit!(e::Emitter, op::UInt8)::Nothing
    push!(e.code, op)
    return nothing
end

function emit_u16!(e::Emitter, val::Int)::Nothing
    push!(e.code, UInt8(val & 0xFF))
    push!(e.code, UInt8((val >> 8) & 0xFF))
    return nothing
end

function push_depth!(e::Emitter)::Nothing
    e.depth += 1
    e.depth > e.max_depth && (e.max_depth = e.depth)
    return nothing
end

function pop_depth!(e::Emitter)::Nothing
    e.depth -= 1
    return nothing
end

function add_const!(e::Emitter, val::Float64)::Int
    idx = get(e.const_index, val, 0)
    if idx == 0
        push!(e.constants, val)
        idx = length(e.constants)
        idx > typemax(UInt16) && error("constant pool exceeds UInt16 limit: $idx")
        e.const_index[val] = idx
    end
    return idx
end

#__ compile dispatch

function compile_node!(e::Emitter, val::NumVal{Float64})::Nothing
    x = val[]
    if isnan(x)
        emit!(e, OP_LOAD_NAN)
    elseif x === 0.0
        emit!(e, OP_LOAD_ZERO)
    elseif x === 1.0
        emit!(e, OP_LOAD_ONE)
    else
        emit!(e, OP_LOAD_CONST)
        emit_u16!(e, add_const!(e, x))
    end
    push_depth!(e)
    return nothing
end

function compile_node!(e::Emitter, val::NumVal{Bool})::Nothing
    emit!(e, val[] ? OP_LOAD_TRUE : OP_LOAD_FALSE)
    push_depth!(e)
    return nothing
end

function compile_node!(e::Emitter, var::Variable)::Nothing
    idx = get_or_create!(e.ctx, var[])
    idx > typemax(UInt16) && error("variable index exceeds UInt16 limit: $idx")
    idx > e.nvars && (e.nvars = idx)
    emit!(e, OP_LOAD_VAR)
    emit_u16!(e, idx)
    push_depth!(e)
    return nothing
end

function compile_node!(::Emitter, ::StrVal)::Nothing
    error("String operations are not supported in compiled mode. Use eval_expr instead.")
end

function compile_node!(e::Emitter, node::ExprNode)::Nothing
    head = node.head
    args = node.args
    n = length(args)

    # Unary minus
    if head isa Arithmetic{:-} && n == 1
        compile_node!(e, args[1])
        emit!(e, OP_NEG)
        return nothing
    end

    # Unary plus (identity)
    if head isa Arithmetic{:+} && n == 1
        compile_node!(e, args[1])
        return nothing
    end

    # Functions (unary, binary, ternary)
    if head isa AbstractFuncOperator
        op = opcode(head)
        if op == OP_MEAN
            n < 1 && error("mean requires at least 1 argument, got $n")
            n > 255 && error("mean supports at most 255 arguments, got $n")
            for i in 1:n
                compile_node!(e, args[i])
            end
            emit!(e, op)
            push!(e.code, UInt8(n))
            for _ in 2:n
                pop_depth!(e)
            end
            return nothing
        elseif op == OP_IFELSE
            n != 3 && error("ifelse requires exactly 3 arguments, got $n")
            compile_node!(e, args[1])
            compile_node!(e, args[2])
            compile_node!(e, args[3])
            emit!(e, op)
            pop_depth!(e)
            pop_depth!(e)
            return nothing
        elseif op in (OP_MAX2, OP_MIN2, OP_GET, OP_ROUND, OP_ISLESS, OP_DIV_INT, OP_REM)
            n != 2 && error("function $(head) requires exactly 2 arguments, got $n")
            compile_node!(e, args[1])
            compile_node!(e, args[2])
            emit!(e, op)
            pop_depth!(e)
            return nothing
        else
            n != 1 && error("compiled mode supports only unary function $(head), got $n arguments")
            compile_node!(e, args[1])
            emit!(e, op)
            return nothing
        end
    end

    # Binary / n-ary operators (left-associative fold)
    n < 2 && error("operator $(head) requires at least 2 operands, got $n")
    op = opcode(head)
    compile_node!(e, args[1])
    for i in 2:n
        compile_node!(e, args[i])
        emit!(e, op)
        pop_depth!(e)
    end
    return nothing
end

#__ public API

"""
    compile_expr(node::Union{AbstractExpr,ExprNode}, ctx::VarContext) -> CompiledExpr

Compile a parsed expression tree into compact bytecode.
All formulas compiled with the same `ctx` share variable indices.

"""
function compile_expr(node::Union{AbstractExpr,ExprNode}, ctx::VarContext)::CompiledExpr
    e = Emitter(ctx)
    compile_node!(e, node)
    return CompiledExpr(e.code, e.constants, e.nvars, e.max_depth)
end

"""
    compile_expr(str::AbstractString, ctx::VarContext) -> CompiledExpr

Parse and compile a string expression into compact bytecode.

## Examples

```julia-repl
julia> ctx = VarContext()
VarContext(0 variables)

julia> f = compile_expr("a + b * sin(c)", ctx)
CompiledExpr(13 bytes, 0 consts, stack=2)

julia> ctx
VarContext(3 variables)
```
"""
function compile_expr(str::AbstractString, ctx::VarContext)::CompiledExpr
    return compile_expr(parse_expr(str), ctx)
end
