---@diagnostic disable-next-line: deprecated
local unpack = unpack or table.unpack

local lfs = require("lfs")

local is_windows = package.config:sub(1, 1) == "\\"
local seperator = is_windows and "\\" or "/"

---@class Path
---@field parts string[]
---@field current_directory Path
---@operator div(string|Path|unknown): Path
---@operator sub(number): Path
local Path = {}
Path.__index = Path
Path.__name = "Path"

---@param path string
---@param ... string
---@return Path
function Path.new(path, ...)
    local parts = {}
    if path:sub(1, 1) == seperator then parts = { seperator } end

    for part in path:gmatch("[^/\\]+") do
        table.insert(parts, part)
    end
    for _, part in ipairs({...}) do
        table.insert(parts, part)
    end
    return setmetatable({ parts = parts }, Path)
end

---@return boolean
function Path:exists()
    local mode = self:type()
    return mode == "directory" or mode == "file"
end

function Path:type() return (lfs.attributes(tostring(self), "mode")) end

---@param with_parents boolean?
---@return boolean, string?
function Path:create_directory(with_parents)
    if with_parents then
        local parts = {}
        for i = 1, #self.parts do
            table.insert(parts, self.parts[i])
            local path = Path.new(unpack(parts))
            if not path:exists() then
                local ok, err = lfs.mkdir(tostring(path))
                if not ok then return false, err end
            end
        end

        return true
    else
        return lfs.mkdir(tostring(self))
    end
end

---@overload fun(self: Path, type: "file", mode: openmode?): file*, string?
---@param type "directory"
---@return boolean | file*, string?
function Path:open(type, mode)
    if type == "directory" then return self:create_directory()
    elseif type == "file" then
        mode = mode or "w"
        local file, err = io.open(tostring(self), mode)
        if not file then return false, err end

        return file
    else return false, "Invalid type \""..type.."\"" end
end

---@private
---@param path string | Path
---@return Path
function Path:__div(path)
    if type(path) == "table" then return Path.new(tostring(self), unpack(path.parts)) end
    --[[@cast path string]]

    local parts = {}
    for part in path:gmatch("[^/\\]+") do
        table.insert(parts, part)
    end

    return Path.new(tostring(self), unpack(parts))
end

---@private
---@param other Path
---@return boolean
function Path:__eq(other)
    if #self.parts ~= #other.parts then return false end
    for i = 1, #self.parts do
        if self.parts[i] ~= other.parts[i] then return false end
    end
    return true
end

---Removes `n` parts from the end of the path
---@param n number
---@param from_back boolean?
---@return Path
function Path:pop(n, from_back)
    local parts = {}
    if not from_back then
        for i = n + 1, #self.parts do table.insert(parts, self.parts[i]) end
    else
        for i = 1, #self.parts - n do table.insert(parts, self.parts[i]) end
    end
    return Path.new(unpack(parts))
end

---@param recursive boolean?
---@return fun(): Path?
function Path:entries(recursive)
    return coroutine.wrap(function ()
        for entry in lfs.dir(tostring(self)) do
            if entry ~= "." and entry ~= ".." then
                local path = self/entry
                coroutine.yield(path)
                if recursive and path:type() == "directory" then
                    for subentry in path:entries(true) do
                        coroutine.yield(subentry)
                    end
                end
            end
        end
    end)
end


function Path:name()
    return self.parts[#self.parts]
end

---@param pattern string | fun(p: Path): boolean
---@return fun(): Path
function Path:find(pattern)
    return coroutine.wrap(function ()
        ---@param dir Path
        local function look_in_dir(dir)
            for entry in dir:entries() do
                if entry:type() == "directory" then
                    look_in_dir(entry)
                elseif entry:type() == "file" then
                    if type(pattern) == "function" then
                        if pattern(entry) then coroutine.yield(entry) end
                    elseif entry:name():find(pattern) then
                        coroutine.yield(entry)
                    end
                end
            end
        end

        look_in_dir(self)
    end)
end

---@return string?, string?
function Path:read_all()
    local f, err = io.open(tostring(self), "r+b")
    if not f then return nil, err end
    --[[ @cast f file* ]]
    local data = f:read("*a")
    f:close()
    return data
end

---@return string?
function Path:extension()
    local name = self.parts[#self.parts]
    local i = name:find("%.")
    if i then return name:sub(i + 1) end
end

function Path:remove_extension()
    local parts = {}
    for i = 1, #self.parts - 1 do table.insert(parts, self.parts[i]) end
    table.insert(parts, (self:name():gsub("%..*$", "")))
    return Path.new(unpack(parts))
end

---@param extension string
function Path:add_extension(extension)
    local parts = {}
    for i = 1, #self.parts - 1 do table.insert(parts, self.parts[i]) end
    table.insert(parts, self:name().."."..extension)
    return Path.new(unpack(parts))
end

---@private
Path.__sub = Path.pop

---@private
---@return string
function Path:__tostring() return table.concat(self.parts, seperator) end

---@param type? "file" | "directory"
---@return Path?, string?
function Path.temporary(type)
    local path = os.tmpname()
    if is_windows then path = path:sub(1, -5) end -- remove the last 6 characters (".tmp\n")
    local p = Path.new(path)

    if type ~= "file" then
        local ok, err = p:remove()
        if not ok then return nil, err end
        if type == "directory" then
            ok, err = p:create_directory()
            if not ok then return nil, err end
        end
    end

    return p
end

---@param dest Path
function Path:copy_to(dest)
    local src = tostring(self)
    local dest = tostring(dest)
    local src_file, err = io.open(src, "rb")
    if not src_file then return false, err end

    local dest_file, err = io.open(dest, "w+b")
    if not dest_file then return false, err end

    local data = src_file:read("*a")
    dest_file:write(data)

    src_file:close()
    dest_file:close()
    return true
end

---@return boolean, string?
function Path:remove()
    local mode = self:type()
    if mode == "directory" then
        for entry in self:entries() do
            local ok, err = entry:remove()
            if not ok then return false, err end
        end
        return lfs.rmdir(tostring(self))
    elseif mode == "file" then return os.remove(tostring(self))
    else return false, "Path \""..tostring(self).."\" is not a file or directory" end
end

function Path:move_to(dest)
    local ok, err = self:copy_to(dest)
    if not ok then return false, err end

    return self:remove()
end

---@return Path
function Path:parent_directory()
    local parts = {}
    for i = 1, #self.parts - 1 do table.insert(parts, self.parts[i]) end
    return Path.new(unpack(parts))
end

--[[
```lua
local cwd = Path.current_directory
local some_long_path = /my/current/dir/and/then/some/other/dir
local dir = some_long_path:relative_to(cwd)
print(dir) -- prints "and/then/some/other/dir"
```
]]
---@param base Path
---@return Path?, string?
function Path:relative_to(base)
    local base_parts = base.parts
    local self_parts = self.parts

    local i = 1
    while i <= #base_parts and i <= #self_parts and base_parts[i] == self_parts[i] do i = i + 1 end

    if i == #base_parts + 1 then
        local parts = {}
        for j = i, #self_parts do table.insert(parts, self_parts[j]) end
        return Path.new(unpack(parts)), nil
    end
end

---@return boolean
function Path:is_absolute()
    return self.parts[1] == seperator
end

--[[
Adapted from https://github.com/lunarmodules/Penlight/blob/f3d8e9967d3764327c8b9564198245b3ac316c65/lua/pl/path.lua#L499
```lua
--- Replace a starting '~' with the user's home directory.
-- In windows, if HOME isn't set, then USERPROFILE is used in preference to
-- HOMEDRIVE HOMEPATH. This is guaranteed to be writeable on all versions of Windows.
-- @string P A file path
-- @treturn[1] string The file path with the `~` prefix substituted, or the input path if it had no prefix.
-- @treturn[2] nil
-- @treturn[2] string Error message if the environment variables were unavailable.
function path.expanduser(P)
    assert_string(1,P)
    if P:sub(1,1) ~= '~' then
        return P
    end

    local home = getenv('HOME')
    if (not home) and (not path.is_windows) then
        -- no more options to try on Nix
        return nil, "failed to expand '~' (HOME not set)"
    end

    if (not home) then
        -- try alternatives on Windows
        home = getenv 'USERPROFILE'
        if not home then
            local hd = getenv 'HOMEDRIVE'
            local hp = getenv 'HOMEPATH'
            if not (hd and hp) then
              return nil, "failed to expand '~' (HOME, USERPROFILE, and HOMEDRIVE and/or HOMEPATH not set)"
            end
            home = hd..hp
        end
    end

    return home..sub(P,2)
end
```
]]
---@return Path?, string?
function Path:expand()
    if self.parts[1] == "~" then
        local home = os.getenv("HOME")
        if not home then
            if is_windows then
                home = os.getenv("USERPROFILE")
                if not home then
                    local hd = os.getenv("HOMEDRIVE")
                    local hp = os.getenv("HOMEPATH")
                    if not (hd and hp) then
                        return nil, "failed to expand '~' (HOME, USERPROFILE, and HOMEDRIVE and/or HOMEPATH not set)"
                    end
                    home = hd..hp
                end
            else
                return nil, "failed to expand '~' (HOME not set)"
            end
        end

        local parts = {}
        for i = 2, #self.parts do table.insert(parts, self.parts[i]) end
        return Path.new(home, unpack(parts)), nil
    end

    return self
end

---@return Path
function Path:absolute()
    if self:is_absolute() then return self end
    return Path.current_directory/self
end

---@return integer?, string?
function Path:size()
    local size = 0
    if self:type() == "directory" then
        for entry in self:entries() do
            local entry_size, err = entry:size()
            if not entry_size then return nil, err end
            size = size + entry_size
        end
    else
        local f, err = self:open("file", "rb")
        if not f then return nil, err end
        size = f:seek("end")
        f:close()
    end
    return size
end

-- setmetatable(Path, { __call = function(_, ...) return Path.new(...) end })
Path.current_directory = Path.new(lfs.currentdir())
return Path
