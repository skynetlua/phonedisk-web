


return function(get_func, deltaTime)
	assert(type(get_func) == "function")

	local __time2caches = {}
	local __key2data = {}
	local startTime = os.time()
	local nextTime = 0
	local clearIdx = 0
	deltaTime = deltaTime or 60

	local function removeData(key)
		assert(key)
		local data = __key2data[key]
		if not data then
			return
		end
		__key2data[key] = nil
		local pcurIdx = data.__curIdx
		if pcurIdx then
			local datas = __time2caches[pcurIdx]
	        if datas then
	            datas[key] = nil
	        end
		end
	end

	local function getData(key)
		assert(key)
	    local curTime = os.time()
	    local curIdx = math.floor((curTime-startTime)/deltaTime)
	    if curTime > nextTime then
	        nextTime = curTime+deltaTime
	        local idx = clearIdx
	        local datas
	        for idx=clearIdx,curIdx-10 do
	            datas = __time2caches[idx]
	            if datas then
	                for key,_ in pairs(datas) do
	                    __key2data[key] = nil
	                end
	            end
	        end
	        clearIdx = idx
	    end

	    local data = __key2data[key]
	    if not data or data.__needClear then
	    	if data and data.__curIdx then
	    		local datas = __time2caches[data.__curIdx]
	            if datas then
	                datas[key] = nil
	            end
	    	end
	        data = get_func(key)
	        if data then
	            __key2data[key] = data
	        end
	    end
	    if data then
	        local pcurIdx = data.__curIdx
	        if pcurIdx and pcurIdx ~= curIdx then
	            local datas = __time2caches[pcurIdx]
	            if datas then
	                datas[key] = nil
	            end
	            pcurIdx = nil
	        end
	        if not pcurIdx then
	            data.__curIdx = curIdx
	            local datas = __time2caches[curIdx]
	            if not datas then
	                datas = {}
	                __time2caches[curIdx] = datas
	            end
	            datas[key] = true
	        end
	        return data
	    end
	    __key2data[key] = false
	end

	return {
		getData = getData,
		removeData = removeData
	}
end