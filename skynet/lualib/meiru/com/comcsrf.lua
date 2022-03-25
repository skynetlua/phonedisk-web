local Com  = require "meiru.com.com"
local uuid = require "meiru.lib.uuid"
local platform = require "meiru.util.platform"


local kMCSRFKey = "mrcsrf"

----------------------------------------
--ComCSRF
----------------------------------------
local ComCSRF = class("ComCSRF", Com)

function ComCSRF:ctor()
end

function ComCSRF:match(req, res)
	-- log("req =", req)
	-- local csrf_secret = req.app.get("csrf_secret") or "csrf_secret"
	if req.method == "post" then
		local host = req.app.get('host')
		if host then
			local referer = req.header['referer']
			local ret = referer:find("//"..host, 1, true)
			if not ret then
				log("ComCSRF referer =", referer, "host =", host)
				return false
			end
		end
		local body_csrf   = req.get_body_csrf()
		local header_csrf = req.get_header_csrf()
		if body_csrf ~= header_csrf then
			log("ComCSRF header_csrf =", header_csrf, "body_csrf =", body_csrf)
			return false
		end
		local key = header_csrf:sub(1, #header_csrf-8)
		local val = header_csrf:sub(#header_csrf-8+1)
		local mac = platform.hmacmd5(key, req.sessionid)
		mac = mac:sub(1, 8)
		if val ~= mac then
			log("ComCSRF sessionid error header_csrf =", header_csrf, "mac =", mac)
			return false
		end
	end
	if req.sessionid then
		local key = uuid()
		local mac = platform.hmacmd5(key, req.sessionid)
		mac = mac:sub(1, 8)
		res.res_csrf = key .. mac
	end
end

return ComCSRF
