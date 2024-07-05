---@type {[OS] : fun(args: GetLuaArguments, dl_url: string)}
return {
    macosx   = require("binary-toolkit.actions.get-lua.builders.jit.posix"),
    linux   = require("binary-toolkit.actions.get-lua.builders.jit.posix"),
    windows = require("binary-toolkit.actions.get-lua.builders.jit.windows")
}
