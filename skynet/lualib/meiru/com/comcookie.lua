local Com = require "meiru.com.com"
local Cookie = require "meiru.util.cookie"

----------------------------------------------
--ComCookie
----------------------------------------------
local ComCookie = class("ComCookie", Com)

function ComCookie:ctor()
end

function ComCookie:match(req, res)
	if not req.cookies then
		local req_cookie = req.get('cookie')
		if not req_cookie then
			req.cookies = {}
		    req.signcookies = {}
		else
			local session_secret = req.app.get("session_secret") or "meiru"
			local cookies, signcookies = Cookie.cookie_decode(req_cookie, session_secret)
			req.cookies = cookies or {}
		    req.signcookies = signcookies or {}
		end
	end
end

return ComCookie
