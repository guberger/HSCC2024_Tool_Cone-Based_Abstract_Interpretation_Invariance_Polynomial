module Example

# Automated and Sound Synthesis of Lyapunov Functions with SMT Solvers
# Example 6, modified

using LinearAlgebra
using Random
Random.seed!(0)
using LaTeXStrings
using DynamicPolynomials
using Plots
using DifferentialEquations
using CDDLib
using SumOfSquares
using MosekTools

include("utils.jl")

var, = @polyvar x[1:2]
flow = [
    -x[1]^3 + x[2] / 2,
    -x[1] - 2 * x[2],
]
display(flow)
xc = zeros(2)
rad = 0.5
dom_init = @set (x - xc)' * (x - xc) ≤ rad^2

xlims = (-1.5, 1.5)
ylims = (-1.5, 1.5)
plt = plot(xlabel=L"x_1", ylabel=L"x_2",
           aspect_ratio=:equal,
           xlims=xlims .* 1.1, ylims=ylims .* 1.1,
           dpi=400)

x1s_ = range(xlims..., length=15)
x2s_ = range(ylims..., length=15)
xs = collect(Iterators.product(x1s_, x2s_))[:]
x1s = getindex.(xs, 1)
x2s = getindex.(xs, 2)
dxs = [[f(var=>x) for f in flow] for x in xs]
nx = maximum(dx -> norm(dx), dxs)
dxs1 = getindex.(dxs, 1) * 0.5 / nx
dxs2 = getindex.(dxs, 2) * 0.5 / nx
quiver!(x1s, x2s, quiver=(dxs1, dxs2), arrow=:closed)

x1s_ = range(xlims..., length=500)
x2s_ = range(ylims..., length=500)
Fplot_init(x1, x2) = maximum(g(var=>[x1, x2]) for g in inequalities(dom_init))
z = @. Fplot_init(x1s_', x2s_)
contourf!(x1s_, x2s_, z, levels=[0, 100],
          lw=5, c=:yellow, alpha=0.5, colorbar=:none)

#-------------------------------------------------------------------------------

nstep = 5
dt = 0.25
np = 20
rad = 0.5
vals = generate_vals_on_ball(np, xc, rad, dt, nstep, var, flow)

include("../src/main.jl")
const TK = ToolKit

F = TK.Field(var, flow)
points = [TK.Point(var, val) for val in vals]
λ = 1.0
ϵ = 1e-1

#-------------------------------------------------------------------------------

funcs = [1, x[1], x[2]]
hc = TK.hcone_from_points(funcs, F, λ, ϵ, points)
display(length(hc.halfspaces))

vc = TK.vcone_from_hcone(hc, () -> CDDLib.Library())
display(length(vc.rays))

δ = 1e-8
flag = @time TK.narrow_vcone!(vc, dom_init, F, λ, ϵ, δ, Inf, solver,
                              callback_func=callback_func)
@assert flag
display(length(vc.rays))
TK.simplify_vcone!(vc, 1e-5, solver, delete=false)
display(length(vc.rays))

Fplot_vc(x1, x2) = begin
    gxs = [g(var=>[x1, x2]) for g in vc.funcs]
    maximum(r -> dot(r.a, gxs), vc.rays)
end
z = @. Fplot_vc(x1s_', x2s_)
contour!(x1s_, x2s_, z, levels=[0], color=:green, lw=2)

#-------------------------------------------------------------------------------

funcs = [1, x[1]^2, x[1]*x[2], x[2]^2]
hc = TK.hcone_from_points(funcs, F, λ, ϵ, points)
display(length(hc.halfspaces))

vc = TK.vcone_from_hcone(hc, () -> CDDLib.Library())
display(length(vc.rays))

δ = 1e-8
flag = @time TK.narrow_vcone!(vc, dom_init, F, λ, ϵ, δ, Inf, solver,
                              callback_func=callback_func)
@assert flag
display(length(vc.rays))
TK.simplify_vcone!(vc, 1e-5, solver, delete=false)
display(length(vc.rays))

z = @. Fplot_vc(x1s_', x2s_)
contour!(x1s_, x2s_, z, levels=[0], color=:red, lw=2)

savefig(plt, "examples/figures/ahmed6.png")

#-------------------------------------------------------------------------------

file = open(string(@__DIR__, "/output.txt"), "w")
@polyvar x0 x1
println(file, "Flow")
for f in flow
    str = string(f(var=>[x0, x1]), ",")
    str = replace(str, "^"=>"**")
    println(file, str)
end
println(file, "Barriers python")
for r in vc.rays
    p = dot(vc.funcs, r.a)
    str = string(p(var=>[x0, x1]), ",")
    str = replace(str, "^"=>"**")
    println(file, str)
end
@polyvar x1 x2
println(file, "Barriers latex")
for r in vc.rays
    p = dot(vc.funcs, r.a)
    str = string(p(var=>[x1, x2]), ",")
    println(file, str)
end
close(file)

end # module