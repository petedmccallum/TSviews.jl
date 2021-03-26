function eval_cooling(data_fill,cols)
    i_nonmissing = ismissing.(data_fill[!,cols["temp_col"]]).==false
    df = data_fill[i_nonmissing,[:datetime,Symbol(cols["temp_col"])]]


    # Eval cooling windows
    cooling_ranges = cooling_onoff_segmentation(
        df.datetime,
        df.temperature_deg_c,
        θ_grad_onset=0.05,
    )


    # Map cooling ranges to data_fill dataframe (which includes missing timestamps)
    cooling_ranges_fill = map_data_to_datafill.((df,),(data_fill,),cooling_ranges)
    data_fill[!,Symbol("$(cols["temp_col"])_neg_grad")] = fill!(Array{Bool}(undef,nrow(data_fill)),false)
    data_fill[!,Symbol("$(cols["temp_col"])_neg_grad")][vcat(collect.(cooling_ranges_fill)...)] .= true
    # Include "ac_on" bool in data_fill
    data_fill[!,:ac_on] = fill!(Array{Bool}(undef,nrow(data_fill)),false)
    data_fill[!,:ac_on][vcat(collect.(cooling_ranges_fill)...)] .= true


    # Find standby ranges
    standby_ranges_fill = find_standby_segments(cooling_ranges_fill,nrow(data_fill))
    # Include "ac_standby" bool in data_fill
    data_fill[!,:ac_standby] = fill!(Array{Bool}(undef,nrow(data_fill)),false)
    data_fill.ac_standby[vcat(collect.(standby_ranges_fill)...)] .= true


    # Find gaps longer than 5 minutes
    gap_ranges_fill = find_gaps(df,data_fill;gap_treshold_minutes=5)
    # Include gap bool in data_fill
    data_fill[!,:prolonged_gap] = fill!(Array{Bool}(undef,nrow(data_fill)),false)
    data_fill.prolonged_gap[vcat(collect.(gap_ranges_fill)...)] .= true


    # Impose gaps in cooling/standby segments
    data_fill.ac_on[data_fill.prolonged_gap] .= false
    data_fill.ac_standby[data_fill.prolonged_gap] .= false


    # Check for mischaracterised standby periods (high loads, even where temperature increases)
    standby_ranges_fill = ranges_from_vec(findall(data_fill.ac_standby))
    i_cooling_corr = check_standby_segment.((data_fill[!,cols["power_col"]],),standby_ranges_fill;power_threshold=50)
    standby_ranges_fill = standby_ranges_fill[Not(i_cooling_corr)]
    data_fill.ac_standby[Not(vcat(collect.(standby_ranges_fill)...))] .= false
    data_fill.ac_on[setdiff(findall(data_fill.prolonged_gap.==false),findall(data_fill.ac_standby))] .= true


    # Ground truth against power
    i_nonmissing = findall(ismissing.(data_fill[!,cols["power_col"]]).==false)
    i_stby = i_nonmissing[findall(data_fill[i_nonmissing,cols["power_col"]].<50)]
    i_ac_on = i_nonmissing[findall(data_fill[i_nonmissing,cols["power_col"]].>=50)]
    data_fill.ac_on[i_stby] .= false
    data_fill.ac_on[i_ac_on] .= true
    data_fill.ac_standby[i_stby] .= true
    data_fill.ac_standby[i_ac_on] .= false

    return data_fill, cooling_ranges_fill, standby_ranges_fill
end
