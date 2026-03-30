if !@isdefined(THROTTLE_DT)
	const THROTTLE_DT = 0.05
end
if !@isdefined(SLIDER_THROTTLE)
	const SLIDER_THROTTLE = 0.1
end
if !@isdefined(SIMULATION_DEBOUNCE)
	const SIMULATION_DEBOUNCE = 0.5
end

if !@isdefined(CLEAN_SIGNAL_CHANNEL_NAME)
	const CLEAN_SIGNAL_CHANNEL_NAME = :AF3
end

if !@isdefined(hanning_colors)
	const hanning_colors = Dict(
		"P100 (Positive)" => :blue,
		"N170 (Negative)" => :orange,
		"P300 (Positive)" => :green,
		"N400 (Negative)" => :magenta,
	)
end

if !@isdefined(VARIABLE_TEMPLATES)
	const VARIABLE_TEMPLATES = Dict(
		"condition" => ["A", "B"],
		"stimulus_type" => ["face", "car", "house"],
		"task" => ["visual", "auditory", "tactile"],
		"emotion" => ["happy", "sad", "neutral", "angry"],
		"color" => ["red", "green", "blue"],
		"intensity" => (min=0.0, max=10.0, steps=5),
		"contrast" => (min=0.0, max=1.0, steps=10),
		"duration" => (min=100.0, max=500.0, steps=5),
		"frequency" => (min=1.0, max=20.0, steps=10)
	)
	println("✓ Loaded variable templates")
end
