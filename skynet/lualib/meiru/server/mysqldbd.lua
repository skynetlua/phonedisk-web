
local ok, skynet = pcall(require, "skynet")
skynet = ok and skynet

if not skynet then
    local mysqldb = {}

    setmetatable(mysqldb, { __index = function(t,cmd)
        local f = function(...)
        end
        t[cmd] = f
        return f
    end})
    
    return mysqldb 

end

local _mysqldbd
local _thread_queue = {}
skynet.fork(function()
    local addr = skynet.address(skynet.self())
    local name = string.sub(addr, 2)
    name = "." .. name
    local list = skynet.call(".launcher", "lua", "LIST")
    for address,param in pairs(list) do
        if param:find(addr, 1, true) then
            _mysqldbd = skynet.queryservice(name)
            break
        end
    end
    if not _mysqldbd then
        _mysqldbd = skynet.newservice("meiru/mysqldbd", addr)
    -- else
        -- log("===========================>> _mysqldbd2 =", _mysqldbd)
    end

    for _,thread in ipairs(_thread_queue) do
        skynet.wakeup(thread)
    end
    _thread_queue = nil
end)


local mysqldb = {}

setmetatable(mysqldb, { __index = function(t, cmd)
    if not _mysqldbd then
        local thread = coroutine.running()
        table.insert(_thread_queue, thread)
        skynet.wait(thread)
    end
    local f = function(...)
    	return skynet.call(_mysqldbd, "lua", cmd, ...)
    end
    t[cmd] = f
    return f
end})


return mysqldb 