
local Com = require "meiru.com.com"
local url = require "meiru.util.url"
local systemd = require "meiru.server.systemd"

local sfind = string.find
----------------------------------------------
--ComPath
----------------------------------------------
local ComPath = class("ComPath", Com)

function ComPath:ctor()
end

function ComPath:match(req, res)
    local path, query = url.parse_url(req.rawurl)

    local idx = path:find("/", 1, true)
    if idx ~= 1 then
        log("[attack] path =", path)
        res.is_end = true
		return false
	end
    -- idx = sfind(path, "..", 1, true)
    -- if idx then
    --     log("[attack] path =", path)
    --     systemd.kick(req.ip)
    --     res.is_end = true
    --     return false
    -- end
    idx = sfind(path, "./", 1, true)
    if idx then
        log("[attack] path =", path)
        systemd.kick(req.ip)
        res.is_end = true
        return false
    end
    idx = sfind(path, ".\\", 1, true)
    if idx then
        log("[attack] path =", path)
        systemd.kick(req.ip)
        res.is_end = true
        return false
    end
    idx = sfind(path, "//", 1, true)
    if idx then
        log("[attack] path =", path)
        systemd.kick(req.ip)
        res.is_end = true
        return false
    end
    idx = sfind(path, "\\", 1, true)
    if idx then
        log("[attack] path =", path)
        systemd.kick(req.ip)
        res.is_end = true
        return false
    end
    req.path = path
    if query and #query > 0 then
        req.query = url.parse_query(query)
    else
    	req.query = {}
    end
    req.path_params = req.path:split("/")
end

return ComPath
