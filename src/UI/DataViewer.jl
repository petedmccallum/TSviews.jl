function data_viewer(w,project)
        ## Time window
    nDays = 1
    i_lastday = findlast(Time.(project.data[project.current_site].datetime).==Time(0))
    t_start = project.data[project.current_site].datetime[i_lastday] - Day(nDays)
    t_end = project.data[project.current_site].datetime[i_lastday]

    marker_trace(df,col) = scatter(x=df.datetime,y=df[:,col],mode="markers",name=col)
    line_trace(df,col) = scatter(x=df.datetime,y=df[:,col],mode="line",name=col)
    cols = names(project.data[project.current_site])[2:end]
    # tr_records = marker_trace.((project.data[project.current_site],),cols)
    tr_records = line_trace.((project.data[project.current_site],),cols)
    layout = Layout(Dict(
        "height"=>800,
        "width"=>1800,
        "legend_orientation"=>"h",
        "legend_x"=>0.,
        "legend_y"=>1.05))
    global plt = plot(tr_records,layout);



    ## GENERATE WIDGETS
    widget_sites = togglebuttons(project.sites)
    widget_startDate = datepicker(t_start)
    widget_numDays = spinbox(1:365,value=1)

    ## FORMAT WIDGETS
    widget_sites.scope.dom.props[:style] = Dict("height"=>16px,"fontsize"=>10px);
    widget_startDate.scope.dom.props[:style] = Dict("height"=>36px);
    widget_numDays.scope.dom.props[:style] = Dict("height"=>36px);


    div_sitepicker = hbox(
        hskip(5mm),
        HTML(string("<div style='font-size:20px'>Site:</div>")),
        hskip(5mm),
        vbox(vskip(3mm),widget_sites),
    )
    ## GENERATE UI
    body!(w,vbox(
        vskip(8mm),
        div_sitepicker,
        vskip(8mm),
        Interact.hline(),
        vskip(8mm),
        hbox(
            hbox(hskip(5mm),HTML(string("<div style='font-size:20px'>Start date:</div>")),hskip(5mm),widget_startDate),
            hbox(hskip(5mm),HTML(string("<div style='font-size:20px'>Num. days:</div>")),hskip(5mm),widget_numDays),
        ),
        plt,
        )
    )

    widget_sites_prev=widget_sites[]
    @manipulate for
        widget_sites_ in widget_sites,
        widget_startDate_ in widget_startDate,
        widget_numDays_ in widget_numDays,
        widget_sites_prev_ in widget_sites_prev

        relayout!(plt,xaxis_range=widget_startDate[] .+ Day.([0,widget_numDays[]]))


        if widget_sites_ != widget_sites_prev_
            project.current_site = widget_sites[]
            cols = names(project.data[project.current_site])[2:end]
            traces = [scatter(
                x=project.data[project.current_site].datetime,
                y=project.data[project.current_site][!,col],
                line_width=0.5,
                name=replace(string(col),"Power_Wm_sid_"=>""))
                for col in cols]
            [deletetraces!(plt,i) for i in length(plt.plot.data):-1:1]
            [addtraces!(plt,trace) for trace in traces]
            widget_sites_prev_=widget_sites_
        end

    end
end
