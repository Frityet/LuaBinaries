---@type {[OS] : fun(args: CLIArgs, dl_url: string)}
return {
    macosx   = require("builders.jit.posix"),
    linux   = require("builders.jit.posix"),
    windows = require("builders.jit.windows")
}
