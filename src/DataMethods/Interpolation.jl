function set_interp_times(df,col)
    # original records (no missings)
    t_nonmissing = df.datetime[ismissing.(df[!,col]).==false]
    # gap lengths
    gap_lengths = diff(t_nonmissing)
    # position of start of each gap
    i_start_gap = findall(gap_lengths.>Minute(5))
    # gaps as ranges (for removal from interpolation time vector)
    range_arr(start,gap,stop) = start:gap:stop
    datetime_gaps = range_arr.(
        ceil.(t_nonmissing[i_start_gap],Dates.Minute),
        Minute(1),
        floor.(t_nonmissing[i_start_gap.+1],Dates.Minute))
    t_gaps = vcat(collect.(datetime_gaps)...)

    t_vec = collect(ceil(
        minimum(df.datetime),Dates.Minute):
        Minute(1):
        floor(maximum(df.datetime),Dates.Minute)
    )

    t_vec = setdiff(t_vec,t_gaps)
    return t_vec
end


function linear_interp(df,col,t_vec)
    # Indices of nonmissing records
    i_nonmissing = ismissing.(df[!,col]).==false

    # Date vectors (irreg & regular) as relative floats
    min_date = Dates.value.(floor.(minimum([t_vec[1],df.datetime[1]]),Dates.Minute))/60000
    t_val_irreg = Dates.value.(df.datetime[i_nonmissing])/60000 .- min_date
    t_val_reg = Dates.value.(t_vec)/60000 .- min_date

    # Interp function
    interp_linear = LinearInterpolation(
        sort(t_val_irreg),
        sort(df[i_nonmissing,col]),
    )

    # Interpolation result
    df_new = DataFrame(
        :datetime => t_vec,
        Symbol(col) => interp_linear(t_val_reg),
    )
    return df_new
end

function interp_col(config,df,t_vec,col)
    if sum(keys(config["timeseries"][col]).=="interp_method")>0
        interp_method = config["timeseries"][col]["interp_method"]
        if occursin.("constant power projected backwards using energy",interp_method)
            col_names = lowercase.(names(df))
            i_col_pwr = findfirst(occursin.("power",col_names))
            i_col_ene = findfirst(occursin.("energy",col_names))
            @assert !isnothing(i_col_pwr) && !isnothing(i_col_ene) "Columns for power and energy required for this interpolation method"
            col_pwr = col_names[i_col_pwr]
            col_ene = col_names[i_col_ene]
            df_new = const_power_from_ene(df,t_vec,col_pwr,col_ene)
        elseif occursin("linear",interp_method)
            df_new = linear_interp(df,col,t_vec)
        end
    end
end

function eval_interpolations(data_arr,unique_cols_arr,config)
    set_interp_times_arr(df,cols) = set_interp_times.((df,),cols)
    t_vecs = set_interp_times_arr.(data_arr,unique_cols_arr)

    interp_cols = string.(keys(config["timeseries"]))
    find_interp_col(interp_cols,unique_col) = sum(interp_cols.==unique_col).>0
    find_interp_cols(interp_cols,unique_cols) = unique_cols[findall(find_interp_col.((interp_cols,),unique_cols))]
    interp_cols = find_interp_cols.((interp_cols,),unique_cols_arr)

    interp_arr(df,t_vec,cols) = interp_col.((config,),(df,),t_vec,cols)
    data_interp = interp_arr.(data_arr,t_vecs,interp_cols)

    data_interp = vcat(data_interp...)

    data_interp = data_interp[isempty.(data_interp).==false]

    # WARNING QUICK FIX
    data_interp = unique(data_interp)

    data_compiled = data_interp[1]

    for i = 2:length(data_interp)
        data_compiled = outerjoin(data_compiled,data_interp[i],on=:datetime)
    end

    sort!(data_compiled,:datetime)

    return data_compiled
end
