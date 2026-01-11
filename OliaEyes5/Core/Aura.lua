local Jungle, jungle = ...

local function Debuff(_aura, _target, _PLAYER, _expired, _counts)
	--[[
	_PLAYER - set nil or '|PLAYER'
	]]
	local _PLAYER = _PLAYER or ''
	local _expired = _expired or 9999
	local _counts = _counts or 0
	local aura,_,counts,_,_,expired = AuraUtil.FindAuraByName(_aura, _target, "HARMFUL".._PLAYER)
	if aura == _aura
	and (expired - GetTime()) <= _expired
	and counts >= _counts then
		return true
	end
end
jungle.Debuff = Debuff


local function Buff(_aura, _target, _PLAYER, _expired, _counts)
	--[[
	_PLAYER - set nil or '_PLAYER'
	]]
	local _PLAYER = _PLAYER or ''
	local _expired = _expired or 9999
	local _counts = _counts or 0
	local aura,_,counts,_,_,expired = AuraUtil.FindAuraByName(_aura, _target, "HELPFUL".._PLAYER)
	if aura == _aura
	and (expired - GetTime()) <= _expired
	and counts >= _counts then
		return true
	end
end
jungle.Buff = Buff


local function isSlowed(_target)
--[[
	Checks for target for slow debuffs
]]
	local result = false
	local d = jungle.slowDebuffs
	for i, aura in ipairs(d) do
		if (Debuff(aura, _target)) then 
			result = true break
		end
	end
	return result
end
jungle.isSlowed = isSlowed


local function isSlowProtected(_target)
--[[
	Checks for target for slow immunity
]]
	local result = false
	local b = jungle.slowImmunityBuffs
	for i, aura in ipairs(b) do
		if (Buff(aura, _target)) then 
			result = true break
		end
	end
	return result

end
jungle.isSlowProtected = isSlowProtected


local function isEctremePoison(_target)
	local result = false
	local p = jungle.extremePoisons
		for i, aura in pairs(p) do
			if jungle.Debuff(aura, _target)
				then 
				result = true break
			end
		end
	return result
end
jungle.isEctremePoison = isEctremePoison



local function isEctremeCursed(_target)
	local result = false
	local c = jungle.extremeCurses
		for i, aura in pairs(c) do
			if jungle.Debuff(aura, _target)
				then 
				result = true break
			end
		end
	return result
end
jungle.isEctremeCursed = isEctremeCursed


local function isHasOneOfDebuffs(_target, _debuffs)
  local result = false
  for aura, _ in pairs(_debuffs) do
    if jungle.Debuff(aura, _target) then
      result = true
      break
    end
  end
  return result
end
jungle.isHasOneOfDebuffs = isHasOneOfDebuffs


local function isHasOneOfBuffs(_target, _buffs)
	local result = false
	local c = _buffs
		for i, aura in pairs(c) do
			if jungle.Buff(aura, _target)
				then 
				result = true break
			end
		end
	return result
end
jungle.isHasOneOfBuffs = isHasOneOfBuffs


local function hasAuraTypeCount(_target, _filter, _type)
	--[[
	Check of target for cout of debuff by type:
		_filter [, 'HELPFUL', 'HARMFUL']
		_type [, 'Magic', 'Curse', 'Disease', 'Poison']
	returns num of debuffs
	]]
	local count = 0
	AuraUtil.ForEachAura(_target, _filter, nil, function(_, _, _, dispelType, ...)
		if dispelType == _type then
			count = count + 1
		end
	end)
	return count
end
jungle.hasAuraTypeCount = hasAuraTypeCount


local function hasAuraType(_target, _filter, _type)
	--[[
	Check of target for one of debuffs type:
		_filter [, 'HELPFUL', 'HARMFUL']
		_type [, 'Magic', 'Curse', 'Disease', 'Poison']
	returns true or false
	]]
	local result = false
	AuraUtil.ForEachAura(_target, _filter, nil, function(_, _, _, dispelType, ...)
		if dispelType == _type then
			result = dispelType
		end
	end)
	if result == _type then
		return true
	end
end
jungle.hasAuraType = hasAuraType


local function CheckDispellableDebuffs(unit, debuffList, ...)
    -- Ensure unit is valid
    if not UnitExists(unit) then return false end

    -- Collect all dispel types from varargs into a set for quick lookup
    local dispelTypeSet = {}
    for _, dispelType in ipairs({...}) do
        dispelTypeSet[dispelType] = true
    end

    -- Iterate through debuffs on the unit
    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HARMFUL")
        if not aura then break end -- Stop if no more debuffs

        -- Check if debuff is in debuffList and matches any of the specified dispel types
        if dispelTypeSet[aura.dispelName] then
            for _, debuffName in ipairs(debuffList) do
                if aura.name == debuffName then
                    return true
                end
            end
        end
    end

    -- Return false if no matching debuff was found
    return false
end
jungle.CheckDispellableDebuffs = CheckDispellableDebuffs


local function ReCastCyclone(target, bufferTime)
    local cycloneSpellId = 33786  -- Cyclone spell ID, adjust if needed
    
    -- Get Cyclone's cast time in seconds
    local cycloneInfo = C_Spell.GetSpellInfo(cycloneSpellId)
    local cycloneCastTime = (cycloneInfo and cycloneInfo.castTime or 0) / 1000  -- Convert milliseconds to seconds if available
    
    -- Total buffer time includes cast time and additional buffer
    local totalBufferTime = cycloneCastTime + (bufferTime or 0.2)  -- Default buffer of 0.2 if not provided

    -- Find Cyclone debuff on the target
    for i = 1, 40 do
        local name, _, _, _, _, expirationTime, caster = UnitDebuff(target, i)
        
        if not name then
            -- No more debuffs to check, exit loop
            break
        end
        
        if name == "Cyclone" and caster == "player" then
            -- Cyclone debuff found, calculate remaining time
            local remainingTime = expirationTime - GetTime()
            
            -- Check if it's time to cast the next Cyclone without overlapping
            if remainingTime <= totalBufferTime then
                return true  -- Cast Cyclone to refresh before expiration
            else
                return false  -- Do not cast yet, too early
            end
        end
    end
    
    return true  -- Cast Cyclone if no current debuff found on target
end
jungle.ReCastCyclone = ReCastCyclone