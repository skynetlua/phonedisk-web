local Com = require "meiru.com.com"
local Cookie = require "meiru.util.cookie"
local Session = nil

local function create_session(req, res)
	if not Session then
		Session = require "meiru.util.session"
	end
	return Session(req, res)
end
----------------------------------------------
--ComSession
----------------------------------------------
local ComSession = class("ComSession", Com)

function ComSession:ctor()
end

function ComSession:match(req, res)
	if req.session then
		return
	end
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
	req.session = create_session(req, res)
	req.sessionid = req.session.sessionid
end



return ComSession
