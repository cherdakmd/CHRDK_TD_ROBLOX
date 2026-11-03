-- Central balance sheet. All prices are in-match gold, not Robux.
local Config = {}

Config.Version = "0.1.0"
Config.Title = "РУБЕЖ"
Config.MaxPlayers = 4
Config.MaxWaves = 20
Config.StartGold = 600
Config.LobbySeconds = 45
Config.ReadySeconds = 6
Config.IntermissionSeconds = 22
Config.ResultsSeconds = 30
Config.SimulationRate = 20
Config.StateRate = 5
Config.ActionInterval = 0.12
Config.SellRefund = 0.70
Config.MaxTowers = 18

Config.Difficulties = {
	Normal = { label = "Обычный", coreHP = 30, health = 1, reward = 1, xp = 1 },
	Hard = { label = "Испытание", coreHP = 20, health = 1.35, reward = 1.15, xp = 1.5 },
}

Config.Map = {
	Scale = 0.85,
	Size = Vector3.new(174, 4, 112),
	Center = Vector3.new(0, 0, -3),
	RoadWidth = 8,
	PadRadius = 3.6,
	-- Orthogonal path, in unscaled map coordinates.
	Points = {
		{ -84, -44 }, { -54, -44 }, { -54, 8 }, { -20, 8 },
		{ -20, -34 }, { 20, -34 }, { 20, 32 }, { 58, 32 },
		{ 58, -8 }, { 82, -8 },
	},
	Pads = {
		{ -70, -29 }, { -41, -31 }, { -69, -8 }, { -39, -7 },
		{ -38, 23 }, { -6, 22 }, { -5, -8 }, { -5, -48 },
		{ 6, -20 }, { 35, -21 }, { 6, 2 }, { 35, 13 },
		{ 42, 46 }, { 72, 18 }, { 44, 17 }, { 73, -24 },
		{ 84, 8 }, { -82, -57 },
	},
}

Config.TowerOrder = { "Sentry", "Cannon", "Frost", "Tesla" }
Config.Towers = {
	Sentry = {
		name = "Страж", short = "СТРАЖ", role = "Скорострельная",
		description = "Надёжная основа обороны. Быстро поражает наземные и воздушные цели.",
		color = Color3.fromRGB(111, 224, 164), cost = 160,
		damage = 11, interval = 0.38, range = 24, air = true,
		upgradeCosts = { 130, 250, 430 },
		damageScale = { 1, 1.65, 2.7, 4.3 },
		rangeGain = 2, cooldownScale = { 1, 0.92, 0.84, 0.74 },
	},
	Cannon = {
		name = "Мортира", short = "МОРТИРА", role = "Урон по площади",
		description = "Взрыв радиусом 7 studs. Против групп наземных врагов. Не атакует воздух.",
		color = Color3.fromRGB(255, 176, 89), cost = 280,
		damage = 48, interval = 1.8, range = 31, air = false,
		splash = 7, upgradeCosts = { 210, 390, 650 },
		damageScale = { 1, 1.65, 2.7, 4.2 },
		rangeGain = 2, cooldownScale = { 1, 0.94, 0.88, 0.8 },
	},
	Frost = {
		name = "Криомант", short = "КРИОМАНТ", role = "Замедление",
		description = "Замедляет цель на 48% на 1,8 с. Работает по воздуху. Боссы сопротивляются.",
		color = Color3.fromRGB(107, 218, 255), cost = 240,
		damage = 8, interval = 0.75, range = 23, air = true,
		slow = 0.52, slowTime = 1.8, upgradeCosts = { 170, 310, 520 },
		damageScale = { 1, 1.7, 2.8, 4.4 },
		rangeGain = 2, cooldownScale = { 1, 0.94, 0.88, 0.8 },
	},
	Tesla = {
		name = "Тесла", short = "ТЕСЛА", role = "Цепная молния",
		description = "Молния перескакивает на 3 соседей. Каждый следующий удар слабее на 22%.",
		color = Color3.fromRGB(184, 157, 255), cost = 360,
		damage = 30, interval = 1.0, range = 24, air = true,
		chains = 3, chainRange = 10, upgradeCosts = { 260, 460, 760 },
		damageScale = { 1, 1.65, 2.75, 4.4 },
		rangeGain = 1.5, cooldownScale = { 1, 0.93, 0.86, 0.76 },
	},
}

Config.Enemies = {
	Scout = { name = "Разведчик", hp = 52, speed = 8.5, bounty = 10, coreDamage = 1, armor = 0, color = Color3.fromRGB(236, 112, 106), size = 1 },
	Runner = { name = "Бегун", hp = 38, speed = 14, bounty = 9, coreDamage = 1, armor = 0, color = Color3.fromRGB(255, 199, 93), size = 0.8 },
	Brute = { name = "Громила", hp = 185, speed = 5.6, bounty = 22, coreDamage = 3, armor = 2, color = Color3.fromRGB(179, 100, 129), size = 1.45 },
	Shield = { name = "Броненосец", hp = 125, speed = 7.2, bounty = 17, coreDamage = 2, armor = 6, color = Color3.fromRGB(139, 158, 181), size = 1.15 },
	Wisp = { name = "Призрак", hp = 78, speed = 9.5, bounty = 15, coreDamage = 1, armor = 0, flying = true, color = Color3.fromRGB(172, 151, 244), size = 0.95 },
	Boss = { name = "Разрушитель", hp = 1450, speed = 4.7, bounty = 180, coreDamage = 10, armor = 5, boss = true, slowResist = 0.5, color = Color3.fromRGB(226, 76, 93), size = 2.35 },
}

Config.Abilities = {
	Meteor = { name = "Метеор", cooldown = 45, radius = 15, damage = 180, waveDamage = 18, color = Color3.fromRGB(255, 155, 82), key = "Q" },
	Freeze = { name = "Стужа", cooldown = 40, duration = 5, slow = 0.25, color = Color3.fromRGB(118, 224, 255), key = "E" },
}

Config.Priorities = { "First", "Strong", "Near" }
Config.PriorityLabels = { First = "Первый", Strong = "Сильный", Near = "Ближний" }

function Config.Stats(towerType, level)
	local def = Config.Towers[towerType]
	if not def or level < 1 or level > 4 then return nil end
	return {
		damage = def.damage * def.damageScale[level],
		interval = def.interval * def.cooldownScale[level],
		range = def.range + def.rangeGain * (level - 1),
		splash = def.splash and def.splash + (level - 1) * 0.6 or nil,
		chains = def.chains and def.chains + math.floor((level - 1) / 2) or nil,
		slowTime = def.slowTime and def.slowTime + (level - 1) * 0.25 or nil,
	}
end

function Config.HealthScale(wave)
	return 1 + (wave - 1) * 0.14 + (wave - 1) ^ 2 * 0.006
end

function Config.PartyHealthScale(playerCount)
	return 1 + math.max(0, playerCount - 1) * 0.42
end

function Config.Level(xp)
	return 1 + math.floor(math.max(0, xp) / 250)
end

return Config
