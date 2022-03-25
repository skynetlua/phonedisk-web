
----------------------------------------------
--Com
----------------------------------------------
local Com = class("Com")

function Com:ctor()
	self.name = name
end

function Com:match(req, res)
end

function Com:get_name()
	if not self.name then
		return self.__cname
	end
end

function Com:get_node()
    return self._node
end

function Com:set_node(node)
    self._node = node
    self._meiru  = node:get_meiru()
end

function Com:set_meiru(meiru)
	self._meiru = meiru
end

return Com
