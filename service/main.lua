local skynet = require "skynet"

skynet.start(function()
    skynet.newservice("console")
    skynet.newservice("debug_console", 8000)
    
    skynet.uniqueservice("weblistend")

    skynet.exit()
end)