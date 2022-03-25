
local Check = {}

function Check.string(str)
    if type(str) ~= 'string' then
        log("check_string:", str)
        assert(false)
    end
end
function Check.number(num)
    if type(num) ~= 'number' then
        log("check_number:", num)
        assert(false)
    end
end
function Check.table(tbl)
    if type(tbl) ~= 'table' then
        log("check_table:", tbl)
        assert(false)
    end
end


return Check
