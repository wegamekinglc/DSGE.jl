abstract AbstractDSGEModel{T<:AbstractFloat}

function Base.show{T<:AbstractDSGEModel}(io::IO, m::T)
    @printf io "Dynamic Stochastic General Equilibrium Model\n"
    @printf io "%s\n" T
    @printf io "no. states:             %i\n" num_states(m)
    @printf io "no. anticipated shocks: %i\n" num_anticipated_shocks(m)
    @printf io "no. anticipated lags:   %i\n" num_anticipated_lags(m)
    @printf io "description:\n %s\n"          description(m)
end

# TODO consider stacking all parameters in a single vector. Alternately, all fixed
# parameters can be added to the normal parameters vector at a (potentially negligible)
# performance hit.
@inline function Base.getindex(m::AbstractDSGEModel, i::Integer)
    if i <= (j = length(m.parameters))
        return m.parameters[i]
    else
        return m.steady_state[i-j]
    end
end

# need to define like this so we can disable bounds checking
@inline function Base.getindex(m::AbstractDSGEModel, k::Symbol)
    i = m.keys[k]
    @inbounds if i <= (j = length(m.parameters))
        return m.parameters[i]
    else
        return m.steady_state[i-j]
    end
end

@inline function Base.setindex!(m::AbstractDSGEModel, value, i::Integer)
    if i <= (j = length(m.parameters))
        param = m.parameters[i]
        param.value = value
        if isa(ScaledParameter)
            param.scaledvalue = param.scaling(value)
        end
        return param
    else
        ssparam = m.steady_state[i-j]
        ssparam.value = value
        return ssparam
    end
end
Base.setindex!(m::AbstractDSGEModel, value, k::Symbol) = Base.setindex!(m, value, m.keys[k])

#=
"""
(<=){T}(m::AbstractDSGEModel{T}, p::AbstractParameter{T})

Syntax for adding a parameter to a model: m <= parameter.
NOTE: If `p` is added to `m` and length(m.steady_state) > 0, `keys(m)` will not generate the index of `p` in `m.parameters`.
"""
=#
function (<=){T}(m::AbstractDSGEModel{T}, p::AbstractParameter{T})
    @assert !in(p.key, keys(m.keys)) "Key $(p.key) is already present in DSGE model"

    new_param_index = length(m.keys) + 1

    # grow parameters and add the parameter
    push!(m.parameters, p)

    # add parameter location to dict
    setindex!(m.keys, new_param_index, p.key)
end

#=
"""
(<=){T}(m::AbstractDSGEModel{T}, ssp::SteadyStateParameter)

Add a new steady-state value to the model by appending `ssp` to the `m.steady_state` and adding `ssp.key` to `m.keys`.
"""
=#
function (<=){T}(m::AbstractDSGEModel{T}, ssp::SteadyStateParameter)
    @assert !in(ssp.key, keys(m.keys)) "Key $(ssp) is already present in DSGE model"

    new_param_index = length(m.keys) + 1

    # append ssp to steady_state vector
    push!(m.steady_state, ssp)

    # add parameter location to dict
    setindex!(m.keys, new_param_index, ssp.key)
end

## Defunct bc steady state values have their own type now
## #=
## """
## (<=)(m::AbstractDSGEModel, vec::Vector{Symbol})

## Add all elements of `vec` to the `m.steady_state`. Update `m.keys` appropriately.
## """
## =#

## function (<=)(m::AbstractDSGEModel, vec::Vector{Symbol})
##     for k in vec
##         m <= k
##     end
## end

Distributions.logpdf(m::AbstractDSGEModel) = logpdf(m.parameters)
Distributions.pdf(m::AbstractDSGEModel) = exp(logpdf(m))

# Number of anticipated policy shocks
num_anticipated_shocks(m::AbstractDSGEModel) = m.num_anticipated_shocks

# Padding for nant
num_anticipated_shocks_padding(m::AbstractDSGEModel) = m.num_anticipated_shocks_padding

# Number of periods back we should start incorporating zero bound expectations
# ZLB expectations should begin in 2008 Q4
num_anticipated_lags(m::AbstractDSGEModel) = m.num_anticipated_lags

# TODO: This should be set when the data are read in
# Number of presample periods
num_presample_periods(m::AbstractDSGEModel) = m.num_presample_periods

# Number of a few things that are useful apparently
num_states(m::AbstractDSGEModel)                 = length(m.endogenous_states)
num_states_augmented(m::AbstractDSGEModel)       = num_states(m) + length(m.endogenous_states_postgensys)
num_shocks_exogenous(m::AbstractDSGEModel)       = length(m.exogenous_shocks)
num_shocks_expectational(m::AbstractDSGEModel)   = length(m.expected_shocks)
num_equilibrium_conditions(m::AbstractDSGEModel) = length(m.equilibrium_conditions)
num_observables(m::AbstractDSGEModel)            = length(m.observables)
num_parameters(m::AbstractDSGEModel)             = length(m.parameters)
num_parameters_fixed(m::AbstractDSGEModel)       = length(m.parameters_fixed)
num_parameters_steady_state(m::AbstractDSGEModel)= length(m.steady_state)
num_parameters_free(m::AbstractDSGEModel)        = sum([!α.fixed for α in m.parameters])

# Paths to where input/output/results data are stored
savepath(m::AbstractDSGEModel)  = normpath(m.savepath)
inpath(m::AbstractDSGEModel)    = normpath(joinpath(m.savepath, "input_data/"))
outpath(m::AbstractDSGEModel)   = normpath(joinpath(m.savepath, "output_data/"))
tablepath(m::AbstractDSGEModel) = normpath(joinpath(m.savepath, "results/tables/"))
plotpath(m::AbstractDSGEModel)  = normpath(joinpath(m.savepath, "results/plots/"))
logpath(m::AbstractDSGEModel)   = normpath(joinpath(m.savepath, "logs/"))

# TODO is there a better place for these? They do depend on AbstractDSGEModel type.
function tomodel!{T<:AbstractFloat}(m::AbstractDSGEModel, values::Vector{T})
    tomodel!(values, m.parameters)
    return steadystate!(m)
end
function update!{T<:AbstractFloat}(m::AbstractDSGEModel, values::Vector{T})
    update!(m.parameters, values)
    return steadystate!(m)
end

