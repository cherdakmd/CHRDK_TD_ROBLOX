local Format = {}

function Format.Number(value)
	local text = tostring(math.floor(value or 0))
	local result = text
	while true do
		local nextText = string.gsub(result, "^(-?%d+)(%d%d%d)", "%1 %2")
		result = nextText
		if nextText == text then break end
		text = nextText
	end
	return result
end

function Format.Time(seconds)
	seconds = math.max(0, math.ceil(seconds or 0))
	return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

function Format.Roman(level)
	return ({ "I", "II", "III", "IV" })[level] or "I"
end

return Format
