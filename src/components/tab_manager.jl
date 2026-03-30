# ============================================================
# TAB MANAGER
# Owns: create_new_tab, Hanning overlay controls, tab UI
# ============================================================

function init_tab_manager!(state::AppState)
    label_s = state.label_s
    tab_beta_textfields = Dict{String,Any}()
    tab_contrast_textfields = Dict{String,Any}()
    tab_formula_dropdowns = Dict{String,Any}()
    tab_formula_use_buttons = Dict{String,Any}()

    function build_formula_options(cat_vars, cont_vars)
        cat_names = collect(keys(cat_vars))
        cont_names = collect(keys(cont_vars))
        all_terms = vcat(cat_names, cont_names)

        options = String["@formula(0 ~ 1)"]
        if !isempty(all_terms)
            push!(options, "@formula(0 ~ 1 + $(join(all_terms, " + ")))")
        end
        if !isempty(cat_names)
            push!(options, "@formula(0 ~ 1 + $(join(cat_names, " + ")))")
        end
        if !isempty(cont_names)
            push!(options, "@formula(0 ~ 1 + $(join(cont_names, " + ")))")
        end
        if !isempty(cat_names) && !isempty(cont_names)
            push!(options, "@formula(0 ~ 1 + $(cat_names[1]) * $(cont_names[1]))")
        end
        return unique(options)
    end

    # ── Helper: sync selected_hannings from current tabs ─────
    function sync_selected_hannings!()
        s = Set{String}()
        for t in state.component_tabs[]
            t.name == "Custom" && continue
            push!(s, t.name)
        end
        state.selected_hannings[] = s
    end

    # ── Helper: remove a tab by preset name ──────────────────
    function remove_hanning_tab!(preset_name::String)
        preset_name == "Custom" && return false
        tabs = copy(state.component_tabs[])
        idx  = findfirst(t -> t.name == preset_name, tabs)
        idx === nothing && return false
        length(tabs) <= 1 && return false
        removed = tabs[idx]
        deleteat!(tabs, idx)
        pop!(tab_beta_textfields, removed.id, nothing)
        pop!(tab_contrast_textfields, removed.id, nothing)
        pop!(tab_formula_dropdowns, removed.id, nothing)
        pop!(tab_formula_use_buttons, removed.id, nothing)
        state.component_tabs[] = tabs
        if state.active_tab_id[] == removed.id && !isempty(tabs)
            state.active_tab_id[] = tabs[clamp(idx, 1, length(tabs))].id
        end
        pruned = Dict{String,Any}()
        for (k, v) in state.all_tab_results[]
            k == removed.id && continue
            pruned[k] = v
        end
        state.all_tab_results[] = pruned
        return true
    end

    # ── create_new_tab ────────────────────────────────────────
    function create_new_tab(preset_name::String)
        state.tab_counter[] += 1
        tab_id = "tab_$(state.tab_counter[])"

        presets   = ["Custom","N170 (Negative)","N400 (Negative)","P100 (Positive)","P300 (Positive)"]
        preset_idx = something(findfirst(==(preset_name), presets), 1)

        model_cat  = Bonito.Dropdown(["Linear Model","Mixed Model","Multi-channel Model"]; index=1)
        hanning_pre = Bonito.Dropdown(presets; index=preset_idx)
        contrast_t  = Bonito.Dropdown(["DummyCoding","EffectsCoding"]; index=1)

        basis_defaults = Dict(
            "Custom"         => "hanning(40, 0, 100)",
            "N170 (Negative)"=> "-hanning(20, 15, 100)",
            "N400 (Negative)"=> "-hanning(50, 35, 100)",
            "P100 (Positive)"=> "hanning(15, 8, 100)",
            "P300 (Positive)"=> "hanning(40, 25, 100)",
        )
        beta_defaults = Dict("Custom"=>50,"N170 (Negative)"=>40,"N400 (Negative)"=>35,
                             "P100 (Positive)"=>60,"P300 (Positive)"=>65)

        basis_t      = Bonito.TextField(basis_defaults[preset_name])
        formula_t    = Bonito.TextField("@formula(0 ~ 1 + condition)")
        formula_opts = build_formula_options(state.categorical_variables[], state.continuous_variables[])
        formula_d    = Bonito.Dropdown(formula_opts; index=1)
        formula_btn  = Bonito.Button("Apply")
        projection_t = Bonito.TextField("[1.0, 0.5, -0.2]")
        beta_s       = Bonito.Slider(0:1:100; value=beta_defaults[preset_name])
        beta_tf      = make_synced_textfield(beta_s, map_to_beta, inv_beta; digits=2)
        contrast_s   = Bonito.Slider(0:1:100; value=50)
        contrast_tf  = make_synced_textfield(contrast_s, map_to_contrast, inv_contrast; digits=2)
        mixed_s      = Bonito.Slider(0:1:100; value=20)

        on(hanning_pre.value) do val
            basis_t.value[] = basis_defaults[val]
            notify(basis_t.value)
        end
        preset_name != "Custom" && notify(hanning_pre.value)

        new_tab = ComponentTab(tab_id, preset_name, model_cat, hanning_pre, contrast_t,
            basis_t, formula_t, projection_t, beta_s, contrast_s, mixed_s, nothing)
        tab_beta_textfields[tab_id] = beta_tf
        tab_contrast_textfields[tab_id] = contrast_tf
        tab_formula_dropdowns[tab_id] = formula_d
        tab_formula_use_buttons[tab_id] = formula_btn

        refresh_formula_options! = () -> begin
            opts = build_formula_options(state.categorical_variables[], state.continuous_variables[])
            formula_d.options[] = opts
            if !(formula_d.value[] in opts)
                formula_d.value[] = opts[1]
            end
        end
        refresh_formula_options!()

        on(formula_btn.value) do _
            formula_t.value[] = string(formula_d.value[])
            notify(formula_t.value)
        end

        on(state.categorical_variables) do _
            refresh_formula_options!()
        end
        on(state.continuous_variables) do _
            refresh_formula_options!()
        end

        for (obs_pair) in [
            (beta_s.value,      v -> state.active_beta_value[]          = v),
            (contrast_s.value,  v -> state.active_contrast_value[]      = v),
            (mixed_s.value,     v -> state.active_sigma_value[]         = v),
            (basis_t.value,     v -> state.active_basis_value[]         = v),
            (formula_t.value,   v -> state.active_formula_value[]       = v),
            (projection_t.value,v -> state.active_projection_value[]    = v),
            (contrast_t.value,  v -> state.active_contrast_type_value[] = v),
            (model_cat.value,   v -> state.active_model_category[]      = v),
        ]
            obs, fn = obs_pair
            on(obs) do v; new_tab.id == state.active_tab_id[] && fn(v); end
        end

        current = state.component_tabs[]
        push!(current, new_tab)
        state.active_tab_id[] = tab_id
        state.component_tabs[] = current
        # immediately push active values
        state.active_beta_value[]          = beta_s.value[]
        state.active_contrast_value[]      = contrast_s.value[]
        state.active_sigma_value[]         = mixed_s.value[]
        state.active_basis_value[]         = basis_t.value[]
        state.active_formula_value[]       = formula_t.value[]
        state.active_projection_value[]    = projection_t.value[]
        state.active_contrast_type_value[] = contrast_t.value[]
        state.active_model_category[]      = model_cat.value[]
        return new_tab
    end

    # ── Active-tab switch: push its values into global state ──
    on(state.active_tab_id) do active_id
        tabs     = state.component_tabs[]
        tab_idx  = findfirst(t -> t.id == active_id, tabs)
        tab_idx === nothing && return
        tab = tabs[tab_idx]
        state.active_beta_value[]          = tab.beta_slider.value[]
        state.active_contrast_value[]      = tab.contrast_slider.value[]
        state.active_sigma_value[]         = tab.mixed_sigma.value[]
        state.active_basis_value[]         = tab.basis_txt.value[]
        state.active_formula_value[]       = tab.formula_txt.value[]
        state.active_projection_value[]    = tab.projection_txt.value[]
        state.active_contrast_type_value[] = tab.contrast_type.value[]
        state.active_model_category[]      = tab.model_category.value[]
    end

    # ── component_tabs guard: prune stale all_tab_results ─────
    on(state.component_tabs) do tabs
        isempty(tabs) && return
        if findfirst(t -> t.id == state.active_tab_id[], tabs) === nothing
            state.active_tab_id[] = tabs[1].id
        end
        valid = Set(t.id for t in tabs)
        pruned = Dict{String,Any}()
        for (k, v) in state.all_tab_results[]
            k in valid && (pruned[k] = v)
        end
        length(pruned) != length(state.all_tab_results[]) &&
            (state.all_tab_results[] = pruned)
        sync_selected_hannings!()
    end

    # ── Hanning overlay buttons ───────────────────────────────
    apply_hanning_overlay_button  = Bonito.Button("+ Apply Hanning")
    remove_hanning_overlay_button = Bonito.Button("- Remove Selected")

    on(apply_hanning_overlay_button.value) do _
        picked = string(state.global_hanning_preset.value[])
        picked == "Custom" && return
        existing = findfirst(t -> t.name == picked, state.component_tabs[])
        if existing === nothing; create_new_tab(picked)
        else; state.active_tab_id[] = state.component_tabs[][existing].id; end
        sync_selected_hannings!()
    end

    on(remove_hanning_overlay_button.value) do _
        remove_hanning_tab!(string(state.global_hanning_preset.value[]))
        sync_selected_hannings!()
    end

    # ── Tab bar UI (reactive) ─────────────────────────────────
    tab_bar_ui = map(state.component_tabs, state.active_tab_id) do tabs, active_id
        isempty(tabs) && return Bonito.DOM.div("No tabs")
        active_idx = something(findfirst(t -> t.id == active_id, tabs), 1)
        active_tab_obj = tabs[active_idx]
        tab_list = join([t.name for t in tabs], ", ")
        if length(tabs) > 1
            Bonito.DOM.div(
                Bonito.DOM.span("Active: ", style="font-weight:600; font-size:11px; color:var(--text2); margin-right:6px;"),
                Bonito.DOM.span(active_tab_obj.name, style="font-weight:700; font-size:13px; color:#ffffff; background:var(--green2); padding:2px 10px; border-radius:20px; margin-right:14px;"),
                Bonito.DOM.span("all: $tab_list", style="font-size:10px; color:var(--text2); font-style:italic;"),
                style="padding:10px 14px; background:var(--bg2); border:1px solid var(--border); border-radius:8px 8px 0 0; display:flex; align-items:center; gap:4px;"
            )
        else
            Bonito.DOM.div(
                Bonito.DOM.span("Tab: $(active_tab_obj.name)", style="font-weight:700; font-size:12px; color:var(--text1);"),
                style="padding:10px 14px; background:var(--bg2); border:1px solid var(--border); border-radius:8px 8px 0 0;"
            )
        end
    end

    # ── Hanning chip list UI ──────────────────────────────────
    selected_hannings_ui = map(state.selected_hannings) do sel
        isempty(sel) && return Bonito.DOM.span("No applied Hanning components",
            style="font-size:10px; color:var(--text2); font-style:italic;")
        chips = Any[]
        for preset_name in sort(collect(sel))
            rm_btn = Bonito.Button("×")
            on(rm_btn.value) do _
                remove_hanning_tab!(preset_name)
                sync_selected_hannings!()
            end
            push!(chips, Bonito.DOM.div(
                Bonito.DOM.span(preset_name, style="font-size:10px; color:var(--text1); margin-right:6px;"),
                rm_btn,
                style="display:flex; align-items:center; gap:6px; padding:4px 6px; border:1px solid var(--border); border-radius:6px; background:var(--bg3);"
            ))
        end
        Bonito.DOM.div(chips..., style="display:flex; flex-direction:column; gap:6px;")
    end

    # ── Per-tab content UI (reactive) ─────────────────────────
    tab_content_ui = map(state.component_tabs, state.active_tab_id) do tabs, active_id
        tab_idx = findfirst(t -> t.id == active_id, tabs)
        tab_idx === nothing && return Bonito.DOM.div("No active tab")
        tab = tabs[tab_idx]
        beta_tf = get(tab_beta_textfields, tab.id) do
            tf = make_synced_textfield(tab.beta_slider, map_to_beta, inv_beta; digits=2)
            tab_beta_textfields[tab.id] = tf
            tf
        end
        contrast_tf = get(tab_contrast_textfields, tab.id) do
            tf = make_synced_textfield(tab.contrast_slider, map_to_contrast, inv_contrast; digits=2)
            tab_contrast_textfields[tab.id] = tf
            tf
        end
        formula_d = get(tab_formula_dropdowns, tab.id, Bonito.Dropdown(["@formula(0 ~ 1)"]; index=1))
        formula_btn = get(tab_formula_use_buttons, tab.id, Bonito.Button("Apply"))

        beta_label     = map(v -> "β (Intercept): $(round(map_to_beta(v), digits=2))",     tab.beta_slider.value)
        contrast_label = map(v -> "Contrast: $(round(map_to_contrast(v), digits=2))",       tab.contrast_slider.value)
        sigma_label    = map(v -> "σs (Random Effect): $(round(map_to_sigma(v), digits=2))",tab.mixed_sigma.value)
        formula_hint = Bonito.DOM.div(
            Bonito.DOM.span("📝 Formula Examples:", style="font-weight:700; font-size:10px; display:block; margin-bottom:4px; color:var(--text1);"),
            Bonito.DOM.span("• @formula(0 ~ 1)", style="font-size:9px; display:block; font-family:monospace; color:var(--accent2);"),
            Bonito.DOM.span("• @formula(0 ~ 1 + your_variable)", style="font-size:9px; display:block; font-family:monospace; color:var(--accent2);"),
            Bonito.DOM.span("• @formula(0 ~ 1 + var1 + var2)", style="font-size:9px; display:block; font-family:monospace; color:var(--accent2);"),
            style="padding:8px; background:var(--bg2); border-radius:6px; margin-bottom:8px; border:1px solid var(--border);"
        )
        Bonito.DOM.div(
            Bonito.DOM.span("Hanning Presets", style=label_s), tab.hanning_preset,
            Bonito.DOM.span("Basis Function",  style=label_s), tab.basis_txt,
            Bonito.DOM.div(
                Bonito.DOM.span("Contrast Coding", style=label_s), tab.contrast_type,
                Bonito.DOM.span("Formula", style=label_s), tab.formula_txt,
                Bonito.DOM.span("Formula Suggestions", style=label_s),
                Bonito.DOM.div(formula_d, formula_btn,
                    style="display:flex; align-items:center; gap:8px; flex-wrap:wrap;"),
                formula_hint,
                Bonito.DOM.span(beta_label, style=label_s),
                Bonito.DOM.div(tab.beta_slider, beta_tf, style="display:flex; align-items:center; gap:8px;", class="slider-tf-wrap"),
                style=map(m -> m in ("Linear Model", "Mixed Model") ? "" : "display:none;", tab.model_category.value)
            ),
            Bonito.DOM.div(
                Bonito.DOM.span(contrast_label, style=label_s),
                Bonito.DOM.div(tab.contrast_slider, contrast_tf, style="display:flex; align-items:center; gap:8px;", class="slider-tf-wrap"),
                style=map(m -> m == "Linear Model" ? "" : "display:none;", tab.model_category.value)
            ),
            Bonito.DOM.div(
                Bonito.DOM.span(sigma_label, style=label_s), tab.mixed_sigma,
                style=map(m -> m == "Mixed Model" ? "" : "display:none;", tab.model_category.value)
            ),
            Bonito.DOM.div(
                Bonito.DOM.span("Projection Vector", style=label_s), tab.projection_txt,
                style=map(m -> m == "Multi-channel Model" ? "" : "display:none;", tab.model_category.value)
            )
        )
    end

    # ── Seed first tab ────────────────────────────────────────
    create_new_tab("Custom")

    return build_model_ui(
        label_s, state.global_hanning_preset,
        apply_hanning_overlay_button, remove_hanning_overlay_button,
        selected_hannings_ui, tab_bar_ui,
        state.component_tabs, state.active_tab_id,
        tab_content_ui,
    )
end

# ── DOM builder (pure) ───────────────────────────────────────
function build_model_ui(
    label_s, global_hanning_preset,
    apply_hanning_overlay_button, remove_hanning_overlay_button,
    selected_hannings_ui, tab_bar_ui,
    component_tabs, active_tab_id, tab_content_ui,
)
    return Bonito.DOM.div(
        Bonito.DOM.span("Select Hanning Preset to Apply/Remove:", style=label_s),
        global_hanning_preset,
        Bonito.DOM.div(
            Bonito.DOM.div(apply_hanning_overlay_button, remove_hanning_overlay_button,
                style="display:flex; gap:8px; margin-top:8px; flex-wrap:wrap;"),
            Bonito.DOM.span("Selecting a preset alone does nothing. Use Apply/Remove buttons.",
                style="font-size:10px; color:var(--text2); display:block; margin-top:8px; margin-bottom:4px;"),
            Bonito.DOM.span("Applied Hannings (main graph):",
                style="font-size:10px; color:var(--text2); display:block; margin-top:8px; margin-bottom:4px;"),
            Bonito.DOM.div(selected_hannings_ui,
                style="margin-top:8px; padding:8px; background:var(--bg2); border:1px solid var(--border); border-radius:6px;"),
            style="margin-top:8px; margin-bottom:8px;"
        ),
        Bonito.DOM.br(), Bonito.DOM.br(),
        tab_bar_ui,
        Bonito.DOM.div(
            Bonito.DOM.div(
                Bonito.DOM.span("Model Type", style=label_s),
                Bonito.map(component_tabs, active_tab_id) do tabs, active_id
                    tab_idx = findfirst(t -> t.id == active_id, tabs)
                    return tab_idx !== nothing ? tabs[tab_idx].model_category : Bonito.DOM.div()
                end,
                style="margin-bottom:10px;"
            ),
            tab_content_ui,
            style="padding:15px; background:var(--bg2); border:1px solid var(--border); border-top:none; border-radius:0 0 10px 10px;"
        )
    )
end
