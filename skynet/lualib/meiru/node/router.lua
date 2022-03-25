
local Node = require "meiru.node.node"

local Router = class("Router", Node)

function Router:ctor(name, meiru)
	Node.ctor(self, name, meiru)
    self._path2Node = {}
end

local function create_node(method, path, ...)
    local node = Node.new("node_router")
    node:set_method(method)
    node:set_path(path)
    node:open_strict()
    node:open_terminal()

    for i = 1, select('#', ...) do
        local field = select(i, ...)
        node:add(field)
    end
    return node
end


local function load_router(router, params)
    local route_rules = params.route_rules
    local route_dir   = params.route_dir
    local type_part   = params.type_part
    local model_names = {}
    local part_len = #type_part
 
    local masks = {}
    local model_masks = {}
    for _,route_rule in ipairs(route_rules) do
        local method_name = route_rule[1]
        if not masks[method_name] then
            masks[method_name] = true
            assert(router[method_name], "method no support:" .. method_name)
        end
        local route_path = route_rule[2]
        local idx = string.find(route_path, "/", part_len, true)
        if not idx then
            assert(false, "route_path error:" .. route_path)
        end

        local model_name = string.sub(route_path, part_len+1, idx-1)
        if not model_masks[model_name] then
            model_masks[model_name] = true
            table.insert(model_names, model_name)
        end
    end

    local methods = {}
    for _,model_name in ipairs(model_names) do
        local path = route_dir .. model_name
        local model = require(path)
        for method_name,handles in pairs(model) do
            local method = methods[method_name]
            if not method then
                methods[method_name] = {}
                method = methods[method_name]
            end
            for path_name,handle in pairs(handles) do
                assert(not method[path_name], "repeat path_name:" .. path_name)

                method[path_name] = handle
            end
        end
    end
    for _,route_rule in ipairs(route_rules) do
        local method_name = route_rule[1]
        local path = route_rule[2]:sub(2)
        table.remove(route_rule, 1)

        local method = methods[method_name]
        assert(method, "no implement method:" .. method_name .. ", path:" .. path)
        
        local path_name = string.gsub(path, "[/:]", "_")
        local handle = method[path_name]
        assert(handle, "no implement route_rule:" .. method_name .. ", " .. path_name)
        table.insert(route_rule, handle)
        router[method_name](table.unpack(route_rule))
    end
end

local function add_handle(router, method_name, path_name, handle)
    local methods = router.__methods
    local method = methods[method_name]
    if not method then
        method = {}
        methods[method_name] = method
    end
    if method[path_name] then
        assert(false, "repeat path_name:" .. path_name)
    end
    method[path_name] = true

    local route_rule = {""}

    local coms = router.__coms
    local idx, tmp
    for com_name,com in pairs(coms) do
        idx = path_name:find(com_name, 1, true)
        if idx then
            route_rule[#route_rule+1] = com
            path_name = path_name:sub(1, idx-1) .. path_name:sub(idx+#com_name)
        end
    end
    idx = path_name:find("__", 1, true)
    if idx then
        tmp = path_name:find("_", idx+2, true)
        if tmp then
            path_name = path_name:sub(1, idx) .. ":" .. path_name:sub(idx+2, tmp-1) .. path_name:sub(tmp)
        else
            path_name = path_name:sub(1, idx) .. ":" .. path_name:sub(idx+2)
        end
    end

    idx = path_name:find("_html", 1, true)
    if idx and idx+4 == #path_name then
        path_name = path_name:sub(1, idx-1) .. ".html"
    end
    path_name = path_name:gsub("_", "/")
    route_rule[1] = "/" .. path_name
    route_rule[#route_rule+1] = handle
    router[method_name](table.unpack(route_rule))
end

local function add_model(router, model)
    local methods = router.__methods
    for method_name, handles in pairs(model) do
        local method = methods[method_name]
        if not method then
            method = {}
            methods[method_name] = method
        end
        for path_name, handle in pairs(handles) do
            add_handle(router, method_name, path_name, handle)
        end
    end
end

local function load_new_router(router, params)

    local coms = {}
    for com_name, com in pairs(params.coms) do
        coms["__" .. com_name] = com
    end
    router.__coms = coms
    router.__methods = {}

    local model_path, model
    local route_dir = params.route_dir
    for _,model_name in ipairs(params.models) do
        model_path = route_dir .. "." .. model_name
        model = require(model_path)
        add_model(router, model)
    end

    -- local idx, route_rule, url, tmp
    -- for _,model_name in ipairs(params.models) do
    --     model_path = route_dir .. "." .. model_name
    --     model = require(model_path)
    --     for method_name, handles in pairs(model) do
    --         local method = methods[method_name]
    --         if not method then
    --             method = {}
    --             methods[method_name] = method
    --         end
    --         for path_name, handle in pairs(handles) do
    --             if method[path_name] then
    --                 assert(false, "repeat path_name:" .. path_name)
    --             end
    --             method[path_name] = handle

    --             route_rule = {""}
    --             for com_name,com in pairs(coms) do
    --                 idx = path_name:find(com_name, 1, true)
    --                 if idx then
    --                     route_rule[#route_rule+1] = com
    --                     path_name = path_name:sub(1, idx-1) .. path_name:sub(idx+#com_name)
    --                 end
    --             end
    --             idx = path_name:find("__", 1, true)
    --             if idx then
    --                 tmp = path_name:find("_", idx+2, true)
    --                 if tmp then
    --                     path_name = path_name:sub(1, idx) .. ":" .. path_name:sub(idx+2, tmp-1) .. path_name:sub(tmp)
    --                 else
    --                     path_name = path_name:sub(1, idx) .. ":" .. path_name:sub(idx+2)
    --                 end
    --             end

    --             idx = path_name:find("_html", 1, true)
    --             if idx and idx+4 == #path_name then
    --                 path_name = path_name:sub(1, idx-1) .. ".html"
    --             end
    --             path_name = path_name:gsub("_", "/")
    --             route_rule[1] = "/" .. path_name
    --             route_rule[#route_rule+1] = handle
    --             router[method_name](table.unpack(route_rule))
    --         end
    --     end
    -- end
end

local function create_router(name, params)
    local router_name = "node_routers"
    if type(name) == "string" then
        router_name = name
    end
    local node_router = Router.new(router_name)

    local router = {}
    function router.get(path, ...)
        assert(type(path) == "string")
        assert(select('#', ...) > 0)
        local node = create_node("get", path, ...)
        node_router:add_child(node)
    end

    function router.post(path, ...)
        assert(type(path) == "string")
        assert(select('#', ...) > 0)
        local node = create_node("post", path, ...)
        node_router:add_child(node)
    end

    -- function router.put(path, ...)
    --     assert(type(path) == "string")
    --     assert(select('#', ...) > 0)
    --     local node = create_node("put", path, ...)
    --     node_router:add_child(node)
    -- end

    -- function router.delete(path, ...)
    --     assert(type(path) == "string")
    --     assert(select('#', ...) > 0)
    --     local node = create_node("delete", path, ...)
    --     node_router:add_child(node)
    -- end

    function router.node()
        return node_router
    end

    function router.bind(method_name, path_name, handle)
        add_handle(router, method_name, path_name, handle)
    end
    
    function router.bind_model(model)
        add_model(router, model)
    end

    params = params or name
    if params and type(params) == "table" then
        node_router._route_idx = params.route_idx
        if params.route_rules then
            load_router(router, params)
        else
            load_new_router(router, params)
        end
    end
    return router
end

return create_router

