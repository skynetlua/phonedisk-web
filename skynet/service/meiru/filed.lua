
local skynet = require "skynet"
local stm    = require "skynet.stm"
local md5    = require "md5"
local QueueMap = require "meiru.lib.queuemap"
local server = require "meiru.util.server"

local _filebox

---------------------------------------------
--command
---------------------------------------------
local FileBox = class("FileBox")

function FileBox:ctor()
    self.map = {}

    local queuemaps = {}
    queuemaps[1] = QueueMap(50, self.map)
    queuemaps[2] = QueueMap(30, self.map)
    queuemaps[3] = QueueMap(10, self.map)
    queuemaps[4] = QueueMap(5, self.map)
    queuemaps[5] = QueueMap(3, self.map)
    self.queuemaps = queuemaps

    self.file_md5s = {}
end

function FileBox:set_data(key, data)
    if os.mode == 'dev' then
        return
    end
    if data == false then
        self.map[key] = false
    else
        --10*1024
        if data.len < 10*1024 then
            self.queuemaps[1].set(key, data)
        --100*1024
        elseif data.len < 100*1024 then
            self.queuemaps[2].set(key, data)
        --500*1024
        elseif data.len < 500*1024 then
            self.queuemaps[3].set(key, data)
        --1024*1024
        elseif data.len < 1024*1024 then
            self.queuemaps[4].set(key, data)
        --5*1024*1024
        else
            self.queuemaps[5].set(key, data)
        end
    end
end

function FileBox:get_data(key)
    return self.map[key]
end

function FileBox:get_file_content(path)
    if os.mode == 'dev' then
        local content = io.readfile(path)
        if content then
            local obj = stm.new(skynet.pack(content))
            local copy_obj = stm.copy(obj)
            return copy_obj
        end
        return
    end

    local data = self:get_data(path)
    if data == false then
        return
    end
    
    if not data then
        local content = io.readfile(path)
        if content then
            local obj = stm.new(skynet.pack(content))
            data = {
                path = path,
                obj  = obj,
                len = #content
            }
            if data.len < 5242880 then
                self:set_data(path, data)
            end
        else
            self:set_data(path, false)
            self.file_md5s[path] = false
            return
        end
    end

    local copy_obj = stm.copy(data.obj)
    return copy_obj
end

function FileBox:get_file_md5(path)
    if os.mode == 'dev' then
        local content = io.readfile(path)
        if content then
            local file_md5 = md5.sumhexa(content)
            return file_md5
        end
        return
    end

    local file_md5 = self.file_md5s[path]
    if file_md5 == false then
        return
    end
    if file_md5 then
        return file_md5
    end

    local data = self:get_data(path)
    if data then
        local copy_obj = stm.copy(data.obj)
        local ref_obj = stm.newcopy(copy_obj)
        local ok, content = ref_obj(skynet.unpack)
        if ok then
            file_md5 = md5.sumhexa(content)
            self.file_md5s[path] = file_md5
            return file_md5
        end
    end
    local content = io.readfile(path)
    if content then
        file_md5 = md5.sumhexa(content)
        self.file_md5s[path] = file_md5
        return file_md5
    else
        self.file_md5s[path] = false
    end
end

---------------------------------------------
--command
---------------------------------------------
local command = {}

function command.file_read(path)
    return _filebox:get_file_content(path)
end

function command.file_md5(path)
    local md5 = _filebox:get_file_md5(path)
    -- log("md5 =", md5)
    return md5
end

-- skynet.start(function()
--     _filebox = FileBox.new()

--     skynet.dispatch("lua", function(_,_,cmd,...)
--         local f = command[cmd]
--         if f then
--             skynet.ret(skynet.pack(f(...)))
--         else
--             assert(false,"error no support cmd"..cmd)
--         end
--     end)
-- end)
local function init()
    _filebox = FileBox.new()
end

server(command, init, ...)
