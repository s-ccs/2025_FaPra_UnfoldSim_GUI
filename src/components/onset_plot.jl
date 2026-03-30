# ============================================================
# ONSET PLOT
# Owns: onset figure creation + reactive density update
# ============================================================

function init_onset_plot!(state::AppState)
    onset_plot_fig = Figure(size=(800,200),
        backgroundcolor=RGBf(0.051,0.071,0.090))
    onset_ax = Axis(onset_plot_fig[1,1],
        title="",
        xlabel="", ylabel="",
        xgridvisible=true, ygridvisible=true,
        backgroundcolor=RGBf(0.055,0.075,0.115),
        titlecolor=RGBAf(0.90,0.93,0.98,1.0), xlabelcolor=RGBAf(0.90,0.93,0.98,1.0), ylabelcolor=RGBAf(0.90,0.93,0.98,1.0),
        xticklabelcolor=RGBAf(0.82,0.86,0.92,1.0), yticklabelcolor=RGBAf(0.82,0.86,0.92,1.0),
        xlabelsize=14, ylabelsize=14, xticklabelsize=11, yticklabelsize=11,
        xlabelpadding=8, ylabelpadding=10,
        titlesize=12, spinewidth=0)
    onset_ax.xtickcolor[] = RGBAf(0.72,0.75,0.82,0.6)
    onset_ax.ytickcolor[] = RGBAf(0.72,0.75,0.82,0.6)
    onset_ax.xgridcolor[] = RGBAf(0.80,0.85,0.95,0.08)
    onset_ax.ygridcolor[] = RGBAf(0.80,0.85,0.95,0.08)
    onset_ax.bottomspinecolor[] = RGBAf(0.70,0.75,0.85,0.35)
    onset_ax.leftspinecolor[] = RGBAf(0.70,0.75,0.85,0.35)
    rowgap!(onset_plot_fig.layout, 0); colgap!(onset_plot_fig.layout, 0)

    state.onset_plot_fig = onset_plot_fig
    state.onset_ax       = onset_ax

    on(state.results) do res
        try
            empty!(onset_ax)
            res.err != "" && return
            raw = res.raw_onsets
            isempty(raw) && return

            x_min = max(0, minimum(raw) - 20)
            x_max = maximum(raw) + 20
            xs    = LinRange(x_min, x_max, 300)

            if res.onset_type in ("LogNormal", "Log Normal")
                μ = get(res.onset_params, :mu, 1.0)
                σ = get(res.onset_params, :sigma, 0.5)
                offset = get(res.onset_params, :offset, 0.0)
                trl = get(res.onset_params, :truncate_lower, nothing)
                tru = get(res.onset_params, :truncate_upper, nothing)
                base = LogNormal(μ, σ)
                ys = similar(collect(xs))
                for (i, x) in enumerate(xs)
                    y = x - offset
                    if y <= 0
                        ys[i] = 0.0
                        continue
                    end
                    if trl !== nothing && x < trl
                        ys[i] = 0.0
                        continue
                    end
                    if tru !== nothing && x > tru
                        ys[i] = 0.0
                        continue
                    end
                    ys[i] = pdf(base, y)
                end
                lines!(onset_ax, collect(xs), ys, color=RGBAf(0.10,0.30,1.0,1.0), linewidth=2.2)
                hist!(onset_ax, Float64.(raw), normalization=:pdf,
                    color=(RGBAf(0.10,0.30,1.0,1.0),0.18), strokecolor=(RGBAf(0.10,0.30,1.0,1.0),0.7), strokewidth=1, bins=30)
            elseif res.onset_type == "Uniform"
                offset = get(res.onset_params, :offset, 0.0)
                width  = get(res.onset_params, :width, 1.0)
                a = offset
                b = offset + max(width, 1e-6)
                h = 1/(b-a)
                step_blue = RGBAf(0.10,0.30,1.0,1.0)
                poly!(onset_ax, [Point2f(a, 0), Point2f(b, 0), Point2f(b, h), Point2f(a, h)],
                    color=(step_blue, 0.22), strokecolor=:transparent, strokewidth=0)
                x_min < a && lines!(onset_ax, [x_min, a], [0.0, 0.0], color=step_blue, linewidth=2.8)
                lines!(onset_ax, [a, a], [0.0, h], color=step_blue, linewidth=2.8)
                lines!(onset_ax, [a, b], [h, h], color=step_blue, linewidth=2.8)
                lines!(onset_ax, [b, b], [h, 0.0], color=step_blue, linewidth=2.8)
                b < x_max && lines!(onset_ax, [b, x_max], [0.0, 0.0], color=step_blue, linewidth=2.8)
                xlims!(onset_ax, x_min, x_max)
                ylims!(onset_ax, 0.0, max(h*1.05, 0.02))
            else
                hist!(onset_ax, Float64.(raw), normalization=:pdf,
                    color=(RGBAf(0.10,0.30,1.0,1.0),0.18), strokecolor=(RGBAf(0.10,0.30,1.0,1.0),0.7), strokewidth=1, bins=30)
            end
            autolimits!(onset_ax)
        catch e; println("Onset plot error: $e"); end
    end

    return onset_plot_fig
end

function build_onset_card(section_title_s, card_s, onset_choice, onset_ui)
    return Bonito.DOM.div(
        Bonito.DOM.h4("3. ⏱ Onset Configuration", style=section_title_s),
        onset_choice,
        onset_ui,
        style=card_s
    )
end
