# ============================================================================
# UNFOLDSIM GUI WITH CUSTOM EVENT VARIABLES + DOWNLOAD/UPLOAD
# ============================================================================
import Logging
Logging.disable_logging(Logging.Info)
Logging.disable_logging(Logging.Warn)

using Bonito
using WGLMakie
using UnfoldSim
using DataFrames
using Distributions
using Random
using Statistics
using Observables
using StatsModels
using ColorSchemes
using Colors
using JSON3
using Dates
using CSV
using JLD2
using TopoPlots
using UnfoldMakie

include("constants.jl")
include("erp_analysis.jl")
using .ERPExplorer
include("hartmut.jl")
include("utils.jl")
include("viz_utils.jl")
include("types.jl")
include("io_system.jl")
include("ui_components.jl")

include("components/event_manager.jl")
include("components/tab_manager.jl")
include("components/sidebar.jl")
include("components/simulation_engine.jl")
include("components/main_plot.jl")
include("components/onset_plot.jl")
include("components/topoplot.jl")
include("components/app_session.jl")

app