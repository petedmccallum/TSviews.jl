"""Determine active cooling segments

Uses temperature and derivatives to determine when cooling is active. A Δt of
10 minutes or better is preferred. This function can be used in conjunction with
`cooling_gap_fill()`.

"""
function cooling_onoff_segmentation(
        time_vec,
        temperature;
        θ_grad_onset::Float64=0.05,
        θ_creep_limit_1::Float64=0.,
        θ_creep_limit_2::Float64=0.11)

    # Dataframe for input data
    data = DataFrame(:t=>time_vec,:θ=>temperature)

    # Find temperature derivative
    derivative(y,t) = diff(y)./(Dates.value.(diff(t))/(1000*60))
    dy_dt = derivative(data.θ,data.t)

    # Find every point with a negative derivative (steeper than -0.5°C/minute)
    i_neg_grad = findall(dy_dt.<=-θ_grad_onset)

    # Find where this downward slope persists over more than 1 timestep
    tmp = findall(diff(i_neg_grad).>1)
    cooling_segment_start = vcat(i_neg_grad[1],i_neg_grad[tmp.+1])


    function find_cooling_off(data,cooling_segment_start,i)
        t = data.t[cooling_segment_start[i]:cooling_segment_start[i+1]]
        y = data.θ[cooling_segment_start[i]:cooling_segment_start[i+1]]
        # Find first consecutive temp rise (intended for <=0.1°C/minute rises)
        i_up = findall(derivative(y,t).>θ_creep_limit_1)
        i_up = isnothing(findfirst(diff(i_up).==1)) ? 1e9 : i_up[findfirst(diff(i_up).==1)]
        # Find first significant temp rise (i.e. >0.1°C/minute rises)
        i_up_sig = findall(derivative(y,t).>θ_creep_limit_2)
        Int(minimum(vcat(length(t),i_up,i_up_sig)))
    end
    cooling_segment_len = find_cooling_off.((data,),(cooling_segment_start,),1:(length(cooling_segment_start)-1))

    # Close last cooling segment at end of timeseries
    cooling_segment_len = vcat(cooling_segment_len,1+nrow(data)-maximum(cooling_segment_start))

    # Set index ranges for cooling segments
    range_arr(start,len) = start.+(0:(len-1))
    cooling_ranges = range_arr.(cooling_segment_start,cooling_segment_len)

    # Join overlapping cooling ranges
    j = sort(unique(vcat(collect.(cooling_ranges)...)))
    k = findall(diff(j).>1)
    range_arr_2(start,stop) = start:stop
    cooling_ranges = range_arr_2.(vcat(j[1],j[k.+1]),vcat(j[k],nrow(data)))

    return cooling_ranges
end



function find_standby_segments(cooling_ranges_fill,L)
    i = setdiff(1:L,vcat(collect.(cooling_ranges_fill)...))
    standby_ranges_fill = ranges_from_vec(i)
    return standby_ranges_fill
end



function find_gaps(data,data_fill;gap_treshold_minutes::Int=5)
    i_gaps = findall(diff(data.datetime).>=Minute(gap_treshold_minutes))
    function date_range_arr(date_vec,date_vec_fill,i_gap)
        start = findfirst(date_vec_fill.==date_vec[i_gap])  .+ 1
        stop = findfirst(date_vec_fill.==date_vec[i_gap+1]) .- 1
        start:stop
    end
    leading_gap = 1:findfirst(data_fill.datetime.==data.datetime[1])-1
    trailing_gap = findfirst(data_fill.datetime.==data.datetime[end])+1:nrow(data_fill)
    gap_ranges_fill = vcat(
        [leading_gap],
        date_range_arr.((data.datetime,),(data_fill.datetime,),i_gaps),
        [trailing_gap]
    )
end



function check_standby_segment(ac_power_vec,standby_range_fill;power_threshold=400)
    standby = ac_power_vec[standby_range_fill]
    i_nonmissing = ismissing.(standby).==false
    sum(standby[i_nonmissing].>power_threshold) > (standby_range_fill[end]-standby_range_fill[1])/2
end
