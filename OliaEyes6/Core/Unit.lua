local Jungle, jungle = ...

local VALID_PLAYER_CLASSES = {
    WARRIOR = true, PALADIN = true, HUNTER = true,
    ROGUE = true, PRIEST = true, SHAMAN = true,
    MAGE = true, WARLOCK = true, DRUID = true,
}
local cachedPlayerClass
local function GetPlayerClass()
    if cachedPlayerClass then
        return cachedPlayerClass
    end

    local _, classToken = UnitClass("player")
    if VALID_PLAYER_CLASSES[classToken] then
        cachedPlayerClass = classToken
    end
    return classToken
end
jungle.GetPlayerClass = GetPlayerClass

local function GetNameplateUnitToken(nameplate, index)
    if not nameplate then return nil end

    local unit = nameplate.namePlateUnitToken
        or nameplate.unitToken
        or nameplate.unit
        or nameplate.displayedUnit

    local unitFrame = nameplate.UnitFrame
    if not unit and unitFrame then
        unit = unitFrame.unit
            or unitFrame.unitToken
            or unitFrame.displayedUnit
    end

    if not unit and index then
        unit = "nameplate" .. index
    end

    if unit and UnitExists(unit) then
        return unit
    end
    return nil
end
jungle.GetNameplateUnitToken = GetNameplateUnitToken

local CREATURE_TYPE_TOTEM_ID = 11

local function IsTotemUnit(unit)
    if not unit or not UnitExists(unit) then return false end
    local creatureTypeName, creatureTypeID = UnitCreatureType(unit)
    return creatureTypeID == CREATURE_TYPE_TOTEM_ID or creatureTypeName == "Totem"
end
jungle.IsTotemUnit = IsTotemUnit

local function HasActiveAuraEntries(entries)
    if not entries then return false end
    for _, aura in pairs(entries) do
        if aura and aura.isActive then
            return true
        end
    end
    return false
end

local enemyNameplateAoEDebuffSet
local enemyNameplateAoEBuffSet
local enemyNameplateAoEEligibilityTick = -1
local enemyNameplateAoEEligibilityByGUID = {}

local function BuildAuraNameSet(names)
    local result = {}
    for _, name in ipairs(names or {}) do
        result[name] = true
    end
    return result
end

local function EnsureEnemyNameplateAoEAuraSets()
    if not enemyNameplateAoEDebuffSet then
        enemyNameplateAoEDebuffSet = BuildAuraNameSet(jungle.enemyNameplateAoEIgnoreDebuffs)
        enemyNameplateAoEBuffSet = BuildAuraNameSet(jungle.enemyNameplateAoEIgnoreBuffs)
    end
end

local function HasDirectMatchingAura(unit, filter, names)
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then return false end
    for index = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
        if not aura then break end
        if names[aura.name] then return true end
    end
    return false
end

local function IsEnemyNameplateEligibleForAoE(unit)
    if not unit
    or not UnitExists(unit)
    or not UnitCanAttack("player", unit)
    or UnitIsDeadOrGhost(unit)
    or IsTotemUnit(unit) then
        return false
    end

    local currentTick = jungle.currentTick
    if currentTick and currentTick ~= enemyNameplateAoEEligibilityTick then
        enemyNameplateAoEEligibilityTick = currentTick
        enemyNameplateAoEEligibilityByGUID = {}
    end
    local guid = currentTick and UnitGUID(unit) or nil
    if guid and enemyNameplateAoEEligibilityByGUID[guid] ~= nil then
        return enemyNameplateAoEEligibilityByGUID[guid]
    end

    local function FinishEligibility(result)
        if guid then enemyNameplateAoEEligibilityByGUID[guid] = result end
        return result
    end

    local unitCache = jungle.unitCache
    local unitData = unitCache and unitCache[unit]
    if unitData and unitData.auraInitialized and unitData.auras then
        local debuffs = unitData.auras.debuffs
        local buffs = unitData.auras.buffs
        if HasActiveAuraEntries(debuffs and debuffs.enemyNameplateAoEIgnore)
        or HasActiveAuraEntries(buffs and buffs.enemyNameplateAoEIgnore) then
            return FinishEligibility(false)
        end
        return FinishEligibility(true)
    end

    EnsureEnemyNameplateAoEAuraSets()
    return FinishEligibility(not HasDirectMatchingAura(unit, "HARMFUL", enemyNameplateAoEDebuffSet)
        and not HasDirectMatchingAura(unit, "HELPFUL", enemyNameplateAoEBuffSet)
    )
end
jungle.IsEnemyNameplateEligibleForAoE = IsEnemyNameplateEligibleForAoE

local function isCasting(_target, timeToEnd, spell)
    --[[
        Checks if a unit is currently casting an interruptible spell.
        @param _target (string): The unit ID (e.g., 'player', 'target').
        @param timeToEnd (number|nil): Max remaining time (seconds) to consider valid.
        @param spell (string|nil): Specific spell name to match.
        @return (boolean): True if criteria are met and spell is interruptible.
    ]]
    local name, _, _, _, endTime, _, _, notInterruptible = UnitCastingInfo(_target)

    if not name then return false end

    timeToEnd = timeToEnd or 999
    local isInterruptible = not notInterruptible 
    
    if spell and spell ~= name then
        return false
    end

    local finish = (endTime / 1000) - GetTime()
    
    return isInterruptible and finish <= timeToEnd
end
jungle.isCasting = isCasting


local function checkPveInterrupt(_target)
    local castName, _, _, startTime, endTime, _, _, notInterruptible = UnitCastingInfo(_target)
    local channelName, _, _, _, _, _, notInterruptibleChannel = UnitChannelInfo(_target)

    local activeSpell = castName or channelName
    if not activeSpell then return false end

    local spellsBigHealsInterrupt = jungle.spellsBigHealsInterrupt
    local spellsImportantInterrupt = jungle.spellsImportantInterrupt
    local spellsCcInterrupt = jungle.spellsCcInterrupt
    
    if spellsBigHealsInterrupt and spellsImportantInterrupt and spellsCcInterrupt then
        local isNeeded = false
        for _, name in ipairs(spellsBigHealsInterrupt) do
            if name == activeSpell then isNeeded = true break end
        end
        if not isNeeded then
            for _, name in ipairs(spellsImportantInterrupt) do
                if name == activeSpell then isNeeded = true break end
            end
        end
        if not isNeeded then
            for _, name in ipairs(spellsCcInterrupt) do
                if name == activeSpell then isNeeded = true break end
            end
        end
        if not isNeeded then return false end
    end

    if (castName and not notInterruptible) or (channelName and not notInterruptibleChannel) then
        local currentTime = GetTime() * 1000
        if channelName then
            return true
        elseif castName and startTime and endTime and (endTime - startTime) > 0 then
            local castProgress = (currentTime - startTime) / (endTime - startTime)
            if castProgress > 0.8 then
                return true
            end
        end
    end
    return false
end
jungle.checkPveInterrupt = checkPveInterrupt



local function getEnemies()
--[[
	Get all enemies visible by visible nameplates
]]
	local _, instanceType = IsInInstance()
	local enemies = {}
	local inRange, nameplates = 0, C_NamePlate.GetNamePlates()
   for index = 1, #nameplates do
      local unit = GetNameplateUnitToken(nameplates[index], index)
      if IsEnemyNameplateEligibleForAoE(unit) then
         local unitHPMax = UnitHealthMax(unit)
         local hpPercent = unitHPMax > 0 and (UnitHealth(unit) / unitHPMax * 100) or 100
         if instanceType == 'arena' or hpPercent >= 20 then
            if inRange >= 1 then return true end
            table.insert(enemies, unit)
         end
      end
   end
   return enemies
end
jungle.getEnemies = getEnemies

local ARENA_UNITS = {}
local ARENA_TARGET_UNITS = {}
for i = 1, 5 do
	ARENA_UNITS[i] = 'arena' .. i
	ARENA_TARGET_UNITS[i] = ARENA_UNITS[i] .. 'target'
end

local arenaPressureTick = -1
local arenaPressureByGUID = {}
local arenaPressureRepresentative = {}

local function CountArenaTargetLegacy(target)
	local enemies = 0
	for i = 1, 5 do
		if UnitExists(ARENA_UNITS[i])
		and UnitIsUnit(ARENA_TARGET_UNITS[i], target) then
			enemies = enemies + 1
		end
	end
	return enemies
end

local function GetArenaTargetPressure(target)
	local currentTick = jungle.currentTick or 0
	if arenaPressureTick ~= currentTick then
		arenaPressureTick = currentTick
		wipe(arenaPressureByGUID)
		wipe(arenaPressureRepresentative)

		for i = 1, 5 do
			if UnitExists(ARENA_UNITS[i]) then
				local targetUnit = ARENA_TARGET_UNITS[i]
				local targetGUID = UnitGUID(targetUnit)
				if targetGUID then
					arenaPressureByGUID[targetGUID] = (arenaPressureByGUID[targetGUID] or 0) + 1
					if not arenaPressureRepresentative[targetGUID] then
						arenaPressureRepresentative[targetGUID] = targetUnit
					end
				end
			end
		end
	end

	local targetGUID = UnitGUID(target)
	if not targetGUID then
		return CountArenaTargetLegacy(target)
	end

	local pressure = arenaPressureByGUID[targetGUID]
	if not pressure then
		return 0
	end

	local representative = arenaPressureRepresentative[targetGUID]
	if representative and UnitIsUnit(representative, target) then
		return pressure
	end
	return CountArenaTargetLegacy(target)
end

local NAMEPLATE_TARGET_UNITS = {}
for i = 1, 40 do
	local unit = 'nameplate' .. i
	NAMEPLATE_TARGET_UNITS[unit] = unit .. 'target'
end

local nameplatePressureTick = -1
local nameplatePressureByGUID = {}
local nameplatePressureRepresentative = {}
local nameplatePressureHasMissingGUID = false

local function GetNameplateTargetUnit(unit)
	local targetUnit = NAMEPLATE_TARGET_UNITS[unit]
	if not targetUnit then
		targetUnit = unit .. 'target'
		NAMEPLATE_TARGET_UNITS[unit] = targetUnit
	end
	return targetUnit
end

local function CountNameplateTargetLegacy(target)
	local enemies = 0
	local nameplates = C_NamePlate.GetNamePlates()
	for i = 1, #nameplates do
		local unit = GetNameplateUnitToken(nameplates[i], i)
		if unit
		and UnitCanAttack('player', unit)
		and UnitIsUnit(GetNameplateTargetUnit(unit), target) then
			enemies = enemies + 1
		end
	end
	return enemies
end

local function GetNameplateTargetPressure(target)
	local currentTick = jungle.currentTick or 0
	if nameplatePressureTick ~= currentTick then
		nameplatePressureTick = currentTick
		wipe(nameplatePressureByGUID)
		wipe(nameplatePressureRepresentative)
		nameplatePressureHasMissingGUID = false

		local nameplates = C_NamePlate.GetNamePlates()
		for i = 1, #nameplates do
			local unit = GetNameplateUnitToken(nameplates[i], i)
			if unit and UnitCanAttack('player', unit) then
				local targetUnit = GetNameplateTargetUnit(unit)
				local targetGUID = UnitGUID(targetUnit)
				if targetGUID then
					nameplatePressureByGUID[targetGUID] = (nameplatePressureByGUID[targetGUID] or 0) + 1
					if not nameplatePressureRepresentative[targetGUID] then
						nameplatePressureRepresentative[targetGUID] = targetUnit
					end
				elseif UnitExists(targetUnit) then
					nameplatePressureHasMissingGUID = true
				end
			end
		end
	end

	if nameplatePressureHasMissingGUID then
		return CountNameplateTargetLegacy(target)
	end

	local targetGUID = UnitGUID(target)
	if not targetGUID then
		return CountNameplateTargetLegacy(target)
	end

	local pressure = nameplatePressureByGUID[targetGUID]
	if not pressure then
		return 0
	end

	local representative = nameplatePressureRepresentative[targetGUID]
	if representative and UnitIsUnit(representative, target) then
		return pressure
	end
	return CountNameplateTargetLegacy(target)
end

local function IsPhysicalPressureTarget(target, classIndex)
	return classIndex == 1
		or classIndex == 3
		or classIndex == 4
		or classIndex == 6
		or (classIndex == 2 and UnitPowerMax(target, 0) < 6000)
		or (classIndex == 7 and UnitPowerMax(target, 0) < 6000)
		or (classIndex == 11 and UnitPowerMax(target, 0) < 6000)
end

local function IsCasterPressureTarget(target, classIndex)
	return classIndex == 8
		or classIndex == 9
		or (classIndex == 5 and jungle.Buff('Shadowform', target))
		or (classIndex == 11 and jungle.Buff('Moonkin Form', target))
		or (classIndex == 7 and UnitPowerMax(target, 0) > 7000)
end


local function targetedByCount(_target, _enemyType)
--[[
	_enemyType: 'phys', 'caster'
	if no _nemyType returns all
]]
	local _, instanceType = IsInInstance()
	if _enemyType == nil and instanceType == 'arena' then
		return GetArenaTargetPressure(_target)
	end

	if instanceType ~= 'arena'
	and (_enemyType == nil or _enemyType == 'phys' or _enemyType == 'caster') then
		local pressure = GetNameplateTargetPressure(_target)
		if _enemyType == nil or pressure == 0 then
			return pressure
		end

		local _, _, classIndex = UnitClass(_target)
		if _enemyType == 'phys' then
			return IsPhysicalPressureTarget(_target, classIndex) and pressure or 0
		end
		return IsCasterPressureTarget(_target, classIndex) and pressure or 0
	end

	local enemies = 0
	local inRange, nameplates = 0, C_NamePlate.GetNamePlates()
	local _, _, classIndex = UnitClass(_target)
	
	if _enemyType == 'phys' then
		if instanceType ~= 'arena' then
			for index = 1, #nameplates do
			  local unit = GetNameplateUnitToken(nameplates[index], index)
			  if unit and UnitCanAttack("player", unit) and UnitIsUnit(unit..'target', _target)
			  and (classIndex==1
				or classIndex==3
				or classIndex==4
				or classIndex==6
				or (classIndex==2 and UnitPowerMax(_target , 0)<6000) -- retri
				or (classIndex==7 and UnitPowerMax(_target , 0)<6000) -- ench
				or (classIndex==11 and UnitPowerMax(_target , 0)<6000) -- feral
			  )
			  then
				 if inRange > 1 then return true end
				 enemies = enemies + 1
			  end
		   end
		elseif instanceType == 'arena' then
			for i=1, 5 do
				if UnitExists('arena'..i)
				and UnitIsUnit('arena'..i..'target', _target)
				and (classIndex==1
				or classIndex==3
				or classIndex==4
				or classIndex==6
				or (classIndex==2 and UnitPowerMax(_target , 0)<6000) -- retri
				or (classIndex==7 and UnitPowerMax(_target , 0)<6000) -- ench
				or (classIndex==11 and UnitPowerMax(_target , 0)<6000) -- feral
			  )
				then
					enemies = enemies + 1
				end
			end
		end
	end
	
	if _enemyType == 'caster' then
		if instanceType ~= 'arena' then
			for index = 1, #nameplates do
			  local unit = GetNameplateUnitToken(nameplates[index], index)
			  if unit and UnitCanAttack("player", unit) and UnitIsUnit(unit..'target', _target)
			  and (classIndex==8
				or classIndex==9
				or (classIndex==5 and jungle.Buff('Shadowform', _target)) -- sp
				or (classIndex==11 and jungle.Buff('Moonkin Form', _target)) -- Moonkin
				or (classIndex==7 and UnitPowerMax(_target , 0)>7000) -- elemental/restor
			  )
			  then
				 if inRange > 1 then return true end
				 enemies = enemies + 1
			  end
		   end
		elseif instanceType == 'arena' then
			for i=1, 5 do
				if UnitExists('arena'..i)
				and UnitIsUnit('arena'..i..'target', _target) 
				and (classIndex==8
				or classIndex==9
				or (classIndex==5 and jungle.Buff('Shadowform', _target)) -- sp
				or (classIndex==11 and jungle.Buff('Moonkin Form', _target)) -- Moonkin
				or (classIndex==7 and UnitPowerMax(_target , 0)>7000) -- elemental/restor
			  )
				then
					enemies = enemies + 1
				end
			end
		end
	end
	
	if _enemyType == nil then
		if instanceType ~= 'arena' then
			for index = 1, #nameplates do
			  local unit = GetNameplateUnitToken(nameplates[index], index)
			  if unit and UnitCanAttack("player", unit) and UnitIsUnit(unit..'target', _target) then
				 if inRange > 1 then return true end
				 enemies = enemies + 1
			  end
		   end
		elseif instanceType == 'arena' then
			for i=1, 5 do
				if UnitExists('arena'..i)
				and UnitIsUnit('arena'..i..'target', _target) then
					enemies = enemies + 1
				end
			end
		end
	end
   return enemies
end
jungle.targetedByCount = targetedByCount


local function enemiesInRange(_spell_range_check)
--[[
	get attackable enemies in range
	_spell_range_check: spell to range check
]]--
	local _, instanceType = IsInInstance()
	local enemies = 0
	local inRange, nameplates = 0, C_NamePlate.GetNamePlates()
		
	if instanceType ~= 'arena' then
		for index = 1, #nameplates do
		  local unit = GetNameplateUnitToken(nameplates[index], index)
		  if IsEnemyNameplateEligibleForAoE(unit) then
			  local unitHPMax = UnitHealthMax(unit)
			  local hpPercent = unitHPMax > 0 and (UnitHealth(unit) / unitHPMax * 100) or 100
			  if C_Spell.IsSpellInRange(_spell_range_check, unit) and hpPercent >= 20 then
				 if inRange > 1 then return true end
				 enemies = enemies + 1
			  end
		  end
	   end
	elseif instanceType == 'arena' then
		for i=1, 5 do
			if IsEnemyNameplateEligibleForAoE('arena'..i)
			and C_Spell.IsSpellInRange(_spell_range_check, 'arena'..i) then
				enemies = enemies + 1
			end
		end
	end
   return enemies
end
jungle.enemiesInRange = enemiesInRange


local function isCastingOneOfSpells(_target, _timeToEnd, _casts)
	local result = false
	local c = _casts
		for i, spell in pairs(c) do
			if jungle.isCasting(_target, _timeToEnd, spell)
				then 
				result = true break
			end
		end
	return result
end
jungle.isCastingOneOfSpells = isCastingOneOfSpells


local function predictedLife(_target)
	--[[Returns [0 - 1+] health level includes direct incoming heals]]
	local life = 0
	if UnitIsDeadOrGhost(_target)==false then
		local maxHealth = UnitHealthMax(_target)
		if maxHealth and maxHealth > 0 then
			life = (UnitHealth(_target) + (UnitGetIncomingHeals(_target) or 0)) / maxHealth
		end
	end
	return life
end
jungle.predictedLife = predictedLife


local function LifePercent(_target)
--[[Returns [0 - 1+] health level]]
	if UnitExists(_target) then
		local maxHealth = UnitHealthMax(_target)
		if maxHealth and maxHealth > 0 then
			return UnitHealth(_target) / maxHealth
		end
	end
	return 0
end
jungle.LifePercent = LifePercent


local function isTanking(_target)
	local result = false
	local status = _G.UnitThreatSituation(_target)
	if status == 3 or status == 2 then
		result = true
	end
	return result
end
jungle.isTanking = isTanking


local function isPriority(_target)
--[[
	Priority target to heal
]]
	local result = false
	--debuffs
	local d = jungle.healDebuffs
	for i, aura in pairs(d) do
		if jungle.Debuff(aura, _target)
			then 
			result = true break
		end
	end
return result
end
jungle.isPriority = isPriority


local function getEnemyNameplates()
	for i = 1, 40 do
		local unit = 'nameplate'..i
		if UnitExists(unit)
		and UnitCanAttack('player', unit) then
			print(UnitName(unit), UnitHealth(unit))
		end
	end
end
jungle.getEnemyNameplates = getEnemyNameplates


local function IsUnitHealer(_target)
	local _, instanceType = IsInInstance()
	local arenaSpec = 0
	if UnitIsFriend('player', _target) then
		if UnitGroupRolesAssigned(_target) == 'HEALER' then
			return true
		end
	elseif UnitCanAttack('player', _target)
	and instanceType == 'arena' then
		for i = 1, 5 do
			if UnitIsUnit(_target, "arena"..i) then
				arenaSpec = GetArenaOpponentSpec(i)
				break
			end
		end
		if (arenaSpec == 105 or arenaSpec == 1468 or arenaSpec == 270 or arenaSpec == 65 or arenaSpec == 256 or arenaSpec == 257 or arenaSpec == 264) then
			return true
		end
	end
	return false
end
jungle.IsUnitHealer = IsUnitHealer


local function getCasterUnitCCWindow(_target, _CCTables, _expired)
	--[[
	Get Unit window to end of CC in '_expired' seconds based on '_CCTables'(list of lists or _CCTable)
	]]--
	local expired = 0
	for k=1, #_CCTables do
		local c = _CCTables[k]
		for i, _aura in pairs(c) do
			local aura,_,_,_,_,expiredStump = AuraUtil.FindAuraByName(_aura, _target, "HARMFUL")
			if aura == _aura
			and expired <= (expiredStump - GetTime()) then
				expired = (expiredStump - GetTime())
			end
		end
	end
	if expired ~= 0
	and expired <= _expired then
		return true
		else
		return false
	end
end
jungle.getCasterUnitCCWindow = getCasterUnitCCWindow


-- IsFishing
-- Returns true if the current softinteract target is the player's fishing bobber (ID: 35591).
local function IsFishing()
    -- Directly query the GUID for the softinteract token.
    local guid = UnitGUID("softinteract")
    if not guid then return false end

    -- Format: Type-0-ServerID-InstanceID-ZoneUID-ID-SpawnUID
    local unitType, _, _, _, _, objectID = strsplit("-", guid)
    
    -- Return true only if it is a GameObject matching the bobber ID
    return (unitType == "GameObject" and objectID == "35591")
end
jungle.IsFishing = IsFishing

local WARRIOR_MELEE_SPELLS = {"Hamstring", "Bloodthirst", "Mortal Strike", "Shield Slam", "Pummel", "Revenge"}
local ROGUE_MELEE_SPELLS = {"Sinister Strike", "Mutilate", "Backstab", "Eviscerate"}
local DRUID_BEAR_MELEE_SPELLS = {"Mangle", "Lacerate"}
local DRUID_CAT_MELEE_SPELLS = {"Claw", "Mangle", "Shred"}
local HUNTER_MELEE_SPELLS = {"Wing Clip", "Raptor Strike"}

local function inMeleeRange(unit)
    if not unit or not UnitExists(unit) then return false end
    
    local classToken = GetPlayerClass()
    local spells
    
    if classToken == "WARRIOR" then
        spells = WARRIOR_MELEE_SPELLS
    elseif classToken == "ROGUE" then
        spells = ROGUE_MELEE_SPELLS
    elseif classToken == "DRUID" then
        local form = GetShapeshiftForm()
        if form == 1 then -- Bear Form
            spells = DRUID_BEAR_MELEE_SPELLS
        elseif form == 3 then -- Cat Form
            spells = DRUID_CAT_MELEE_SPELLS
        end
    elseif classToken == "HUNTER" then
        spells = HUNTER_MELEE_SPELLS
    end
    
    if spells then
        for i = 1, #spells do
            local inRange = C_Spell.IsSpellInRange(spells[i], unit)
            if inRange ~= nil then
                return inRange
            end
        end
    end
    
    -- Fallback to CheckInteractDistance
    return CheckInteractDistance(unit, 3)
end
jungle.inMeleeRange = inMeleeRange
