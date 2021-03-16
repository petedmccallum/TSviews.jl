function include_missing_timestamps(data)
    # Full time vector
    date_vec = Date.(data.datetime)
    dt_vec = (DateTime(minimum(date_vec)):Minute(1):DateTime(maximum(date_vec)+Day(1)))[1:end-1]
    missing_timestamps = setdiff(dt_vec,data.datetime)

    # Create dataframe of missings
    df_append = DataFrame(datetime=missing_timestamps)
    [df_append[!,col]=fill!(Array{Union{Missing,Float64}}(undef,nrow(df_append)),missing) for col in names(data)[2:end]]

    # merge dataframes
    data = vcat(data,df_append)
    # sort
    sort!(data)
end
