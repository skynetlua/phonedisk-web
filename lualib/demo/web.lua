
local meiru  = require "meiru.meiru"

local config = include "config"
local render = include("util.renderfunc")

local view_path = include_assets_path("view")
local static_path = include_assets_path("static")

return function(params)

	local app = meiru.create_app()
	--配置参数
	app.data(render)
	app.data("config", config)
	app.set("static_url", "/")
	app.set("views_path", view_path)
	-- if params.domain then
	-- 	app.set("host", params.domain)
	-- end
	--配置组件
	app.use(app.new("ComInit"))
	-- app.use(app.new("ComCors"))
	app.use(app.new("ComPath"))
	app.use(app.new("ComHeader"))
	app.use(app.new("ComBody"))
	--配置路由
	local router = include("handle.index")
	router.get('/', function(req, res)
		return res.redirect("/index.html")
	end)
	--router.get('/test1.html'
	router.bind("get", "test1_html", function(req, res)
		return res.send(200, "/test1.html")
	end)
	--router.get('/test2.html'
	local model = {
		get = {
			test2_html = function(req, res)
				log("test bind /test2.html")
				return res.send(200, "/test2.html")
			end
		}
	}
	router.bind_model(model)
	app.use(router.node())
	--静态资源
	app.use(meiru.static('/', static_path))
	--监控平台
	app.system()
	--启动
	app.run()
	--日志控制
	if params.footprint then
		app.open_footprint()
	end
	if params.treeprint then
		log("treeprint:\n", app.treeprint())
	end

	return app
end

