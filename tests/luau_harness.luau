-- Lightweight Roblox API double for headless Luau tests. Not a Studio emulator.
local realType = type
warn = function(...) print("[warn]", ...) end
local function classOf(value)
	if realType(value) == "table" then return getmetatable(value) end
	return nil
end

Vector3 = {}
local V3 = { __index = Vector3 }
function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
end
Vector3.zero = Vector3.new(0, 0, 0)
Vector3.one = Vector3.new(1, 1, 1)
function V3.__add(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
function V3.__sub(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
function V3.__unm(a) return Vector3.new(-a.X, -a.Y, -a.Z) end
function V3.__mul(a, b)
	if realType(b) == "number" then return Vector3.new(a.X * b, a.Y * b, a.Z * b) end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
function V3.__div(a, b) return Vector3.new(a.X / b, a.Y / b, a.Z / b) end
function V3.__eq(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
function Vector3:Dot(other) return self.X * other.X + self.Y * other.Y + self.Z * other.Z end
function Vector3:Cross(other) return Vector3.new(self.Y * other.Z - self.Z * other.Y, self.Z * other.X - self.X * other.Z, self.X * other.Y - self.Y * other.X) end
function Vector3:Lerp(other, alpha) return self + (other - self) * alpha end
V3.__index = function(self, key)
	if key == "Magnitude" then return math.sqrt(self.X ^ 2 + self.Y ^ 2 + self.Z ^ 2) end
	if key == "Unit" then local m = math.sqrt(self.X ^ 2 + self.Y ^ 2 + self.Z ^ 2); return m > 0 and self / m or Vector3.zero end
	return Vector3[key]
end

Vector2 = {}
local V2 = { __index = Vector2 }
function Vector2.new(x, y) return setmetatable({ X = x or 0, Y = y or 0 }, V2) end
Vector2.zero = Vector2.new(0, 0)
function V2.__add(a, b) return Vector2.new(a.X + b.X, a.Y + b.Y) end
function V2.__sub(a, b) return Vector2.new(a.X - b.X, a.Y - b.Y) end
function V2.__mul(a, b) return Vector2.new(a.X * b, a.Y * b) end
function V2.__div(a, b) return Vector2.new(a.X / b, a.Y / b) end
V2.__index = function(self, key)
	if key == "Magnitude" then return math.sqrt(self.X ^ 2 + self.Y ^ 2) end
	return Vector2[key]
end

Color3 = {}
local C3 = { __index = Color3 }
function Color3.new(r, g, b) return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3) end
function Color3.fromRGB(r, g, b) return Color3.new(r / 255, g / 255, b / 255) end
function Color3:Lerp(other, alpha) return Color3.new(self.R + (other.R - self.R) * alpha, self.G + (other.G - self.G) * alpha, self.B + (other.B - self.B) * alpha) end

CFrame = {}
local CF = { __index = CFrame }
local function cf(position, r) return setmetatable({ Position = position, r = r or { 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, CF) end
function CFrame.new(x, y, z)
	if realType(x) == "table" then return cf(x) end
	return cf(Vector3.new(x, y, z))
end
function CFrame.Angles(rx, ry, rz)
	local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
	return cf(Vector3.zero, { cy * cz, -cy * sz, sy, cx * sz + sx * sy * cz, cx * cz - sx * sy * sz, -sx * cy, sx * sz - cx * sy * cz, sx * cz + cx * sy * sz, cx * cy })
end
function CFrame.lookAt(position, target)
	local back = (position - target).Unit
	if back.Magnitude == 0 then back = Vector3.new(0, 0, 1) end
	local right = Vector3.new(0, 1, 0):Cross(back).Unit
	if right.Magnitude == 0 then right = Vector3.new(1, 0, 0) end
	local up = back:Cross(right)
	return cf(position, { right.X, up.X, back.X, right.Y, up.Y, back.Y, right.Z, up.Z, back.Z })
end
function CF.__mul(a, b)
	if classOf(b) == V3 then
		local r = a.r
		return a.Position + Vector3.new(r[1] * b.X + r[2] * b.Y + r[3] * b.Z, r[4] * b.X + r[5] * b.Y + r[6] * b.Z, r[7] * b.X + r[8] * b.Y + r[9] * b.Z)
	elseif classOf(b) == CF then
		local ar, br, r = a.r, b.r, {}
		for row = 0, 2 do for col = 0, 2 do
			r[row * 3 + col + 1] = ar[row * 3 + 1] * br[col + 1] + ar[row * 3 + 2] * br[3 + col + 1] + ar[row * 3 + 3] * br[6 + col + 1]
		end end
		return cf(a.Position + a * b.Position, r)
	end
	error("Unsupported CFrame multiplication")
end
function CF.__add(a, b) return cf(a.Position + b, a.r) end
function CF.__sub(a, b) return cf(a.Position - b, a.r) end
CF.__index = function(self, key)
	if key == "LookVector" then return -Vector3.new(self.r[3], self.r[6], self.r[9]) end
	if key == "RightVector" then return Vector3.new(self.r[1], self.r[4], self.r[7]) end
	if key == "UpVector" then return Vector3.new(self.r[2], self.r[5], self.r[8]) end
	return CFrame[key]
end

TweenInfo = { new = function(time, style, direction) return { Time = time or 1, EasingStyle = style, EasingDirection = direction } end }
UDim = { new = function(scale, offset) return { Scale = scale or 0, Offset = offset or 0 } end }
UDim2 = {}
function UDim2.new(xs, xo, ys, yo) return { X = UDim.new(xs, xo), Y = UDim.new(ys, yo), Width = UDim.new(xs, xo), Height = UDim.new(ys, yo) } end
function UDim2.fromScale(x, y) return UDim2.new(x, 0, y, 0) end
function UDim2.fromOffset(x, y) return UDim2.new(0, x, 0, y) end

Enum = setmetatable({}, { __index = function(self, category)
	local value = setmetatable({}, { __index = function(items, name) local item = { Name = name, Value = 0 }; rawset(items, name, item); return item end })
	rawset(self, category, value); return value
end })

local function signal()
	local handlers = {}
	return {
		Connect = function(_, fn) local h = { fn = fn, Connected = true }; function h:Disconnect() self.Connected = false end; table.insert(handlers, h); return h end,
		Once = function(self, fn) local h; h = self:Connect(function(...) if h.Connected then h:Disconnect(); fn(...) end end); return h end,
		Fire = function(_, ...) for _, h in ipairs(table.clone(handlers)) do if h.Connected then h.fn(...) end end end,
	}
end
Signal = signal

local InstanceMT = {}
local function propsOf(self) return rawget(self, "__props") end
local methods = {}
local signalNames = { Destroying = true, Changed = true, InputBegan = true, InputChanged = true, InputEnded = true, Activated = true, MouseEnter = true, MouseLeave = true, OnClientEvent = true, OnServerEvent = true, CharacterAdded = true, PlayerAdded = true, PlayerRemoving = true, Heartbeat = true, RenderStepped = true, Stepped = true, Completed = true }
Instance = {}
function Instance.new(className)
	local props = { ClassName = className, Name = className, Parent = nil, Attributes = {}, Children = {}, Signals = {}, Source = "" }
	if className == "Part" or className == "SpawnLocation" then
		props.Size = Vector3.one; props.CFrame = CFrame.new(); props.Color = Color3.new(1, 1, 1); props.Transparency = 0; props.Anchored = false; props.CanCollide = true; props.CanQuery = true
	elseif className == "Model" then props.PrimaryPart = nil
	elseif className == "Frame" or className == "TextLabel" or className == "TextButton" then props.Size = UDim2.fromScale(1, 1); props.Position = UDim2.fromScale(0, 0); props.Visible = true; props.Text = ""
	elseif className == "Highlight" then props.Enabled = true
	end
	local object = setmetatable({ __props = props }, InstanceMT)
	return object
end
function InstanceMT.__index(self, key)
	local props = propsOf(self)
	if type(props[key]) == "function" then return props[key] end
	if methods[key] then return methods[key] end
	if signalNames[key] then
		if not props.Signals[key] then props.Signals[key] = signal() end
		return props.Signals[key]
	end
	if props[key] ~= nil then return props[key] end
	for _, child in ipairs(props.Children) do if child.Name == key then return child end end
	return nil
end
function InstanceMT.__newindex(self, key, value)
	local props = propsOf(self)
	if (props.ClassName == "Part" or props.ClassName == "SpawnLocation") and (key == "Visible" or key == "Enabled") then
		error("Invalid BasePart property: " .. key)
	end
	if key == "Parent" then
		local old = props.Parent
		if old then local children = propsOf(old).Children; local index = table.find(children, self); if index then table.remove(children, index) end end
		props.Parent = value
		if value then table.insert(propsOf(value).Children, self) end
	else props[key] = value end
end
function methods:FindFirstChild(name)
	for _, child in ipairs(propsOf(self).Children) do if child.Name == name then return child end end
	return nil
end
function methods:WaitForChild(name) return self:FindFirstChild(name) end
function methods:FindFirstChildOfClass(className)
	for _, child in ipairs(propsOf(self).Children) do if child.ClassName == className then return child end end
	return nil
end
function methods:GetChildren() return table.clone(propsOf(self).Children) end
function methods:IsA(className) return propsOf(self).ClassName == className end
function methods:SetAttribute(name, value) propsOf(self).Attributes[name] = value end
function methods:GetAttribute(name) return propsOf(self).Attributes[name] end
function methods:GetAttributes() return table.clone(propsOf(self).Attributes) end
function methods:GetPropertyChangedSignal(name) local key = "Property:" .. name; local signals = propsOf(self).Signals; if not signals[key] then signals[key] = signal() end; return signals[key] end
function methods:ClearAllChildren() for _, child in ipairs(self:GetChildren()) do child:Destroy() end end
function methods:Destroy()
	self:ClearAllChildren()
	self.Destroying:Fire()
	self.Parent = nil
	propsOf(self).Destroyed = true
end
function methods:GetPivot()
	local props = propsOf(self)
	if props.Pivot then return props.Pivot end
	if props.PrimaryPart then return props.PrimaryPart.CFrame end
	return props.CFrame or CFrame.new()
end
function methods:PivotTo(cframe)
	propsOf(self).Pivot = cframe
	if propsOf(self).PrimaryPart then propsOf(self).PrimaryPart.CFrame = cframe end
end
function methods:Kick(message) propsOf(self).Kicked = message; self.Parent = nil end
function methods:FireClient(player, ...) if player == Players.LocalPlayer then self.OnClientEvent:Fire(...) end end
function methods:FireAllClients(...) self.OnClientEvent:Fire(...) end
function methods:FireServer(...) self.OnServerEvent:Fire(...) end
function methods:GetPlayerByUserId(id) for _, player in ipairs(self:GetPlayers()) do if player.UserId == id then return player end end return nil end
function methods:GetPlayers()
	local result = {}
	for _, child in ipairs(propsOf(self).Children) do if child.ClassName == "Player" then table.insert(result, child) end end
	return result
end
function methods:GetService(name) return Services[name] end
function methods:BindToClose(fn) propsOf(self).CloseCallback = fn end
function methods:IsStudio()
	local override = propsOf(self).IsStudio
	if override ~= nil then return override() end
	return true
end
function methods:SetCoreGuiEnabled() end
function methods:SetCore() end
function methods:ScreenPointToRay(x, y) return { Origin = Vector3.new(0, 100, 0), Direction = Vector3.new((x - 640) / 1000, -1, (y - 360) / 1000).Unit } end
function methods:Connect() end

Services = {}
local function service(name, className)
	local object = Instance.new(className or name); object.Name = name; Services[name] = object; return object
end
game = Instance.new("DataModel")
workspace = service("Workspace")
Players = service("Players")
ReplicatedStorage = service("ReplicatedStorage")
ServerScriptService = service("ServerScriptService")
StarterPlayer = service("StarterPlayer")
StarterGui = service("StarterGui")
Lighting = service("Lighting")
SoundService = service("SoundService")
RunService = service("RunService")
UserInputService = service("UserInputService")
TweenService = service("TweenService")
Debris = service("Debris")
HttpService = service("HttpService")
DataStoreService = service("DataStoreService")
TextChatService = service("TextChatService")
workspace.CurrentCamera = Instance.new("Camera")
workspace.CurrentCamera.ViewportSize = Vector2.new(1280, 720)
workspace.CurrentCamera.FieldOfView = 50
local starterScripts = Instance.new("StarterPlayerScripts"); starterScripts.Name = "StarterPlayerScripts"; starterScripts.Parent = StarterPlayer
Players.LocalPlayer = Instance.new("Player"); Players.LocalPlayer.Name = "Tester"; Players.LocalPlayer.DisplayName = "Tester"; Players.LocalPlayer.UserId = 1; Players.LocalPlayer.Parent = Players
local playerGui = Instance.new("PlayerGui"); playerGui.Name = "PlayerGui"; playerGui.Parent = Players.LocalPlayer
local playerScripts = Instance.new("PlayerScripts"); playerScripts.Name = "PlayerScripts"; playerScripts.Parent = Players.LocalPlayer
local playerModule = Instance.new("ModuleScript"); playerModule.Name = "PlayerModule"; playerModule.Parent = playerScripts

local guid = 0
function HttpService:GenerateGUID() guid += 1; return "guid-" .. guid end
function HttpService:JSONEncode(value) return tostring(value) end
function DataStoreService:GetDataStore()
	return { UpdateAsync = function(_, _, transform) return transform(nil) end }
end
function TweenService:Create(object, info, goals)
	return { Play = function() for key, value in pairs(goals) do object[key] = value end end, Cancel = function() end, Completed = signal() }
end
function Debris:AddItem(object, lifetime) task.delay(lifetime, function() if object.Parent then object:Destroy() end end) end

VirtualTime = 0
local realOS = os
os = setmetatable({ clock = function() return VirtualTime end }, { __index = realOS })
local delayedTasks = {}
task = {
	wait = function(seconds) return coroutine.yield(seconds or 0) end,
	spawn = function(fn, ...)
		local thread = coroutine.create(fn)
		local ok, problem = coroutine.resume(thread, ...)
		if not ok then error(problem) end
		return thread
	end,
	delay = function(seconds, fn, ...) table.insert(delayedTasks, { at = os.clock() + seconds, fn = fn, args = { ... } }); return delayedTasks[#delayedTasks] end,
	defer = function(fn, ...) table.insert(delayedTasks, { at = os.clock(), fn = fn, args = { ... } }); return delayedTasks[#delayedTasks] end,
}
Random = {}
function Random.new(seed)
	local state = seed or 1
	local function nextNumber(a, b)
		state = (state * 1103515245 + 12345) % 2147483648
		local alpha = state / 2147483648
		if a then return a + (b - a) * alpha end
		return alpha
	end
	return { NextNumber = function(_, a, b) return nextNumber(a, b) end, NextInteger = function(_, a, b) return math.floor(nextNumber(a, b + 1)) end }
end
typeof = function(value)
	local mt = classOf(value)
	if mt == V3 then return "Vector3" elseif mt == V2 then return "Vector2" elseif mt == CF then return "CFrame" elseif mt == C3 then return "Color3" end
	if mt == InstanceMT then return "Instance" end
	return realType(value)
end

-- Build the same hierarchy as default.project.json from embedded source files.
local moduleCache = {}
local function buildTree(parent, prefix)
	local direct = {}
	for path in pairs(SOURCES) do
		if string.sub(path, 1, #prefix) == prefix then
			local rest = string.sub(path, #prefix + 1)
			if not string.find(rest, "/", 1, true) then table.insert(direct, path) end
		end
	end
	table.sort(direct)
	for _, path in ipairs(direct) do
		local filename = string.match(path, "([^/]+)$")
		local className, name = "ModuleScript", string.gsub(filename, "%.luau$", "")
		if string.find(filename, ".server.luau", 1, true) then className = "Script"; name = string.gsub(filename, "%.server%.luau$", "")
		elseif string.find(filename, ".client.luau", 1, true) then className = "LocalScript"; name = string.gsub(filename, "%.client%.luau$", "") end
		local object = Instance.new(className); object.Name = name; object.Parent = parent; object:SetAttribute("SourcePath", path)
	end
	local folders = {}
	for path in pairs(SOURCES) do
		if string.sub(path, 1, #prefix) == prefix then
			local rest = string.sub(path, #prefix + 1)
			local folder = string.match(rest, "^([^/]+)/")
			if folder then folders[folder] = true end
		end
	end
	for folder in pairs(folders) do
		local object = Instance.new("Folder"); object.Name = folder; object.Parent = parent
		buildTree(object, prefix .. folder .. "/")
	end
end
Shared = Instance.new("Folder"); Shared.Name = "Shared"; Shared.Parent = ReplicatedStorage; buildTree(Shared, "src/shared/")
local serverRoot = Instance.new("Folder"); serverRoot.Name = "Server"; serverRoot.Parent = ServerScriptService; buildTree(serverRoot, "src/server/")
local clientRoot = Instance.new("Folder"); clientRoot.Name = "Client"; clientRoot.Parent = starterScripts; buildTree(clientRoot, "src/client/")

function Require(module)
	assert(typeof(module) == "Instance" and module.ClassName == "ModuleScript", "Require expects a ModuleScript")
	if moduleCache[module] ~= nil then return moduleCache[module] end
	local path = module:GetAttribute("SourcePath")
	local fn, problem = loadstring(SOURCES[path], "@" .. path)
	if not fn then error(problem) end
	local env = setmetatable({ script = module, require = Require }, { __index = getfenv(0) })
	setfenv(fn, env)
	local result = fn()
	moduleCache[module] = result
	return result
end

function LoadScript(path)
	local fn, problem = loadstring(SOURCES[path], "@" .. path)
	if not fn then error(problem) end
	local object
	if string.find(path, "src/server/", 1, true) then object = serverRoot:FindFirstChild("Main") else object = clientRoot:FindFirstChild("Main") end
	local env = setmetatable({ script = object, require = Require }, { __index = getfenv(0) })
	setfenv(fn, env)
	return fn()
end

function AddTestPlayer(id, name)
	local player = Instance.new("Player"); player.Name = name; player.DisplayName = name; player.UserId = id; player.Parent = Players
		local character = Instance.new("Model"); character.Name = name .. "Character"
	local root = Instance.new("Part"); root.Name = "HumanoidRootPart"; root.Parent = character
	local humanoid = Instance.new("Humanoid"); humanoid.Name = "Humanoid"; humanoid.Parent = character
	player.Character = character
	Players.PlayerAdded:Fire(player)
	return player
end

function FireAction(player, kind, payload)
	payload = payload or {}; payload.kind = kind
	ReplicatedStorage.TD_Remotes.Action.OnServerEvent:Fire(player, payload)
end

function Tick(seconds)
	local step = 1 / 20
	local remaining = seconds
	while remaining > 0 do
		local dt = math.min(step, remaining)
		VirtualTime += dt
		RunService.Heartbeat:Fire(dt)
		remaining -= dt
	end
end
