
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
	return res.redirect("/index.html")
end)

return router
