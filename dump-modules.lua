#!/usr/bin/env ./lua
---@type string[]
local loaded_modules = {}
local l_require = require
function require(name)
    local ret, data = l_require(name)
    loaded_modules[name] = data
    return ret
end

local pretty = require("pl.pretty")

dofile("binary-creator.lua")

local f = assert(io.open("dumped-modules.lua", "w+b"))
f:write("return ", pretty.write(loaded_modules))
f:close()
print("Dumped modules to dumped-modules.lua")
