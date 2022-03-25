local ok, skynet = pcall(require, "skynet.manager")
skynet = ok and skynet

local have_mysql = nil
local _mysqldbd

local timeout_func = function(t, f, ...) 
    -- f(t, ...)
end

if skynet then
    have_mysql = (skynet and skynet.getenv("mysql")) and true
    if have_mysql then
        skynet.init(function()
            local cache_mysql = skynet.getenv("cache_mysql") and "cache_mysql" or nil
            _mysqldbd = skynet.newservice("meiru/mysqldbd", cache_mysql)
        end)
    end
    timeout_func = skynet.timeout
end

local database = {}
function database.select(...)
    return skynet.call(_mysqldbd, "lua", "select", ...)
end

function database.query(...)
    return skynet.call(_mysqldbd, "lua", "query", ...)
end

function database.insert(...)
    return skynet.call(_mysqldbd, "lua", "insert", ...)
end

function database.update(...)
    return skynet.call(_mysqldbd, "lua", "update", ...)
end


local string = string
local table = table

--执行
local kMDoSaveInterval = 5
--缓存时间低于给定时间，不写入数据库
local kMTmpSaveIntervel = 60*10
--最大缓存容量
local kMMaxCacheCap = 1000*5
--缓存最大时间
local kMMaxSaveIntervel = 1*3600



-- LimitQueue-------------------------
local LimitQueue = class("LimitQueue")

function LimitQueue:ctor(cache)
    assert(cache)
    self.cache = cache

    self.from_idx = 1
    self.to_idx = 1
    self.queue = {}
end

function LimitQueue:add_data(ckey, data)
    local cache = self.cache
    cache.datas[ckey] = data

    local to_idx = self.to_idx
    self.queue[to_idx] = ckey
    self.to_idx = to_idx+1
    local from_idx = self.from_idx
    if to_idx - from_idx > kMMaxCacheCap then
        local ockey = self.queue[from_idx]
        self.queue[from_idx] = nil
        if ockey and ockey ~= ckey then
            cache.datas[ockey] = nil
        end
        self.from_idx = from_idx+1
    end
end


-- SaveQueue-------------------------
local SaveQueue = class("SaveQueue")

function SaveQueue:ctor(cache)
    assert(cache)
    self.cache = cache

    self.save_map  = {}
    self.save_time = os.time()
end

function SaveQueue:remove(ckey)
    self.save_map[ckey] = nil
end

function SaveQueue:run_save_timer()
    local cur_time = os.time()
    if self.timer_running then
        if cur_time-self.save_time < kMDoSaveInterval then
            return
        end
    end

    self.timer_running = true
    local delta_time = kMDoSaveInterval
    self.save_time = cur_time+delta_time
    -- log("SaveQueue:run_save_timer======================>>start, delta_time =", delta_time)
    timeout_func(delta_time*100, function()
        -- log("SaveQueue:run_save_timer======================>>end")
        self.timer_running = nil
        local cur_time = os.time()
        local remove_keys = {}
        for ckey,save_time in pairs(self.save_map) do
            if not save_time or cur_time >= save_time then
                table.insert(remove_keys, ckey)
            end
        end
        for _,ckey in ipairs(remove_keys) do
            self.save_map[ckey] = nil
            self.cache:save(ckey)
        end
        if not next(self.save_map) then
            return
        end
        self:run_save_timer()
    end)
end

function SaveQueue:add_savequeue(ckey)
    self.save_map[ckey] = os.time()+kMDoSaveInterval
    self:run_save_timer()
end

--Cache--------------------------------
local Cache = class("Cache")

function Cache:ctor()
    self.mname = "cache"
    self.datas = {}

    self.limitQueue = LimitQueue.new(self)
    self.saveQueue = SaveQueue.new(self)

    -- self:clear_time_out()
end

function Cache:set(ckey, val, timeout)
    -- log("Cache:set ckey =", ckey, "timeout =", timeout, "val =", val)
    local data = self:get_data(ckey)
    if not data then
        -- log("Cache:set====================>>not data")
        data = {
            ckey  = ckey,
            vdata = val,
        }
        self.limitQueue:add_data(ckey, data)
    else
        -- log("Cache:set====================>>data")
        assert(data.ckey == ckey)
        data.vdata = val
    end

    timeout = timeout or kMMaxSaveIntervel
    data.deadline = os.time()+timeout
    data.timeout = timeout
    --缓存时间太短，无需存入数据库
    if timeout < kMTmpSaveIntervel then
        return
    end
    self.saveQueue:add_savequeue(ckey)
end

function Cache:get_data(ckey)
    local data = self.datas[ckey]
    if data == false then
        return
    end
    if data then
        if os.time() >= data.deadline then
            self:remove(ckey)
            data = nil
        else
            return data
        end
    end

    if have_mysql then
        local cond = "WHERE `ckey` = '" .. ckey:quote_sql_str() .. "'"
        -- local ret = skynet.call(_mysqldbd, "lua", "select", self.mname, cond)
        local ret = database.select(self.mname, cond)
        assert(#ret < 2)
        if #ret == 1 then
            data = ret[1]
            assert(data.ckey == ckey)
            self.limitQueue:add_data(ckey, data)
        else
            self.datas[ckey] = false
        end
    end
    return data
end

function Cache:get(ckey)
    local data = self:get_data(ckey)
    if data then
        return data.vdata, data.deadline
    end
end

function Cache:save(ckey)
    local data = self.datas[ckey]
    if type(data) ~= "table" or not have_mysql then
        return
    end
    local ret
    if data.id then
        local cond = "WHERE `id` = " .. data.id
        -- ret = skynet.call(_mysqldbd, "lua", "update", self.mname, data, cond)
        ret = database.update(self.mname, data, cond)
    else
        -- ret = skynet.call(_mysqldbd, "lua", "insert", self.mname, data, "ckey")
        ret = database.insert(self.mname, data, "ckey")
        -- skynet.log("Cache:save ret2 =", ret)
        if ret and ret.insert_id then
            if not data.id then
                data.id = ret.insert_id
            else
                assert(data.id == ret.insert_id)
            end
        end
    end
    assert(ret.affected_rows == 1)
end

function Cache:remove(ckey)
    assert(type(ckey) == 'string' and #ckey > 0)
    self.saveQueue:remove(ckey)
    local data = self.datas[ckey]
    self.datas[ckey] = false
    if have_mysql then
        local sql = "DELETE FROM `" .. self.mname .. "` WHERE `ckey` = '" .. ckey:quote_sql_str() .. "'"
        database.query(sql)
        -- skynet.send(_mysqldbd, "lua", "query", sql)
    end
    return data
end

--timer to clear timeout data
function Cache:clear_time_out()
    if have_mysql then
        local sql = "DELETE FROM `" .. self.mname .. "` WHERE `deadline` != 0 and `deadline` < " .. os.time()
        -- skynet.send(_mysqldbd, "lua", "query", sql)
        database.query(sql)
    end

    local cur_time = os.time()
    local datas = self.datas
    for k, data in pairs(datas) do
        if cur_time > data.deadline then
            datas[k] = nil
        end
    end
    self:time_out()
end

function Cache:time_out()
    timeout_func(3600*1, function()
        self:clear_time_out()
    end)
end


return Cache
