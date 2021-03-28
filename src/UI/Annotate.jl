function annotate_traces(w,project)
    ptLog = DataFrame(
        fieldname=[],
        t1=[],
        t2=[],
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
        i_t2_tbc = findall(existing_log.t2.=="tbc")
        i_name_match = findall(existing_log.fieldname.==tr_name)
        i_match = intersect(i_t2_tbc,i_name_match)
        if isempty(i_match)
            # First point (of 2)
            pt = DataFrame(
                fieldname=tr_name,
                t1=t,
                t2="tbc",
                annot="tbc",
                blacklist=false,
                infill="tbc",
                log_time="tbc",
                author="tbc",
            )
            existing_log = vcat(existing_log,pt)
            CSV.write(joinpath(project.paths["annot"],fname),existing_log)
        else
            # Second point

            # w_annot = Window()

            annot_text = "annotation text $(now())"
            blacklist_bool = false
            infill = "tbc"
            author = split(Base.Filesystem.homedir(),"\\")[end]


            existing_log[i_match[1],:t2]=t
            existing_log[i_match[1],:annot]=annot_text
            existing_log[i_match[1],:blacklist]=blacklist_bool
            existing_log[i_match[1],:log_time]="$(now())"
            existing_log[i_match[1],:author]=author
            existing_log[i_match[1],:infill]=infill
            #
            sort!(existing_log)
            CSV.write(joinpath(project.paths["annot"],fname),existing_log)

        end
    end
end
