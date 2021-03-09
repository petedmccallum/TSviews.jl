function import_raw(project,i_site=1)

    # Load config file (for raw schema)
    fname = project.paths["shared_config"]
    f = open(fname) do file
        read(file,String)
    end
    config = JSON.parse(f)


    # All filenames in raw folder
    raw_fnames = readdir(project.paths["raw"])


    # Load data for site 1 (all relevant files based on config)
    sites = String.(keys(config["sites"]))
    site = sites[i_site]
    target_fnames = config["sites"][site]
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


    # find all recorded timestamps (may be irregular, not nearest minute)
    datetime_vec = sort(unique(vcat(
        data_arr[1].datetime,
        data_arr[2].datetime,
    )))
    # Append interpolated spaces
    datetime_vec_interp = ceil(minimum(datetime_vec),Dates.Minute):Minute(1):floor(maximum(datetime_vec),Dates.Minute)
    datetime_vec = sort(unique(vcat(datetime_vec,datetime_vec_interp)))
    # Create new blank dataframe
    data_fill = DataFrame(:datetime=>datetime_vec)
    fill_missing_df_col(df,col) = df[!,col] = fill!(Array{Union{Missing,Float64}}(undef,nrow(df)),missing)
    cols = vcat(unique_cols_arr...)
    fill_missing_df_col.((data_fill,),cols)


    # Map data records to blank dataframe
    findall_arr(arr,val) = findall(arr.==val)
    find_i_maps(data_fill,df) = vcat(findall_arr.((data_fill.datetime,),df.datetime)...)
    i_maps = find_i_maps.((data_fill,),data_arr)
    fill_df_by_index(data_fill,df,i_map,uniq_cols) = data_fill[i_map,uniq_cols].=df[!,uniq_cols]
    fill_df_by_index.((data_fill,),data_arr,i_maps,unique_cols_arr)

    project.data[site] = data_fill

    CSV.write(joinpath(
        project.paths["compiled"],
        "$(site).csv"
    ),data_fill)

    return project
end
