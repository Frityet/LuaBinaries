local easyhttp = require("easyhttp")
local Path = require("Path")
local tar = require("luarocks.tools.tar")
local zip = require("luarocks.tools.zip")

---@param args CLIArgs
---@param url string
return function (args, url)
    local out_archive_path = Path.temporary("directory")/string.format("lua-%s.tar.gz", args.version)
    do
        local out_archive = assert(out_archive_path:open("file", "w+b"))
        print("Downloading "..url)
        local response, err = easyhttp.request(url, {
            method = "GET",
            on_progress = function(dltotal, dlnow, ultotal, ulnow)
                io.write(string.format("\rDownloading %s: %.2f%%", url, math.floor(dlnow / dltotal * 100))):flush()
            end,
            output_file = out_archive
        })
        if not response then error(string.format("Failed to fetch %s: %s", url, err)) end
        out_archive:close()
    end
    print("\nDownloaded to "..tostring(out_archive_path))
end
