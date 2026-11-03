local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Models = require(script.Parent.Models)
local Map = require(script.Parent.Map)
local Towers = { ByPad = {}, folder = nil }

function Towers:Init(folder)
	self.folder = folder
end

function Towers:CreateModel(tower)
	if tower.model then tower.model:Destroy() end
	local pad = Map.Pads[tower.padId]
	local model, head = Models.Tower(tower.kind, tower.level, pad.position, tower.padId)
	tower.model, tower.head = model, head
	model.Parent = self.folder
	pad.model = model
	pad.part:SetAttribute("TowerType", tower.kind)
	pad.part:SetAttribute("Level", tower.level)
	pad.part:SetAttribute("OwnerId", tower.ownerId)
	pad.part:SetAttribute("OwnerName", tower.ownerName)
	pad.part:SetAttribute("Invested", tower.invested)
	pad.part:SetAttribute("Priority", tower.priority)
	pad.top.Color = Config.Towers[tower.kind].color:Lerp(Color3.fromRGB(30, 45, 55), 0.65)
	pad.label.TextTransparency = 1
end

function Towers:Build(padId, kind, player)
	local pad = Map.Pads[padId]
	if not pad or pad.model then return nil end
	local tower = {
		padId = padId, kind = kind, level = 1, ownerId = player.UserId,
		ownerName = player.DisplayName, invested = Config.Towers[kind].cost,
		cooldown = 0.15, priority = "First", position = pad.position,
	}
	self.ByPad[padId] = tower
	self:CreateModel(tower)
	return tower
end

function Towers:Upgrade(padId)
	local tower = self.ByPad[padId]
	if not tower or tower.level >= 4 then return false end
	tower.level += 1
	self:CreateModel(tower)
	return true
end

function Towers:Remove(padId)
	local tower = self.ByPad[padId]
	if not tower then return end
	if tower.model then tower.model:Destroy() end
	local pad = Map.Pads[padId]
	pad.model = nil
	pad.part:SetAttribute("TowerType", "")
	pad.part:SetAttribute("OwnerId", 0)
	pad.part:SetAttribute("OwnerName", "")
	pad.part:SetAttribute("Level", 0)
	pad.part:SetAttribute("Invested", 0)
	pad.top.Color = Color3.fromRGB(77, 103, 105)
	pad.label.TextTransparency = 0.15
	self.ByPad[padId] = nil
end

function Towers:Clear()
	for padId in pairs(self.ByPad) do self:Remove(padId) end
	if self.folder then self.folder:ClearAllChildren() end
	Map.ResetPads()
end

function Towers:Update(dt, enemies, emit, now)
	for _, tower in pairs(self.ByPad) do
		tower.cooldown -= dt
		if tower.cooldown <= 0 then
			local def = Config.Towers[tower.kind]
			local stats = Config.Stats(tower.kind, tower.level)
			local target = enemies:Choose(tower.position, stats.range, def.air, tower.priority)
			if target then
				tower.cooldown = stats.interval
				local headPosition = tower.position + Vector3.new(0, 3.45, 0)
				local flatTarget = Vector3.new(target.position.X, headPosition.Y, target.position.Z)
				if (flatTarget - headPosition).Magnitude > 0.01 then
					tower.head:PivotTo(CFrame.lookAt(headPosition, flatTarget))
				end
				local origin = headPosition + Vector3.new(0, 0.4, 0)
				local targetPosition = target.position
				emit({ kind = tower.kind, from = origin, to = targetPosition, color = def.color, radius = stats.splash })
				if tower.kind == "Cannon" then
					for _, enemy in ipairs(enemies:InRadius(targetPosition, stats.splash, false)) do
						local falloff = 1 - math.min(0.35, (enemy.position - targetPosition).Magnitude / stats.splash * 0.35)
						enemies:Damage(enemy, stats.damage * falloff, tower.ownerId)
					end
				elseif tower.kind == "Tesla" then
					local hit = {}
					local current = target
					for jump = 1, stats.chains + 1 do
						if not current or current.dead then break end
						local previousPosition = current.position
						hit[current.id] = true
						enemies:Damage(current, stats.damage * 0.78 ^ (jump - 1), tower.ownerId)
						local nextEnemy, nearest = nil, def.chainRange ^ 2
						if jump <= stats.chains then
							for _, candidate in ipairs(enemies:Candidates(previousPosition, def.chainRange, true)) do
								if not hit[candidate.enemy.id] and candidate.distance < nearest then
									nextEnemy, nearest = candidate.enemy, candidate.distance
								end
							end
						end
						if nextEnemy then emit({ kind = "Chain", from = previousPosition, to = nextEnemy.position, color = def.color }) end
						current = nextEnemy
					end
				else
					if tower.kind == "Frost" then enemies:Slow(target, def.slow, stats.slowTime, now) end
					enemies:Damage(target, stats.damage, tower.ownerId)
				end
			else
				tower.cooldown = 0
			end
		end
	end
end

return Towers
