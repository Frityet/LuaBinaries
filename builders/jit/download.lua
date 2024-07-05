local easyhttp = require("easyhttp")
local Path = require("utilities.Path")
local zip = require("zip")

---@param zipfile Path
---@param out_dir Path
---@return boolean, string?
local function recursive_unzip(zipfile, out_dir)
    local z, err = zip.open(tostring(zipfile))
    if not z then return false, "Failed to open zip file: "..err end
    for file in z:files() do
        if file.compressed_size == 0 then goto next end
        local path = out_dir/file.filename
        path:parent_directory():create_directory(true)
        local f = assert(path:open("file", "w+b"))
        local compressed_f, err = z:open(file.filename)
        if not compressed_f then return false, "Failed to open file in zip: "..err end
        f:write(compressed_f:read("*a"))
        f:close()

        ::next::
    end

    -- closing the zip file causes a sigsegv
    -- z:close()
    return true
end

---@param url string
---@return Path
return function (url)
    local tmpdir = assert(Path.temporary("directory"))
    local out_archive_path = tmpdir/"luajit.zip"
    do
        local out_archive = assert(out_archive_path:open("file", "w+b"))
        local response, err = easyhttp.request(url, {
            method = "GET",
            follow_redirects = true,
            on_progress = function(dltotal, dlnow, ultotal, ulnow)
                if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") ~= "1" then
                    io.write(string.format("\rDownloading %s: %.2f%%", url, dlnow / dltotal * 100)):flush()
                end
            end,
            output_file = out_archive
        })
        if not response then error(string.format("Failed to fetch %s: %s", url, err)) end
        out_archive:close()
    end
    print("\nDownloaded to "..tostring(out_archive_path))

    local ok, err = recursive_unzip(out_archive_path, tmpdir)
    if not ok then error("Failed to extract zip: "..err) end
    return tmpdir/"LuaJIT-2.1"
end
