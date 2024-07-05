local download = require("binary-toolkit.actions.get-lua.builders.jit.download")
local utilities = require("binary-toolkit.utilities")

---@param args GetLuaArguments
---@param url string
return function (args, url)
    if not args.make then
        error("Make is required for building LuaJIT")
    end

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
    utilities.execute(env.." "..args.make.." -j"..args.jobs.." -C '"..tostring(out_dir).."' 'CC="..args.c_compiler.."'")
    utilities.execute(env.." "..args.make.." -j"..args.jobs.." -C '"..tostring(out_dir).."' 'PREFIX="..tostring(args.output).."' install")
end
