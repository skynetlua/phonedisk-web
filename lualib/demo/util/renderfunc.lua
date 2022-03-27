
local filed = require "meiru.server.filed"
local config = include "config"

local table = table

local static_host = config.site_static_host or ""
local static_path = config.static_path or "./assets/static/"

--------------------------------------------------
--exports
--------------------------------------------------
local exports = {}

function exports.static_file(filePath)
    if filePath:find('http', 1, true) == 1 or filePath:find('https', 1, true) == 1 or filePath:find('//', 1, true) == 1 then
        return filePath
    end
    local file_md5 = filed.file_md5(path.joinpath(static_path, filePath))
    if file_md5 then
        if filePath:find('?', 1, true) then
            filePath = filePath .. "&fv=" .. file_md5
        else
            filePath = filePath .. "?fv=" .. file_md5
        end
    else
        log("staticFile not find filePath =", static_path..filePath)
    end
    if #static_host == 0 then
        return filePath
    end
    return path.joinpath(static_host, filePath)
end

function exports.Loader(js, css)
    local target = {}
    if js then
        target[path.extname(js)] = js
    end
    if css then
        target[path.extname(css)] = css
    end

    local self = {}
    local script = {
        assets = {},
        target = target[".js"]
    }
    local style = {
        assets = {},
        target = target[".css"]
    }

    ------------------------------
    local Loader = self

    function Loader.js(src)
        table.insert(script.assets, src)
        return self
    end
    function Loader.css(href)
        table.insert(style.assets, href)
        return self
    end
    function Loader.dev(prefix)
        local htmls = {}
        prefix = prefix or ''
        local version = '?v=' .. os.time()
        for _,asset in ipairs(script.assets) do
            table.insert(htmls, '<script src="'.. prefix .. asset .. version.. '"></script>\n')
        end
        for _,asset in ipairs(style.assets) do
            table.insert(htmls, '<link rel="stylesheet" href="' .. prefix .. asset .. version ..'" media="all" />\n')
        end
        return table.concat(htmls)
    end
    function Loader.pro(CDNMap, prefix)
        if not CDNMap then
            return ""
        end
        prefix = prefix or ''
        local htmls = {}
        local scriptTarget = script.target
        if scriptTarget and CDNMap[scriptTarget] then
            table.insert(htmls, '<script src="' .. prefix .. CDNMap[scriptTarget] .. '"></script>\n')
        end
        local styleTarget = style.target
        if styleTarget and CDNMap[styleTarget] then
            table.insert(htmls, '<link rel="stylesheet" href="' .. prefix .. CDNMap[styleTarget] .. '" media="all" />\n')
        end
        return table.concat(htmls)
    end
    function Loader.done(CDNMap, prefix, mini)
        prefix = prefix or ""
        if #prefix > 0 and prefix:byte(#prefix) == '/' then
            prefix = prefix:sub(1, #prefix-1)
        end
        return mini and self.pro(CDNMap, prefix) or self.dev(prefix)
    end
    return self
end


return exports