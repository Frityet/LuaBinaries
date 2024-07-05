#!/usr/bin/env ./lua

---@type argparse
local argparse = require("argparse")
local actions = require("actions")
local utilities = require("utilities")

---@alias OS            "linux"  | "macosx" | "windows"
---@alias Architecture  "x86_64" | "arm64"  | "aarch64"

local host_os, host_arch = utilities.get_host_info()

local found_cc = utilities.check_program(os.getenv("CC") or "cc")
                            or utilities.check_program("gcc")
                            or utilities.check_program("clang")
                            or "cc"
local found_make = utilities.check_program(os.getenv("MAKE") or "make")
                            or utilities.check_program("gmake")
                            or utilities.check_program("make")
                            or utilities.check_program("mingw32-make")


local parser = argparse("binary-toolkit", "Automatically compile and package lua binaries")

parser  :option "--os"
        :description "The operating system to compile for"
        :choices { "linux", "macosx", "windows" }
        :default(host_os)
        :args(1)

parser  :option "--arch"
        :description "The architecture to compile for"
        :choices { "x86_64", "arm64", "aarch64" }
        :default(host_arch)
        :args(1)

parser  :option "--c-compiler"
        :description "The C compiler to use"
        :default(found_cc)
        :args(1)

parser  :option "--linker"
        :description "The linker to use"
        :default(found_cc)
        :args(1)

parser  :option "--make"
        :description "The make program to use"
        :default(found_make)
        :args(1)


for _, action in pairs(actions) do
    local cmd = parser:command(action.name, action.description)
    action.configure_command(cmd)
end

parser:add_help(true)
parser:add_complete()


---@class BaseArguments
---@field os OS
---@field arch Architecture
---@field c_compiler string
---@field linker string
---@field make string?
local args = parser:parse()

for k, v in pairs(actions) do
    if args[k] then os.exit(v.action(args)) end
end
