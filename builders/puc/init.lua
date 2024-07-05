---@type {[OS] : fun(args: GetLuaArguments, dl_url: string)}
return {
    macosx   = require("builders.puc.posix"),
    linux   = require("builders.puc.posix"),
    windows = require("builders.puc.windows")
}
