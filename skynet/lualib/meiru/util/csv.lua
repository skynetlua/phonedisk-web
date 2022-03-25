-- local platform = require "meiru.util.platform"
-- local ok, lfs = pcall(require, "lfs")
-- lfs = ok and lfs

-- local __excelDir = "./data/excel"

local csv = {}

-- local function getExcelFiles(excelDir)
--     local excelFiles = {}
--     if lfs then
--         for file in lfs.dir(excelDir) do
--             if io.extname(file) == ".csv" then
--                 table.insert(excelFiles, file)
--             end
--         end
--     else
--         local files = io.dir(excelDir)
--         for _,file in ipairs(files) do
--             if not file.isdir then
--                 if io.extname(file.name) == ".csv" then
--                     table.insert(excelFiles, file.name)
--                 end
--             end
--         end
--     end
--     return excelFiles
-- end

local sbyte = string.byte
local ssub = string.sub
local sfind = string.find

local function splitchar(input, sep)
    assert(#sep == 1)
    local tchar = sbyte(sep, 1)
    local retval = {}
    local si = 1
    for i=1,#input do
        if sbyte(input, i) == tchar then
            assert(si <= i)
            if si == i then
                retval[#retval+1] = ""
            else
                retval[#retval+1] = ssub(input, si, i-1)
            end
            si = i+1
        end
    end
    retval[#retval+1] = ssub(input, si)
    return retval
end

local function __convert(excelFile)
    log("excelFile =", excelFile)
    local content = io.readfile(excelFile)
    assert(content)
    
    if sbyte(content, 1) == 239 and sbyte(content, 2) == 187 and sbyte(content, 3) == 191 then
        content = ssub(content, 4)
    end

    -- local items = splitchar(content, "\n")
    local items = string.split(content, "\n")
    local box = {}
    for idx,item in ipairs(items) do
        item = string.trim(item)
        if item and #item>0 then
            -- item = ",,,"
            item = splitchar(item, ",")
            -- item = string.split(item, ",")
            table.insert(box, item)
        end
    end
    return box
end

------------------------------------------------------
------------------------------------------------------
local csv = {}
function csv.csv2lua(excelFile, fieldmap)
    local items = __convert(excelFile)
    local len = #items
    local fields
    local field = items[2][1]
    local dataIdx = 1
    if ssub(field, 1, 1) == "*" then
        items[2][1] = ssub(field, 2)
        fields = items[2]
        dataIdx = 3
    else
        fields = items[1]
        dataIdx = 2
    end
    if fieldmap then
        for i,key in ipairs(fields) do
            if fieldmap[key] then
                fields[i] = fieldmap[key]
            else
                fields[i] = false
            end
        end
    end
    local tmp, idx
    for i,field in ipairs(fields) do
        if field and #field > 0 then
            idx = sfind(field, "|")
            if idx then
                tmp = { ssub(field, 0, idx-1), ssub(field, idx+1) } 
            else
                tmp = { field } 
            end
            fields[i] = tmp
        else
            fields[i] = false
        end
    end
    local key, item, data, value
    local datas = {}
    for idx=dataIdx,len do
        data = {}
        item = items[idx]
        for i,field in ipairs(fields) do
            if field then
                key = field[1]
                value = item[i]
                if field[2] == "n" then
                    value = tonumber(value)
                    data[key] = value and math.floor(value)
                else
                    data[key] = value
                end
            end
        end
        table.insert(datas, data)
    end
    return datas
end

return csv