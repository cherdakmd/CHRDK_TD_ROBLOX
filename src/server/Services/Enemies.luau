local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Path = require(ReplicatedStorage.Shared:WaitForChild("Path"))
local Models = require(script.Parent.Models)
local Enemies = { Active = {}, nextId = 0, folder = nil }

function Enemies:Init(folder)
	self.folder = folder
end

function Enemies:Clear()
	for _, enemy in pairs(self.Active) do
		if enemy.model then enemy.model:Destroy() end
	end
	self.Active = {}
	if self.folder then self.folder:ClearAllChildren() end
end

function Enemies:Spawn(kind, wave, playerCount, difficulty, finalBoss)
	local def = Config.Enemies[kind]
	assert(def, "Unknown enemy")
	self.nextId += 1
	local model, bar = Models.Enemy(kind, self.nextId)
	local maxHP = math.floor(def.hp * Config.HealthScale(wave) * Config.PartyHealthScale(playerCount) * Config.Difficulties[difficulty].health * (finalBoss and 2.4 or 1))
	local enemy = {
		id = self.nextId, kind = kind, def = def, model = model, bar = bar,
		hp = maxHP, maxHP = maxHP, progress = 0, speed = def.speed,
		position = Vector3.zero, damageByPlayer = {}, totalDamage = 0,
		slowUntil = 0, slowFactor = 1, slowed = false, dead = false,
	}
	self.Active[enemy.id] = enemy
	self:Position(enemy, 0)
	model.Parent = self.folder
	return enemy
end

function Enemies:Position(enemy, now)
	local x, z, angle = Path.Sample(enemy.progress)
	local bob = enemy.def.flying and math.sin(now * 3 + enemy.id) * 0.45 or 0
	local height = enemy.def.flying and 6 + bob or 1.6 * enemy.def.size + 0.3
	enemy.position = Vector3.new(x, height, z)
	enemy.model:PivotTo(CFrame.new(enemy.position) * CFrame.Angles(0, angle, 0))
end

function Enemies:Update(dt, now)
	local leaked = {}
	for id, enemy in pairs(self.Active) do
		local slowed = now < enemy.slowUntil
		if slowed ~= enemy.slowed then
			enemy.slowed = slowed
			local body = enemy.model:FindFirstChild("Body")
			if body then body.Color = slowed and enemy.def.color:Lerp(Color3.fromRGB(130, 228, 255), 0.65) or enemy.def.color end
		end
		if not slowed then enemy.slowFactor = 1 end
		enemy.progress += enemy.speed * (slowed and enemy.slowFactor or 1) * dt
		if enemy.progress >= Path.Length then
			enemy.dead = true
			self.Active[id] = nil
			enemy.model:Destroy()
			table.insert(leaked, enemy)
		else
			self:Position(enemy, now)
		end
	end
	return leaked
end

function Enemies:Slow(enemy, factor, duration, now)
	if enemy.dead then return end
	if enemy.def.slowResist then factor = 1 - (1 - factor) * (1 - enemy.def.slowResist) end
	if now < enemy.slowUntil then factor = math.min(factor, enemy.slowFactor) end
	enemy.slowFactor = math.clamp(factor, 0.1, 1)
	enemy.slowUntil = math.max(enemy.slowUntil, now + duration)
end

function Enemies:Damage(enemy, amount, playerId)
	if enemy.dead or not self.Active[enemy.id] then return false end
	local effective = math.max(1, amount - enemy.def.armor)
	local actual = math.min(enemy.hp, effective)
	enemy.hp -= actual
	if playerId then
		enemy.damageByPlayer[playerId] = (enemy.damageByPlayer[playerId] or 0) + actual
		enemy.totalDamage += actual
		if self.OnDamage then self.OnDamage(playerId, actual) end
	end
	enemy.bar.Size = UDim2.fromScale(math.max(0, enemy.hp / enemy.maxHP), 1)
	if enemy.hp <= 0 then
		enemy.dead = true
		self.Active[enemy.id] = nil
		local position = enemy.position
		enemy.model:Destroy()
		if self.OnKill then self.OnKill(enemy, playerId, position) end
		return true
	end
	return false
end

function Enemies:Candidates(position, range, canHitAir)
	local result = {}
	local rangeSquared = range * range
	for _, enemy in pairs(self.Active) do
		if not enemy.dead and (canHitAir or not enemy.def.flying) then
			local dx, dz = enemy.position.X - position.X, enemy.position.Z - position.Z
			local distance = dx * dx + dz * dz
			if distance <= rangeSquared then table.insert(result, { enemy = enemy, distance = distance }) end
		end
	end
	return result
end

function Enemies:Choose(position, range, canHitAir, priority)
	local best, bestScore = nil, -math.huge
	for _, candidate in ipairs(self:Candidates(position, range, canHitAir)) do
		local score = candidate.enemy.progress
		if priority == "Strong" then score = candidate.enemy.hp
		elseif priority == "Near" then score = -candidate.distance end
		if score > bestScore then best, bestScore = candidate.enemy, score end
	end
	return best
end

function Enemies:InRadius(position, radius, canHitAir)
	local result = {}
	for _, candidate in ipairs(self:Candidates(position, radius, canHitAir)) do
		table.insert(result, candidate.enemy)
	end
	return result
end

function Enemies:Count()
	local count = 0
	for _ in pairs(self.Active) do count += 1 end
	return count
end

return Enemies
