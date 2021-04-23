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


function combine_similar_df(data_arr)
    # Find groups of unique cols across dataframes
    cols_arr = names.(data_arr)
    cols_arr_unq = unique(cols_arr)
    unique_cols_arr = find_unique_cols.((cols_arr_unq,),1:length(cols_arr_unq))
    # Rationalise columns across all dataframes, to datetime and unique cols
    if length(unique_cols_arr)>1
        target_cols = vcat(unique_cols_arr...)
        rationalise_cols(data,cols,target_cols) = data[:,vcat("datetime",intersect(target_cols,cols))]
        data_arr = rationalise_cols.(data_arr,cols_arr,(target_cols,))
    end
    # Merge similar dataframes
    cols_arr_joinstr = join.(cols_arr,",")
    cols_arr_joinstr_unq = unique(cols_arr_joinstr)
    findall_arr(arr,val) = findall(arr.==val)
    i_group = findall_arr.((cols_arr_joinstr,),cols_arr_joinstr_unq)
    vcat_data(data_arr,i) = unique(vcat(tuple(data_arr[i]...)...))
    data_arr = vcat_data.((data_arr,),i_group)
    return data_arr, unique_cols_arr
end
