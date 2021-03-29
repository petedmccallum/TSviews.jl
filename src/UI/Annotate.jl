function annotate_traces(w,project)
    ptLog = DataFrame(
        fieldname=[],
        datetime_from=[],
        datetime_to=[],
        annot=[],
        blacklist=[],
        infill=[],
        log_time=[],
        author=[],
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
    fname = "AnnotationsLog.csv"
    existing_file = sum(readdir(project.paths["annot"]).==fname)>0
    if existing_file==false
        CSV.write(joinpath(project.paths["annot"],fname),ptLog)
    end


    on(plt["click"]) do pt_click
        existing_log = CSV.read(joinpath(project.paths["annot"],fname),DataFrame)
        t = pt_click["points"][1]["x"]
        tr_name = trace_names[1+pt_click["points"][1]["curveNumber"]]
        if @isdefined(pt1) == false
            global pt1 = Dict()
        end
        if isempty(pt1)
            # First point (of 2)
            pt1 = Dict(
                "fieldname"=>tr_name,
                "datetime_from"=>t,
            )
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


        if buttons_save_>0
            # Fill form response
            new_annot = DataFrame(
                :fieldname => pt1["fieldname"],
                :datetime_from => "$(datepickers["from"][]) $(timepickers["from"][])",
                :datetime_to => "$(datepickers["to"][]) $(timepickers["to"][])",
                :annot => textboxes["annot_text"][],
                :blacklist => chkboxes["blacklist"][],
                :infill => textboxes["infill"][],
                :log_time => "$(now())",
                :author => textboxes["author"][],
            )

            updated_log = vcat(existing_log,new_annot)
            sort!(existing_log)
            CSV.write(joinpath(project.paths["annot"],"AnnotationsLog.csv"),updated_log)
            global pt1 = Dict()
            close(w_annot)
            println("save")

            return pt1
        elseif buttons_cancel_ >0
            global pt1 = Dict()
            close(w_annot)
            println("cancel")
            return pt1
        end
    end

end
