local Com = require "meiru.com.com"
local Render = require "meiru.util.render"
local filed  = require "meiru.lib.filed"
local Coder = require "meiru.util.coder"
local json  = Coder("json")

local views_path

local function get_res(path)
    local content = filed.file_read(views_path.."/"..path..".html")
    if not content then
        content = filed.file_read(views_path.."/"..path..".lua")
        if not content then
            print("[ERROR]not exit path:", views_path.."/"..path..".html", debug.traceback())
            assert(false)
            return
        end
    end
    return content
end


-- sec-fetch-site = "cross-site",
-- sec-fetch-mode = "cors",
-- sec-fetch-dest = "empty",
-----------------------------------------------
--ComRender
----------------------------------------------
local ComRender = class("ComRender", Com)

function ComRender:ctor()
end

function ComRender:match(req, res)
	if res.__rendertype == "html" then
		views_path = req.app.get("views_path")
        local render = Render(get_res, req.app.get_viewdatas())
		local csrf = res.res_csrf
		local data = res.__data or {}
		data.csrf = csrf

		local ok, body = render(res.__path, data)
        if not ok then
            req.app.__render_error = body
            assert(false)
            return false
        end
		local layout = res.get_layout()
		if layout and #layout > 0 then
			data.body = body
    		ok, res.body = render(layout, data)
            if not ok then
                req.app.__render_error = body
                assert(false)
                return false
            end
    	else
    		res.body = body
    	end
    elseif res.__rendertype == "json" then
        res.body = json.encode(res.__data)
	end
end


return ComRender
