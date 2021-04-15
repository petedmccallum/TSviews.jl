function annotate_traces(w,project;fname="AnnotationsLog.csv")

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
        if sum(keys(pt_click["points"][1]).=="x")>0
            # If timeseries is clicked on ("x" occurs in `pt_click`)
            datetime_click = pt_click["points"][1]["x"]
            datetime_click = DateTime(datetime_click[1:16],"y-m-d H:M")
            field = trace_names[1+pt_click["points"][1]["curveNumber"]]
            y = pt_click["points"][1]["y"]
            println("$(datetime_click)\t$(field)\t$(y)")
            if @isdefined(current_annot) == false
                global current_annot = Dict()
            end
            if isempty(current_annot)
                # First point (of 2)
                current_annot = Dict(
                    "site"=>project.current_site,
                    "field"=>field,
                    "datetime_from"=>datetime_click,
                )
                blacklist=false
                infill=false
                author="tbc"
                annot_text="tbc"
                config = project.config
                datetime_to = nothing
                annot_plot(config,
                    field,
                    annot_text,
                    blacklist,
                    infill,
                    author,
                    current_annot["datetime_from"],
                    datetime_to,
                )
            else
                # Second point
                push!(current_annot,"datetime_to"=>datetime_click)
                new_annot = current_annot
                current_annot = Dict()
                ui_annot(project;existing_log=existing_log,new_annot=new_annot);
            end
        else
            # If annotation area is clicked on ("x" doesn't occur in `pt_click` in this case)
            curveNumber = Int(pt_click["points"][1]["curveNumber"])
            trace_names = trace_name.(plt.plot.data)
            i_tr_annot = vcat([
                findall(trace_names.=="Comment"),
                findall(trace_names.=="Infill"),
                findall(trace_names.=="BLACKLIST")
            ]...)
            i_click_annot = findfirst(i_tr_annot.==curveNumber)
            # println(existing_log[i_click_annot,:])
            ui_annot(project;recalled_annot=existing_log[i_click_annot,:]);
        end
    end
end


function ui_annot(project;existing_log=DataFrame(),new_annot=Dict(),recalled_annot=[])
    # Adapt for new annot or existing annot
    if isempty(new_annot)==false
        author = split(Base.Filesystem.homedir(),"\\")[end]
        datetime_from = new_annot["datetime_from"]
        datetime_to = new_annot["datetime_to"]
        esc_button_str = "Cancel"
        global field = new_annot["field"]

        textboxes = Dict(
            "annot_text" => textbox("annotation text...",multiline=true),
            "author" => textbox("author",value=author),
            "infill" => textbox("#.###"),
            "response" => textbox("Comment response",multiline=true),
            "author_resp" => textbox("author_resp",value=author),
        )
        chkboxes = Dict(
            "blacklist" => checkbox(),
            "infill" => checkbox(),
            "closed" => checkbox(),
        )
    else
        datetime_from = recalled_annot.datetime_from[1]
        datetime_to = recalled_annot.datetime_to[1]
        esc_button_str = "Delete"
        global field = recalled_annot.field[1]

        textboxes = Dict(
            "annot_text" => textbox("annotation text...",value=recalled_annot.annot[1],multiline=true),
            "author" => textbox("author",value=recalled_annot.author[1]),
            "infill" => textbox("#.###",value=recalled_annot.infill[1]),
            "response" => textbox("Comment response",value=recalled_annot.response[1],multiline=true),
            "author_resp" => textbox("author_resp",value=recalled_annot.response_author[1]),
        )
        chkboxes = Dict(
            "blacklist" => checkbox(recalled_annot.blacklist[1]),
            "infill" => checkbox(recalled_annot.infill[1]),
            "closed" => checkbox(recalled_annot.closed[1]),
        )
    end

    datepickers = Dict(
        "from" => datepicker(Date(datetime_from)),
        "to" => datepicker(Date(datetime_to)),
    )
    timepickers = Dict(
        "from" => timepicker(Time(datetime_from)),
        "to" => timepicker(Time(datetime_to)),
    )
    buttons = Dict(
        "save" => button("Save"),
        "cancel" => button(esc_button_str),
    )
    infill_types = vcat("constant",unique(find_interp.((project.config["timeseries"],),keys(project.config["timeseries"]))))
    dropdowns = Dict(
        "infill" => dropdown(infill_types),
    )

    # Reformat widgets
    textboxes["annot_text"].scope.dom.props[:style] = Dict(
        :width => "568px",
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
    textboxes["response"].scope.dom.props[:style] = Dict(
        :width => "568px",
        :height => "72px",
    )
    textboxes["author_resp"].scope.dom.props[:style] = Dict(
        :width => "100px",
        :height => "36px",
    )

    div_annot = vbox(
        HTML(string("<div style='font-size:24px'>Annotations</div>")),
        vskip(8px),
        hbox(
            vbox(vskip(6px),width("120px",HTML(string("<div style='font-size:16px'>From:</div>")))),
            datepickers["from"],
            timepickers["from"],
        ),
        vskip(8px),
        hbox(
            vbox(vskip(6px),width("120px",HTML(string("<div style='font-size:16px'>To:</div>")))),
            datepickers["to"],
            timepickers["to"],
        ),
        vskip(8px),
        hbox(
            vbox(vskip(6px),width("120px",HTML(string("<div style='font-size:16px'>Comment:</div>")))),
            textboxes["annot_text"],
        ),
        vskip(8px),
        hbox(
            vbox(vskip(6px),width("120px",HTML(string("<div style='font-size:16px'>Author/initials:</div>")))),
            textboxes["author"],
        ),
        vskip(8px),
        hbox(
            vbox(vskip(1px),width("112px",HTML(string("<div style='font-size:16px'>Blacklist data:</div>")))),
            vbox(vskip(2px),chkboxes["blacklist"]),
        ),
        vskip(8px),
        hbox(
            vbox(vskip(5px),width("112px",HTML(string("<div style='font-size:16px'>Infill:</div>")))),
            vbox(vskip(6px),chkboxes["infill"]),
            dropdowns["infill"],
            textboxes["infill"],
        )
    )

    div_buttons = vbox(
        vskip(28px),
        hbox(
            buttons["save"],
            hskip(10px),
            buttons["cancel"]
        )
    )


    if isempty(new_annot)==true
        div_response = vbox(
            vskip(16px),
            Interact.hline(),
            vskip(24px),
            hbox(
                vbox(vskip(6px),width("120px",HTML(string("<div style='font-size:16px'>Response:</div>")))),
                textboxes["response"],
            ),
            vskip(8px),
            hbox(
                vbox(vskip(5px),width("112px",HTML(string("<div style='font-size:16px'>Closed?</div>")))),
                vbox(vskip(6px),chkboxes["closed"]),
                textboxes["author_resp"],
            )
        )
        div_ALL = vbox(div_annot,div_response,div_buttons)
        window_height = 720
    else
        div_ALL = vbox(div_annot,div_buttons)
        window_height = 550
    end




    global w_annot = Window(Dict(
        "title"=>"TSviews",
        "width"=>800,
        "height"=>window_height,
    ));
    body!(w_annot,
        hbox(
            hskip(40px),
            vbox(
                vskip(20px),
                div_ALL,
            )
        )
    );



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
                :field => field,
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
            close(w_annot)
        elseif buttons_cancel_ >0
            close(w_annot)
        end
    end
    return w_annot
end


function annot_plot(config,field,annot,blacklist,infill,author,datetime_from,datetime_to)

    ts = keys(config["timeseries"])
    ts_alias = find_alias.((config["timeseries"],),ts)
    tr = string.(ts)[findfirst(ts_alias.==field)]

    subplots = find_subplot_fields.((config,),1:length(config["subplots"]))
    i_subplot = findfirst(findall_arr2.(subplots,(tr)))

    # Eval corresponding y-values
    i_trace = findfirst(find_tracenames.((plt.plot.data,),1:length(plt.plot.data)).==field)

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
            clr = "#bbbbbbbb"
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
