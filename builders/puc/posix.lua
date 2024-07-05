local download = require("builders.puc.download")

return function (args, url)
    local srcdir = download(args.version, url)
    os.exec(args.make.." -j"..args.jobs.." -C "..tostring(srcdir).." guess")
    os.exec(args.make.." -j"..args.jobs.." -C "..tostring(srcdir).." install INSTALL_TOP="..tostring(args.output))
end
