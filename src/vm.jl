# vm

#__ variable adapter

struct ResolverAdapter{F}
    f::F
end

@inline Base.getindex(r::ResolverAdapter, idx::Int)::Float64 = r.f(idx)

#__ bytecode decoding

@inline function _read_u16(code_ptr::Ptr{UInt8}, pos::Int)::Int
    lo = unsafe_load(code_ptr, pos)
    hi = unsafe_load(code_ptr, pos + 1)
    return Int(lo) | (Int(hi) << 8)
end


@inline _vars_pointer(vars::Vector{Float64}) = pointer(vars)
@inline _vars_pointer(_)                     = nothing

@inline _read_var(::Vector{Float64}, vars_ptr::Ptr{Float64}, idx::Int) =
    unsafe_load(vars_ptr, idx)
@inline _read_var(vars, ::Nothing, idx::Int) =
    @inbounds vars[idx]
#__ calendar helpers (ns-unix timestamp as Float64)

# civil_from_days (H. Hinnant): (year, month, day) of the civil date
@inline function _civil(v::Float64)::NTuple{3,Float64}
    days = fld(v, 86_400_000_000_000.0)
    z = days + 719_468.0
    era = fld(z, 146_097.0)
    doe = z - era * 146_097.0
    yoe = fld(doe - fld(doe, 1460.0) + fld(doe, 36_524.0) - fld(doe, 146_096.0), 365.0)
    y = yoe + era * 400.0
    doy = doe - (365.0 * yoe + fld(yoe, 4.0) - fld(yoe, 100.0))
    mp = fld(5.0 * doy + 2.0, 153.0)
    d = doy - fld(153.0 * mp + 2.0, 5.0) + 1.0
    m = mp < 10.0 ? mp + 3.0 : mp - 9.0
    return (m <= 2.0 ? y + 1.0 : y, m, d)
end

#__ core VM loop

function vm_eval(
    code::Vector{UInt8},
    consts::Vector{Float64},
    vars::V,
    stack::Vector{Float64},
)::Float64 where {V}
    n = length(code)
    GC.@preserve code consts stack vars begin
        code_ptr   = pointer(code)
        consts_ptr = pointer(consts)
        stack_ptr  = pointer(stack)
        vars_ptr   = _vars_pointer(vars)

        sp = 0
        pc = 1
        while pc <= n
            op = unsafe_load(code_ptr, pc)

            if op == OP_LOAD_CONST
                idx = _read_u16(code_ptr, pc + 1)
                sp += 1
                unsafe_store!(stack_ptr, unsafe_load(consts_ptr, idx), sp)
                pc += 3
            elseif op == OP_LOAD_VAR
                idx = _read_u16(code_ptr, pc + 1)
                sp += 1
                unsafe_store!(stack_ptr, _read_var(vars, vars_ptr, idx), sp)
                pc += 3
            elseif op == OP_LOAD_TRUE
                sp += 1
                unsafe_store!(stack_ptr, 1.0, sp)
                pc += 1
            elseif op == OP_LOAD_FALSE
                sp += 1
                unsafe_store!(stack_ptr, 0.0, sp)
                pc += 1
            elseif op == OP_LOAD_NAN
                sp += 1
                unsafe_store!(stack_ptr, NaN, sp)
                pc += 1
            elseif op == OP_LOAD_ZERO
                sp += 1
                unsafe_store!(stack_ptr, 0.0, sp)
                pc += 1
            elseif op == OP_LOAD_ONE
                sp += 1
                unsafe_store!(stack_ptr, 1.0, sp)
                pc += 1
            elseif op == OP_ADD
                a = unsafe_load(stack_ptr, sp - 1)
                b = unsafe_load(stack_ptr, sp)
                unsafe_store!(stack_ptr, a + b, sp - 1)
                sp -= 1
                pc += 1
            elseif op == OP_SUB
                a = unsafe_load(stack_ptr, sp - 1)
                b = unsafe_load(stack_ptr, sp)
                unsafe_store!(stack_ptr, a - b, sp - 1)
                sp -= 1
                pc += 1
            elseif op == OP_MUL
                a = unsafe_load(stack_ptr, sp - 1)
                b = unsafe_load(stack_ptr, sp)
                unsafe_store!(stack_ptr, a * b, sp - 1)
                sp -= 1
                pc += 1
            elseif op == OP_DIV
                a = unsafe_load(stack_ptr, sp - 1)
                b = unsafe_load(stack_ptr, sp)
                unsafe_store!(stack_ptr, a / b, sp - 1)
                sp -= 1
                pc += 1
            elseif op == OP_POW
                a = unsafe_load(stack_ptr, sp - 1)
                b = unsafe_load(stack_ptr, sp)
                unsafe_store!(stack_ptr, a ^ b, sp - 1)
                sp -= 1
                pc += 1
            elseif op == OP_MOD
                a = unsafe_load(stack_ptr, sp - 1)
                b = unsafe_load(stack_ptr, sp)
                unsafe_store!(stack_ptr, a % b, sp - 1)
                sp -= 1
                pc += 1
            elseif op == OP_REM
                a = unsafe_load(stack_ptr, sp - 1)
                b = unsafe_load(stack_ptr, sp)
                unsafe_store!(stack_ptr, rem(a, b), sp - 1)
                sp -= 1
                pc += 1
            elseif op == OP_NEG
                unsafe_store!(stack_ptr, -unsafe_load(stack_ptr, sp), sp)
                pc += 1
            elseif op == OP_GT
                a = unsafe_load(stack_ptr, sp - 1)
                b = unsafe_load(stack_ptr, sp)
                unsafe_store!(stack_ptr, Float64(a > b), sp - 1)
                sp -= 1
                pc += 1
            elseif op == OP_LT
                a = unsafe_load(stack_ptr, sp - 1)
                b = unsafe_load(stack_ptr, sp)
                unsafe_store!(stack_ptr, Float64(a < b), sp - 1)
                sp -= 1
                pc += 1
            elseif op == OP_GE
                a = unsafe_load(stack_ptr, sp - 1)
                b = unsafe_load(stack_ptr, sp)
                unsafe_store!(stack_ptr, Float64(a >= b), sp - 1)
                sp -= 1
                pc += 1
            elseif op == OP_LE
                a = unsafe_load(stack_ptr, sp - 1)
                b = unsafe_load(stack_ptr, sp)
                unsafe_store!(stack_ptr, Float64(a <= b), sp - 1)
                sp -= 1
                pc += 1
            elseif op == OP_EQ
                a = unsafe_load(stack_ptr, sp - 1)
                b = unsafe_load(stack_ptr, sp)
                unsafe_store!(stack_ptr, Float64(a == b), sp - 1)
                sp -= 1
                pc += 1
            elseif op == OP_NE
                a = unsafe_load(stack_ptr, sp - 1)
                b = unsafe_load(stack_ptr, sp)
                unsafe_store!(stack_ptr, Float64(a != b), sp - 1)
                sp -= 1
                pc += 1
            elseif op == OP_AND
                a = unsafe_load(stack_ptr, sp - 1)
                b = unsafe_load(stack_ptr, sp)
                unsafe_store!(stack_ptr, Float64((a != 0.0) & (b != 0.0)), sp - 1)
                sp -= 1
                pc += 1
            elseif op == OP_OR
                a = unsafe_load(stack_ptr, sp - 1)
                b = unsafe_load(stack_ptr, sp)
                unsafe_store!(stack_ptr, Float64((a != 0.0) | (b != 0.0)), sp - 1)
                sp -= 1
                pc += 1
            elseif op == OP_SQRT
                unsafe_store!(stack_ptr, sqrt(unsafe_load(stack_ptr, sp)), sp)
                pc += 1
            elseif op == OP_ABS
                unsafe_store!(stack_ptr, abs(unsafe_load(stack_ptr, sp)), sp)
                pc += 1
            elseif op == OP_SIN
                unsafe_store!(stack_ptr, sin(unsafe_load(stack_ptr, sp)), sp)
                pc += 1
            elseif op == OP_COS
                unsafe_store!(stack_ptr, cos(unsafe_load(stack_ptr, sp)), sp)
                pc += 1
            elseif op == OP_ATAN
                unsafe_store!(stack_ptr, atan(unsafe_load(stack_ptr, sp)), sp)
                pc += 1
            elseif op == OP_EXP
                unsafe_store!(stack_ptr, exp(unsafe_load(stack_ptr, sp)), sp)
                pc += 1
            elseif op == OP_LOG
                unsafe_store!(stack_ptr, log(unsafe_load(stack_ptr, sp)), sp)
                pc += 1
            elseif op == OP_ISNAN
                unsafe_store!(stack_ptr, Float64(isnan(unsafe_load(stack_ptr, sp))), sp)
                pc += 1
            elseif op == OP_NOT
                x = unsafe_load(stack_ptr, sp)
                unsafe_store!(stack_ptr, isnan(x) ? NaN : (x == 0.0 ? 1.0 : 0.0), sp)
                pc += 1
            elseif op == OP_ISZERO
                unsafe_store!(stack_ptr, Float64(unsafe_load(stack_ptr, sp) == 0.0), sp)
                pc += 1
            elseif op == OP_ISONE
                unsafe_store!(stack_ptr, Float64(unsafe_load(stack_ptr, sp) == 1.0), sp)
                pc += 1
            elseif op == OP_FLOOR
                unsafe_store!(stack_ptr, floor(unsafe_load(stack_ptr, sp)), sp)
                pc += 1
            elseif op == OP_CEIL
                unsafe_store!(stack_ptr, ceil(unsafe_load(stack_ptr, sp)), sp)
                pc += 1
            elseif op == OP_TG
                unsafe_store!(stack_ptr, tan(unsafe_load(stack_ptr, sp)), sp)
                pc += 1
            elseif op == OP_CTG
                unsafe_store!(stack_ptr, cot(unsafe_load(stack_ptr, sp)), sp)
                pc += 1
            elseif op == OP_MAX2
                a = unsafe_load(stack_ptr, sp - 1)
                b = unsafe_load(stack_ptr, sp)
                unsafe_store!(stack_ptr, max(a, b), sp - 1)
                sp -= 1
                pc += 1
            elseif op == OP_MIN2
                a = unsafe_load(stack_ptr, sp - 1)
                b = unsafe_load(stack_ptr, sp)
                unsafe_store!(stack_ptr, min(a, b), sp - 1)
                sp -= 1
                pc += 1
            elseif op == OP_IFELSE
                c      = unsafe_load(stack_ptr, sp - 2)
                v_then = unsafe_load(stack_ptr, sp - 1)
                v_else = unsafe_load(stack_ptr, sp)
                unsafe_store!(stack_ptr,
                    isnan(c) ? NaN : (c != 0.0 ? v_then : v_else),
                    sp - 2)
                sp -= 2
                pc += 1
            elseif op == OP_GET
                a = unsafe_load(stack_ptr, sp - 1)
                b = unsafe_load(stack_ptr, sp)
                unsafe_store!(stack_ptr, isnan(a) ? b : a, sp - 1)
                sp -= 1
                pc += 1
            elseif op == OP_ROUND
                a = unsafe_load(stack_ptr, sp - 1)
                b = unsafe_load(stack_ptr, sp)
                unsafe_store!(stack_ptr,
                    isnan(b) ? NaN : round(a; digits = Int(b)),
                    sp - 1)
                sp -= 1
                pc += 1
            elseif op == OP_ISLESS
                a = unsafe_load(stack_ptr, sp - 1)
                b = unsafe_load(stack_ptr, sp)
                unsafe_store!(stack_ptr, Float64(isless(a, b)), sp - 1)
                sp -= 1
                pc += 1
            elseif op == OP_DIV_INT
                a = unsafe_load(stack_ptr, sp - 1)
                b = unsafe_load(stack_ptr, sp)
                unsafe_store!(stack_ptr, div(a, b), sp - 1)
                sp -= 1
                pc += 1
            elseif op == OP_MEAN
                count = Int(unsafe_load(code_ptr, pc + 1))
                s = 0.0
                base = sp - count + 1
                for i in base:sp
                    s += unsafe_load(stack_ptr, i)
                end
                unsafe_store!(stack_ptr, s / count, base)
                sp = base
                pc += 2
            elseif op == OP_MILLISECOND
                x = unsafe_load(stack_ptr, sp)
                unsafe_store!(stack_ptr, isnan(x) ? NaN : mod(fld(x, 1.0e6), 1000.0), sp)
                pc += 1
            elseif op == OP_SECOND
                x = unsafe_load(stack_ptr, sp)
                unsafe_store!(stack_ptr, isnan(x) ? NaN : mod(fld(x, 1.0e9), 60.0), sp)
                pc += 1
            elseif op == OP_MINUTE
                x = unsafe_load(stack_ptr, sp)
                unsafe_store!(stack_ptr, isnan(x) ? NaN : mod(fld(x, 6.0e10), 60.0), sp)
                pc += 1
            elseif op == OP_HOUR
                x = unsafe_load(stack_ptr, sp)
                unsafe_store!(stack_ptr, isnan(x) ? NaN : mod(fld(x, 3.6e12), 24.0), sp)
                pc += 1
            elseif op == OP_DAYOFMONTH
                x = unsafe_load(stack_ptr, sp)
                unsafe_store!(stack_ptr, isnan(x) ? NaN : _civil(x)[3], sp)
                pc += 1
            elseif op == OP_MONTH
                x = unsafe_load(stack_ptr, sp)
                unsafe_store!(stack_ptr, isnan(x) ? NaN : _civil(x)[2], sp)
                pc += 1
            elseif op == OP_YEAR
                x = unsafe_load(stack_ptr, sp)
                unsafe_store!(stack_ptr, isnan(x) ? NaN : _civil(x)[1], sp)
                pc += 1
            else
                error("unknown opcode: 0x$(string(op, base=16, pad=2))")
            end
        end

        return unsafe_load(stack_ptr, 1)
    end
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
