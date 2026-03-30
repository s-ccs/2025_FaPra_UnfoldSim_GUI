if !@isdefined(CACHED_HARTMUT)
	const CACHED_HARTMUT = Hartmut()
	println("✓ Loaded HArtMuT model")
end

if !@isdefined(CACHED_ELECTRODE_POSITIONS)
	const CACHED_ELECTRODE_POSITIONS = let
		h = CACHED_HARTMUT
		labels = h.electrodes["label"]
		pos_3d = h.electrodes["pos"]

		norms = vec(sqrt.(sum(pos_3d.^2, dims=2)))
		norms[norms .== 0] .= 1.0
		p = pos_3d ./ norms

		z3 = vec(p[:, 3])
		x3 = vec(p[:, 1])
		y3 = vec(p[:, 2])

		θ = acos.(clamp.(z3, -1.0, 1.0))
		φ = atan.(y3, x3)

		θ_max = maximum(θ)
		θ_max = θ_max > 0 ? θ_max : π
		r = θ ./ θ_max

		xs = r .* cos.(φ)
		ys = r .* sin.(φ)

		coords_2d = Dict{Symbol, Tuple{Float64, Float64}}()
		for i in 1:length(labels)
			coords_2d[Symbol(labels[i])] = (xs[i], ys[i])
		end
		coords_2d
	end
	println("✓ Cached $(length(CACHED_ELECTRODE_POSITIONS)) electrode positions (all channels, θ-normalised equidistant)")
end

function get_electrode_positions()
	return CACHED_ELECTRODE_POSITIONS
end
