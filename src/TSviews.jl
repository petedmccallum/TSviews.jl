module TSviews


using Blink, Interact, PlotlyJS, JSON, CSV, DataFrames, Dates, Interpolations


include("Init\\Init_project.jl")
include("UI\\Launch.jl")
include("UI\\DataViewer.jl")
include("DataMethods\\Data_import.jl")
include("DataMethods\\Interpolation.jl")


function __init__()

    ui_launch()


end

end
