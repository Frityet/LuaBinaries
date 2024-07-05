---@type {[OS] : fun(args: GetLuaArguments, dl_url: string)}
return {
    macosx   = require("binary-toolkit.actions.get-lua.builders.puc.posix"),
    linux   = require("binary-toolkit.actions.get-lua.builders.puc.posix"),
    windows = require("binary-toolkit.actions.get-lua.builders.puc.windows")
}
