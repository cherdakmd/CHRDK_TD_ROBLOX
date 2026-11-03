local Config = require(script.Parent.Config)
local Waves = {}

-- Deterministic plans make tests and the wave preview agree with the server.
function Waves.Plan(wave)
	assert(wave >= 1 and wave <= Config.MaxWaves and wave == math.floor(wave), "Invalid wave")
	local events = {}
	local time = 0.7
	local count = 6 + wave * 2
	local gap = math.max(0.42, 0.95 - wave * 0.018)
	for index = 1, count do
		local kind = "Scout"
		if wave >= 2 and index % 4 == 0 then kind = "Runner" end
		if wave >= 3 and index % 6 == 0 then kind = "Brute" end
		if wave >= 6 and index % 5 == 0 then kind = "Shield" end
		if wave >= 8 and index % 7 == 0 then kind = "Wisp" end
		if wave >= 12 and index % 11 == 0 then kind = "Wisp" end
		table.insert(events, { at = time, kind = kind })
		time += gap
		if index % 8 == 0 then time += 1.5 end
	end
	if wave % 5 == 0 then
		time += 2
		table.insert(events, { at = time, kind = "Boss", final = wave == Config.MaxWaves })
	end
	local counts = {}
	for _, event in ipairs(events) do
		counts[event.kind] = (counts[event.kind] or 0) + 1
	end
	return { events = events, total = #events, counts = counts, duration = time, boss = wave % 5 == 0 }
end

function Waves.Description(wave)
	if wave == 20 then return "Финальный босс + эскорт" end
	if wave % 5 == 0 then return "Босс + эскорт" end
	if wave >= 8 then return "Пехота, броня и воздух" end
	if wave >= 6 then return "Броненосцы подходят" end
	if wave >= 3 then return "Громилы в строю" end
	if wave >= 2 then return "Быстрые бегуны" end
	return "Разведчики"
end

return Waves
