local Jungle, jungle = ...
local unitCache = jungle.unitCache

local function Fishing()
    -- Prevent actions if currently casting (e.g. Lure)
    local castingName = UnitCastingInfo("player")
    if castingName then
        jungle.lastLureTime = GetTime()
        jungle.lastLureAttemptTime = GetTime() -- Reset attempt time to match actual casting state
        return {}
    end

    local hasMainHandEnchant, mainHandExpiration, mainHandEnchantID, hasOffHandEnchant, offHandExpiration, offHandEnchantID = GetWeaponEnchantInfo()

    -- Prevent double casting Lure due to server-client synchronization delay
    local isLureActive = hasMainHandEnchant
    if jungle.lastLureTime and (GetTime() - jungle.lastLureTime < 15) then
        isLureActive = true
    end

    -- Attempt to lure not often than once every 10 seconds if it fails to start casting
    if jungle.lastLureAttemptTime then
        local timeSinceAttempt = GetTime() - jungle.lastLureAttemptTime
        -- Give the bot a 3-second window to register the pixel and start casting.
        -- If no cast starts within 3 seconds, block Lure attempts until 10 seconds have passed.
        if timeSinceAttempt >= 3 and timeSinceAttempt < 10 then
            isLureActive = true
        end
    end

    -- If we are currently channeling (usually Fishing), we cannot cast Lure
    local channelName = UnitChannelInfo("player")
    if channelName then
        isLureActive = true
    end

    -- Record the lure attempt timestamp if we are choosing to Lure (only if outside current window)
    if not isLureActive then
        if not jungle.lastLureAttemptTime or (GetTime() - jungle.lastLureAttemptTime >= 10) then
            jungle.lastLureAttemptTime = GetTime()
        end
    end

    local set = {			
		[1]= {'',
			'Lure',
			(
				not isLureActive
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