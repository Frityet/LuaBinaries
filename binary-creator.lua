local easyhttp = require("easyhttp")
local Path = require("Path")
---@type argparse
local argparse = require("argparse")
local pretty = require("pl.pretty")
local tablex = require("pl.tablex")
local sysdetect = require("sysdetect")
local builders = require("builders")

local RELEASE_CACHE_PATH = Path.current_directory/"releases.lua"
local LUA_RELEASE_PAGE_URL = "https://www.lua.org/ftp/"
local LUAJIT_RELEASE_ARCHIVE_URL = "https://github.com/LuaJIT/LuaJIT/archive/refs/heads/v2.1.zip"

---@alias OS            "linux"  | "macosx" | "windows"
---@alias Architecture  "x86_64" | "arm64"  | "aarch64"

local l_execute = os.execute
---os.execute that properly handles 5.1 and 5.4
---@param cmd string
---@param debug boolean?
---@return boolean
function os.exec(cmd, debug)
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

---@return OS, Architecture
local function get_host_info()
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
local function check_program(name)
    local host_os = get_host_info()
    local ok = false
    if host_os == "windows" then
        ok = os.exec("where "..name.." >nul 2>&1", false)
    else
        ok = os.exec("command -v "..name.." >/dev/null 2>&1", false)
    end

    return ok and name or nil
end


---@return { [string] : string }
local function fetch_lua_releases()
    local body, code, headers = easyhttp.request(LUA_RELEASE_PAGE_URL )
    if not body then error("Could not create request: "..code) end
    --[[@cast code integer]]
    --[[@cast body string]]
    if code ~= 200 then
        error("Failed to fetch lua releases: "..(body or ""))
    end

    local releases = {
        ["LuaJIT-2.1.0"] = LUAJIT_RELEASE_ARCHIVE_URL,
    }
    for release in body:gmatch('HREF="lua%-([%d.]+)%.tar%.gz"') do
        releases[release] = string.format("https://www.lua.org/ftp/lua-%s.tar.gz", release)
    end
    return releases
end

---@type { [string] : string }
local releases
if not RELEASE_CACHE_PATH:exists() then
    releases = fetch_lua_releases()
    local f = assert(RELEASE_CACHE_PATH:open("file", "w+b"))
    f:write("return ", pretty.write(releases))
    f:close()
else
    releases = dofile(tostring(RELEASE_CACHE_PATH))
end

local host_os, host_arch = get_host_info()

local found_cc = check_program(os.getenv("CC") or "cc")
                            or check_program("gcc")
                            or check_program("clang")
                            or "cc"
local found_make = check_program(os.getenv("MAKE") or "make")
                            or check_program("gmake")
                            or check_program("make")
                            or check_program("mingw32-make")

local versions = tablex.keys(releases)
table.sort(versions)
local parser = argparse("binary-creator", "Automatically compile and package lua binaries")
parser  :argument "version"
        :description "The version of lua to compile"
        :choices(versions)
        :args(1)

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
        :description "The make program to use, optional on Windows"
        :default(found_make)
        :args(1)

parser:add_help(true)
parser:add_complete()

---@class CLIArgs
---@field version string
---@field os OS
---@field arch Architecture
---@field c_compiler string
---@field linker string
---@field make string?
local args = parser:parse()

if not args.c_compiler then error("No C compiler found") end
if not args.linker then error("No linker found") end

if args.version ~= "LuaJIT-2.1.0" then
    builders.puc[args.os](args, releases[args.version])
end
