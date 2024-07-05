local easyhttp = require("easyhttp")
local zlib = require("zlib")
local Path = require("binary-toolkit.utilities.Path")
local tar = require("binary-toolkit.utilities.tar")

---@param version string
---@param url string
---@return Path
return function (version, url)
    local tmpdir = Path.temporary("directory")
    local out_archive_path = tmpdir/string.format("lua-%s.tar.gz", version)
    do
        local out_archive = assert(out_archive_path:open("file", "w+b"))
        local response, err = easyhttp.request(url, {
            method = "GET",
            on_progress = function(dltotal, dlnow, ultotal, ulnow)
                if not DEBUG then
                    io.write(string.format("\rDownloading %s: %.2f%%", url, dlnow / dltotal * 100)):flush()
                end
            end,
            output_file = out_archive
        })
        if not response then error(string.format("Failed to fetch %s: %s", url, err)) end
        out_archive:close()
    end
    print("\nDownloaded to "..tostring(out_archive_path))

    local out_dir = tmpdir/"lua"
    assert(out_dir:create_directory())
    local tarfile_path = out_dir/"lua.tar"
    local tarfile = tarfile_path:open("file", "w+b")
    local inflate = zlib.inflate()
    for chunk in out_archive_path:open("file", "rb"):lines(1024) do
        local res, _1, _2, _3 = inflate(chunk)
        tarfile:write(res)
    end
    tarfile:close()

    assert(tar.untar(tostring(out_dir/"lua.tar"), tostring(out_dir)))
    print("Extracted to "..tostring(out_dir))

    return out_dir/(string.format("lua-%s", version))
end
