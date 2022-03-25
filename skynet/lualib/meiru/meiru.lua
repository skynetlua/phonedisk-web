
require "meiru.com.index"

local Request  = require "meiru.util.request"
local Response = require "meiru.util.response"
local Node     = require "meiru.node.node"
local Root     = require "meiru.node.root"
local Router   = require "meiru.node.router"
local Static   = require "meiru.node.static"
local platform = require "meiru.util.platform"

----------------------------------------------
--Meiru
----------------------------------------------
local Meiru = class("Meiru")

function Meiru:ctor()
	self.viewdatas = {}
	self.settings  = {}

	self:default_config()
end

function Meiru:get_viewdatas()
	return self.viewdatas
end

function Meiru:data(key, value)
	if type(key) == "string" then
		self.viewdatas[key] = value
	elseif type(key) == "table" then
		assert(not value)
		for k,v in pairs(key) do
			self.viewdatas[k] = v
		end
	else
		assert(false)
	end
end

function Meiru:set(key, value)
	self.settings[key] = value
end

function Meiru:get(key)
	return self.settings[key]
end

function Meiru:get_node(name, depth)
	if not name or self.node_root.name == name then
		return self.node_root
	end
	depth = depth or 2
	local node = self.node_root:search_child_byname(name, depth)
	return node
end

function Meiru:add_node(parent_name, node)
	local parent = self:get_node(parent_name)
	assert(parent)
	if type(node) == "string" then
		node = Node.new(node, self)
		assert(node)
	end
	parent:add_child(node)
end

function Meiru:get_or_create_node(name, parent_name)
	local node = self:get_node(name)
	if not node then
		node = Node.new(name, self)
		assert(node)
		if parent_name then
			local parent_node = type(parent_name) == "string" and self:get_node(parent_name) or self.node_res
			parent_node:add_child(node)
		else
			self.node_req:add_child(node)
		end
	end
	return node
end

function Meiru:add_com(name, com, parent_name, ...)
	if not com then
		com = name
		name = self.node_req.name
	end
	local node = self:get_or_create_node(name, parent_name)
	node:add_com(com, ...)
	return node
end

function Meiru:use(...)
	local args = {...}
	local path = args[1]
	local node = self:get_or_create_node("node_req")
	if type(path) == "string" then
		if path:byte(1) == string.byte("/") then
			node = Node.new("node_use", self)
			self:add_node("node_req", node)
		else
			node = self:get_or_create_node(path)
		end
		assert(node)
		table.remove(args, 1)
	end
	for _,field in ipairs(args) do
		node:add(field)
	end
end

function Meiru:run()
	-- self.node_root:print()
end

if os.mode == 'dev' then
local LineChars = "\n--------------------------------------\n"
function Meiru:dispatch(app, raw_req, raw_res)
	local req = Request(app, raw_req)
	local res = Response(app, raw_res)

	-- self.is_working = true
	local start_time = platform.time()
	local traceback
	local err_msg
	local function throw_error(msg)
		err_msg = tostring(msg)
		traceback = debug.traceback()
		-- log("throw_error:", msg)
		-- log("throw_error:", traceback)
	end
	local ok, ret = xpcall(self.node_req.dispatch, throw_error, self.node_req, req, res)
	if ok then
		res.req_ret = res.is_end or ret
		res.is_end = nil
		ok, ret = xpcall(self.node_res.dispatch, throw_error, self.node_res, req, res)
	end
	if ok then
		if self.enable_footprint then
			log("dispatch url:"..req.rawurl)
			log("dispatch cost_time:" .. (platform.time() - start_time))
			log(LineChars.."FOOTPRINT"..LineChars..(self.node_req:footprint() or 'nothing'))
		end
		if ret == nil or ret == false then
			self:response(res, 404, "Forbidden")
		else
			assert(ret == true)
		end
	else
		local logmsg = "Meiru req:"..table.tostring(req.rawreq)
		if self.enable_footprint then
			logmsg = logmsg.."\ndispatch url:"..req.rawurl
			logmsg = logmsg .."\ndispatch cost_time:" .. (platform.time() - start_time)
			logmsg = logmsg ..LineChars.."FOOTPRINT"..LineChars..(self.node_req:footprint() or 'nothing')
		end
		local errmsg = LineChars.."ERROR"..LineChars..(err_msg or "").."\n"..traceback
		if req.app.__render_error then
			local renerror = req.app.__render_error
			req.app.__render_error = nil
			errmsg = errmsg..LineChars.."RENDER_ERROR"..LineChars
			errmsg = errmsg.."Render error:"..renerror.error
			if renerror.path then
				errmsg = errmsg.."\nRender path:"..renerror.path
				errmsg = errmsg.."\nRender chunk:\n"..renerror.chunk
			end
		end
		log(logmsg.."\n"..errmsg)
		self:response(res, 404, logmsg.."\n"..errmsg, {['content-type'] = "text/plain;charset=utf-8"})
	end
	return ret
end
end

if os.mode ~= 'dev' then

function Meiru:dispatch(app, raw_req, raw_res)
	local req = Request(app, raw_req)
	local res = Response(app, raw_res)

	-- self.is_working = true
	local start_time = platform.time()
	local traceback
	local err_msg
	local function throw_error(msg)
		err_msg = msg
		traceback = debug.traceback()
	end

	local ok, ret = xpcall(self.node_req.dispatch, throw_error, self.node_req, req, res)
	if ok then
		res.req_ret = res.is_end or ret
		res.is_end = nil
		ok, ret = xpcall(self.node_res.dispatch, throw_error, self.node_res, req, res)
	end
	if not ok then
		log("Meiru req:", req.rawreq)
		log(err_msg .. "\n" .. traceback)
	end

	if self.enable_footprint then
		log("Meiru url:", req.rawurl)
		log("Meiru cost_time:", platform.time() - start_time)
		log("Meiru footprint:\n", self.node_req:footprint())
	end
	if not ok then
		self:response(res, 404, "Forbidden")
	else
		if ret == nil or ret == false then
			self:response(res, 404, "Forbidden")
		else
			assert(ret == true)
		end
	end
	return ret
end
end

function Meiru:open_footprint(enable)
	enable = type(enable) ~= 'nil' and enable or true
	self.enable_footprint = enable
	log("open footprint===>>")
end

function Meiru:response(res, code, body, header)
	res.__response(code, body, header)
	-- self.is_working = nil
end

function Meiru:default_config()
	self:set('x-powered-by', true)

	self.node_root = Root.new("node_root", self)

	self:add_node("node_root", "node_req")
	self:add_node("node_root", "node_res")
	self.node_req = self:get_node("node_req")
	self.node_res = self:get_node("node_res")

	-- self:add_node("node_req", "node_req_start")
	-- self:add_node("node_req", "node_req_finish")

	-- self:add_com("node_req_start", "ComInit")
	-- self:add_com("node_req_start", "ComPath")
	-- self:add_com("node_req_start", "ComHeader")
	-- self:add_com("node_req_start", "ComCors")
	-- self:add_com("node_req_start", "ComCookie")
	-- self:add_com("node_req_start", "ComSession")
	-- self:add_com("node_req_start", "ComBody")

	-- self:add_com("node_req_finish", "ComFinish")

	self:add_com("node_res", "ComRender")
	self:add_com("node_res", "ComResponse")
	
	-- self:add_node("node_res", "node_res_start")
	-- self:add_node("node_res", "node_res_finish")
	-- self:add_com("node_res_start", "ComRenderJson")
	-- self:add_com("node_res_start", "ComRenderHtml")
	-- self:add_com("node_res_finish", "ComResponse")

end

function Meiru:footprint()
	return self.node_root:footprint()
end

function Meiru:treeprint()
	return self.node_root:treeprint()
end

-----------------------------------------------
--exports
-----------------------------------------------
local exports = {
	Meiru = Meiru
}

function exports.router(...)
	return Router(...)
end

function exports.static(path, static_dir)
	return Static(path, static_dir)
end

-----------------------------------------
---create_app
-- -----------------------------------------
function exports.create_app()
	local meiru = Meiru.new()

	local app = {}
	function app.data(...)
		meiru:data(...)
	end

	function app.get_viewdatas(...)
		return meiru:get_viewdatas(...)
	end

	function app.set(...)
		meiru:set(...)
	end

	function app.get(...)
		return meiru:get(...)
	end

	function app.add_node(...)
		meiru:add_node(...)
	end

	function app.get_node(...)
		return meiru:get_node(...)
	end

	function app.get_or_create_node(...)
		return meiru:get_or_create_node(...)
	end

	function app.add_com(...)
		return meiru:add_com(...)
	end

	function app.use(...)
		meiru:use(...)
	end

	function app.run(...)
		meiru:run(...)
	end

	function app.dispatch(raw_req, raw_res)
		return meiru:dispatch(app, raw_req, raw_res)
	end

	function app.response(...)
		meiru:response(...)
	end

	function app.open_footprint(enable)
		meiru:open_footprint(enable)
	end
	
	function app.footprint()
		return meiru:footprint()
	end

	function app.treeprint()
		return meiru:treeprint()
	end

	function app.system()
	 	local node = require "meiru.node.system"
	 	meiru:use(node)
 	end

	function app.chunkprint()
		assert(false, "discard")
		-- assert(os.mode == 'dev', "Please open development mode.just setting os.mode = 'dev'")
		-- local chunk = ""
		-- if app.__chunks then
		-- 	for _,v in ipairs(app.__chunks) do
		-- 		chunk = chunk .."ejs:[["..v[1].."]]\n"..v[2].."\n"
		-- 	end
		-- end
		-- return chunk
	end

	function app.new(name, ...)
		return instance(name, ...)
	end

	function app.static(com, urlpath, filepath)
		local node = Node.new("node_static")
		node:set_method("get")
    	node:set_path(urlpath)
    	node:open_terminal()
    	node:add_com(com, filepath)
    	meiru:use(node)
	end
	------------------------------
	-----------------------------
	-- meiru:default_config()
	return app
end

-- log("================================>>meiru")

return exports
