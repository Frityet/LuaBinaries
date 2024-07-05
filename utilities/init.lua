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


return export
