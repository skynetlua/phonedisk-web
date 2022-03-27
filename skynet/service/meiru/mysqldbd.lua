local skynet = require "skynet"
local manager = require "skynet.manager"
local mysql  = require "skynet.db.mysql"
local cjson  = require "cjson"
local server = require "meiru.util.server"

local assert = assert
local string = string
local table = table


local args = {...}
log("args =", ...)
local mysql_config_name
if #args > 0 then
    local mtype = string.sub(args[1], 1, 1)
    if mtype == ":" then
        local name = string.sub(args[1], 2)
        name = "." .. name
        skynet.register(name)
    else
        mysql_config_name = args[1]
    end
end

local mysql_config_str = skynet.getenv(mysql_config_name or "mysql")
-- log("mysql_config_str =", mysql_config_str)
local mysql_config = load("return " .. mysql_config_str)()

local db_config = {
    host = mysql_config.host,
    port = mysql_config.port,
    user = mysql_config.username,
    password = mysql_config.password,
    database = mysql_config.database
}

local db 
local _table_descs

local ValueType = {
    integer   = 1,
    varchar   = 2,
    blob      = 3,
    text      = 4,
    -- datetime  = 5,
    timestamp = 6,
}

local function decode_value(field_info, value)
    local vtype = field_info.vtype
    if vtype == ValueType.integer then
        return value
    elseif vtype == ValueType.varchar or vtype == ValueType.text then
        return value
    elseif vtype == ValueType.blob then
        if type(value) == "string" and #value > 0 then
            value = skynet.unpack(value)
            return value
        else
            return value
        end
    elseif vtype == ValueType.timestamp then
        return value
    else
        skynet.log("decode_value field_info =", field_info, "type value =", type(value) , "value =", value)
        assert(false)
    end
end

local function encode_value(field_info, value)
    local vtype = field_info.vtype
    if vtype == ValueType.integer then
        if type(value) == "number" then
            if value >= 0 and value <= field_info.vlimit then
                return value
            end
        else
            skynet.log("encode_value type =", type(value), " value =", value)
            skynet.log("encode_value field_info =", field_info)
            skynet.error("[mysqldbd]WARN: value must be number")
            assert(false)
        end
    elseif vtype == ValueType.varchar then
        if type(value) == "string" then
            -- value = dataEncode(value)
            value = string.quote_sql_str(value)
            if utf8.len(value) > field_info.vlimit then
                skynet.error("[mysqldbd]WARN: string length is too many")
                skynet.error("[mysqldbd]WARN: value =", value)
                skynet.log("[mysqldbd]WARN: field_info =", field_info)
                assert(false)
            end
            return value
        else
            skynet.log("encode_value value =", value)
            skynet.log("encode_value field_info =", field_info)
            skynet.error("[mysqldbd]WARN: value must be string")
            assert(false)
        end
    elseif vtype == ValueType.text then
        if type(value) == "string" then
            -- return dataEncode(value)
            return string.quote_sql_str(value)
        else
            skynet.log("encode_value value =", value)
            skynet.log("encode_value field_info =", field_info)
            skynet.error("[mysqldbd]WARN: value must be string")
            assert(false)
        end
    elseif vtype == ValueType.blob then
        value = skynet.packstring(value)
        -- value = dataEncode(value)
        return string.quote_sql_str(value)
        -- return value
    elseif vtype == ValueType.timestamp then
        return value
    else
        skynet.log("encode_value value =", value)
        skynet.log("encode_value field_info =", field_info)
        skynet.error("[mysqldbd]WARN:  no support type")
        assert(false)
    end
    skynet.log("encode_value value =", value)
    skynet.log("encode_value field_info =", field_info)
    assert(false)
end

local function throw_error(msg)
    log(msg, "\n", debug.traceback())
end

local _lastInitTime
local load_desc_tables
local function init()
    log("mysqldbd =======================>>init")
    if _lastInitTime then
        if os.time() < _lastInitTime+5 then
            log("mysqldbd =======================>>init too fast")
            return
        end
    end
    db = mysql.connect(db_config)
    assert(db,"[MYSQLDBD]failed to connect mysql")
    if not _table_descs then
        load_desc_tables(db, db_config.database)
    end
    log("mysqldbd =======================<<init")
    -- skynet.hooktrace()
    -- skynet.exithooktrace()
end

local function database_select(sql)
     -- db:query(sql)
    local ok, ret = xpcall(db.query, throw_error, db, sql)
    if ok then
        return ret
    end
    log("mysql.connect==============>> try connect1", skynet.self())
    log("mysql.connect==============>> try connect2", skynet.self())
    log("mysql.connect==============>> try connect3", skynet.self())
    skynet.sleep(100)
    db = mysql.connect(db_config)
    assert(db, "[MYSQLDBD]failed to connect mysql")
    if not _table_descs then
        load_desc_tables(db, db_config.database)
    end
    return db:query(sql)
end

local function get_table_desc(tblname)
    if not _table_descs then
        init()
        assert(_table_descs)
    end
    local table_desc = _table_descs[tblname]
    if not table_desc or not next(table_desc) then
        log("table_desc no exist.tblname:", tblname)
        assert(false)
    end
    return table_desc
end

------------------------------------------------
------------------------------------------------
local command = {}

function command.select(tblname, cond, ...)
    local table_desc = get_table_desc(tblname)
    -- assert(type(cond) == 'string' and #cond>0)
    local fields
    local len = select('#', ...)
    if len == 0 then
        fields = "*"
    else
        local arg
        fields = ""
        for i = 1, len do
            arg = select(i, ...)
            if type(arg) == 'string' and #arg > 0 then
                if #fields > 0 then
                    fields = fields .. ", `"..arg .. "`"
                else
                    fields = "`"..arg .. "`"
                end
            else
                assert(false)
            end
        end
    end
    local sql = "SELECT " .. fields .. " FROM `".. tblname .. "` " .. (cond or "") .. ";"
    skynet.error("[mysqldbd]select sql:",sql)
    local retval = database_select(sql)
    if retval.errno then
        skynet.log("[MYSQLDBD]select sql:", sql)
        skynet.log("[MYSQLDBD]ERROR errno:", retval.errno, ",err:", retval.err)
        assert(false)
    else
        if #retval>0 then
            local field_info
            for _,data in ipairs(retval) do
                for key, value in pairs(data) do
                    field_info = table_desc[key]
                    if not field_info then
                        log("table_desc =", table_desc)
                        log("retval =", retval)
                        assert(false)
                    end
                    data[key] = decode_value(field_info, value)
                end
            end
        end
    end
    -- log("[mysqldbd]select", retval)
    return retval
end

function command.rawselect(...)
    local retval = command.select(...)
    if #retval>0 then
        for idx,data in ipairs(retval) do
            retval[idx] = skynet.packstring(data)
        end
    end
    return retval
end

function command.jsonselect(...)
    local retval = command.select(...)
    if #retval>0 then
        for idx,data in ipairs(retval) do
            retval[idx] = cjson.encode(data)
        end
    end
    return retval
end

function command.update(tblname, data, cond)
    -- data["id"] = nil
    -- data["created_at"] = nil
    -- data["updated_at"] = nil
    -- data["deleted_at"] = nil
    -- log("update tblname =", tblname)
    -- log("update cond =", cond)
    -- log("update data =", data)
    assert(cond and #cond>0)
    local table_desc = get_table_desc(tblname)
    assert(not data['key'], "marailDB keyword cause error")

    local field_info
    local tblkv
    local kv
    for key, value in pairs(data) do
        field_info = table_desc[key]
        if field_info then
            value = encode_value(field_info, value)
            if field_info.vtype == ValueType.integer then
                kv = "`"..key.."`="..value
            else
                kv = "`"..key.."`='" .. value .. "'"
            end
            if tblkv then
                tblkv = tblkv .. ", " .. kv
            else
                tblkv = kv
            end
        end
    end
    if not tblkv then
        log("tblname =", tblname, "data =", data, "cond =", cond)
        assert(tblkv)
    end
    local sql = "UPDATE `" .. tblname .. "` SET " .. tblkv .. " " .. cond .. ";"
    skynet.error("[mysqldbd]update sql:", sql)
    local retval = database_select(sql)
    if retval.errno then
        skynet.log(true, "[MYSQLDBD]update sql:",sql)
        skynet.log(true, "[MYSQLDBD]ERROR errno:",retval.errno,",err:",retval.err)
        -- assert(false)
        return false
    end
    return retval
end

function command.insert(tblname, data, fupdate)
    -- data["id"] = nil
    -- data["created_at"] = nil
    -- data["updated_at"] = nil
    -- data["deleted_at"] = nil
    -- log("insert tblname =", tblname)
    -- log("insert fupdate =", fupdate)
    -- log("insert data =", data)
    local table_desc = get_table_desc(tblname)
    assert(not data['key'], "marailDB keyword cause error")
    local tblkey
    local tblvalue
    local field_info

    for key, value in pairs(data) do
        field_info = table_desc[key]
        if field_info then
            if tblkey then
                tblkey = tblkey ..",`"..key.. "`"
            else
                tblkey = "`"..key.. "`"
            end
            value = encode_value(field_info, value)
            if field_info.vtype ~= ValueType.integer then
                value = "'"..value.. "'"
            end
            if tblvalue then
                tblvalue = tblvalue .. "," .. value
            else
                tblvalue = value
            end
        end
    end
    local sql = "INSERT INTO `" .. tblname .. "`(" .. tblkey .. ") VALUES(" .. tblvalue .. ");"
    skynet.error("[mysqldbd]insert sql:",sql)
    local retval = database_select(sql)
    if retval.errno then
        skynet.log(true, "[MYSQLDBD]insert sql:",sql)
        skynet.log(true, "[MYSQLDBD]ERROR errno:",retval.errno,",err:",retval.err)
        if retval.errno == 1062 and fupdate and table_desc[fupdate] then
            skynet.log("[MYSQLDBD]insert failed.change update data")
            local key = fupdate
            local field_info = table_desc[key]
            local value = data[key]
            value = encode_value(field_info, value)
            local cond
            if field_info.vtype == ValueType.integer then
                cond = "WHERE `".. key.. "`=".. value
            else
                cond = "WHERE `".. key.. "`=\"".. value.. "\""
            end
            return command.update(tblname, data, cond)
        else
            -- assert(false)
            return false
        end
    end
    return retval
end

function command.delete(tblname, id)
    -- local sql = string.format("DELETE FROM `%s` WHERE `id` = %s;",tblname, id)
    local sql = "DELETE FROM `" .. tblname .. "` WHERE `id` = " .. id .. ";"
    local retval = database_select(sql)
    -- skynet.error("[mysqldbd]command.delete sql:",sql)    
    if retval.errno then
        skynet.log(true, "[MYSQLDBD]insert sql:", sql)
        skynet.log(true, "[MYSQLDBD]ERROR errno:", retval.errno, ",err:", retval.err)
        -- assert(false)
        return false
    end
    return retval
end

function command.distinct(tblname, field)
    -- local sql = string.format("SELECT DISTINCT %s FROM %s;", field, tblname)
    local sql = "SELECT DISTINCT " .. field .. " FROM " .. tblname .. ";"
    local retval = database_select(sql)
    if retval.errno then
        skynet.log(true, "[MYSQL]select sql:", sql)
        skynet.log(true, "[MYSQL]ERROR errno:", retval.errno, ",err:", retval.err)
        return false
        -- assert(false)
    else
        if #retval>0 then
            local table_desc = get_table_desc(tblname)
            local field_info
            local values = {}
            for _,data in ipairs(retval) do
                for key, value in pairs(data) do
                    field_info = table_desc[key]
                    value = decode_value(field_info, value)
                    table.insert(values, value)
                end
            end
            return values
        end
    end
    return retval
end

function command.table_desc(tblname)
    return get_table_desc(tblname)
end

function command.table_descs()
    return _table_descs
end

function command.query(sql)
    skynet.error("[mysqldbd]query sql:", sql)
    local retval = database_select(sql)
    if retval.errno then
        skynet.log(true, "[MYSQLDBD]query sql:",sql)
        skynet.log(true, "[MYSQLDBD]ERROR errno:",retval.errno,",err:",retval.err)
        assert(false)
    end
    return retval
end

----------------------------------------------
----------------------------------------------

local function dbquery(db, sql)
    local retval = db:query(sql)
    if retval.errno then
        skynet.log(true, "[MYSQLDBD]dbquery sql:",sql)
        skynet.log(true, "[MYSQLDBD]ERROR errno:",retval.errno,",err:",retval.err)
        assert(false)
    end
    return retval
end

local function get_all_tablenames(db, db_name)
    local sql = string.format("SELECT table_name FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='%s';", db_name)
    local retval = dbquery(db, sql)
    return retval
end

local function is_exist_table(db, db_name, table_name)
    local sql = string.format("SELECT table_name FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='%s' AND TABLE_NAME='%s';", db_name, table_name)
    local retval = dbquery(db, sql)
    return #retval>0
end

load_desc_tables = function(db, db_name)
    local tableNames = get_all_tablenames(db, db_name)
    _table_descs = {}
    local table_name
    for _,v in pairs(tableNames) do
        table_name = v.table_name or v.TABLE_NAME
        if is_exist_table(db, db_name, table_name) then
            local sql = string.format("desc `%s`;",table_name)
            local retval = dbquery(db, sql)
            _table_descs[table_name] = retval
        end
    end
    -- skynet.log("1table_descs =", table_descs)
    for table_name, table_desc in pairs(_table_descs) do
        local field_infos = {}
        for _,info in ipairs(table_desc) do
            field_infos[info.Field] = info
            info.Type = string.lower(info.Type)
            if string.find(info.Type, "int", 1, true) then
                info.vtype = ValueType.integer
                if string.find(info.Type, "tinyint", 1, true) then
                    info.vlimit = 255
                elseif string.find(info.Type, "smallint", 1, true) then
                    info.vlimit = 65535
                elseif string.find(info.Type, "mediumint", 1, true) then
                    info.vlimit = 16777215
                elseif string.find(info.Type, "int", 1, true) then
                    info.vlimit = 4294967295
                elseif string.find(info.Type, "bigint", 1, true) then
                    info.vlimit = 18446744073709551615
                else
                    skynet.log("table_name:", table_name)
                    skynet.log("field_name:", info.Field)
                    skynet.log("no support type:", info.Type)
                    assert(false)
                end
            elseif string.find(info.Type, "varchar", 1, true) then
                info.vtype = ValueType.varchar
                local limit = string.match(info.Type, "varchar%((%d+)%)")
                if limit then
                    info.vlimit = tonumber(limit)
                    if not info.vlimit then
                        skynet.log("table_name:", table_name)
                        skynet.log("field_name:", info.Field)
                        skynet.log("no support type:", info.Type)
                        assert(false)
                    end
                else
                    info.vlimit = 65535
                end
            elseif info.Type == "blob" then
                info.vtype = ValueType.blob
            elseif info.Type == "text" then
                info.vtype = ValueType.text
            elseif info.Type == "datetime" then
                info.vtype = ValueType.datetime
            elseif info.Type == "timestamp" then
                info.vtype = ValueType.timestamp
            else
                skynet.log("table_name:", table_name)
                skynet.log("field_name:", info.Field)
                skynet.log("no support type:", info.Type)
                assert(false)
            end
        end
        _table_descs[table_name] = field_infos
    end
    -- skynet.log("2table_descs =", table_descs)
end

server(command, init, ...)
