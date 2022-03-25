
local string = string
local table = table
local os  = os

local function urlencodechar(char)
    return "%" .. string.format("%02X", char:byte())
end

function string.urlencode(input)
    input = tostring(input):gsub("\n", "\r\n")
    input = input:gsub("([^%w%.%- ])", urlencodechar)
    return input:gsub(" ", "+")
end

function string.urldecode(input)
    input = input:gsub("+", " ")
    input = input:gsub("%%(%x%x)", function(h) return string.char(tonumber(h,16) or 0) end)
    input = input:gsub("\r\n", "\n")
    return input
end

local escape_map = {
    ['\0'] = "\\0",
    ['\b'] = "\\b",
    ['\n'] = "\\n",
    ['\r'] = "\\r",
    ['\t'] = "\\t",
    ['\26'] = "\\Z",
    ['\\'] = "\\\\",
    ["'"] = "\\'",
    ['"'] = '\\"',
}

function string.quote_sql_str(str)
    local ret = str:gsub("[\0\b\n\r\t\26\\\'\"]", escape_map)
    return ret
end

function string.ltrim(input)
    return input:gsub("^[ \t\n\r]+", "")
end

function string.rtrim(input)
    return input:gsub("[ \t\n\r]+$", "")
end

function string.trim(input)
    input = input:gsub("^[ \t\n\r]+", "")
    return input:gsub("[ \t\n\r]+$", "")
end

function string.split(input, sep)
    local retval = {}
    sep = sep and "([^"..sep.."]+)" or "([^\t]+)"
    input:gsub(sep , function(c)
        table.insert(retval, c)
    end)
    return retval
end

function string.splitchar(input, sep)
    assert(#sep == 1)
    local tchar = sep:byte(1)
    local retval = {}
    local si = 1
    for i=1,#input do
        if input:byte(i) == tchar then
            -- assert(si <= i)
            if si == i then
                retval[#retval+1] = ""
            else
                retval[#retval+1] = input:sub(si, i-1)
            end
            si = i+1
        end
    end
    retval[#retval+1] = input:sub(si)
    return retval
end

function string.utf8len(input)
    local len  = #input
    local left = len
    local cnt  = 0
    local arr  = {0, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc}
    local tmp
    local i
    while left ~= 0 do
        tmp = string.byte(input, -left)
        i   = #arr
        while arr[i] do
            if tmp >= arr[i] then
                left = left - i                
                break
            end
            i = i - 1
        end
        cnt = cnt + 1
    end
    return cnt
end

function string.utf8tochars(input)
    local list = {}
    local len  = #input
    local index = 1
    local arr  = {0, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc}
    local c
    local offset
    local str
    while index <= len do
        c = string.byte(input, index)
        offset = 1
        if c < 0xc0 then
            offset = 1
        elseif c < 0xe0 then
            offset = 2
        elseif c < 0xf0 then
            offset = 3
        elseif c < 0xf8 then
            offset = 4
        elseif c < 0xfc then
            offset = 5
        end
        str = string.sub(input, index, index+offset-1)
        index = index + offset
        table.insert(list, str)
    end
    return list
end

--table----------------------
function table.nums(t)
    local count = 0
    for _, _ in pairs(t) do
        count = count + 1
    end
    return count
end

function table.keys(hashtable)
    local keys = {}
    for k, _ in pairs(hashtable) do
        keys[#keys + 1] = k
    end
    return keys
end

function table.values(hashtable)
    local values = {}
    for _, v in pairs(hashtable) do
        values[#values + 1] = v
    end
    return values
end

function table.merge(dest, src)
    for k, v in pairs(src) do
        dest[k] = v
    end
end

function table.indexof(array, value, begin)
    for i = begin or 1, #array do
        if array[i] == value then 
            return i 
        end
    end
    return false
end

function table.keyof(hashtable, value)
    for k, v in pairs(hashtable) do
        if v == value then 
            return k 
        end
    end
    return nil
end

function table.removebyvalue(array, value, removeall)
    local c, i, max = 0, 1, #array
    while i <= max do
        if array[i] == value then
            table.remove(array, i)
            c = c + 1
            i = i - 1
            max = max - 1
            if not removeall then break end
        end
        i = i + 1
    end
    return c
end

function table.map(t, fn)
    local tmp = {}
    for k, v in pairs(t) do
        tmp[k] = fn(v, k)
    end
    return tmp
end

function table.slice(t,s,e)
    local tmp = {}
    if e >= s then
        for i=s,e do
            if t[i] then
                table.insert(tmp, t[i])
            end
        end
    else
        for i=s,e,-1 do
            if t[i] then
                table.insert(tmp, t[i])
            end
        end
    end
    return tmp
end

function table.walk(t, fn)
    for k,v in pairs(t) do
        fn(v, k)
    end
end

function table.filter(t, fn)
    local tmp = {}
    for k, v in pairs(t) do
        if fn(v, k) then 
            tmp[k] = v
        end
    end
    return tmp
end

function table.unique(t, bArray)
    local check = {}
    local n = {}
    local idx = 1
    for k, v in pairs(t) do
        if not check[v] then
            if bArray then
                n[idx] = v
                idx = idx + 1
            else
                n[k] = v
            end
            check[v] = true
        end
    end
    return n
end

function table.clone(t, meta)
    if type(t) ~= "table" then
        return t
    end
    local copy = {}
    if meta then
        setmetatable(copy, getmetatable(t))
    end
    for k, v in pairs(t) do
        copy[k] = v
    end
    return copy
end

function table.deepclone(t, meta)
    if type(t) ~= "table" then
        return t
    end
    local copy = {}
    if meta then
        setmetatable(copy, getmetatable(t))
    end
    for k, v in pairs(t) do
        if type(v) == "table" then
            copy[k] = table.deepclone(v, meta)
        else
            copy[k] = v
        end
    end
    return copy
end

-------------------------------------------
--os
--------------------------------------------
function os.gmtdate(ts)
    ts = ts or os.time()
    return os.date("!%a, %d %b %Y %X GMT", ts)
end

function os.gmttime(date)
    local day, month, year, hour, min, sec, gmt = date:match("(%d+) (%a+) (%d+) (%d+):(%d+):(%d+) (%a+)")
    local months = {Jan=1, Feb=2, Mar=3, Apr=4, May=5, Jun=6, Jul=7, Aug=8, Sep=9, Oct=10, Nov=11, Dec=12}
    local ts = os.time({year = year, month = months[month], day = day, hour = hour, min = min, sec = sec})
    if gmt:upper() == 'GMT' then
        local zonediff = os.difftime(os.time(), os.time(os.date("!*t", os.time())))
        ts = ts+zonediff
    end
    return os.time(os.date("*t",ts))
end

os.platform = ({...})[2]:match([[\]]) and 'win' or 'unix'

function os.excute_cmd(cmd)
    local file = io.popen(cmd)
    assert(file)
    local ret = file:read("*all")
    file:close()
    return ret
end

-------------------------------------------
--io
--------------------------------------------
local ok, lfs = pcall(require, "lfs")
lfs = ok and lfs
function io.exists(path)
    if lfs then
        local attr = lfs.attributes(path)
        if attr then
            return true
        end
        return false
    end
    local file = io.open(path, "r")
    if file then
        io.close(file)
        return true
    end
    return false
end

function io.joinpath(dirpath, ...)
    local len = select('#', ...)
    local part, v
    local ret = dirpath
    for i=1,len do
        part = select(i, ...)
        v = ret:byte(#ret)
        if v == 47  or v == 92 then
            v = part:byte(1)
            if v == 47 or v == 92 then
                ret = ret .. part:sub(2)
            else
                ret = ret .. part
            end
        else
            v = part:byte(1)
            if v == 47 or v == 92 then
                ret = ret .. part
            else
                ret = ret .. "/" .. part
            end
        end
    end
    return ret
end

function io.readfile(path)
    local file = io.open(path, "rb")
    if file then
        local content = file:read("*a")
        io.close(file)
        return content
    end
    return nil
end

function io.writefile(path, content, mode)
    mode = mode or "wb"
    local file = io.open(path, mode)
    if file then
        if file:write(content) == nil then return false end
        io.close(file)
        return true
    else
        return false
    end
end

function io.pathinfo(path)
    local pos = #path
    local extpos = pos + 1
    while pos > 0 do
        local b = path:byte(pos)
        if b == 46 then -- 46 = char "."
            extpos = pos
        elseif b == 47 then -- 47 = char "/"
            break
        end
        pos = pos - 1
    end
    local dirname = path:sub(1, pos)
    local filename = path:sub(pos + 1)
    extpos = extpos - pos
    local basename = filename:sub(1, extpos - 1)
    local extname = filename:sub(extpos)
    return {
        dirname = dirname,
        filename = filename,
        basename = basename,
        extname = extname
    }
end

function io.dirname(path)
    local pos = #path
    while pos > 0 do
        if path:byte(pos) == 47 then
            break
        end
        pos = pos - 1
    end
    return path:sub(1, pos)
end

function io.filename(path)
    local pos = #path
    while pos > 0 do
        if path:byte(pos) == 47 then
            break
        end
        pos = pos - 1
    end
    return path:sub(pos + 1)
end

function io.extname(path)
    for i=#(path),1,-1 do
         local b = path:byte(i)
         if b == 46 then -- 46 = char "."
            return path:sub(i, #path)
        elseif b == 47 then -- 47 = char "/"
            return
        end
    end
end

function io.filesize(path)
    local size = false
    local file = io.open(path, "r")
    if file then
        local current = file:seek()
        size = file:seek("end")
        file:seek("set", current)
        io.close(file)
    end
    return size
end

function io.dir(path)
    local retval
    local file_list = {}
    if os.platform == "win" then
        path = string.gsub(path, "/", "\\")
        retval = os.excute_cmd("dir "..path)
        -- local file_list = {}
        retval = retval:split("\n")
        for _,file in ipairs(retval) do
            retval = file:split("%s")
            if #retval == 4 then
                if retval[1]:match("%d+/%d+/%d+") then
                    if retval[3] == "<DIR>" then
                        retval = {name = retval[4], isdir = true}
                    else
                        retval = {name = retval[4]}
                    end
                    table.insert(file_list, retval)
                end
            end
        end
        retval = file_list
    else
        local ok, lfs = pcall(require, "lfs")
        if ok then
            for file in lfs.dir(path) do
                if file ~= "." and file ~= ".." then
                    local attr = lfs.attributes(io.joinpath(path, file))
                    -- log("file =", file, attr)
                    if attr.mode == "directory" then
                        retval = {name = file, isdir = true}
                    else
                        retval = {name = file}
                    end
                    table.insert(file_list, retval)
                end
            end
            return file_list
        end
        retval = os.excute_cmd("ls -al "..path)
        retval = retval:split("\n")
        for _,file in ipairs(retval) do
            retval = file:split("%s")
            if #retval > 4 then
                if retval[1]:byte(1) == string.byte("d") then
                    retval = {name = table.remove(retval), isdir = true}
                else
                    retval = {name = table.remove(retval)}
                end
                table.insert(file_list, retval)
            end
        end
        retval = file_list
    end
    return retval
end

-- ".+%.(%w+)$"
function io.tracedir(root, suffix, collect)
    collect = collect or {}
    local path
    for _,element in pairs(io.dir(root)) do
        if element.name ~= "." and element.name ~= ".." then
            if string.byte(root, #root) == string.byte("/") then
                path = root .. element.name
            else
                path = root .. "/" .. element.name
            end
            if element.isdir then
                io.tracedir(path, suffix, collect)
            else
                if not suffix or path:match(suffix) then
                    table.insert(collect, path)
                end
            end
        end
    end
    return collect
end

--------------------------------------------------------
--meiru clase and instance
---------------------------------------------------------
local ok, skynet = pcall(require, "skynet")
skynet = ok and skynet

local function __tostring(...)
    local len = select('#', ...)
    if len == 0 then
        return ""
    end
    local ret = ""
    for i = 1, len do
        local arg = select(i, ...)
        local vtype = type(arg)
        if vtype == "function" then
            ret = ret .. vtype
        elseif vtype == "userdata" then
            ret = ret .. vtype
        elseif vtype == "thread" then
            ret = ret .. vtype
        elseif vtype == "table" then
            ret = ret .. vtype
        elseif vtype == "string" then
            ret = ret .. '"'..arg..'"'
        else
            ret = ret .. tostring(arg)
        end
        if i ~= len then
            ret = ret .. ", "
        end
    end
    return ret
end

local class_map = {}
local alive_map = {}

local function empty_ctor()
end

function class(cname, super)
    assert(cname, "cname not nil")
    assert(not class_map[cname], "repeated define class:" .. cname)
    local clazz = {}
    clazz.__cname = cname
    class_map[cname] = clazz
    clazz.__index = clazz
    if type(super) == "table" then
        setmetatable(clazz, {__index = super})
    else
        clazz.ctor = empty_ctor
    end

    function clazz.typeof(cname)
        if clazz.__cname == cname then
            return true
        end
        local pclazz = getmetatable(clazz)
        while pclazz do
            if pclazz.__cname == cname then
                return true
            end
            local ppclazz = pclazz.__index
            if not ppclazz then
                ppclazz = getmetatable(pclazz)
            end
            if ppclazz == pclazz then
                break
            end
            pclazz = ppclazz
        end
        return false
    end

    function clazz.new(...)
        local inst = {}
        if os.mode == "dev" then
            local date_key = os.date("%x %H:%M")
            local map = alive_map[date_key]
            if not map then
                alive_map[date_key] = {}
                map = alive_map[date_key]
                setmetatable(map, {__mode = "kv"})
            end
            local info = debug.getinfo(3)
            map[inst]  = info.short_src.. ":"..info.currentline ..":" .. clazz.__cname .."(" .. (__tostring(...) or "")..")"
        end
        inst = setmetatable(inst, clazz)
        inst:ctor(...)
        return inst
    end
    return clazz
end

function instance(cname, ...)
    local clazz = class_map[cname]
    assert(clazz, "no define class:"..cname)
    local ret = clazz.new(...)
    return ret
end

function typeof(inst)
    local ltype = type(inst)
    if ltype == "table" and inst.typeof then
        return inst.__cname
    end
    return ltype
end

function dump_memory()
    local lua_mem1 = collectgarbage("count")
    collectgarbage("collect")
    local lua_mem2 = collectgarbage("count")
    local ret = string.format("lua已用内存:%sKB=>%sKB", lua_mem1, lua_mem2) .. "\n活跃对象实例:"
    local rets = {ret}
    for key, map in pairs(alive_map) do
        table.insert(rets, "创建时间：" .. key)
        for inst, params in pairs(map) do
            table.insert(rets, "instance:".. params) --.. (inst.__traceback or ""))
        end
    end
    return table.concat(rets, "\n")
end

-----------------------------------------------------------
--log
-----------------------------------------------------------
local function convert_val(v)
    if type(v) == "nil" then
        return "nil"
    elseif type(v) == "string" then
        return '"'.. v .. '"'
    elseif type(v) == "number" or type(v) == "boolean" then
        return tostring(v)
    else
        return tostring(v)
    end
end

local function __dump(t, depth, dups)
    if type(t) ~= "table" then 
        return convert_val(t) 
    end
    dups = dups or {}
    if dups[t] then
        return convert_val(t)
    else
        dups[t] = true
    end
    depth = (depth or 0) + 1
    if depth > 10 then
        return "..."
    else
        local retval = ""
        for k, v in pairs(t) do
            retval = retval .. string.rep("\t", depth) .. k .. " = " .. __dump(v, depth, dups) .. ",\n"
        end
        return "{\n" .. retval .. string.rep("\t", depth - 1) .. "}"
    end
end

function log(...)
    local sid = 1
    if type(select(1, ...)) == "boolean" then
        sid = 2
    end
    local output = ""
    local v, log
    for i = sid, select('#', ...) do
        v = select(i, ...)
        if type(v) == "table" then
            log = __dump(v, 0)
        else
            log = v and tostring(v) or "nil"
        end
        if #output > 0 then
            output = output .. " " .. log
        else
            output = log
        end
    end
    if sid == 2 then
        output = output .. "\n" .. debug.traceback()
    end
    local info = debug.getinfo(2)
    if info then
        info = "[" .. info.short_src .. "|" .. info.currentline .. os.date("|%m-%d %X") .. "]"
    end
    if skynet then
        skynet.error(info, output)
    else
        print(info, output)
    end
end

function table.tostring(...)
    local strs = ""
    for i = 1, select('#', ...) do
        local v = select(i, ...)
        if type(v) == "table" then
            strs = strs .. __dump(v, 0)
        else
            strs = strs .. (v and tostring(v) or "nil")
        end
    end
    return strs
end

ROOT_PATH = "./"

function include_project_name(stack)
    stack = stack or 2
    local info = debug.getinfo(stack)
    local source = info.source
    source = source:gsub("\\", "/")
    local target = "lualib/"
    local sidx = source:find(target, 1, true)    
    if sidx then
        sidx = sidx+#target
        local eidx = source:find("/", sidx, true)
        return source:sub(sidx, eidx-1)
    else
        assert(false, "get_project_name: not meiru project")
    end
end

function include(path)
    local project_name = include_project_name(3)
    if project_name then
        path = project_name.. "." .. path
    else
        log("include failed. path =", path)
    end
    return require(path)
end

function include_assets_path(file_part)
    local project_name = include_project_name(3)
    local ret_path  = io.joinpath(ROOT_PATH, "assets", project_name)
    if file_part then
        ret_path  = io.joinpath(ret_path, file_part)
    end
    return ret_path
end

function include_data_path(file_part)
    local project_name = include_project_name(3)
    local ret_path  = io.joinpath(ROOT_PATH, "data", project_name)
    if file_part then
        ret_path  = io.joinpath(ret_path, file_part)
    end
    return ret_path
end


setmetatable(_G, {
    __newindex = function(_, k)
        if k == "lfs" then return end
        error("attempt to change undeclared variable " .. k)
    end,
    __index = function(_, k)
        if k == "skynet" then return end
        error("attempt to access undeclared variable " .. k)
    end,
})


