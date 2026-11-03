-- Exercises the real server scripts against the API double, including remotes and economy.
local Config = Require(Shared.Config)
local passed = 0
local function check(condition, message)
	passed += 1
	if not condition then error("FAIL: " .. message, 2) end
end

LoadScript("src/server/Main.server.luau")
local remotes = ReplicatedStorage:WaitForChild("TD_Remotes")
local mapRoot = workspace:WaitForChild("TD_Map")
local pads = mapRoot:WaitForChild("Pads")
local towersFolder = mapRoot:WaitForChild("Towers")
local enemiesFolder = mapRoot:WaitForChild("Enemies")
check(remotes and pads and towersFolder and enemiesFolder, "server creates replication hierarchy")

local player1 = Players.LocalPlayer
local latest, notices = nil, {}
remotes.State.OnClientEvent:Connect(function(state) latest = state end)
remotes.Notice.OnClientEvent:Connect(function(message) table.insert(notices, message) end)
local function refresh() FireAction(player1, "Hello"); return latest end
local function state() return refresh() end

check(state().phase == "Lobby", "starts in lobby")
check(state().gold == Config.StartGold, "starting gold")
local player2 = AddTestPlayer(2, "Bob")
local player3 = AddTestPlayer(3, "Cara")
local player4 = AddTestPlayer(4, "Dana")
check(#state().players == 4, "four players admitted")
local fifth = AddTestPlayer(5, "Eve")
check(fifth.Kicked ~= nil and #Players:GetPlayers() == 4, "fifth player rejected")

local function pad(id) return pads:FindFirstChild(string.format("Pad_%02d", id)) end
FireAction(player1, "Build", { padId = 1, towerType = "Sentry" })
check(state().gold == 440 and pad(1):GetAttribute("TowerType") == "Sentry", "build debits gold and occupies pad")
FireAction(player1, "Build", { padId = 1, towerType = "Sentry" })
check(state().gold == 440, "occupied pad cannot double-charge")
FireAction(player1, "Upgrade", { padId = 1 })
check(state().gold == 310 and pad(1):GetAttribute("Level") == 2, "upgrade debits and levels")
FireAction(player1, "Priority", { padId = 1, value = "Strong" })
check(pad(1):GetAttribute("Priority") == "Strong", "target priority replicated")
FireAction(player1, "Sell", { padId = 1 })
check(state().gold == 513 and pad(1):GetAttribute("TowerType") == "", "sell refunds 70 percent")
FireAction(player2, "Build", { padId = 2, towerType = "Cannon" })
local before = state().gold
FireAction(player1, "Upgrade", { padId = 2 })
check(state().gold == before and pad(2):GetAttribute("Level") == 1, "cannot upgrade another player's tower")
FireAction(player1, "Build", { padId = 1, towerType = "Sentry" })
FireAction(player1, "Build", { padId = 4, towerType = "Frost" })

-- Invalid remote payloads must be rejected without taking money or crashing.
local gold = state().gold
FireAction(player1, "Build", { padId = 999, towerType = "Sentry" })
FireAction(player1, "Build", { padId = 3, towerType = "Fake" })
FireAction(player1, "Build", { padId = 3.5, towerType = "Sentry" })
FireAction(player1, "Priority", { padId = 1, value = "Cheat" })
FireAction(player1, "Ability", { ability = "Meteor", target = Vector3.new(999, 0, 0) })
check(state().gold == gold and #notices > 0, "invalid actions rejected with feedback")

Tick(2) -- refill action tokens after the rapid security probes
for _, player in ipairs(Players:GetPlayers()) do FireAction(player, "Ready", { ready = true }) end
Tick(6.2)
check(state().phase == "Combat" and state().wave == 1, "unanimous ready starts wave")
FireAction(player1, "Speed", { value = 2 })
check(state().speed == 1, "one of four cannot force 2x")
FireAction(player2, "Speed", { value = 2 })
check(state().speed == 1, "two of four is a tie")
FireAction(player3, "Speed", { value = 2 })
check(state().speed == 2, "three of four enables 2x")
FireAction(player1, "Ability", { ability = "Freeze" })
check(state().cooldowns.Freeze > 0, "shared freeze goes on cooldown")
Tick(3)
check(#enemiesFolder:GetChildren() > 0, "enemies spawn and replicate")
local combatGold = state().gold
local elapsed = 0
while state().phase == "Combat" and elapsed < 150 do Tick(1); elapsed += 1 end
check(state().phase == "Intermission" and state().wavesCleared == 1, "wave one can be cleared")
check(state().gold > combatGold, "kills and wave clear pay gold")
check(Require(ServerScriptService.Server.Services.Profiles):Get(player1).xp > 0, "wave clear grants account XP")
FireAction(player1, "Skip", {})
FireAction(player2, "Skip", {})
FireAction(player3, "Skip", {})
check(state().nextIn <= 2.1, "majority skip shortens intermission")
Tick(2.2)
check(state().wave == 2 and state().phase == "Combat", "next wave starts")

player4.Parent = nil
Players.PlayerRemoving:Fire(player4)
check(#state().players == 3, "leaving player removed from team")

-- Remove the defense and let leaks exercise defeat + replay reset.
FireAction(player1, "Sell", { padId = 1 })
FireAction(player1, "Sell", { padId = 4 })
FireAction(player2, "Sell", { padId = 2 })
elapsed = 0
while state().phase ~= "Defeat" and elapsed < 500 do Tick(1); elapsed += 1 end
check(state().phase == "Defeat" and state().coreHP == 0, "leaks destroy the core and end the match")
check(state().result ~= nil, "result snapshot is present")
FireAction(player1, "Replay", {})
FireAction(player2, "Replay", {})
check(state().phase == "Lobby" and state().wave == 0, "replay majority returns to lobby")
check(#towersFolder:GetChildren() == 0 and state().gold == Config.StartGold, "replay resets towers and gold")
check(Require(ServerScriptService.Server.Services.Profiles):Get(player1).matches >= 1, "match count persisted in session")

for _ = 1, 30 do FireAction(player1, "Hello") end
Tick(2)
check(state().phase == "Lobby", "rate limiter does not break the server")
print(string.format("server_integration: %d assertions passed", passed))
