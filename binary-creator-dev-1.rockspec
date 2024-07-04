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
   "luarocks", --for tar
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
      ["Path"] = "path.lua",
      ["builders"] = "builders/init.lua",
      ["builders.puc"] = "builders/puc/init.lua",
      ["builders.puc.posix"] = "builders/puc/posix.lua",
      ["builders.puc.windows"] = "builders/puc/windows.lua",
   }
}
