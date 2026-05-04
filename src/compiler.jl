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
        e.const_index[val] = idx
    end
    return idx
end

#__ compile dispatch

function compile_node!(e::Emitter, val::NumVal{Float64})::Nothing
    x = val[]
    if isnan(x)
        emit!(e, OP_LOAD_NAN)
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

    # Unary functions
    if head isa AbstractFuncOperator
        n != 1 && error("compiled mode supports only unary functions, got $n arguments for $(head)")
        compile_node!(e, args[1])
        emit!(e, opcode(head))
        return nothing
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

Throws an error if the expression contains string operations.
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
