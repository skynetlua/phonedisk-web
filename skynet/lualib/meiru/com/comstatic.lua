local Com = require "meiru.com.com"
local platform = require "meiru.util.platform"
local filed = require "meiru.server.filed"

local string = string

----------------------------------------------
--ComStatic
----------------------------------------------
local ComStatic = class("ComStatic", Com)

function ComStatic:ctor(static_dir)
	self.file_md5s = {}
	self.max_age = 3600*24*365
	self.static_dir = static_dir
end

function ComStatic:find_static_dir()
	if self.static_dir then
		return self.static_dir
	end
	local static_dir = req.app.get("static_dir")
	assert(static_dir)
    self.static_dir = static_dir
end

function ComStatic:get_full_path(path_name)
	if not self.static_dir then
		self:find_static_dir()
	end
	local file_path = path.joinpath(self.static_dir, path_name)
	if not io.exists(file_path) then
		return
	end
	return file_path
end

function ComStatic:match(req, res)
	local fullpath = self:get_full_path(req.path)
	if not fullpath then
		return
	end
	-- log("fullpath =", fullpath)
    local header = req.header
	local modify_date = header['if-modified-since']
	-- log("modify_date =", modify_date)
	if type(modify_date) == "string" and #modify_date > 0 then
		local modify_time = os.gmttime(modify_date)
		if modify_time then
			local fmodify_time = platform.file_modify_time(fullpath)
			if fmodify_time == modify_time then
				res.send(304)
				res.set_header('Last-Modified', os.gmtdate(fmodify_time))
				res.set_cache_timeout(self.max_age)
				return true
			end
		end
	end
	
	local file_md5 = filed.file_md5(fullpath)
	-- log("file_md5 =", file_md5)
	if not file_md5 then
		return false
	end
	local etag = header['if-none-match']
	-- log("etag =", etag)
	if type(etag) == "string" and #etag > 0 then
		if etag == file_md5 then
			res.send(304)
			res.set_header('ETag', file_md5)
			res.set_cache_timeout(self.max_age)
			return true
		end
	end
	local content = filed.file_read(fullpath)
	if not content then
		return false
	end

	res.set_type(path.extname(fullpath))
	res.set_header('ETag', file_md5)
	local modify_time = platform.file_modify_time(fullpath)
	res.set_header('Last-Modified', os.gmtdate(modify_time))
	res.set_header('Age', 3600*24)
	res.set_cache_timeout(self.max_age)

	res.send(content)
	return true
end

return ComStatic
