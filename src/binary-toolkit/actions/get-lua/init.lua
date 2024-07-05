local Path = require("binary-toolkit.utilities.Path")
local easyhttp = require("easyhttp")
local builders = require("binary-toolkit.actions.get-lua.builders.init")
local utilities = require("binary-toolkit.utilities")

local export = {}

local RELEASE_CACHE_PATH = Path.current_directory/"releases.lua"
local LUA_RELEASE_PAGE_URL = "https://www.lua.org/ftp/"
local LUAJIT_RELEASE_ARCHIVE_URL = "https://github.com/LuaJIT/LuaJIT/archive/refs/heads/v2.1.zip"


---@return { [string] : string }
local function fetch_lua_releases()
    local body, code, headers = easyhttp.request(LUA_RELEASE_PAGE_URL)
    if not body then error("Could not create request: "..code) end
    --[[@cast code integer]]
    --[[@cast body string]]
    if code ~= 200 then
        error("Failed to fetch lua releases: "..(body or ""))
    end

    local releases = {
        ["LuaJIT"] = LUAJIT_RELEASE_ARCHIVE_URL,
    }
    for release in body:gmatch('HREF="lua%-([%d.]+)%.tar%.gz"') do
        releases[release] = string.format("https://www.lua.org/ftp/lua-%s.tar.gz", release)
    end
    return releases
end

---@return { [string] : string }
function export.get_releases()
    local releases
    if not RELEASE_CACHE_PATH:exists() then
        releases = fetch_lua_releases()
        local f = assert(RELEASE_CACHE_PATH:open("file", "w+b"))
        f:write("return {", "\n")
        for k, v in pairs(releases) do
            f:write(string.format('    ["%s"] = "%s";\n', k, v))
        end
        f:write("}\n")
        f:close()
    else
        releases = dofile(tostring(RELEASE_CACHE_PATH))
    end

    return releases
end

export.name = "get-lua"
export.description = "Download and compile Lua releases"

---@param cmd argparse.Command
function export.configure_command(cmd)
    cmd :argument "version"
        :description "The version of lua to compile"
        :choices((function()
            local versions = utilities.keys(export.get_releases())
            table.sort(versions)
            return versions
        end)())
        :args(1)

    cmd :option "-o --output"
        :description "The output directory"
        :args(1)

    cmd :option "-j --jobs"
        :description "The number of jobs to run in parallel"
        :args(1)
        :default((function ()
            local nproc = io.popen("nproc", "r")
            if nproc then
                local jobs = nproc:read("*a"):gsub("\n", "")
                nproc:close()
                return jobs
            end
            return 4
        end)())
end

---@class GetLuaArguments : BaseArguments
---@field version string
---@field output Path
---@field jobs integer

---@param args GetLuaArguments
---@return integer
function export.action(args)
    if not args.c_compiler then error("No C compiler found") end
    if not args.linker then error("No linker found") end
    if not args.output then error("No output directory specified")
    else
        args.output = assert(Path.new(args.output):expand()):absolute()
    end

    if args.version ~= "LuaJIT" then
        builders.puc[args.os](args, export.get_releases()[args.version])
    else
        builders.jit[args.os](args, LUAJIT_RELEASE_ARCHIVE_URL)
    end

    return 0
end

return export
