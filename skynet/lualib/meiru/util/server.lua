
local ok, skynet = pcall(require, "skynet")
skynet = ok and skynet

return function(command, start_func, ...)
    -- log("meiru.server", start_func, ...)
    if not skynet then
    	if type(start_func) == "function" then
    		start_func()
    	end
    else
        skynet.start(function()
        	if type(start_func) == "function" then
        		start_func()
        	end
            skynet.dispatch("lua", function(_,_,cmd,...)
                    -- skynet.error("SERVICE_NAME:", SERVICE_NAME, "cmd:", cmd)
                    local f = command[cmd]
                    if f then
                        skynet.ret(skynet.pack(f(...)))
                    else
                        assert(false,"error no support cmd:"..cmd)
                    end
            end)
        end)
    end
end