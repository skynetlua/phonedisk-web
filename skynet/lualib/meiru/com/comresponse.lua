local Com = require "meiru.com.com"

----------------------------------------------
--ComResponse
----------------------------------------------
local ComResponse = class("ComResponse", Com)

function ComResponse:ctor()
end

function ComResponse:match(req, res)
	if res.req_ret == true then
		res.app.response(res, res.get_statuscode(), res.get_body(), res.get_header())
		if os.mode == 'dev' then
			-- log("dispatch success rawurl =", req.rawurl)
			if res.__rendertype ~= "json" then
				log("dispatch success:", req.rawurl)
			else
				log("dispatch " .. "url =", req.rawurl, " body:", res.get_body())
			end
		else
			if res.__rendertype ~= "json" then
				log("dispatch success:", req.rawurl)
			else
				log("dispatch " .. "url =", req.rawurl, " body:", res.get_body())
			end
			-- log("dispatch success rawurl =", req.rawurl, " body:", res.get_body())
		end
		return true
	elseif res.req_ret == false then
		log("dispatch failed:", req.rawreq)
	else
		log("dispatch nothing:", req.rawreq)
		assert(not res.is_end)
	end
	res.app.response(res, 404, "HelloWorld 404")
	return true
end

return ComResponse
