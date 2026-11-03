-- All gameplay decisions stay on the server. This script is presentation + intent only.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Controllers = script.Parent:WaitForChild("Controllers")
local Theme = require(Controllers:WaitForChild("Theme"))
local Camera = require(Controllers:WaitForChild("Camera"))
local Effects = require(Controllers:WaitForChild("Effects"))
local UI = require(Controllers:WaitForChild("UI"))

local remotes = ReplicatedStorage:WaitForChild("TD_Remotes")
local StateRemote = remotes:WaitForChild("State")
local ActionRemote = remotes:WaitForChild("Action")
local EffectsRemote = remotes:WaitForChild("Effects")
local NoticeRemote = remotes:WaitForChild("Notice")
local mapRoot = workspace:WaitForChild("TD_Map")
local padsFolder = mapRoot:WaitForChild("Pads")
local enemyFolder = mapRoot:WaitForChild("Enemies")

for _, coreGui in ipairs({ Enum.CoreGuiType.Health, Enum.CoreGuiType.Backpack, Enum.CoreGuiType.PlayerList }) do
	pcall(function() StarterGui:SetCoreGuiEnabled(coreGui, false) end)
end
task.spawn(function()
	local playerModule = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 15)
	if playerModule then pcall(function() require(playerModule):GetControls():Disable() end) end
end)

Camera:Init()
Effects:Init()
local state, selectedPad, pendingType, targeting = nil, nil, nil, false
local lastPhase = nil
local actions = {}
local hud = UI.new(actions)

local localFolder = Instance.new("Folder"); localFolder.Name = "TD_Selection"; localFolder.Parent = workspace
local function indicator(name, radius, color, transparency)
	local part = Instance.new("Part")
	part.Name = name; part.Shape = Enum.PartType.Cylinder; part.Anchored = true
	part.CanCollide = false; part.CanTouch = false; part.CanQuery = false
	part.Material = Enum.Material.Neon; part.Transparency = transparency
	part.Color = color; part.Size = Vector3.new(0.08, radius * 2, radius * 2)
	part.CFrame = CFrame.new(0, 0.4, 0) * CFrame.Angles(0, 0, math.pi / 2)
	part.Parent = localFolder
	return part
end
local range = indicator("Range", 24, Theme.Mint, 0.88)
local targetRing = indicator("MeteorTarget", Config.Abilities.Meteor.radius, Theme.Gold, 0.65)
range.Transparency = 1; targetRing.Transparency = 1
local highlight = Instance.new("Highlight")
highlight.Name = "Selection"; highlight.FillTransparency = 0.92; highlight.OutlineTransparency = 0.1
highlight.FillColor = Theme.Mint; highlight.OutlineColor = Theme.Mint; highlight.Enabled = false
highlight.Parent = localFolder

local function send(kind, payload)
	payload = payload or {}; payload.kind = kind
	ActionRemote:FireServer(payload)
end
local function getPad(padId)
	return padId and padsFolder:FindFirstChild(string.format("Pad_%02d", padId)) or nil
end
local function stopTargeting()
	targeting = false; targetRing.Transparency = 1; hud:SetTargeting(false)
end
local function deselect()
	selectedPad = nil; pendingType = nil; range.Transparency = 1; highlight.Enabled = false
	stopTargeting(); hud:Selection(nil, nil, nil)
end

local function refreshSelection()
	local pad = getPad(selectedPad)
	if not pad then
		selectedPad = nil; range.Transparency = 1; highlight.Enabled = false
		hud:Selection(nil, nil, pendingType); return
	end
	local attributes = pad:GetAttributes()
	hud:Selection(selectedPad, attributes, pendingType)
	local kind = attributes.TowerType
	if kind and kind ~= "" and Config.Towers[kind] then
		local stats = Config.Stats(kind, attributes.Level or 1)
		range.Size = Vector3.new(0.08, stats.range * 2, stats.range * 2)
		range.Color = Config.Towers[kind].color
		range.CFrame = CFrame.new(pad.Position.X, 0.38, pad.Position.Z) * CFrame.Angles(0, 0, math.pi / 2)
		range.Transparency = targeting and 1 or 0.88
		local towers = mapRoot:FindFirstChild("Towers")
		local model = towers and towers:FindFirstChild("Tower_" .. selectedPad)
		highlight.Adornee = model or pad
		highlight.FillColor = Config.Towers[kind].color; highlight.OutlineColor = Config.Towers[kind].color
		highlight.Enabled = true
	else
		range.Transparency = 1; highlight.Adornee = pad; highlight.FillColor = Theme.Mint; highlight.OutlineColor = Theme.Mint; highlight.Enabled = true
	end
end

local function build(kind)
	if not selectedPad then pendingType = kind; hud.pendingType = kind; hud:Toast("Теперь выберите свободную площадку на карте.", "info"); return end
	local pad = getPad(selectedPad)
	if not pad then deselect(); return end
	if pad:GetAttribute("TowerType") ~= "" then hud:Toast("Площадка занята. Выберите другую или улучшите эту башню.", "danger"); return end
	send("Build", { padId = selectedPad, towerType = kind })
	pendingType = nil; hud.pendingType = nil
end

local function chooseAbility(kind)
	if not state or state.phase ~= "Combat" then hud:Toast("Способности доступны во время волны.", "info"); return end
	if (state.cooldowns[kind] or 0) > 0 then hud:Toast("Способность ещё восстанавливается.", "info"); return end
	if kind == "Meteor" then
		targeting = not targeting; targetRing.Transparency = targeting and 0.65 or 1; range.Transparency = 1
		hud:SetTargeting(targeting)
		if targeting then hud:Toast("Наведите на карту и нажмите. Esc — отмена.", "ability") end
	else
		send("Ability", { ability = "Freeze" })
	end
end

actions.Send = send
actions.ChooseTower = function(kind) stopTargeting(); build(kind); if state then hud:Update(state) end end
actions.Deselect = deselect
actions.RefreshSelection = refreshSelection
actions.Upgrade = function()
	if not selectedPad then return end
	local pad = getPad(selectedPad)
	if pad and pad:GetAttribute("TowerType") == "" and pendingType then build(pendingType)
	else send("Upgrade", { padId = selectedPad }) end
end
actions.Sell = function() if selectedPad then send("Sell", { padId = selectedPad }) end end
actions.Priority = function(value) if selectedPad then send("Priority", { padId = selectedPad, value = value }) end end
actions.Ability = chooseAbility
actions.FocusMap = function(position) Camera:SetCenter(position) end

local function nearestPad(point)
	local best, distance = nil, Config.Map.PadRadius + 1.2
	for index, coordinates in ipairs(Config.Map.Pads) do
		local x, z = coordinates[1] * Config.Map.Scale, coordinates[2] * Config.Map.Scale
		local d = math.sqrt((point.X - x)^2 + ( point.Z - z)^2)
		if d < distance then best, distance = index, d end
	end
	return best
end

Camera.OnTap = function(screenPosition)
	if hud.helpShade.Visible or hud.modalShade.Visible then return end
	local point = Camera:GroundPoint(screenPosition)
	if not point then if not targeting then deselect() end; return end
	if targeting then
		send("Ability", { ability = "Meteor", target = point })
		stopTargeting(); return
	end
	local padId = nearestPad(point)
	if padId then selectedPad = padId; refreshSelection()
	else deselect() end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
	local key = input.KeyCode
	if key == Enum.KeyCode.Escape then
		if hud.helpShade.Visible then hud:ShowHelp(false) else deselect() end
		return
	end
	if hud.helpShade.Visible or hud.modalShade.Visible then return end
	local number = nil
	if key == Enum.KeyCode.One then number = 1 elseif key == Enum.KeyCode.Two then number = 2
	elseif key == Enum.KeyCode.Three then number = 3 elseif key == Enum.KeyCode.Four then number = 4 end
	if number and Config.TowerOrder[number] then actions.ChooseTower(Config.TowerOrder[number])
	elseif key == Enum.KeyCode.Q then chooseAbility("Meteor")
	elseif key == Enum.KeyCode.E then chooseAbility("Freeze")
	elseif key == Enum.KeyCode.U then actions.Upgrade()
	elseif key == Enum.KeyCode.H then hud:ShowHelp(true)
	elseif key == Enum.KeyCode.F and selectedPad then
		local pad = getPad(selectedPad); if pad then Camera:SetCenter(pad.Position) end
	elseif key == Enum.KeyCode.Space and state then
		if state.phase == "Lobby" then local mine = hud:Mine(); send("Ready", { ready = not (mine and mine.ready) })
		elseif state.phase == "Intermission" then send("Skip", {}) end
	end
end)

StateRemote.OnClientEvent:Connect(function(snapshot)
	state = snapshot
	if state.phase == "Lobby" and lastPhase ~= "Lobby" then deselect() end
	lastPhase = state.phase
	if targeting and (state.phase ~= "Combat" or (state.cooldowns.Meteor or 0) > 0) then stopTargeting() end
	hud:Update(state)
end)
EffectsRemote.OnClientEvent:Connect(function(batch) Effects:Play(batch) end)
NoticeRemote.OnClientEvent:Connect(function(message, tone) hud:Toast(message, tone) end)

local minimapElapsed = 0
RunService.RenderStepped:Connect(function(dt)
	if targeting then
		local point = Camera:GroundPoint(UserInputService:GetMouseLocation())
		if point then targetRing.CFrame = CFrame.new(point.X, 0.45, point.Z) * CFrame.Angles(0, 0, math.pi / 2); targetRing.Transparency = 0.65
		else targetRing.Transparency = 1 end
	end
	minimapElapsed += dt
	if minimapElapsed >= 0.25 then minimapElapsed = 0; hud:UpdateMinimap(enemyFolder) end
end)

-- Ask until the server has loaded our profile; regular snapshots continue at 5 Hz.
task.spawn(function()
	for _ = 1, 20 do
		if state then return end
		send("Hello"); task.wait(1)
	end
	if not state then hud.loadingText.Text = "Сервер загружается. Если это не проходит, проверьте Output в Studio." end
end)
