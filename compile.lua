#!/usr/bin/env ./lua

local Path = require("utilities.Path")
local hash = require("utilities.hash")
local tablex = require("pl.tablex")
local pretty = require("pl.pretty")
local sysdetect = require("sysdetect")
local LUAOT_GIT_REPO = "https://github.com/Frityet/lua-aot-5.4"
local LUAOT_GIT_BRANCH = "self-loader"

---@type "windows" | "macosx" | "linux" | string
local operating_system = sysdetect.detect()

local DEBUG = os.getenv("DEBUG") == "1"
local CC = os.getenv("CC") or "cc"
local CFLAGS = os.getenv("CFLAGS") or "-Os -fPIC"
local LD = os.getenv("LD") or CC
local LDFLAGS = os.getenv("LDFLAGS") or "-Os -flto"
local LIBS = os.getenv("LIBS") or ""
local AR = os.getenv("AR") or "ar"
local ARFLAGS = os.getenv("ARFLAGS") or "rcs"

---@type { [string] : string, ["$!main!$"]: string }
local dumped_mods = assert(dofile("dumped-modules.lua"), "You must run the program once with `./dump-modules.lua` before trying to compile!")

if DEBUG then
    print("Compile info:")
    pretty {
        CC = CC,
        CFLAGS = CFLAGS,
        LD = LD,
        LDFLAGS = LDFLAGS,
        LIBS = LIBS,
        AR = AR,
        ARFLAGS = ARFLAGS,
        OS = operating_system,
        DEBUG = DEBUG,
        ["modules to compile"] = dumped_mods
    }
end

--#region Helper functions

local l_execute = os.execute
---os.execute that properly handles 5.1 and 5.4
---@param cmd string
---@param debug boolean?
---@return boolean
local function execute(cmd, debug)
    --debug == nil will still print
    if debug ~= false then
        print("$ "..cmd)
    end

    if _VERSION == "Lua 5.1" then
        return l_execute(cmd) == 0
    else
        local _, _, code = l_execute(cmd)
        return code == 0
    end
end

---os.execute that properly handles 5.1 and 5.4
---@param ... string | Path
local function exec(...)
    local cmd = ""

    for i = 1, select("#", ...) do
        cmd = cmd..tostring(select(i, ...)).." "
    end
    if not execute(cmd, DEBUG) then
        error("Failed to execute command: "..cmd)
    end
end

---@param ... string
---@return fun(env: { [string]: Path | string })
local function luarocks(...)
    local cmd = "luarocks "
    for i = 1, select("#", ...) do
        cmd = cmd..tostring(select(i, ...)).." "
    end
    return function(env)
        local env_str = ""
        for k, v in pairs(env) do
            env_str = env_str..k.."=\""..tostring(v).."\" "
        end
        if not execute(cmd..env_str, DEBUG) then
            error("Failed to execute command: "..cmd)
        end
    end
end

---@param siz integer
local function human_size(siz)
    return siz < 1024 and string.format("%d B", siz) or siz < 1024^2 and string.format("%.2f KiB", siz/1024) or string.format("%.2f MiB", siz/1024^2)
end


---Unicode progress bar
---@param current integer
---@param total integer
---@return string
local function progress_bar(current, total)
    local width = 80
    local percent = current/total
    local bar = string.rep("■", math.floor(percent*width))
    return string.format("[\x1b[32m%s\x1b[0m%s] \x1b[33m(%d/%d) %.2f%%", bar, string.rep(" ", width-math.floor(percent*width)), current, total, percent*100)
end

---@param path Path
---@return string
local function hash_file(path)
    local f = assert(path:open("file", "rb"))
    local h = hash.sha256()
    for chunk in f:lines(4096) do
        h(chunk)
    end
    f:close()
    return h() --[[@as string]]

end

--#endregion

--#region Preperation

local luaot_dir = Path.current_directory/"lua-aot"
if not luaot_dir:exists() then
    exec("git", "clone", "--branch", LUAOT_GIT_BRANCH, LUAOT_GIT_REPO, luaot_dir, "--depth 1")
    exec("make", "-j", "-C", luaot_dir, "guess")
end
luaot_dir = luaot_dir/"src" --all the files are built into here

local out_dir = Path.current_directory/"out"

---replace lua_modules with our out dir
for k, v in pairs(dumped_mods) do
    dumped_mods[k] = v:gsub("lua_modules", out_dir:name())
end

luarocks("make", "--tree=\""..tostring(out_dir).."\"", "--lua-version=5.4") {
    LD          = Path.current_directory/"ar-wrapper.sh",
    LIB_EXTENSION   = "a",
    LUA             = luaot_dir/"lua",
    LUAC            = luaot_dir/"luac",
    LUA_DIR         = luaot_dir,
    LUA_INCDIR      = luaot_dir,
    LUA_LIBDIR      = luaot_dir,
    LUALIB          = luaot_dir/"liblua.a",
    LUA_LIBDIR_FILE = luaot_dir/"liblua.a",
}

--#endregion

--#region Compilation

--now we start compiling
local obj_dir = out_dir/"obj"
obj_dir:create_directory()

---@param modname string
---@return string
local function modname_to_symname(modname)
    return "lm_"..hash.md5(modname)
end

---@class TranspiledModule
---@field is_main boolean
---@field module_name string
---@field symbol_name string
---@field path Path
---@field dependent_modules Path[]

local total_module_count = #tablex.filter(tablex.values(dumped_mods), function(v) return Path.new(v):extension() == "lua" end)
local transpiled_lua_file_count = 0

local cmodule_hash_file = Path.current_directory/"cmodule-hashes.lua"

---Used for detecting if there are any changes in the lua files, the C files will have the same hash if the lua file hasn't changed
---@type { [string] : string }
local cmodule_hashes
if cmodule_hash_file:exists() then
    cmodule_hashes = assert(dofile(tostring(cmodule_hash_file)))
else
    cmodule_hashes = {}
end

---@param modname string
---@param path Path
---@param is_main boolean
---@return TranspiledModule
local function compile_lua(modname, path, is_main)
    --luaot creates multiple C files for each lua file, so we need to create a directory for each lua file
    local name = is_main and "lm_main_mod" or modname_to_symname(modname)
    local comp_dir = obj_dir/name
    comp_dir:create_directory()

    local cfile = (comp_dir/name):remove_extension():add_extension("c")
    if is_main then
        exec(tostring(luaot_dir/"luaot"), path, "-o", cfile, "-m", name, "-e", "-i", operating_system == "windows" and "windows" or "posix")
    else
        exec(tostring(luaot_dir/"luaot"), path, "-o", cfile, "-m", name)
    end

    transpiled_lua_file_count = transpiled_lua_file_count + 1
    print(string.format("\x1b[33m[%d/%d (%.2f%%)] \x1b[32mTranspiled lua file \x1b[34m%s (%s)\x1b[0m", transpiled_lua_file_count, total_module_count, transpiled_lua_file_count/total_module_count*100, modname, path:relative_to(Path.current_directory) or path))

    ---@type TranspiledModule
    local mod = {
        is_main = is_main,
        module_name = modname,
        symbol_name = name,
        path = cfile,
        dependent_modules = {}
    }

    --find all files that depend on this module, these are all the other files put into comp_dir
    for file in comp_dir:entries() do
        if file:extension() == "c" and file:name() ~= cfile:name() then
            table.insert(mod.dependent_modules, file)
        end
    end

    return mod
end

---@type TranspiledModule
---@type { [string] : TranspiledModule }
local c_files = {}
print("--- Transpiling Lua files ---")
for modname, path in pairs(dumped_mods) do
    local p = Path.new(path)
    if p:extension() == "lua" then
        c_files[modname] = compile_lua(modname, p, modname == "$!main!$")
    end
end

--when compiling the main, we need to know the order of the files
local mod_def_list = "-D'LUAOT_INTERNAL_SEARCHER_MODULES="
local first = true
for modname, mod in pairs(c_files) do
    mod_def_list = mod_def_list..string.format('%s{ "%s", "%s" }', (first and "" or ", "), modname, mod.symbol_name)
    first = false
end
mod_def_list = mod_def_list.."'"

local makefile_path = out_dir/"Makefile"
local makefile = assert(makefile_path:open("file", "w+b"))

---@type Path[]
local ar_files = {}
print("--- Compiling C files ---")
for modname, mod in pairs(c_files) do
    --check if the lua file has changed
    local hash = hash_file(mod.path)
    local ar_file = (obj_dir/mod.symbol_name):add_extension("a")
    if cmodule_hashes[modname] == hash then
        print("\x1b[33mSkipped \x1b[34m"..modname.."\x1b[0m - \x1b[32mNo changes\x1b[0m")
        table.insert(ar_files, ar_file)
        goto continue
    end

    --first, compile all of them to objects
    ---@type Path[]
    local objects = {}
    local compmsg = string.format("\x1b[33m[%d/%d (%.2f%%)] \x1b[32mCompiling \x1b[34m%s\x1b[0m... ",  #ar_files, total_module_count, #ar_files/total_module_count*100, modname)
    io.write("\x1b[?25l"):flush()
    for i, dep in ipairs(mod.dependent_modules) do
        exec(CC, CFLAGS, "-c", dep, "-o", dep:add_extension("o"), "-I", luaot_dir)
        io.write(compmsg, progress_bar(i, #mod.dependent_modules), "\r"):flush()
        table.insert(objects, dep:add_extension("o"))
    end
    if not mod.is_main then
        exec(CC, CFLAGS, "-c", mod.path, "-o", mod.path:add_extension("o"), "-I", luaot_dir)
    end
    exec(CC, CFLAGS, "-c", mod.path, "-o", mod.path:add_extension("o"), "-I", luaot_dir, mod_def_list)
    table.insert(objects, mod.path:add_extension("o"))

    exec(AR, ARFLAGS, ar_file, table.unpack(objects))
    table.insert(ar_files, ar_file)
    local arsize = ar_file:size()
    local arsize_str = string.format("%s, %s", #mod.dependent_modules..(#mod.dependent_modules == 1 and " function" or " functions"), arsize and human_size(arsize) or "unknown size")
    print(string.format("\x1b[?25h\r\x1b[33m[%d/%d (%.2f%%)] \x1b[32mCompiled \x1b[34m%s\x1b[0m \x1b[33m(%s)\x1b[0m\x1b[0K", #ar_files, total_module_count, #ar_files/total_module_count*100, modname, arsize_str))

    cmodule_hashes[modname] = hash
    ::continue::
end

local f = assert(cmodule_hash_file:open("file", "w+b"))
f:write("return ", pretty.write(cmodule_hashes))
f:close()

---@type { [string] : boolean }
local luaopens = {}
--add the .a files from the dumped modules
for modname, path in pairs(dumped_mods) do
    local p = Path.new(path)
    --the .so and .dlls are actually archives
    if p:extension() == "a" or p:extension() == "so" or p:extension() == "dll" then
        --use nm to find any luaopen functions (could be multiple)
        local f = assert(io.popen("nm -U "..tostring(p), "r"))

        for sym in f:lines() do
            --[[@cast sym string]]
            local luaopen = sym:match("[tT] _?luaopen_(.+)")
            if luaopen then luaopens[luaopen] = true end
        end

        f:close()

        table.insert(ar_files, p)
        local arsize = p:size()
        print(string.format("\x1b[32mAdded \x1b[34m"..modname.."\x1b[0m (\x1b[33m%s\x1b[0m)", arsize and human_size(arsize) or "unknown size"))
    end
end
--finally, compile it all together
local mainmod = c_files["$!main!$"]
exec(CC, CFLAGS, "-c", mainmod.path, "-o", mainmod.path:add_extension("o"), "-I", luaot_dir, mod_def_list)

--#endregion

--#region Linking

local out_file = out_dir/(operating_system == "windows" and "main.exe" or "main")

local retained_symbol_list_path = assert(Path.temporary())
local f = assert(retained_symbol_list_path:open("file", "w+b"))
for modname, mod in pairs(c_files) do
    f:write((operating_system == "macosx" and "_" or "").."luaopen_"..mod.symbol_name, "\n")
end

for luaopen in pairs(luaopens) do
    f:write((operating_system == "macosx" and "_" or "").."luaopen_"..luaopen, "\n")
end

f:close()

if operating_system == "linux" or operating_system == "windows" then
    LDFLAGS = LDFLAGS.." -Wl,--retain-symbols-file='"..tostring(retained_symbol_list_path).."'"
elseif operating_system == "macosx" then
    LDFLAGS = LDFLAGS.." '-Wl,-exported_symbols_list,"..tostring(retained_symbol_list_path).."'"
else
    io.stderr:write("Unsupported operating system: `", operating_system, "`\n")
end

exec(LD, LDFLAGS, "-o", out_file, "-L", luaot_dir, "-llua", LIBS, mainmod.path:add_extension("o"), table.unpack(ar_files))

local outsiz = out_file:size()
print(string.format("\x1b[32mLinked \x1b[34m%s\x1b[0m \x1b[33m(%s)\x1b[0m", out_file, outsiz and human_size(outsiz) or "unknown size"))

makefile:close()

--#endregion
