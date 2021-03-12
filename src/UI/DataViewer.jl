function data_viewer(w,project)

    fname = project.paths["shared_config"]
    f = open(fname) do file
        read(file,String)
    end
    config = JSON.parse(f)

    ## Time window
    nDays = 1
    i_lastday = findlast(Time.(project.data[project.current_site].datetime).==Time(0))
    t_start = project.data[project.current_site].datetime[i_lastday] - Day(nDays)
    t_end = project.data[project.current_site].datetime[i_lastday]


    cols = names(project.data[project.current_site])[2:end]
    dfs = include_df_gaps.((project.data[project.current_site],),cols)
    n_plots = length(keys(config["subplots"]))
    tr_site = line_trace.(dfs,(config,),(n_plots,))
    layout = Layout(Dict(
        :height=>800,
        :width=>1800,
        :legend_orientation=>"h",
        :legend_x=>0.,
        :legend_y=>1.05,
        :margin_l=>80,
    ))

    if n_plots == 1
        relayout!(layout, xaxis_domain=[0., 1.])
        relayout!(layout, yaxis_domain=[0., 0.3])
    elseif n_plots == 2
        relayout!(layout, xaxis_domain=[0., 1.])
        relayout!(layout, yaxis_domain=[0., 0.3])
        relayout!(layout, xaxis2_domain=[0., 1.])
        relayout!(layout, yaxis2_domain=[0.35, 0.65])
    elseif n_plots == 3
        subplot_yaxes = find_subplot_yaxis.((config,),1:n_plots)
        relayout!(layout, xaxis_domain=[0., 1.])
        relayout!(layout, xaxis2_domain=[0., 1.])
        relayout!(layout, xaxis3_domain=[0., 1.])
        relayout!(layout, yaxis_domain=[0., 0.3])
        relayout!(layout, yaxis2_domain=[0.35, 0.65])
        relayout!(layout, yaxis3_domain=[0.7, 1.])
        relayout!(layout, yaxis_title=subplot_yaxes[3])
        relayout!(layout, yaxis2_title=subplot_yaxes[2])
        relayout!(layout, yaxis3_title=subplot_yaxes[1])
    end
    global plt = plot(tr_site[:],layout);



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

    global widget_sites_prev=widget_sites[]
    @manipulate for
        widget_sites_ in widget_sites,
        widget_startDate_ in widget_startDate,
        widget_numDays_ in widget_numDays

        relayout!(plt,xaxis_range=widget_startDate[] .+ Day.([0,widget_numDays[]]))


        if widget_sites_ != widget_sites_prev
            project.current_site = widget_sites[]
            if sum(keys(project.data).==project.current_site) == 0
                i_site = findfirst(project.sites.==project.current_site)
                project = import_data(project;i_site=i_site)
            end
            sleep(0.1)
            cols = names(project.data[project.current_site])[2:end]
            dfs = include_df_gaps.((project.data[project.current_site],),cols)
            # n_plots = length(keys(config["subplots"]))
            tr_site = line_trace.(dfs,(config,),(n_plots,))
            L = length(plt.plot.data)
            deletetraces_arr.((plt,),L:-1:1)
            addtraces_arr.((plt,),tr_site)
            widget_sites_prev=widget_sites[]
        end

    end
end
