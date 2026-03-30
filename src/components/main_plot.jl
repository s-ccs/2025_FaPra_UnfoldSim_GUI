# ============================================================
# MAIN PLOT
# Owns: fig/ax creation, cumulative signal, channel/tab lines,
#       legend, event markers, hanning refs
# ============================================================

function init_main_plot!(state::AppState)
    max_tabs   = 10
    tab_colors = [:cyan,:orange,:magenta,:blue,:green,:purple,:pink,:brown,:navy,:olive]

    # ── Figure ────────────────────────────────────────────────
    fig = Figure(size=(800,600), backgroundcolor=RGBf(0.051,0.071,0.090))
    ax  = Axis(fig[1,1],
        title="UnfoldSim + ERP Explorer (Cumulative)",
        xlabel="Time (s)", ylabel="µV",
        xgridvisible=false, ygridvisible=true,
        backgroundcolor=RGBf(0.086,0.106,0.133),
        titlecolor=:white, xlabelcolor=:white, ylabelcolor=:white,
        xticklabelcolor=:white, yticklabelcolor=:white,
        ygridcolor=RGBAf(1,1,1,0.08), spinewidth=0,
        titlesize=14, titlefont=:bold)
    ax.xtickcolor[] = RGBAf(1,1,1,0.5)
    ax.ytickcolor[] = RGBAf(1,1,1,0.5)
    rowgap!(fig.layout, 0); colgap!(fig.layout, 0)
    state.fig = fig; state.ax = ax

    # ── Static elements ───────────────────────────────────────
    hlines!(ax, [0.0], color=(:white,0.15), linewidth=0.5, linestyle=:dash)
    state.sep_xs_obs = Observable([0.0])
    sep_plot = vlines!(ax, state.sep_xs_obs,
        color=RGBAf(0.87,0.82,0.25,0.55), linestyle=:dash, linewidth=2.5)
    sep_plot.visible[] = false
    state.sep_plot = sep_plot

    # ── Per-tab lines ─────────────────────────────────────────
    state.tab_line_data       = [Observable(Point2f[(0,0)]) for _ in 1:max_tabs]
    state.tab_line_visibility = [Observable(false)          for _ in 1:max_tabs]
    for i in 1:max_tabs
        lines!(ax, state.tab_line_data[i],
            color=(tab_colors[i],0.5), linewidth=1.5, linestyle=:dash,
            visible=state.tab_line_visibility[i])
    end

    # ── Cumulative lines ──────────────────────────────────────
    state.cumulative_noisy_obs = Observable(Point2f[(0,0)])
    state.cumulative_clean_obs = Observable(Point2f[(0,0)])
    lines!(ax, state.cumulative_noisy_obs, color=:gray, linewidth=2.5, label="Cumulative Noisy")
    lines!(ax, state.cumulative_clean_obs, color=:red,  linewidth=3.0, label="Cumulative Clean")

    # ── Per-channel lines ─────────────────────────────────────
    N = state.n_channels
    state.channel_line_data       = [Observable(Point2f[(0,0)]) for _ in 1:N]
    state.channel_line_visibility = [Observable(false)          for _ in 1:N]
    rainbow = [get(ColorSchemes.jet, (i-1)/max(N-1,1)) for i in 1:N]
    for i in 1:N
        lines!(ax, state.channel_line_data[i],
            color=rainbow[i], linewidth=2.5,
            visible=state.channel_line_visibility[i])
    end

    # ── Refs for dynamic overlays ─────────────────────────────
    state.hanning_plot_refs = Ref{Vector{Any}}([])
    state.event_marker_refs = Ref{Vector{Any}}([])

    # ── Event markers on(results) ─────────────────────────────
    event_colors = [
        RGBAf(0.22,0.78,0.56,0.75), RGBAf(0.58,0.40,1.00,0.75),
        RGBAf(0.98,0.47,0.26,0.75), RGBAf(0.91,0.30,0.55,0.75),
        RGBAf(0.25,0.65,0.95,0.75), RGBAf(0.95,0.80,0.20,0.75),
    ]
    on(state.results) do res
        for p in state.event_marker_refs[]
            try; p in ax.scene.plots && delete!(ax, p); catch; end
        end
        empty!(state.event_marker_refs[])
        (res.err != "" || isempty(res.events) || !hasproperty(res.events,:latency)) && return
        if hasproperty(res.events, :condition)
            for (i, cond) in enumerate(unique(res.events.condition))
                color = event_colors[mod1(i, length(event_colors))]
                mask  = res.events.condition .== cond
                p = vlines!(ax, res.events.latency[mask] ./ 100,
                    color=color, linewidth=1.4, linestyle=:dashdot)
                push!(state.event_marker_refs[], p)
            end
        end
    end

    # ── Cumulative update on(all_tab_results) ─────────────────
    on(state.all_tab_results) do all_res
        try
            for i in 1:max_tabs; state.tab_line_visibility[i][] = false; end
            if isempty(all_res)
                state.cumulative_clean_obs[] = Point2f[]
                state.cumulative_noisy_obs[] = Point2f[]
                sep_plot.visible[] = false; return
            end
            cum_clean, cum_noisy, ref_time, events_df = compute_cumulative_signal(all_res)
            state.cumulative_clean_obs[] = cum_clean
            state.cumulative_noisy_obs[] = cum_noisy
            for (tab_idx, tab) in enumerate(state.component_tabs[])
                tab_idx > max_tabs && break
                res = get(all_res, tab.id, nothing)
                if !isnothing(res) && res.err == "" && !isempty(res.clean)
                    state.tab_line_data[tab_idx][]       = res.clean
                    state.tab_line_visibility[tab_idx][] = true
                else
                    state.tab_line_visibility[tab_idx][] = false
                end
            end
            if !isempty(events_df) && hasproperty(events_df,:subject) &&
               state.design_category[] == "Multi-subject design"
                subjs = sort(unique(events_df.subject))
                if length(subjs) > 1 && !isempty(ref_time)
                    tps = ref_time[end] - ref_time[1]
                    state.sep_xs_obs[] = [ref_time[1] + i*(tps/length(subjs)) for i in 1:length(subjs)-1]
                    sep_plot.visible[] = true
                else; sep_plot.visible[] = false; end
            else; sep_plot.visible[] = false; end
            autolimits!(ax)
        catch e; println("Cumulative plot error: $e"); end
    end

    # ── Channel line update ───────────────────────────────────
    onany(state.selected_channels, state.results, state.active_model_category) do sel, res, m_cat
        for i in 1:N; state.channel_line_visibility[i][] = false; end
        if m_cat == "Multi-channel Model" && !isempty(sel) && res.err == "" && !isempty(res.time)
            CLEAN_CH = state.clean_signal_channel_idx
            for ch in sel
                ch == CLEAN_CH && continue
                ch <= size(res.multichannel_clean, 2) && ch <= N || continue
                state.channel_line_data[ch][]       = Point2f.(res.time, res.multichannel_clean[:,ch])
                state.channel_line_visibility[ch][] = true
            end
            autolimits!(ax)
        end
    end

    # ── Legend (reactive) ─────────────────────────────────────
    rainbow_colors = rainbow
    legend_content = map(state.selected_channels, state.active_model_category,
                         state.component_tabs, state.results) do sel, m_cat, tabs, res
        function hex(c)
            r = round(Int, clamp(red(c),0,1)*255)
            g = round(Int, clamp(green(c),0,1)*255)
            b = round(Int, clamp(blue(c),0,1)*255)
            "#$(lpad(string(r,base=16),2,"0"))$(lpad(string(g,base=16),2,"0"))$(lpad(string(b,base=16),2,"0"))"
        end
        base_items = [
            Bonito.DOM.div(Bonito.DOM.div(style="width:40px;height:3px;background:var(--text2);display:inline-block;vertical-align:middle;margin-right:8px;"),
                Bonito.DOM.span("Cumulative Noisy",style="font-size:11px;vertical-align:middle;color:var(--text1);"),style="display:inline-block;margin-right:25px;"),
            Bonito.DOM.div(Bonito.DOM.div(style="width:40px;height:3px;background:#ff7b72;display:inline-block;vertical-align:middle;margin-right:8px;"),
                Bonito.DOM.span("Cumulative Clean",style="font-size:11px;vertical-align:middle;color:var(--text1);"),style="display:inline-block;margin-right:25px;"),
        ]
        tab_items = [begin
            hx = hex(parse(Colorant,string(tab_colors[idx])))
            Bonito.DOM.div(Bonito.DOM.div(style="width:40px;height:2px;background:$hx;display:inline-block;vertical-align:middle;margin-right:8px;border-top:2px dashed $hx;"),
                Bonito.DOM.span(tab.name,style="font-size:10px;vertical-align:middle;color:var(--text1);"),style="display:inline-block;margin-right:15px;")
        end for (idx,tab) in enumerate(tabs) if idx <= max_tabs]

        event_items = if res.err=="" && !isempty(res.events) && hasproperty(res.events,:condition)
            ec_hex = ["#38C78E","#9466FF","#FA7842","#E84D8A","#40A6F2","#F2CC33"]
            [begin
                h  = ec_hex[mod1(i,6)]
                n  = sum(res.events.condition .== cond)
                Bonito.DOM.div(
                    Bonito.DOM.div(style="width:40px;height:0;border-top:2px dashed $h;display:inline-block;vertical-align:middle;margin-right:4px;"),
                    Bonito.DOM.span("Condition $cond ($n)", style="font-size:10px;color:$h;font-weight:600;"),
                    style="display:inline-block;margin-right:15px;")
            end for (i,cond) in enumerate(unique(res.events.condition))]
        else []; end

        channel_section = if m_cat == "Multi-channel Model" && !isempty(sel)
            CLEAN_CH = state.clean_signal_channel_idx
            ch_items = [begin
                ch_name = string(state.channel_names_list[ch])
                hx = hex(rainbow_colors[ch])
                Bonito.DOM.div(Bonito.DOM.div(style="width:40px;height:3px;background:$hx;display:inline-block;vertical-align:middle;margin-right:8px;"),
                    Bonito.DOM.span("Ch: $ch_name",style="font-size:10px;vertical-align:middle;color:var(--text1);"),style="display:inline-block;margin-right:15px;")
            end for ch in sort(collect(sel)) if ch != CLEAN_CH && ch <= length(state.channel_names_list)]
            isempty(ch_items) ? [] :
                [Bonito.DOM.span("| Electrodes: ",style="font-size:11px;color:var(--text2);margin-right:8px;vertical-align:middle;"); ch_items...]
        else []; end

        Bonito.DOM.div(
            Bonito.DOM.span("Legend: ",style="font-weight:700;font-size:11px;margin-right:10px;color:var(--text2);"),
            base_items..., tab_items..., event_items..., channel_section...,
            style="padding:10px 14px;background:var(--bg2);border:1px solid var(--border);border-radius:8px;display:flex;flex-wrap:wrap;gap:10px;align-items:center;margin-top:10px;"
        )
    end

    return fig, legend_content
end

function build_center_panel(fig, legend_content, onset_plot_fig)
    return Bonito.DOM.div(
        Bonito.DOM.div(fig, legend_content,
            style="margin-bottom:20px;max-width:100%;overflow:hidden;box-sizing:border-box;"),
        Bonito.DOM.div(
            Bonito.DOM.h5("Onset Distribution Probability Density",
                style="margin:0 0 8px 0;font-size:13px;font-weight:700;color:var(--text1);text-align:center;"),
            Bonito.DOM.div(
                Bonito.DOM.div(
                    Bonito.DOM.span("Density",
                        style="position:absolute;left:8px;top:50%;transform:translateY(-50%) rotate(-90deg);transform-origin:left top;color:var(--text1);font-size:12px;font-weight:600;letter-spacing:0.2px;"),
                    Bonito.DOM.div(onset_plot_fig, style="margin-left:26px;"),
                    style="position:relative;"
                ),
                Bonito.DOM.div(
                    Bonito.DOM.span("Samples", style="color:var(--text1);font-size:12px;font-weight:600;letter-spacing:0.2px;"),
                    style="text-align:center;margin-top:4px;margin-left:26px;"
                )
            ),
            var"data-onset-wrapper"="true",
            style="padding:12px;background:var(--bg2);border:1px solid var(--border);border-radius:10px;max-width:100%;overflow:hidden;box-sizing:border-box;"),
        style="grid-column:2;padding:18px;overflow:auto;box-sizing:border-box;background:var(--bg1);"
    )
end
