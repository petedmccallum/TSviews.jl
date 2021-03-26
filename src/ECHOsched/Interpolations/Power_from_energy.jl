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
