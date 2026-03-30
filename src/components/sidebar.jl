# ============================================================
# SIDEBAR
# Owns: theme toggle, design config UI, onset UI,
#       global_css, floating_status, build_sidebar DOM
# ============================================================

function init_sidebar!(state::AppState, session)
    # ── Design dropdown + reactive sync ──────────────────────
    design_dropdown_options = ["Single-subject design", "Repeat design", "Multi-subject design"]
    state.design_dropdown   = Bonito.Dropdown(design_dropdown_options; index=1)
    syncing_design_dropdown = Ref(false)

    on(state.design_dropdown.value) do val
        syncing_design_dropdown[] && return
        state.user_set_design[]  = true
        state.design_category[]  = val
        state.all_tab_results[]  = Dict{String,Any}()
        for tab in state.component_tabs[]; tab.last_result = nothing; end
        old = state.noise_lvl.value[]
        state.noise_lvl.value[] = old == 0 ? 1 : 0
        state.noise_lvl.value[] = old
    end
    on(state.design_category) do val
        idx = findfirst(==(val), design_dropdown_options)
        if idx !== nothing && state.design_dropdown.value[] != val
            syncing_design_dropdown[] = true
            state.design_dropdown.value[] = val
            syncing_design_dropdown[] = false
        end
    end

    # ── Design config UI ─────────────────────────────────────
    state.design_config_ui = Bonito.map(
        state.active_model_category, state.design_category
    ) do m, d
        if m == "Mixed Model"
            Bonito.DOM.div(
                Bonito.DOM.span("Multi-subject design (required for Mixed Model)",
                    style="font-size:14px;color:#f78166;font-weight:700;display:block;margin-bottom:6px;"),
                Bonito.DOM.div(
                    Bonito.DOM.span(Bonito.map(v -> "Subjects: $(map_to_subjects(v))", state.subjects_throttled), style=state.label_s),
                    slider_row(state.n_subjects, state.n_subjects_tf),
                    Bonito.DOM.span(Bonito.map(v -> "Items: $(map_to_items(v))", state.items_throttled), style=state.label_s),
                    slider_row(state.n_items, state.n_items_tf)))
        else
            Bonito.DOM.div(
                Bonito.DOM.span("Design Type", style=state.label_s), state.design_dropdown,
                Bonito.DOM.div(Bonito.DOM.span("Single-subject configuration active.",
                        style="font-style:italic;color:var(--text2)"),
                    style=d == "Single-subject design" ? "" : "display:none;"),
                Bonito.DOM.div(
                    Bonito.DOM.span(Bonito.map(v -> "Repeats: $(map_to_items(v))", state.items_throttled), style=state.label_s),
                    slider_row(state.n_items, state.n_items_tf),
                    style=d == "Repeat design" ? "" : "display:none;"),
                Bonito.DOM.div(
                    Bonito.DOM.span(Bonito.map(v -> "Subjects: $(map_to_subjects(v))", state.subjects_throttled), style=state.label_s),
                    slider_row(state.n_subjects, state.n_subjects_tf),
                    Bonito.DOM.span(Bonito.map(v -> "Items: $(map_to_items(v))", state.items_throttled), style=state.label_s),
                    slider_row(state.n_items, state.n_items_tf),
                    Bonito.DOM.span("ℹ️ Linear Model with Multi-subject design: component applied per subject.",
                        style="font-size:9px;color:var(--accent);font-style:italic;display:block;margin-top:4px;"),
                    style=d == "Multi-subject design" ? "" : "display:none;"))
        end
    end

    # ── Onset UI ──────────────────────────────────────────────
    state.onset_ui = Bonito.DOM.div(
        Bonito.DOM.span("No parameters needed.",
            style=map(o -> o == "No Onset" ? "font-style:italic;color:var(--text2);" : "display:none;", state.onset_choice.value)),
        Bonito.DOM.div(
            Bonito.DOM.span(Bonito.map(v -> "Width: $(map_to_width(v))", state.width_throttled), style=state.label_s),
            slider_row(state.u_width, state.u_width_tf),
            Bonito.DOM.span(Bonito.map(v -> "Offset: $(map_to_offset(v))", state.uoff_throttled), style=state.label_s),
            slider_row(state.u_offset_uni, state.u_offset_uni_tf),
            style=map(o -> o == "Uniform" ? "" : "display:none;", state.onset_choice.value)
        ),
        Bonito.DOM.div(
            Bonito.DOM.span(Bonito.map(v -> "μ (Mu): $(round(map_to_mu(v), digits=2))", state.mu_throttled), style=state.label_s),
            slider_row(state.on_mu, state.on_mu_tf),
            Bonito.DOM.span(Bonito.map(v -> "σ (Sigma): $(round(map_to_onset_sigma(v), digits=2))", state.sigma_onset_throttled), style=state.label_s),
            slider_row(state.on_sigma, state.on_sigma_tf),
            Bonito.DOM.span(Bonito.map(v -> "Offset: $(map_to_offset(v))", state.offset_throttled), style=state.label_s),
            slider_row(state.on_offset, state.on_offset_tf),
            Bonito.DOM.span(Bonito.map(v -> "Truncate Lower: $(map_to_truncate_lower(v))", state.trl_throttled), style=state.label_s),
            slider_row(state.on_truncate_lower, state.on_truncate_lower_tf),
            Bonito.DOM.span(Bonito.map(v -> "Truncate Upper: $(map_to_truncate(v))", state.tr_throttled), style=state.label_s),
            slider_row(state.on_truncate, state.on_truncate_tf),
            style=map(o -> o == "Log Normal" ? "" : "display:none;", state.onset_choice.value)
        )
    )

    # ── Theme toggle ──────────────────────────────────────────
    is_dark_theme    = state.is_dark_theme
    theme_btn_label  = state.theme_btn_label
    theme_toggle_btn = Bonito.Button(theme_btn_label)
    state.theme_toggle_btn = theme_toggle_btn

    on(theme_toggle_btn.value) do _
        is_dark_theme[] = !is_dark_theme[]
        fig         = state.fig;       ax         = state.ax
        onset_fig   = state.onset_plot_fig; onset_ax = state.onset_ax
        brainfig    = state.brain_fig; brainax    = state.brain_ax
        brainfig2   = state.brain_fig2

        if is_dark_theme[]
            theme_btn_label[] = "☀️ Light Mode"
            Bonito.evaljs(session, Bonito.js"""
                document.documentElement.classList.remove('light-mode');
                document.body.style.background = 'var(--bg1)';
                document.body.style.color = 'var(--text1)';
                document.querySelectorAll('[data-onset-wrapper]').forEach(el => {
                    el.style.background = 'var(--bg1)';
                });
            """)
            fig.scene.backgroundcolor[]  = RGBf(0.051,0.071,0.090)
            ax.backgroundcolor[]         = RGBf(0.086,0.106,0.133)
            ax.xgridcolor[]              = RGBAf(1,1,1,0.08);  ax.ygridcolor[] = RGBAf(1,1,1,0.08)
            ax.titlecolor[]              = RGBf(0.9,0.9,0.9);  ax.xlabelcolor[] = RGBf(0.9,0.9,0.9)
            ax.ylabelcolor[]             = RGBf(0.9,0.9,0.9);  ax.xticklabelcolor[] = RGBf(0.9,0.9,0.9)
            ax.yticklabelcolor[]         = RGBf(0.9,0.9,0.9);  ax.xtickcolor[] = RGBAf(1,1,1,0.5)
            ax.ytickcolor[]              = RGBAf(1,1,1,0.5);   ax.bottomspinecolor[] = RGBAf(1,1,1,0.15)
            ax.leftspinecolor[]          = RGBAf(1,1,1,0.15)
            onset_fig.scene.backgroundcolor[] = RGBf(0.067,0.071,0.090)
            onset_ax.backgroundcolor[]        = RGBf(0.055,0.075,0.115)
            onset_ax.titlecolor[]             = RGBf(0.90,0.93,0.98); onset_ax.xlabelcolor[] = RGBf(0.90,0.93,0.98)
            onset_ax.ylabelcolor[]            = RGBf(0.90,0.93,0.98); onset_ax.xticklabelcolor[] = RGBf(0.82,0.86,0.92)
            onset_ax.yticklabelcolor[]        = RGBf(0.82,0.86,0.92); onset_ax.xtickcolor[] = RGBAf(0.82,0.86,0.92,0.7)
            onset_ax.ytickcolor[]             = RGBAf(0.82,0.86,0.92,0.7); onset_ax.xgridcolor[] = RGBAf(0.80,0.85,0.95,0.08)
            onset_ax.ygridcolor[]             = RGBAf(0.80,0.85,0.95,0.08)
            brainfig.scene.backgroundcolor[]  = RGBf(0.086,0.106,0.133)
            brainax.backgroundcolor[]         = RGBf(0.086,0.106,0.133)
            brainfig2.scene.backgroundcolor[] = RGBf(0.086,0.106,0.133)
        else
            theme_btn_label[] = "🌙 Dark Mode"
            Bonito.evaljs(session, Bonito.js"""
                document.documentElement.classList.add('light-mode');
                document.body.style.background = 'var(--bg1)';
                document.body.style.color = 'var(--text1)';
                document.querySelectorAll('[data-onset-wrapper]').forEach(el => {
                    el.style.background = 'var(--bg1)'; el.style.borderColor = 'var(--border)';
                });
            """)
            fig.scene.backgroundcolor[]  = RGBf(1.0,1.0,1.0); ax.backgroundcolor[] = RGBf(1.0,1.0,1.0)
            ax.xgridcolor[]              = RGBAf(0.82,0.84,0.87,0.8); ax.ygridcolor[] = RGBAf(0.82,0.84,0.87,0.8)
            ax.titlecolor[]              = RGBf(0.12,0.14,0.16); ax.xlabelcolor[] = RGBf(0.12,0.14,0.16)
            ax.ylabelcolor[]             = RGBf(0.12,0.14,0.16); ax.xticklabelcolor[] = RGBf(0.12,0.14,0.16)
            ax.yticklabelcolor[]         = RGBf(0.12,0.14,0.16); ax.xtickcolor[] = RGBf(0.12,0.14,0.16)
            ax.ytickcolor[]              = RGBf(0.12,0.14,0.16); ax.bottomspinecolor[] = RGBf(0.82,0.84,0.87)
            ax.leftspinecolor[]          = RGBf(0.82,0.84,0.87)
            onset_fig.scene.backgroundcolor[] = RGBf(1.0,1.0,1.0); onset_ax.backgroundcolor[] = RGBf(1.0,1.0,1.0)
            onset_ax.titlecolor[]             = RGBf(0.12,0.14,0.16); onset_ax.xlabelcolor[] = RGBf(0.12,0.14,0.16)
            onset_ax.ylabelcolor[]            = RGBf(0.12,0.14,0.16); onset_ax.xticklabelcolor[] = RGBf(0.12,0.14,0.16)
            onset_ax.yticklabelcolor[]        = RGBf(0.12,0.14,0.16); onset_ax.xtickcolor[] = RGBf(0.4,0.4,0.4)
            onset_ax.ytickcolor[]             = RGBf(0.4,0.4,0.4); onset_ax.xgridcolor[] = RGBAf(0.82,0.84,0.87,0.8)
            onset_ax.ygridcolor[]             = RGBAf(0.82,0.84,0.87,0.8)
            onset_ax.bottomspinecolor[]       = RGBf(0.82,0.84,0.87); onset_ax.leftspinecolor[] = RGBf(0.82,0.84,0.87)
            brainfig.scene.backgroundcolor[]  = RGBf(0.96,0.97,0.98)
            brainax.backgroundcolor[]         = RGBf(0.96,0.97,0.98)
            brainfig2.scene.backgroundcolor[] = RGBf(0.96,0.97,0.98)
        end
    end

    # ── Global CSS ────────────────────────────────────────────
    global_css = Bonito.DOM.style("""
        .slider-tf-wrap input[type="text"] {
            width:52px !important; min-width:42px; max-width:60px;
            font-size:11px; font-family:monospace; text-align:center;
            padding:2px 4px; border-radius:4px;
            border:1px solid var(--border); background:var(--bg1); color:var(--text1);
        }
        :root {
            --bg1:#0d1117; --bg2:#161b22; --bg3:#21262d;
            --border:#30363d; --text1:#c9d1d9; --text2:#8b949e;
            --accent:#58a6ff; --accent2:#79c0ff;
            --green1:#238636; --green2:#2ea043;
            --scroll-thumb:#30363d; --scroll-hover:#58a6ff;
        }
        :root.light-mode {
            --bg1:#ffffff; --bg2:#f6f8fa; --bg3:#eaeef2;
            --border:#d0d7de; --text1:#1f2328; --text2:#656d76;
            --accent:#0969da; --accent2:#218bff;
            --green1:#1a7f37; --green2:#2da44e;
            --scroll-thumb:#d0d7de; --scroll-hover:#0969da;
        }
        html, body { background: var(--bg1) !important; color: var(--text1) !important; }
        input, textarea {
            background:var(--bg3) !important; color:var(--text1) !important;
            border:1px solid var(--border) !important; border-radius:6px !important;
            padding:5px 9px !important; font-size:12px !important; outline:none !important;
        }
        input[type=range] {
            background:transparent !important; border:none !important;
            -webkit-appearance:none !important; width:100% !important; cursor:pointer !important;
        }
        input[type=range]::-webkit-slider-runnable-track {
            height:4px !important;
            background:linear-gradient(90deg, var(--accent), var(--accent2)) !important;
            border-radius:4px !important;
        }
        input[type=range]::-webkit-slider-thumb {
            -webkit-appearance:none !important; width:14px !important; height:14px !important;
            border-radius:50% !important; background:var(--accent) !important; margin-top:-5px !important;
        }
        select {
            background:var(--bg3) !important; color:var(--text1) !important;
            border:1px solid var(--border) !important; border-radius:6px !important;
            padding:5px 9px !important; font-size:12px !important; width:100% !important;
        }
        button {
            background:linear-gradient(135deg, var(--green1), var(--green2)) !important;
            color:#fff !important; border:none !important; border-radius:6px !important;
            padding:6px 14px !important; font-size:12px !important; font-weight:600 !important;
            cursor:pointer !important;
        }
        button:hover { filter:brightness(1.2) !important; }
        ::-webkit-scrollbar { width:6px; height:6px; }
        ::-webkit-scrollbar-track { background:var(--bg2); }
        ::-webkit-scrollbar-thumb { background:var(--scroll-thumb); border-radius:4px; }
        ::-webkit-scrollbar-thumb:hover { background:var(--scroll-hover); }
        [style*="grid-column: 3"] * { max-width:100% !important; }
        [style*="grid-column: 3"] canvas { max-width:100% !important; height:auto !important; }
    """)

    # ── Floating status pill ──────────────────────────────────
    floating_status = Bonito.DOM.div(
        Bonito.DOM.span(
            map(s -> s == "Running..." ? "⏳ " : (startswith(s,"Error") ? "❌ " : "✅ "), state.status_text),
            style="font-size:11px;"),
        Bonito.DOM.span(state.status_text,
            style=map(s -> begin
                color = s == "Running..." ? "#58a6ff" : startswith(s,"Error") ? "#f78166" : "#3fb950"
                "font-size:12px;font-weight:700;color:$color;"
            end, state.status_text)),
        style="position:fixed;bottom:18px;right:24px;z-index:9999;background:linear-gradient(135deg,var(--bg2),var(--bg3));border:1px solid var(--border);border-radius:20px;padding:7px 16px;box-shadow:0 4px 16px rgba(0,0,0,0.22);display:flex;align-items:center;gap:4px;pointer-events:none;")

    # ── Build sidebar ─────────────────────────────────────────
    onset_card = build_onset_card(
        state.section_title_s, state.card_s, state.onset_choice, state.onset_ui)
    sidebar = build_sidebar(
        theme_toggle_btn, state.section_title_s, state.status_text,
        state.event_definition_ui, state.design_config_ui, state.model_ui,
        onset_card, state.card_s, state.noise_choice, state.noise_throttled,
        state.label_s, state.noise_lvl, state.noise_lvl_tf,
        state.download_button, state.download_sim_button, state.save_jld2_button,
        state.save_jld2_status, state.upload_sim_file_input, state.data_mgmt_status)

    return sidebar, global_css, floating_status
end

function build_sidebar(
    theme_toggle_btn, section_title_s, status_text,
    event_definition_ui, design_config_ui, model_ui,
    onset_card, card_s, noise_choice, noise_throttled,
    label_s, noise_lvl, noise_lvl_tf,
    download_button, download_sim_button, save_jld2_button,
    save_jld2_status, upload_sim_file_input, data_mgmt_status)

    return Bonito.DOM.div(
        Bonito.DOM.div(theme_toggle_btn,
            style="display:flex;justify-content:center;padding:4px 0 10px 0;"),
        Bonito.DOM.div(
            Bonito.DOM.img(src="https://github.com/unfoldtoolbox/UnfoldSim.jl/blob/assets/docs/src/assets/UnfoldSim_features_animation.gif?raw=true",
                style="width:220px;max-width:100%;vertical-align:middle;margin-right:12px;border-radius:8px;background:white;padding:6px;"),
            style="margin-bottom:18px;display:flex;align-items:center;justify-content:center;"),
        Bonito.DOM.div(
            Bonito.DOM.h6("⚡ Status", style=section_title_s),
            Bonito.DOM.div(
                Bonito.DOM.span(status_text, style="font-size:12px;font-weight:700;color:var(--green2);"),
                style="background:var(--bg1);border:1px solid var(--green1);border-radius:6px;padding:6px 10px;margin-bottom:10px;display:inline-block;")),
        Bonito.DOM.div(Bonito.DOM.h4("0. 🧬 Event Definition", style=section_title_s), event_definition_ui, style=card_s),
        Bonito.DOM.div(Bonito.DOM.h4("1. 🔬 Design Configuration", style=section_title_s), design_config_ui, style=card_s),
        Bonito.DOM.div(Bonito.DOM.h4("2. 🧩 Component Configuration", style=section_title_s), model_ui, style=card_s),
        onset_card,
        Bonito.DOM.div(
            Bonito.DOM.h4("4. 🔊 Global Noise", style=section_title_s),
            noise_choice,
            Bonito.DOM.span(Bonito.map(v -> "Noise Level: $(round(map_to_noise(v), digits=2))", noise_throttled), style=label_s),
            slider_row(noise_lvl, noise_lvl_tf),
            style=card_s),
        Bonito.DOM.div(
            Bonito.DOM.h4("5. 💾 Data Management", style=section_title_s),
            Bonito.DOM.div(download_button, style="margin-bottom:10px;"),
            Bonito.DOM.div(download_sim_button, style="margin-bottom:10px;"),
            Bonito.DOM.div(
                Bonito.DOM.h5("💾 Save UnfoldSim Simulation Object",
                    style="font-size:11px;font-weight:700;color:var(--accent2);margin:0 0 5px 0;"),
                save_jld2_button,
                Bonito.DOM.div(
                    Bonito.DOM.span(save_jld2_status, style="font-size:11px;font-weight:700;color:var(--green2);word-wrap:break-word;"),
                    style="padding:6px 10px;background:rgba(63,185,80,0.08);border-radius:6px;border-left:3px solid var(--green2);margin-top:8px;"),
                style="padding:10px;background:var(--bg2);border:1px solid var(--border);border-radius:8px;margin-bottom:10px;"),
            Bonito.DOM.div(
                Bonito.DOM.span("📂 Upload Saved Simulation:", style=label_s),
                upload_sim_file_input, style="margin-bottom:8px;"),
            Bonito.DOM.div(
                Bonito.DOM.span(data_mgmt_status, style="font-size:11px;font-weight:700;color:var(--accent);word-wrap:break-word;"),
                style="padding:8px 10px;background:rgba(88,166,255,0.08);border-radius:6px;border-left:3px solid var(--accent);margin-top:8px;"),
            style=card_s),
        style="grid-column:1;padding:12px 10px;background:linear-gradient(180deg,var(--bg1) 0%,var(--bg2) 100%);border-right:1px solid var(--border);height:100vh;overflow-y:auto;box-sizing:border-box;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',system-ui,sans-serif;")
end

