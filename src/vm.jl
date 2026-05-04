# vm

#__ variable adapter

struct ResolverAdapter{F}
    f::F
end

@inline Base.getindex(r::ResolverAdapter, idx::Int)::Float64 = r.f(idx)

#__ bytecode decoding

@inline function read_u16(code::Vector{UInt8}, pos::Int)::Int
    return Int(code[pos]) | (Int(code[pos + 1]) << 8)
end

#__ core VM loop

function vm_eval(
    code::Vector{UInt8},
    consts::Vector{Float64},
    vars::V,
    stack::Vector{Float64},
)::Float64 where {V}
    sp = 0
    pc = 1
    n = length(code)

    @inbounds while pc <= n
        op = code[pc]

        if op == OP_LOAD_CONST
            idx = read_u16(code, pc + 1)
            sp += 1
            stack[sp] = consts[idx]
            pc += 3
        elseif op == OP_LOAD_VAR
            idx = read_u16(code, pc + 1)
            sp += 1
            stack[sp] = vars[idx]
            pc += 3
        elseif op == OP_LOAD_TRUE
            sp += 1
            stack[sp] = 1.0
            pc += 1
        elseif op == OP_LOAD_FALSE
            sp += 1
            stack[sp] = 0.0
            pc += 1
        elseif op == OP_LOAD_NAN
            sp += 1
            stack[sp] = NaN
            pc += 1
        elseif op == OP_ADD
            stack[sp - 1] += stack[sp]
            sp -= 1
            pc += 1
        elseif op == OP_SUB
            stack[sp - 1] -= stack[sp]
            sp -= 1
            pc += 1
        elseif op == OP_MUL
            stack[sp - 1] *= stack[sp]
            sp -= 1
            pc += 1
        elseif op == OP_DIV
            stack[sp - 1] /= stack[sp]
            sp -= 1
            pc += 1
        elseif op == OP_POW
            stack[sp - 1] = stack[sp - 1] ^ stack[sp]
            sp -= 1
            pc += 1
        elseif op == OP_MOD
            stack[sp - 1] = stack[sp - 1] % stack[sp]
            sp -= 1
            pc += 1
        elseif op == OP_NEG
            stack[sp] = -stack[sp]
            pc += 1
        elseif op == OP_GT
            stack[sp - 1] = Float64(stack[sp - 1] > stack[sp])
            sp -= 1
            pc += 1
        elseif op == OP_LT
            stack[sp - 1] = Float64(stack[sp - 1] < stack[sp])
            sp -= 1
            pc += 1
        elseif op == OP_GE
            stack[sp - 1] = Float64(stack[sp - 1] >= stack[sp])
            sp -= 1
            pc += 1
        elseif op == OP_LE
            stack[sp - 1] = Float64(stack[sp - 1] <= stack[sp])
            sp -= 1
            pc += 1
        elseif op == OP_EQ
            stack[sp - 1] = Float64(stack[sp - 1] == stack[sp])
            sp -= 1
            pc += 1
        elseif op == OP_NE
            stack[sp - 1] = Float64(stack[sp - 1] != stack[sp])
            sp -= 1
            pc += 1
        elseif op == OP_AND
            stack[sp - 1] = Float64((stack[sp - 1] != 0.0) & (stack[sp] != 0.0))
            sp -= 1
            pc += 1
        elseif op == OP_OR
            stack[sp - 1] = Float64((stack[sp - 1] != 0.0) | (stack[sp] != 0.0))
            sp -= 1
            pc += 1
        elseif op == OP_SQRT
            stack[sp] = sqrt(stack[sp])
            pc += 1
        elseif op == OP_ABS
            stack[sp] = abs(stack[sp])
            pc += 1
        elseif op == OP_SIN
            stack[sp] = sin(stack[sp])
            pc += 1
        elseif op == OP_COS
            stack[sp] = cos(stack[sp])
            pc += 1
        elseif op == OP_ATAN
            stack[sp] = atan(stack[sp])
            pc += 1
        elseif op == OP_EXP
            stack[sp] = exp(stack[sp])
            pc += 1
        elseif op == OP_LOG
            stack[sp] = log(stack[sp])
            pc += 1
        elseif op == OP_ISNAN
            stack[sp] = Float64(isnan(stack[sp]))
            pc += 1
        elseif op == OP_NOT
            x = stack[sp]
            stack[sp] = x == 1.0 ? 0.0 : (x == 0.0 ? 1.0 : NaN)
            pc += 1
        elseif op == OP_ISZERO
            stack[sp] = Float64(stack[sp] == 0.0)
            pc += 1
        elseif op == OP_ISONE
            stack[sp] = Float64(stack[sp] == 1.0)
            pc += 1
        elseif op == OP_FLOOR
            stack[sp] = floor(stack[sp])
            pc += 1
        elseif op == OP_CEIL
            stack[sp] = ceil(stack[sp])
            pc += 1
        elseif op == OP_TG
            stack[sp] = tan(stack[sp])
            pc += 1
        elseif op == OP_CTG
            stack[sp] = cos(stack[sp]) / sin(stack[sp])
            pc += 1
        elseif op == OP_MAX2
            stack[sp - 1] = max(stack[sp - 1], stack[sp])
            sp -= 1
            pc += 1
        elseif op == OP_MIN2
            stack[sp - 1] = min(stack[sp - 1], stack[sp])
            sp -= 1
            pc += 1
        elseif op == OP_IFELSE
            c = stack[sp - 2]; v_then = stack[sp - 1]; v_else = stack[sp]
            stack[sp - 2] = c == 1.0 ? v_then : v_else
            sp -= 2
            pc += 1
        elseif op == OP_GET
            a = stack[sp - 1]; b = stack[sp]
            stack[sp - 1] = isnan(a) ? b : a
            sp -= 1
            pc += 1
        elseif op == OP_ROUND
            a = stack[sp - 1]; b = stack[sp]
            stack[sp - 1] = isnan(b) ? NaN : round(a; digits = Int(b))
            sp -= 1
            pc += 1
        elseif op == OP_ISLESS
            a = stack[sp - 1]; b = stack[sp]
            stack[sp - 1] = Float64(a === b ? false : isless(a, b))
            sp -= 1
            pc += 1
        elseif op == OP_DIV_INT
            stack[sp - 1] = div(stack[sp - 1], stack[sp])
            sp -= 1
            pc += 1
        elseif op == OP_MEAN
            count = Int(code[pc + 1])
            s = 0.0
            base = sp - count + 1
            for i in base:sp
                s += stack[i]
            end
            stack[base] = s / count
            sp = base
            pc += 2
        else
            error("unknown opcode: 0x$(string(op, base=16, pad=2))")
        end
    end

    return stack[1]
end

#__ public API

"""
    eval_compiled(expr::CompiledExpr, values::AbstractVector{Float64}, stack::Vector{Float64}) -> Float64

Evaluate a compiled expression with a pre-allocated stack (zero heap allocations).
This is the fastest evaluation path, suitable for hot loops.

## Examples

```julia-repl
julia> ctx = VarContext()
VarContext(0 variables)

julia> f = compile_expr("a + b * 2", ctx)
CompiledExpr(9 bytes, 1 consts, stack=2)

julia> values = [3.0, 4.0]
julia> stack = Vector{Float64}(undef, f.max_stack)

julia> eval_compiled(f, values, stack)
11.0
```
"""
function eval_compiled(
    expr::CompiledExpr,
    values::AbstractVector{Float64},
    stack::Vector{Float64},
)::Float64
    return vm_eval(expr.code, expr.constants, values, stack)
end

"""
    eval_compiled(expr::CompiledExpr, values::AbstractVector{Float64}) -> Float64

Evaluate a compiled expression (allocates a temporary stack).

## Examples

```julia-repl
julia> ctx = VarContext()
VarContext(0 variables)

julia> f = compile_expr("a + b * 2", ctx)
CompiledExpr(9 bytes, 1 consts, stack=2)

julia> eval_compiled(f, [3.0, 4.0])
11.0
```
"""
function eval_compiled(expr::CompiledExpr, values::AbstractVector{Float64})::Float64
    stack = Vector{Float64}(undef, expr.max_stack)
    return vm_eval(expr.code, expr.constants, values, stack)
end

"""
    eval_compiled(expr::CompiledExpr, resolver) -> Float64

Evaluate a compiled expression using a resolver callable for variable lookup.
The resolver is called as `resolver(index::Int) -> Float64` for each variable reference.
Any callable (function, functor, closure) is accepted.
"""
function eval_compiled(expr::CompiledExpr, resolver)::Float64
    stack = Vector{Float64}(undef, expr.max_stack)
    return vm_eval(expr.code, expr.constants, ResolverAdapter(resolver), stack)
end

"""
    eval_compiled(expr::CompiledExpr, ctx::VarContext, pairs::Pair...) -> Float64

Evaluate a compiled expression with named variable values (convenience method, allocates).

## Examples

```julia-repl
julia> ctx = VarContext()
VarContext(0 variables)

julia> f = compile_expr("price + tax", ctx)
CompiledExpr(9 bytes, 0 consts, stack=2)

julia> eval_compiled(f, ctx, "price" => 100.0, "tax" => 8.0)
108.0
```
"""
function eval_compiled(
    expr::CompiledExpr,
    ctx::VarContext,
    pairs::Pair{<:AbstractString,<:Real}...,
)::Float64
    values = zeros(Float64, length(ctx))
    for (name, val) in pairs
        values[ctx[name]] = Float64(val)
    end
    return eval_compiled(expr, values)
end
