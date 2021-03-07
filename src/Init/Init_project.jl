function select_project()
    appdata_local = joinpath(Base.Filesystem.homedir(),"AppData","Local")
    appdata_local_tsviews = joinpath(appdata_local,"julia_projects","TSviews","projects")

    if isdir(appdata_local_tsviews)
        dir = readdir(appdata_local_tsviews)
        dir_excl_suffix = replace.(dir,".json"=>"")
    else
        function add_dir(dirs,i)
            if !isdir(joinpath(appdata_local,join(dirs[1:i],"\\")))
                mkdir(joinpath(appdata_local,join(dirs[1:i],"\\")))
            end
        end
        add_dir.((["julia_projects","TSviews","projects"],),1:3)
        dir_excl_suffix = [""]
    end
    return dir_excl_suffix
end
