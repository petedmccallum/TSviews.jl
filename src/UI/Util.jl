function include_df_gaps(df,col)
    df = df[ismissing.(df[:,Symbol(col)]).==false,[:datetime,Symbol(col)]]
    t_vec_append = df.datetime[findall(diff(df.datetime).>Millisecond(60000))].+Minute(1)
    df_append = DataFrame(
        :datetime => t_vec_append,
        Symbol(col) => fill!(Array{Union{Missing,Float64}}(undef,length(t_vec_append)),missing)
    )
    df = sort(vcat(df,df_append),:datetime)
end

function line_trace(df,config,n_plots)
    col = names(df)[2]
    col_alias = config["timeseries"][col]["alias"]
    col_colour = config["timeseries"][col]["colour"]
    subplot_fields = find_subplot_fields.((config,),1:n_plots)
    i_subplot = findfirst(findall_arr2.(subplot_fields,(col,)))
    yaxis = "y$(1+length(subplot_fields)-i_subplot)"
    tr = scatter(
        x=df.datetime,
        y=df[:,2],
        mode="line",
        line=attr(color=col_colour),
        name=col_alias,
        xaxis="x",
        yaxis=yaxis)
end

##

function filltrace(datetime_vec,bool_vec;name::String="",colour::String="#0000ff22",yaxis="y",val=1000.)
    # Find ranges from boolean vector
    i = findall(bool_vec)
    sort!(i)
    i_incremental = findall(diff(i).==1)
    i_new_seq = findall(diff(i_incremental).!=1)

    i_start = vcat(i[1],i[i_incremental[i_new_seq.+1]])
    i_stop = vcat(i[i_incremental[i_new_seq].+1],i[end])
    range_arr(start,stop) = start:stop
    ranges = range_arr.(i_start,i_stop)

    # Trace data
    range_to_filltrace_t(range) = [maximum([1,range[1]-1]);maximum([1,range[1]-1]);range[end];range[end]]
    range_to_filltrace_y(val,i) = [0,val,val,0]

    i_x = vcat(range_to_filltrace_t.(ranges)...)
    y = vcat(range_to_filltrace_y.(val,1:length(ranges))...)

    trace = scatter(
        x=datetime_vec[i_x][:],
        y=y[:],
        mode="lines",
        line=attr(width=0),
        fill="tozeroy",
        fillcolor=colour,
        yaxis=yaxis,
        name=name,
        showlegend=false,
        hoverinfo="skip",hovertemplate=nothing
    )
end
function filltrace_set(project,i_subplot,i_filltrace)
    n_plots = length(keys(project.config["subplots"]))
    subplot_fields = find_subplot_fields.((project.config,),1:n_plots)
    # i_subplot = findfirst(findall_arr2.(subplot_fields,(col,)))
    skipmissing_var(arr) = arr[findall(ismissing.(arr).==false)]
    skipnan(arr) = arr[findall(isnan.(arr).==false)]
    find_subplot_max(project,col) = ceil(1.05*maximum(skipnan(skipmissing_var(project.data[project.current_site][!,col]))))
    find_subplot_maxs(project,cols) = maximum(find_subplot_max.((project,),cols))
    subplot_maxs = find_subplot_maxs.((project,),subplot_fields)

    col = string.(keys(project.config["filltraces"]))[i_filltrace]

    trace = filltrace(
        project.data[project.current_site].datetime,
        project.data[project.current_site][!,col];
        name=project.config["filltraces"][col]["alias"],
        colour=project.config["filltraces"][col]["colour"],
        yaxis="y$(1+length(subplot_fields)-i_subplot)",
        val=subplot_maxs[i_subplot],
    )

    if i_subplot == 1
        restyle!(trace,showlegend=true)
    end

    return trace
end
filltrace_sets(project,i_subplot,i_filltrace) = filltrace_set.((project,),i_subplot,(i_filltrace,))

##

loaddata(project,target_fname) = CSV.read(joinpath(project.paths["raw"],target_fname), DataFrame,normalizenames=true,delim=project.config["raw_schema"]["delim"])
find_time_col(df) = findfirst(occursin.("time",lowercase.(names(df))))
new_DateTime_col(df,i_time_col) = df[!,:datetime]=DateTime.(df[!,i_time_col],"y-m-d H:M:S")
find_unique_cols(cols,i) = setdiff(cols[i],vcat(cols[Not(i)]...))

deletetraces_arr(plt,i) = deletetraces!(plt,i)
addtraces_arr(plt,tr) = addtraces!(plt,tr)
find_subplot_fields(config,i) = config["subplots"]["$i"]["fields"]
find_subplot_yaxis(config,i) = config["subplots"]["$i"]["yaxis"]
findall_arr2(arr,val) = sum(findall(arr.==val))>0

trace_name(tr) = tr["name"]
find_interp(ts,key) = ts[key]["interp_method"]
find_alias(timeseries,ts) = timeseries[ts]["alias"]
find_tracenames(plt_data,i) = plt_data[i]["name"]
find_y_value(plt_data,i_trace,t) = plt_data[i_trace]["y"][plt_data[i_trace]["x"].==t][1]
find_y_value_range(plt_data,i_trace,(t1,t2)) = plt_data[i_trace]["y"][findfirst(plt_data[i_trace]["x"].>=t1):findfirst(plt_data[i_trace]["x"].>=t2)]
