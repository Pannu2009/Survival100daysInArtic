local Config = require(script.Parent:WaitForChild("Config"))
local Seed = {}
Seed.__index = Seed
local function hashString(str)
	local h = 5381
	for i = 1, #str do
		h = (h * 33 + string.byte(str, i)) % 4294967296
	end
	return h
end
local function xorshift32(x)
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	return x
end
function Seed.Normalize(str)
	return tostring(str or ""):upper():gsub("[^A-Z]", "")
end
function Seed.IsValid(str)
	local length = #Seed.Normalize(str)
	return length >= Config.World.MinSeedLength and length <= Config.World.MaxSeedLength
end
function Seed.new(seedString)
	local normalized = Seed.Normalize(seedString)
	local self = setmetatable({}, Seed)
	self.String = normalized
	self._state = hashString(normalized)
	if self._state == 0 then
		self._state = 2654435769
	end
	return self
end
function Seed:Next()
	self._state = xorshift32(self._state)
	if self._state == 0 then
		self._state = 2654435769
	end
	return self._state / 4294967296
end
function Seed:NextNumber(min, max)
	return min + self:Next() * (max - min)
end
function Seed:NextInteger(min, max)
	return math.floor(self:Next() * (max - min + 1)) + min
end
function Seed:Chance(probability)
	return self:Next() < probability
end
function Seed:Fork(label)
	local forked = setmetatable({}, Seed)
	forked.String = self.String
	forked._state = hashString(self.String .. ":" .. tostring(label))
	if forked._state == 0 then
		forked._state = 2654435769
	end
	return forked
end
return Seed
