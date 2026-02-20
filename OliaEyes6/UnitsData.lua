local Jungle, jungle = ...

BEACONED_FRIEND = ''
TO_BEACON = nil

local unitCache = {} -- Table to store cached unit data
jungle.unitCache = unitCache

-- Define a function to check if a value is in a list
local function IsInList(value, list)
  for _, item in pairs(list) do
    if value == item then
      return true
    end
  end
  return false
end
jungle.IsInList = IsInList

--------------------------------------------------------------------------------
-- OPTIMIZATION HELPERS (Table Recycling)
--------------------------------------------------------------------------------

local function InitUnitTable()
    -- Create the complex table structure ONCE per unit
    return {
        identificator = 0,
        isMe = false,
        isInCombat = false,
        currLife = 0,
        missingHP = 0,   -- [NEW] Absolute missing health
        hpBucket = 0,    -- [NEW] Missing HP divided into 500s
        hotScore = 0,    -- [NEW] Saturation score
        threatStatus = 0,
        isTank = false,
        auras = {
            debuffs = {
                all = {}, magic = {}, curse = {}, poison = {}, disease = {},
                slow = {}, root = {}, freedom = {}, unitIgnore = {},
            },
            buffs = {
                player = {}, nonplayer = {}, slowImmunity = {},
                unitIgnoreIfYouCaster = {}, unitIgnoreIfYouPhys = {},
            },
        },
    }
end

local function ResetUnitCache(t)
    -- Efficiently wipe sub-tables without deleting the main table
    -- 1. Wipe Debuffs
    for _, v in pairs(t.auras.debuffs) do
        wipe(v)
    end
    -- 2. Wipe Buffs
    for _, v in pairs(t.auras.buffs) do
        wipe(v)
    end
end

--------------------------------------------------------------------------------
-- PARSING HELPERS
--------------------------------------------------------------------------------

local function debuffParse(unit)
    -- Note: unitCache[unit] is guaranteed to exist and be clean here
    local data = unitCache[unit].auras.debuffs
    
	AuraUtil.ForEachAura(unit, "HARMFUL", nil, function(debuff, _, count, dispelType, duration, expirationTime, source, isStealable, _, spellId, _, _, castByPlayer, ...)
		if IsInList(debuff, jungle.unitIgnoreDebuffs) then
			data.unitIgnore[debuff] = { count = count, expirationTime = expirationTime, source = source }
		end	
		if dispelType == 'Magic' then
			data.magic[debuff] = { count = count, expirationTime = expirationTime, source = source }
		end						
		if dispelType == 'Curse' then
			data.curse[debuff] = { count = count, expirationTime = expirationTime, source = source }
		end						
		if dispelType == 'Poison' then
			data.poison[debuff] = { count = count, expirationTime = expirationTime, source = source }
		end						
		if dispelType == 'Disease' then
			data.disease[debuff] = { count = count, expirationTime = expirationTime, source = source }
		end						
		if IsInList(debuff, jungle.slowDebuffs) then
			data.slow[debuff] = { count = count, expirationTime = expirationTime, source = source }
		end
		if IsInList(debuff, jungle.rootDebuffs) then
			data.root[debuff] = { count = count, expirationTime = expirationTime, source = source }
		end
		if IsInList(debuff, jungle.toFreedomDebuffs) then
			data.freedom[debuff] = { count = count, expirationTime = expirationTime, source = source }
		end
	end)
end

local function buffParse(unit)
    -- Note: unitCache[unit] is guaranteed to exist and be clean here
    local data = unitCache[unit].auras.buffs

	AuraUtil.ForEachAura(unit, "HELPFUL", nil, function(buff, _, count, dispelType, duration, expirationTime, source, isStealable, _, spellId, _, _, castByPlayer, ...)
		if source == 'player' then
				data.player[buff] = { count = count, expirationTime = expirationTime, source = source }
				if buff == 'Beacon of Light' then
					BEACONED_unit = unit
				end
			else
				data.nonplayer[buff] = { count = count, expirationTime = expirationTime, source = source }
		end
		if IsInList(buff, jungle.slowImmunityBuffs) then
			data.slowImmunity[buff] = { count = count, expirationTime = expirationTime, source = source }
		end
		if IsInList(buff, jungle.unitIgnoreBuffCaster) then
			data.unitIgnoreIfYouCaster[buff] = { count = count, expirationTime = expirationTime, source = source }
		end
		if IsInList(buff, jungle.unitIgnoreBuffPhys) then
			data.unitIgnoreIfYouPhys[buff] = { count = count, expirationTime = expirationTime, source = source }
		end
	end)
end

local function auraParser(unit)
	debuffParse(unit)
	buffParse(unit)
    
    -- =======================================================
    -- [NEW] HOT SCORE & TANK BIAS LOGIC
    -- =======================================================
    local u = unitCache[unit]
    local score = 0
    local pBuffs = u.auras.buffs.player
    local anyBuffs = u.auras.buffs.nonplayer

    -- Calculate base score
    if pBuffs['Lifebloom'] then score = score + pBuffs['Lifebloom'].count end
    if pBuffs['Rejuvenation'] or anyBuffs['Rejuvenation'] then score = score + 1 end
    if pBuffs['Regrowth'] or anyBuffs['Regrowth'] then score = score + 1 end

    -- Tank Bias: Force tanks to look like they have fewer HoTs so they get priority
    if u.isTank and jungle.isTanking(unit) then
        if u.currLife < 0.60 then
            score = score - 2 -- Critical Tank
        elseif u.currLife < 0.90 then
            score = score - 1 -- Injured Tank
        end
    end

    u.hotScore = score
end

local function cacheUnitData(unit, _identificator)
    if not unitCache[unit] then
        unitCache[unit] = InitUnitTable()
    else
        ResetUnitCache(unitCache[unit])
    end

    local u = unitCache[unit]
    
	u.identificator = _identificator
	u.guid = UnitGUID(unit) -- [NEW] Cache the GUID for the tracker
	u.isMe = (UnitName(unit) == UnitName('player'))
	u.isInCombat = UnitAffectingCombat(unit)
	u.currLife = jungle.LifePercent(unit)
	u.threatStatus = UnitThreatSituation(unit)
	u.isTank = (UnitGroupRolesAssigned(unit) == 'TANK') or (GetPartyAssignment("MAINTANK", unit) == true)
    
    -- =======================================================
    -- [NEW] MISSING HP BUCKET LOGIC (Incoming Heals Supported)
    -- =======================================================
    local maxHP = UnitHealthMax(unit) or 1
    local currentHP = UnitHealth(unit) or 0
    local incHeals = UnitGetIncomingHeals(unit) or 0 
    
    local missingHP = maxHP - (currentHP + incHeals)
    if missingHP < 0 then missingHP = 0 end
    
    u.missingHP = missingHP
    -- Groups players by 500 HP tiers (0-499=0, 500-999=1, etc.)
    u.hpBucket = math.floor(missingHP / 500) 
end
jungle.cacheUnitData = cacheUnitData

local function clearCacheData(identificator)
  -- Remove stale units that were NOT updated in the current cycle
  for unitName, unitData in pairs(unitCache) do
    if unitData.identificator ~= identificator then
      unitCache[unitName] = nil
      -- Note: This might clear globals aggressively, but preserving original logic behavior here
	  BEACONED_FRIEND = ''
	  TO_BEACON = nil
    end
  end
end

local function cacheEveryUnit(_identificator)
    local identificator = math.random(100, 999)
    local groupType
    local player = false 
    local _, instanceType = IsInInstance()
    
	-- 1. Universal Token Scan
		local universalTokens = {"player", "target", "focus", "mouseover", "pet"}
		for _, token in ipairs(universalTokens) do
			if UnitExists(token) and not UnitIsDeadOrGhost(token) then
				-- FACT: This is the critical "Blacklist" gate
				-- Only cache if it's the player OR if the unit is NOT blacklisted
				if token == "player" or not jungle.isTargetInLos(token) then
					cacheUnitData(token, identificator)
					auraParser(token)
				end
			end
		end

    -- 2. Group Scanning Logic (Unchanged)
    if UnitExists('raid1') then
        groupType = 'raid'
    elseif UnitExists('party1') then
        groupType = 'party'
        player = true
    else
        player = true
    end
	
	if player and not UnitIsDeadOrGhost('player') then
		cacheUnitData('player', identificator)
		auraParser('player')
	end
	
    if groupType then
        for i = 1, GetNumGroupMembers() do
			if i > 25 then break end
			local u = groupType .. i
			if UnitExists(u)
			and not jungle.isTargetInLos(u)
			and (UnitName(u) == UnitName('player') or UnitInRange(u))
			and not UnitIsDeadOrGhost(u) then
				cacheUnitData(u, identificator)
				auraParser(u)
			end
         end
    end
	if instanceType == 'arena' then
		for j = 1, 5 do
			if UnitExists('arena' .. j) and not jungle.isTargetInLos('arena' .. j) and not UnitIsDeadOrGhost('arena' .. j) then
				cacheUnitData('arena' .. j, identificator)
				auraParser('arena' .. j)
			end
		end
	end
    
    -- Now prune anyone who wasn't seen (old ID)
    clearCacheData(identificator)
end

local function updateUnitsData()
  cacheEveryUnit()
end
jungle.updateUnitsData = updateUnitsData

-- Function to get the number of auras for a specific unit
function GetUnitAuraCount(unit)
  if not unitCache[unit] then return 0 end
  return jungle.countEntries(unitCache[unit].auras.buffs.player)
end
jungle.GetUnitAuraCount = GetUnitAuraCount

local function getCacheFriend(_buff, _PLAYER)
	for friend, unitData in pairs(jungle.unitCache) do
		if _PLAYER then
			if jungle.unitCacheBuff(friend, _buff, '_PLAYER', nil, nil) then return friend end
		else
			if jungle.unitCacheBuff(friend, _buff, nil, nil) then return friend end
		end
	end
end
jungle.getCacheFriend = getCacheFriend

--------------------------------------------------------------------------------
-- TBC SPEC DETECTION (Robust Fix)
--------------------------------------------------------------------------------
local function GetTalentSpec()
    -- TBC/Classic: Count points in each tab. 1=Left, 2=Middle, 3=Right.
    -- FIX: Use multiple assignment to capturing ONLY the 3rd return value.
    -- This ensures 'p1' is just the points, not followed by the texture string.
    
    local _, _, p1 = GetTalentTabInfo(1)
    local _, _, p2 = GetTalentTabInfo(2)
    local _, _, p3 = GetTalentTabInfo(3)

    -- Force number or 0
    p1 = tonumber(p1) or 0
    p2 = tonumber(p2) or 0
    p3 = tonumber(p3) or 0
    
    local max = math.max(p1, p2, p3)
    
    if max == 0 then return 1 end -- No talents? Default to 1
    if max == p1 then return 1 end
    if max == p2 then return 2 end
    return 3
end

local function isUnitAvailable(_unit)
	local _, engClass = UnitClass('player')
	local mySpec = GetTalentSpec()

	if UnitExists(_unit) 
	and unitCache[_unit]
	and next(unitCache[_unit].auras.debuffs.unitIgnore)==nil
	then
		if UnitCanAttack('player', _unit) and not jungle.isTargetInLos(_unit) then
			-- CASTER / HEALER LOGIC
			if (
				(engClass == "MAGE") or (engClass == "PRIEST") or (engClass == "WARLOCK")
				or (engClass == "DRUID" and (mySpec == 1 or mySpec == 3)) -- Balance / Resto
				or (engClass == "PALADIN" and mySpec == 1) -- Holy
				or (engClass == "SHAMAN" and (mySpec == 1 or mySpec == 3)) -- Ele / Resto
			) 
			and next(unitCache[_unit].auras.buffs.unitIgnoreIfYouCaster) == nil then
				return true
			
			-- PHYSICAL LOGIC
			elseif (
				(engClass == "WARRIOR") or (engClass == "ROGUE") or (engClass == "HUNTER")
				or (engClass == "DRUID" and mySpec == 2) -- Feral
				or (engClass == "PALADIN" and (mySpec == 2 or mySpec == 3)) -- Prot / Ret
				or (engClass == "SHAMAN" and mySpec == 2) -- Enh
			) 
			and next(unitCache[_unit].auras.buffs.unitIgnoreIfYouPhys) == nil then
				return true
			end
		end
		
		-- Logic for Friendly Targets (Heals)
		if not UnitCanAttack('player', _unit) and not jungle.isTargetInLos(_unit) then
			return true
		end
	end
	return false
end
jungle.isUnitAvailable = isUnitAvailable

local function lowLifeFriendsCount(_life)
	local count = 0
	local life = _life or 1
	for _, unitData in pairs(unitCache) do
		if unitData.currLife <= life then
			count = count + 1
		end
	end
	return count
end
jungle.lowLifeFriendsCount = lowLifeFriendsCount

local function bloomFriendsCount(_life)
	local count = 0
	local life = _life or 1
	for _, unitData in pairs(unitCache) do
		if unitData.currLife <= life
		and unitData.auras.buffs.player['Lifebloom'] then
			count = count + 1
		end
	end
	return count
end
jungle.bloomFriendsCount = bloomFriendsCount

local function unitCacheBuff(_unit, _aura, _PLAYER, _expired, _counts)
    -- 1. SAFETY GUARD:
    -- Returns false if unit is dead, out of LoS (missing from cache), or doesn't exist.
    if not _unit or not unitCache[_unit] or not unitCache[_unit].auras then 
        return false 
    end

    local _expired = _expired or 0
    local _counts = _counts or 0
    local buffs = unitCache[_unit].auras.buffs
    local buffList = _PLAYER and buffs.player or buffs.nonplayer
    
    local auraData = buffList[_aura]
    if not _PLAYER and not auraData then
        auraData = buffs.player[_aura]
    end

    if auraData then
        -- FACT: expirationTime is 0 for buffs that don't expire (until used or die)
        local isInfinite = (auraData.expirationTime == 0)
        local remaining = isInfinite and 99999 or (auraData.expirationTime - GetTime())

        if remaining >= _expired and auraData.count >= _counts then
            return true
        end
    end
    return false
end
jungle.unitCacheBuff = unitCacheBuff

local function unitCacheDebuff(_friend, _aura, _expired, _counts)
    -- 1. SAFETY GUARD: Check if unit exists in our cache
    -- Prevents "attempt to index field '?' (a nil value)"
    if not _friend or not unitCache[_friend] or not unitCache[_friend].auras then 
        return false 
    end

    local _expired = _expired or 0
    local _counts = _counts or 0
    
    -- FACT: Check all debuff categories safely
    local categories = {'magic', 'curse', 'poison', 'disease', 'slow', 'root', 'freedom', 'unitIgnore'}
    
    for _, cat in ipairs(categories) do
        local catTable = unitCache[_friend].auras.debuffs[cat]
        
        if catTable and catTable[_aura] then
            local d = catTable[_aura]
            
            -- 2. INFINITE CHECK: expirationTime is 0 for permanent debuffs
            local isInfinite = (d.expirationTime == 0)
            local remaining = isInfinite and 99999 or (d.expirationTime - GetTime())

            if remaining >= _expired and d.count >= _counts then
                return true
            end
        end
    end
    return false
end
jungle.unitCacheDebuff = unitCacheDebuff

local function countEntries(table)
  local count = 0
  for k, v in pairs(table) do
    if type(v) == 'table' then count = count + 1 end
  end
  return count
end
jungle.countEntries = countEntries