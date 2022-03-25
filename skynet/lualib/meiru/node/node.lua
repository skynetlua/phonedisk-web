
local Node = class("Node")

function Node:ctor(name, meiru)
    self.name = assert(name)
    if meiru then
        assert(typeof(meiru) == 'Meiru')
        self._meiru = meiru
    end
end

function Node:set_method(method)
    self._method = method:lower()
end

function Node:set_path(path)
    self._path = path or "/"
    local parts = path:split("/")
    local path_params = {}
    local path_param
    for i,part in ipairs(parts) do
        -- if part:byte(1) == (":"):byte() then
        if part:byte(1) == 58 then
            local idx = part:find(".html", 1, true)
            if idx then
                local idx = part:find(".html", 1, true)
                part = part:sub(1, idx - 1)
            end
            path_param = {
                part  = part,
                mask  = true,
                param = part:sub(2) 
            }
        else
            path_param = {
                part = part,
                mask = false
            }
        end
        path_params[i] = path_param
    end
    self._path_params = path_params
end

function Node:get_path_params()
    return self._path_params
end

function Node:get_path()
    return self._path
end

function Node:open_strict()
    self._is_strict = true
end

function Node:open_terminal()
    self._is_terminal = true
end

function Node:check_pass(req, res)
    if self._method ~= req.method then
        return
    end

    local rpath_params = req.path_params
    if rpath_params and #rpath_params > 0 then
        local path_params = self._path_params
        if path_params and #path_params>0 and #rpath_params == #path_params then
            if self.is_strict then
                if #path_params ~= #rpath_params then
                    return
                end
            else
                if #path_params > #rpath_params then
                    return
                end
            end
            local params
            for i,nparam in ipairs(path_params) do
                local rparam = rpath_params[i]
                if nparam.mask then
                    params = params or {}
                    params[nparam.param] = rparam
                else
                    if nparam.part ~= rparam then
                        return
                    end
                end
            end
            req.params = params
        else
            if self._is_strict then
                if self._path ~= req.path then
                    return
                end
            end
        end
    end
    return true
end

function Node:dispatch(req, res)
    self.pass_mask = true

    if self._method and self._path_params then
        if not self:check_pass(req, res) then
            return
        end
    end
    
    local ret
    if self._coms then
        ret = self:dispatch_coms(req, res)
    end

    if ret == nil and self._children then
        ret = self:dispatch_childs(req, res)
    end

    if ret == nil and self._is_terminal then
        ret = false
    end
    return ret
end

function Node:dispatch_coms(req, res)
    local ret
    for _,com in ipairs(self._coms) do
        ret = com:match(req, res)
        com.pass_mask = true
        if ret ~= nil then
            break
        end
        if res.is_end then
            return true
        end
    end
    return ret
end

function Node:__add_child(child)
    local path_params = child:get_path_params()
    if not path_params then
        if not self._nopathNodes then
            self._nopathNodes = {}
        end
        table.insert(self._nopathNodes, child)
        return
    end
    local route_idx = self._route_idx or 1
    local param = path_params[route_idx]
    if not param or param.mask then
        if not self._nopathNodes then
            self._nopathNodes = {}
        end
        table.insert(self._nopathNodes, child)
        return
    end

    if not self._path2Node then
        self._path2Node = {}
    end
    local childs = self._path2Node[param.part]
    if not childs then
        self._path2Node[param.part] = {}
        childs = self._path2Node[param.part]
    end
    table.insert(childs, child)
end

function Node:dispatch_childs(req, res)
    local ret
    if self._path2Node then
        local rpath_params = req.path_params
        if rpath_params and #rpath_params > 0 then
            local route_idx = self._route_idx or 1
            local rparam = rpath_params[route_idx]
            local childs = self._path2Node[rparam]
            if childs then
                local path = req.path
                local method = req.method
                for _,node in ipairs(childs) do
                    if node._path == path and node._method == method then
                        path = nil
                        ret = node:dispatch(req, res)
                        if res.is_end then
                            return true
                        end
                        break
                    end
                end
                if path then
                    for _,node in ipairs(childs) do
                        ret = node:dispatch(req, res)
                        if ret ~= nil then
                            break
                        end
                        if res.is_end then
                            return true
                        end
                    end
                end
                return ret
            end
        end
    end
    if self._nopathNodes then
        for _,node in ipairs(self._nopathNodes) do
            ret = node:dispatch(req, res)
            if ret ~= nil then
                break
            end
            if res.is_end then
                return true
            end
        end
    end
    return ret
end

-- function Node:dispatch_childs(req, res)
--     local ret
--     if self._path then
--         ret = self:__dispatch_childs(req, res)
--     else
--         for _,node in ipairs(self._children) do
--             ret = node:dispatch(req, res)
--             if ret ~= nil then
--                 break
--             end
--             if res.is_end then
--                 return true
--             end
--         end
--     end
--     return ret
-- end

function Node:add(obj, ...)
    if type(obj) == "string" or type(obj) == "function" then
        self:add_com(obj, ...)
    else
        assert(type(obj) == "table")
        if obj.typeof("Com") then
            self:add_com(obj)
        elseif obj.typeof("Node") then
            self:add_child(obj)
        else
            assert(false, obj.__cname)
        end
    end
end

function Node:add_com(com, ...)
    if type(com) == "string" or type(com) == "function" then
        if type(com) == "string" then
            com = instance(com, ...)
        elseif type(com) == "function" then
            com = instance("ComHandle", com, ...)
        end
    else
        assert(type(com) == "table")
        assert(com.typeof("Com"))
    end
    assert(com:get_node() == nil)
    self._coms = self._coms or {}
    for _,_com in ipairs(self._coms) do
        if _com == com then
            assert(false, "_com == com repeat")
        end
    end
    table.insert(self._coms, com)
    com:set_node(self)
end

function Node:remove_com(com)
    assert(com:get_node() == self)
    if not self._coms then
        return
    end
    for idx, _com in ipairs(self._coms) do
        if _com == com then
            table.remove(self._coms, idx)
            return
        end
    end
end

function Node:get_meiru()
    return self._meiru
end

function Node:set_meiru(meiru)
    self._meiru = meiru
    if self._coms then
        for _,com in ipairs(self._coms) do
            com:set_meiru(meiru)
        end
    end
    if self._children then
        for _,node in ipairs(self._children) do
            node:set_meiru(meiru)
        end
    end
end

function Node:get_children()
    return self._children
end

function Node:add_child(child)
    assert(child:get_parent() == nil)
    self._children = self._children or {}
    for _,_child in ipairs(self._children) do
        if _child == child then
            assert(false)
        end
    end

    table.insert(self._children, child)
    child:set_parent(self)
    -- if not child:get_meiru() and self.meiru then
        child:set_meiru(self._meiru)
    -- end
    self:__add_child(child)
end

function Node:remove_child(child)
    if not self._children then
        return
    end
    for idx,_child in ipairs(self._children) do
        if _child == child then
            child:set_parent(nil)
            table.remove(self._children, idx)
            return
        end
    end
end

function Node:get_child(idx)
    if not self._children then
        return
    end
    return self._children[idx]
end

function Node:get_child_byname(name)
    if not self._children then
        return
    end
    for _,child in ipairs(self._children) do
        if child.name == name then
            return child
        end
    end
end

function Node:search_child_byname(name, depth)
    if not self._children then
        return
    end
    for _,child in ipairs(self._children) do
        if child.name == name then
            return child
        end
    end
    if depth then
        depth = depth-1
        if depth <= 0 then
            return
        end
    end
    local sub_child
    for _,child in ipairs(self._children) do
        sub_child = child:search_child_byname(name, depth)
        if sub_child then
            return sub_child
        end
    end
end

function Node:get_parent()
    return self._parent
end

function Node:set_parent(parent)
    self._parent = parent
end

function Node:get_root()
    local root = self:get_parent()
    if root == nil then
        return
    end
    while root:get_parent() do
        root = root:get_parent()
    end
    return root
end

function Node:footprint(depth)
    depth = (depth or 0)+1
    if self.pass_mask then
        self.pass_mask = nil
        local rets = {}
        if self._path then
            table.insert(rets, string.rep("++", depth) .. self.name .. ":[" .. (self._method and self._method .. ":" or '') .. self._path .. "]")
        else
            table.insert(rets, string.rep("++", depth) .. self.name)
        end
        if self._coms then
            for _,com in ipairs(self._coms) do
                if com.pass_mask then
                    table.insert(rets, string.rep("--", depth) .. com.__cname)
                    com.pass_mask = nil
                end
            end
        end
        if self._children then
            for _,child in ipairs(self._children) do
                local ret = child:footprint(depth)
                if ret then
                    table.insert(rets, ret)
                end
            end
        end
        return table.concat(rets, "\n")
    end
end

function Node:treeprint(depth)
    depth = (depth or 0)+1
    local rets = {}
    if self._path then
        if self._method then
            table.insert(rets, string.rep("++", depth) .. self.name..":["..self._method..":"..self._path.."]")
        else
            table.insert(rets, string.rep("++", depth) .. self.name..":["..self._path.."]")
        end
    else
        table.insert(rets, string.rep("++", depth) .. self.name)
    end
    if self._coms then
        for _,com in ipairs(self._coms) do
            table.insert(rets, string.rep("--", depth) .. com.__cname)
        end
    end
    if self._children then
        for _,child in ipairs(self._children) do
            local ret = child:treeprint(depth)
            if ret then
                table.insert(rets, ret)
            end
        end
    end
    return table.concat(rets, "\n")
end

return Node
