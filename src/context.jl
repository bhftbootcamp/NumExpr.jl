# context

"""
    VarContext(; sizehint::Int = 0)

Shared variable registry that maps variable names to integer indices.
All formulas compiled with the same `VarContext` share variable indices,
so a single `values::Vector{Float64}` can be used to evaluate any of them.

## Indexing

- `ctx[i::Integer]` — variable name by index.
- `ctx[name::String]` — index by variable name.
- `haskey(ctx, name)` — check if a variable is registered.

## Examples

```julia-repl
julia> ctx = VarContext()
VarContext(0 variables)

julia> compile_expr("price + tax", ctx)
CompiledExpr(9 bytes, 0 consts, stack=2)

julia> ctx["price"]
1

julia> ctx["tax"]
2
```
"""
struct VarContext
    names::Vector{String}
    lookup::Dict{String,Int}

    function VarContext(; sizehint::Int = 0)
        names = sizehint > 0 ? sizehint!(String[], sizehint) : String[]
        lookup = sizehint > 0 ? sizehint!(Dict{String,Int}(), sizehint) : Dict{String,Int}()
        return new(names, lookup)
    end
end

#__ accessors

Base.length(ctx::VarContext)::Int = length(ctx.names)
Base.getindex(ctx::VarContext, i::Integer)::String = ctx.names[i]
Base.getindex(ctx::VarContext, name::AbstractString)::Int = ctx.lookup[name]
Base.haskey(ctx::VarContext, name::AbstractString)::Bool = haskey(ctx.lookup, name)
Base.keys(ctx::VarContext)::Vector{String} = ctx.names

function Base.show(io::IO, ctx::VarContext)
    print(io, "VarContext(", length(ctx), " variables)")
end

#__ mutation

function get_or_create!(ctx::VarContext, name::String)::Int
    idx = get(ctx.lookup, name, 0)
    if idx == 0
        push!(ctx.names, name)
        idx = length(ctx.names)
        ctx.lookup[name] = idx
    end
    return idx
end
