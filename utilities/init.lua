local sysdetect = require("sysdetect")

local export = {}

---@generic T, V
---@param t { [T] : V  }
---@return T[]
function export.keys(t)
    local keys = {}
    for k, _ in pairs(t) do
        table.insert(keys, k)
    end
    return keys
end

---From https://github.com/luarocks/luarocks/blob/master/src/luarocks/fun.lua
---@generic T: function
---@param fn T
---@return T
function export.memoize(fn)
    local memory = setmetatable({}, { __mode = "k" })
    local errors = setmetatable({}, { __mode = "k" })
    local NIL = {}
    return function(arg)
       if memory[arg] then
          if memory[arg] == NIL then
             return nil, errors[arg]
          end
          return memory[arg]
       end
       local ret1, ret2 = fn(arg)
       if ret1 ~= nil then
          memory[arg] = ret1
       else
          memory[arg] = NIL
          errors[arg] = ret2
       end
       return ret1, ret2
    end
end


---os.execute that properly handles 5.1 and 5.4
---@param cmd string
---@param debug boolean?
---@return boolean
function export.execute(cmd, debug)
   --debug == nil will still print
   if debug ~= false then
       print("$ "..cmd)
   end

   if _VERSION == "Lua 5.1" then
       return os.execute(cmd) == 0
   else
       local _, _, code = os.execute(cmd)
       return code == 0
   end
end

---@return OS, Architecture
function export.get_host_info()
   local host_os, arch = sysdetect.detect()

   if host_os == "macosx" then host_os = "macosx"
   elseif host_os == "windows" or host_os == "cygwin" then host_os = "windows"
   elseif host_os == "linux" then host_os = "linux"
   else error("Unsupported OS: "..host_os) end

   if arch ~= "x86_64" and arch ~= "arm64" and arch ~= "aarch64" then
       error("Unsupported architecture: "..arch)
   end

   --[[@cast host_os OS]]
   --[[@cast arch Architecture]]
   return host_os, arch
end

---@param name string
---@return string?
function export.check_program(name)
   local host_os = export.get_host_info()
   local ok = false
   if host_os == "windows" then
      ok = export.execute("where "..name.." >nul 2>&1", false)
   else
      ok = export.execcute("command -v "..name.." >/dev/null 2>&1", false)
   end

   return ok and name or nil
end

return export
