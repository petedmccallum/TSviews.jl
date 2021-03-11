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
    interp_linear = LinearInterpolation(t_val_irreg, df[i_nonmissing,col])

    # Interpolation result
    df_new = DataFrame(
        :datetime => t_vec,
        Symbol(col) => interp_linear(t_val_reg),
    )
    return df_new
end


function const_power_from_ene(df,col,t_vec)
    # Indices of nonmissing records
    i_nonmissing = ismissing.(df[!,col]).==false
    df = df[i_nonmissing,:]

    t_diff_minutes = Dates.value.(diff(df.datetime))/60000
    power_from_ene = (df.energy[2:end] ./ t_diff_minutes)/60

    interp_step = (df.power[2:end] .- power_from_ene) ./ diff(df.power)
    unity_range(val) = minimum([maximum([val,0]),1])
    interp_step = unity_range.(interp_step)
    interp_step = abs.(interp_step.-1)

    df_new = DataFrame(
        :datetime => t_vec,
        Symbol(col) => step_interp.((df,),(interp_step,),(col,),t_vec),
    )
    return df_new
end
function step_interp(df,interp_step,col,t)
    datetime_floor = floor.(df.datetime,Dates.Minute)
    i_next_val = findfirst(df.datetime.-t .> Millisecond(0))
    i_prev_val = i_next_val .- 1
    step_time = Dates.value(df.datetime[i_next_val]-df.datetime[i_prev_val]) * interp_step[i_prev_val]
    interp_time = Dates.value(t-df.datetime[i_prev_val])
    if interp_time < step_time
        y_iterp = df[i_prev_val,col]
    else
        y_iterp = df[i_next_val,col]
    end
    return y_iterp
end

function interp_col(config,df,t_vec,target_cols,col)
    i_interp_method = findfirst(occursin.(col,target_cols))

    if !isnothing(i_interp_method)
        interp_method = config["interpolations"][target_cols[i_interp_method]]
        if occursin.("constant power projected backwards using energy",interp_method)
            df_new = const_power_from_ene(df,col,t_vec)
        elseif interp_method == "linear"
            df_new = linear_interp(df,col,t_vec)
        end
    else
        df_new = DataFrame()
    end
end

function eval_interpolations(data_arr,unique_cols_arr,config)
    set_interp_times_arr(df,cols) = set_interp_times.((df,),cols)
    t_vecs = set_interp_times_arr.(data_arr,unique_cols_arr)

    target_cols = string.(keys(config["interpolations"]))

    interp_arr(df,t_vec,target_cols,cols) = interp_col.((config,),(df,),t_vec,(target_cols,),cols)
    data_interp = interp_arr.(data_arr,t_vecs,(target_cols,),unique_cols_arr)

    data_interp = vcat(data_interp...)

    data_interp = data_interp[isempty.(data_interp).==false]

    data_compiled = data_interp[1]

    for i = 2:length(data_interp)
        data_compiled = outerjoin(data_compiled,data_interp[i],on=:datetime)
    end

    sort!(data_compiled,:datetime)

    return data_compiled
end
