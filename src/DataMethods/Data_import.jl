function import_data(project;i_site=1)

    # Load config file (for raw schema)
    fname = project.paths["shared_config"]
    f = open(fname) do file
        read(file,String)
    end
    config = JSON.parse(f)

    project.sites = String.(keys(config["sites"]))
    project.current_site = project.sites[i_site]

    dir = readdir(project.paths["compiled"])
    if sum(occursin.(project.current_site,dir))>0
        project.data[project.current_site] = CSV.read(joinpath(
            project.paths["compiled"],
            "$(project.current_site).csv"),
            DataFrame,normalizenames=true
        )
    else
        project = import_raw(project,config)
    end
    return project
end

function import_raw(project,config)

    # All filenames in raw folder
    raw_fnames = readdir(project.paths["raw"])


    # Load data for selected site (all relevant files based on config)
    target_fnames = config["sites"][project.current_site]
    loaddata(target_fname) = CSV.read(joinpath(project.paths["raw"],target_fname), DataFrame,normalizenames=true,delim=config["raw_schema"]["delim"])
    data_arr = loaddata.(target_fnames)


    # Find time column and convert to datetime (all data files for current site)
    find_time_col(df) = findfirst(occursin.("time",lowercase.(names(df))))
    i_time_cols = find_time_col.(data_arr)
    new_DateTime_col(df,i_time_col) = df[!,:datetime]=DateTime.(df[!,i_time_col],"y-m-d H:M:S")
    new_DateTime_col.(data_arr,i_time_cols)


    # Identify column names unique to each data file
    cols_arr = names.(data_arr)
    find_unique_cols(cols,i) = setdiff(cols[i],vcat(cols[Not(i)]...))
    unique_cols_arr = find_unique_cols.((cols_arr,),1:length(cols_arr))

    # Interpolations
    data_fill = eval_interpolations(data_arr,unique_cols_arr,config)

    project.data[project.current_site] = data_fill

    CSV.write(joinpath(
        project.paths["compiled"],
        "$(project.current_site).csv"
    ),data_fill)

    return project
end
