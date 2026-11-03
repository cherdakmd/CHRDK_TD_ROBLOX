-- CHRDK / РУБЕЖ — authoritative cooperative tower defense server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Waves = require(Shared:WaitForChild("Waves"))
local Economy = require(Shared:WaitForChild("Economy"))
local Services = script.Parent:WaitForChild("Services")
local Map = require(Services:WaitForChild("Map"))
local Profiles = require(Services:WaitForChild("Profiles"))
local Enemies = require(Services:WaitForChild("Enemies"))
local Towers = require(Services:WaitForChild("Towers"))

Lighting.ClockTime = 14.5
Lighting.Brightness = 2.3
Lighting.Ambient = Color3.fromRGB(105, 126, 137)
Lighting.OutdoorAmbient = Color3.fromRGB(143, 157, 162)
Lighting.GlobalShadows = true
Lighting.FogEnd = 650
Lighting.FogColor = Color3.fromRGB(113, 161, 172)
pcall(function() workspace.StreamingEnabled = false end)

local remotes = Instance.new("Folder"); remotes.Name = "TD_Remotes"; remotes.Parent = ReplicatedStorage
local function remote(name)
	local event = Instance.new("RemoteEvent"); event.Name = name; event.Parent = remotes; return event
end
local StateRemote, ActionRemote, EffectsRemote, NoticeRemote = remote("State"), remote("Action"), remote("Effects"), remote("Notice")
local mapRoot = Map.Build()
Enemies:Init(mapRoot:WaitForChild("Enemies"))
Towers:Init(mapRoot:WaitForChild("Towers"))
Profiles:Init()

local match = {
	phase = "Lobby", wave = 0, wavesCleared = 0, coreHP = 30, coreMax = 30,
	difficulty = "Normal", nextAt = os.clock() + Config.LobbySeconds,
	speed = 1, clock = 0, matchId = 0, matchStarted = 0,
	plan = Waves.Plan(1), spawnIndex = 1, waveElapsed = 0,
	speedVotes = {}, skipVotes = {}, replayVotes = {},
	abilities = { Meteor = 0, Freeze = 0 }, result = nil, readyAccelerated = false,
}
local roundPlayers = {}
local effects = {}
local running = true

local function now() return os.clock() end
local function notice(player, text, tone)
	if player.Parent == Players then NoticeRemote:FireClient(player, text, tone or "info") end
end
local function announce(text, tone) NoticeRemote:FireAllClients(text, tone or "info") end
local function emit(effect)
	if #effects < 180 then table.insert(effects, effect) end
end
local function countPlayers()
	local count = 0
	for _ in pairs(roundPlayers) do count += 1 end
	return count
end
local function rule(condition, message)
	if not condition then error({ feedback = message }, 0) end
end
local function validNumber(value)
	return type(value) == "number" and value == value and math.abs(value) < 1e6
end
local function validPad(value)
	return validNumber(value) and value == math.floor(value) and value >= 1 and value <= #Config.Map.Pads
end
local function buildAllowed()
	return match.phase == "Lobby" or match.phase == "Combat" or match.phase == "Intermission"
end

local function updateVotes()
	local count = countPlayers()
	match.speed = Economy.VoteReached(match.speedVotes, count, function(vote) return vote == 2 end) and 2 or 1
end

local function snapshot(player)
	local list = {}
	local readyCount = 0
	for other, session in pairs(roundPlayers) do
		local profile = Profiles:Get(other)
		table.insert(list, {
			id = other.UserId, name = other.DisplayName, level = Config.Level(profile.xp), xp = profile.xp,
			gold = session.gold, ready = session.ready, kills = session.kills, damage = session.damage,
			difficulty = session.difficulty, speedVote = match.speedVotes[other.UserId] or 1,
			skipVote = match.skipVotes[other.UserId] == true, replayVote = match.replayVotes[other.UserId] == true,
			saveStatus = Profiles.Sessions[other] and Profiles.Sessions[other].status or "loading",
		})
		if session.ready then readyCount += 1 end
	end
	table.sort(list, function(a, b) return a.id < b.id end)
	local alive = Enemies:Count()
	local remaining = match.phase == "Combat" and alive + math.max(0, #match.plan.events - match.spawnIndex + 1) or 0
	local previewWave = match.phase == "Intermission" and math.min(20, match.wave + 1) or math.max(1, match.wave)
	local preview = match.phase == "Intermission" and Waves.Plan(previewWave) or match.plan
	local cooldowns = {}
	for kind, readyAt in pairs(match.abilities) do cooldowns[kind] = math.max(0, (readyAt - match.clock) / match.speed) end
	local mine = roundPlayers[player]
	return {
		phase = match.phase, wave = match.wave, wavesCleared = match.wavesCleared, maxWaves = Config.MaxWaves,
		coreHP = match.coreHP, coreMax = match.coreMax, alive = alive, remaining = remaining,
		total = match.plan.total, progress = match.phase == "Combat" and 1 - remaining / math.max(1, match.plan.total) or 0,
		nextIn = math.max(0, match.nextAt - now()), speed = match.speed, difficulty = match.difficulty,
		players = list, gold = mine and mine.gold or 0, readyCount = readyCount,
		cooldowns = cooldowns, previewWave = previewWave, preview = preview.counts,
		result = match.result, matchId = match.matchId, version = Config.Version,
	}
end

local function broadcast()
	for player in pairs(roundPlayers) do StateRemote:FireClient(player, snapshot(player)) end
end

local function resetLobby()
	Enemies:Clear(); Towers:Clear()
	match.phase = "Lobby"; match.wave = 0; match.wavesCleared = 0
	match.coreHP = Config.Difficulties.Normal.coreHP; match.coreMax = match.coreHP
	match.nextAt = now() + Config.LobbySeconds; match.clock = 0; match.speed = 1
	match.plan = Waves.Plan(1); match.spawnIndex = 1; match.waveElapsed = 0
	match.speedVotes = {}; match.skipVotes = {}; match.replayVotes = {}
	match.abilities = { Meteor = 0, Freeze = 0 }; match.result = nil; match.readyAccelerated = false
	for _, session in pairs(roundPlayers) do
		session.gold = Config.StartGold; session.ready = false; session.kills = 0; session.damage = 0
	end
	Map.UpdateCore(match.coreHP, match.coreMax)
	announce("Новый матч. Стройте оборону и голосуйте за готовность.", "info")
	broadcast()
end

local function startWave(wave)
	match.wave = wave; match.phase = "Combat"; match.plan = Waves.Plan(wave)
	match.spawnIndex = 1; match.waveElapsed = 0; match.nextAt = 0; match.skipVotes = {}
	updateVotes()
	if match.plan.boss then announce(wave == 20 and "ФИНАЛ: Разрушитель приближается!" or "Волна " .. wave .. ": замечен босс!", "danger")
	else announce("Волна " .. wave .. " / " .. Config.MaxWaves .. " — " .. Waves.Description(wave), "info") end
	broadcast()
end

local function startMatch()
	if countPlayers() == 0 then match.nextAt = now() + Config.LobbySeconds; return end
	local hardVotes = 0
	for _, session in pairs(roundPlayers) do if session.difficulty == "Hard" then hardVotes += 1 end end
	match.difficulty = hardVotes > countPlayers() / 2 and "Hard" or "Normal"
	match.coreMax = Config.Difficulties[match.difficulty].coreHP; match.coreHP = match.coreMax
	match.matchId += 1; match.matchStarted = now(); match.clock = 0
	match.abilities = { Meteor = 0, Freeze = 0 }; match.replayVotes = {}
	for player, session in pairs(roundPlayers) do
		session.kills = 0; session.damage = 0
		Profiles:Add(player, { matches = 1 })
	end
	Map.UpdateCore(match.coreHP, match.coreMax)
	startWave(1)
end

local function finish(victory)
	if match.phase ~= "Combat" then return end
	match.phase = victory and "Victory" or "Defeat"; match.nextAt = now() + Config.ResultsSeconds
	match.replayVotes = {}; match.result = { victory = victory, wave = match.wave, cleared = match.wavesCleared, duration = now() - match.matchStarted, coreHP = match.coreHP }
	Enemies:Clear()
	local multiplier = Config.Difficulties[match.difficulty].xp
	for player in pairs(roundPlayers) do
		Profiles:Add(player, { xp = math.floor((victory and 300 or 40) * multiplier), wins = victory and 1 or 0 })
		task.spawn(function() Profiles:Save(player, false) end)
	end
	announce(victory and "Рубеж удержан! Все 20 волн отражены." or "Ядро уничтожено. Усильте оборону и попробуйте снова.", victory and "success" or "danger")
	broadcast()
end

Enemies.OnDamage = function(playerId, actual)
	local player = Players:GetPlayerByUserId(playerId)
	local session = player and roundPlayers[player]
	if session then session.damage += actual end
end

Enemies.OnKill = function(enemy, killerId, position)
	local bounty = math.floor(enemy.def.bounty * Config.Difficulties[match.difficulty].reward)
	local shares = Economy.SplitBounty(bounty, enemy.damageByPlayer, killerId)
	for userId, amount in pairs(shares) do
		local player = Players:GetPlayerByUserId(userId)
		local session = player and roundPlayers[player]
		if session then session.gold += amount end
	end
	if killerId then
		local player = Players:GetPlayerByUserId(killerId)
		local session = player and roundPlayers[player]
		if session then session.kills += 1 end
		if player then Profiles:Add(player, { kills = 1 }) end
	end
	emit({ kind = "Defeat", to = position, color = enemy.def.color, boss = enemy.def.boss })
end

local function clearWave()
	match.wavesCleared = match.wave
	local multiplier = Config.Difficulties[match.difficulty].xp
	for player, session in pairs(roundPlayers) do
		local reward = Economy.WaveReward(match.wave, session.gold, match.difficulty)
		session.gold += reward
		Profiles:Add(player, { xp = math.floor((20 + match.wave * 3) * multiplier) })
		Profiles:Best(player, match.wavesCleared)
		notice(player, "Волна отражена  +" .. reward .. " золота", "success")
	end
	if match.wave >= Config.MaxWaves then
		finish(true)
	else
		match.phase = "Intermission"; match.nextAt = now() + Config.IntermissionSeconds; match.skipVotes = {}
		broadcast()
	end
end

local function simulationStep(dt)
	if match.phase == "Combat" then
		match.clock += dt
		match.waveElapsed += dt
		while match.spawnIndex <= #match.plan.events and match.plan.events[match.spawnIndex].at <= match.waveElapsed do
			local event = match.plan.events[match.spawnIndex]
			Enemies:Spawn(event.kind, match.wave, countPlayers(), match.difficulty, event.final)
			match.spawnIndex += 1
		end
		local leaked = Enemies:Update(dt, match.clock)
		for _, enemy in ipairs(leaked) do
			match.coreHP = math.max(0, match.coreHP - enemy.def.coreDamage)
			emit({ kind = "CoreHit", to = Map.CorePosition + Vector3.new(0, 4, 0), color = Color3.fromRGB(255, 114, 102) })
		end
		if #leaked > 0 then Map.UpdateCore(match.coreHP, match.coreMax) end
		if match.coreHP <= 0 then finish(false); return end
		Towers:Update(dt, Enemies, emit, match.clock)
		if match.spawnIndex > #match.plan.events and Enemies:Count() == 0 then clearWave() end
	elseif match.phase == "Intermission" then
		match.clock += dt
	end
end

local function ownedTower(session, padId)
	rule(validPad(padId), "Выберите площадку на карте.")
	local tower = Towers.ByPad[padId]
	rule(tower ~= nil, "На этой площадке пока нет башни.")
	rule(tower.ownerId == session.player.UserId, "Управлять этой башней может только её владелец.")
	return tower
end

local function dispatch(player, session, kind, payload)
	if kind == "Hello" then
		StateRemote:FireClient(player, snapshot(player)); return
	elseif kind == "Ready" then
		rule(match.phase == "Lobby", "Матч уже начался.")
		rule(type(payload.ready) == "boolean", "Некорректный голос.")
		session.ready = payload.ready
	elseif kind == "Difficulty" then
		rule(match.phase == "Lobby", "Сложность выбирается до начала матча.")
		rule(payload.value == "Normal" or payload.value == "Hard", "Неизвестная сложность.")
		session.difficulty = payload.value; session.ready = false
	elseif kind == "Build" then
		rule(buildAllowed(), "Дождитесь следующего матча.")
		rule(validPad(payload.padId), "Некорректная площадка.")
		rule(type(payload.towerType) == "string" and Config.Towers[payload.towerType] ~= nil, "Выберите башню из списка.")
		rule(not Towers.ByPad[payload.padId], "Площадка уже занята.")
		local cost = Config.Towers[payload.towerType].cost
		rule(session.gold >= cost, "Недостаточно золота.")
		session.gold -= cost
		Towers:Build(payload.padId, payload.towerType, player)
		emit({ kind = "Build", to = Map.Pads[payload.padId].position + Vector3.new(0, 1, 0), color = Config.Towers[payload.towerType].color })
	elseif kind == "Upgrade" then
		rule(buildAllowed(), "Улучшения доступны во время матча.")
		local tower = ownedTower(session, payload.padId)
		rule(tower.level < 4, "Достигнут максимальный уровень.")
		local cost = Economy.UpgradeCost(tower.kind, tower.level)
		rule(session.gold >= cost, "Недостаточно золота для улучшения.")
		session.gold -= cost; tower.invested += cost; Towers:Upgrade(tower.padId)
		emit({ kind = "Build", to = tower.position + Vector3.new(0, 2, 0), color = Config.Towers[tower.kind].color })
	elseif kind == "Sell" then
		rule(buildAllowed(), "Продажа доступна во время матча.")
		local tower = ownedTower(session, payload.padId)
		local refund = Economy.Refund(tower.invested)
		session.gold += refund; Towers:Remove(tower.padId)
		notice(player, "Башня продана  +" .. refund .. " золота", "info")
	elseif kind == "Priority" then
		local tower = ownedTower(session, payload.padId)
		rule(table.find(Config.Priorities, payload.value) ~= nil, "Неизвестная цель.")
		tower.priority = payload.value; Map.Pads[tower.padId].part:SetAttribute("Priority", payload.value)
	elseif kind == "Speed" then
		rule(match.phase == "Combat" or match.phase == "Intermission", "Скорость доступна во время матча.")
		rule(payload.value == 1 or payload.value == 2, "Некорректная скорость.")
		match.speedVotes[player.UserId] = payload.value; updateVotes()
	elseif kind == "Skip" then
		rule(match.phase == "Intermission", "Сейчас нельзя пропустить подготовку.")
		match.skipVotes[player.UserId] = true
		if Economy.VoteReached(match.skipVotes, countPlayers(), function(vote) return vote end) then match.nextAt = math.min(match.nextAt, now() + 2) end
	elseif kind == "Replay" then
		rule(match.phase == "Victory" or match.phase == "Defeat", "Матч ещё не завершён.")
		match.replayVotes[player.UserId] = true
		if Economy.VoteReached(match.replayVotes, countPlayers(), function(vote) return vote end) then resetLobby(); return end
	elseif kind == "Ability" then
		rule(match.phase == "Combat", "Способности доступны только во время волны.")
		local def = Config.Abilities[payload.ability]
		rule(def ~= nil, "Неизвестная способность.")
		rule(match.clock >= match.abilities[payload.ability], "Способность ещё восстанавливается.")
		if payload.ability == "Meteor" then
			local target = payload.target
			rule(typeof(target) == "Vector3" and validNumber(target.X) and validNumber(target.Y) and validNumber(target.Z), "Выберите точку на карте.")
			rule(math.abs(target.X) <= 88 and math.abs(target.Z) <= 58, "Цель вне карты.")
			match.abilities.Meteor = match.clock + def.cooldown
			local position = Vector3.new(target.X, 0.5, target.Z)
			emit({ kind = "Meteor", to = position, color = def.color, radius = def.radius })
			for _, enemy in ipairs(Enemies:InRadius(position, def.radius, true)) do
				Enemies:Damage(enemy, def.damage + match.wave * def.waveDamage, player.UserId)
			end
		else
			match.abilities.Freeze = match.clock + def.cooldown
			for _, enemy in pairs(Enemies.Active) do Enemies:Slow(enemy, def.slow, def.duration, match.clock) end
			emit({ kind = "Freeze", to = Vector3.zero, color = def.color, radius = 95 })
		end
		announce(player.DisplayName .. " применяет «" .. def.name .. "»", "ability")
	else
		rule(false, "Неизвестное действие.")
	end
	broadcast()
end

ActionRemote.OnServerEvent:Connect(function(player, message)
	local session = roundPlayers[player]
	if not session or type(message) ~= "table" or type(message.kind) ~= "string" or #message.kind > 24 then return end
	local time = now()
	session.tokens = math.min(12, session.tokens + math.max(0, time - session.refill) / Config.ActionInterval)
	session.refill = time
	if session.tokens < 1 then return end
	session.tokens -= 1
	local ok, problem = pcall(dispatch, player, session, message.kind, message)
	if not ok then
		if type(problem) == "table" and problem.feedback then notice(player, problem.feedback, "danger")
		else warn("[Action] ", message.kind, ": ", problem) end
	end
end)

local function setupCharacter(character)
	local root = character:WaitForChild("HumanoidRootPart", 8)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root then root.Anchored = true end
	if humanoid then
		humanoid.WalkSpeed = 0; humanoid.JumpPower = 0; humanoid.JumpHeight = 0
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.MaxHealth = 100; humanoid.Health = 100
	end
end

local function playerAdded(player)
	if #Players:GetPlayers() > Config.MaxPlayers then
		player:Kick("РУБЕЖ рассчитан на команду до 4 игроков. Выберите другой сервер.")
		return
	end
	task.spawn(function()
		local profile = Profiles:Load(player)
		if player.Parent ~= Players or profile.status == "locked" then return end
		roundPlayers[player] = {
			player = player, gold = match.phase == "Lobby" and Config.StartGold or Economy.CatchupGold(match.wavesCleared, countPlayers() + 1),
			ready = false, difficulty = "Normal", kills = 0, damage = 0,
			tokens = 12, refill = now(),
		}
		player.CharacterAdded:Connect(setupCharacter)
		if player.Character then task.spawn(setupCharacter, player.Character) end
		if profile.status == "unavailable" then
			notice(player, "Хранилище недоступно: можно играть, но прогресс этого сеанса не сохранится.", "danger")
		elseif profile.status == "local" then
			notice(player, "Локальный тест: прогресс сохранится только после публикации и включения DataStore.", "info")
		end
		broadcast()
	end)
end

Players.PlayerAdded:Connect(playerAdded)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(playerAdded, player) end
Players.PlayerRemoving:Connect(function(player)
	roundPlayers[player] = nil
	match.speedVotes[player.UserId] = nil; match.skipVotes[player.UserId] = nil; match.replayVotes[player.UserId] = nil
	updateVotes()
	task.spawn(function() Profiles:Save(player, true) end)
end)

local accumulator, stateAccumulator = 0, 0
RunService.Heartbeat:Connect(function(frameDT)
	if not running then return end
	accumulator += math.min(frameDT, 0.25)
	local step = 1 / Config.SimulationRate
	local iterations = 0
	while accumulator >= step and iterations < 8 do
		accumulator -= step; iterations += 1
		updateVotes()
		if match.phase == "Lobby" then
			local count = countPlayers()
			local allReady = count > 0
			for _, session in pairs(roundPlayers) do if not session.ready then allReady = false end end
			if count == 0 then
				match.nextAt = now() + Config.LobbySeconds; match.readyAccelerated = false
			elseif allReady then
				match.nextAt = math.min(match.nextAt, now() + Config.ReadySeconds); match.readyAccelerated = true
			elseif match.readyAccelerated then
				match.nextAt = math.max(match.nextAt, now() + 12); match.readyAccelerated = false
			end
			if count > 0 and now() >= match.nextAt then startMatch() end
		elseif match.phase == "Combat" or match.phase == "Intermission" then
			simulationStep(step * match.speed)
			if match.phase == "Intermission" and now() >= match.nextAt then startWave(match.wave + 1) end
		elseif (match.phase == "Victory" or match.phase == "Defeat") and now() >= match.nextAt then
			resetLobby()
		end
	end
	if #effects > 0 then
		EffectsRemote:FireAllClients(effects)
		effects = {}
	end
	stateAccumulator += frameDT
	if stateAccumulator >= 1 / Config.StateRate then stateAccumulator = 0; broadcast() end
end)

game:BindToClose(function()
	running = false
	Profiles:Shutdown()
end)

Map.UpdateCore(match.coreHP, match.coreMax)
print("[РУБЕЖ] Server ready — 4-player co-op / 20 waves / v" .. Config.Version)
