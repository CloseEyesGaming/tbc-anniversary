local Jungle, jungle = ...
local unitCache = jungle.unitCache

local function Fishing()
    local hasMainHandEnchant, mainHandExpiration, mainHandEnchantID, hasOffHandEnchant, offHandExpiration, offHandEnchantID = GetWeaponEnchantInfo()

    local set = {			
		[1]= {'',
			'Lure',
			(
				not hasMainHandEnchant
			),
			1, 
			0 
		},			
		[2]= {'',
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