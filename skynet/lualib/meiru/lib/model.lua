
local _database_default

local function get_database()
	if not _database_default then
		local mysqldbd = require "meiru.server.mysqldbd"
		_database_default = {
			select = mysqldbd.select,
			query  = mysqldbd.query,
			fields = mysqldbd.table_desc,
			insert = mysqldbd.insert,
			update = mysqldbd.update,
		}
	end
	return _database_default
end

local table = table
local string = string
local type = type
local ipairs = ipairs
local pairs = pairs
local assert = assert

local tinsert = table.insert
local squote_sql_str = string.quote_sql_str

local conditions = {}

conditions["$in"] = function(k, v, opt, args)
	assert(next(args))
	local ttype = type(args[1])
	if ttype == "string" then
		local tmps
		local tmp
		for i,arg in ipairs(args) do
			tmp = "\"" .. squote_sql_str(arg) .. "\""
			if tmps then
				tmps = tmps .. ", " .. tmp
			else
				tmps = tmp
			end
		end
		return "`" .. k .. "` IN (" .. tmps .. ")"
	elseif ttype == "number" then
		return "`" .. k .. "` IN (" .. table.concat(args, ", ") .. ")"
	else
		assert(false, "args[1]=" .. args[1])
	end
end

conditions["$like"] = function(k, v, opt, args)
	local ttype = type(args)
	if ttype == "string" then
		return "`" .. k .. "` LIKE \"" .. squote_sql_str(args) .. "\""
	elseif ttype == "number" then
		return "`" .. k .. "` LIKE " .. args
	else
		assert(false)
	end
end

conditions["$nin"] = function(k, v, opt, args)
	assert(next(args))
	local ttype = type(args[1])
	if ttype == "string" then
		local tmps
		local tmp
		for _,arg in ipairs(args) do
			tmp = '"'.. squote_sql_str(arg)..'"'
			if tmps then
				tmps = tmps .. ", " .. tmp
			else
				tmps = tmp
			end
		end
		return "`" .. k .. "` NOT IN (" .. tmps .. ")"
	elseif ttype == "number" then
		return "`" .. k .. "` NOT IN (" .. table.concat(args, ", ") .. ")"
	else
		assert(false)
	end
end

conditions["$gte"] = function(k, v, opt, args)
	assert(type(args) == "number")
	return "`" .. k .. "` >= " .. args
end

conditions["$gt"] = function(k, v, opt, args)
	assert(type(args) == "number")
	-- tinsert(conds, string.format([[`%s` > %s]], k, args))
	return "`" .. k .. "` > " .. args
end

conditions["$lte"] = function(k, v, opt, args)
	assert(type(args) == "number")
	-- tinsert(conds, string.format([[`%s` <= %s]], k, args))
	return "`" .. k .. "` <= " .. args
end

conditions["$lt"] = function(k, v, opt, args)
	assert(type(args) == "number")
	-- tinsert(conds, string.format([[`%s` < %s]], k, args))
	return "`" .. k .. "` < " .. args
end

--{['$or'] = {loginname = loginname, email = email}}
conditions["$or"] = function(k, v)
	assert(next(v))
	local tmps
	local tmp
	local ttype
	for i,arg in pairs(v) do
		ttype = type(arg)
		if ttype == "string" then
			tmp = "`" .. k .. "` = \"" .. squote_sql_str(arg) .. "\""
		elseif ttype == "number" then
			tmp = "`" .. k .. "` = " .. arg
		elseif ttype == "boolean" then
			tmp = "`" .. k .. "` = " .. (arg and 1 or 0)
		else
			assert(false)
		end
		if tmps then
			tmps = tmps .. " OR " .. tmp
		else
			tmps = tmp
		end
	end
	return "(" .. tmps .. ")"
end

--{['$and'] = {loginname = loginname, email = email}}
conditions["$and"] = function(k, v)
	assert(next(v))
	local tmps
	local tmp
	local ttype
	for i,arg in pairs(v) do
		ttype = type(arg)
		if ttype == "string" then
			tmp = "`" .. k .. "` = \"" .. squote_sql_str(arg) .. "\""
		elseif ttype == "number" then
			tmp = "`" .. k .. "` = " .. arg
		elseif ttype == "boolean" then
			tmp = "`" .. k .. "` = " .. (arg and 1 or 0)
		else
			assert(false)
		end
		if tmps then
			tmps = tmps .. " AND " .. tmp
		else
			tmps = tmp
		end
	end
	return "(" .. tmps .. ")"
end

local platform = require "meiru.util.platform"
local warn_msg = "Call method of Object. Use \":\", not \".\""

return function(tblName, db)
	-- local database = db or get_database()
	-- assert(database)
	local Model = {}
	Model.__index = Model

	function Model:commit()
		assert(getmetatable(self) == Model, warn_msg)
		local fields = Model.GetFields()
		local data = {}
		for k,_ in pairs(fields) do
			data[k] = self[k]
		end
		data["id"] = nil
		if self.id then
			local sql_cond = "WHERE `id` = " .. self.id
			local retval = get_database().update(tblName, data, sql_cond)
			if type(retval) == "table" then
				if retval.affected_rows == 1 then
					self._isNotModel = nil
					return true
				end
			end
		else
			local retval = get_database().insert(tblName, data)
			if type(retval) == "table" then
				if retval.affected_rows == 1 then
					self.id = retval.insert_id
					self._isNotModel = nil
					return true
				end
			end
		end
		self._isNotModel = true
		return false
	end

	function Model:save(...)
		assert(getmetatable(self) == Model, warn_msg)
		assert(type(self.id) == 'number')
		local fields = {...}
		local data = {}
		local ownFields = Model.GetFields()
		if #fields >= 0 then
			for _,field in ipairs(fields) do
				if ownFields[field] then
					data[field] = self[field]
				end
			end
			assert(next(data), 'Model:save nothing')
		else
			for k,_ in pairs(ownFields) do
				data[k] = self[k]
			end
		end
		data["id"] = nil
		if not next(data) then
			log("fields =", fields, "data =", self)
			assert(false)
			return false
		end
		
		local sql_cond = "WHERE `id` = " .. self.id
		local retval = get_database().update(tblName, data, sql_cond)
		if type(retval) == "table" then
			if retval.affected_rows == 1 then
				self._isNotModel = nil
				return true
			end
		end
		self._isNotModel = true
		return false
	end

	function Model:savedata(sdata, isCheck)
		assert(getmetatable(self) == Model, warn_msg)
		assert(type(self.id) == 'number')
		assert(next(sdata))
		local ownFields = Model.GetFields()
		if isCheck then
			for field,value in pairs(sdata) do
	       		if ownFields[field] then
	       			if self[field] ~= value then
	       				log("tblName:", tblName, "field =", field, "self[field] =", self[field], "value =", value)
	       				isCheck = false
	       				break
	       			end	       			
	       		end
	   		end
	   		if isCheck then
	   			return true
	   		end
		end
		local data = {}
		for field,value in pairs(sdata) do
			if ownFields[field] then
				self[field] = value
				data[field] = value
			end
		end
		data["id"] = nil
		if not next(data) then
			log("data =", sdata)
			assert(false)
			return true
		end

		local sql_cond = "WHERE `id` = " .. self.id
		local retval = get_database().update(tblName, data, sql_cond)
		if type(retval) == "table" then
			if retval.affected_rows == 1 then
				self._isNotModel = nil
				return true
			end
		end
		self._isNotModel = true
		return false
	end

	function Model:fetchdata(...)
		assert(getmetatable(self) == Model, warn_msg)
		assert(type(self.id) == 'number')
		local len = select('#', ...)
		assert(len > 0)
		local sql_cond
		if Model.has_deleted_at then
			sql_cond = "WHERE `deleted_at` is null AND `id` = " .. self.id
		else
			sql_cond = "WHERE `id` = " .. self.id
		end
   		local data = get_database().select(tblName, sql_cond, ...)
	    if type(data) ~= 'table' or #data == 0 then
	        return false
	    end
	    data = data[1]
	    for k,v in pairs(data) do
	        self[k] = v
	    end
	    return true
	end

	function Model:isNotModel()
		assert(getmetatable(self) == Model, warn_msg)
		return self._isNotModel
	end

	function Model:dusting()
		assert(getmetatable(self) == Model, warn_msg)
		setmetatable(self, nil)
		local fields = Model.GetFields()
		for k,_ in pairs(self) do
			if not fields[k] then
				if k ~= "created_at" and k ~= "updated_at" then
					self[k] = nil
				end
			end
		end
		setmetatable(self, Model)
	end

	function Model:snapshot()
		assert(getmetatable(self) == Model, warn_msg)
		local fields = Model.GetFields()
		local data = {}
		for k,v in pairs(self) do
			-- if type(v) ~= 'function' then
			if fields[k] then
				data[k] = v
			end
			-- end
		end
		return data
	end

	function Model:remove()
		assert(getmetatable(self) == Model, warn_msg)
		local data = {
			deleted_at = os.date("%Y-%m-%d %X")
		}
		local sql_cond = "WHERE `id` = " .. self.id
		local retval = get_database().update(tblName, data, sql_cond)
		if type(retval) == "table" then
			if retval.affected_rows == 1 then
				self._isNotModel = nil
				return true
			end
		end
		return false
	end

	-----------------------------------------------
	-----------------------------------------------
	function Model.MakeModel(data)
		assert(type(data) == 'table')
		-- local instance = {}
	    setmetatable(data, Model)
	    -- instance.mdata = data
	    data:dusting()
	    data:ctor()
	    return data
	end

	function Model.GetFields()
		if not Model._fields then
			Model._fields = get_database().fields(tblName)
			Model.has_deleted_at = Model._fields["deleted_at"] and true
			Model.has_updated_at = Model._fields["updated_at"] and true
			Model.has_created_at = Model._fields["created_at"] and true

			Model._fields["created_at"] = nil
    		Model._fields["updated_at"] = nil
    		Model._fields["deleted_at"] = nil
		end
		return Model._fields
	end

	-- function Model.GetModel(id)
	-- 	assert(type(id) == 'number')
 --   		local sql_cond = "WHERE `deleted_at` is null AND `id` = " .. id
 --   		local datas = database.select(tblName, sql_cond, "id")
	--     if type(datas) ~= 'table' or #datas == 0 then
	--         return
	--     end
	--     assert(#datas == 1)
	--  	local data = Model.makeModel(datas[1])
	--     return data
	-- end

	-- function Model.GetModels(ids)
	-- 	local sql_cond = "WHERE `deleted_at` is null AND `id` IN (" .. table.concat(ids, ", ") .. ")"
 --        local datas = database.select(tblName, sql_cond)
 --        for idx,data in ipairs(datas) do
 --            datas[idx] = Model.makeModel(data)
 --        end
	--     return datas
	-- end

	local function make_condition(query, options)
		-- log("make_condition query =", query)
		-- log("make_condition options =", options)
		local conds
		local option_conds
		if query and next(query) then
			local cond
			local typename
			for k,v in pairs(query) do
				typename = type(v)
				if k == "$or" or k == "$and" then
					local condition = conditions[k]
					assert(condition, "condition no exist:"..k)
					cond = condition(k, v)
					if conds then
						conds = conds .. " AND " .. cond
					else
						conds = cond
					end
				elseif typename == "table" then
					for opt,args in pairs(v) do
						local condition = conditions[opt]
						assert(condition, "condition no exist:"..opt)
						cond = condition(k, v, opt, args)
						if conds then
							conds = conds .. " AND " .. cond
						else
							conds = cond
						end
					end
				else
					if typename == "string" then
						cond = "`" .. k .. '` = \"' .. string.quote_sql_str(v) .. "\""
					elseif typename == "number" then
						cond = "`" .. k .. "` = " .. v
					elseif typename == "boolean" then
						cond = "" .. k .. "` = " .. (v and 1 or 0)
					else
						assert(false)
					end
					if conds then
						conds = conds .. " AND " .. cond
					else
						conds = cond
					end
				end
			end
		end
		if options and next(options) then
			local option = options["sort"]
			local tmp
			if option then
				options["sort"] = nil
				local sort_options
				local fields = string.split(option, " ")
				for _,field in ipairs(fields) do
					local char = string.byte(field, 1)
					if char == string.byte("-") then
						field = string.sub(field, 2)
						tmp = "`" .. field .. "` DESC"
					elseif char == string.byte("+") then
						field = string.sub(field, 2)
						tmp = "`" .. field .. "` ASC"
					else
						tmp = "`" .. field .. "` ASC"
					end
					if not sort_options then
						sort_options = tmp
					else
						sort_options = sort_options .. "," .. tmp
					end
				end
				tmp = "ORDER BY " .. sort_options
				if option_conds then
					option_conds = option_conds .. " " .. tmp
				else
					option_conds = tmp
				end
			end
			option = options["limit"]
			if option then
				options["limit"] = nil
				if options["skip"] then
					tmp = "LIMIT " .. options["skip"] .. ", " .. option
					options["skip"] = nil
				else
					tmp = "LIMIT " .. option
				end
				if option_conds then
					option_conds = option_conds .. " " .. tmp
				else
					option_conds = tmp
				end
			end
			if next(options) then
				assert(false)
			end
		end
		-- local sql_cond = ""
		if Model.has_deleted_at then
			local sql_cond = "WHERE `deleted_at` is null "
			if not conds then
				if option_conds then
					sql_cond = sql_cond .. option_conds
				end
			else
				if not option_conds then
					sql_cond = sql_cond .. "AND " .. conds
				else
					sql_cond = sql_cond .. "AND " .. conds .. " " .. option_conds
				end
			end
			return sql_cond
		else
			local sql_cond
			if not conds then
				if option_conds then
					sql_cond = option_conds
				end
			else
				if not option_conds then
					sql_cond = "WHERE " .. conds
				else
					sql_cond = sql_cond .. "WHERE " .. conds .. " " .. option_conds
				end
			end
			return sql_cond
		end
		-- if not conds then
		-- 	if option_conds then
		-- 		sql_cond = sql_cond .. option_conds
		-- 	end
		-- else
		-- 	if not option_conds then
		-- 		sql_cond = sql_cond .. "AND " .. conds
		-- 	else
		-- 		sql_cond = sql_cond .. "AND " .. conds .. " " .. option_conds
		-- 	end
		-- end
		-- return sql_cond
	end

	function Model.Finds(query, options, ...)
		if not Model._fields then
			Model.GetFields()
		end
		local sql_cond = make_condition(query, options)
		-- log("Model.Finds:", tblName, sql_cond, ...)
		local datas = get_database().select(tblName, sql_cond, ...)
		-- log("Model.Finds:", datas)
		if datas and #datas > 0 then
	        for idx,data in ipairs(datas) do
	            datas[idx] = Model.MakeModel(data)
	        end
	    end
	    return datas
	end

	function Model.Find(...)
		local models = Model.Finds(...)
		if models then
			return models[1]
		end
		return false
	end

	function Model.Count(query, options)
		local sql_cond = make_condition(query, options)
		local sql = "SELECT COUNT(*) FROM `" .. tblName .. "` " .. sql_cond .. ";"
		local ret = get_database().query(sql)
		assert(#ret == 1)
		return ret[1]['COUNT(*)']
	end

	return Model
end
