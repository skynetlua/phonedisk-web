local skynet = require "skynet"
local Cache = require "meiru.lib.cached"
local server = require "meiru.util.server"

-------------------------------------------------------
--command
-------------------------------------------------------
local _cache
local function init()
    _cache = Cache.new()
end

local command = {}

function command.get(ckey)
    -- log("command.get ckey =", ckey)
    assert(ckey)
    local vdata, deadline = _cache:get(ckey)
    return vdata, deadline
end

function command.remove(ckey)
    assert(ckey)
    return _cache:remove(ckey)
end

function command.set(ckey, vdata, timeout)
    -- log("command.set ckey =", ckey)
    assert(ckey)
    assert(type(vdata) == "string", "need vdata = skynet.packstring(vdata)")
    return _cache:set(ckey, vdata, timeout)
end

server(command, init)
