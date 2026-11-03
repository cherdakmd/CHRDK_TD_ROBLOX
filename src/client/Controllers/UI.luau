local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Waves = require(Shared:WaitForChild("Waves"))
local Theme = require(script.Parent.Theme)
local UI = {}
UI.__index = UI

local function create(class, properties, parent)
	local object = Instance.new(class)
	for key, value in pairs(properties) do object[key] = value end
	object.Parent = parent
	return object
end
local function corner(object, radius)
	create("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, object)
end
local function stroke(object, color, transparency, thickness)
	return create("UIStroke", { Color = color or Theme.Stroke, Transparency = transparency or 0.65, Thickness = thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, object)
end
local function panel(parent, name, position, size, color)
	local frame = create("Frame", { Name = name, Position = position, Size = size, BackgroundColor3 = color or Theme.Panel, BackgroundTransparency = 0.04, BorderSizePixel = 0 }, parent)
	corner(frame, 12); stroke(frame); return frame
end
local function text(parent, value, position, size, fontSize, color, bold)
	return create("TextLabel", {
		Text = value, Position = position, Size = size, BackgroundTransparency = 1,
		Font = bold and Theme.Bold or Theme.Font, TextSize = fontSize or 14,
		TextColor3 = color or Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)
end
local function button(parent, value, position, size, color, callback, fontSize)
	local object = create("TextButton", {
		Text = value, Position = position, Size = size, BackgroundColor3 = color or Theme.Panel2,
		TextColor3 = Theme.Text, Font = Theme.Bold, TextSize = fontSize or 13,
		BorderSizePixel = 0, AutoButtonColor = false, TextWrapped = true,
	}, parent)
	corner(object, 8); local outline = stroke(object, Theme.Stroke, 0.6)
	object.MouseEnter:Connect(function() TweenService:Create(outline, TweenInfo.new(0.12), { Transparency = 0.05 }):Play() end)
	object.MouseLeave:Connect(function() TweenService:Create(outline, TweenInfo.new(0.12), { Transparency = 0.6 }):Play() end)
	object.Activated:Connect(function() if callback then callback() end end)
	return object, outline
end
local function bar(parent, position, size, color)
	local back = create("Frame", { Position = position, Size = size, BackgroundColor3 = Theme.Background, BorderSizePixel = 0 }, parent)
	corner(back, 3)
	local fill = create("Frame", { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0 }, back)
	corner(fill, 3); return fill
end

function UI.new(actions)
	local self = setmetatable({ actions = actions, selectedPad = nil, pendingType = nil, targeting = false, teamOpen = false, toasts = {}, shop = {}, slots = {} }, UI)
	self.gui = create("ScreenGui", { Name = "TD_HUD", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 10, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, Players.LocalPlayer:WaitForChild("PlayerGui"))
	self.root = create("Frame", { Name = "Root", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, self.gui)
	self:BuildTop()
	self:BuildTeam()
	self:BuildWave()
	self:BuildShop()
	self:BuildAbilities()
	self:BuildInspector()
	self:BuildMinimap()
	self:BuildModals()
	self.toastRoot = create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 90), Size = UDim2.fromOffset(430, 180), BackgroundTransparency = 1, ZIndex = 40 }, self.root)
	create("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, self.toastRoot)
	self.loading = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Background, BackgroundTransparency = 0.08, ZIndex = 70, Active = true }, self.root)
	text(self.loading, "РУБЕЖ", UDim2.new(0.5, -160, 0.43, 0), UDim2.fromOffset(320, 50), 40, Theme.Mint, true).TextXAlignment = Enum.TextXAlignment.Center
	self.loadingText = text(self.loading, "Соединяемся с сервером…", UDim2.new(0.5, -200, 0.53, 0), UDim2.fromOffset(400, 30), 16, Theme.Muted)
	self.loadingText.TextXAlignment = Enum.TextXAlignment.Center
	local camera = workspace.CurrentCamera
	if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(function() self:Resize() end) end
	self:Resize()
	return self
end

function UI:BuildTop()
	self.top = panel(self.root, "TopBar", UDim2.fromOffset(16, 14), UDim2.new(1, -32, 0, 64))
	self.brand = text(self.top, "РУБЕЖ", UDim2.fromOffset(18, 9), UDim2.fromOffset(155, 29), 25, Theme.Mint, true)
	self.brandSub = text(self.top, "CO-OP TOWER DEFENSE", UDim2.fromOffset(19, 39), UDim2.fromOffset(165, 14), 9, Theme.Muted, true)
	local function stat(name, caption, x, width, color)
		local frame = create("Frame", { Name = name, Position = UDim2.fromOffset(x, 9), Size = UDim2.fromOffset(width, 48), BackgroundTransparency = 1 }, self.top)
		local title = text(frame, caption, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 15), 9, Theme.Muted, true)
		local value = text(frame, "—", UDim2.fromOffset(0, 17), UDim2.new(1, 0, 0, 25), 21, color or Theme.Text, true)
		return { frame = frame, title = title, value = value }
	end
	self.waveStat = stat("Wave", "ВОЛНА", 195, 110)
	self.coreStat = stat("Core", "ПРОЧНОСТЬ ЯДРА", 315, 155, Theme.Mint)
	self.coreBar = bar(self.coreStat.frame, UDim2.fromOffset(0, 45), UDim2.new(1, -8, 0, 3), Theme.Mint)
	self.goldStat = stat("Gold", "ВАШЕ ЗОЛОТО", 495, 125, Theme.Gold)
	self.enemyStat = stat("Enemies", "ОСТАЛОСЬ ВРАГОВ", 640, 125)
	self.phaseStat = stat("Phase", "ПОДГОТОВКА", 800, 170, Theme.Blue)
	self.helpButton = button(self.top, "?", UDim2.new(1, -49, 0, 15), UDim2.fromOffset(34, 34), Theme.Panel2, function() self:ShowHelp(true) end, 18)
end

function UI:BuildTeam()
	self.team = panel(self.root, "Team", UDim2.fromOffset(16, 92), UDim2.fromOffset(192, 236))
	self.teamTitle = text(self.team, "ОТРЯД  1 / 4", UDim2.fromOffset(13, 10), UDim2.new(1, -26, 0, 20), 11, Theme.Muted, true)
	for index = 1, 4 do
		local row = create("Frame", { Position = UDim2.fromOffset(10, 38 + (index - 1) * 47), Size = UDim2.new(1, -20, 0, 43), BackgroundColor3 = Theme.Panel2, BackgroundTransparency = 0.35, BorderSizePixel = 0 }, self.team)
		corner(row, 7)
		local dot = create("Frame", { Position = UDim2.fromOffset(8, 11), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = Theme.Stroke, BorderSizePixel = 0 }, row); corner(dot, 3)
		local name = text(row, "Свободное место", UDim2.fromOffset(21, 4), UDim2.new(1, -27, 0, 18), 12, Theme.Text, true)
		local detail = text(row, "Пригласите друга", UDim2.fromOffset(21, 23), UDim2.new(1, -27, 0, 14), 10, Theme.Muted)
		self.slots[index] = { row = row, dot = dot, name = name, detail = detail }
	end
	self.teamToggle = button(self.root, "ОТРЯД", UDim2.fromOffset(12, 116), UDim2.fromOffset(78, 30), Theme.Panel, function()
		self.teamOpen = not self.teamOpen; self:Resize()
	end, 10)
end

function UI:BuildWave()
	self.preview = panel(self.root, "WavePreview", UDim2.new(1, -266, 0, 92), UDim2.fromOffset(250, 96))
	self.previewTitle = text(self.preview, "СЛЕДУЮЩАЯ ВОЛНА  01", UDim2.fromOffset(13, 9), UDim2.new(1, -26, 0, 18), 11, Theme.Blue, true)
	self.previewDescription = text(self.preview, "Разведчики", UDim2.fromOffset(13, 31), UDim2.new(1, -26, 0, 19), 14, Theme.Text, true)
	self.previewCounts = text(self.preview, "", UDim2.fromOffset(13, 54), UDim2.new(1, -26, 0, 29), 10, Theme.Muted)
	self.previewCounts.TextWrapped = true
	self.waveBar = bar(self.preview, UDim2.fromOffset(13, 86), UDim2.new(1, -26, 0, 3), Theme.Blue)
	self.command = panel(self.root, "Command", UDim2.new(1, -266, 0, 200), UDim2.fromOffset(250, 142))
	self.readyButton = button(self.command, "Я ГОТОВ", UDim2.fromOffset(10, 10), UDim2.new(1, -20, 0, 42), Color3.fromRGB(44, 100, 83), function()
		local mine = self:Mine()
		self.actions.Send("Ready", { ready = not (mine and mine.ready) })
	end)
	self.normalButton = button(self.command, "Обычный", UDim2.fromOffset(10, 61), UDim2.new(0.5, -14, 0, 32), Theme.Panel2, function() self.actions.Send("Difficulty", { value = "Normal" }) end, 11)
	self.hardButton = button(self.command, "Испытание", UDim2.new(0.5, 4, 0, 61), UDim2.new(0.5, -14, 0, 32), Theme.Panel2, function() self.actions.Send("Difficulty", { value = "Hard" }) end, 11)
	self.skipButton = button(self.command, "СЛЕДУЮЩАЯ ВОЛНА", UDim2.fromOffset(10, 10), UDim2.new(1, -20, 0, 42), Color3.fromRGB(44, 83, 105), function() self.actions.Send("Skip", {}) end, 12)
	self.speed1 = button(self.command, "1×", UDim2.fromOffset(10, 61), UDim2.new(0.5, -14, 0, 32), Theme.Panel2, function() self.actions.Send("Speed", { value = 1 }) end)
	self.speed2 = button(self.command, "2×", UDim2.new(0.5, 4, 0, 61), UDim2.new(0.5, -14, 0, 32), Theme.Panel2, function() self.actions.Send("Speed", { value = 2 }) end)
	self.commandHint = text(self.command, "", UDim2.fromOffset(12, 101), UDim2.new(1, -24, 0, 31), 10, Theme.Muted)
	self.commandHint.TextWrapped = true
end

function UI:TowerIcon(parent, kind, color)
	local icon = create("Frame", { Name = "Icon", Position = UDim2.fromOffset(12, 7), Size = UDim2.fromOffset(44, 39), BackgroundTransparency = 1 }, parent)
	local function piece(x, y, w, h, c, rotation)
		local p = create("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = c or color, BorderSizePixel = 0, Rotation = rotation or 0 }, icon); corner(p, 2); return p
	end
	piece(4, 32, 36, 5, Theme.Stroke)
	if kind == "Sentry" then
		piece(11, 17, 23, 15); piece(13, 3, 6, 20, Theme.Text); piece(26, 3, 6, 20, Theme.Text)
	elseif kind == "Cannon" then
		piece(9, 19, 27, 14); local barrel = piece(22, 3, 10, 25, Theme.Text, 35); barrel.AnchorPoint = Vector2.new(0.5, 0.5)
	elseif kind == "Frost" then
		piece(13, 7, 20, 20, color, 45); piece(4, 24, 7, 9); piece(35, 24, 7, 9)
	else
		piece(20, 7, 5, 26, Theme.Text); piece(10, 13, 25, 5); piece(8, 22, 29, 5); piece(17, 2, 11, 9)
	end
	return icon
end

function UI:BuildShop()
	self.hint = text(self.root, "ЛКМ — площадка   ·   WASD — камера   ·   колесо — масштаб   ·   R — обзор", UDim2.new(0.5, -330, 1, -173), UDim2.fromOffset(660, 18), 10, Theme.Text)
	self.hint.TextXAlignment = Enum.TextXAlignment.Center
	self.hint.TextStrokeTransparency = 0.4
	self.dock = panel(self.root, "Shop", UDim2.new(0.5, 0, 1, -16), UDim2.fromOffset(640, 132), Theme.Background)
	self.dock.AnchorPoint = Vector2.new(0.5, 1)
	for index, kind in ipairs(Config.TowerOrder) do
		local def = Config.Towers[kind]
		local card = create("TextButton", { Name = kind, Text = "", Position = UDim2.fromOffset(10 + (index - 1) * 156, 10), Size = UDim2.fromOffset(146, 112), BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, AutoButtonColor = false }, self.dock)
		corner(card, 9); local outline = stroke(card, def.color, 0.6)
		local icon = self:TowerIcon(card, kind, def.color)
		local name = text(card, def.name, UDim2.fromOffset(11, 49), UDim2.new(1, -22, 0, 18), 14, Theme.Text, true)
		local role = text(card, def.role, UDim2.fromOffset(11, 69), UDim2.new(1, -16, 0, 14), 9, Theme.Muted)
		local cost = text(card, Format.Number(def.cost) .. "  ◆", UDim2.fromOffset(11, 87), UDim2.new(1, -22, 0, 17), 13, Theme.Gold, true)
		local key = text(card, tostring(index), UDim2.new(1, -23, 0, 8), UDim2.fromOffset(15, 15), 10, Theme.Muted, true)
		card.MouseEnter:Connect(function() TweenService:Create(card, TweenInfo.new(0.12), { BackgroundColor3 = Theme.Panel2 }):Play() end)
		card.MouseLeave:Connect(function() TweenService:Create(card, TweenInfo.new(0.12), { BackgroundColor3 = Theme.Panel }):Play() end)
		card.Activated:Connect(function() self.actions.ChooseTower(kind) end)
		self.shop[kind] = { card = card, outline = outline, icon = icon, name = name, role = role, cost = cost, key = key }
	end
end

function UI:BuildAbilities()
	self.abilities = create("Frame", { Position = UDim2.new(0, 16, 1, -292), Size = UDim2.fromOffset(192, 128), BackgroundTransparency = 1 }, self.root)
	text(self.abilities, "ОБЩИЕ СПОСОБНОСТИ", UDim2.fromOffset(2, 0), UDim2.new(1, 0, 0, 16), 9, Theme.Text, true).TextStrokeTransparency = 0.5
	self.meteorButton = button(self.abilities, "Q   МЕТЕОР", UDim2.fromOffset(0, 23), UDim2.new(1, 0, 0, 46), Theme.Panel, function() self.actions.Ability("Meteor") end, 12)
	self.freezeButton = button(self.abilities, "E   СТУЖА", UDim2.fromOffset(0, 77), UDim2.new(1, 0, 0, 46), Theme.Panel, function() self.actions.Ability("Freeze") end, 12)
end

function UI:BuildInspector()
	self.inspector = panel(self.root, "Inspector", UDim2.new(1, -306, 0, 92), UDim2.fromOffset(290, 354))
	self.inspector.Visible = false
	self.inspectorTitle = text(self.inspector, "ПЛОЩАДКА 01", UDim2.fromOffset(15, 12), UDim2.new(1, -58, 0, 18), 10, Theme.Muted, true)
	button(self.inspector, "×", UDim2.new(1, -40, 0, 8), UDim2.fromOffset(30, 28), Theme.Panel2, function() self.actions.Deselect() end, 20)
	self.towerName = text(self.inspector, "Свободная площадка", UDim2.fromOffset(15, 39), UDim2.new(1, -30, 0, 26), 21, Theme.Text, true)
	self.towerOwner = text(self.inspector, "", UDim2.fromOffset(15, 69), UDim2.new(1, -30, 0, 18), 11, Theme.Muted)
	self.towerDescription = text(self.inspector, "Выберите башню в нижней панели. Её стоимость спишется только при строительстве.", UDim2.fromOffset(15, 98), UDim2.new(1, -30, 0, 57), 12, Theme.Muted)
	self.towerDescription.TextWrapped = true; self.towerDescription.TextYAlignment = Enum.TextYAlignment.Top
	self.statsFrame = create("Frame", { Position = UDim2.fromOffset(15, 101), Size = UDim2.new(1, -30, 0, 57), BackgroundTransparency = 1 }, self.inspector)
	self.damageStat = text(self.statsFrame, "УРОН", UDim2.fromOffset(0, 0), UDim2.fromOffset(80, 17), 9, Theme.Muted, true)
	self.rangeStat = text(self.statsFrame, "РАДИУС", UDim2.fromOffset(88, 0), UDim2.fromOffset(80, 17), 9, Theme.Muted, true)
	self.rateStat = text(self.statsFrame, "ВЫСТР./С", UDim2.fromOffset(176, 0), UDim2.fromOffset(80, 17), 9, Theme.Muted, true)
	self.damageValue = text(self.statsFrame, "—", UDim2.fromOffset(0, 21), UDim2.fromOffset(80, 27), 21, Theme.Text, true)
	self.rangeValue = text(self.statsFrame, "—", UDim2.fromOffset(88, 21), UDim2.fromOffset(80, 27), 21, Theme.Text, true)
	self.rateValue = text(self.statsFrame, "—", UDim2.fromOffset(176, 21), UDim2.fromOffset(80, 27), 21, Theme.Text, true)
	self.priorityLabel = text(self.inspector, "ПРИОРИТЕТ ЦЕЛИ", UDim2.fromOffset(15, 171), UDim2.new(1, -30, 0, 16), 9, Theme.Muted, true)
	self.priorityButtons = {}
	for index, priority in ipairs(Config.Priorities) do
		local b = button(self.inspector, Config.PriorityLabels[priority], UDim2.fromOffset(15 + (index - 1) * 88, 193), UDim2.fromOffset(82, 30), Theme.Panel2, function() self.actions.Priority(priority) end, 10)
		self.priorityButtons[priority] = b
	end
	self.upgradeButton = button(self.inspector, "УЛУЧШИТЬ", UDim2.fromOffset(15, 239), UDim2.new(1, -30, 0, 45), Color3.fromRGB(45, 102, 83), function() self.actions.Upgrade() end, 12)
	self.sellButton = button(self.inspector, "ПРОДАТЬ", UDim2.fromOffset(15, 293), UDim2.new(1, -30, 0, 32), Theme.Panel2, function() self.actions.Sell() end, 11)
	self.inspectorHint = text(self.inspector, "", UDim2.fromOffset(15, 331), UDim2.new(1, -30, 0, 14), 9, Theme.Muted)
end

function UI:BuildMinimap()
	self.minimap = panel(self.root, "Minimap", UDim2.new(1, -176, 1, -134), UDim2.fromOffset(160, 118), Theme.Background)
	text(self.minimap, "ТАКТИЧЕСКАЯ КАРТА", UDim2.fromOffset(10, 7), UDim2.new(1, -20, 0, 14), 8, Theme.Muted, true)
	self.mapArea = create("Frame", { Position = UDim2.fromOffset(8, 27), Size = UDim2.fromOffset(144, 82), BackgroundColor3 = Color3.fromRGB(38, 65, 58), BorderSizePixel = 0 }, self.minimap)
	corner(self.mapArea, 5)
	self.mapDots = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, self.mapArea)
	local Path = require(Shared:WaitForChild("Path"))
	local function mapPosition(x, z) return UDim2.fromScale((x + 88) / 176, (z + 57) / 114) end
	for _, segment in ipairs(Path.Segments) do
		local a, b = segment.a, segment.b
		local x, y = (math.min(a.x, b.x) + 88) / 176, (math.min(a.z, b.z) + 57) / 114
		local w, h = (math.abs(a.x - b.x) + 2.5) / 176, (math.abs(a.z - b.z) + 2.5) / 114
		create("Frame", { Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h), BackgroundColor3 = Color3.fromRGB(155, 151, 116), BorderSizePixel = 0 }, self.mapArea)
	end
	for _, point in ipairs(Config.Map.Pads) do
		local dot = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = mapPosition(point[1] * Config.Map.Scale, point[2] * Config.Map.Scale), Size = UDim2.fromOffset(4, 4), BackgroundColor3 = Theme.Muted, BorderSizePixel = 0, ZIndex = 2 }, self.mapArea)
		corner(dot, 2)
	end
	self.mapArea.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local relative = (Vector2.new(input.Position.X, input.Position.Y) - self.mapArea.AbsolutePosition) / self.mapArea.AbsoluteSize
			self.actions.FocusMap(Vector3.new(relative.X * 176 - 88, 0, relative.Y * 114 - 57))
		end
	end)
end

function UI:BuildModals()
	self.modalShade = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, BorderSizePixel = 0, Visible = false, Active = true, ZIndex = 50 }, self.root)
	self.result = panel(self.modalShade, "Result", UDim2.new(0.5, 0, 0.5, 0), UDim2.fromOffset(520, 448), Theme.Background)
	self.result.AnchorPoint = Vector2.new(0.5, 0.5)
	self.resultTitle = text(self.result, "РУБЕЖ УДЕРЖАН", UDim2.fromOffset(28, 27), UDim2.new(1, -56, 0, 42), 30, Theme.Mint, true)
	self.resultSubtitle = text(self.result, "", UDim2.fromOffset(28, 77), UDim2.new(1, -56, 0, 25), 14, Theme.Muted)
	self.resultStats = text(self.result, "", UDim2.fromOffset(28, 117), UDim2.new(1, -56, 0, 48), 15, Theme.Text, true)
	text(self.result, "ВКЛАД КОМАНДЫ", UDim2.fromOffset(28, 177), UDim2.new(1, -56, 0, 18), 10, Theme.Muted, true)
	self.resultRows = {}
	for index = 1, 4 do
		local row = text(self.result, "", UDim2.fromOffset(28, 201 + (index - 1) * 28), UDim2.new(1, -56, 0, 24), 13, Theme.Text)
		self.resultRows[index] = row
	end
	self.replayButton = button(self.result, "ЕЩЁ ОДИН МАТЧ", UDim2.fromOffset(28, 333), UDim2.new(1, -56, 0, 48), Color3.fromRGB(45, 102, 83), function() self.actions.Send("Replay", {}) end)
	self.resultHint = text(self.result, "", UDim2.fromOffset(28, 395), UDim2.new(1, -56, 0, 25), 11, Theme.Muted)
	self.helpShade = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, BorderSizePixel = 0, Visible = false, Active = true, ZIndex = 60 }, self.root)
	self.help = panel(self.helpShade, "Help", UDim2.new(0.5, 0, 0.5, 0), UDim2.fromOffset(600, 470), Theme.Background)
	self.help.AnchorPoint = Vector2.new(0.5, 0.5)
	text(self.help, "ДЕРЖИМ РУБЕЖ ВМЕСТЕ", UDim2.fromOffset(28, 24), UDim2.new(1, -56, 0, 38), 25, Theme.Mint, true)
	text(self.help, "Кооперативная оборона на 1–4 игроков", UDim2.fromOffset(28, 67), UDim2.new(1, -56, 0, 23), 14, Theme.Muted)
	local steps = {
		{ "01", "Выберите площадку на карте, затем башню внизу.", "Или сначала башню, затем свободную площадку." },
		{ "02", "Комбинируйте башни и улучшайте их до IV.", "Мортира не бьёт по воздуху. Страж, Криомант и Тесла — бьют." },
		{ "03", "Метеор и Стужа общие для всей команды.", "Q — выбрать точку метеора, E — заморозить всех врагов." },
		{ "04", "Отразите 20 волн и сохраните ядро.", "Боссы каждые 5 волн. Награда за врага делится по урону." },
	}
	for index, step in ipairs(steps) do
		local y = 108 + (index - 1) * 61
		text(self.help, step[1], UDim2.fromOffset(28, y), UDim2.fromOffset(34, 25), 19, Theme.Gold, true)
		text(self.help, step[2], UDim2.fromOffset(73, y), UDim2.new(1, -101, 0, 23), 13, Theme.Text, true)
		text(self.help, step[3], UDim2.fromOffset(73, y + 25), UDim2.new(1, -101, 0, 22), 11, Theme.Muted)
	end
	text(self.help, "WASD — камера · ПКМ — поворот · колесо / щипок — масштаб · R — обзор\n1–4 — башни · U — улучшить · Esc — отмена · Пробел — готовность / волна", UDim2.fromOffset(28, 363), UDim2.new(1, -56, 0, 40), 10, Theme.Muted).TextWrapped = true
	button(self.help, "К ОБОРОНЕ", UDim2.fromOffset(28, 414), UDim2.new(1, -56, 0, 36), Color3.fromRGB(45, 102, 83), function() self:ShowHelp(false) end)
end

function UI:Mine()
	if not self.state then return nil end
	for _, player in ipairs(self.state.players) do if player.id == Players.LocalPlayer.UserId then return player end end
	return nil
end

function UI:Resize()
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	self.compact = viewport.X < 760
	local medium = viewport.X < 1080
	self.top.Size = UDim2.new(1, self.compact and -24 or -32, 0, self.compact and 96 or 64)
	self.top.Position = UDim2.fromOffset(self.compact and 12 or 16, 14)
	self.brandSub.Visible = not self.compact
	self.brand.Position = UDim2.fromOffset(self.compact and 12 or 18, self.compact and 7 or 9)
	self.brand.TextSize = self.compact and 21 or 25
	if self.compact then
		self.waveStat.frame.Position = UDim2.fromOffset(12, 53); self.waveStat.frame.Size = UDim2.fromOffset(78, 40)
		self.coreStat.frame.Position = UDim2.fromOffset(99, 53); self.coreStat.frame.Size = UDim2.fromOffset(118, 40)
		self.goldStat.frame.Position = UDim2.fromOffset(231, 53); self.goldStat.frame.Size = UDim2.fromOffset(105, 40)
		self.phaseStat.frame.Position = UDim2.fromOffset(122, 7); self.phaseStat.frame.Size = UDim2.fromOffset(math.max(100, viewport.X - 205), 40)
		self.waveStat.value.TextSize = 17; self.coreStat.value.TextSize = 17; self.goldStat.value.TextSize = 17; self.phaseStat.value.TextSize = 17
	else
		local start = medium and 130 or 195
		local gap = medium and 118 or 155
		self.waveStat.frame.Position = UDim2.fromOffset(start, 9); self.waveStat.frame.Size = UDim2.fromOffset(105, 48)
		self.coreStat.frame.Position = UDim2.fromOffset(start + gap, 9); self.coreStat.frame.Size = UDim2.fromOffset(medium and 110 or 145, 48)
		self.goldStat.frame.Position = UDim2.fromOffset(start + gap * 2, 9); self.goldStat.frame.Size = UDim2.fromOffset(105, 48)
		self.enemyStat.frame.Position = UDim2.fromOffset(start + gap * 3, 9); self.enemyStat.frame.Size = UDim2.fromOffset(125, 48)
		self.phaseStat.frame.Position = UDim2.fromOffset(start + gap * (medium and 3 or 4), 9); self.phaseStat.frame.Size = UDim2.fromOffset(medium and 125 or 160, 48)
		self.waveStat.value.TextSize = 21; self.coreStat.value.TextSize = 21; self.goldStat.value.TextSize = 21; self.phaseStat.value.TextSize = 21
	end
	self.enemyStat.frame.Visible = not medium and not self.compact
	self.team.Visible = not self.compact or self.teamOpen
	self.teamToggle.Visible = self.compact
	self.team.Position = UDim2.fromOffset(self.compact and 12 or 16, self.compact and 154 or 92)
	self.team.ZIndex = 25
	for _, slot in ipairs(self.slots) do slot.row.ZIndex = 26; slot.name.ZIndex = 27; slot.detail.ZIndex = 27; slot.dot.ZIndex = 27 end
	self.teamTitle.ZIndex = 26
	local rightWidth = self.compact and 196 or (medium and 224 or 250)
	self.preview.Position = UDim2.new(1, -rightWidth - 12, 0, self.compact and 116 or 92)
	self.preview.Size = UDim2.fromOffset(rightWidth, 96)
	self.command.Position = UDim2.new(1, -rightWidth - 12, 0, self.compact and 224 or 200)
	self.command.Size = UDim2.fromOffset(rightWidth, 142)
	local cardWidth = self.compact and 86 or (medium and 126 or 146)
	local gap = self.compact and 6 or 8
	local padding = self.compact and 8 or 10
	local dockWidth = cardWidth * 4 + gap * 3 + padding * 2
	self.dock.Size = UDim2.fromOffset(dockWidth, self.compact and 114 or 132)
	for index, kind in ipairs(Config.TowerOrder) do
		local item = self.shop[kind]
		item.card.Position = UDim2.fromOffset(padding + (index - 1) * (cardWidth + gap), padding)
		item.card.Size = UDim2.fromOffset(cardWidth, self.compact and 98 or 112)
		item.name.TextSize = self.compact and 11 or 14
		item.role.Visible = not self.compact; item.key.Visible = not self.compact
		item.cost.Position = UDim2.fromOffset(11, self.compact and 73 or 87)
		item.icon.Position = UDim2.fromOffset(self.compact and 20 or 12, 7)
	end
	self.abilities.Position = UDim2.new(0, self.compact and 12 or 16, 1, self.compact and -258 or -292)
	self.abilities.Size = UDim2.fromOffset(self.compact and 145 or 192, 128)
	self.meteorButton.Size = UDim2.new(1, 0, 0, self.compact and 42 or 46)
	self.freezeButton.Position = UDim2.fromOffset(0, self.compact and 73 or 77)
	self.freezeButton.Size = UDim2.new(1, 0, 0, self.compact and 42 or 46)
	self.inspector.Position = UDim2.new(1, self.compact and -248 or -306, 0, self.compact and 116 or 92)
	self.inspector.Size = UDim2.fromOffset(self.compact and 236 or 290, 354)
	if self.compact then
		self.damageStat.Position = UDim2.fromOffset(0, 0); self.damageValue.Position = UDim2.fromOffset(0, 21)
		self.rangeStat.Position = UDim2.fromOffset(73, 0); self.rangeValue.Position = UDim2.fromOffset(73, 21)
		self.rateStat.Position = UDim2.fromOffset(146, 0); self.rateValue.Position = UDim2.fromOffset(146, 21)
		for index, priority in ipairs(Config.Priorities) do self.priorityButtons[priority].Position = UDim2.fromOffset(15 + (index - 1) * 70, 193); self.priorityButtons[priority].Size = UDim2.fromOffset(66, 30) end
	else
		self.rangeStat.Position = UDim2.fromOffset(88, 0); self.rangeValue.Position = UDim2.fromOffset(88, 21)
		self.rateStat.Position = UDim2.fromOffset(176, 0); self.rateValue.Position = UDim2.fromOffset(176, 21)
		for index, priority in ipairs(Config.Priorities) do self.priorityButtons[priority].Position = UDim2.fromOffset(15 + (index - 1) * 88, 193); self.priorityButtons[priority].Size = UDim2.fromOffset(82, 30) end
	end
	self.minimap.Visible = not medium and not self.compact
	self.hint.Visible = not medium and not self.compact
	self.help.Size = UDim2.fromOffset(math.min(600, viewport.X - 24), 470)
	self.result.Size = UDim2.fromOffset(math.min(520, viewport.X - 24), 448)
	self.toastRoot.Position = UDim2.new(0.5, 0, 0, self.compact and 116 or 90)
	self.toastRoot.Size = UDim2.fromOffset(math.min(430, viewport.X - 30), 180)
	self:RefreshVisibility()
end

function UI:RefreshVisibility()
	local ended = self.state and (self.state.phase == "Victory" or self.state.phase == "Defeat")
	self.inspector.Visible = self.selectedPad ~= nil and not ended
	self.preview.Visible = self.selectedPad == nil and not ended
	self.command.Visible = self.selectedPad == nil and not ended
	-- On narrow screens the inspector replaces abilities instead of overlapping them.
	self.abilities.Visible = not self.compact or (self.selectedPad == nil and not ended)
	self.modalShade.Visible = ended == true
end

function UI:Update(state)
	local first = self.state == nil
	self.state = state; self.receivedAt = os.clock()
	self.loading.Visible = false
	self.waveStat.value.Text = string.format("%02d / %02d", state.wave, state.maxWaves)
	self.coreStat.value.Text = state.coreHP .. " / " .. state.coreMax
	self.coreBar.Size = UDim2.fromScale(math.clamp(state.coreHP / state.coreMax, 0, 1), 1)
	self.coreBar.BackgroundColor3 = state.coreHP / state.coreMax < 0.3 and Theme.Red or Theme.Mint
	self.goldStat.value.Text = Format.Number(state.gold) .. "  ◆"
	self.enemyStat.value.Text = tostring(state.remaining)
	local phaseNames = { Lobby = "ПОДГОТОВКА", Combat = "ВОЛНА ИДЁТ", Intermission = "ПЕРЕДЫШКА", Victory = "ПОБЕДА", Defeat = "ПОРАЖЕНИЕ" }
	self.phaseStat.title.Text = phaseNames[state.phase] or ""
	self.phaseStat.value.Text = state.phase == "Combat" and (state.speed == 2 and "2×  В БОЮ" or "В БОЮ") or Format.Time(state.nextIn)
	self.teamTitle.Text = "ОТРЯД  " .. #state.players .. " / 4"
	for index, slot in ipairs(self.slots) do
		local player = state.players[index]
		if player then
			slot.name.Text = player.name .. "  ·  ур. " .. player.level
			slot.dot.BackgroundColor3 = player.id == Players.LocalPlayer.UserId and Theme.Mint or Theme.Blue
			slot.detail.Text = state.phase == "Lobby" and (player.ready and "✓ Готов  ·  " .. Format.Number(player.gold) .. " ◆" or "Строит оборону  ·  " .. Format.Number(player.gold) .. " ◆") or (player.kills .. " добив.  ·  " .. Format.Number(player.damage) .. " урона")
		else
			slot.name.Text = "Свободное место"; slot.detail.Text = "Пригласите друга"; slot.dot.BackgroundColor3 = Theme.Stroke
		end
	end
	local combat = state.phase == "Combat"
	self.previewTitle.Text = (combat and "СЕЙЧАС · ВОЛНА " or "СЛЕДУЮЩАЯ ВОЛНА ") .. string.format("%02d", combat and state.wave or state.previewWave)
	self.previewDescription.Text = Waves.Description(combat and state.wave or state.previewWave)
	local counts = {}
	for _, kind in ipairs({ "Scout", "Runner", "Brute", "Shield", "Wisp", "Boss" }) do
		if state.preview[kind] then table.insert(counts, Config.Enemies[kind].name .. " ×" .. state.preview[kind]) end
	end
	self.previewCounts.Text = table.concat(counts, " · ")
	self.waveBar.Size = UDim2.fromScale(combat and math.clamp(state.progress, 0, 1) or 1, 1)
	local mine = self:Mine()
	local lobby = state.phase == "Lobby"
	local intermission = state.phase == "Intermission"
	self.readyButton.Visible = lobby; self.normalButton.Visible = lobby; self.hardButton.Visible = lobby
	self.skipButton.Visible = intermission
	self.speed1.Visible = combat or intermission; self.speed2.Visible = combat or intermission
	self.readyButton.Text = mine and mine.ready and "✓ ГОТОВ · ОТМЕНИТЬ" or "Я ГОТОВ"
	self.normalButton.BackgroundColor3 = mine and mine.difficulty == "Normal" and Color3.fromRGB(44, 88, 91) or Theme.Panel2
	self.hardButton.BackgroundColor3 = mine and mine.difficulty == "Hard" and Color3.fromRGB(117, 69, 65) or Theme.Panel2
	self.speed1.BackgroundColor3 = mine and mine.speedVote == 1 and Color3.fromRGB(44, 88, 91) or Theme.Panel2
	self.speed2.BackgroundColor3 = mine and mine.speedVote == 2 and Color3.fromRGB(44, 88, 91) or Theme.Panel2
	self.speed1.Text = "1×"; self.speed2.Text = "2×"
	local speedVotes = 0
	for _, player in ipairs(state.players) do if player.speedVote == 2 then speedVotes += 1 end end
	if lobby then
		local hardVotes = 0
		for _, player in ipairs(state.players) do if player.difficulty == "Hard" then hardVotes += 1 end end
		self.commandHint.Text = string.format("Готовы %d/%d · Испытание %d/%d\nБольшинство решает. Можно строить заранее.", state.readyCount, #state.players, hardVotes, #state.players)
	elseif intermission then
		local votes = 0
		for _, player in ipairs(state.players) do if player.skipVote then votes += 1 end end
		self.skipButton.Text = "НАЧАТЬ РАНЬШЕ  ·  " .. votes .. "/" .. (math.floor(#state.players / 2) + 1)
		self.commandHint.Text = "Передышка " .. Format.Time(state.nextIn) .. " · Улучшите башни.\n2× выбирается большинством отряда."
	else
		self.commandHint.Text = "Ускорение 2×: " .. speedVotes .. "/" .. #state.players .. " голосов.\nЯдро у команды общее. Берегите его."
	end
	for kind, item in pairs(self.shop) do
		local affordable = state.gold >= Config.Towers[kind].cost
		item.cost.TextColor3 = affordable and Theme.Gold or Theme.Red
		item.outline.Transparency = self.pendingType == kind and 0 or 0.65
		item.outline.Thickness = self.pendingType == kind and 2 or 1
	end
	local meteorCD = state.cooldowns.Meteor or 0
	local freezeCD = state.cooldowns.Freeze or 0
	self.meteorButton.Text = self.targeting and "ВЫБЕРИТЕ ТОЧКУ" or (meteorCD > 0 and "МЕТЕОР  ·  " .. math.ceil(meteorCD) .. " с" or "Q   МЕТЕОР")
	self.freezeButton.Text = freezeCD > 0 and "СТУЖА  ·  " .. math.ceil(freezeCD) .. " с" or "E   СТУЖА"
	self.meteorButton.TextColor3 = self.targeting and Theme.Gold or (meteorCD > 0 and Theme.Muted or Theme.Text)
	self.freezeButton.TextColor3 = freezeCD > 0 and Theme.Muted or Theme.Text
	if state.phase == "Victory" or state.phase == "Defeat" then self:UpdateResult(state) end
	self:RefreshVisibility()
	if self.selectedPad then self.actions.RefreshSelection() end
	if first then self:ShowHelp(true) end
end

function UI:Selection(padId, attributes, pendingType)
	self.selectedPad = padId; self.pendingType = pendingType
	if not padId then self:RefreshVisibility(); return end
	local kind = attributes.TowerType
	local occupied = kind ~= nil and kind ~= "" and Config.Towers[kind] ~= nil
	self.inspectorTitle.Text = string.format("ПЛОЩАДКА %02d", padId)
	self.statsFrame.Visible = occupied; self.priorityLabel.Visible = occupied
	for _, b in pairs(self.priorityButtons) do b.Visible = occupied end
	self.upgradeButton.Visible = occupied; self.sellButton.Visible = occupied
	self.towerDescription.Visible = not occupied
	if occupied then
		local def = Config.Towers[kind]
		local level = attributes.Level or 1
		local stats = Config.Stats(kind, level)
		local owner = attributes.OwnerId == Players.LocalPlayer.UserId
		self.towerName.Text = def.name .. "  " .. Format.Roman(level); self.towerName.TextColor3 = def.color
		self.towerOwner.Text = owner and "Ваша башня · улучшение до уровня IV" or "Владелец: " .. (attributes.OwnerName or "игрок")
		self.damageValue.Text = tostring(math.floor(stats.damage + 0.5)); self.rangeValue.Text = tostring(stats.range); self.rateValue.Text = string.format("%.1f", 1 / stats.interval)
		local cost = def.upgradeCosts[level]
		self.upgradeButton.Text = cost and ("УЛУЧШИТЬ ДО " .. Format.Roman(level + 1) .. "  ·  " .. cost .. " ◆") or "МАКСИМАЛЬНЫЙ УРОВЕНЬ"
		self.upgradeButton.BackgroundColor3 = owner and cost and Color3.fromRGB(45, 102, 83) or Theme.Panel2
		self.sellButton.Text = "ПРОДАТЬ  ·  +" .. math.floor((attributes.Invested or def.cost) * Config.SellRefund) .. " ◆"
		self.sellButton.Visible = owner
		self.inspectorHint.Text = owner and "Продажа возвращает 70% всех вложений." or "Чужие башни нельзя улучшать или продавать."
		for priority, b in pairs(self.priorityButtons) do b.BackgroundColor3 = attributes.Priority == priority and Color3.fromRGB(44, 88, 91) or Theme.Panel2 end
	else
		self.towerName.Text = "Свободная площадка"; self.towerName.TextColor3 = Theme.Text
		self.towerOwner.Text = "Общее место для обороны команды"
		self.towerDescription.Text = pendingType and ("Выбрана башня «" .. Config.Towers[pendingType].name .. "». Нажмите «ПОСТРОИТЬ» или выберите другую башню внизу.") or "Выберите башню в нижней панели. Стоимость спишется только при строительстве."
		self.upgradeButton.Visible = true
		self.upgradeButton.Text = pendingType and ("ПОСТРОИТЬ  ·  " .. Config.Towers[pendingType].cost .. " ◆") or "ВЫБЕРИТЕ БАШНЮ ВНИЗУ"
		self.upgradeButton.BackgroundColor3 = pendingType and Color3.fromRGB(45, 102, 83) or Theme.Panel2
		self.inspectorHint.Text = "1–4 — быстрый выбор типа башни"
	end
	self:RefreshVisibility()
end

function UI:UpdateResult(state)
	local result = state.result
	if not result then return end
	self.resultTitle.Text = result.victory and "РУБЕЖ УДЕРЖАН" or "ЯДРО ПОТЕРЯНО"
	self.resultTitle.TextColor3 = result.victory and Theme.Mint or Theme.Red
	self.resultSubtitle.Text = result.victory and "Команда отразила все 20 волн. Отличная работа!" or "Попробуйте больше замедления и улучшений у поворотов."
	self.resultStats.Text = "Волн отражено: " .. result.cleared .. " / 20     ·     Время: " .. Format.Time(result.duration) .. "\nЯдро: " .. result.coreHP .. "     ·     Режим: " .. Config.Difficulties[state.difficulty].label
	local sorted = table.clone(state.players)
	table.sort(sorted, function(a, b) return a.damage > b.damage end)
	for index, row in ipairs(self.resultRows) do
		local player = sorted[index]
		row.Text = player and string.format("%d.  %s     %s урона     %d добиваний", index, player.name, Format.Number(player.damage), player.kills) or ""
	end
	local votes = 0
	for _, player in ipairs(state.players) do if player.replayVote then votes += 1 end end
	local mine = self:Mine()
	self.replayButton.Text = (mine and mine.replayVote and "ГОЛОС УЧТЁН  ·  " or "ЕЩЁ ОДИН МАТЧ  ·  ") .. votes .. "/" .. (math.floor(#state.players / 2) + 1)
	self.resultHint.Text = "Новый матч начнётся автоматически через " .. Format.Time(state.nextIn) .. ". Прогресс аккаунта сохраняется."
end

function UI:SetTargeting(active)
	self.targeting = active
	if self.state then self.meteorButton.Text = active and "ВЫБЕРИТЕ ТОЧКУ" or "Q   МЕТЕОР" end
end

function UI:ShowHelp(visible)
	self.helpShade.Visible = visible
end

function UI:Toast(message, tone)
	if #self.toasts >= 3 then
		local oldest = table.remove(self.toasts, 1)
		if oldest then oldest:Destroy() end
	end
	local color = tone == "danger" and Theme.Red or (tone == "success" and Theme.Mint or (tone == "ability" and Theme.Gold or Theme.Blue))
	local frame = create("Frame", { Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = Theme.Background, BackgroundTransparency = 0.05, BorderSizePixel = 0, ZIndex = 41 }, self.toastRoot)
	corner(frame, 8); stroke(frame, color, 0.4)
	local accent = create("Frame", { Position = UDim2.fromOffset(0, 9), Size = UDim2.fromOffset(3, 24), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 42 }, frame)
	corner(accent, 2)
	local label = text(frame, message, UDim2.fromOffset(14, 4), UDim2.new(1, -28, 1, -8), 12, Theme.Text, true)
	label.TextWrapped = true; label.ZIndex = 42
	table.insert(self.toasts, frame)
	task.delay(3.8, function()
		if frame.Parent then
			local tween = TweenService:Create(frame, TweenInfo.new(0.25), { BackgroundTransparency = 1 })
			tween:Play(); label.TextTransparency = 1; accent.BackgroundTransparency = 1
			task.wait(0.25); frame:Destroy()
			local index = table.find(self.toasts, frame); if index then table.remove(self.toasts, index) end
		end
	end)
end

function UI:UpdateMinimap(enemyFolder)
	for _, dot in ipairs(self.mapDots:GetChildren()) do dot:Destroy() end
	if not enemyFolder then return end
	for _, enemy in ipairs(enemyFolder:GetChildren()) do
		local kind = enemy:GetAttribute("EnemyKind")
		if kind and Config.Enemies[kind] then
			local position = enemy:GetPivot().Position
			local size = Config.Enemies[kind].boss and 7 or 4
			local dot = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale((position.X + 88) / 176, (position.Z + 57) / 114), Size = UDim2.fromOffset(size, size), BackgroundColor3 = Config.Enemies[kind].color, BorderSizePixel = 0, ZIndex = 4 }, self.mapDots)
			corner(dot, size / 2)
		end
	end
end

return UI
