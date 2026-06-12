using WasmMakie
include("/Users/daleblack/Documents/dev/GroupTherapyOrg/WasmMakie.jl/reftests/wasm_compile.jl")
using .WasmCompile

straight(x0, y0, x, m) = y0 + m * (x - x0)

function newton_param(n::Int64, x0i::Int64)
    f(x) = 0.2 * x^3 - 4.0 * x + 1.0
    f′ = x -> 0.6 * x^2 - 4.0          # V6 analytic — traps at (1,6) in the island
    x0 = Float64(x0i)
    xs = Float64[]; ys = Float64[]
    let t = -10.0, hi = 10.0, dt = 0.01
        while t <= hi + dt / 2
            push!(xs, t); push!(ys, Float64(f(t))); t += dt
        end
    end
    fig = Figure(size = (400.0, 300.0))
    ax = Axis(fig[1, 1])
    ax.ymin = -10.0
    ax.ymax = 70.0
    lines!(ax, xs, ys; linewidth = 3)
    hlines!(ax, [0.0]; color = :magenta, linewidth = 3, linestyle = :dash)
    scatter!(ax, [Float64(x0)], [0.0]; color = :green)
    for i in 1:n
        lines!(ax, [Float64(x0), Float64(x0)], [0.0, Float64(f(x0))]; color = (0.5, 0.5, 0.5, 0.5))
        scatter!(ax, [Float64(x0)], [Float64(f(x0))]; color = :red)
        m = f′(x0)
        ts = Float64[]
        for x in xs
            push!(ts, Float64(straight(x0, f(x0), x, m)))
        end
        lines!(ax, xs, ts; color = (0.0, 0.0, 1.0, 0.5), linestyle = :dash, linewidth = 2)
        x1 = x0 - f(x0) / m
        scatter!(ax, [Float64(x1)], [0.0]; color = :green)
        x0 = x1
    end
    render!(fig, WasmCtx())
    return Int64(0)
end

entry() = newton_param(Base.inferencebarrier(1)::Int64, Base.inferencebarrier(6)::Int64)

bytes = compile_with_canvas(Any[(entry, (), "ntrap"), (newton_param, (Int64, Int64), "newton_param")])
println("compiled: ", length(bytes), " bytes")
dir = mktempdir()
wasm_path = joinpath(dir, "ntrap.wasm"); write(wasm_path, bytes)
glue_path = joinpath(dir, "glue.js"); write(glue_path, js_glue())
checker = "/Users/daleblack/Documents/dev/GroupTherapyOrg/WasmMakie.jl/test/wasm_stream_check.js"
out = try
    strip(read(`node $checker $wasm_path $glue_path ntrap`, String))
catch e
    "NODE FAILED (trap?): $(first(sprint(showerror, e), 300))"
end
println("node result: ", first(out, 160))
