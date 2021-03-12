function include_df_gaps(df,col)
    df = df[ismissing.(df[:,Symbol(col)]).==false,[:datetime,Symbol(col)]]
    t_vec_append = df.datetime[findall(diff(df.datetime).>Millisecond(60000))].+Minute(1)
    df_append = DataFrame(
        :datetime => t_vec_append,
        Symbol(col) => fill!(Array{Union{Missing,Float64}}(undef,length(t_vec_append)),missing)
    )
    df = sort(vcat(df,df_append),:datetime)
end

function line_trace(df)
    col = names(df)[2]
    col_alias = config["timeseries"][col]["alias"]
    col_colour = config["timeseries"][col]["colour"]
    tr = scatter(
        x=df.datetime,
        y=df[:,2],
        mode="line",
        line=attr(color=col_colour),
        name=col_alias)
end

deletetraces_arr(plt,i) = deletetraces!(plt,i)
addtraces_arr(plt,tr) = addtraces!(plt,tr)
