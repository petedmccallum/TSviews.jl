module TSviews


using Blink, Interact, PlotlyJS, JSON, CSV, DataFrames, Dates, Interpolations


include("Init\\Init_project.jl")
include("UI\\Launch.jl")
include("UI\\DataViewer.jl")
include("UI\\Util.jl")
include("DataMethods\\Data_import.jl")
include("DataMethods\\Interpolation.jl")
include("DataMethods\\Util.jl")
include("ECHOsched\\Interpolations\\Power_from_energy.jl")
include("ECHOsched\\cooling\\Cooling_segments.jl")
include("ECHOsched\\cooling\\Eval_cooling.jl")
include("ECHOsched\\cooling\\Util.jl")


function __init__()

    select_project()
    

end

end
