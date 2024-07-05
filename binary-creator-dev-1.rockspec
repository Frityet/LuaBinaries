package = "binary-creator"
version = "dev-1"
source = {
   url = "*** please add URL for source tarball, zip or repository here ***"
}
description = {
   homepage = "*** please enter a project homepage ***",
   license = "*** please specify a license ***"
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
         ["binary-creator"] = "binary-creator.lua"
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
