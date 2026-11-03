local Config = require(script.Parent.Config)
local Economy = {}

function Economy.UpgradeCost(towerType, level)
	local def = Config.Towers[towerType]
	if not def or level < 1 or level >= 4 then return nil end
	return def.upgradeCosts[level]
end

function Economy.Refund(invested)
	return math.floor(math.max(0, invested) * Config.SellRefund)
end

function Economy.WaveReward(wave, gold, difficulty)
	local multiplier = Config.Difficulties[difficulty].reward
	return math.floor((80 + wave * 12 + math.min(90, gold * 0.03)) * multiplier)
end

-- Split the exact bounty, never duplicate it. Remainder goes to the final hit.
function Economy.SplitBounty(bounty, damageByPlayer, killerId)
	local total = 0
	for _, damage in pairs(damageByPlayer) do total += math.max(0, damage) end
	local result, assigned = {}, 0
	if total <= 0 then
		if killerId then result[killerId] = bounty end
		return result
	end
	for playerId, damage in pairs(damageByPlayer) do
		local share = math.floor(bounty * math.max(0, damage) / total)
		if share > 0 then result[playerId] = share end
		assigned += share
	end
	if killerId and bounty > assigned then
		result[killerId] = (result[killerId] or 0) + bounty - assigned
	end
	return result
end

function Economy.VoteReached(votes, playerCount, predicate)
	local count = 0
	for _, vote in pairs(votes) do
		if predicate(vote) then count += 1 end
	end
	return playerCount > 0 and count > playerCount / 2
end

function Economy.CatchupGold(wavesCleared, playerCount)
	return Config.StartGold + math.max(0, wavesCleared) * 45 + math.max(0, playerCount - 1) * 35
end

return Economy
