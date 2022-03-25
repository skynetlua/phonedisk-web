local Com = require "meiru.com.com"

----------------------------------------------
--ComInit
----------------------------------------------
local ComInit = class("ComInit", Com)

function ComInit:ctor()
end

function ComInit:match(req, res)
	if req.app.get('x-powered-by') then
		res.set_header('X-Powered-By', 'meiru')
	end
	res.set_header('server', 'meiru/1.0.0')
	res.set_header('accept-ranges', 'bytes')
end

return ComInit
