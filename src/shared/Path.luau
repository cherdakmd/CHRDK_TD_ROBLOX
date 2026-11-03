-- Shared by map construction, server movement and client minimap.
local Config = require(script.Parent.Config)
local Path = {}
Path.Points = {}
Path.Segments = {}
Path.Length = 0

for _, point in ipairs(Config.Map.Points) do
	table.insert(Path.Points, { x = point[1] * Config.Map.Scale, z = point[2] * Config.Map.Scale })
end
for index = 1, #Path.Points - 1 do
	local a, b = Path.Points[index], Path.Points[index + 1]
	local length = math.abs(b.x - a.x) + math.abs(b.z - a.z)
	table.insert(Path.Segments, { a = a, b = b, start = Path.Length, length = length })
	Path.Length += length
end

function Path.Sample(distance)
	distance = math.clamp(distance, 0, Path.Length)
	for _, segment in ipairs(Path.Segments) do
		if distance <= segment.start + segment.length then
			local alpha = (distance - segment.start) / segment.length
			local dx, dz = segment.b.x - segment.a.x, segment.b.z - segment.a.z
			return segment.a.x + dx * alpha, segment.a.z + dz * alpha, math.atan2(dx, dz)
		end
	end
	local last = Path.Points[#Path.Points]
	return last.x, last.z, 0
end

function Path.DistanceToRoad(x, z)
	local nearest = math.huge
	for _, segment in ipairs(Path.Segments) do
		local px = math.clamp(x, math.min(segment.a.x, segment.b.x), math.max(segment.a.x, segment.b.x))
		local pz = math.clamp(z, math.min(segment.a.z, segment.b.z), math.max(segment.a.z, segment.b.z))
		nearest = math.min(nearest, math.sqrt((x - px)^2 + ( z - pz)^2))
	end
	return nearest
end

return Path
