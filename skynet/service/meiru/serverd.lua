
local skynet = require "skynet"
local socket = require "skynet.socket"
local server = require "meiru.util.server"

local table  = table
local string = string
local command = {}

--每个IP，每秒钟，可以访问次数
local kMCountPerIpPerSecond = 16
local kMCountPerIpPerMinute = 512
local kMMissMaxPerMinute = 30

local _slaves = {}

-- local _blacklistd
local _blacklists = {}
local _blackcount = {}

local _config;
-- local _json_file = "./data/json/blacklist.json"

-- 1 秒流量
-- 2 分流量
-- 3 未完成
-- 4 国外
-- 5 国内

local _server_id = skynet.self()

local function add_blacklist(ip, reason)
	if _blacklists[ip] then
		local count = _blackcount[ip] or 0
		count = count+1
		_blackcount[ip] = count
		if count > 200 then
			if _blacklists[ip] == 168 then
				skynet.error("firewall stop cdn ip =", ip)
			else
				skynet.error("firewall kick ip =", ip)
				-- skynet.send(_blacklistd, "lua", "kick", _server_id, ip)
			end
		end
		return
	end
	skynet.error("add_blacklist ip =", ip, "reason =", reason)
	_blackcount[ip] = 1
	_blacklists[ip] = reason or true
	-- local content = json.encode(_blacklists)
	-- io.writefile(_json_file, content)
end

local _whitelists = {
	["121.51.58.170"] = true,
	["121.51.58.175"] = true,
	["121.51.58.173"] = true,
	["101.226.103.16"] = true,
	["121.51.58.168"] = true,
	["127.0.0.1"] = true,
}

local function check_ip(ip)
	if _whitelists[ip] then
		return
	end
	-- skynet.send(_blacklistd, "lua", "check_ip", _server_id, ip)
end

local function add_whitelist(ip)
	skynet.error("add_whitelist ip =", ip)
	_whitelists[ip] = true
end


local function load_blacklist()
	-- _blacklistd = skynet.uniqueservice("meiru/blacklistd", ".blacklistd")
end


-- 127.0.0.1
-- 159.223.92.253
-- 58.255.109.145

---------------------------------------------
--slave
---------------------------------------------
local function create_slaves(config)
	local service_num = config.service_num or 1
	local protocol = config.protocol
	for instanceId = 1, service_num do
		local slaveId = skynet.newservice("meiru/agentd", protocol, instanceId, config.port)
		-- skynet.log("create_slaves slaveId =", slaveId, "instanceId =", instanceId)
		local slave = {
			slaveId = slaveId,
			instanceId = instanceId,
			config = config,
			users = {},
			master = skynet.self()
		}
		skynet.call(slaveId, "lua", "start", slave)
		-- skynet.log("create_slaves params =", params)
		table.insert(_slaves, slave)
	end
end

local _balanceIdx = 1
local _ip2slave = {}
local function get_slave(ip)
	local slave = _ip2slave[ip]
	if slave then
		return slave
	end
	while not slave do
		slave = _slaves[_balanceIdx]
		_balanceIdx = _balanceIdx + 1
		if _balanceIdx > #_slaves then
			_balanceIdx = 1
		end
	end
	_ip2slave[ip] = slave
	return slave
end

---------------------------------------------
--Client
---------------------------------------------
local Client = class("Client")

function Client:ctor(ip)
	self.ip = ip
	self.slave = get_slave(ip)
	self.visit_times = 0
	self.finish_times = 0
	self.mvisit_times = 0
	self.mfinish_times = 0

	self.second_times = 0
	self.minute_times = 0

	self.max_second_times = 0
	self.max_minute_times = 0

	local curtime = os.time()
	self.second_anchor = curtime
	self.minute_anchor = math.floor(curtime/60)
end

function Client:is_invalid()
	local curtime = os.time()
	if curtime == self.second_anchor then
		if self.second_times > kMCountPerIpPerSecond then
			skynet.error("Client:is_invalid ip =", self.ip, "second_limit_times =", self.second_times, os.date("|%m-%d %X"))
			return 1 + self.second_times*10
		end
		self.second_times = self.second_times+1
	else
		if self.second_times > self.max_second_times then
			self.max_second_times = self.second_times
		end
		self.second_times = 0
	end

	curtime = math.floor(curtime/60)
	if curtime == self.minute_anchor then
		if self.minute_times > kMCountPerIpPerMinute then
			skynet.error("Client:is_invalid ip =", self.ip, "minute_limit_times =", self.minute_times, os.date("|%m-%d %X"))
			return 2 + self.minute_times*10
		end
		self.minute_times = self.minute_times+1
	else
		if self.minute_times > self.max_minute_times then
			self.max_minute_times = self.minute_times
		end
		self.minute_times = 0
		self.mvisit_times = 0
		self.mfinish_times = 0
	end

	local delta_times = self.mvisit_times - self.mfinish_times
	if delta_times > 20 then
		skynet.error("[error]Client:is_invalid ip =", self.ip, "delta_times =", delta_times, os.date("|%m-%d %X"))
		return 3 + delta_times*10
	end
end

function Client:record_visit_times(addr)
	self.visit_times = self.visit_times+1
	self.mvisit_times = self.mvisit_times+1
	local curtime = os.time()
	self.last_visit_time = curtime
	skynet.error("\n\n\n[New]Client:addr =", addr, 
		"visit_times =", self.visit_times, 
		"finish_times =", self.finish_times, 
		"mvisit_times =", self.mvisit_times, 
		"mfinish_times =", self.mfinish_times, 
		"max_second_times =", self.max_second_times, 
		"max_minute_times =", self.max_minute_times, 
		os.date("|%m-%d %X"))
end

-----------------------------------------
-----------------------------------------
local total_anchor = 0
local _total_keys = {}
local _total_times = {}
local _total_ip_times = {}
local function record_times(ip)
	-- local cur_anchor = math.floor(os.time()/1800)
	local cur_anchor = os.date("%y-%m-%d %H:%M")
	if total_anchor ~= cur_anchor then
		total_anchor = cur_anchor
		table.insert(_total_keys, cur_anchor)

		-- if #_total_keys>100 then
		--     local total_key = table.remove(_total_keys, 1)
		--     _total_ip_times[total_key] = nil
		--     _total_times[total_key] = nil
		-- end
		-- if not _total_ip_times[cur_anchor] then
		--     _total_ip_times[cur_anchor] = {}
		--     _total_times[cur_anchor] = 0
		-- end
	end
	local ip_times = _total_ip_times[cur_anchor]
	if not ip_times then
		ip_times = {}
		_total_ip_times[cur_anchor] = ip_times
	end
	ip_times[ip] = (ip_times[ip] or 0) + 1
	_total_times[cur_anchor] = (_total_times[cur_anchor] or 0) + 1
end

local _clientsmap = {}
local function get_client(ip)
	local client = _clientsmap[ip]
	if not client then
		client = Client.new(ip)
		_clientsmap[ip] = client
	end
	return client
end

local function remove_client(ip)
	_clientsmap[ip] = nil
	-- log("remove_client ip =", ip)
end

local function client_enter(fd, addr)
	local ip = addr:match("([^:]+)")
	record_times(ip)
	local client = get_client(ip)
	if _blacklists[ip] then
		skynet.error("client_enter blacklists ip:", ip)
		client:record_visit_times(addr)
		return
	end
	local ret = client:is_invalid()
	if ret then
		add_blacklist(ip, ret)
		client:record_visit_times(addr)
		return
	end
	-- check_ip(ip)
	client:record_visit_times(addr)
	return client
end

---------------------------------------------------------------------------
---------------------------------------------------------------------------
local function check_services(config)
	if not config or not next(config) then
		config = {
			['http'] = "web", 
			['ws'] = "ws",
		}
		config.protocol = 'http'
	else
		if config['http'] or config['ws'] then
			assert(not config['https'] and not config['wss'])
			config.protocol = 'http'
		elseif config['https'] or config['wss'] then
			assert(not config['http'] and not config['ws'])
			config.protocol = 'https'
		else
			assert(false)
		end
	end
	return config
end 

local _listen_fd 
function command.start(config)
	assert(not _listen_fd)
	-- skynet.log("start config =", config)
	config = check_services(config)
	local host = config.host or "0.0.0.0"
	local port = tonumber(config.port)
	local protocol = config.protocol
	if not port then
		port = (protocol == 'http' and 80) or (protocol == 'https' and 443)
		assert(port, "[serverd] need port")
	end
	config.port = port
	create_slaves(config)
	_config = config
	skynet.error(string.format("Serverd listen %s://%s:%s", protocol, host, port))
	_listen_fd = socket.listen(host, port)
	assert(_listen_fd, "listen error")
	socket.start(_listen_fd, function(fd, addr)
		local client = client_enter(fd, addr)
		if client then
			skynet.send(client.slave.slaveId, "lua", "enter", fd, addr)
		else
			socket.close(fd)
		end
	end)
end

function command.finish(fd, addr)
	local ip = addr:match("([^:]+)")
	local client = get_client(ip)
	client.finish_times = client.finish_times+1
	client.mfinish_times = client.mfinish_times+1
end

function command.add_blacklist(ip, reason)
	add_blacklist(ip, reason)
end

function command.kick(ip, reason)
	remove_client(ip)
	add_blacklist(ip, reason)
end

function command.remove_blacklist(ip)
	_blacklists[ip] = nil
end

function command.add_whitelist(ip)
	add_whitelist(ip)
end

function command.client_infos()
	local infos = {}
	for _,client in pairs(_clientsmap) do
		local info = {
			ip    = client.ip,
			black = _blacklists[client.ip],
			port  = _config.port,
			slaveId = client.slave.slaveId,
			visit_times = client.visit_times,
			finish_times = client.finish_times,
			max_stimes  = client.max_second_times,
			max_mtimes  = client.max_minute_times,
			last_visit_time = client.last_visit_time,
		}
		table.insert(infos, info)
	end
	return infos
end

function command.server_records()
	local records = {}
	local ip_count
	for _,key in ipairs(_total_keys) do
		ip_count = 0
		for _ in pairs(_total_ip_times[key]) do
			ip_count = ip_count+1
		end
		records[key] = {
			time = key,
			ip_count = ip_count,
			visit_times = _total_times[key]
		}
	end
	return records
end

function command.exit()
	for _, slave in pairs(_slaves) do
		skynet.call(slave.slaveId, "lua", "exit")
	end
end

function command.stop()
	socket.close(listen_fd)
	listen_fd = nil
	for _, slave in pairs(_slaves) do
		skynet.call(slave.slaveId, "lua", "stop")
	end
end

-- skynet.start(function()
-- 	load_blacklist()
-- 	skynet.dispatch("lua", function(_,_,cmd,...)
-- 		local f = command[cmd]
-- 		if f then
-- 			skynet.ret(skynet.pack(f(...)))
-- 		else
-- 			assert(false,"error no support cmd"..cmd)
-- 		end
-- 	end)
-- end)

server(command, load_blacklist, ...)
