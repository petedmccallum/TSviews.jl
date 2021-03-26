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

#=
function const_power_from_ene(df,t_vec,col_pwr,col_ene)
    # Indices of nonmissing records
    i_nonmissing = ismissing.(df[!,col_pwr]).==false
    e = df[i_nonmissing,col_ene]
    p = df[i_nonmissing,col_pwr]
    t_orig = df.datetime[i_nonmissing]

    # Find average power from energy over timestep
    t_diff_minutes = Dates.value.(diff(t_orig))/60000
    power_from_ene = (e[2:end] ./ t_diff_minutes)/60

    # Find interpolation ratio
    interp_numer = (df[2:end,col_pwr] .- power_from_ene)
    interp_denom = diff(p)
    i_denom_0 = findall(interp_denom.==0)
    interp_step = interp_numer ./ interp_denom

    # Case 1: power record is constant (denom=0) AND change in energy derived power is small (<3 Watts)
    i_constant_p = findall(abs.(interp_numer[i_denom_0]) .<= 3) # Watts (i.e. small devitions from constant power)
    i_unknown_p = i_denom_0[Not(i_constant_p)]
    i_constant_p = i_denom_0[i_constant_p]

    #
    range_arr(t_vec,t_orig,i) = findfirst(t_vec.>=t_orig[i-1]):findlast(t_vec.<=t_orig[i])
    @time i_fill_rngs = range_arr.((t_vec,),(t_orig,),2:length(t_orig))

    y_vec = fill!(Array{Union{Missing,Float64}}(undef,length(t_vec)),missing)

    repeat_arr(val,reps) = repeat([val],reps)
    @time reps = length.(i_fill_rngs)

    # Case 1: power record is constant (denom=0) AND change in energy derived power is small (<3 Watts)
    i_constant_p = findall(abs.(interp_numer[i_denom_0]) .<= 3) # Watts (i.e. small devitions from constant power)
    i_unknown_p = i_denom_0[Not(i_constant_p)]
    i_constant_p = i_denom_0[i_constant_p]
    p_fill = vcat(repeat_arr.(power_from_ene[i_constant_p],reps[i_constant_p])...)
    i_fill = vcat(collect.(i_fill_rngs[i_constant_p])...)
    y_vec[i_fill].= p_fill
    # Case 2: power record is constant (denom=0) AND change in energy derived power is not negligible (>3 Watts)
    # (no action rqd - retatin missings at `i_unknown_p`)
    # Case 3: power record varies (denom>0) AND change in energy derived power is less than power differential (inner interpolation)
    i_interp = Not(i_denom_0)
    p_fill = vcat(repeat_arr.(power_from_ene[i_interp],reps[i_interp])...)
    i_fill = vcat(collect.(i_fill_rngs[i_interp])...)
    y_vec[i_fill].= p_fill

    df_new = DataFrame(
        :datetime => t_vec,
        Symbol(col_pwr) => y_vec,
    )
    return df_new
end
=#

function const_power_from_ene(df,t_vec,col_pwr,col_ene)
    # Indices of nonmissing records
    i_nonmissing = ismissing.(df[!,col_pwr]).==false
    df = df[i_nonmissing,:]

    # Find average power from energy over timestep (L = N_timestep-1)
    t_diff_minutes = Dates.value.(diff(df.datetime))/60000
    power_from_ene = (df[2:end,col_ene] ./ t_diff_minutes)/60

    # Find interpolation ratio
    interp_numer = (df[2:end,col_pwr] .- power_from_ene)
    interp_denom = diff(df[:,col_pwr])
    i_case2 = findall(interp_denom.==0)
    i_case_1_3 = findall(interp_denom.!=0)
    interp_ratio = interp_numer ./ interp_denom

    # Identify cases
    # Case 2: power record is constant (denom=0) AND change in energy derived power is small (<5 Watts)
    P_small = 5 # Watts
    i_case2a = findall(abs.(interp_numer[i_case2]) .<= P_small) # Watts (i.e. small devitions from constant power)
    i_case2b = i_case2[Not(i_case2a)]
    i_case2a = i_case2[i_case2a]
    # Cases 1&3
    i_case1 = findall(abs.(interp_ratio).<=1.)
    i_case3 = setdiff(i_case_1_3,i_case1)
    i_case3ac = intersect(i_case3,findall(interp_numer.>=0))
    i_case3bd = setdiff(i_case3,i_case3ac)

    function case_step_in_interval(df,t_diff_minutes,interp_ratio,i)
        # Take all original power records as timestep bookends
        t_starts = df.datetime[i] .+ Millisecond(1)
        t_ends = df.datetime[i.+ 1]
        p_starts = df.power[i]
        p_ends = df.power[i.+ 1]

        t′ = Millisecond.(round.(60000*t_diff_minutes[i] .* abs.(interp_ratio[i])))
        t_step = df.datetime[i.+1] .- t′

        df_case = DataFrame(
            :datetime => [t_starts;t_step;t_step .+ Millisecond(1);t_ends],
            :power => [p_starts;p_starts;p_ends;p_ends]
        )
        df_case = sort(unique(df_case))
    end

    function case_mean_pwr_from_ene(df,i)
        t_starts = df.datetime[i] .+ Millisecond(1)
        t_ends = df.datetime[i .+ 1]
        p_starts = power_from_ene[i]
        p_ends = p_starts

        df_case = DataFrame(
            :datetime => [t_starts;t_ends],
            :power => [p_starts;p_ends]
        )
        df_case = sort(unique(df_case))
    end
    function case_pwr_from_tplus1(df,i)
        t_starts = df.datetime[i] .+ Millisecond(1)
        t_ends = df.datetime[i .+ 1]
        p_starts = df.power[i .+ 1]
        p_ends = p_starts

        df_case = DataFrame(
            :datetime => [t_starts;t_ends],
            :power => [p_starts;p_ends]
        )
        df_case = sort(unique(df_case))
    end

    function case_missings(df,i;t_offset_ms=0)
        t_starts = df.datetime[i] .+ Millisecond(1) .+ Millisecond(t_offset_ms)
        t_ends = df.datetime[i .+ 1] .- Millisecond(t_offset_ms)
        T = typeof(df.power[1])
        p_vec = fill!(Array{Union{Missing,T}}(undef,2*length(i)),missing)

        df_case = DataFrame(
            :datetime => [t_starts;t_ends],
            :power => p_vec
        )
        df_case = sort(unique(df_case))
    end

    Δt_cutoff = 5 # minutes
    i_case4 = findall(t_diff_minutes .> Δt_cutoff)

    df_case_1 = case_step_in_interval(df,t_diff_minutes,interp_ratio,i_case1)
    df_case_2a_3ac = case_pwr_from_tplus1(df,vcat(i_case2a,i_case3ac))
    df_case_2b_3bc = case_missings(df,vcat(i_case2b,i_case3bd))
    df_case_4 = case_missings(df,i_case4;t_offset_ms=1)

    df_steps1 = sort(unique(vcat(df_case_1,df_case_2a_3ac,df_case_2b_3bc,df_case_4)))
    df_steps = sort(unique(vcat(df_case_1,df_case_2a_3ac)))

    # Define full time vector
    t_vec = collect(ceil(minimum(df_steps.datetime),Minute(1)):Minute(1):floor(maximum(df_steps.datetime),Minute(1)))
    # t_vec = collect(minimum(df.datetime):Minute(1):maximum(df.datetime))
    df_interp = linear_interp(df_steps,"power",t_vec)

    # Find full vector timestamps for all missings
    interval_ts(t1,t2) = ceil(t1,Minute(1)):Minute(1):floor(t2,Minute(1))
    t_missings_case2b = vcat(interval_ts.(df.datetime[i_case2b],df.datetime[i_case2b.+1])...)
    t_missings_case3bd = vcat(interval_ts.(df.datetime[i_case3bd],df.datetime[i_case3bd.+1])...)
    t_missings_case4 = vcat(interval_ts.(df.datetime[i_case4],df.datetime[i_case4.+1])...)
    t_missings = sort(unique(vcat(t_missings_case2b,t_missings_case3bd,t_missings_case4)))
    t_missings = intersect(t_missings,t_vec)

    findfirst_arr(arr,val) = findfirst(arr.==val)
    i_missings = findfirst_arr.((t_vec,),t_missings)
    df_interp.power[i_missings] .= NaN
    return df_interp
end

#=
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
=#

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
