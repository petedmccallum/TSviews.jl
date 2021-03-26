function import_data(project;i_site=1)


    project.sites = sort(String.(keys(project.config["sites"])))
    project.current_site = project.sites[i_site]

    dir = readdir(project.paths["compiled"])
    if sum(occursin.(project.current_site,dir))>0
        project.data[project.current_site] = CSV.read(joinpath(
            project.paths["compiled"],
            "$(project.current_site).csv"),
            DataFrame,normalizenames=true
        )
    else
        project = import_raw(project)
    end
    return project
end

function import_raw(project)

    # All filenames in raw folder
    raw_fnames = readdir(project.paths["raw"])


    # Load data for selected site (all relevant files based on config)
    target_fnames = project.config["sites"][project.current_site]
    data_arr = loaddata.((project,),target_fnames)

    # Remove empty dataframes
    data_arr = data_arr[isempty.(data_arr).==false]

    # Find time column and convert to datetime (all data files for current site)
    i_time_cols = find_time_col.(data_arr)
    new_DateTime_col.(data_arr,i_time_cols)


    # Identify column names unique to each data file
    cols_arr = names.(data_arr)

    # Combine similar dataframes (with same column headings)
    (data_arr, unique_cols_arr) = combine_similar_df(data_arr)

    # Interpolations
    data_interp = eval_interpolations(data_arr,unique_cols_arr,project.config)

    # Include all missing timestamps (with missings)
    data_fill = include_missing_timestamps(data_interp)


    # Eval cooling cycles (if specified in config)
    if sum(keys(project.config).=="status_eval")>0 && sum(keys(project.config["status_eval"]).=="ac")>0
        cols = project.config["status_eval"]["ac"]
        (data_fill, cooling_ranges_fill, standby_ranges_fill) = ECHOsched.eval_cooling(data_fill,cols)
    end


    project.data[project.current_site] = data_fill

    CSV.write(joinpath(
        project.paths["compiled"],
        "$(project.current_site).csv"
    ),data_fill)

    return project
end
