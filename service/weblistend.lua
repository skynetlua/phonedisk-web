local skynet = require "skynet"
local socket = require "skynet.socket"

skynet.start(function()
	local webacceptd = {}
	for i = 1, 20 do
		webacceptd[i] = skynet.newservice("webacceptd")
	end
	local balance = 1
	local id = socket.listen("0.0.0.0", 8001)
	skynet.error("Listen web port 8001")
	socket.start(id, function(id, addr)
		skynet.error(string.format("%s connected, pass it to agent :%08x", addr, webacceptd[balance]))
		skynet.send(webacceptd[balance], "lua", id)
		balance = balance + 1
		if balance > #webacceptd then
			balance = 1
		end
	end)
end)
	