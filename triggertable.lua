local function isEqual(a, b)
	if a == b then return true
	elseif type(a) ~= type(b) then return false 
	elseif type(a) ~= "table" then return false
	else 
		for k, v in pairs(a.__values) do
			if not isEqual(v, b[k]) then return false end
		end
		for k, v in pairs(b.__values) do
			if a[k] == nil then return false end
		end 
	end
	return true
end

local function outOfDate(t, k, iswhat, callStamp)
	local stamp = callStamp
	while stamp do
		if stamp[t] then
			for _, par in ipairs(stamp[t]) do
				if par[1] == k and par[2] == iswhat then
					return true
				end
			end
		end
		stamp = stamp.next
	end
	callStamp[t] = callStamp[t] or {}
	table.insert(callStamp[t], {k, iswhat})
	return false
end

local function trueCall(t, k, v, iswhat, equal)
	rawset(t, "__iswhat_now__", iswhat)
	rawset(t, "__now_key_", k)
	rawset(t, "__is_equal__", equal)
	local callList = {}
	for i = 1, table.maxn(t.__recall__) do
		if t.__recall__[i] then
			for _, fun in ipairs(t.__recall__[i]) do
				callList[#callList+1] = fun
			end
		end
	end
	for _, fun in ipairs(callList) do
		local p = {}
		local len = table.maxn(fun[2])
		for i = 1, len do
			p[i] = fun[2][i]
		end
		p[len+1] = t; p[len+2] = k; p[len+3] = v; 
		xpcall(function () fun[1](unpack(p, 1, len+3)) end, XpcallErrorHandle)
	end
	rawset(t, "__iswhat_now__", nil)
	rawset(t, "__now_key_", nil)
	rawset(t, "__is_equal__", nil)
end

local function recall(t, k, v, iswhat, callStamp, equal, fromChild)
	if outOfDate(t, k, iswhat, callStamp) then return end
	local meta = getmetatable(t)
	if fromChild then 
		meta.__old__[k] = meta.__values__[k]
	end
	if meta.__mute__ then
		meta.silentQueue[k] = meta.silentQueue[k] or {}
		if meta.silentQueue[k][iswhat] == nil then meta.silentQueue[k][iswhat] = true end
		meta.silentQueue[k][iswhat] = meta.silentQueue[k][iswhat] and equal
	else
		trueCall(t, k, v, iswhat, equal)
	end
	for father, keys in pairs(t.__father__) do
		for k, iswhat in pairs(keys) do
			if iswhat == 1 then
				recall(father, k, father[k], 1, callStamp, equal, true)
			elseif iswhat == 2 then
				recall(father, k, t, 2, callStamp, equal, true)
			elseif iswhat == 3 then
				recall(father, k, t, 1, callStamp, equal, true)
				recall(father, k, t, 2, callStamp, equal, true)
			end
		end
	end
end

local function unTrace(t, father, k)
	if type(t) == "table" and type(t.__father__) == "table" and type(t.__father__[father]) == "table" then
		t.__father__[father][k] = nil
	end
end
local recordForHU = setmetatable({}, {__mode = "k"})

function TriggerTable(t, father, k, iswhat)
	if t == nil then t = {} end
	if type(t) ~= "table" then return t end
	local meta = {}; meta.__values__ = {};meta.__old__ = {};meta.silentQueue = {}  
	local oldMeta = getmetatable(t)
	if oldMeta then
		if not oldMeta.__values__ then
			setmetatable(meta.__values__, oldMeta)
			setmetatable(t, nil)
			oldMeta = nil
		end
	end
	t.__father__ = t.__father__ or {}
	if father and k and iswhat then
		t.__father__[father] = t.__father__[father] or {}
		t.__father__[father][k] = iswhat
	end 
	if oldMeta then return t end
	setmetatable(t, meta)
	for k, v in pairs(t) do
		if type(k) ~= "string" or not string.find(k, "^__.*__$") then
			meta.__values__[k] = TriggerTable(v, t, k, 2)
			meta.__old__[k] = meta.__values__[k]
			TriggerTable(k, t, k, 1)
		end
	end
	for k in pairs(meta.__values__) do 
		t[k] = nil
	end
	t.__recall__ = {[5]={}}
	function t.__reg(f, ...)
		if type(f) == "function" then
			local d = {f, {...}}
			table.insert(t.__recall__[5], d)
			return {5, d}
		end
	end
	function t.__priority(d, l)
		if type(d) ~= "table" or type(l) ~= "number" or d[1] == l then return end
		t.__unreg(d)
		t.__recall__[l] = t.__recall__[l] or {}
		table.insert(t.__recall__[l], d[2])
		d[1] = l
	end
	function t.__unreg(d)
		if type(d) == "table" and d[1] and d[2] then 
			for k, v in ipairs(t.__recall__[d[1]]) do
				if v == d[2] then
					table.remove(t.__recall__[d[1]], k)
				end
			end
		end
	end
	function t.__sort(...)
		meta.copytoOld()
		table.sort(meta.__values__, ...)
		meta.checkCall()
	end
	function t.__insert(...)
		meta.copytoOld()
		table.insert(meta.__values__, ...)
		meta.checkCall("i")
	end
	function t.__remove(...)
		meta.copytoOld()
		local result = table.remove(meta.__values__, ...)
		meta.checkCall("r")
		return result
	end
	function t.__clear()
		local keys = {}
		for k in pairs(meta.__values__) do
			keys[#keys+1] = k
		end
		for _, k in ipairs(keys) do
			t[k] = nil
		end 
	end
	function t.__concat(...)
		return table.concat(meta.__values__, ...)
	end
	function t.__maxn(...)
		return table.maxn(meta.__values__)
	end
	function t.__old(k)
		k = k or t.__now_key_
		if k then return meta.__old__[k] end
	end
	function t.__type()
		local temp = {"key", "value"}
		return temp[t.__iswhat_now__]
	end
	function t.__equal()
		return t.__is_equal__
	end
	function t.__same()
		return meta.__old__[t.__now_key_] == meta.__values__[t.__now_key_]
	end
	function t.__mute()
		meta.__mute__ = true
	end
	function t.__unmute()
		meta.__mute__ = false
		for k, v in pairs(meta.silentQueue) do
			for iswhat, equal in pairs(v) do
				trueCall(t, k, t[k], iswhat, equal)
			end
		end
		meta.silentQueue = {}
	end
	function meta.__index(t, k)
		if k == "__values" then return meta.__values__ end
		return meta.__values__[k]
	end
	function meta.__newindex(t, k, v)
		meta.__old__[k] =  meta.__values__[k]
		if meta.__values__[k] ~= v then
			if v == nil then 
				unTrace(meta.__values__[k], t, k)
				unTrace(k, t, k)
				meta.__values__[k] = nil
			else
				if type(k) == "table" and k == v then
					meta.__values__[k] = TriggerTable(v, t, k, 3)	
				else
					meta.__values__[k] = TriggerTable(v, t, k, 2)
					TriggerTable(k, t, k, 1)
				end
			end
		end
		local equal = isEqual(meta.__old__[k], v)
		recall(t, k, v, 2, {}, equal)
	end
	function meta.copytoOld()
		local len_old = table.maxn(meta.__old__)
		local len_values = table.maxn(meta.__values__)
		for i = 1, len_values do
			meta.__old__[i] = meta.__values__[i]
		end
		for i = len_values+1, len_old do
			meta.__old__[i] = nil
		end
	end
	function meta.checkCall(mode)
		local len = math.max(table.maxn(meta.__old__), table.maxn(meta.__values__))
		for i = 1, len do
			if meta.__old__[i] ~= meta.__values__[i] then
				if mode == "i" then
					TriggerTable(meta.__values__[i], t, i, 2)
					mode = nil
				elseif mode == "r" then
					unTrace(meta.__old__[i], t, i)
					mode = nil
				end
				local equal = isEqual(meta.__old__[i], meta.__values__[i])
				recall(t, i, meta.__values__[i], 2, {}, equal)
			end
		end
	end
	recordForHU[t] = true
	return t
end

return TriggerTable