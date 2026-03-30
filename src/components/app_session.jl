# ============================================================
# MAIN APP SESSION
# ~140 lines: creates widgets → AppState → calls init functions → assembles DOM
# ============================================================

app = Bonito.App() do session

    # ── Electrode setup ───────────────────────────────────────
    elec_pos             = get_electrode_positions()
    n_channels           = length(elec_pos)
    channel_names_list   = collect(keys(elec_pos))
    clean_ch_idx         = findfirst(==(CLEAN_SIGNAL_CHANNEL_NAME), channel_names_list)
    clean_ch_idx         = clean_ch_idx === nothing ? 1 : clean_ch_idx

    # ── Style constants ───────────────────────────────────────
    label_s         = "font-weight:600; font-size:11px; margin-top:10px; display:block; color:var(--text1); letter-spacing:0.3px; text-transform:uppercase;"
    card_s          = "padding:12px 14px; border:1px solid var(--border); border-radius:10px; background:linear-gradient(135deg, var(--bg2) 0%, var(--bg3) 100%); margin-bottom:10px; box-shadow:0 2px 8px rgba(0,0,0,0.18);"
    section_title_s = "font-size:13px; font-weight:700; color:var(--accent); margin:4px 0 8px 0; display:flex; align-items:center; gap:6px; border-bottom:1px solid var(--border); padding-bottom:6px;"

    # ── Sliders ───────────────────────────────────────────────
    time_slider       = Bonito.Slider(1:1:500;  value=100)
    n_subjects        = Bonito.Slider(0:1:100;  value=10)
    n_items           = Bonito.Slider(0:1:100;  value=20)
    on_mu             = Bonito.Slider(0:1:100;  value=17)
    on_sigma          = Bonito.Slider(0:1:100;  value=44)
    on_offset         = Bonito.Slider(0:1:100;  value=10)
    on_truncate_lower = Bonito.Slider(0:1:100;  value=0)
    on_truncate       = Bonito.Slider(0:1:100;  value=44)
    u_width           = Bonito.Slider(0:1:100;  value=21)
    u_offset_uni      = Bonito.Slider(0:1:100;  value=10)
    noise_lvl         = Bonito.Slider(0:1:100;  value=15)

    # ── Synced text fields ────────────────────────────────────
    time_slider_tf       = make_synced_textfield(time_slider; digits=0)
    n_subjects_tf        = make_synced_textfield(n_subjects,   map_to_subjects,       inv_subjects;       digits=0, mirror_slider_to_textfield=false)
    n_items_tf           = make_synced_textfield(n_items,      map_to_items,          inv_items;          digits=0, mirror_slider_to_textfield=false)
    on_mu_tf             = make_synced_textfield(on_mu,        map_to_mu,             inv_mu)
    on_sigma_tf          = make_synced_textfield(on_sigma,     map_to_onset_sigma,    inv_onset_sigma)
    on_offset_tf         = make_synced_textfield(on_offset,    map_to_offset,         inv_offset;         digits=0)
    on_truncate_lower_tf = make_synced_textfield(on_truncate_lower, map_to_truncate_lower, inv_truncate_lower; digits=0)
    on_truncate_tf       = make_synced_textfield(on_truncate,  map_to_truncate,       inv_truncate;       digits=0)
    u_width_tf           = make_synced_textfield(u_width,      map_to_width,          inv_width;          digits=0)
    u_offset_uni_tf      = make_synced_textfield(u_offset_uni, map_to_offset,         inv_offset;         digits=0)
    noise_lvl_tf         = make_synced_textfield(noise_lvl,    map_to_noise,          inv_noise)

    # ── Dropdowns & buttons ───────────────────────────────────
    onset_choice        = Bonito.Dropdown(["Uniform", "Log Normal", "No Onset"]; index=1)
    noise_choice        = Bonito.Dropdown(["No Noise", "White", "Pink", "Red"];  index=1)
    global_hanning_preset = Bonito.Dropdown(["Custom","N170 (Negative)","N400 (Negative)","P100 (Positive)","P300 (Positive)"]; index=1)
    download_button     = Bonito.Button("Download Configuration")
    download_sim_button = Bonito.Button("Download Simulation Object")
    save_jld2_button    = Bonito.Button("💾 Save Simulation (.jld2)")
    upload_sim_file_input = Bonito.FileInput(Observable(String[]), true)

    # ── Core observables ──────────────────────────────────────
    categorical_variables = Observable(Dict{String,Vector{String}}("condition" => ["A","B"]))
    continuous_variables  = Observable(Dict{String,NamedTuple{(:min,:max,:steps),Tuple{Float64,Float64,Int}}}())
    event_status          = Observable("Default: condition = [A, B]")

    component_tabs      = Observable(ComponentTab[])
    active_tab_id       = Observable("")
    tab_counter         = Ref(0)
    all_tab_results     = Observable(Dict{String,Any}())

    active_beta_value          = Observable(50)
    active_contrast_value      = Observable(50)
    active_sigma_value         = Observable(20)
    active_basis_value         = Observable("hanning(40, 0, 100)")
    active_formula_value       = Observable("@formula(0 ~ 1 + condition)")
    active_projection_value    = Observable("[1.0, 0.5, -0.2]")
    active_contrast_type_value = Observable("DummyCoding")
    active_model_category      = Observable("Linear Model")
    selected_hannings          = Observable(Set{String}())

    design_category   = Observable("Single-subject design")
    user_set_design   = Observable(false)

    results           = Observable((noisy=Point2f[], clean=Point2f[],
                            multichannel_noisy=zeros(1,1), multichannel_clean=zeros(1,1),
                            time=[0.0], events=DataFrame(), err="",
                            raw_onsets=Int[], onset_type="No Onset",
                            onset_params=Dict{Symbol,Any}()))
    event_table_dom   = Observable{Any}(Bonito.DOM.span("No events yet.",
                            style="font-size:10px;color:var(--text2);font-style:italic;"))
    last_simulation_obj   = Observable{Any}(nothing)
    status_text           = Observable("Ready")
    is_running            = Observable(false)
    save_jld2_status      = Observable("")
    data_mgmt_status      = Observable("")
    selected_channels     = Observable(Set{Int}([clean_ch_idx]))
    upload_file_content   = Observable{String}("")
    upload_processing_flag = Observable(false)

    # ── Throttles ─────────────────────────────────────────────
    time_slider_throttled     = throttle(THROTTLE_DT,    time_slider.value)
    subjects_throttled        = throttle(SLIDER_THROTTLE, n_subjects.value)
    items_throttled           = throttle(SLIDER_THROTTLE, n_items.value)
    mu_throttled              = throttle(SLIDER_THROTTLE, on_mu.value)
    sigma_onset_throttled     = throttle(SLIDER_THROTTLE, on_sigma.value)
    offset_throttled          = throttle(SLIDER_THROTTLE, on_offset.value)
    trl_throttled             = throttle(SLIDER_THROTTLE, on_truncate_lower.value)
    tr_throttled              = throttle(SLIDER_THROTTLE, on_truncate.value)
    width_throttled           = throttle(SLIDER_THROTTLE, u_width.value)
    uoff_throttled            = throttle(SLIDER_THROTTLE, u_offset_uni.value)
    noise_throttled           = throttle(SLIDER_THROTTLE, noise_lvl.value)
    active_beta_throttled     = throttle(SLIDER_THROTTLE, active_beta_value)
    active_contrast_throttled = throttle(SLIDER_THROTTLE, active_contrast_value)
    active_sigma_throttled    = throttle(SLIDER_THROTTLE, active_sigma_value)

    # Trigger simulation on any relevant control change (skip initial fire in engine)
    sim_trigger = throttle(SIMULATION_DEBOUNCE,
        map((args...) -> sum(hash.(args)),
            active_model_category, design_category, onset_choice.value,
            noise_choice.value, active_beta_throttled, active_contrast_throttled,
            active_sigma_throttled, subjects_throttled, items_throttled,
            mu_throttled, sigma_onset_throttled, offset_throttled,
            trl_throttled, tr_throttled, width_throttled, uoff_throttled,
            noise_throttled, active_contrast_type_value,
            active_basis_value, active_formula_value, active_projection_value,
            categorical_variables, continuous_variables))

    sliders_dict = Dict(
        "n_subjects" => n_subjects.value, "n_items" => n_items.value,
        "on_mu" => on_mu.value, "on_sigma" => on_sigma.value,
        "on_offset" => on_offset.value, "on_truncate_lower" => on_truncate_lower.value,
        "on_truncate" => on_truncate.value, "u_width" => u_width.value,
        "u_offset_uni" => u_offset_uni.value, "noise_lvl" => noise_lvl.value,
        "active_beta_value" => active_beta_value, "active_contrast_value" => active_contrast_value,
        "active_sigma_value" => active_sigma_value, "onset_choice" => onset_choice.value,
        "noise_choice" => noise_choice.value, "design_category" => design_category,
        "active_model_category" => active_model_category,
        "active_contrast_type_value" => active_contrast_type_value,
        "active_basis_value" => active_basis_value, "active_formula_value" => active_formula_value,
        "active_projection_value" => active_projection_value)

    # ── Construct shared state ────────────────────────────────
    state = AppState(
        elec_pos, n_channels, channel_names_list, clean_ch_idx,
        categorical_variables, continuous_variables, event_status,
        component_tabs, active_tab_id, tab_counter, all_tab_results,
        active_beta_value, active_contrast_value, active_sigma_value,
        active_basis_value, active_formula_value, active_projection_value,
        active_contrast_type_value, active_model_category,
        selected_hannings,
        time_slider, n_subjects, n_items, on_mu, on_sigma, on_offset,
        on_truncate_lower, on_truncate, u_width, u_offset_uni, noise_lvl,
        onset_choice, noise_choice, nothing, global_hanning_preset,
        design_category, user_set_design,
        time_slider_throttled, subjects_throttled, items_throttled,
        mu_throttled, sigma_onset_throttled, offset_throttled,
        trl_throttled, tr_throttled, width_throttled, uoff_throttled,
        noise_throttled, active_beta_throttled, active_contrast_throttled,
        active_sigma_throttled, sim_trigger,
        results, event_table_dom, last_simulation_obj,
        status_text, is_running, save_jld2_status, data_mgmt_status,
        selected_channels, Ref(false), Ref(0),
        nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing,
        Observable(RGBAf[]), Observable(Float64[]), Observable(Float64[]),
        Observable(RGBAf[]), Observable(Float64[]), Observable(Float64[]),
        Observable(Point2f[]), Observable(Point2f[]),
        [], [], [], [],
        Ref{Vector{Any}}([]), Ref{Vector{Any}}([]),
        nothing, Observable(Float64[0.0]), Observable("—"),
        noise_lvl_tf, time_slider_tf, n_subjects_tf, n_items_tf,
        on_mu_tf, on_sigma_tf, on_offset_tf, on_truncate_lower_tf, on_truncate_tf,
        u_width_tf, u_offset_uni_tf,
        nothing, nothing, nothing, nothing,
        download_button, download_sim_button, save_jld2_button, upload_sim_file_input,
        upload_file_content, upload_processing_flag, sliders_dict,
        label_s, card_s, section_title_s,
        Observable(true), Observable("☀️ Light Mode"), nothing)

    # ── Wire active_model_category → design_category ─────────
    on(active_model_category) do m
        if m == "Mixed Model"
            state.user_set_design[] = false; state.design_category[] = "Multi-subject design"
        elseif !state.user_set_design[]
            state.design_category[] = "Single-subject design"
        end
    end

    # ── Call init functions (order matters!) ──────────────────
    init_onset_plot!(state)
    fig, legend_content = init_main_plot!(state)
    erp_panel_content   = init_topoplot!(state)

    state.event_definition_ui = init_event_manager!(state)
    state.model_ui            = init_tab_manager!(state)
    init_simulation_engine!(state)
    init_io_handlers!(state, session)

    sidebar_dom, global_css, floating_status = init_sidebar!(state, session)

    # ── Assemble 3-panel layout ───────────────────────────────
    center_panel = build_center_panel(fig, legend_content, state.onset_plot_fig)
    erp_panel    = build_erp_panel(erp_panel_content)

    Bonito.DOM.div(
        Bonito.DOM.div(
            global_css,
            sidebar_dom,
            center_panel,
            erp_panel,
            style="display:grid; grid-template-columns:minmax(300px,22vw) minmax(0,1fr) minmax(300px,22vw); grid-template-rows:100vh; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',system-ui,sans-serif; width:100vw; height:100vh; box-sizing:border-box; overflow:hidden; margin:0; padding:0; background:var(--bg1); color:var(--text1);",
            var"data-theme-wrapper"="true"),
        floating_status,
        style="position:relative; width:100vw; height:100vh; overflow:hidden; margin:0; padding:0; background:var(--bg1);",
        var"data-theme-wrapper"="true")
end;

app
