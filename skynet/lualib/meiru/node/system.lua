local Com = require "meiru.com.com"
----------------------------------------------
--ComSystem
----------------------------------------------

local GMs = {
	['oCHWR4lrP4uuiWqs8XG7v5iHIPGEoCHWR4lrP4uuiWqs8XG7v5iHIPGE'] = true
}
local ComSystem = class("ComSystem", Com)

function ComSystem:ctor()
end

function ComSystem:match(req, res)
	local token = req.query["token"]
	if type(token) ~= "string" or #token < 10 then
		return false
	end
	if not GMs[token] then
		return false
	end
end


local function testIp(ip)
    local items = string.split(ip, ".")
    if #items ~= 4 then
        return false
    end
    for _,item in ipairs(items) do
        if #item > 3 then
            return false
        end
        item = tonumber(item)
        if item < 0 then
            return false
        end
        if item > 255 then
            return false
        end
    end
    return true
end

------------------------------------------
local systemd = require "meiru.server.systemd"

local cmds = {
	["network"] = function(req, res, page, limit)
		local data = systemd.net_stat(page, limit)
		local retval = {
			code  = 0,
			msg   = "",
			count = #data,
			data  = data,
		}
		return retval
	end,

	["service"] = function(req, res, page, limit)
		local data = systemd.service_stat(page, limit)
		local stat = systemd.mem_stat()
		local retval = {
			code  = 0,
			msg   = "",
			count = #data,
			data  = data,
			total = stat.total,
			block = stat.block
		}
		return retval
	end,

	["visit"] = function(req, res, page, limit)
		local data = systemd.client_stat()
		-- local region = ip2regiond.ip2region(req.ip)
		local retval = {
			code  = 0,
			msg   = "",
			count = #data,
			data  = data,
			addr  = req.addr,
			-- region = region,
		}
		return retval
	end,

	["router"] = function(req, res, page, limit)
		local data = req.app:treeprint()
		local retval = {
			code = 0,
			msg  = "",
			data = data,
		}
		return retval
	end,

	["online"] = function(req, res, page, limit)
		local data = systemd.online_stat()
		local retval = {
			code = 0,
			msg  = "",
			data = data,
		}
		return retval
	end,

	["system"] = function(req, res, page, limit)
		local data = systemd.system_stat()
		local retval = {
			code = 0,
			msg  = "",
			count = #data,
			data  = data,
		}
		return retval
	end,

	["kick"] = function(req, res, page, limit)
		local ip = req.query.ip
		if req.id == ip then
			log("self req.query =", req.query)
			return {
				code = 1,
				msg = "不能拉黑自己"
			}
		end
		if not testIp(ip) then
			log("bad req.query =", req.query)
			return {
				code = 1,
				msg = "不是IP"
			}
		end

		systemd.kick(ip)
		local retval = {
			code = 0,
			ip = ip
		}
		return retval
	end,

	["db_tables"] = function(req, res, page, limit)
		local mysqldbd = require "meiru.db.mysqldbd"
		local tables = mysqldbd.table_descs()
		local retval = {
			code = 0,
			msg  = "",
			count = #tables,
			data  = tables,
		}
		return retval
	end,
}

-----------------------------------------
local meiru = require "meiru.meiru"

local router = meiru.router()

router.get('/system/index', function(req, res)
    local tab = req.query.tab
	local item = req.query.item
	local token = req.query.token
	res.set_layout(nil)
    return res.html('/system/index', {
    	url_path = "/system/index",
    	api_path = "/system/",
        token = token,
    	cur_tab = tab,
    	cur_item = item
    })
end)

router.get('/system/:what', function(req, res)
	local what = req.params.what
	local page = req.query.page
	local limit = req.query.limit
	local retval = cmds[what](req, res, page, limit)
	return res.json(retval)
end)


local node = router.node()
node:set_path("/system")
node:add("ComSystem")

return node
