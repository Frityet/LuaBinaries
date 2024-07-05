local download = require("builders.jit.download")

---@param args CLIArgs
---@param url string
return function (args, url)
    local out_dir = download(url)

    os.exec(args.make.." -j"..args.jobs.." -C '"..tostring(out_dir).."' CC="..args.c_compiler)
    os.exec(args.make.." -j"..args.jobs.." -C '"..tostring(out_dir).."' PREFIX="..tostring(args.output).." install")
end
