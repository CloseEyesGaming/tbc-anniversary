local Jungle, jungle = ...


local function SpellOnCD(_spell)
	local duration = C_Spell.GetSpellCooldown(jungle.offsets.GCD_SELL_ID).duration
	local duration1 = C_Spell.GetSpellCooldown(_spell).duration
	if (duration1 - duration) <= 0 then
		return false
	else
		return true
	end
end
jungle.SpellOnCD = SpellOnCD


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


local function ReadyCastSpell(_spell, _target) --string:spell name, string: target, 
	local _, _, lagHome, _ = GetNetStats()
	local start = C_Spell.GetSpellCooldown(_spell).startTime
	local duration = C_Spell.GetSpellCooldown(_spell).duration
	local start1 = C_Spell.GetSpellCooldown(jungle.offsets.GCD_SELL_ID).startTime
	local duration1 = C_Spell.GetSpellCooldown(jungle.offsets.GCD_SELL_ID).duration
	local usable, nomana = C_Spell.IsSpellUsable(_spell)
	lagHome = lagHome
	if (_target ~='player' and _target ~= nil)
	and C_Spell.GetSpellInfo(_spell)
	and (usable and not nomana)
	and not UnitIsDeadOrGhost('player')
	and ((duration - duration1)==0 or (GetTime() - (start + duration - lagHome/1000))>=0)
	and C_Spell.IsSpellInRange(_spell, _target)
	then
		return true
	
	elseif _target == nil
	and C_Spell.GetSpellInfo(_spell)
	and (usable and not nomana)
	and not UnitIsDeadOrGhost('player')
	and ((duration - duration1)==0 or (GetTime() - (start + duration - lagHome/1000))>=0)
	-- and not UnitCastingInfo('player') 
	then
		return true
	
	elseif _target == 'player'
	and C_Spell.GetSpellInfo(_spell)
	and (usable and not nomana)
	and not UnitIsDeadOrGhost('player')
	and ((duration - duration1)==0 or (GetTime() - (start + duration - lagHome/1000))>=0)
	then
		return true
	else
		return false
	end

end
jungle.ReadyCastSpell = ReadyCastSpell


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


local function isCasting(_target, timeToEnd, spell)
--[[
	Is unit casting
]]
	local casting = false
	local spellName, _, _, _, endTime, _, _, notInterruptible = UnitCastingInfo(_target)
	timeToEnd = timeToEnd or 999
	if spell == nil then
		if spellName
		and notInterruptible == false then 
		local finish = endTime/1000 - GetTime()
			if timeToEnd >= finish then
				casting = true
			end
		end
	end	
	
	if spell == spellName then
		if spellName 
		and notInterruptible == false then 
			local finish = endTime/1000 - GetTime()
			if timeToEnd >= finish then
				casting = true
			end		
		end
	end
	return casting 
end
jungle.isCasting = isCasting


local function TimeToReady(_spell)
	local start = C_Spell.GetSpellCooldown(_spell).startTime
	local duration = C_Spell.GetSpellCooldown(_spell).duration
	if SpellOnCD(_spell) then
		return (start + duration - GetTime())
	else return 0
	end
end
jungle.TimeToReady = TimeToReady


local function getEnemies()
--[[
	Get all enemies visible by visible nameplates
]]
	local enemies = {}
	local inRange, nameplates = 0, C_NamePlate.GetNamePlates()
   for index = 1, #nameplates do
      local unit = nameplates[index].namePlateUnitToken
      if UnitCanAttack("player", unit) then
         if inRange >= 1 then return true end
         table.insert(enemies, unit)
      end
   end
   return enemies
end
jungle.getEnemies = getEnemies


local function targetedByCount(_target, _enemyType)
--[[
	_enemyType: 'phys', 'caster'
	if no _nemyType returns all
]]
	local _, instanceType = IsInInstance()
	local enemies = 0
	local inRange, nameplates = 0, C_NamePlate.GetNamePlates()
	local _, _, classIndex = UnitClass(_target)
	
	if _enemyType == 'phys' then
		if instanceType ~= 'arena' then
			for index = 1, #nameplates do
			  local unit = nameplates[index].namePlateUnitToken
			  if UnitCanAttack("player", unit) and UnitIsUnit(unit..'target', _target)
			  and (classIndex==1
				or classIndex==3
				or classIndex==4
				or classIndex==6
				or (classIndex==2 and UnitPowerMax(_target , 0)<12000) -- retri
				or (classIndex==7 and UnitPowerMax(_target , 0)<12000) -- ench
				or (classIndex==11 and UnitPowerMax(_target , 0)<12000) -- feral
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
				or (classIndex==2 and UnitPowerMax(_target , 0)<12000) -- retri
				or (classIndex==7 and UnitPowerMax(_target , 0)<12000) -- ench
				or (classIndex==11 and UnitPowerMax(_target , 0)<12000) -- feral
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
			  local unit = nameplates[index].namePlateUnitToken
			  if UnitCanAttack("player", unit) and UnitIsUnit(unit..'taret', _target)
			  and (classIndex==8
				or classIndex==9
				or (classIndex==5 and jungle.Buff('Shadowform', _target)) -- sp
				or (classIndex==11 and jungle.Buff('Moonkin Form', _target)) -- Moonkin
				or (classIndex==7 and UnitPowerMax(_target , 0)>12000) -- elemental/restor
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
				or (classIndex==7 and UnitPowerMax(_target , 0)>12000) -- elemental/restor
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
			  local unit = nameplates[index].namePlateUnitToken
			  if UnitCanAttack("player", unit) and UnitIsUnit(unit..'taret', _target) then
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
	local enemies = 0
	local inRange, nameplates = 0, C_NamePlate.GetNamePlates()
		
	if instanceType ~= 'arena' then
		for index = 1, #nameplates do
		  local unit = nameplates[index].namePlateUnitToken
		  if UnitCanAttack("player", unit)
		  and C_Spell.IsSpellInRange(_spell_range_check, unit) then
			 if inRange > 1 then return true end
			 enemies = enemies + 1
		  end
	   end
	elseif instanceType == 'arena' then
		for i=1, 5 do
			if UnitExists('arena'..i)
			and C_Spell.IsSpellInRange(_spell_range_check, 'arena'..i) then
				enemies = enemies + 1
			end
		end
	end
   return enemies
end
jungle.enemiesInRange = enemiesInRange


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
		life = (UnitHealth(_target) + UnitGetIncomingHeals(_target))/UnitHealthMax(_target)
	end
	return life
end
jungle.predictedLife = predictedLife


local function LifePercent(_target)
--[[Returns [0 - 1+] health level]]
	if UnitExists(_target) then
		return UnitHealth(_target)/UnitHealthMax(_target)
	end
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


local function getEnemyNameplates()
	for i = 1, 100 do
		local unit = 'nameplate'..i
		if UnitExists(unit)
		and UnitCanAttack('player', unit) then
			print(UnitName(unit), UnitHealth(unit))
		else
			break
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