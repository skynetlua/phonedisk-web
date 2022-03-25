
local model = {
	"home",
	"topic"
}

local com = {}
function com.auth(req, res)
	log("com.auth req ===>>")
end

function com.adminauth(req, res)
	log("com.admin_auth req ===>>")
end

local route_params = {
	route_dir = "demo.handle",
	models = model,
	coms = com
}

--node----------------------------------
local meiru = require "meiru.meiru"

------------------------------------------
------------------------------------------
local router = meiru.router("handle", route_params)
router.get('ping', function(req, res)
    return res.send(200, "pong")
end)

router.get('/', function(req, res)
	-- local app = req.app
	-- local domain = app.get("host") or "127.0.0.1"
	-- log("domain =", domain)
	return res.redirect("/index.html")
end)

------------------------------------------
------------------------------------------
router.bind("get", "test1_html", function(req, res)
	log("test bind /test1.html")
	return res.send(200, "/test1.html")
end)

------------------------------------------
------------------------------------------
local model = {
	get = {
		test2_html = function(req, res)
			log("test bind /test2.html")
			return res.send(200, "/test2.html")
		end
	}
}

router.bind_model(model)

local node = router.node()
node:set_path("/")


return node
