local download = require("builders.jit.download")

---@param args CLIArgs
---@param url string
return function (args, url)
    local out_dir = download(url)

    local env = ""
    if args.os == "macosx" then
        --try to use sw_vers to get the version
        local version = ""
        local f = io.popen("sw_vers -productVersion", "r")
        if f then
            version = f:read("*a"):gsub("\n", "")
            f:close()
        else
            version = "10.15"
        end

        env = "MACOSX_DEPLOYMENT_TARGET="..version
    end
    os.exec(env.." "..args.make.." -j"..args.jobs.." -C '"..tostring(out_dir).."' 'CC="..args.c_compiler.."'")
    os.exec(env.." "..args.make.." -j"..args.jobs.." -C '"..tostring(out_dir).."' 'PREFIX="..tostring(args.output).."' install")
end
