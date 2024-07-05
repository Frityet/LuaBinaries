local utilities = require("binary-toolkit.utilities")
local download = require("binary-toolkit.actions.get-lua.builders.puc.download")

return function (args, url)
    local srcdir = download(args.version, url)

    utilities.execute(args.make.."-j"..args.jobs.." -C "..tostring(srcdir).." guess")
    utilities.execute(args.make.."-j"..args.jobs.." -C "..tostring(srcdir).." install INSTALL_TOP="..tostring(args.output))
end
