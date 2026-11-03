-- Fail-closed persistence: a failed load is never later written over real data.
-- Only account progression is saved. Match gold and towers are intentionally temporary.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local STORE_NAME = "CHRDK_TD_Profile_v1"
local LOCK_SECONDS = 180
local SAVE_EVERY = 60
local Profiles = { Sessions = {}, store = nil, running = true }

local function defaults()
	return { schema = 1, xp = 0, wins = 0, bestWave = 0, kills = 0, matches = 0 }
end

local function sanitize(value)
	local result = defaults()
	if type(value) == "table" then
		for key, defaultValue in pairs(result) do
			local n = value[key]
			if type(n) == "number" and n == n and n >= 0 and n < 1e12 then
				result[key] = math.floor(n)
			else
				result[key] = defaultValue
			end
		end
	end
	return result
end

local function retry(callback)
	local lastError
	for attempt = 1, 3 do
		local ok, result = pcall(callback)
		if ok then return true, result end
		lastError = result
		if attempt < 3 then task.wait(0.8 * 2 ^ (attempt - 1) + math.random() * 0.2) end
	end
	return false, lastError
end

function Profiles:Init()
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then self.store = store end
	task.spawn(function()
		while self.running do
			task.wait(SAVE_EVERY)
			for player, session in pairs(self.Sessions) do
				task.spawn(function()
					if self.Sessions[player] ~= session or session.closed then return end
					local saved = self:Save(player, false)
					if session.lost then
						player:Kick("Профиль открыт на другом сервере. Подключитесь снова через минуту.")
					elseif not saved then
						warn("[Profiles] Autosave failed for", player.UserId)
					end
				end)
			end
		end
	end)
end

function Profiles:Load(player)
	local session = {
		data = defaults(), canSave = false, status = "loading", dirty = false,
		busy = false, closed = false, lost = false,
		lockId = HttpService:GenerateGUID(false),
	}
	self.Sessions[player] = session
	if RunService:IsStudio() or not self.store then
		session.status = "local"
		return session
	end
	local lockedByOther = false
	local ok, record = retry(function()
		return self.store:UpdateAsync("u_" .. player.UserId, function(old)
			lockedByOther = false
			-- PlayerRemoving may run while the initial UpdateAsync is in flight.
			if session.closed then return nil end
			if type(old) == "table" and type(old.lock) == "table"
				and old.lock.id ~= session.lockId and (old.lock.expires or 0) > os.time() then
				lockedByOther = true
				return nil
			end
			local data = sanitize(old)
			data.lock = { id = session.lockId, expires = os.time() + LOCK_SECONDS }
			return data
		end)
	end)
	if self.Sessions[player] ~= session or session.closed then
		-- If the lock was acquired just before disconnect, release only that lock.
		if ok and type(record) == "table" and type(record.lock) == "table" and record.lock.id == session.lockId then
			pcall(function()
				self.store:UpdateAsync("u_" .. player.UserId, function(old)
					if type(old) == "table" and type(old.lock) == "table" and old.lock.id == session.lockId then
						local data = sanitize(old)
						data.lock = nil
						return data
					end
					return nil
				end)
			end)
		end
		return session
	end
	if lockedByOther then
		session.status = "locked"
		player:Kick("Твой профиль ещё закрывается на другом сервере. Подожди минуту и попробуй снова.")
	elseif ok and type(record) == "table" and type(record.lock) == "table" and record.lock.id == session.lockId then
		session.data = sanitize(record)
		session.canSave = true
		session.status = "saved"
	else
		session.status = "unavailable"
		warn("[Profiles] Load failed; writes disabled for", player.UserId, record)
	end
	return session
end

function Profiles:Get(player)
	local session = self.Sessions[player]
	return session and session.data or defaults()
end

function Profiles:Add(player, fields)
	local session = self.Sessions[player]
	if not session then return end
	for key, amount in pairs(fields) do
		if session.data[key] ~= nil and type(amount) == "number" and amount >= 0 then
			session.data[key] = math.min(1e11, session.data[key] + math.floor(amount))
			session.dirty = true
		end
	end
end

function Profiles:Best(player, wave)
	local session = self.Sessions[player]
	if session and wave > session.data.bestWave then
		session.data.bestWave = wave
		session.dirty = true
	end
end

function Profiles:Save(player, release)
	local session = self.Sessions[player]
	if not session then return true end
	if release then session.closed = true end
	if not session.canSave then
		if release then self.Sessions[player] = nil end
		return session.status == "local"
	end
	local deadline = os.clock() + 12
	while session.busy and os.clock() < deadline do task.wait(0.05) end
	if session.busy then return false end
	session.busy = true
	local snapshot = table.clone(session.data)
	snapshot.lock = { id = session.lockId, expires = os.time() + LOCK_SECONDS }
	if release then snapshot.lock = nil end
	local ok, result = retry(function()
		return self.store:UpdateAsync("u_" .. player.UserId, function(old)
			if type(old) ~= "table" or type(old.lock) ~= "table" or old.lock.id ~= session.lockId then
				session.lost = true
				return nil
			end
			return snapshot
		end)
	end)
	local success = ok and type(result) == "table" and not session.lost
	session.busy = false
	if success then
		session.dirty = false
		session.status = "saved"
	elseif session.lost then
		session.canSave = false
		session.status = "lost"
	end
	if release then
		-- Keep a lost session marked so a late autosave cannot resurrect it.
		if not session.lost then self.Sessions[player] = nil end
	elseif not success then
		session.status = "unavailable"
	end
	return success
end

function Profiles:Shutdown()
	self.running = false
	local pending = 0
	for player in pairs(self.Sessions) do
		pending += 1
		task.spawn(function()
			self:Save(player, true)
			pending -= 1
		end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do task.wait(0.1) end
end

return Profiles
