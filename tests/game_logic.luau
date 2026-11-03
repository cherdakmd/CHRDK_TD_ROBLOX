local Config = Require(Shared.Config)
local Path = Require(Shared.Path)
local Waves = Require(Shared.Waves)
local Economy = Require(Shared.Economy)
local Format = Require(Shared.Format)
local passed = 0
local function check(condition, message)
	passed += 1
	if not condition then error("FAIL: " .. message, 2) end
end

check(Config.MaxPlayers == 4, "four-player limit")
check(Config.MaxWaves == 20, "twenty waves")
check(#Config.TowerOrder == 4, "four tower classes")
check(#Config.Map.Pads == Config.MaxTowers, "pad count matches tower limit")

local seen = {}
for index, pad in ipairs(Config.Map.Pads) do
	local key = pad[1] .. ":" .. pad[2]
	check(not seen[key], "duplicate pad " .. index)
	seen[key] = true
	local x, z = pad[1] * Config.Map.Scale, pad[2] * Config.Map.Scale
	check(math.abs(x) < 87 and math.abs(z) < 56, "pad inside island " .. index)
	check(Path.DistanceToRoad(x, z) > Config.Map.RoadWidth / 2 + Config.Map.PadRadius - 0.5, "pad overlaps road " .. index)
	for other = index + 1, #Config.Map.Pads do
		local distance = math.sqrt((x - Config.Map.Pads[other][1] * Config.Map.Scale)^2 + ( z - Config.Map.Pads[other][2] * Config.Map.Scale)^2)
		check(distance > Config.Map.PadRadius * 2, "pads overlap " .. index .. "/" .. other)
	end
end

check(Path.Length > 250, "path has meaningful length")
local x, z = Path.Sample(0)
check(math.abs(x - Path.Points[1].x) < 1e-6 and math.abs(z - Path.Points[1].z) < 1e-6, "path starts at portal")
x, z = Path.Sample(Path.Length)
check(math.abs(x - Path.Points[#Path.Points].x) < 1e-6 and math.abs(z - Path.Points[#Path.Points].z) < 1e-6, "path ends at core")
for _, segment in ipairs(Path.Segments) do
	local ax, az = Path.Sample(segment.start)
	local bx, bz = Path.Sample(segment.start + segment.length)
	check(math.sqrt((ax - segment.a.x)^2 + ( az - segment.a.z)^2) < 1e-6, "segment start continuity")
	check(math.sqrt((bx - segment.b.x)^2 + ( bz - segment.b.z)^2) < 1e-6, "segment end continuity")
end

local previousTotal = 0
for wave = 1, Config.MaxWaves do
	local plan = Waves.Plan(wave)
	check(plan.total == #plan.events and plan.total > 0, "wave count " .. wave)
	check(plan.total > previousTotal, "wave size increases " .. wave)
	previousTotal = plan.total
	local previousAt, counted = -1, 0
	for _, event in ipairs(plan.events) do
		check(event.at > previousAt, "spawn order " .. wave)
		check(Config.Enemies[event.kind] ~= nil, "known enemy " .. wave)
		previousAt = event.at
		counted += 1
	end
	check(counted == plan.total, "counted events " .. wave)
	check(plan.boss == (wave % 5 == 0), "boss cadence " .. wave)
	local sum = 0
	for _, count in pairs(plan.counts) do sum += count end
	check(sum == plan.total, "preview counts agree " .. wave)
	if wave < 8 then check(plan.counts.Wisp == nil, "no early flying enemies " .. wave) end
end
check(Waves.Plan(20).counts.Boss == 1, "one final boss")

for _, kind in ipairs(Config.TowerOrder) do
	local previousDamage, previousInterval = 0, math.huge
	for level = 1, 4 do
		local stats = Config.Stats(kind, level)
		check(stats.damage > previousDamage, "damage upgrade " .. kind .. level)
		check(stats.interval < previousInterval, "cooldown upgrade " .. kind .. level)
		check(stats.range >= Config.Towers[kind].range, "range upgrade " .. kind .. level)
		previousDamage, previousInterval = stats.damage, stats.interval
		if level < 4 then check(Economy.UpgradeCost(kind, level) > 0, "upgrade price " .. kind .. level)
		else check(Economy.UpgradeCost(kind, level) == nil, "max level " .. kind) end
	end
	check(Config.Stats(kind, 5) == nil, "invalid level rejected " .. kind)
end
check(Config.Towers.Cannon.air == false, "cannon cannot hit air")
check(Config.Towers.Sentry.air and Config.Towers.Frost.air and Config.Towers.Tesla.air, "anti-air coverage")

check(Economy.Refund(1000) == 700, "70 percent refund")
check(Economy.Refund(-50) == 0, "no negative refund")
check(Economy.WaveReward(10, 0, "Normal") == 200, "base wave reward")
check(Economy.WaveReward(10, 10000, "Normal") == 290, "interest cap")
check(Economy.WaveReward(10, 0, "Hard") > Economy.WaveReward(10, 0, "Normal"), "hard reward bonus")
local shares = Economy.SplitBounty(101, { [1] = 10, [2] = 30 }, 2)
local total = 0
for _, amount in pairs(shares) do check(amount >= 0, "nonnegative bounty"); total += amount end
check(total == 101, "bounty conserved with remainder")
check(Economy.SplitBounty(50, {}, 7)[7] == 50, "ability/last-hit fallback")
check(next(Economy.SplitBounty(0, { [1] = 10 }, 1)) == nil, "zero bounty")

check(Economy.VoteReached({ true }, 1, function(v) return v end), "solo vote")
check(not Economy.VoteReached({ true }, 2, function(v) return v end), "half is not majority")
check(Economy.VoteReached({ true, true }, 3, function(v) return v end), "two of three")
check(not Economy.VoteReached({ true, true }, 4, function(v) return v end), "two of four is tie")
check(Economy.VoteReached({ true, true, true }, 4, function(v) return v end), "three of four")
check(not Economy.VoteReached({}, 0, function(v) return v end), "empty server")
check(Economy.CatchupGold(10, 4) > Config.StartGold, "late join catch-up")
check(Config.HealthScale(20) > Config.HealthScale(1), "health scaling")
check(Config.PartyHealthScale(4) > Config.PartyHealthScale(1), "party scaling")
check(Config.Level(0) == 1 and Config.Level(250) == 2, "account levels")
check(Format.Number(1234567) == "1 234 567", "number formatting")
check(Format.Number(0) == "0", "zero formatting")
check(Format.Time(65) == "01:05", "time formatting")
check(Format.Roman(4) == "IV", "roman levels")

print(string.format("game_logic: %d assertions passed", passed))
