
map_data_to_datafill(data,data_fill,range) = findfirst(data_fill.datetime.==data.datetime[range[1]]):findfirst(data_fill.datetime.==data.datetime[range[end]])

function ranges_from_vec(i)
    sort!(i)
    i_incremental = findall(diff(i).==1)
    i_new_seq = findall(diff(i_incremental).!=1)

    i_start = vcat(i[1],i[i_incremental[i_new_seq.+1]])
    i_stop = vcat(i[i_incremental[i_new_seq].+1],i[end])
    range_arr(start,stop) = start:stop
    ranges = range_arr.(i_start,i_stop)
end
