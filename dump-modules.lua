#!/usr/bin/env ./lua
if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then require("lldebugger").start() end
---@type string[]
local loaded_modules = {}
local l_require = require
function require(name)
    local ret, data = l_require(name)
    if data and not loaded_modules[name] then
        loaded_modules[name] = data
    end
    return ret, data
end

dofile("main.lua")
loaded_modules["$!main!$"] = "main.lua"

local Path = require("utilities.Path")
for k, v in pairs(loaded_modules) do
    loaded_modules[k] = tostring(Path.new(v):expand():absolute():relative_to(Path.current_directory))
end

local f = assert(io.open("dumped-modules.lua", "w+b"))
f:write("return {", "\n")
for k, v in pairs(loaded_modules) do
    f:write(string.format('    ["%s"] = "%s";', k, v), "\n")
end
f:write("}", "\n")
f:close()
print("Dumped modules to dumped-modules.lua")
require = l_require
