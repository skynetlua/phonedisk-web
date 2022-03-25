
local skynet = require "skynet"
local handle_web = require "meiru.net.handle_web"
local server = require "meiru.util.server"

local table  = table
local string = string

local web
local ws

---------------------------------------------
--protocol
---------------------------------------------
local _protocol
local _slave
local _config
local _master

local function handle_web_cb(is_ws, ...)
    if is_ws then
        assert(ws, "no open ws/wss service")
        local ret = ws.dispatch(...)
        if ret then
            return true
        end
    else
        assert(web, "no open http/https service")
        web.dispatch(...)
    end
end

---------------------------------------------
--slave service
---------------------------------------------
local command = {}
function command.start(slave)
    _slave = slave
    -- skynet.log("start data =", data)
    _master = slave.master
    assert(_master)
    local config = slave.config
    _protocol = config.protocol
    _config = config
    local lua_file = config['http'] or config['https']
    if type(lua_file) == "string" then
        web = require(lua_file)
        web = web(config)
    end

    lua_file = config['ws'] or config['wss']
    if type(lua_file) == "string" then
        ws = require(lua_file)
        ws = ws(config)
    end
end

-- function command.kick(ip)
--     skynet.send(_master, "lua", "kick", ip)
-- end

function command.exit()
end

function command.stop()
end

-- local _thread_queue = {}
-- local _main_thread
-- local ref = 0
function command.enter(fd, addr)
    handle_web(fd, addr, _protocol, handle_web_cb, _config)
    skynet.send(_master, "lua", "finish", fd, addr)
    -- local thread = coroutine.running()
    -- if _main_thread then
    --     log("busy=======================>>1", coroutine.running())
    --     _thread_queue[thread] = thread
    --     skynet.wait(thread)
    --     _thread_queue[thread] = nil
    --     _main_thread = thread
    --     log("busy==========================>>2", coroutine.running())
    -- else
    --     log("empty==========================>>", coroutine.running())
    --     _main_thread = thread
    -- end
    -- assert(ref == 0)
    -- ref = ref+1
    -- log("run======================================>>1", coroutine.running())
    -- handle_web(fd, addr, _protocol, handle_web_cb, _config.certfile, _config.keyfile)
    -- log("run======================================>>2", coroutine.running())

    -- thread = next(_thread_queue)
    -- if thread then
    --     log("wakeup==============================>>1", coroutine.running())
    --     skynet.wakeup(thread)
    --     log("wakeup=============================>>3", coroutine.running())
    -- end
    -- _main_thread = nil
    -- ref = ref-1
    -- assert(ref == 0)
end

-- skynet.start(function()
--     skynet.dispatch("lua", function(_,_,cmd,...)
--         local f = command[cmd]
--         if f then
--             skynet.ret(skynet.pack(f(...)))
--         else
--             assert(false,"error no support cmd"..cmd)
--         end
--     end)
-- end)

server(command, ...)
