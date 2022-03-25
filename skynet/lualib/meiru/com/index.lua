
local names = {
	"com", 
	"combody", 
	"commultibody",
	"comcookie", 
	"comcsrf",
	"comcors",
	"comfinish",

	"comhandle",
	"comheader",
	"cominit",
	"compath",
	"comrender",
	
	"comresponse",
	"comsession",
	"comstatic",
}
local models = {}
local model
local path
for _,name in ipairs(names) do
	path = "meiru.com." .. name
	-- log("com path:", path)
	model = require(path)
	models[model.__cname] = model
end

return models
