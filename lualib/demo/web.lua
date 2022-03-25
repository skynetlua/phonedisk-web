
local meiru  = require "meiru.meiru"

local config = include "config"
local render = include("util.renderfunc")

local view_path = include_assets_path("view")
local static_path = include_assets_path("static")

return function(params)
	local app = meiru.create_app()
	app.data(render)
	app.data("config", config)

	app.set("static_url", "/")
	app.set("views_path", view_path)

	-- local layout = io.joinpath(view_path, "layout.html")
	-- app.set("layout", layout)

	if params.domain then
		app.set("host", params.domain)
	end

	app.use(app.new("ComInit"))
	app.use(app.new("ComCors"))
	app.use(app.new("ComPath"))
	app.use(app.new("ComHeader"))
	app.use(app.new("ComBody"))

	local handle = include("handle.index")
	app.use(handle)
	
	app.use(meiru.static('/', static_path))
	app.system()

	app.run()

	if params.footprint then
		app.open_footprint()
	end

	if params.treeprint then
		log("treeprint:\n", app.treeprint())
	end
	return app
end

