local ok, skynet = pcall(require, "skynet")
skynet = ok and skynet


return function(name, unique)
    local command = {
        __name = name,
        __unique = unique
    }
    if not skynet then
        setmetatable(command, {__index = function(t,cmd)
            local f = function(...)
                return ""
            end
            t[cmd] = f
            return f
        end})
        return command 
    end
    local _serverd
    local _thread_queue = {}
    skynet.fork(function()
        if unique then
            _serverd = skynet.uniqueservice(name)
        else
            _serverd = skynet.newservice(name)
        end
        for _,thread in ipairs(_thread_queue) do
            skynet.wakeup(thread)
        end
        _thread_queue = nil
    end)

    setmetatable(command, {__index = function(t, cmd)
        if not _serverd then
            local thread = coroutine.running()
            table.insert(_thread_queue, thread)
            skynet.wait(thread)
        end
        local f, fname
        local head = string.sub(cmd, 1, 4)
        if head == "send" then
            fname = cmd
            cmd = string.sub(cmd, 5)
            f = function(...)
                return skynet.send(_serverd, "lua", cmd, ...)
            end
        else
            fname = cmd
            f = function(...)
                return skynet.call(_serverd, "lua", cmd, ...)
            end
        end
        t[fname] = f
        return f
    end})

    return command

end 