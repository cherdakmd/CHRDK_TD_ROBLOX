local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local Effects = { count = 0 }

function Effects:Init()
	self.folder = Instance.new("Folder"); self.folder.Name = "TD_ClientFX"; self.folder.Parent = workspace
end

function Effects:Part(size, cframe, color, shape, transparency)
	local part = Instance.new("Part")
	part.Size = size; part.CFrame = cframe; part.Color = color; part.Material = Enum.Material.Neon
	part.Anchored = true; part.CanCollide = false; part.CanTouch = false; part.CanQuery = false
	part.Transparency = transparency or 0
	if shape then part.Shape = shape end
	part.Parent = self.folder
	self.count += 1
	part.Destroying:Once(function() self.count = math.max(0, self.count - 1) end)
	Debris:AddItem(part, 3)
	return part
end

function Effects:Beam(from, to, color, width, lifetime)
	if self.count > 150 then return end
	local length = (to - from).Magnitude
	if length < 0.05 then return end
	local beam = self:Part(Vector3.new(width or 0.14, width or 0.14, length), CFrame.lookAt((from + to) / 2, to), color)
	TweenService:Create(beam, TweenInfo.new(lifetime or 0.13), { Transparency = 1 }):Play()
	Debris:AddItem(beam, lifetime or 0.13)
end

function Effects:Burst(position, color, radius, lifetime)
	if self.count > 150 then return end
	local sphere = self:Part(Vector3.new(1, 1, 1), CFrame.new(position), color, Enum.PartType.Ball, 0.55)
	TweenService:Create(sphere, TweenInfo.new(lifetime or 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(radius * 2, radius * 1.1, radius * 2), Transparency = 1,
	}):Play()
	Debris:AddItem(sphere, (lifetime or 0.35) + 0.05)
end

function Effects:Projectile(from, to, color, radius, meteor)
	if self.count > 140 then return end
	local start = meteor and to + Vector3.new(16, 55, -8) or from
	local orb = self:Part(Vector3.new(1, 1, 1) * (meteor and 3 or 0.7), CFrame.new(start), color, Enum.PartType.Ball)
	local duration = meteor and 0.48 or 0.3
	local elapsed = 0
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local alpha = math.min(1, elapsed / duration)
		local position = start:Lerp(to, alpha)
		if not meteor then position += Vector3.new(0, math.sin(alpha * math.pi) * 8, 0) end
		orb.CFrame = CFrame.new(position)
		if alpha >= 1 then
			connection:Disconnect(); orb:Destroy()
			self:Burst(to, color, radius or 6, 0.4)
		end
	end)
	Debris:AddItem(orb, duration + 0.2)
	task.delay(duration + 0.25, function() if connection.Connected then connection:Disconnect() end end)
end

function Effects:Play(batch)
	for _, effect in ipairs(batch) do
		local kind, color = effect.kind, effect.color
		if kind == "Sentry" then self:Beam(effect.from, effect.to, color, 0.12, 0.1)
		elseif kind == "Frost" then self:Beam(effect.from, effect.to, color, 0.22, 0.18); self:Burst(effect.to, color, 1.6, 0.2)
		elseif kind == "Cannon" then self:Projectile(effect.from, effect.to, color, effect.radius, false)
		elseif kind == "Tesla" or kind == "Chain" then
			local middle = (effect.from + effect.to) / 2 + Vector3.new(math.random(-10, 10) / 10, math.random(0, 12) / 10, math.random(-10, 10) / 10)
			self:Beam(effect.from, middle, color, 0.22, 0.18); self:Beam(middle, effect.to, color, 0.22, 0.18)
		elseif kind == "Meteor" then self:Projectile(effect.from, effect.to, color, effect.radius, true)
		elseif kind == "Freeze" then self:Burst(Vector3.new(0, 1, 0), color, effect.radius, 0.9)
		elseif kind == "Defeat" then self:Burst(effect.to, color, effect.boss and 7 or 1.8, effect.boss and 0.6 or 0.22)
		elseif kind == "Build" then self:Burst(effect.to, color, 4, 0.45)
		elseif kind == "CoreHit" then self:Burst(effect.to, color, 7, 0.4)
		end
	end
end

return Effects
