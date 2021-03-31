function annotate_traces(w,project;fname="AnnotationsLog.csv")

    trace_name(tr) = tr["name"]
    trace_names = trace_name.(plt.plot.data)

    # Prep csv log file
    existing_folder = sum(readdir(project.paths["root"]).=="annotations")>0
    if existing_folder==false
        mkdir(project.paths["annot"])
    end

    existing_file = sum(readdir(project.paths["annot"]).==fname)>0
    global annot_file = joinpath(project.paths["annot"],fname)
    # Create annotation log
    if existing_file==false
        # Blank annotation log for new file
        existing_log = DataFrame(
            site=[],
            field=[],
            datetime_from=[],
            datetime_to=[],
            annot=[],
            blacklist=[],
            infill=[],
            log_time=[],
            author=[],
            closed=[],
            infill_method=[],
            infill_const=[],
            response=[],
            response_author=[],
        )
        CSV.write(annot_file,existing_log)
    else
        existing_log = CSV.read(annot_file,DataFrame)
        annot_plot.((project.config,),
            existing_log.field,
            existing_log.annot,
            existing_log.blacklist,
            existing_log.infill,
            existing_log.author,
            existing_log.datetime_from,
            existing_log.datetime_to,
        )
    end

    ############################################################################ ↓ TEMP
    datetime_click = "2021-03-30 06:53"
    datetime_click = "2021-03-30 08:53"
    datetime_click = DateTime(datetime_click[1:16],"y-m-d H:M")
    # on(plt["click"]) do pt_click
    #     datetime_click = pt_click["points"][1]["x"]
    #     field = trace_names[1+pt_click["points"][1]["curveNumber"]]
    #     println(datetime_click)
    #     println(field)
    # end
    field="RH (%)"
    ############################################################################ ↑ TEMP
    on(plt["click"]) do pt_click
        existing_log = CSV.read(annot_file,DataFrame)
        datetime_click = pt_click["points"][1]["x"]
        datetime_click = DateTime(datetime_click[1:16],"y-m-d H:M")
        field = trace_names[1+pt_click["points"][1]["curveNumber"]]
        if @isdefined(pt1) == false
            global pt1 = Dict()
        end
        if isempty(pt1)
            # First point (of 2)
            pt1 = Dict(
                "site"=>project.current_site,
                "field"=>field,
                "datetime_from"=>datetime_click,
            )
            blacklist=false
            infill=false
            author="tbc"
            annot_text="tbc"
            config = project.config
            datetime_from = datetime_click
            datetime_to = nothing
            annot_plot(config,field,annot_text,blacklist,infill,author,datetime_from,datetime_to)
        else
            # Second point
            datetime_from = pt1["datetime_from"]
            datetime_to = datetime_click
            ui_annot(project,datetime_from,datetime_to,existing_log,pt1);
        end
    end
end


function ui_annot(project,datetime_from,datetime_to,existing_log,pt1)
    author = split(Base.Filesystem.homedir(),"\\")[end]
    buttons = Dict(
        "save" => button("Save"),
        "cancel" => button("Cancel"),
    )
    textboxes = Dict(
        "annot_text" => textbox("annotation text...",multiline=true),
        "author" => textbox("author",value=author),
        "infill" => textbox("#.###"),
    )
    chkboxes = Dict(
        "blacklist" => checkbox(),
        "infill" => checkbox(),
    )
    datepickers = Dict(
        "from" => datepicker(Date(datetime_from)),
        "to" => datepicker(Date(datetime_to)),
    )
    timepickers = Dict(
        "from" => timepicker(Time(datetime_from)),
        "to" => timepicker(Time(datetime_to)),
    )

    # Reformat widgets
    textboxes["annot_text"].scope.dom.props[:style] = Dict(
        :width => "550px",
        :height => "108px",
    )
    textboxes["author"].scope.dom.props[:style] = Dict(
        :width => "100px",
        :height => "36px",
    )
    textboxes["infill"].scope.dom.props[:style] = Dict(
        :width => "80px",
        :height => "36px",
    )

    div_annot = vbox(
        HTML(string("<div style='font-size:24px'>Annotations</div>")),
        vskip(8px),
        hbox(
            width("120px",HTML(string("<div style='font-size:16px'>From:</div>"))),
            datepickers["from"],
            timepickers["from"],
        ),
        vskip(8px),
        hbox(
            width("120px",HTML(string("<div style='font-size:16px'>To:</div>"))),
            datepickers["to"],
            timepickers["to"],
        ),
        vskip(8px),
        hbox(
            width("120px",HTML(string("<div style='font-size:16px'>Comment:</div>"))),
            textboxes["annot_text"],
        ),
        vskip(8px),
        hbox(
            width("120px",HTML(string("<div style='font-size:16px'>Author/initials:</div>"))),
            textboxes["author"],
        ),
        vskip(8px),
        hbox(
            width("120px",HTML(string("<div style='font-size:16px'>Blacklist data:</div>"))),
            chkboxes["blacklist"],
        ),
        vskip(8px),
        hbox(
            width("120px",HTML(string("<div style='font-size:16px'>Infill constant:</div>"))),
            chkboxes["infill"],
            textboxes["infill"],
        ),
        vskip(8px),
        hbox(
            buttons["save"],
            hskip(10px),
            buttons["cancel"]
        )
    )

    global w_annot = Window(Dict(
        "title"=>"TSviews",
        "width"=>700,
        "height"=>500,
    ));
    body!(w_annot,
        hbox(
            hskip(40px),
            vbox(
                vskip(20px),
                div_annot,
            )
        )
    );

    # (annot_text, blacklist_bool, author, infill)

    @manipulate for
            buttons_save_ in buttons["save"],
            buttons_cancel_ in buttons["cancel"],
            textboxes_annot_text_ in textboxes["annot_text"],
            textboxes_author_ in textboxes["author"],
            textboxes_infill_ in textboxes["infill"],
            datepickers_from_ in datepickers["from"],
            datepickers_to_ in datepickers["to"],
            chkboxes_blacklist_ in chkboxes["blacklist"],
            chkboxes_infill_ in chkboxes["infill"]


        if buttons["save"][]>0 && !isnothing(textboxes["annot_text"][])
            # Fill form response
            new_annot = DataFrame(
                :site => project.current_site,
                :field => pt1["field"],
                :datetime_from => datepickers["from"][]+timepickers["from"][],
                :datetime_to => datepickers["to"][]+timepickers["to"][],
                :annot => textboxes["annot_text"][],
                :blacklist => chkboxes["blacklist"][],
                :infill => chkboxes["infill"][],
                :log_time => "$(now())",
                :author => textboxes["author"][],
                :closed => "tbc",
                :infill_method => "tbc",
                :infill_const => "tbc",
                :response => "tbc",
                :response_author => "tbc",
            )
            annot_plot(
                project.config,
                new_annot.field[1],
                new_annot.annot[1],
                new_annot.blacklist[1],
                new_annot.infill[1],
                new_annot.author[1],
                new_annot.datetime_from[1],
                new_annot.datetime_to[1],
            )
            updated_log = vcat(existing_log,new_annot)
            sort!(existing_log)
            CSV.write(annot_file,updated_log)
            global pt1 = Dict()
            close(w_annot)

            return pt1
        elseif buttons_cancel_ >0
            global pt1 = Dict()
            close(w_annot)
            return pt1
        end
    end
    return w_annot
end


function annot_plot(config,field,annot,blacklist,infill,author,datetime_from,datetime_to)

    find_alias(timeseries,ts) = timeseries[ts]["alias"]
    ts = keys(config["timeseries"])
    ts_alias = find_alias.((config["timeseries"],),ts)
    tr = string.(ts)[findfirst(ts_alias.==field)]

    subplots = find_subplot_fields.((config,),1:length(config["subplots"]))
    i_subplot = findfirst(findall_arr2.(subplots,(tr)))

    # Eval corresponding y-values
    find_tracenames(plt_data,i) = plt_data[i]["name"]
    i_trace = findfirst(find_tracenames.((plt.plot.data,),1:length(plt.plot.data)).==field)
    find_y_value(plt_data,i_trace,t) = plt_data[i_trace]["y"][plt_data[i_trace]["x"].==t][1]
    find_y_value_range(plt_data,i_trace,(t1,t2)) = plt_data[i_trace]["y"][findfirst(plt_data[i_trace]["x"].>=t1):findfirst(plt_data[i_trace]["x"].>=t2)]

    if isnothing(datetime_to)
        t = [datetime_from]
        y = find_y_value.((plt.plot.data,),(i_trace,),t)
        mode = "markers"
        clr = "#11111188"
        name = "tmp"
    else
        t = [datetime_from;datetime_to;datetime_to;datetime_from;datetime_from]
        t1 = datetime_from
        t2 = datetime_to
        plt_data = plt.plot.data
        ys = skipmissing(find_y_value_range(plt.plot.data,i_trace,(datetime_from,datetime_to)))
        annot_box_scale = (maximum(skipmissing(plt_data[i_trace]["y"]))-minimum(skipmissing(plt_data[i_trace]["y"])))*0.1
        y = [minimum(ys)-annot_box_scale,minimum(ys)-annot_box_scale,maximum(ys)+annot_box_scale,maximum(ys)+annot_box_scale,minimum(ys)-annot_box_scale]
        mode = "lines"
        if blacklist==true
            clr = "#11111188"
            name = "BLACKLIST"
        elseif infill==true
            clr = "#a55eea"
            name = "Infill"
        else
            clr = "#666666bb"
            name = "Comment"
        end
    end


    tr = scatter(x=t,y=y,
        name=name,
        text="[$(author)] $(annot)",
        mode=mode,
        line=attr(width=1,color=clr,dash=:dot),
        marker=attr(symbol=Symbol("300"),size=15,color=clr),
        fill="toself",
        fillopacity=0.2,
        yaxis="y$(length(subplots)+1-i_subplot)",
        showlegend=false,
    )


    rm_traces = findall(find_tracenames.((plt.plot.data,),1:length(plt.plot.data)).=="tmp")
    [deletetraces!(plt,rm_tr) for rm_tr in rm_traces]
    addtraces!(plt,tr)

end
