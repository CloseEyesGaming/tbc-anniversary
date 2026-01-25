local Jungle, jungle = ...
local unitCache = jungle.unitCache

local function Fishing()
    local set = {			
		[1]= {'',
			'Fishing',
			(
				not jungle.IsFishing()
			),
			1, 
			0 
		},			
	}
	return set
end
jungle.Fishing = Fishing