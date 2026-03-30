function draw_head_outline!(ax)
	θ = range(0, 2π, length=100)
	lines!(ax, cos.(θ), sin.(θ), color=RGBAf(0.78, 0.84, 0.91, 1.0), linewidth=2)
	lines!(ax, [0.0, -0.15, 0.15, 0.0], [1.0, 1.15, 1.15, 1.0], color=RGBAf(0.78, 0.84, 0.91, 1.0), linewidth=2)
	lines!(ax, [-1.0, -1.1, -1.1, -1.0], [0.15, 0.15, -0.15, -0.15], color=RGBAf(0.78, 0.84, 0.91, 1.0), linewidth=2)
	lines!(ax, [1.0, 1.1, 1.1, 1.0], [0.15, 0.15, -0.15, -0.15], color=RGBAf(0.78, 0.84, 0.91, 1.0), linewidth=2)
end

function plot_expexplorer_topoplot(multichannel_data, positions, time_point, viz_mode)
	try
		n_samples, n_channels = size(multichannel_data)
		if viz_mode == "Amplitude"
			time_idx = min(max(1, time_point), n_samples)
			amplitudes = multichannel_data[time_idx, :]
		elseif viz_mode == "RMS"
			metrics = ERPExplorer.calculate_erp_metrics(multichannel_data)
			amplitudes = metrics[:rms]
		elseif viz_mode == "Peak Detection"
			metrics = ERPExplorer.calculate_erp_metrics(multichannel_data)
			amplitudes = metrics[:peak_amplitude]
		else
			metrics = ERPExplorer.calculate_erp_metrics(multichannel_data)
			amplitudes = metrics[:mean_amplitude]
		end
		amp_min, amp_max = extrema(amplitudes)
		amp_range = amp_max - amp_min
		if amp_range > 0
			norm_amps = (amplitudes .- amp_min) ./ amp_range
		else
			norm_amps = fill(0.5, length(amplitudes))
		end
		colors = fill(RGBAf(0.2, 0.4, 0.9, 0.85), length(amplitudes))
		return colors, amplitudes
	catch e
		return fill(RGBAf(0.5, 0.5, 0.5, 0.8), length(positions)), zeros(length(positions))
	end
end
