mutable struct Project
    name::String
    paths::Dict
    sites::Array{String}
    raw::Dict
    compiled::Dict
    current_site::String
    data::Dict
    Project() = new()
end

function ui_launch()
    # Check for existing project JSONs (saved paths) in AppData/Local/julia_projects/TSviews/projects
    existing_projects = select_project()

    # Define widgets
    buttons = Dict(
        "new" => button(HTML(string("<div style='font-size:16px'>Add</div>"))),
        "existing" => button(HTML(string("<div style='font-size:16px'>Load</div>"))),
    )
    dropdowns = Dict(
        "existing" => dropdown(existing_projects),
    )
    textboxes = Dict(
        "name" => textbox("Project name"),
        "raw" => textbox("Choose a folder (i.e. deposit raw data in a new folder called '.../raw')"),
        "compiled" => textbox("Choose a different folder (i.e. make new empty folder called '.../compiled')"),
    )


    # Restyle widgets
    buttons["new"].scope.dom.props[:style] = Dict(
        :width => "170px",
        :height => "36px",
        :backgroundColor=>"#52bec3"
    )
    buttons["existing"].scope.dom.props[:style] = Dict(
        :width => "170px",
        :height => "36px",
        :backgroundColor=>"#52bec3"
    )
    textboxes["name"].scope.dom.props[:style] = Dict(
        :width => "1000px",
        :height => "36px",
    )
    textboxes["raw"].scope.dom.props[:style] = Dict(
        :width => "1000px",
        :height => "36px",
    )
    textboxes["compiled"].scope.dom.props[:style] = Dict(
        :width => "1000px",
        :height => "36px",
    )
    dropdowns["existing"].scope.dom.props[:style] = Dict(
        :width => "170px",
        :height => "36px",
    )


    # Build elements
    el_new = vbox(
        HTML(string("<div style='font-size:24px'>New project</div>")),
        vskip(8px),
        hbox(
            width("200px",vbox(
                vskip(5px),
                HTML(string("<div style='font-size:16px'>Project name</div>")))
            ),
            textboxes["name"],
        ),
        vskip(8px),
        hbox(
            width("200px",vbox(
                vskip(5px),
                HTML(string("<div style='font-size:16px'>Raw data</div>")))
            ),
            textboxes["raw"],
        ),
        vskip(8px),
        hbox(
            width("200px",vbox(
                vskip(5px),
                HTML(string("<div style='font-size:16px'>Compiled data</div>")))
            ),
            textboxes["compiled"],
            hskip(20px),
        ),
        vskip(8px),
        hbox(
            width("200px",vbox(
                vskip(5px),
                HTML(string("<div style='font-size:16px'> </div>")))
            ),
            buttons["new"],
        )
    )
    el_existing = vbox(
        HTML(string("<div style='font-size:24px'>Existing project</div>")),
        vskip(8px),
        hbox(
            width("200px",HTML(string("<div style='font-size:16px'> </div>"))),
            dropdowns["existing"],
        ),
        vskip(8px),
        hbox(
            width("200px",HTML(string("<div style='font-size:16px'> </div>"))),
            buttons["existing"],
        )
    )
    el_ctrl = vbox(
        el_new,
        vskip(50px),
        Interact.hline(),
        vskip(50px),
        el_existing,
    )


    # Launch blink window and content
    w = Window(Dict(
        "title"=>"TSviews",
        "width"=>2000,
        "height"=>1000,
    ))
    body!(w,
        hbox(
            hskip(100px),
            vbox(
                vskip(50px),
                el_ctrl,
            )
        )
    )


    @manipulate for
        buttons_new in buttons["new"],
        buttons_existing in buttons["existing"]

        if buttons_new[]>0
            println("name\t->\t$(textboxes["name"].output.val)")
            println("raw\t->\t$(textboxes["raw"].output.val)")
            println("compiled\t->\t$(textboxes["compiled"].output.val)")
            paths = Dict()
            return paths

        elseif buttons_existing[]>0
            project_name = dropdowns["existing"].output.val
            appdata_local = joinpath(Base.Filesystem.homedir(),"AppData","Local","julia_projects","TSviews","projects")
            fname = joinpath(appdata_local,"$project_name.json")
            f = open(fname) do file
                read(file,String)
            end
            paths = JSON.parse(f)

            project = Project()
            project.name=project_name
            project.paths=paths
            project.raw=Dict()
            project.compiled=Dict()
            project.data=Dict()

            plot_data(w, project)

        end

    end


end
