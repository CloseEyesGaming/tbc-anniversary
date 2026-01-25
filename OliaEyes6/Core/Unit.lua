local Jungle, jungle = ...

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