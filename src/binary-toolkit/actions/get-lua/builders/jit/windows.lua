local download = require("binary-toolkit.actions.get-lua.builders.jit.download")
local utilities = require("binary-toolkit.utilities")

---@param args GetLuaArguments
---@param url string
return function (args, url)
    local out_dir = download(url)

    utilities.execute(args.make.." -j"..args.jobs.." -C '"..tostring(out_dir).."' 'CC="..args.c_compiler.."'")
    utilities.execute(args.make.." -j"..args.jobs.." -C '"..tostring(out_dir).."' 'PREFIX="..tostring(args.output).."' install")
end
