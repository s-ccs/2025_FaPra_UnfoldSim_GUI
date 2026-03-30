function download_sim_files_smart(res, slider_config::Dict)
	try
		data_file = "simulation_data.csv"
		if size(res.multichannel_noisy, 1) > 0 && size(res.multichannel_noisy, 2) > 0
			data_df = DataFrame(res.multichannel_noisy, :auto)
			CSV.write(data_file, data_df)
		else
			empty_data = DataFrame(zeros(1, 1), :auto)
			CSV.write(data_file, empty_data)
		end
		events_file = "simulation_events.csv"
		if !isempty(res.events)
			events_df = copy(res.events)
		else
			events_df = DataFrame(
				sample = [1],
				condition = ["A"],
				subject = [1],
				latency = [0.0]
			)
		end
		config_json = JSON3.write(slider_config)
		events_df[!, :metadata] .= config_json
		CSV.write(events_file, events_df)
		return "✓ Saved: simulation_data.csv, simulation_events.csv ($(length(slider_config)) params)"
	catch e
		return "✗ Error saving files: $(sprint(showerror, e))"
	end
end
