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
   "lua ~> 5.4",
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
         ["binary-toolkit"] = "main.lua"
      }
   },

   modules = {
      ["builders"] = "builders/init.lua",
      ["builders.puc"] = "builders/puc/init.lua",
      ["builders.puc.posix"] = "builders/puc/posix.lua",
      ["builders.puc.windows"] = "builders/puc/windows.lua",
      ["utilities"] = "utilities/init.lua",
      ["Path"] = "utilities/Path.lua",
      ["tar"] = "utilities/tar.lua",
      ["hash"] = "utilities/hash.lua"
   }
}
