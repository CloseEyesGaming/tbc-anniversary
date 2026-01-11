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
-- PARSING HELPERS
--------------------------------------------------------------------------------

local function debuffParse(unit)
	AuraUtil.ForEachAura(unit, "HARMFUL", nil, function(debuff, _, count, dispelType, duration, expirationTime, source, isStealable, _, spellId, _, _, castByPlayer, ...)
		if IsInList(debuff, jungle.unitIgnoreDebuffs) then
			unitCache[unit].auras.debuffs.unitIgnore[debuff] = { count = count, expirationTime = expirationTime, source = source }
		end	
		if dispelType == 'Magic' then
			unitCache[unit].auras.debuffs.magic[debuff] = { count = count, expirationTime = expirationTime, source = source }
		end						
		if dispelType == 'Curse' then
			unitCache[unit].auras.debuffs.curse[debuff] = { count = count, expirationTime = expirationTime, source = source }
		end						
		if dispelType == 'Poison' then
			unitCache[unit].auras.debuffs.poison[debuff] = { count = count, expirationTime = expirationTime, source = source }
		end						
		if dispelType == 'Disease' then
			unitCache[unit].auras.debuffs.disease[debuff] = { count = count, expirationTime = expirationTime, source = source }
		end						
		if IsInList(debuff, jungle.slowDebuffs) then
			unitCache[unit].auras.debuffs.slow[debuff] = { count = count, expirationTime = expirationTime, source = source }
		end
		if IsInList(debuff, jungle.rootDebuffs) then
			unitCache[unit].auras.debuffs.root[debuff] = { count = count, expirationTime = expirationTime, source = source }
		end
		if IsInList(debuff, jungle.toFreedomDebuffs) then
			unitCache[unit].auras.debuffs.freedom[debuff] = { count = count, expirationTime = expirationTime, source = source }
		end
	end)
end

local function buffParse(unit)
	AuraUtil.ForEachAura(unit, "HELPFUL", nil, function(buff, _, count, dispelType, duration, expirationTime, source, isStealable, _, spellId, _, _, castByPlayer, ...)
		if source == 'player' then
				unitCache[unit].auras.buffs.player[buff] = { count = count, expirationTime = expirationTime, source = source }
				if buff == 'Beacon of Light' then
					BEACONED_unit = unit
				end
			else
				unitCache[unit].auras.buffs.nonplayer[buff] = { count = count, expirationTime = expirationTime, source = source }
		end
		if IsInList(buff, jungle.slowImmunityBuffs) then
			unitCache[unit].auras.buffs.slowImmunity[buff] = { count = count, expirationTime = expirationTime, source = source }
		end
		if IsInList(buff, jungle.unitIgnoreBuffCaster) then
			unitCache[unit].auras.buffs.unitIgnoreIfYouCaster[buff] = { count = count, expirationTime = expirationTime, source = source }
		end
		if IsInList(buff, jungle.unitIgnoreBuffPhys) then
			unitCache[unit].auras.buffs.unitIgnoreIfYouPhys[buff] = { count = count, expirationTime = expirationTime, source = source }
		end
	end)
end

local function auraParser(unit)
	debuffParse(unit)
	buffParse(unit)
end

local function cacheUnitData(unit, _identificator)
	unitCache[unit] = {
		identificator = _identificator,
		isMe = (UnitName(unit) == UnitName('player')),
		isInCombat = UnitAffectingCombat(unit),
		currLife = jungle.LifePercent(unit),
		auras = {
			debuffs = {
				all = {},
				magic = {},
				curse = {},
				poison = {},
				disease = {},
				slow = {},
				root = {},
				freedom = {},
				unitIgnore = {},
			},
			buffs = {
				player = {},
				nonplayer = {},
				slowImmunity = {},
				unitIgnoreIfYouCaster = {},
				unitIgnoreIfYouPhys = {},
			},
		},
		threatStatus = UnitThreatSituation(unit),
		isTank = UnitGroupRolesAssigned(unit)=='TANK',
	}
end
jungle.cacheUnitData = cacheUnitData

local function clearCacheData(identificator)
  for unitName, unitData in pairs(unitCache) do
    if unitData.identificator ~= identificator then
      unitCache[unitName] = nil
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
	clearCacheData(identificator)
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
		if UnitCanAttack('player', _unit) then
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
		if not UnitCanAttack('player', _unit) then
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
	local _expired = _expired or 0
	local _counts = _counts or 0
	local buffList = _PLAYER and unitCache[_unit].auras.buffs.player or unitCache[_unit].auras.buffs.nonplayer
	
	-- Fallback check for nonplayer if checking generic
	local auraData = buffList[_aura]
	if not _PLAYER and not auraData then
		auraData = unitCache[_unit].auras.buffs.player[_aura]
	end

	if auraData then
		if (auraData.expirationTime - GetTime()) >= _expired
		and auraData.count >= _counts then
			return true
		end
	end
	return false
end
jungle.unitCacheBuff = unitCacheBuff

local function unitDebuff(_friend, _aura, _expired, _counts)
	local _expired = _expired or 0
	local _counts = _counts or 0
	
	-- Check all debuff categories
	local categories = {'magic', 'curse', 'poison', 'disease', 'slow', 'root', 'freedom', 'unitIgnore'}
	for _, cat in ipairs(categories) do
		if unitCache[_friend].auras.debuffs[cat] and unitCache[_friend].auras.debuffs[cat][_aura] then
			local d = unitCache[_friend].auras.debuffs[cat][_aura]
			if (d.expirationTime - GetTime()) >= _expired and d.count >= _counts then
				return true
			end
		end
	end
	return false
end
jungle.unitDebuff = unitDebuff

local function countEntries(table)
  local count = 0
  for k, v in pairs(table) do
    if type(v) == 'table' then count = count + 1 end
  end
  return count
end
jungle.countEntries = countEntries