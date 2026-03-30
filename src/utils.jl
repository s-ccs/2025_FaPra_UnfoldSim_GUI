function hanning_p100()
	t = range(0, 0.5, length=100)
	y = exp.(-(t .- 0.1).^2 / (2*0.02^2)) * 2.0
	return y
end

function hanning_n170()
	t = range(0, 0.5, length=100)
	y = -exp.(-(t .- 0.17).^2 / (2*0.03^2)) * 1.5
	return y
end

function hanning_p300()
	t = range(0, 0.8, length=160)
	y = exp.(-(t .- 0.3).^2 / (2*0.05^2)) * 3.0
	return y
end

function hanning_n400()
	t = range(0, 0.8, length=160)
	y = -exp.(-(t .- 0.4).^2 / (2*0.06^2)) * 2.0
	return y
end

function hanning(width, shift, sfreq)
	window = 0.5 .- 0.5 .* cos.(2π .* (0:width-1) ./ (width-1))
	padded = zeros(width + shift)
	padded[shift+1:end] .= window
	return padded
end

map_to_beta(gui_val) = (gui_val - 50) / 2.5
map_to_contrast(gui_val) = (gui_val - 50) / 5
map_to_sigma(gui_val) = gui_val / 20
map_to_subjects(gui_val) = max(1, round(Int, gui_val / 2))
map_to_items(gui_val) = max(2, round(Int, gui_val))
map_to_noise(gui_val) = gui_val / 10
map_to_mu(gui_val) = -1.0 + (gui_val / 100) * 3.0
map_to_onset_sigma(gui_val) = 0.1 + (gui_val / 100) * 0.9
map_to_offset(gui_val) = round(Int, gui_val * 2)
map_to_truncate(gui_val) = round(Int, 50 + gui_val * 4.5)
map_to_truncate_lower(gui_val) = round(Int, gui_val * 5)
map_to_width(gui_val) = round(Int, 10 + gui_val * 1.9)

inv_beta(v)           = clamp(round(Int, v * 2.5 + 50), 0, 100)
inv_contrast(v)       = clamp(round(Int, v * 5 + 50), 0, 100)
inv_sigma(v)          = clamp(round(Int, v * 20), 0, 100)
inv_subjects(v)       = clamp(round(Int, v * 2), 0, 100)
inv_items(v)          = clamp(round(Int, v), 0, 100)
inv_noise(v)          = clamp(round(Int, v * 10), 0, 100)
inv_mu(v)             = clamp(round(Int, (v + 1.0) / 3.0 * 100), 0, 100)
inv_onset_sigma(v)    = clamp(round(Int, (v - 0.1) / 0.9 * 100), 0, 100)
inv_offset(v)         = clamp(round(Int, v / 2), 0, 100)
inv_truncate(v)       = clamp(round(Int, (v - 50) / 4.5), 0, 100)
inv_truncate_lower(v) = clamp(round(Int, v / 5), 0, 100)
inv_width(v)          = clamp(round(Int, (v - 10) / 1.9), 0, 100)

function get_channel_colors(n_channels)
	return [ColorSchemes.jet[i / n_channels] for i in 1:n_channels]
end

function count_formula_terms(formula_str::String, cat_vars::Dict, cont_vars::Dict)
	if !occursin("+", formula_str) || formula_str == "@formula(0 ~ 1)"
		return 1
	end
	n_terms = 1
	clean_formula = replace(formula_str, r"@formula\([^~]*~\s*" => "")
	clean_formula = replace(clean_formula, ")" => "")
	terms = [strip(t) for t in split(clean_formula, "+")]
	filter!(t -> t != "1", terms)
	for term in terms
		base_var = replace(term, r"\^[0-9]+" => "")
		base_var = strip(base_var)
		if haskey(cat_vars, base_var)
			n_levels = length(cat_vars[base_var])
			n_terms += (n_levels - 1)
		else
			n_terms += 1
		end
	end
	return n_terms
end

function build_design_from_events(categorical_vars::Dict, continuous_vars::Dict,
								   design_type::String, n_items::Int, n_subjects::Int)
	conditions = Dict{Symbol, Any}()
	for (var_name, levels) in categorical_vars
		if !isempty(levels)
			conditions[Symbol(var_name)] = levels
		end
	end
	for (var_name, params) in continuous_vars
		conditions[Symbol(var_name)] = range(params.min, params.max, length=params.steps)
	end
	if isempty(conditions)
		conditions[:condition] = ["A", "B"]
	end
	if design_type == "Single-subject design"
		return SingleSubjectDesign(; conditions = conditions)
	elseif design_type == "Repeat design"
		base_design = SingleSubjectDesign(; conditions = conditions)
		return RepeatDesign(base_design, n_items)
	else
		items_between_dict = Dict{Symbol, Any}()
		for (var_name, levels) in categorical_vars
			if !isempty(levels)
				items_between_dict[Symbol(var_name)] = levels
				break
			end
		end
		if isempty(items_between_dict)
			items_between_dict[:condition] = ["A", "B"]
		end
		ni_adjusted = n_items % 2 == 0 ? n_items : n_items - 1
		return MultiSubjectDesign(n_subjects = n_subjects, n_items = ni_adjusted,
								  items_between = items_between_dict)
	end
end
