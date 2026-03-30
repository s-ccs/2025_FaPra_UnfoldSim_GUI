# UnfoldSimDashboard

Interactive EEG simulation dashboard based on Bonito + WGLMakie + UnfoldSim.

## Entry point
Run:

```julia
julia --project=. run.jl
```

If packages are not installed yet, run once before starting:

```julia
julia --project=. -e "using Pkg; Pkg.instantiate()"
```

## Project structure

```text
UnfoldSimDashboard/
├── run.jl                 # Entry point - run this
├── Project.toml           # Dependencies
├── README.md              # This file
└── src/
    ├── app.jl             # Application assembly (full existing app)
    ├── types.jl           # Data structures
    ├── constants.jl       # Global constants
    ├── hartmut.jl         # HArtMuT model integration
    ├── erp_analysis.jl    # ERP metrics and analysis
    ├── utils.jl           # Helper functions
    ├── io_system.jl       # File I/O operations
    ├── viz_utils.jl       # Visualization utilities
    ├── ui_components.jl   # Reusable UI widgets
    └── components/
        ├── app_session.jl
        ├── event_manager.jl
        ├── tab_manager.jl
        ├── simulation_engine.jl
        ├── main_plot.jl
        ├── onset_plot.jl
        ├── topoplot.jl
        └── sidebar.jl
```

    ## Notes

    - `run.jl` includes `src/app.jl` as the main startup path.
    - The app is already modularized under `src/components/` and these files are actively used.
