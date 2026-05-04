using BenchmarkTools
using NumExpr

const SUITE = BenchmarkGroup()

# ─────────────────────────────────────────────────────────────────────────────
#  Shared test data
# ─────────────────────────────────────────────────────────────────────────────

const BENCH_VARS = Dict{String,Float64}(
    "a" => 1.5, "b" => 2.3, "c" => 0.7, "d" => 4.1, "e" => 5.9,
    "f" => 3.2, "g" => 7.8, "h" => 6.4, "i" => 8.1, "j" => 9.3,
    "k" => 2.7, "x" => 1.2,
)

NumExpr.eval_expr(var::NumExpr.Variable) = get(BENCH_VARS, var[], NaN)

const BENCH_EXPRS = [
    "constant"    => "42",
    "simple"      => "a + b",
    "medium"      => "a + b * c - d / e",
    "trig"        => "sin(x) ^ 2 + cos(x) ^ 2",
    "func_chain"  => "sqrt(abs(a * b - c))",
    "complex"     => "sin(a) * cos(b) + exp(c) / log(d + 1) - sqrt(abs(e))",
    "large"       => "a + b * c + d * e + f * g + h * i + j * k",
]

# ─────────────────────────────────────────────────────────────────────────────
#  1. Parse
# ─────────────────────────────────────────────────────────────────────────────

SUITE["parse"] = BenchmarkGroup(["parsing"])

for (label, expr_str) in BENCH_EXPRS
    SUITE["parse"][label] = @benchmarkable parse_expr($expr_str)
end

# ─────────────────────────────────────────────────────────────────────────────
#  2. Compile (parse + compile)
# ─────────────────────────────────────────────────────────────────────────────

SUITE["compile"] = BenchmarkGroup(["compilation"])

for (label, expr_str) in BENCH_EXPRS
    SUITE["compile"][label] = @benchmarkable compile_expr($expr_str, VarContext())
end

# ─────────────────────────────────────────────────────────────────────────────
#  3. Eval — tree walk
# ─────────────────────────────────────────────────────────────────────────────

SUITE["eval"] = BenchmarkGroup(["evaluation"])
SUITE["eval"]["tree"] = BenchmarkGroup(["tree-walk"])

for (label, expr_str) in BENCH_EXPRS
    node = parse_expr(expr_str)
    SUITE["eval"]["tree"][label] = @benchmarkable eval_expr($node)
end

# ─────────────────────────────────────────────────────────────────────────────
#  4. Eval — bytecode VM (pre-allocated stack)
# ─────────────────────────────────────────────────────────────────────────────

SUITE["eval"]["vm"] = BenchmarkGroup(["bytecode", "vm"])

for (label, expr_str) in BENCH_EXPRS
    ctx = VarContext()
    compiled = compile_expr(expr_str, ctx)
    values = zeros(Float64, length(ctx))
    for (name, val) in BENCH_VARS
        haskey(ctx, name) && (values[ctx[name]] = val)
    end
    stack = Vector{Float64}(undef, compiled.max_stack)
    SUITE["eval"]["vm"][label] = @benchmarkable eval_compiled($compiled, $values, $stack)
end

# ─────────────────────────────────────────────────────────────────────────────
#  5. Eval — bytecode VM (auto stack)
# ─────────────────────────────────────────────────────────────────────────────

SUITE["eval"]["vm_auto"] = BenchmarkGroup(["bytecode", "vm", "auto-stack"])

for (label, expr_str) in BENCH_EXPRS
    ctx = VarContext()
    compiled = compile_expr(expr_str, ctx)
    values = zeros(Float64, length(ctx))
    for (name, val) in BENCH_VARS
        haskey(ctx, name) && (values[ctx[name]] = val)
    end
    SUITE["eval"]["vm_auto"][label] = @benchmarkable eval_compiled($compiled, $values)
end

# ─────────────────────────────────────────────────────────────────────────────
#  6. Throughput — bulk evaluation
# ─────────────────────────────────────────────────────────────────────────────

SUITE["throughput"] = BenchmarkGroup(["bulk", "throughput"])

let
    ctx = VarContext()
    formulas_1k = [compile_expr("$(rand()) + $(rand()) * $(rand())", ctx) for _ in 1:1_000]
    formulas_10k = [compile_expr("$(rand()) + $(rand()) * $(rand())", ctx) for _ in 1:10_000]
    values = Float64[]
    stack_1k = Vector{Float64}(undef, maximum(f.max_stack for f in formulas_1k))
    stack_10k = Vector{Float64}(undef, maximum(f.max_stack for f in formulas_10k))

    SUITE["throughput"]["1k_formulas"] = @benchmarkable begin
        @inbounds for f in $formulas_1k
            eval_compiled(f, $values, $stack_1k)
        end
    end

    SUITE["throughput"]["10k_formulas"] = @benchmarkable begin
        @inbounds for f in $formulas_10k
            eval_compiled(f, $values, $stack_10k)
        end
    end
end
