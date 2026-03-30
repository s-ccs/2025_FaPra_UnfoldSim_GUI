if !@isdefined(ComponentTab)
    mutable struct ComponentTab
        id::String
        name::String
        model_category::Any
        hanning_preset::Any
        contrast_type::Any
        basis_txt::Any
        formula_txt::Any
        projection_txt::Any
        beta_slider::Any
        contrast_slider::Any
        mixed_sigma::Any
        last_result::Any
    end
end

mutable struct AppState
    # ── Electrode / channel info ──────────────────────────────────────────
    electrode_positions::Any
    n_channels::Int
    channel_names_list::Vector{Symbol}
    clean_signal_channel_idx::Int

    # ── Event-variable observables ────────────────────────────────────────
    categorical_variables::Observable
    continuous_variables::Observable
    event_status::Observable

    # ── Tab / component state ─────────────────────────────────────────────
    component_tabs::Observable
    active_tab_id::Observable
    tab_counter::Ref{Int}
    all_tab_results::Observable

    active_beta_value::Observable
    active_contrast_value::Observable
    active_sigma_value::Observable
    active_basis_value::Observable
    active_formula_value::Observable
    active_projection_value::Observable
    active_contrast_type_value::Observable
    active_model_category::Observable

    selected_hannings::Observable

    # ── Widgets (sliders / dropdowns) ─────────────────────────────────────
    time_slider::Any
    n_subjects::Any
    n_items::Any
    on_mu::Any
    on_sigma::Any
    on_offset::Any
    on_truncate_lower::Any
    on_truncate::Any
    u_width::Any
    u_offset_uni::Any
    noise_lvl::Any

    onset_choice::Any
    noise_choice::Any
    design_dropdown::Any
    global_hanning_preset::Any

    design_category::Observable
    user_set_design::Observable

    # ── Throttled derived observables ─────────────────────────────────────
    time_slider_throttled::Any
    subjects_throttled::Any
    items_throttled::Any
    mu_throttled::Any
    sigma_onset_throttled::Any
    offset_throttled::Any
    trl_throttled::Any
    tr_throttled::Any
    width_throttled::Any
    uoff_throttled::Any
    noise_throttled::Any
    active_beta_throttled::Any
    active_contrast_throttled::Any
    active_sigma_throttled::Any
    sim_trigger::Any

    # ── Simulation results ────────────────────────────────────────────────
    results::Observable
    event_table_dom::Observable
    last_simulation_obj::Observable

    # ── Status ────────────────────────────────────────────────────────────
    status_text::Observable
    is_running::Observable
    save_jld2_status::Observable
    data_mgmt_status::Observable

    # ── Channel selection (topoplot) ──────────────────────────────────────
    selected_channels::Observable
    click_in_progress::Ref{Bool}
    pending_topo_gen::Ref{Int}

    # ── Figures (set during init) ─────────────────────────────────────────
    fig::Any
    ax::Any
    onset_plot_fig::Any
    onset_ax::Any
    brain_fig::Any
    brain_ax::Any
    brain_fig2::Any
    ax_topo1::Any

    # ── Plot observables ──────────────────────────────────────────────────
    topo_colors_obs::Observable
    topo_data_obs::Observable
    topo_rms_obs::Observable
    topo_base_colors::Observable
    topo_base_data::Observable
    topo_base_rms::Observable
    cumulative_clean_obs::Observable
    cumulative_noisy_obs::Observable
    channel_line_data::Any
    channel_line_visibility::Any
    tab_line_data::Any
    tab_line_visibility::Any
    hanning_plot_refs::Ref
    event_marker_refs::Ref
    sep_plot::Any
    sep_xs_obs::Observable
    hovered_electrode_name::Observable

    # ── Text fields (synced to sliders) ──────────────────────────────────
    noise_lvl_tf::Any
    time_slider_tf::Any
    n_subjects_tf::Any
    n_items_tf::Any
    on_mu_tf::Any
    on_sigma_tf::Any
    on_offset_tf::Any
    on_truncate_lower_tf::Any
    on_truncate_tf::Any
    u_width_tf::Any
    u_offset_uni_tf::Any

    # ── UI component outputs (set during init) ────────────────────────────
    event_definition_ui::Any
    model_ui::Any
    design_config_ui::Any
    onset_ui::Any

    # ── I/O buttons / observables ────────────────────────────────────────
    download_button::Any
    download_sim_button::Any
    save_jld2_button::Any
    upload_sim_file_input::Any
    upload_file_content::Observable
    upload_processing_flag::Observable
    sliders_dict::Any

    # ── Style constants (computed once, reused everywhere) ────────────────
    label_s::String
    card_s::String
    section_title_s::String

    # ── Theme ─────────────────────────────────────────────────────────────
    is_dark_theme::Observable
    theme_btn_label::Observable
    theme_toggle_btn::Any
end
