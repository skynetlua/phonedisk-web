local ok, skynet = pcall(require, "skynet.manager")
skynet = ok and skynet

-----------------------------------------
-----------------------------------------
local filed = {}

if skynet then

local stm = require "skynet.stm"
local QueueMap = require "meiru.lib.queuemap"
local queue_map = QueueMap(500)
-----------------------------------------------
-----------------------------------------------
local agent_sum = 4
local AGENTS = {}
for i=1,agent_sum do
    AGENTS[i] = ".filed"..i
end

local function get_agent(file_path)
    local file_name = path.filename(file_path)
    local sum = 0
    for i=1,#file_name do
        sum = sum+string.byte(file_name, i)
    end
    local idx = sum%(#AGENTS)+1
    local agent = AGENTS[idx]
    -- local ret = skynet.queryservice(agent)
    -- skynet.error("======================[[[[]]]]>>ret = ", ret)
    return agent
end

setmetatable(filed, {__index = function(t,cmd)
    local f = function(file_path, ...)
        local filed = get_agent(file_path)
    	return skynet.call(filed, "lua", cmd, file_path, ...)
    end
    t[cmd] = f
    return f
end})

function filed.file_read(file_path)
    local filed = get_agent(file_path)
    local copy_obj = skynet.call(filed, "lua", "file_read", file_path)
    if copy_obj then
        local ref_obj = stm.newcopy(copy_obj)
        local ok, ret = ref_obj(skynet.unpack)
        if ok then
            return ret
        end
    end
end

function filed.file_md5(file_path)
    if os.mode ~= 'dev' then
        local file_md5 = queue_map.get(file_path)
        if file_md5 then
            return file_md5
        end
    end
    local filed = get_agent(file_path)
    local file_md5 = skynet.call(filed, "lua", "file_md5", file_path)
    if file_md5 then
        queue_map.set(file_path, file_md5)
        return file_md5
    end
end

function filed.init()
    for _,agent in ipairs(AGENTS) do
        local filed = skynet.newservice("meiru/filed", agent)
        skynet.name(agent, filed)
    end
end

else
-----------------------------------------------
-----------------------------------------------
local platform = require "meiru.util.platform"

function filed.file_read(file_path)
    return io.readfile(file_path)
end

function filed.file_md5(file_path)
    local content = io.readfile(file_path)
    if content then
        return platform.md5(content)
    end
end

function filed.init()
end

end

return filed 