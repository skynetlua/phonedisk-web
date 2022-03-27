local skynet = require "skynet"
local mysql = require "skynet.db.mysql"

local mysql_file = skynet.getenv("mysql_file")
local mysql_config = load("return " .. skynet.getenv("mysql"))()

local db_config = {
    host = mysql_config.host,
    port = mysql_config.port,
    user = mysql_config.username,
    password = mysql_config.password
}

local target_db = mysql_config.database
local model_path = mysql_config.model_path
local sql_file = mysql_config.sql_file

local check_db = "mycheck"
local _table_infos

local function exist_file(file_path)
    local file = io.open(file_path, "r")
    if not file then
        return
    end
    return true
end

local function read_file(file_path)
    local file = io.open(file_path, "r")
    if not file then
        assert(false, file_path)
        return
    end
    local content = file:read("*a")
    file:close()
    return content
end

local function write_file(file_path, content)
    local file = io.open(file_path, "w+")
    if not file then
        assert(false, file_path)
        return
    end
    file:write(content)
    file:close()
end


local modelTemplate = [[
local Model = require "meiru.lib.model"

------------------------
%s
------------------------

local %s = Model("%s")
function %s:ctor()
    --log("%s:ctor id =",self.id)
end

return %s
]]

local function convert(name)
    local file_name = string.lower(name)
    local model_name = string.upper(name:sub(1, 1)) .. name:sub(2)
    return file_name, model_name
    -- local items = string.split(name, "_")
    -- table.remove(items, 1)
    -- local file_name = table.concat(items, "_")
    -- for i,v in ipairs(items) do
    --     items[i] = string.upper(v:sub(1, 1)) .. v:sub(2)
    -- end
    -- local model_name = table.concat(items)
    -- return file_name, model_name
end

local function create_models(tableblocks)
    if not _table_infos then
        return
    end
    -- log("_table_infos =", _table_infos)
    for name,tableblock in pairs(tableblocks) do
        log("create_models: name =", name)
        local file_name, model_name = convert(name)
        -- log("create_models file_name =", file_name, "model_name =", model_name)
        if file_name and #file_name > 0 then
            local model_file = path.joinpath(model_path, file_name ..".lua")
            -- log("create model model_file:", model_file)
            if not exist_file(model_file) then
                log("create model:", model_file)
                local fields = {}
                local table_info = _table_infos[string.lower(name)]
                for _,v in pairs(table_info) do
                    table.insert(fields, "--" .. v.Type .. " " .. v.Field)
                end
                local content = string.format(modelTemplate, table.concat(fields, "\n"), model_name, name, model_name, model_name, model_name)
                write_file(model_file, content)
            end
        else
            log("create_models name =", name)
        end
    end
end

local tableblocks = {}
local function load_sql()
    skynet.error("load_sql sql_file =", sql_file)
    local slqtxt = read_file(sql_file)
    local seartidx = 1
    while true do
        local startidx = string.find(slqtxt, "DROP TABLE", seartidx, true)
        if not startidx then
            break
        end
        seartidx = startidx+1
        local endidx = string.find(slqtxt, ";", seartidx, true)
        if not endidx then
            break
        end
        seartidx = endidx+1

        local drop_block = string.sub(slqtxt, startidx, endidx)
        local table_name = string.match(drop_block,"`([^`]+)`")
        skynet.error("load_sql table_name =", table_name)
        ------------------------------
        local startidx = string.find(slqtxt, "CREATE TABLE", seartidx, true)
        if not startidx then
            break
        end
        seartidx = startidx+1
        local endidx = string.find(slqtxt, ";", seartidx, true)
        if not endidx then
            break
        end
        seartidx = endidx+1

        local create_block = string.sub(slqtxt, startidx, endidx)
        -- log("load_sql create_block =", create_block)
        assert(table_name == string.match(create_block,"`([^`]+)`"), table_name)
        -- assert(not tableblocks[table_name], tableblocks)
        local tableblock = {
            table_name = table_name,
            drop_block = drop_block,
            create_block = create_block
        }
        tableblocks[table_name] = tableblock
    end
    create_models(tableblocks)
end

local function check_error(retval,sql)
    if retval.errno then
        skynet.error("[MYSQL]sql:",sql)
        skynet.error("[MYSQL]发生错误 errno:",retval.errno,",err:",retval.err)
        assert(false)
        return
    end
end

--database---------------------
local function create_db(db, db_name)
    local sql = string.format("CREATE DATABASE `%s` DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;", db_name)
    check_error(db:query(sql), sql)
end

local function use_db(db, db_name)
    local sql = string.format("USE `%s`;",db_name)
    check_error(db:query(sql),sql)
end

local function drop_db(db, db_name)
    local sql = string.format("DROP DATABASE `%s`;",db_name)
    check_error(db:query(sql),sql)
end

local function is_exist_db(db, db_name)
    local sql = "SHOW DATABASES;"
    local databases = db:query(sql)
    check_error(databases,sql)
    for _,database in pairs(databases) do
        if database.Database == db_name then
            return true
        end
    end
end

--table--------------------------------
local function drop_tables(db, db_name, table_names)
    use_db(db, db_name)
    for _,table_name in ipairs(table_names) do
        local sql = string.format("DROP TABLE IF EXISTS `%s`;",table_name)
        check_error(db:query(sql),sql)
    end
end

local function create_tables(db, db_name, create_rules)
    use_db(db, db_name)
    for _,create_rule in pairs(create_rules) do
        -- log("create_rule =", create_rule)
        local sql = create_rule.drop_block
        local retval = db:query(sql)
        check_error(retval,sql)

        local sql = create_rule.create_block
        local retval = db:query(sql)
        check_error(retval,sql)
    end
end

local function is_exist_table(db, db_name, table_name)
    local sql = string.format("SELECT table_name FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='%s' AND TABLE_NAME='%s';",db_name,table_name)
    local retval = db:query(sql)
    check_error(retval,sql)
    return #retval>0
end

local function get_all_tablenames(db, db_name)
    local sql = string.format("SELECT table_name FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='%s';",db_name)
    local retval = db:query(sql)
    check_error(retval,sql)
    return retval
end

local function desc_tables(db, db_name)
    use_db(db, db_name)
    local table_names = get_all_tablenames(db, db_name)
    local table_descs = {}
    for _,v in pairs(table_names) do
        local table_name = v.table_name or v.TABLE_NAME
        if is_exist_table(db, db_name, table_name) then
            local sql = string.format("desc `%s`;",table_name)
            local retval = db:query(sql)
            check_error(retval,sql)
            table_descs[string.lower(table_name)] = retval
        end
    end
    return table_descs
end

--opt-----------------------------------
local function create_mysql(db, db_name)
    create_db(db, db_name)
    -- log("create_mysql tableblocks =", tableblocks)
    create_tables(db, db_name, tableblocks)
end

local function change_mysql(db, tdb_name, cdb_name)
    if is_exist_db(db, cdb_name) then
        drop_db(db, cdb_name)
    end
    create_mysql(db, cdb_name)
    local ctable_infos = desc_tables(db, cdb_name)
    -- drop_db(db, cdb_name)
    local ttable_infos = desc_tables(db, tdb_name)
    -- log("ctable_infos =", ctable_infos)
    -- log("ttable_infos =", ctable_infos)

    local new_tableblocks = {}
    local table_name, ctable_info, ttable_info, ctable_infomap, cfield, tfield
    for _,tableblock in pairs(tableblocks) do
        table_name = tableblock.table_name
        table_name = string.lower(table_name)
        skynet.error("check table: table_name =", table_name)

        ctable_info = ctable_infos[table_name]
        assert(ctable_info, "no create table:"..table_name)
        ttable_info = ttable_infos[table_name]
        ttable_infos[table_name] = nil
        if not ttable_info then
            skynet.error("create new table:",tableblock.table_name)
            table.insert(new_tableblocks, tableblock)
        else
            ctable_infomap = {}
            for _,cfield in pairs(ctable_info) do
                ctable_infomap[cfield.Field] = cfield
            end
            for _,tfield in pairs(ttable_info) do
                cfield = ctable_infomap[tfield.Field]
                ctable_infomap[tfield.Field] = nil
                --需要移除字段
                if not cfield then
                    skynet.error("check table:", table_name, "remove field:", tfield.Field)
                    table.insert(new_tableblocks, tableblock)
                    tableblock = nil
                else
                    for key,value in pairs(cfield) do
                        if tfield[key] ~= value then
                            skynet.error("check table:", table_name, "change field:", tfield.Field)
                            table.insert(new_tableblocks, tableblock)
                            tableblock = nil
                        end
                    end
                end
            end
            if tableblock then
                for _,cfield in pairs(ctable_infomap) do
                    skynet.error("check table:", table_name, "add field:", cfield.Field)
                    table.insert(new_tableblocks, tableblock)
                    tableblock = nil
                end
            end
        end
    end
   
    for _,tableblock in pairs(new_tableblocks) do
        skynet.error("need create new table:", tableblock.table_name)
    end
    
    local remove_tablenames = {}
    for table_name in pairs(ttable_infos) do
        skynet.error("need delete table:", table_name)
        table.insert(remove_tablenames,table_name)
    end
    log("new_tableblocks =", new_tableblocks)
    do return end

    --重新创建表格
    create_tables(db, tdb_name, new_tableblocks)

    --删除丢弃的表格
    drop_tables(db, tdb_name, remove_tablenames)
end

local function chech_mysql()
    log("chech_mysql db_config =", db_config)
    local db = mysql.connect(db_config)
    assert(db, "failed to connect mysql")
    skynet.error("success to connect to mysql server")
    if is_exist_db(db, target_db) then
        skynet.error("database is exist:", target_db)
        change_mysql(db, target_db, check_db)
    else
        skynet.error("database is no exist:", target_db)
        create_mysql(db, target_db)
    end
    _table_infos = desc_tables(db, target_db)
    db:disconnect()
end

-------------------------------------------------
-------------------------------------------------

local command = {}
function command.start()

    load_sql()
    chech_mysql()
    load_sql()

    skynet.sleep(10)
    skynet.fork(skynet.exit)
end

skynet.start(function()
	skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = command[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            assert(false, "error no support cmd" .. cmd)
        end
    end)
end)
