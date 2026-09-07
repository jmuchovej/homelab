const TOOLENVS = Dict{VersionNumber,String}(
# @@tool-envs@@
)

let env = get(TOOLENVS, VersionNumber(VERSION.major, VERSION.minor), nothing)
    if env !== nothing
        depot = joinpath(env, "depot")
        depot in DEPOT_PATH || push!(DEPOT_PATH, depot)

        # insert *after* @v#.# (just before @stdlib). inserting earlier makes
        # this the active project on a bare `julia` (which sucks 'cause it's read-only).
        proj = joinpath(env, "project", "Project.toml")
        if proj ∉ LOAD_PATH
            i = findfirst(==("@stdlib"), LOAD_PATH)
            insert!(LOAD_PATH, something(i, length(LOAD_PATH) + 1), proj)
        end
    end
end

# https://timholy.github.io/Revise.jl/stable/config/#Using-Revise-automatically-within-Jupyter/IJulia-1
if isinteractive()
    try
        @eval using OhMyREPL
        @eval using AbbreviatedStackTraces
        @eval using Revise
    catch e
        @warn "Julia REPL tooling unavailable" exception = (e, catch_backtrace())
    end
end
