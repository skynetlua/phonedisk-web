local Com = require "meiru.com.com"

----------------------------------------------
--ComMultiBody
----------------------------------------------
local ComMultiBody = class("ComMultiBody", Com)

function ComMultiBody:ctor()
end


local _multipart = "multipart/form-data"
local _checklen = #_multipart
local _maxlen = 1024*1024*16

local ssplitchar = string.splitchar

local function split_key_value(str)
	local idx = str:find("=", 1, true)
	if idx then
		local key = str:sub(1, idx-1)
		key = string.trim(key)
		idx = str:find("\"", idx+1, true)
		if idx then
			idx = idx+1
			local eidx = str:find("\"", idx, true)
			if eidx then
				local value = str:sub(idx, eidx-1)
				return key, value
			end
		end
	end
end

local sfind = string.find
local ssub = string.sub
function ComMultiBody:match(req, res)
	local content_type = req.header['content-type']
	if type(content_type) ~= 'string' then
		return
	end
	local rawbody = req.rawbody
	if type(rawbody) ~= 'string' then
		return
	end
	local check = content_type:sub(1, _checklen)
	-- log("ComMultiBody check =", check)
	if check == _multipart then
		local content_length = tonumber(req.header['content-length'])
		-- log("ComMultiBody content_length =", content_length)
		if content_length > _maxlen then
			log("content_length =", content_length)
			assert(false)
			return false
		end
		-- log("ComMultiBody content_type =", content_type)
		local idx = sfind(content_type, "boundary=", 1, true)
		if not idx then
			log("ComMultiBody content_length =", content_length)
			return false
		end
		local tmp = ssub(content_type, idx+9)
		local sidx = 1
		local eidx = 1
		eidx = sfind(rawbody, "\r\n", 1, true)
		if not eidx then
			log("ComMultiBody rawbody =", rawbody)
			return false
		end
		local checkstr = ssub(rawbody, 1, eidx-1)
		local need_checkstr = string.lower(checkstr)
		sidx = sfind(need_checkstr, tmp, 1, true)
		if not sidx then
			log("ComMultiBody checkstr =", checkstr, "tmp =", tmp)
			return false
		end
		local boundary = ssub(rawbody, 1, eidx+2)
		-- log("ComMultiBody boundary =", boundary)
		local blen = #boundary
		sidx = 1
		eidx = 1
		local idx, key, value, items, item, index, tmps
		local form = req.form or {}
		while eidx do
			eidx = sfind(rawbody, boundary, sidx, true)
			if not eidx then
				return false
			end
			-- form-data;
			-- Content-Disposition: form-data; 
			-- tmp = ssub(rawbody, sidx, sidx+blen-1)
			-- log("sidx =", sidx, "blen =", blen)
			-- log("tmp =", tmp)
			-- assert(tmp == boundary)
			sidx = sidx+blen
			eidx = sfind(rawbody, boundary, sidx, true)
			if eidx then
				index = eidx-3
			else
				tmp = ssub(rawbody, #rawbody-1)
				-- log("tmp ====", tmp)
				if tmp == "\r\n" then
					index = #rawbody-2
				else
					index = #rawbody
				end
			end

			idx = sfind(rawbody, "\r\n\r\n", sidx)
			assert(idx)
			tmp = ssub(rawbody, sidx, idx-1)
			tmps = string.split(tmp, "\r\n")
			assert(#tmps > 0)
			items = ssplitchar(tmps[1], ";")
			-- log("tmp =", tmp)
			-- log("items =", items)
			local data = {}
			for i,item in ipairs(items) do
				key, value = split_key_value(item)
				if key then
					data[key] = value
				end
			end
			key = data.name
			assert(key)
			value = ssub(rawbody, idx+4, index)
			data.name = nil
			if next(data) then
				data.value = value
				form[key] = data
				if #tmps > 1 then
					table.remove(tmps, 1)
					for _,tmp in ipairs(tmps) do
						items = ssplitchar(tmp, ":")
						key = string.trim(items[1])
						key = string.lower(key)
						value = string.trim(items[2])
						data[key] = value
					end
				end
			else
				form[key] = value
			end
			sidx = eidx
		end
		req.form = form
	end
end

return ComMultiBody

