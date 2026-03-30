# ============================================================
# TOPOPLOT + ERP PANEL
# Owns: brain_fig/brain_ax (scatter dot), hover_fig,
#       brain_fig2/ax_topo1 (heatmap), all reactive handlers,
#       erp_panel_content map
# ============================================================

function init_topoplot!(state::AppState)
    N = state.n_channels
    positions     = [Point2f(state.electrode_positions[ch]...) for ch in state.channel_names_list]
    topo_positions = copy(positions)
    CLEAN_CH = state.clean_signal_channel_idx

    # ── Scatter dot topoplot ─────────────────────────────────
    brain_fig = Figure(size=(250,250), backgroundcolor=RGBf(0.086,0.106,0.133))
    brain_ax  = Axis(brain_fig[1,1],
        aspect=DataAspect(),
        title="HArtMuT EEG ($(N) Channels)",
        titlesize=10, titlefont=:bold, titlealign=:center,
        backgroundcolor=RGBf(0.086,0.106,0.133),
        titlecolor=:white)
    rowgap!(brain_fig.layout, 0); colgap!(brain_fig.layout, 0)
    hidedecorations!(brain_ax); hidespines!(brain_ax)
    draw_head_outline!(brain_ax)

    # ── Hover label ──────────────────────────────────────────
    hovered_electrode_name = Observable("Hover electrode: —")
    hover_fig = Figure(size=(260,26), backgroundcolor=RGBf(0.086,0.106,0.133))
    hover_label = Label(hover_fig[1,1], hovered_electrode_name, color=:white, fontsize=9, tellwidth=false)

    # ── Base colour / data observables ───────────────────────
    topo_colors_obs = Observable([i == CLEAN_CH ? RGBAf(1.0,0.0,0.0,1.0) :
                                                   RGBAf(0.2,0.4,0.9,0.85) for i in 1:N])
    topo_data_obs   = Observable(zeros(N))
    topo_rms_obs    = Observable(zeros(N))
    topo_base_colors = Observable(fill(RGBAf(0.2,0.4,0.9,0.85), N))
    topo_base_data   = Observable(zeros(N))
    topo_base_rms    = Observable(zeros(N))
    state.topo_colors_obs  = topo_colors_obs
    state.topo_data_obs    = topo_data_obs
    state.topo_rms_obs     = topo_rms_obs
    state.topo_base_colors = topo_base_colors
    state.topo_base_data   = topo_base_data
    state.topo_base_rms    = topo_base_rms

    scatter!(brain_ax, positions, color=topo_colors_obs, markersize=9,
             strokewidth=1, strokecolor=:black)

    # ── Mutex for click debounce ──────────────────────────────
    click_in_progress  = Ref(false)
    pending_topo_gen   = Ref(0)

    # ── Heatmap topoplot (brain_fig2) ─────────────────────────
    brain_fig2 = Figure(size=(260,280), backgroundcolor=RGBf(0.086,0.106,0.133))
        topo_title_label = Label(brain_fig2[0,1], "Amplitude Topoplot",
            color=:white, fontsize=10, font=:bold, tellwidth=false)
        ax_topo1, topo_cbar = topoplot(
        brain_fig2[1,1], topo_data_obs, topo_positions;
        colormap       = Reverse(:RdBu),
        label          = nothing,
        axis           = (backgroundcolor=RGBf(0.086,0.106,0.133),
                          aspect=DataAspect(),
                          xticklabelcolor=:white, yticklabelcolor=:white,
                          xtickcolor=:white, ytickcolor=:white,
                          xlabelcolor=:white, ylabelcolor=:white,
                          xgridcolor=RGBAf(1,1,1,0.08), ygridcolor=RGBAf(1,1,1,0.08),
                          spinewidth=0),
        colorbar       = (label="Voltage [µV]", labelcolor=:white,
                          ticklabelcolor=:white, tellwidth=true),
        enlarge        = 1.05,
        interpolation  = TopoPlots.DelaunayMesh(),
        electrode_style= (strokecolor=:black, strokewidth=1, color=:white, markersize=6),
        head_line      = (color=:black, linewidth=2),
    )
    state.brain_fig  = brain_fig
    state.brain_ax   = brain_ax
    state.brain_fig2 = brain_fig2
    state.ax_topo1   = ax_topo1

    on(state.is_dark_theme) do dark
        try
            if dark
                brain_fig.scene.backgroundcolor[]  = RGBf(0.086,0.106,0.133)
                brain_ax.backgroundcolor[]         = RGBf(0.086,0.106,0.133)
                brain_ax.titlecolor[]              = RGBf(1.0,1.0,1.0)
                hover_fig.scene.backgroundcolor[]  = RGBf(0.086,0.106,0.133)
                hover_label.color[]                = RGBf(1.0,1.0,1.0)
                brain_fig2.scene.backgroundcolor[] = RGBf(0.086,0.106,0.133)
                topo_title_label.color[]           = RGBf(1.0,1.0,1.0)
                ax_topo1.backgroundcolor[]         = RGBf(0.086,0.106,0.133)
                ax_topo1.xticklabelcolor[]         = RGBf(1.0,1.0,1.0)
                ax_topo1.yticklabelcolor[]         = RGBf(1.0,1.0,1.0)
                ax_topo1.xtickcolor[]              = RGBf(1.0,1.0,1.0)
                ax_topo1.ytickcolor[]              = RGBf(1.0,1.0,1.0)
                ax_topo1.xlabelcolor[]             = RGBf(1.0,1.0,1.0)
                ax_topo1.ylabelcolor[]             = RGBf(1.0,1.0,1.0)
                ax_topo1.xgridcolor[]              = RGBAf(1.0,1.0,1.0,0.08)
                ax_topo1.ygridcolor[]              = RGBAf(1.0,1.0,1.0,0.08)
                try topo_cbar.labelcolor[] = RGBf(1.0,1.0,1.0) catch end
                try topo_cbar.ticklabelcolor[] = RGBf(1.0,1.0,1.0) catch end
            else
                brain_fig.scene.backgroundcolor[]  = RGBf(0.96,0.97,0.98)
                brain_ax.backgroundcolor[]         = RGBf(0.96,0.97,0.98)
                brain_ax.titlecolor[]              = RGBf(0.12,0.14,0.16)
                hover_fig.scene.backgroundcolor[]  = RGBf(1.0,1.0,1.0)
                hover_label.color[]                = RGBf(0.12,0.14,0.16)
                brain_fig2.scene.backgroundcolor[] = RGBf(0.96,0.97,0.98)
                topo_title_label.color[]           = RGBf(0.12,0.14,0.16)
                ax_topo1.backgroundcolor[]         = RGBf(0.96,0.97,0.98)
                ax_topo1.xticklabelcolor[]         = RGBf(0.12,0.14,0.16)
                ax_topo1.yticklabelcolor[]         = RGBf(0.12,0.14,0.16)
                ax_topo1.xtickcolor[]              = RGBf(0.4,0.4,0.4)
                ax_topo1.ytickcolor[]              = RGBf(0.4,0.4,0.4)
                ax_topo1.xlabelcolor[]             = RGBf(0.12,0.14,0.16)
                ax_topo1.ylabelcolor[]             = RGBf(0.12,0.14,0.16)
                ax_topo1.xgridcolor[]              = RGBAf(0.82,0.84,0.87,0.8)
                ax_topo1.ygridcolor[]              = RGBAf(0.82,0.84,0.87,0.8)
                try topo_cbar.labelcolor[] = RGBf(0.12,0.14,0.16) catch end
                try topo_cbar.ticklabelcolor[] = RGBf(0.12,0.14,0.16) catch end
            end
        catch
        end
    end

    # ── Reactive update: onany(results, time_slider, model_cat) ──
    onany(state.results, state.time_slider_throttled, state.active_model_category) do res, time_pt, m_cat
        if m_cat != "Multi-channel Model" || res.err != "" || size(res.multichannel_clean,2) != N
            base = [i == CLEAN_CH ? RGBAf(1.0,0.0,0.0,1.0) : RGBAf(0.2,0.4,0.9,0.85) for i in 1:N]
            topo_base_colors[] = base; topo_base_data[] = zeros(N); topo_base_rms[] = zeros(N)
            topo_colors_obs[]  = base; topo_data_obs[]  = zeros(N); topo_rms_obs[]  = zeros(N)
            return
        end
        mc    = res.multichannel_clean
        t_idx = clamp(time_pt, 1, size(mc,1))
        base_amp = mc[t_idx,:]
        base_rms = [sqrt(mean(mc[:,ch].^2)) for ch in 1:N]
        colors, _ = plot_expexplorer_topoplot(res.multichannel_noisy, topo_positions, time_pt, "Amplitude")
        n_c = length(colors)
        base = [i == CLEAN_CH ? RGBAf(1.0,0.0,0.0,1.0) :
                (i <= n_c ? colors[i] : RGBAf(0.2,0.4,0.9,0.85)) for i in 1:N]
        topo_base_colors[] = base; topo_base_data[] = base_amp; topo_base_rms[] = base_rms
        sel = state.selected_channels[]
        if isempty(sel)
            topo_colors_obs[] = base; topo_data_obs[] = base_amp; topo_rms_obs[] = base_rms
        else
            amp_range = maximum(abs.(base_amp)); rms_range = maximum(base_rms)
            amp_hi = copy(base_amp); rms_hi = copy(base_rms); dot_hi = copy(base)
            hl_amp = amp_range > 0 ? amp_range*1.5 : 1.0
            hl_rms = rms_range > 0 ? rms_range*1.5 : 1.0
            for ch in sel
                ch == CLEAN_CH && continue; ch <= N || continue
                amp_hi[ch] = base_amp[ch] >= 0 ? hl_amp : -hl_amp
                rms_hi[ch] = hl_rms
                dot_hi[ch] = RGBAf(1.0,0.95,0.0,1.0)
            end
            topo_colors_obs[] = dot_hi; topo_data_obs[] = amp_hi; topo_rms_obs[] = rms_hi
        end
    end

    # ── Electrode click handler ───────────────────────────────
    on(events(brain_ax.scene).mousebutton) do event
        event.button == Mouse.left && event.action == Mouse.press || return
        state.active_model_category[] == "Multi-channel Model"    || return
        click_in_progress[] && return
        click_in_progress[] = true
        try
            pos = mouseposition(brain_ax.scene)
            min_dist = Inf; best_idx = 0
            for (i, p) in enumerate(positions)
                d = (pos[1]-p[1])^2 + (pos[2]-p[2])^2
                if d < min_dist; min_dist = d; best_idx = i; end
            end
            if min_dist > 0.04 || best_idx == CLEAN_CH
                click_in_progress[] = false; return
            end
            curr = copy(state.selected_channels[])
            best_idx in curr ? delete!(curr, best_idx) : push!(curr, best_idx)

            dot_hi = copy(topo_base_colors[])
            for ch in curr
                ch == CLEAN_CH && continue; ch <= N || continue
                dot_hi[ch] = RGBAf(1.0,0.95,0.0,1.0)
            end
            topo_colors_obs[] = dot_hi
            state.selected_channels[] = curr

            snap_base_amp = copy(topo_base_data[]); snap_base_rms = copy(topo_base_rms[])
            snap_curr = copy(curr)
            pending_topo_gen[] += 1; my_gen = pending_topo_gen[]

            @async begin
                try
                    sleep(0.35)
                    pending_topo_gen[] != my_gen && (click_in_progress[] = false; return)
                    if !all(snap_base_amp .== 0)
                        amp_range = maximum(abs.(snap_base_amp)); rms_range = maximum(snap_base_rms)
                        amp_hi = copy(snap_base_amp); rms_hi = copy(snap_base_rms)
                        hl_amp = amp_range > 0 ? amp_range*1.5 : 1.0
                        hl_rms = rms_range > 0 ? rms_range*1.5 : 1.0
                        for ch in snap_curr
                            ch == CLEAN_CH && continue; ch <= N || continue
                            amp_hi[ch] = snap_base_amp[ch] >= 0 ? hl_amp : -hl_amp
                            rms_hi[ch] = hl_rms
                        end
                        topo_data_obs[] = amp_hi; topo_rms_obs[] = rms_hi
                    end
                catch e; println("Async topo error: $e")
                finally; click_in_progress[] = false; end
            end
        catch e
            click_in_progress[] = false
            println("Electrode click error: $e")
        end
    end

    # ── Hover handlers ────────────────────────────────────────
    function _update_hover(curr_pos, pts)
        min_dist = Inf; best_idx = 0
        for (i, p) in enumerate(pts)
            d = (curr_pos[1]-p[1])^2 + (curr_pos[2]-p[2])^2
            if d < min_dist; min_dist = d; best_idx = i; end
        end
        hovered_electrode_name[] = best_idx > 0 && min_dist <= 0.03 ?
            "Hover electrode: $(state.channel_names_list[best_idx])" : "Hover electrode: —"
    end
    on(events(brain_ax.scene).mouseposition) do _
        _update_hover(mouseposition(brain_ax.scene), positions)
    end
    on(events(ax_topo1.scene).mouseposition) do _
        _update_hover(mouseposition(ax_topo1.scene), topo_positions)
    end

    # ── Dot colour sync when selection changes ────────────────
    on(state.selected_channels) do sel
        base = topo_base_colors[]
        highlighted = copy(base)
        for ch in sel
            ch == CLEAN_CH && continue; ch <= N || continue
            highlighted[ch] = RGBAf(1.0,0.95,0.0,1.0)
        end
        topo_colors_obs[] = highlighted
    end

    # ── erp_panel_content reactive map ───────────────────────
    erp_panel_content = map(state.active_model_category) do m_cat
        event_table_section = Bonito.DOM.div(
            Bonito.DOM.h4("📋 Event Table",
                style="font-size:12px;font-weight:700;color:var(--accent);margin:0 0 6px 0;border-bottom:1px solid var(--border);padding-bottom:5px;"),
            Bonito.DOM.div(state.event_table_dom;
                style="width:100%;max-width:100%;overflow:hidden;box-sizing:border-box;"),
            Bonito.DOM.div(
                Bonito.DOM.span("💡 Each row is one trial. Latency = onset sample index.",
                    style="font-size:9px;color:var(--text2);font-style:italic;"),
                style="padding:6px 8px;background:var(--bg2);border-left:3px solid var(--border);border-radius:3px;margin-top:6px;"),
            style="padding:8px 0 0 0;")

        if m_cat != "Multi-channel Model"
            Bonito.DOM.div(
                Bonito.DOM.p("🔬 Switch to Multi-channel Model to explore electrode topographies.",
                    style="color:var(--text2);font-style:italic;font-size:11px;padding:12px;"),
                event_table_section,
                style="padding:10px;")
        else
            Bonito.DOM.div(
                Bonito.DOM.h3("ERP Explorer",
                    style="font-size:15px;margin:6px 0;font-weight:700;color:var(--accent);"),
                Bonito.DOM.div(brain_fig,
                    style="margin-bottom:6px;width:100%;max-width:400px;height:auto;overflow:hidden;display:block;box-sizing:border-box;"),
                Bonito.DOM.div(hover_fig,
                    style="margin-bottom:4px;width:100%;max-width:400px;height:auto;overflow:hidden;display:block;box-sizing:border-box;"),
                Bonito.DOM.div(brain_fig2,
                    style="margin-bottom:6px;width:100%;max-width:400px;height:auto;overflow:hidden;display:block;box-sizing:border-box;"),
                event_table_section,
                style="padding:10px;")
        end
    end

    return erp_panel_content
end

function build_erp_panel(erp_panel_content)
    return Bonito.DOM.div(
        erp_panel_content,
        style="grid-column:3;padding:12px;background:var(--bg2);border-left:1px solid var(--border);overflow-y:auto;overflow-x:hidden;height:100vh;box-sizing:border-box;width:100%;max-width:100%;"
    )
end
