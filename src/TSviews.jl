module TSviews


using Blink, Interact, PlotlyJS, JSON, CSV, DataFrames, Dates


include("Init\\Init_project.jl")
include("UI\\Launch.jl")
include("UI\\DataViewer.jl")
include("DataMethods\\Raw_import.jl")


function __init__()

    ui_launch()


end

end
