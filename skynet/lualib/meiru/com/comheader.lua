local Com = require "meiru.com.com"

----------------------------------------------
--ComHeader
----------------------------------------------
local ComHeader = class("ComHeader", Com)

function ComHeader:ctor()

end

local slower = string.lower
function ComHeader:match(req, res)
	local header = {}
	-- log("req.rawheader =", req.rawheader)
	for k,v in pairs(req.rawheader) do
		k = slower(k)
		if k == 'user-agent' or k == 'content-type' then
			v = slower(v)
		end
		header[k] = v
	end
	req.header = header
end

return ComHeader
