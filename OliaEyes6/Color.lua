local Jungle, jungle = ...

local Color = {};
Color.__index = Color;
local rgbCache = {}

function Color:new()
	local self = {};
	setmetatable(self, Color);
	return self;
end
function round(value, decimal)
	local exp = decimal and 10 ^ decimal or 1
		return (math.ceil(value * exp - 0.5) / exp)
end

function Color:getRGB(str)
	str = str or 'No color'
	local cached = rgbCache[str]
	if cached then
		return cached[1], cached[2], cached[3]
	end

	local hash = 0 -- hash

		local counter = 1
		local long = string.len(str)
		for i = 1, long, 3 do 
		counter = math.fmod(counter*8161, 4294967279) +  -- 2^32 - 17: Prime!
		  (string.byte(str,i)*16776193) +
		  ((string.byte(str,i+1) or (long-i+256))*8372226) +
		  ((string.byte(str,i+2) or (long-i+256))*3932164)
		end
		hash = math.fmod(counter, 4294967291) -- 2^32 - 5: Prime (and different from the prime in the loop)

		-- print(hash[1], hash[#hash], #str)
		local a = math.floor((hash / math.pow(10, math.floor(math.log10(hash)) - 2 + 1))) --take 2 first numbers from hash
		local b = hash % 100  --take last 2 numbers from hash
		local c = math.ceil(math.log10(hash)) -- get length of hash
		local r = round(a / 255, 4)
		local g = round(b / 255, 4)
		local blue = round(c / 255, 4)

	rgbCache[str] = {r, g, blue}
	return r, g, blue
end

function Color:makeColor(str)
	local r, g, b = self:getRGB(str)
	return {r, g, b}
end
jungle.Color = Color
