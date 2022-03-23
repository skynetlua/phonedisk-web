local ok, skynetlib = pcall(require, "skynetlib.c")
skynetlib = ok and skynetlib

if skynetlib then
local cmodels = {
	["skynet.core"] = 1,
	["skynet.socketdriver"] = 1,
	["skynet.stm"] = 1,
	["skynet.sharetable.core"] = 1,
	[ "skynet.sharedata.core"] = 1,
	["skynet.profile"] = 1,
	["skynet.netpack"] = 1,
	["skynet.mysqlaux.c"] = 1,
	["skynet.multicast.core"] = 1,
	["skynet.mongo.driver"] = 1,
	["skynet.memory"] = 1,
	["skynet.debugchannel"] = 1,
	["skynet.datasheet.core"] = 1,
	["skynet.crypt"] = 1,
	["client.crypt"] = 1,
	["skynet.cluster.core"] = 1,
	["bson"] = 1,
	["ltls.c"] = 1,
	["ltls.init.c"] = 1,
	["cjson"] = 1,
	["lfs"] = 1,
	["lpeg"] = 1,
	["sproto.core"] = 1,
	["md5.core"] = 1,
	["protobuf.c"] = 1
}

local skynetlib = require "skynetlib.c"
local rawrequire = require
function require(model_path)
	-- print("require model_path:", model_path)
	if cmodels[model_path] then
		return skynetlib.load(model_path)
	else
		return rawrequire(model_path)
	end
end

end


local args = {}
for word in string.gmatch(..., "%S+") do
	table.insert(args, word)
end

SERVICE_NAME = args[1]

local main, pattern

local err = {}
for pat in string.gmatch(LUA_SERVICE, "([^;]+);*") do
	local filename = string.gsub(pat, "?", SERVICE_NAME)
	local f, msg = loadfile(filename)
	if not f then
		table.insert(err, msg)
	else
		pattern = pat
		main = f
		break
	end
end

if not main then
	error(table.concat(err, "\n"))
end

LUA_SERVICE = nil
package.path , LUA_PATH = LUA_PATH
package.cpath , LUA_CPATH = LUA_CPATH

local service_path = string.match(pattern, "(.*/)[^/?]+$")

if service_path then
	service_path = string.gsub(service_path, "?", args[1])
	package.path = service_path .. "?.lua;" .. package.path
	SERVICE_PATH = service_path
else
	local p = string.match(pattern, "(.*/).+$")
	SERVICE_PATH = p
end

if LUA_PRELOAD then
	local f = assert(loadfile(LUA_PRELOAD))
	f(table.unpack(args))
	LUA_PRELOAD = nil
end

_G.require = (require "skynet.require").require

main(select(2, table.unpack(args)))
