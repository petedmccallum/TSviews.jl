function annotate_traces(w,project;fname="AnnotationsLog.csv")
    ptLog = DataFrame(
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

    trace_name(tr) = tr["name"]
    trace_names = trace_name.(plt.plot.data)

    # Prep csv log file
    push!(project.paths,"root"=>join(split(project.paths["compiled"],"\\")[1:end-1],"\\"))
    push!(project.paths,"annot"=>joinpath(project.paths["root"],"annotations"))
    existing_folder = sum(readdir(project.paths["root"]).=="annotations")>0
    if existing_folder==false
        mkdir(project.paths["annot"])
    end

    existing_file = sum(readdir(project.paths["annot"]).==fname)>0
    global annot_file = joinpath(project.paths["annot"],fname)
    if existing_file==false
        CSV.write(annot_file,ptLog)
    end


    on(plt["click"]) do pt_click
        existing_log = CSV.read(annot_file,DataFrame)
        t = pt_click["points"][1]["x"]
        tr_name = trace_names[1+pt_click["points"][1]["curveNumber"]]
        if @isdefined(pt1) == false
            global pt1 = Dict()
        end
        if isempty(pt1)
            # First point (of 2)
            pt1 = Dict(
                "field"=>tr_name,
                "datetime_from"=>t,
            )
            blacklist=false
            author="tbc"
            annot_text="tbc"
            annot_plot(project.config,tr_name,annot_text,blacklist,author,t)
        else
            # Second point
            datetime_from = pt1["datetime_from"]
            datetime_to = t
            ui_annot(project,datetime_from,datetime_to,existing_log,pt1)
        end
    end
end


function ui_annot(project,from,to,existing_log,pt1)
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
        "from" => datepicker(Date(from[1:10])),
        "to" => datepicker(Date(to[1:10])),
    )
    timepickers = Dict(
        "from" => timepicker(Time(from[12:end])),
        "to" => timepicker(Time(to[12:end])),
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

    (annot_text, blacklist_bool, author, infill)

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


        if buttons_save_>0 && !isnothing(textboxes["annot_text"][])
            # Fill form response
            new_annot = DataFrame(
                :field => pt1["field"],
                :datetime_from => "$(datepickers["from"][]) $(timepickers["from"][])",
                :datetime_to => "$(datepickers["to"][]) $(timepickers["to"][])",
                :annot => textboxes["annot_text"][],
                :blacklist => chkboxes["blacklist"][],
                :infill => textboxes["infill"][],
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
                new_annot.author[1],
                new_annot.datetime_from[1];
                dt_to=new_annot.datetime_to[1],
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

end


function annot_plot(config,field,annot_text,blacklist,author,dt_from;dt_to=[])

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

    if isempty(dt_to)
        t = [DateTime(dt_from,"y-m-d H:M:S")]
        y = find_y_value.((plt.plot.data,),(i_trace,),t)
        name = "tmp"
    else
        t = [DateTime(dt_from,"y-m-d H:M:S");DateTime(dt_to,"y-m-d H:M:S")]
        y = find_y_value.((plt.plot.data,),(i_trace,),t)
        name = ""
    end

    if blacklist==true
        clr = :black
    else
        clr = "#555555bb"
    end

    tr = scatter(x=t,y=y,
        name=name,
        text="[$(author)] $(annot_text)",
        mode="lines+markers",
        line=attr(dash=:dash,color=clr),
        marker=attr(symbol=Symbol("300"),size=15,color=clr),
        yaxis="y$(length(subplots)+1-i_subplot)",
        showlegend=false,
    )


    rm_traces = findall(find_tracenames.((plt.plot.data,),1:length(plt.plot.data)).=="tmp")
    [deletetraces!(plt,rm_tr) for rm_tr in rm_traces]
    addtraces!(plt,tr)

end
