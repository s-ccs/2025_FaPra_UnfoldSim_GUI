# UnfoldSimDashboard

Interactive EEG/ERP simulation dashboard built in Julia on top of **UnfoldSim.jl**, with a reactive web UI powered by **Bonito.jl** and **WGLMakie.jl**.

This project was developed in the context of the University of Stuttgart Fachpraktikum to make simulation-driven EEG experimentation easier for Researchers and First-time users

---

## 1) What this project is

UnfoldSimDashboard is a browser-based GUI that lets you configure and run EEG simulations without writing scripts.

It covers the full simulation pipeline:

- **Event definition** (categorical + continuous variables)
- **Design selection** (single-subject, repeat, multi-subject)
- **Component modeling** (Linear, Mixed, Multi-channel)
- **Onset distribution** (No Onset, Uniform, Log Normal)
- **Noise injection** (No Noise, White, Pink, Red)
- **Interactive visualization** (main waveform, onset density, ERP/topoplot panel)
- **Data export/import** (JSON/CSV/JLD2)

---

## 2) Main features

### 2.1 Reactive simulation workflow

- UI changes trigger simulation updates through Observables.
- Debounce/throttle is built in to keep interactions smooth during slider moves.

### 2.2 Multiple model categories

- **Linear Model**
- **Mixed Model** (requires multi-subject design)
- **Multi-channel Model** (includes channel-level and topoplot exploration)

### 2.3 Event variable system

- Add categorical templates (e.g., condition, task, emotion)
- Add continuous templates (e.g., intensity, duration)
- Define custom variables directly from the sidebar

### 2.4 Hanning component tabs and overlays

- Add/remove preset components: `N170`, `N400`, `P100`, `P300`, `Custom`
- Each tab has its own model controls and contributes to cumulative plotting

### 2.5 ERP Explorer and topoplots

- Uses HArtMuT electrode geometry
- Includes channel scatter view + amplitude heatmap
- Supports channel click selection and hover labels

### 2.6 Data management

- Download configuration JSON from the GUI
- Export simulation CSV files
- Save full simulation objects as `.jld2`
- Upload saved CSV to restore GUI parameters (metadata-based)

---

## 3) Tech stack and dependencies

Core dependencies from `Project.toml`:

- `Bonito`, `WGLMakie`, `UnfoldSim`
- `DataFrames`, `StatsModels`, `Distributions`, `Observables`
- `TopoPlots`, `UnfoldMakie`, `ColorSchemes`, `Colors`
- `CSV`, `JSON3`, `JLD2`

Compatibility:

- Julia `1.10`

---

## 4) First-time setup (new user)

### 4.1 Prerequisites

Before running this repo for the first time, make sure:

1. Julia 1.10 is installed and available in terminal.
2. You run commands from the project root (where `Project.toml` is located).
3. You have internet access for first-time package installation.

### 4.2 Clone and enter the project

```bash
git clone https://github.com/s-ccs/2025_FaPra_UnfoldSim_GUI.git
cd 2025_FaPra_UnfoldSim_GUI
```

### 4.3 Install dependencies (one-time)

```julia
julia --project=. -e "using Pkg; Pkg.instantiate()"
```

If packages are already present, this is fast and safe to rerun.

### 4.4 Start the dashboard

```julia
julia --project=. run.jl
```

`run.jl` includes `src/app.jl`, which builds the full Bonito app and serves the GUI.

### 4.5 Open the app

- In most setups, a local browser session opens automatically.
- If not, open the local URL printed in the Julia terminal output.

---

## 5) How to use the app (recommended order)

The sidebar is organized into numbered sections:

1. **Event Definition**
    - Add categorical/continuous variables from templates or custom inputs.

2. **Design Configuration**
    - Choose single-subject, repeat, or multi-subject design.
    - Mixed model enforces compatible design.

3. **Component Configuration**
    - Create/select component tabs and Hanning presets.
    - Configure formula, basis, contrast coding, beta/sigma/projection controls.

4. **Onset Configuration**
    - Pick `No Onset`, `Uniform`, or `Log Normal` and tune parameters.

5. **Global Noise**
    - Set noise type and level.

6. **Data Management**
    - Download config JSON
    - Download simulation CSV files
    - Save `.jld2` simulation object
    - Upload a saved simulation CSV to restore settings

As you interact with controls, the center and right panels update reactively.

---

## 6) Outputs and saved files

Depending on the action in section 5 of the sidebar:

- **Configuration download**: browser download of JSON settings
- **Simulation export**:
  - `simulation_data.csv`
  - `simulation_events.csv` (contains metadata for restoring sliders/settings)
- **JLD2 save**:
  - `unfoldsim_YYYY-MM-DD_HH-MM-SS.jld2`

Files are saved relative to the current working directory (usually project root if launched there).

---

## 7) Detailed architecture

### 7.1 Runtime entry flow

- `run.jl` → includes `src/app.jl`
- `src/app.jl`:
  - loads all modules/files,
  - creates UI widgets + `AppState`,
  - initializes plots/components,
  - wires reactivity and handlers,
  - returns the final Bonito app layout.

### 7.2 State model

`AppState` (in `src/types.jl`) is the central state container. It holds:

- controls and synced text fields,
- active model/tab values,
- throttled observables and simulation trigger,
- simulation results and status,
- plot handles/observables,
- data-management controls,
- theme state.

### 7.3 Simulation cycle

Core simulation logic is in `src/components/simulation_engine.jl`:

1. wait on `sim_trigger` (debounced)
2. validate model/design compatibility
3. map GUI slider values to model parameters
4. build design + component(s)
5. run `simulate(...)` for noisy and clean signals
6. update current tab result and cumulative store
7. refresh tables/plots/status and cache simulation object

---

## 8) Full project structure (expanded)

```text
UnfoldSimDashboard/
├── run.jl                         # Entry point; includes src/app.jl
├── Project.toml                   # Package dependencies and Julia compat
├── README.md                      # Documentation
├── report.txt                     # Project report and background details
└── src/
     ├── app.jl                     # Main app assembly and initialization order
     ├── constants.jl               # Throttle/debounce constants, templates, defaults
     ├── types.jl                   # AppState and ComponentTab data structures
     ├── hartmut.jl                 # HArtMuT caching + electrode position projection
     ├── erp_analysis.jl            # ERPExplorer module (RMS/peak/mean utilities)
     ├── utils.jl                   # Slider mappings, formula term counting, design builder
     ├── viz_utils.jl               # Head outline + topoplot helper logic
     ├── ui_components.jl           # Synced text fields, slider rows, event table DOM builder
     ├── io_system.jl               # CSV/JSON save helpers for simulation export
     └── components/
          ├── app_session.jl         # Creates Bonito.App session and global state
          ├── event_manager.jl        # Event variable controls and handlers
          ├── tab_manager.jl          # Component tabs, formulas, Hanning overlay controls
          ├── simulation_engine.jl    # Core simulation trigger, execution, IO handlers
          ├── main_plot.jl            # Cumulative plot, tab overlays, channel lines, legend
          ├── onset_plot.jl           # Onset distribution plot + histogram/PDF rendering
          ├── topoplot.jl             # ERP explorer panel, electrode interaction, heatmap
          └── sidebar.jl              # Sidebar sections, theme toggle, global CSS
```

---

## 9) What first-time contributors should know

1. **Initialization order matters** in `src/components/app_session.jl`:
    - plots/components are initialized in a specific sequence before full DOM assembly.

2. **Most UI behavior is reactive**:
    - prefer updating `Observable`s/state over imperative DOM mutations.

3. **Model/design constraints are intentional**:
    - mixed model with incompatible design is blocked by validation logic.

4. **State restoration relies on metadata**:
    - upload flow expects metadata embedded in exported events CSV.

5. **Theme support touches JS + Makie objects**:
    - changes may require updates in both CSS variables and plot color updates.

---

## 10) Troubleshooting

### Packages fail to resolve

Run:

```julia
julia --project=. -e "using Pkg; Pkg.instantiate(); Pkg.precompile()"
```

### App does not open in browser

- Check terminal output for the local URL and open it manually.
- Ensure no firewall/network rule blocks local loopback browser access.

### Empty or error simulation results

- Verify model/design combination is valid.
- Start with default settings, then change one section at a time.
- Watch status text in the app (`Running`, `Done`, or error messages).

### Upload restore does not apply settings

- Use a `simulation_events.csv` exported from this dashboard.
- Confirm the file contains metadata column with serialized config.

---

## 11) Notes

- This repository is focused on GUI-driven EEG simulation and exploration.
- The implementation is modular: component files in `src/components/` are actively used by `src/app.jl`.
- For feature-level background and project rationale, see `report.txt`.
