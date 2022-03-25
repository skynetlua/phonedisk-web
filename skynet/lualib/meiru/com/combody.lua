local Com = require "meiru.com.com"

----------------------------------------------
--ComBody
----------------------------------------------
local ComBody = class("ComBody", Com)

function ComBody:ctor()
end


local _check = "application/x-www-form-urlencoded"
local _checklen = #_check
function ComBody:match(req, res)
	local content_type = req.header['content-type']
	if type(content_type) ~= 'string' then
		return
	end
	local rawbody = req.rawbody
	if type(rawbody) ~= 'string' then
		return
	end
	local ret = content_type:sub(1, _checklen)
	if ret == _check then
		local tmp = req.rawbody
		local items = tmp:split("&")
		local query = req.query or {}
		local value
		for _,item in ipairs(items) do
			tmp = item:split("=")
			value = tmp[2]
			query[tmp[1]] = value and value:urldecode() or ""
		end
		req.query = query
	end
end

return ComBody
