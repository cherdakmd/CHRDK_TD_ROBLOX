-- A deterministic solo commander should be able to win with a sensible mixed defense.
local Config = Require(Shared.Config)
local Path = Require(Shared.Path)
local Economy = Require(Shared.Economy)
LoadScript("src/server/Main.server.luau")
local player = Players.LocalPlayer
local remotes = ReplicatedStorage.TD_Remotes
local pads = workspace.TD_Map.Pads
local enemiesFolder = workspace.TD_Map.Enemies
local latest
remotes.State.OnClientEvent:Connect(function(state) latest = state end)
local function send(kind, payload) payload = payload or {}; payload.kind = kind; remotes.Action.OnServerEvent:Fire(player, payload) end
local function state() send("Hello"); return latest end
local function padObject(id) return pads:FindFirstChild(string.format("Pad_%02d", id)) end

local samples = {}
for distance = 0, Path.Length, 2 do
	local x, z = Path.Sample(distance)
	table.insert(samples, { x = x, z = z })
end
local scores = {}
for id, coordinates in ipairs(Config.Map.Pads) do
	local x, z = coordinates[1] * Config.Map.Scale, coordinates[2] * Config.Map.Scale
	local score = 0
	for _, sample in ipairs(samples) do
		if math.sqrt((x - sample.x) ^ 2 + (z - sample.z) ^ 2) <= 27 then score += 1 end
	end
	scores[id] = score
end
local buildOrder = { "Sentry", "Frost", "Sentry", "Cannon", "Tesla", "Sentry", "Frost", "Cannon", "Tesla", "Sentry", "Frost", "Tesla" }
local buildIndex = 1
local function spend()
	local s = state()
	if not s or (s.phase ~= "Lobby" and s.phase ~= "Combat" and s.phase ~= "Intermission") then return end
	-- Establish a mixed core of six towers, then deepen upgrades.
	local owned = {}
	for id = 1, #Config.Map.Pads do
		local pad = padObject(id)
		if pad:GetAttribute("OwnerId") == player.UserId then table.insert(owned, id) end
	end
	if #owned >= 6 or buildIndex > #buildOrder then
		table.sort(owned, function(a, b) return scores[a] > scores[b] end)
		for _, id in ipairs(owned) do
			local pad = padObject(id)
			local cost = Economy.UpgradeCost(pad:GetAttribute("TowerType"), pad:GetAttribute("Level"))
			if cost and state().gold >= cost then send("Upgrade", { padId = id }); return end
		end
	end
	if buildIndex <= #buildOrder then
		local best, bestScore = nil, -1
		for id = 1, #Config.Map.Pads do
			local pad = padObject(id)
			if pad:GetAttribute("TowerType") == "" and scores[id] > bestScore then best, bestScore = id, scores[id] end
		end
		local kind = buildOrder[buildIndex]
		if best and state().gold >= Config.Towers[kind].cost then
			send("Build", { padId = best, towerType = kind }); buildIndex += 1
		end
	end
end
local function abilities()
	local s = state()
	if s.phase ~= "Combat" then return end
	local enemies = enemiesFolder:GetChildren()
	if #enemies >= 6 and (s.cooldowns.Freeze or 0) <= 0 then send("Ability", { ability = "Freeze" }) end
	if #enemies >= 4 and (s.cooldowns.Meteor or 0) <= 0 then
		local best, bestCount = nil, 0
		for _, enemy in ipairs(enemies) do
			local position = enemy:GetPivot().Position
			local count = 0
			for _, other in ipairs(enemies) do
				local p = other:GetPivot().Position
				if math.sqrt((position.X - p.X) ^ 2 + (position.Z - p.Z) ^ 2) <= Config.Abilities.Meteor.radius then count += 1 end
			end
			if count > bestCount then best, bestCount = position, count end
		end
		if best then send("Ability", { ability = "Meteor", target = best }) end
	end
end

send("Ready", { ready = true })
send("Speed", { value = 2 })
local elapsed = 0
while elapsed < 2400 do
	Tick(0.5); elapsed += 0.5
	local s = state()
	if s.phase == "Victory" or s.phase == "Defeat" then break end
	if s.phase == "Lobby" then send("Ready", { ready = true }) end
	if s.phase == "Intermission" then send("Skip", {}) end
	spend(); abilities()
end
local result = state()
print(string.format("balance: phase=%s wave=%d cleared=%d core=%d gold=%d towers=%d", result.phase, result.wave, result.wavesCleared, result.coreHP, result.gold, buildIndex - 1))
assert(result.phase == "Victory", "solo mixed-defense strategy should clear all 20 waves")
assert(result.coreHP > 0, "core survives")
print("balance_simulation: 2 assertions passed")
