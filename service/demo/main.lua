local skynet = require "skynet.manager"
local filed = require "meiru.lib.filed"

skynet.start(function()
    filed.init()

    local server_cfgs = load("return " .. skynet.getenv("servers"))()
    for _,config in ipairs(server_cfgs) do
        if config.http then
            config.port = config.http_port
            local httpd = skynet.newservice("meiru/serverd", config.port)
            skynet.call(httpd, "lua", "start", config)
        end
        if config.https then
            config.port = config.https_port
            local httpsd = skynet.newservice("meiru/serverd", config.port)
            skynet.call(httpsd, "lua", "start", config)
        end
    end
end)