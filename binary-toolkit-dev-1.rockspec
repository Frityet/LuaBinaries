---@diagnostic disable: lowercase-global
package = "binary-toolkit"
version = "dev-1"
source = {
    url = "https://github.com/Frityet/LuaBinaries.git"
}
description = {
    homepage = "https://github.com/Frityet/LuaBinaries",
    license = "MIT"
}
dependencies = {
    "lua >= 5.1",
    "penlight",
    "luafilesystem",
    "argparse",
    "sysdetect",
    "lua-zlib",
    "luazip",
    "easy-http >= 0.1.1"
}
build = {
    type = "builtin",
    install = {
        bin = {
            ["binary-toolkit"] = "src/binary-toolkit/main.lua"
        }
    },

    modules = {
        ["binary-toolkit.actions.get-lua.builders"]             = "src/binary-toolkit/actions/get-lua/builders/init.lua",
        ["binary-toolkit.actions.get-lua.builders.puc"]         = "src/binary-toolkit/actions/get-lua/builders/puc/init.lua",
        ["binary-toolkit.actions.get-lua.builders.puc.posix"]   = "src/binary-toolkit/actions/get-lua/builders/puc/posix.lua",
        ["binary-toolkit.actions.get-lua.builders.puc.windows"] = "src/binary-toolkit/actions/get-lua/builders/puc/windows.lua",
        ["binary-toolkit.actions.get-lua.builders.puc.download"]= "src/binary-toolkit/actions/get-lua/builders/puc/download.lua",
        ["binary-toolkit.actions.get-lua.builders.jit"]         = "src/binary-toolkit/actions/get-lua/builders/jit/init.lua",
        ["binary-toolkit.actions.get-lua.builders.jit.posix"]   = "src/binary-toolkit/actions/get-lua/builders/jit/posix.lua",
        ["binary-toolkit.actions.get-lua.builders.jit.windows"] = "src/binary-toolkit/actions/get-lua/builders/jit/windows.lua",
        ["binary-toolkit.actions.get-lua.builders.jit.download"]= "src/binary-toolkit/actions/get-lua/builders/jit/download.lua",
        ["binary-toolkit.actions.get-lua"]                      = "src/binary-toolkit/actions/get-lua/init.lua",
        ["binary-toolkit.actions"]                              = "src/binary-toolkit/actions/init.lua",
        ["binary-toolkit.utilities"]                            = "src/binary-toolkit/utilities/init.lua",
        ["binary-toolkit.utilities.Path"]                       = "src/binary-toolkit/utilities/Path.lua",
        ["binary-toolkit.utilities.tar"]                        = "src/binary-toolkit/utilities/tar.lua",
        ["binary-toolkit.utilities.hash"]                       = "src/binary-toolkit/utilities/hash.lua"
    }
}
