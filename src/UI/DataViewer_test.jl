
function plot_data(w, project)

    fname_test = readdir(project.paths["raw"])[1]

    if occursin(".txt",fname_test)
        delim = "\t"
    else
        delim = ","
    end

    data_test = CSV.read(
        joinpath(project.paths["raw"],fname_test),
        DataFrame,
        normalizenames=true,
        delim=delim
    )

    time_col = findfirst(occursin.("time",names(data_test)))
    data_test[!,:datetime] = DateTime.(data_test[!,time_col],"y-m-d H:M:S")

    trace = scatter(
        x = data_test.datetime,
        y = data_test[!,5],
    )
    plt = plot(trace);

    body!(w, plt)
end
