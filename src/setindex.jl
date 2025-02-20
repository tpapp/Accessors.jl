Base.@propagate_inbounds function setindex(args...)
    Base.setindex(args...)
end

@inline setindex(::Base.RefValue, val) = Ref(val)

Base.@propagate_inbounds function setindex(xs::AbstractArray, v, I...)
    T = promote_type(eltype(xs), typeof(v))
    ys = similar(xs, T)
    if eltype(xs) !== Union{}
        copy!(ys, xs)
    end
    ys[I...] = v
    return ys
end

Base.@propagate_inbounds function setindex(d0::AbstractDict, v, k)
    K = promote_type(keytype(d0), typeof(k))
    V = promote_type(valtype(d0), typeof(v))
    d = empty(d0, K, V)
    copy!(d, d0)
    d[k] = v
    return d
end

@inline setindex(x::NamedTuple{names}, v, i::Int) where {names} = NamedTuple{names}(setindex(values(x), v, i))

# copied from Base: this method doesn't exist in Julia 1.3
@inline setindex(nt::NamedTuple, v, idx::Symbol) = merge(nt, (; idx => v))

@inline setindex(nt::NamedTuple, v, idx::Tuple{Vararg{Symbol}}) = merge(nt, NamedTuple{idx}(v))
