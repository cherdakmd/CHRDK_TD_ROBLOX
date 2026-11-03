local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Models = {}
local dark = Color3.fromRGB(39, 54, 66)
local metal = Color3.fromRGB(84, 105, 116)

local function part(parent, name, size, cframe, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = cframe; p.Color = color
	p.Material = material or Enum.Material.Metal
	p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.Parent = parent
	return p
end

local function cyl(parent, name, radius, height, offset, color, material)
	return part(parent, name, Vector3.new(height, radius * 2, radius * 2), CFrame.new(offset) * CFrame.Angles(0, 0, math.pi / 2), color, material, Enum.PartType.Cylinder)
end

function Models.Tower(towerType, level, position, padId)
	local def = Config.Towers[towerType]
	local model = Instance.new("Model"); model.Name = "Tower_" .. padId
	local origin = CFrame.new(position + Vector3.new(0, 0.85, 0))
	local base = cyl(model, "Base", 2.65, 0.65, origin.Position + Vector3.new(0, 0.32, 0), dark)
	model.PrimaryPart = base
	cyl(model, "Accent", 2.3, 0.15, origin.Position + Vector3.new(0, 0.73, 0), def.color, Enum.Material.Neon)
	cyl(model, "Pedestal", 1.35, 1.5, origin.Position + Vector3.new(0, 1.45, 0), metal)
	local head = Instance.new("Model"); head.Name = "Head"; head.Parent = model
	local headOrigin = origin + Vector3.new(0, 2.6, 0)
	local pivot
	if towerType == "Sentry" then
		pivot = part(head, "Pivot", Vector3.new(2.7, 1.6, 2.5), headOrigin, def.color)
		part(head, "BarrelL", Vector3.new(0.48, 0.48, 3.4), headOrigin * CFrame.new(-0.7, 0.1, 2), dark)
		part(head, "BarrelR", Vector3.new(0.48, 0.48, 3.4), headOrigin * CFrame.new(0.7, 0.1, 2), dark)
		part(head, "Sight", Vector3.new(0.8, 0.3, 0.6), headOrigin * CFrame.new(0, 1, 0.3), def.color, Enum.Material.Neon)
	elseif towerType == "Cannon" then
		pivot = part(head, "Pivot", Vector3.new(3.2, 1.9, 2.8), headOrigin, def.color)
		local barrel = cyl(head, "Barrel", 0.85, 4.2, Vector3.new(0, 0, 0), dark)
		barrel.CFrame = headOrigin * CFrame.new(0, 0.5, 2) * CFrame.Angles(math.pi / 2, 0, 0)
		local muzzle = cyl(head, "Muzzle", 0.95, 0.4, Vector3.new(0, 0, 0), def.color)
		muzzle.CFrame = headOrigin * CFrame.new(0, 0.5, 4) * CFrame.Angles(math.pi / 2, 0, 0)
	elseif towerType == "Frost" then
		pivot = part(head, "Pivot", Vector3.new(2, 2.8, 2), headOrigin * CFrame.Angles(0, math.pi / 4, math.pi / 7), def.color, Enum.Material.Neon)
		for angle = 0, math.pi * 1.5, math.pi / 2 do
			part(head, "Shard", Vector3.new(0.6, 1.8, 0.6), headOrigin * CFrame.new(math.cos(angle) * 1.8, -0.5, math.sin(angle) * 1.8) * CFrame.Angles(0.2, angle, 0.3), def.color, Enum.Material.Glass)
		end
	else
		pivot = part(head, "Pivot", Vector3.new(1.8, 1.8, 1.8), headOrigin + Vector3.new(0, 1, 0), def.color, Enum.Material.Neon, Enum.PartType.Ball)
		for height = -1, 1 do
			cyl(head, "Coil", 1.5, 0.25, headOrigin.Position + Vector3.new(0, height * 0.7, 0), height == 0 and def.color or metal, height == 0 and Enum.Material.Neon or Enum.Material.Metal)
		end
	end
	head.PrimaryPart = pivot
	model:SetAttribute("HeadOffset", headOrigin.Position - origin.Position)
	for rank = 1, level do
		part(model, "Rank", Vector3.new(0.38, 0.22, 0.7), origin * CFrame.new(-0.9 + (rank - 1) * 0.6, 0.85, 1.8), Color3.fromRGB(255, 222, 134), Enum.Material.Neon)
	end
	local light = Instance.new("PointLight"); light.Color = def.color; light.Range = 7; light.Brightness = 0.4; light.Parent = pivot
	model:SetAttribute("TowerType", towerType); model:SetAttribute("Level", level)
	return model, head
end

function Models.Enemy(kind, id)
	local def = Config.Enemies[kind]
	local scale = def.size
	local model = Instance.new("Model"); model.Name = "Enemy_" .. id
	local root = part(model, "Root", Vector3.new(2, 2, 2) * scale, CFrame.new(0, 2, 0), def.color)
	root.Transparency = 1
	model.PrimaryPart = root
	local body
	if def.flying then
		body = part(model, "Body", Vector3.new(2, 2, 2) * scale, CFrame.new(0, 0, 0), def.color, Enum.Material.Neon, Enum.PartType.Ball)
		part(model, "WingL", Vector3.new(2.4, 0.2, 1.2) * scale, CFrame.new(-1.4 * scale, 0, 0) * CFrame.Angles(0, 0, -0.3), def.color, Enum.Material.Glass)
		part(model, "WingR", Vector3.new(2.4, 0.2, 1.2) * scale, CFrame.new(1.4 * scale, 0, 0) * CFrame.Angles(0, 0, 0.3), def.color, Enum.Material.Glass)
	else
		body = part(model, "Body", Vector3.new(2.1, 2.2, 1.7) * scale, CFrame.new(0, 0, 0), def.color, Enum.Material.SmoothPlastic)
		part(model, "Helmet", Vector3.new(2.3, 0.6, 1.9) * scale, CFrame.new(0, 1.1 * scale, 0), def.boss and dark or body.Color:Lerp(Color3.new(0, 0, 0), 0.25))
		for _, side in ipairs({ -1, 1 }) do
			part(model, "Foot", Vector3.new(0.7, 0.7, 1.2) * scale, CFrame.new(side * 0.65 * scale, -1.25 * scale, 0.15), dark)
		end
		if def.boss then
			for _, side in ipairs({ -1, 1 }) do
				part(model, "Horn", Vector3.new(0.6, 1.8, 0.6) * scale, CFrame.new(side * 0.85 * scale, 1.75 * scale, 0) * CFrame.Angles(0, 0, side * -0.35), Color3.fromRGB(255, 190, 129), Enum.Material.Neon)
			end
		end
	end
	part(model, "Visor", Vector3.new(1.5, 0.35, 0.12) * scale, CFrame.new(0, 0.35 * scale, 0.91 * scale), Color3.fromRGB(255, 241, 202), Enum.Material.Neon)
	local gui = Instance.new("BillboardGui"); gui.Name = "Health"; gui.Size = UDim2.fromOffset(def.boss and 90 or 42, def.boss and 24 or 6); gui.StudsOffsetWorldSpace = Vector3.new(0, 2 * scale + 0.7, 0); gui.MaxDistance = 180; gui.Parent = root
	local back = Instance.new("Frame"); back.Size = UDim2.fromScale(1, def.boss and 0.3 or 1); back.Position = UDim2.fromScale(0, def.boss and 0.7 or 0); back.BackgroundColor3 = dark; back.BorderSizePixel = 0; back.Parent = gui
	local fill = Instance.new("Frame"); fill.Name = "Fill"; fill.Size = UDim2.fromScale(1, 1); fill.BackgroundColor3 = def.boss and Color3.fromRGB(255, 125, 109) or Color3.fromRGB(133, 237, 164); fill.BorderSizePixel = 0; fill.Parent = back
	if def.boss then
		local title = Instance.new("TextLabel"); title.Size = UDim2.fromScale(1, 0.65); title.BackgroundTransparency = 1; title.Text = def.name; title.TextColor3 = Color3.fromRGB(255, 221, 207); title.TextScaled = true; title.Font = Enum.Font.GothamBold; title.Parent = gui
	end
	model:SetAttribute("EnemyKind", kind)
	return model, fill
end

return Models
