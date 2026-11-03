local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Path = require(game:GetService("ReplicatedStorage").Shared:WaitForChild("Path"))
local Map = {}

local COLORS = {
	grass = Color3.fromRGB(64, 112, 86), edge = Color3.fromRGB(45, 77, 67),
	road = Color3.fromRGB(204, 185, 145), roadEdge = Color3.fromRGB(143, 143, 111),
	metal = Color3.fromRGB(47, 66, 78), dark = Color3.fromRGB(29, 45, 56),
	mint = Color3.fromRGB(115, 244, 198), stone = Color3.fromRGB(126, 151, 139),
}

local function part(parent, name, size, cframe, color, material, shape)
	local object = Instance.new("Part")
	object.Name = name
	object.Size = size
	object.CFrame = cframe
	object.Color = color
	object.Material = material or Enum.Material.SmoothPlastic
	object.Anchored = true
	object.CanCollide = false
	object.CanTouch = false
	object.TopSurface = Enum.SurfaceType.Smooth
	object.BottomSurface = Enum.SurfaceType.Smooth
	if shape then object.Shape = shape end
	object.Parent = parent
	return object
end

local function cylinder(parent, name, radius, height, position, color, material)
	return part(parent, name, Vector3.new(height, radius * 2, radius * 2), CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2), color, material, Enum.PartType.Cylinder)
end

local function label(parent, text, position, color, size)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(size or 190, 34)
	local basePosition = parent:IsA("BasePart") and parent.Position or Vector3.zero
	gui.StudsOffsetWorldSpace = position - basePosition + Vector3.new(0, 3, 0)
	gui.MaxDistance = 260
	gui.AlwaysOnTop = false
	gui.Parent = parent
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextSize = 15
	textLabel.TextColor3 = color
	textLabel.TextStrokeColor3 = COLORS.dark
	textLabel.TextStrokeTransparency = 0.35
	textLabel.Text = text
	textLabel.Parent = gui
	return textLabel
end

function Map.Build()
	local old = workspace:FindFirstChild("TD_Map")
	if old then old:Destroy() end
	local root = Instance.new("Folder")
	root.Name = "TD_Map"
	root.Parent = workspace
	local scenery = Instance.new("Folder"); scenery.Name = "Scenery"; scenery.Parent = root
	local padsFolder = Instance.new("Folder"); padsFolder.Name = "Pads"; padsFolder.Parent = root
	local towers = Instance.new("Folder"); towers.Name = "Towers"; towers.Parent = root
	local enemies = Instance.new("Folder"); enemies.Name = "Enemies"; enemies.Parent = root
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "CommandDeck"
	spawn.Size = Vector3.new(18, 0.6, 8)
	spawn.CFrame = CFrame.new(0, 0.3, 43)
	spawn.Color = COLORS.metal
	spawn.Material = Enum.Material.Metal
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = scenery
	part(scenery, "Ocean", Vector3.new(1800, 2, 1800), CFrame.new(0, -10, 0), Color3.fromRGB(42, 85, 99), Enum.Material.SmoothPlastic)
	part(scenery, "IslandFoundation", Vector3.new(177, 5, 115), CFrame.new(0, -4, -3), COLORS.edge)
	part(scenery, "IslandRim", Vector3.new(176, 1.5, 114), CFrame.new(0, -1.5, -3), Color3.fromRGB(98, 132, 105))
	local ground = part(scenery, "Grass", Config.Map.Size, CFrame.new(0, -2, -3), COLORS.grass)
	ground.CanCollide = true
	ground.CanQuery = false

	-- Road and rounded junctions are collision-free: enemies follow the shared spline.
	for index, segment in ipairs(Path.Segments) do
		local a, b = segment.a, segment.b
		local center = Vector3.new((a.x + b.x) / 2, 0.12, (a.z + b.z) / 2)
		local horizontal = math.abs(b.x - a.x) > 0
		local size = horizontal and Vector3.new(segment.length, 0.24, Config.Map.RoadWidth) or Vector3.new(Config.Map.RoadWidth, 0.24, segment.length)
		part(scenery, "RoadEdge" .. index, size + Vector3.new(1.2, 0, 1.2), CFrame.new(center - Vector3.new(0, 0.06, 0)), COLORS.roadEdge)
		part(scenery, "Road" .. index, size, CFrame.new(center), COLORS.road)
		for distance = 5, segment.length - 3, 12 do
			local x, z, angle = Path.Sample(segment.start + distance)
			local arrow = part(scenery, "LaneMark", Vector3.new(0.35, 0.03, 2), CFrame.new(x, 0.26, z) * CFrame.Angles(0, angle, 0), Color3.fromRGB(231, 216, 177))
			arrow.Transparency = 0.3
		end
	end
	for _, point in ipairs(Path.Points) do
		cylinder(scenery, "RoadJoin", Config.Map.RoadWidth / 2, 0.24, Vector3.new(point.x, 0.12, point.z), COLORS.road)
	end

	Map.Pads = {}
	for index, coordinates in ipairs(Config.Map.Pads) do
		local position = Vector3.new(coordinates[1] * Config.Map.Scale, 0, coordinates[2] * Config.Map.Scale)
		local pad = cylinder(padsFolder, string.format("Pad_%02d", index), Config.Map.PadRadius, 0.65, position + Vector3.new(0, 0.35, 0), COLORS.metal, Enum.Material.Metal)
		pad.CanQuery = true
		pad:SetAttribute("PadId", index)
		pad:SetAttribute("OwnerId", 0)
		pad:SetAttribute("TowerType", "")
		pad:SetAttribute("Level", 0)
		pad:SetAttribute("Priority", "First")
		pad:SetAttribute("Invested", 0)
		local top = cylinder(pad.Parent, "PadTop" .. index, Config.Map.PadRadius - 0.35, 0.1, position + Vector3.new(0, 0.72, 0), Color3.fromRGB(77, 103, 105), Enum.Material.SmoothPlastic)
		top.CanQuery = true
		top:SetAttribute("PadId", index)
		local number = label(top, string.format("+  %02d", index), position + Vector3.new(0, 0.3, 0), Color3.fromRGB(183, 216, 202), 82)
		number.TextSize = 13
		number.TextTransparency = 0.15
		for angle = 0, math.pi * 1.5, math.pi / 2 do
			local offset = Vector3.new(math.cos(angle) * 3.2, 0.8, math.sin(angle) * 3.2)
			part(padsFolder, "PadLight", Vector3.new(0.45, 0.12, 0.45), CFrame.new(position + offset), COLORS.mint, Enum.Material.Neon)
		end
		Map.Pads[index] = { part = pad, top = top, position = position, label = number, model = nil }
	end

	-- Entry portal.
	local entry = Path.Points[1]
	for _, side in ipairs({ -1, 1 }) do
		part(scenery, "PortalPillar", Vector3.new(2.2, 9, 2.2), CFrame.new(entry.x, 4.5, entry.z + side * 5), COLORS.dark, Enum.Material.Slate)
		part(scenery, "PortalGlow", Vector3.new(0.4, 7, 0.5), CFrame.new(entry.x + 1.2, 4.5, entry.z + side * 5), Color3.fromRGB(255, 115, 110), Enum.Material.Neon)
	end
	part(scenery, "PortalLintel", Vector3.new(2.5, 2, 12), CFrame.new(entry.x, 9, entry.z), COLORS.dark)
	label(spawn, "ВТОРЖЕНИЕ  →", Vector3.new(entry.x, 11, entry.z), Color3.fromRGB(255, 170, 153), 200)

	-- The shared core and its health readout.
	local endpoint = Path.Points[#Path.Points]
	Map.CorePosition = Vector3.new(endpoint.x, 0, endpoint.z)
	cylinder(scenery, "CoreBase", 6.5, 1.2, Map.CorePosition + Vector3.new(0, 0.6, 0), COLORS.dark, Enum.Material.Metal)
	cylinder(scenery, "CoreRing", 5.4, 0.3, Map.CorePosition + Vector3.new(0, 1.35, 0), COLORS.mint, Enum.Material.Neon)
	Map.Core = part(scenery, "CoreCrystal", Vector3.new(4, 6, 4), CFrame.new(Map.CorePosition + Vector3.new(0, 5, 0)) * CFrame.Angles(0, math.pi / 4, math.pi / 8), COLORS.mint, Enum.Material.Neon)
	local light = Instance.new("PointLight"); light.Color = COLORS.mint; light.Range = 20; light.Brightness = 1.5; light.Parent = Map.Core
	Map.CoreLabel = label(Map.Core, "ЯДРО  30 / 30", Map.CorePosition + Vector3.new(0, 10, 0), Color3.fromRGB(183, 255, 225), 210)

	-- Deterministic decoration avoids both the road and every building pad.
	local random = Random.new(7319)
	local trees = 0
	for _ = 1, 450 do
		if trees >= 48 then break end
		local x, z = random:NextNumber(-82, 82), random:NextNumber(-53, 49)
		local clear = Path.DistanceToRoad(x, z) > 9 and math.sqrt((x - endpoint.x)^2 + ( z - endpoint.z)^2) > 12
		clear = clear and not (math.abs(x) < 14 and z > 35)
		for _, pad in ipairs(Map.Pads) do
			if (pad.position - Vector3.new(x, 0, z)).Magnitude < 7 then clear = false end
		end
		if clear then
			trees += 1
			local height = random:NextNumber(5, 9)
			part(scenery, "Trunk", Vector3.new(0.9, height * 0.6, 0.9), CFrame.new(x, height * 0.3, z), Color3.fromRGB(99, 91, 70))
			for layer = 0, 2 do
				local width = (4.8 - layer * 1.1) * height / 7
				part(scenery, "Pine", Vector3.new(width, width, width), CFrame.new(x, height * 0.48 + layer * height * 0.19, z) * CFrame.Angles(0, math.pi / 4 + layer * 0.2, math.pi / 4), Color3.fromRGB(40 + layer * 7, 91 + layer * 9, 74 + layer * 5))
			end
		end
	end
	for _ = 1, 35 do
		local x, z = random:NextNumber(-81, 81), random:NextNumber(-51, 48)
		local clear = Path.DistanceToRoad(x, z) > 7 and not (math.abs(x) < 14 and z > 35)
		for _, pad in ipairs(Map.Pads) do
			if math.sqrt((pad.position.X - x) ^ 2 + (pad.position.Z - z) ^ 2) < 6 then clear = false end
		end
		if clear then
			local size = random:NextNumber(0.8, 2.2)
			part(scenery, "Rock", Vector3.new(size * 1.5, size, size), CFrame.new(x, size / 2, z) * CFrame.Angles(0, random:NextNumber(0, 6), 0.15), COLORS.stone)
		end
	end
	return root
end

function Map.UpdateCore(hp, maximum)
	if Map.CoreLabel then Map.CoreLabel.Text = string.format("ЯДРО  %d / %d", hp, maximum) end
	if Map.Core then Map.Core.Color = hp / maximum < 0.3 and Color3.fromRGB(255, 122, 105) or COLORS.mint end
end

function Map.ResetPads()
	for _, pad in ipairs(Map.Pads) do
		if pad.model then pad.model:Destroy(); pad.model = nil end
		pad.part:SetAttribute("OwnerId", 0)
		pad.part:SetAttribute("TowerType", "")
		pad.part:SetAttribute("Level", 0)
		pad.part:SetAttribute("Priority", "First")
		pad.part:SetAttribute("Invested", 0)
		pad.top.Color = Color3.fromRGB(77, 103, 105)
		pad.label.TextTransparency = 0.15
	end
end

return Map
