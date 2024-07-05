#!/usr/bin/env ./lua

local start_profiling, end_profiling
if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    DEBUG = true
    if jit then
        local p = require("jit.p")
        jit.off()
        require("jit.opt").start(0)
        start_profiling = function()
            p.start("a", os.date("profiles/%Y-%m-%d_%H-%M-%S.profile"))
        end
        end_profiling = function()
            p.stop()
        end
    end
    require("lldebugger").start()
else
    DEBUG = false
end

start_profiling = start_profiling or function() end
end_profiling = end_profiling or function() end

---@type string[]
local loaded_modules = {}
local l_require = require
function require(name)
    local ret, data = l_require(name)
    if data then
        loaded_modules[name] = data
    end
    return ret, data
end

local l_os_exit = os.exit
local exit_code = 0
function os.exit(code)
    exit_code = code
end
start_profiling()
dofile("src/binary-toolkit/main.lua")
end_profiling()
loaded_modules["$!main!$"] = "src/binary-toolkit/main.lua"

local Path = require("binary-toolkit.utilities.Path")
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

os.exit(exit_code)
