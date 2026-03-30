# ============================================================
# EVENT MANAGER
# Owns: all event-variable widgets, reactive handlers, DOM
# ============================================================

"""
Create all event-variable widgets, register reactive handlers,
and return the DOM block for embedding in the sidebar.
"""
function init_event_manager!(state::AppState)
    label_s = state.label_s

    # ── Widgets ──────────────────────────────────────────────
    cat_var_options = ["condition", "stimulus_type", "task", "emotion", "color"]
    cat_var_dropdown       = Bonito.Dropdown(cat_var_options; index=1)
    add_cat_var_button     = Bonito.Button("+ Add Template")
    custom_cat_name        = Bonito.TextField("my_variable")
    custom_cat_levels      = Bonito.TextField("level1, level2, level3")
    add_custom_cat_button  = Bonito.Button("+ Add Custom Categorical")
    remove_cat_var_dropdown = Bonito.Dropdown(["condition"]; index=1)
    remove_cat_var_button  = Bonito.Button("- Remove Selected")

    cont_var_options = ["intensity", "contrast", "duration", "frequency"]
    cont_var_dropdown       = Bonito.Dropdown(cont_var_options; index=1)
    add_cont_var_button     = Bonito.Button("+ Add Template")
    custom_cont_name        = Bonito.TextField("my_continuous")
    custom_cont_min         = Bonito.TextField("0.0")
    custom_cont_max         = Bonito.TextField("10.0")
    custom_cont_steps       = Bonito.TextField("5")
    add_custom_cont_button  = Bonito.Button("+ Add Custom Continuous")
    remove_cont_var_dropdown = Bonito.Dropdown(["intensity"]; index=1)
    remove_cont_var_button  = Bonito.Button("- Remove Selected")

    # ── Sync remove-dropdowns when variables change ───────────
    on(state.categorical_variables) do cat_vars
        options = isempty(cat_vars) ? ["none"] : collect(keys(cat_vars))
        remove_cat_var_dropdown.options[] = options
        remove_cat_var_dropdown.value[]   = options[1]
    end
    on(state.continuous_variables) do cont_vars
        options = isempty(cont_vars) ? ["none"] : collect(keys(cont_vars))
        remove_cont_var_dropdown.options[] = options
        remove_cont_var_dropdown.value[]   = options[1]
    end

    # ── Button handlers ───────────────────────────────────────
    on(add_cat_var_button.value) do _
        try
            var_name = cat_var_dropdown.value[]
            !haskey(VARIABLE_TEMPLATES, var_name) &&
                (state.event_status[] = "❌ Template not found: $var_name"; return)
            levels = VARIABLE_TEMPLATES[var_name]
            new_vars = copy(state.categorical_variables[])
            new_vars[var_name] = levels
            state.categorical_variables[] = new_vars
            state.event_status[] = "✓ Added template: $var_name = $levels"
        catch e; state.event_status[] = "❌ $(sprint(showerror,e))"; end
    end

    on(add_custom_cat_button.value) do _
        try
            var_name = strip(custom_cat_name.value[])
            levels   = [strip(s) for s in split(custom_cat_levels.value[], ',') if !isempty(strip(s))]
            isempty(var_name)  && (state.event_status[] = "❌ Name cannot be empty"; return)
            isempty(levels)    && (state.event_status[] = "❌ Provide at least one level"; return)
            new_vars = copy(state.categorical_variables[])
            new_vars[var_name] = levels
            state.categorical_variables[] = new_vars
            state.event_status[] = "✓ Added custom: $var_name = $levels"
        catch e; state.event_status[] = "❌ $(sprint(showerror,e))"; end
    end

    on(remove_cat_var_button.value) do _
        try
            var_name = remove_cat_var_dropdown.value[]
            var_name == "none" && (state.event_status[] = "❌ Nothing to remove"; return)
            new_vars = copy(state.categorical_variables[])
            haskey(new_vars, var_name) || (state.event_status[] = "❌ Not found: $var_name"; return)
            delete!(new_vars, var_name)
            state.categorical_variables[] = new_vars
            state.event_status[] = "✓ Removed: $var_name"
        catch e; state.event_status[] = "❌ $(sprint(showerror,e))"; end
    end

    on(add_cont_var_button.value) do _
        try
            var_name = cont_var_dropdown.value[]
            !haskey(VARIABLE_TEMPLATES, var_name) &&
                (state.event_status[] = "❌ Template not found: $var_name"; return)
            params = VARIABLE_TEMPLATES[var_name]
            new_vars = copy(state.continuous_variables[])
            new_vars[var_name] = params
            state.continuous_variables[] = new_vars
            state.event_status[] = "✓ Added template: $var_name"
        catch e; state.event_status[] = "❌ $(sprint(showerror,e))"; end
    end

    on(add_custom_cont_button.value) do _
        try
            var_name  = strip(custom_cont_name.value[])
            min_val   = parse(Float64, custom_cont_min.value[])
            max_val   = parse(Float64, custom_cont_max.value[])
            steps_val = parse(Int,     custom_cont_steps.value[])
            isempty(var_name)       && (state.event_status[] = "❌ Name empty"; return)
            steps_val < 2           && (state.event_status[] = "❌ Steps ≥ 2"; return)
            min_val >= max_val      && (state.event_status[] = "❌ Min < Max required"; return)
            new_vars = copy(state.continuous_variables[])
            new_vars[var_name] = (min=min_val, max=max_val, steps=steps_val)
            state.continuous_variables[] = new_vars
            state.event_status[] = "✓ Added: $var_name [$min_val:$max_val, $steps_val steps]"
        catch e; state.event_status[] = "❌ $(sprint(showerror,e))"; end
    end

    on(remove_cont_var_button.value) do _
        try
            var_name = remove_cont_var_dropdown.value[]
            var_name == "none" && (state.event_status[] = "❌ Nothing to remove"; return)
            new_vars = copy(state.continuous_variables[])
            haskey(new_vars, var_name) || (state.event_status[] = "❌ Not found: $var_name"; return)
            delete!(new_vars, var_name)
            state.continuous_variables[] = new_vars
            state.event_status[] = "✓ Removed: $var_name"
        catch e; state.event_status[] = "❌ $(sprint(showerror,e))"; end
    end

    # ── Live display of current variables ─────────────────────
    event_variables_display = map(state.categorical_variables, state.continuous_variables) do cat, cont
        lines = String["📊 Current Event Variables:"]
        if !isempty(cat)
            push!(lines, "\n🔤 Categorical:")
            for (n, lvls) in cat; push!(lines, "  • $n = $(join(lvls, ", "))"); end
        end
        if !isempty(cont)
            push!(lines, "\n📈 Continuous:")
            for (n, p) in cont; push!(lines, "  • $n = [$(p.min):$(p.max), $(p.steps) steps]"); end
        end
        isempty(cat) && isempty(cont) && push!(lines, "  (using defaults)")
        join(lines, "\n")
    end

    return build_event_definition_ui(
        label_s,
        cat_var_dropdown, add_cat_var_button,
        custom_cat_name, custom_cat_levels, add_custom_cat_button,
        remove_cat_var_dropdown, remove_cat_var_button,
        cont_var_dropdown, add_cont_var_button,
        custom_cont_name, custom_cont_min, custom_cont_max, custom_cont_steps,
        add_custom_cont_button,
        remove_cont_var_dropdown, remove_cont_var_button,
        event_variables_display, state.event_status,
    )
end

# ── DOM builder (pure, no side effects) ──────────────────────
function build_event_definition_ui(
    label_s,
    cat_var_dropdown, add_cat_var_button,
    custom_cat_name, custom_cat_levels, add_custom_cat_button,
    remove_cat_var_dropdown, remove_cat_var_button,
    cont_var_dropdown, add_cont_var_button,
    custom_cont_name, custom_cont_min, custom_cont_max, custom_cont_steps,
    add_custom_cont_button,
    remove_cont_var_dropdown, remove_cont_var_button,
    event_variables_display, event_status,
)
	return Bonito.DOM.div(
        Bonito.DOM.h4("Event Definition", style="font-size: 13px; margin: 6px 0; color: var(--accent); font-weight: 700;"),
		Bonito.DOM.div(
			Bonito.DOM.span("💡 Create variables using templates OR define your own custom variables.",
                style="font-size: 10px; color: var(--text2); font-style: italic; display: block; margin-bottom: 8px;"),
			style="padding: 8px; background: rgba(187,128,9,0.1); border-left: 3px solid #d29922; border-radius: 4px; margin-bottom: 8px;"
		),
		Bonito.DOM.div(
            Bonito.DOM.span("🔤 Categorical Variables", style="font-weight: 700; font-size: 11px; display: block; margin-bottom: 8px; color: var(--accent2);"),
			Bonito.DOM.div(
                Bonito.DOM.span("📋 Quick Templates:", style="font-weight: 700; font-size: 10px; display: block; margin-bottom: 4px; color: var(--text1);"),
				Bonito.DOM.span("Select Template:", style=label_s),
				cat_var_dropdown,
				Bonito.DOM.div(
                    Bonito.DOM.span("• condition (A, B)", style="font-size: 9px; color: var(--text2); font-family: monospace; display: block;"),
                    Bonito.DOM.span("• stimulus_type (face, car, house)", style="font-size: 9px; color: var(--text2); font-family: monospace; display: block;"),
                    Bonito.DOM.span("• task (visual, auditory, tactile)", style="font-size: 9px; color: var(--text2); font-family: monospace; display: block;"),
                    Bonito.DOM.span("• emotion (happy, sad, neutral, angry)", style="font-size: 9px; color: var(--text2); font-family: monospace; display: block;"),
                    Bonito.DOM.span("• color (red, green, blue)", style="font-size: 9px; color: var(--text2); font-family: monospace; display: block; margin-bottom: 4px;"),
                    style="padding: 6px; background: var(--bg2); border-radius: 4px; margin-top: 4px; margin-bottom: 4px; border: 1px solid var(--border);"
				),
				add_cat_var_button,
				style="padding: 8px; background: rgba(63,185,80,0.08); border-radius: 6px; margin-bottom: 8px; border: 1px solid rgba(63,185,80,0.2);"
			),
			Bonito.DOM.div(
                Bonito.DOM.span("✏️ Create Custom:", style="font-weight: 700; font-size: 10px; display: block; margin-bottom: 4px; color: var(--text1);"),
				Bonito.DOM.span("Variable Name:", style=label_s), custom_cat_name,
				Bonito.DOM.span("Levels (comma-separated):", style=label_s), custom_cat_levels,
				Bonito.DOM.span("Example: object_type → chair, table, lamp, desk",
                    style="font-size: 9px; color: var(--text2); font-style: italic; margin-top: 2px; display: block;"),
				Bonito.DOM.div(add_custom_cat_button, style="margin-top: 6px;"),
				style="padding: 8px; background: rgba(210,153,34,0.08); border-radius: 6px; margin-bottom: 8px; border: 1px solid rgba(210,153,34,0.2);"
			),
			Bonito.DOM.div(
                Bonito.DOM.span("🗑️ Remove Variable:", style="font-weight: 700; font-size: 10px; display: block; margin-bottom: 4px; color: var(--text1);"),
				remove_cat_var_dropdown,
				Bonito.DOM.div(remove_cat_var_button, style="margin-top: 6px;"),
				style="padding: 8px; background: rgba(248,81,73,0.08); border-radius: 6px; border: 1px solid rgba(248,81,73,0.2);"
			),
            style="padding: 10px; background: rgba(88,166,255,0.06); border-radius: 6px; margin-bottom: 12px; border: 1px solid var(--border);"
		),
		Bonito.DOM.div(
            Bonito.DOM.span("📈 Continuous Variables", style="font-weight: 700; font-size: 11px; display: block; margin-bottom: 8px; color: var(--accent2);"),
			Bonito.DOM.div(
                Bonito.DOM.span("📋 Quick Templates:", style="font-weight: 700; font-size: 10px; display: block; margin-bottom: 4px; color: var(--text1);"),
				Bonito.DOM.span("Select Template:", style=label_s), cont_var_dropdown,
				Bonito.DOM.div(
                    Bonito.DOM.span("• intensity (0.0 to 10.0, 5 steps)", style="font-size: 9px; color: var(--text2); font-family: monospace; display: block;"),
                    Bonito.DOM.span("• contrast (0.0 to 1.0, 10 steps)", style="font-size: 9px; color: var(--text2); font-family: monospace; display: block;"),
                    Bonito.DOM.span("• duration (100.0 to 500.0, 5 steps)", style="font-size: 9px; color: var(--text2); font-family: monospace; display: block;"),
                    Bonito.DOM.span("• frequency (1.0 to 20.0, 10 steps)", style="font-size: 9px; color: var(--text2); font-family: monospace; display: block; margin-bottom: 4px;"),
                    style="padding: 6px; background: var(--bg2); border-radius: 4px; margin-top: 4px; margin-bottom: 4px; border: 1px solid var(--border);"
				),
				add_cont_var_button,
				style="padding: 8px; background: rgba(63,185,80,0.08); border-radius: 6px; margin-bottom: 8px; border: 1px solid rgba(63,185,80,0.2);"
			),
			Bonito.DOM.div(
                Bonito.DOM.span("✏️ Create Custom:", style="font-weight: 700; font-size: 10px; display: block; margin-bottom: 4px; color: var(--text1);"),
				Bonito.DOM.span("Variable Name:", style=label_s), custom_cont_name,
				Bonito.DOM.span("Min Value:", style=label_s), custom_cont_min,
				Bonito.DOM.span("Max Value:", style=label_s), custom_cont_max,
				Bonito.DOM.span("Number of Steps:", style=label_s), custom_cont_steps,
				Bonito.DOM.span("Example: temperature → 20.0 to 40.0, 8 steps",
                    style="font-size: 9px; color: var(--text2); font-style: italic; margin-top: 2px; display: block;"),
				Bonito.DOM.div(add_custom_cont_button, style="margin-top: 6px;"),
				style="padding: 8px; background: rgba(210,153,34,0.08); border-radius: 6px; margin-bottom: 8px; border: 1px solid rgba(210,153,34,0.2);"
			),
			Bonito.DOM.div(
                Bonito.DOM.span("🗑️ Remove Variable:", style="font-weight: 700; font-size: 10px; display: block; margin-bottom: 4px; color: var(--text1);"),
				remove_cont_var_dropdown,
				Bonito.DOM.div(remove_cont_var_button, style="margin-top: 6px;"),
				style="padding: 8px; background: rgba(248,81,73,0.08); border-radius: 6px; border: 1px solid rgba(248,81,73,0.2);"
			),
            style="padding: 10px; background: rgba(210,153,34,0.06); border-radius: 6px; margin-bottom: 12px; border: 1px solid var(--border);"
		),
		Bonito.DOM.div(
            Bonito.DOM.span(event_variables_display, style="font-size: 10px; color: var(--text1); white-space: pre-wrap; font-family: 'Fira Code', 'Cascadia Code', monospace;"),
            style="padding: 8px; background: var(--bg2); border-radius: 6px; border-left: 3px solid var(--green2); margin-bottom: 8px; border: 1px solid var(--border);"
		),
		Bonito.DOM.div(
            Bonito.DOM.span(event_status, style="font-size: 10px; font-weight: 700; color: var(--green2);"),
            style="padding: 6px 10px; background: var(--bg2); border-radius: 6px; border: 1px solid var(--green1);"
		)
	)
end
