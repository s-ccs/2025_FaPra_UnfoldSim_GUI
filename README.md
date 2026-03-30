# UnfoldSimDashboard

UnfoldSimDashboard is an interactive EEG simulation dashboard built with Julia using Bonito, WGLMakie, and UnfoldSim.

## Quick start

1. Install project packages (run once):

```julia
julia --project=. -e "using Pkg; Pkg.instantiate()"
```

2. Start the dashboard:

```julia
julia --project=. run.jl
```

## What runs when you start

- `run.jl` is the entry point.
- `run.jl` loads `src/app.jl`, which assembles and starts the application.

## Project structure (simple view)

```text
UnfoldSimDashboard/
├── run.jl                 # Start here
├── Project.toml           # Julia dependencies
├── README.md              # Project guide
└── src/
    ├── app.jl             # App setup and startup
    ├── types.jl           # Core data structures
    ├── constants.jl       # Shared constants
    ├── hartmut.jl         # HArtMuT model integration
    ├── erp_analysis.jl    # ERP analysis
    ├── utils.jl           # Utility helpers
    ├── io_system.jl       # Input/output logic
    ├── viz_utils.jl       # Plot and visualization helpers
    ├── ui_components.jl   # Reusable UI widgets
    └── components/        # Modular dashboard components
```

## Notes

- The app is already modularized under `src/components/`.
- You can run everything from the project root with the commands above.
