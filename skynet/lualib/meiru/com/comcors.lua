local Com = require "meiru.com.com"

local ComCors = class("ComCors", Com)

--跨域限制
----------------------------------------------
--ComCors
----------------------------------------------
function ComCors:ctor()
end

function ComCors:match(req, res)
	local app = req.app
	local app_host = app.get('host')
	if app_host then
		local host = req.get('host')
		if not host then
			return false
		end
		if app_host == host then
			return
		end
		local idx = host:find(":", 1, true)
		if idx then
			host = host:sub(1, idx-1)
		end
		if app_host ~= host then
			return false
		end
	end
end

return ComCors
