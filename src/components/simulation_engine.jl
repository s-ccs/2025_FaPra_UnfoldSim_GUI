# ============================================================
# SIMULATION ENGINE
# Owns: compute_cumulative_signal, on(sim_trigger),
#       save/download/upload handlers
# ============================================================

function compute_cumulative_signal(all_results_dict)
    isempty(all_results_dict) &&
        return Point2f[], Point2f[], Float64[], DataFrame()
    max_length = 0
    reference_time = Float64[]
    for (_, res) in all_results_dict
        !isnothing(res) && res.err == "" && length(res.time) > max_length &&
            (max_length = length(res.time); reference_time = res.time)
    end
    max_length == 0 &&
        return Point2f[], Point2f[], Float64[], DataFrame()
    cum_clean_y = zeros(max_length)
    cum_noisy_y = zeros(max_length)
    for (_, res) in all_results_dict
        (isnothing(res) || res.err != "" || isempty(res.clean)) && continue
        clean_y = [p[2] for p in res.clean]
        noisy_y = [p[2] for p in res.noisy]
        len = min(length(clean_y), max_length)
        cum_clean_y[1:len] .+= clean_y[1:len]
        cum_noisy_y[1:len] .+= noisy_y[1:len]
    end
    events_df = DataFrame()
    for (_, res) in all_results_dict
        !isnothing(res) && !isempty(res.events) && (events_df = res.events; break)
    end
    return Point2f.(reference_time, cum_clean_y),
           Point2f.(reference_time, cum_noisy_y),
           reference_time, events_df
end

# ── Helper: extract channel data
function extract_channel_data(data, clean, m_cat, CLEAN_CH, N_CH)
    if data isa AbstractArray && ndims(data) == 3
        n_ch, n_t, n_ep = size(data)
        df  = reshape(data,  n_ch, n_t*n_ep)
        cf  = reshape(clean, n_ch, n_t*n_ep)
        ch  = m_cat == "Multi-channel Model" ? CLEAN_CH : 1
        return vec(df[ch,:]), vec(cf[ch,:]), df', cf'
    elseif data isa Matrix && size(data,1) == N_CH && m_cat == "Multi-channel Model"
        return vec(data[CLEAN_CH,:]), vec(clean[CLEAN_CH,:]), data', clean'
    elseif data isa Matrix && size(data,2) == N_CH && m_cat == "Multi-channel Model"
        return vec(data[:,CLEAN_CH]), vec(clean[:,CLEAN_CH]), data, clean
    else
        yn = vec(data); yc = vec(clean)
        return yn, yc, repeat(reshape(yn,:,1),1,N_CH), repeat(reshape(yc,:,1),1,N_CH)
    end
end

# ── I/O handlers ─────────────────────────────────────────────
function init_io_handlers!(state::AppState, session)
    on(state.download_button.value) do _
        try
            config = Dict{String,Any}(
                "n_subjects" => state.n_subjects.value[],
                "n_items" => state.n_items.value[],
                "on_mu" => state.on_mu.value[],
                "on_sigma" => state.on_sigma.value[],
                "on_offset" => state.on_offset.value[],
                "on_truncate_lower" => state.on_truncate_lower.value[],
                "on_truncate" => state.on_truncate.value[],
                "u_width" => state.u_width.value[],
                "u_offset_uni" => state.u_offset_uni.value[],
                "noise_lvl" => state.noise_lvl.value[],
                "active_beta_value" => Int(state.active_beta_value[]),
                "active_contrast_value" => Int(state.active_contrast_value[]),
                "active_sigma_value" => Int(state.active_sigma_value[]),
                "onset_choice" => String(state.onset_choice.value[]),
                "noise_choice" => String(state.noise_choice.value[]),
                "design_category" => String(state.design_category[]),
                "active_model_category" => String(state.active_model_category[]),
            )
            json_str = JSON3.write(config)
            Bonito.evaljs(session, Bonito.js"""
                (function() {
                    const blob = new Blob([$json_str], {type:'application/json'});
                    const url  = URL.createObjectURL(blob);
                    const a    = document.createElement('a');
                    a.href = url; a.download = 'expexplorer_config.json';
                    document.body.appendChild(a);
                    a.click();
                    document.body.removeChild(a);
                    URL.revokeObjectURL(url);
                })();
            """)
        catch e
            println("❌ Download error: $(sprint(showerror,e))")
        end
    end

    on(state.download_sim_button.value) do _
        try
            res = state.results[]
            res.err != "" && (state.data_mgmt_status[] = "❌ Cannot save"; return)
            config = Dict{String,Any}(k => obs[] for (k,obs) in state.sliders_dict)
            msg = download_sim_files_smart(res, config)
            state.data_mgmt_status[] = "✓ Saved to: $(pwd())"
            println(msg)
        catch e
            state.data_mgmt_status[] = "✗ Error: $e"
        end
    end

    on(state.save_jld2_button.value) do _
        try
            isnothing(state.last_simulation_obj[]) &&
                (state.save_jld2_status[] = "❌ Run simulation first"; return)
            res = state.results[]
            res.err != "" && (state.save_jld2_status[] = "❌ Sim has errors"; return)
            ts = Dates.format(Dates.now(), "yyyy-mm-dd_HH-MM-SS")
            filename = "unfoldsim_$(ts).jld2"
            filepath = joinpath(pwd(), filename)
            jldsave(filepath; sim_obj=state.last_simulation_obj[], config=state.results[])
            state.save_jld2_status[] = "✅ Saved: $filename"
        catch e
            state.save_jld2_status[] = "❌ Error: $(string(e)[1:min(80,end)])"
        end
    end

    upload_processing_flag = Observable(false)
    on(state.upload_sim_file_input.value) do file_paths
        upload_processing_flag[] && (state.data_mgmt_status[] = "⚠️ Processing..."; return)
        isempty(file_paths) || isempty(file_paths[1]) &&
            (state.data_mgmt_status[] = "❌ No file"; return)
        upload_processing_flag[] = true
        blob_url = file_paths[1]
        state.data_mgmt_status[] = "⏳ Loading..."
        Bonito.evaljs(session, Bonito.js"""
            fetch($blob_url)
                .then(r => r.text())
                .then(t => { $(state.upload_file_content).notify(t); })
                .catch(e => {
                    $(state.data_mgmt_status).notify("❌ Fetch failed");
                    $(upload_processing_flag).notify(false);
                });
        """)
    end

    on(state.upload_file_content) do csv_text
        try
            isempty(csv_text) && (upload_processing_flag[] = false; return)
            state.data_mgmt_status[] = "⏳ Parsing..."
            df = CSV.read(IOBuffer(csv_text), DataFrame)
            config = Dict{String,Any}()
            metadata_found = false
            if hasproperty(df, :metadata)
                for row in eachrow(df)
                    try
                        raw = strip(replace(row.metadata, "\"\"" => "\""))
                        startswith(raw,"\"") && endswith(raw,"\"") && (raw = raw[2:end-1])
                        js = findfirst("{", raw); je = findlast("}", raw)
                        js === nothing || je === nothing && continue
                        config = JSON3.read(raw[js[1]:je[1]], Dict{String,Any})
                        metadata_found = true; break
                    catch; continue; end
                end
            end
            if metadata_found && !isempty(config)
                restored = 0
                for (key, obs) in state.sliders_dict
                    haskey(config, key) || continue
                    try
                        nv = config[key]
                        obs[] = isa(nv, Real) ? convert(Int, round(nv)) : 
                                isa(nv, String) ? String(nv) : nv
                        restored += 1
                    catch; end
                end
                state.data_mgmt_status[] = "✅ LOADED! $restored params"
            else
                state.data_mgmt_status[] = "⚠️ No config in file"
            end
            upload_processing_flag[] = false
        catch e
            state.data_mgmt_status[] = "❌ Error: $(string(e)[1:min(60,end)])"
            upload_processing_flag[] = false
        end
    end
end

# ── Core simulation handler ───────────────────────────────────
function init_simulation_engine!(state::AppState)
    first_trigger = Ref(true)
    on(state.sim_trigger) do _
        if first_trigger[]
            first_trigger[] = false
            return
        end
        state.is_running[] && return
        state.is_running[] = true
        m_cat = state.active_model_category[]
        d_cat = state.design_category[]

        if m_cat == "Mixed Model" && d_cat in ("Single-subject design","Repeat design")
            state.status_text[] = "ERROR: Invalid Combination"
            state.results[] = (noisy=[Point2f(0,0)], clean=[Point2f(0,0)],
                multichannel_noisy=zeros(1,1), multichannel_clean=zeros(1,1),
                time=[0.0], events=DataFrame(),
                err="Mixed Model requires Multi-subject design.",
                raw_onsets=Int[], onset_type="No Onset",
                onset_params=Dict{Symbol,Any}())
            state.is_running[] = false
            return
        end

        try
            state.status_text[] = "Running..."
            
            o_cat = state.onset_choice.value[]
            n_cat = state.noise_choice.value[]
            b_str = state.active_basis_value[]
            f_str = state.active_formula_value[]
            b_gui = state.active_beta_value[]
            c_gui = state.active_contrast_value[]
            s_gui = state.active_sigma_value[]
            ni_gui = state.n_items.value[]
            ns_gui = state.n_subjects.value[]
            o_mu_gui = state.on_mu.value[]
            o_sig_gui = state.on_sigma.value[]
            o_off_gui = state.on_offset.value[]
            o_trl_gui = state.on_truncate_lower.value[]
            o_tr_gui = state.on_truncate.value[]
            uw_gui = state.u_width.value[]
            uoff_gui = state.u_offset_uni.value[]
            c_type = state.active_contrast_type_value[]
            n_lvl_gui = state.noise_lvl.value[]

            b_val = map_to_beta(b_gui); c_val = map_to_contrast(c_gui)
            s_val = map_to_sigma(s_gui); ni = map_to_items(ni_gui)
            ns = map_to_subjects(ns_gui); o_mu = map_to_mu(o_mu_gui)
            o_sig = map_to_onset_sigma(o_sig_gui); o_off = map_to_offset(o_off_gui)
            o_trl = map_to_truncate_lower(o_trl_gui); o_tr = map_to_truncate(o_tr_gui)
            uw = map_to_width(uw_gui); uoff = map_to_offset(uoff_gui)
            n_lvl = map_to_noise(n_lvl_gui)

            coding = c_type == "DummyCoding" ? DummyCoding() : EffectsCoding()
            cat_vars = state.categorical_variables[]
            contrast_dict = Dict{Symbol,Any}(Symbol(k) => coding
                for (k,v) in cat_vars if !isempty(v))
            isempty(contrast_dict) && (contrast_dict[:condition] = coding)

            design = build_design_from_events(cat_vars, state.continuous_variables[], d_cat, ni, ns)

            p_formula = m_cat == "Mixed Model" ?
                include_string(Main, "@formula(0 ~ 1 + condition + (1 + condition | subject))") :
                include_string(Main, f_str)
            p_basis = include_string(Main, b_str)

            n_terms = count_formula_terms(f_str, cat_vars, state.continuous_variables[])
            β_vec = Float64[b_val; [i == 2 ? c_val : c_val*0.5 for i in 2:n_terms]]

            base_comp = if m_cat == "Mixed Model"
                MixedModelComponent(; basis=p_basis, formula=p_formula,
                    β=[b_val, c_val], σs=Dict(:subject => [s_val, s_val]),
                    contrasts=contrast_dict)
            elseif m_cat == "Multi-channel Model"
                LinearModelComponent(; basis=p_basis, formula=@formula(0 ~ 1), β=[b_val])
            else
                LinearModelComponent(; basis=p_basis, formula=p_formula, β=β_vec, contrasts=contrast_dict)
            end

            CLEAN_CH = state.clean_signal_channel_idx
            N_CH = state.n_channels

            onsets = o_cat == "Log Normal" ? LogNormalOnset(;μ=o_mu,σ=o_sig,offset=o_off,
                truncate_upper=o_tr) :
                o_cat == "Uniform" ? UniformOnset(;width=uw,offset=uoff) : NoOnset()
            
            noise = n_cat == "White" ? WhiteNoise(;noiselevel=n_lvl) :
                n_cat == "Pink"  ? PinkNoise(;noiselevel=n_lvl) :
                n_cat == "Red"   ? RedNoise(;noiselevel=n_lvl) : NoNoise()

            epoched = (o_cat == "No Onset")

            data, events_df = if m_cat == "Multi-channel Model"
                mc1 = UnfoldSim.MultichannelComponent(base_comp, CACHED_HARTMUT => "Left Postcentral Gyrus")
                mc2 = UnfoldSim.MultichannelComponent(base_comp, CACHED_HARTMUT => "Right Occipital Pole")
                simulate(MersenneTwister(42), design, [mc1,mc2], onsets, noise; return_epoched=epoched)
            else
                simulate(MersenneTwister(42), design, base_comp, onsets, noise; return_epoched=epoched)
            end

            clean, _ = if m_cat == "Multi-channel Model"
                mc1 = UnfoldSim.MultichannelComponent(base_comp, CACHED_HARTMUT => "Left Postcentral Gyrus")
                mc2 = UnfoldSim.MultichannelComponent(base_comp, CACHED_HARTMUT => "Right Occipital Pole")
                simulate(MersenneTwister(42), design, [mc1,mc2], onsets, NoNoise(); return_epoched=epoched)
            else
                simulate(MersenneTwister(42), design, base_comp, onsets, NoNoise(); return_epoched=epoched)
            end

            y_noisy, y_clean, mc_noisy, mc_clean = extract_channel_data(data, clean, m_cat, CLEAN_CH, N_CH)

            t = range(0, length=length(y_noisy), step=1/100)
            raw_onsets = Int[]
            if hasproperty(events_df, :latency) && nrow(events_df) > 0
                lats = Int.(round.(Float64.(events_df.latency)))
                sort!(lats)
                first_dist = max(lats[1] - 1, 0)
                raw_onsets = nrow(events_df) == 1 ? [first_dist] : vcat(first_dist, diff(lats))
            end
            current_result = (
                noisy = Point2f.(t, y_noisy), clean = Point2f.(t, y_clean),
                multichannel_noisy = mc_noisy, multichannel_clean = mc_clean,
                time = collect(t), events = events_df, err = "",
                raw_onsets = raw_onsets,
                onset_type = o_cat,
                onset_params = Dict{Symbol,Any}(
                    :choice => o_cat,
                    :mu => o_mu,
                    :sigma => o_sig,
                    :offset => o_off,
                    :truncate_lower => o_trl,
                    :truncate_upper => o_tr,
                    :width => uw,
                    :uoff => uoff
                )
            )

            tabs = state.component_tabs[]
            act_idx = findfirst(t -> t.id == state.active_tab_id[], tabs)
            if act_idx !== nothing
                tabs[act_idx].last_result = current_result
                all_res = state.all_tab_results[]
                all_res[state.active_tab_id[]] = current_result
                state.all_tab_results[] = all_res
            end
            state.results[] = current_result
            state.event_table_dom[] = build_event_table_dom(current_result.events; max_rows=30)

            try
                sim_comp = m_cat == "Multi-channel Model" ? [
                    UnfoldSim.MultichannelComponent(base_comp, CACHED_HARTMUT => "Left Postcentral Gyrus"),
                    UnfoldSim.MultichannelComponent(base_comp, CACHED_HARTMUT => "Right Occipital Pole")
                ] : base_comp
                state.last_simulation_obj[] = Simulation(design, sim_comp, onsets, noise)
            catch e
                println("⚠️ Could not store: $e")
                state.last_simulation_obj[] = nothing
            end

            state.status_text[] = "Done"
        catch e
            state.results[] = (noisy=[Point2f(0,0)], clean=[Point2f(0,0)],
                multichannel_noisy=zeros(1,1), multichannel_clean=zeros(1,1),
                time=[0.0], events=DataFrame(), err=sprint(showerror,e),
                raw_onsets=Int[], onset_type="Error",
                onset_params=Dict{Symbol,Any}())
            state.status_text[] = "Error: $(sprint(showerror,e))"
            state.event_table_dom[] = Bonito.DOM.span("Error — run simulation.",
                style="font-size:10px; color:var(--text2); padding:8px;")
            println("Sim error: ", e)
        finally
            state.is_running[] = false
        end
    end
end
