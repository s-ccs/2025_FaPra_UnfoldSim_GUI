module ERPExplorer
	using Statistics
	using LinearAlgebra

	export calculate_erp_metrics, create_topoplot_interpolation, detect_peaks

	function calculate_erp_metrics(data::Matrix)
		n_samples, n_channels = size(data)
		metrics = Dict(
			:rms => [sqrt(mean(data[:, i].^2)) for i in 1:n_channels],
			:peak_amplitude => [maximum(abs.(data[:, i])) for i in 1:n_channels],
			:mean_amplitude => [mean(data[:, i]) for i in 1:n_channels],
			:std => [std(data[:, i]) for i in 1:n_channels]
		)
		return metrics
	end

	function detect_peaks(signal::Vector, threshold::Float64=0.5)
		peaks = Int[]
		for i in 2:length(signal)-1
			if abs(signal[i]) > threshold &&
			   abs(signal[i]) > abs(signal[i-1]) &&
			   abs(signal[i]) > abs(signal[i+1])
				push!(peaks, i)
			end
		end
		return peaks
	end

	function create_topoplot_interpolation(positions, values)
		return values
	end
end
