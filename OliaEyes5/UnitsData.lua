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

--[[
local function auraParser(friend)
	local i = 1
	local j = 1
	local unitDebuff = C_UnitAuras.GetDebuffDataByIndex(friend, i, 'HARMFUL')
	local unitBuff = C_UnitAuras.GetBuffDataByIndex(friend, j, 'HELPFUL')
	-- -- Check for debuffs
	while i > 0 do
		if unitDebuff ~= nil then
			local debuff = unitDebuff.name
			local count = unitDebuff.charges
			local dispelType = unitDebuff.dispelName
			local duration = unitDebuff.duration
			local expirationTime = unitDebuff.expirationTime
			local source = unitDebuff.sourceUnit
			local isStealable = unitDebuff.isStealable
			local spellId = unitDebuff.spellId
			local castByPlayer = unitDebuff.isFromPlayerOrPlayerPet
		
			unitCache[friend].auras.debuffs.all[debuff] = {
			count = count,
			dispelType = dispelType,
			duration = duration,
			expirationTime = expirationTime,
			source = source,
			isStealable = isStealable,
			spellId = spellId,
			castByPlayer = castByPlayer,
			}
			if IsInList(debuff, jungle.unitIgnoreDebuffs) then
				unitCache[friend].auras.debuffs.unitIgnore[debuff] = {
				count = count,
				dispelType = dispelType,
				duration = duration,
				expirationTime = expirationTime,
				source = source,
				isStealable = isStealable,
				spellId = spellId,
				castByPlayer = castByPlayer,
				}
			end	
			if dispelType == 'Magic' then
				unitCache[friend].auras.debuffs.magic[debuff] = {
				count = count,
				dispelType = dispelType,
				duration = duration,
				expirationTime = expirationTime,
				source = source,
				isStealable = isStealable,
				spellId = spellId,
				castByPlayer = castByPlayer,
				}
			end						
			if IsInList(debuff, jungle.extremeMagicDebuffs)
				and dispelType == 'Magic' then
				unitCache[friend].auras.debuffs.magicExtreme[debuff] = {
				count = count,
				dispelType = dispelType,
				duration = duration,
				expirationTime = expirationTime,
				source = source,
				isStealable = isStealable,
				spellId = spellId,
				castByPlayer = castByPlayer,
				}
			end
			if IsInList(debuff, jungle.extremeCurses)
				and dispelType == 'Curse' then
				unitCache[friend].auras.debuffs.curseExtreme[debuff] = {
				count = count,
				dispelType = dispelType,
				duration = duration,
				expirationTime = expirationTime,
				source = source,
				isStealable = isStealable,
				spellId = spellId,
				castByPlayer = castByPlayer,
				}
			end
			if dispelType == 'Curse' then
				unitCache[friend].auras.debuffs.curse[debuff] = {
				count = count,
				dispelType = dispelType,
				duration = duration,
				expirationTime = expirationTime,
				source = source,
				isStealable = isStealable,
				spellId = spellId,
				castByPlayer = castByPlayer,
				}
			end						
			if IsInList(debuff, jungle.extremePoisons)
				and dispelType == 'Poison' then
				unitCache[friend].auras.debuffs.poisonExtreme[debuff] = {
				count = count,
				dispelType = dispelType,
				duration = duration,
				expirationTime = expirationTime,
				source = source,
				isStealable = isStealable,
				spellId = spellId,
				castByPlayer = castByPlayer,
				}
			end
			if dispelType == 'Poison' then
				unitCache[friend].auras.debuffs.poison[debuff] = {
				count = count,
				dispelType = dispelType,
				duration = duration,
				expirationTime = expirationTime,
				source = source,
				isStealable = isStealable,
				spellId = spellId,
				castByPlayer = castByPlayer,
				}
			end						
			if dispelType == 'Disease' then
				unitCache[friend].auras.debuffs.disease[debuff] = {
				count = count,
				dispelType = dispelType,
				duration = duration,
				expirationTime = expirationTime,
				source = source,
				isStealable = isStealable,
				spellId = spellId,
				castByPlayer = castByPlayer,
				}
			end						
			if IsInList(debuff, jungle.slowDebuffs) then
				unitCache[friend].auras.debuffs.slow[debuff] = {
				count = count,
				dispelType = dispelType,
				duration = duration,
				expirationTime = expirationTime,
				source = source,
				isStealable = isStealable,
				spellId = spellId,
				castByPlayer = castByPlayer,
				}
			end
			if IsInList(debuff, jungle.rootDebuffs) then
				unitCache[friend].auras.debuffs.root[debuff] = {
				count = count,
				dispelType = dispelType,
				duration = duration,
				expirationTime = expirationTime,
				source = source,
				isStealable = isStealable,
				spellId = spellId,
				castByPlayer = castByPlayer,
				}
			end
			if IsInList(debuff, jungle.freedomDebuffs) then
				unitCache[friend].auras.debuffs.freedom[debuff] = {
				count = count,
				dispelType = dispelType,
				duration = duration,
				expirationTime = expirationTime,
				source = source,
				isStealable = isStealable,
				spellId = spellId,
				castByPlayer = castByPlayer,
				}
			end
				if UnitIsUnit(friend, 'player') then
					if IsInList(debuff, jungle.stunDebuffs) then -- all stuns
						unitCache[friend].auras.debuffs.freedomStun[debuff] = {
						count = count,
						dispelType = dispelType,
						duration = duration,
						expirationTime = expirationTime,
						source = source,
						isStealable = isStealable,
						spellId = spellId,
						castByPlayer = castByPlayer,
					}
					end
				elseif IsInList(debuff, jungle.physStunDebuffs) then -- only non dispellable stuns for retri freedom
					unitCache[friend].auras.debuffs.freedomStun[debuff] = {
					count = count,
					dispelType = dispelType,
					duration = duration,
					expirationTime = expirationTime,
					source = source,
					isStealable = isStealable,
					spellId = spellId,
					castByPlayer = castByPlayer,				
				}
				end
			if IsInList(debuff, jungle.stunDebuffs) then
				unitCache[friend].auras.debuffs.stun[debuff] = {
				count = count,
				dispelType = dispelType,
				duration = duration,
				expirationTime = expirationTime,
				source = source,
				isStealable = isStealable,
				spellId = spellId,
				castByPlayer = castByPlayer,
				}
			end
			if IsInList(debuff, jungle.healDebuffs) then
				unitCache[friend].auras.debuffs.heal[debuff] = {
				count = count,
				dispelType = dispelType,
				duration = duration,
				expirationTime = expirationTime,
				source = source,
				isStealable = isStealable,
				spellId = spellId,
				castByPlayer = castByPlayer,
				}
			end
			if IsInList(debuff, jungle.healDebuffs) then
				unitCache[friend].auras.debuffs.heal[debuff] = {
				count = count,
				dispelType = dispelType,
				duration = duration,
				expirationTime = expirationTime,
				source = source,
				isStealable = isStealable,
				spellId = spellId,
				castByPlayer = castByPlayer,
				}
			end
		i = i + 1
		else
		i = 0
		end
	end

	-- Check for buffs
	while j > 0 do
		if unitBuff ~= nil then
			local buff = unitBuff.name
			local count = unitBuff.charges
			local dispelType = unitBuff.dispelName
			local duration = unitBuff.duration
			local expirationTime = unitBuff.expirationTime
			local source = unitBuff.sourceUnit
			local isStealable = unitBuff.isStealable
			local spellId = unitBuff.spellId
			local castByPlayer = unitBuff.isFromPlayerOrPlayerPet
			if source == 'player' then
				unitCache[friend].auras.buffs.player[buff] = {
				count = count,
				dispelType = dispelType,
				duration = duration,
				expirationTime = expirationTime,
				source = source,
				isStealable = isStealable,
				spellId = spellId,
				castByPlayer = castByPlayer,

				}
				if buff == 'Beacon of Light' then
					BEACONED_FRIEND = friend
				end
			else
				unitCache[friend].auras.buffs.nonplayer[buff] = {
				count = count,
				dispelType = dispelType,
				duration = duration,
				expirationTime = expirationTime,
				source = source,
				isStealable = isStealable,
				spellId = spellId,
				castByPlayer = castByPlayer,
				}
			end
			if IsInList(buff, jungle.slowImmunityBuffs) then
				unitCache[friend].auras.buffs.slowImmunity[buff] = {
				count = count,
				dispelType = dispelType,
				duration = duration,
				expirationTime = expirationTime,
				source = source,
				isStealable = isStealable,
				spellId = spellId,
				castByPlayer = castByPlayer,
				}
			end
		j = j + 1
		else
		j = 0
		end
	end
	return unitAuras
end
]]

local function debuffParse(unit)
	AuraUtil.ForEachAura(unit, "HARMFUL", nil, function(debuff, _, count, dispelType, duration, expirationTime, source, isStealable, _, spellId, _, _, castByPlayer, ...)
		if IsInList(debuff, jungle.unitIgnoreDebuffs) then
			unitCache[unit].auras.debuffs.unitIgnore[debuff] = {
			count = count,
			dispelType = dispelType,
			duration = duration,
			expirationTime = expirationTime,
			source = source,
			isStealable = isStealable,
			spellId = spellId,
			castByPlayer = castByPlayer,
			}
		end	
		if dispelType == 'Magic' then
			unitCache[unit].auras.debuffs.magic[debuff] = {
			count = count,
			dispelType = dispelType,
			duration = duration,
			expirationTime = expirationTime,
			source = source,
			isStealable = isStealable,
			spellId = spellId,
			castByPlayer = castByPlayer,
			}
		end						
		if dispelType == 'Curse' then
			unitCache[unit].auras.debuffs.curse[debuff] = {
			count = count,
			dispelType = dispelType,
			duration = duration,
			expirationTime = expirationTime,
			source = source,
			isStealable = isStealable,
			spellId = spellId,
			castByPlayer = castByPlayer,
			}
		end						
		if dispelType == 'Poison' then
			unitCache[unit].auras.debuffs.poison[debuff] = {
			count = count,
			dispelType = dispelType,
			duration = duration,
			expirationTime = expirationTime,
			source = source,
			isStealable = isStealable,
			spellId = spellId,
			castByPlayer = castByPlayer,
			}
		end						
		if dispelType == 'Disease' then
			unitCache[unit].auras.debuffs.disease[debuff] = {
			count = count,
			dispelType = dispelType,
			duration = duration,
			expirationTime = expirationTime,
			source = source,
			isStealable = isStealable,
			spellId = spellId,
			castByPlayer = castByPlayer,
			}
		end						
		if IsInList(debuff, jungle.slowDebuffs) then
			unitCache[unit].auras.debuffs.slow[debuff] = {
			count = count,
			dispelType = dispelType,
			duration = duration,
			expirationTime = expirationTime,
			source = source,
			isStealable = isStealable,
			spellId = spellId,
			castByPlayer = castByPlayer,
			}
		end
		if IsInList(debuff, jungle.rootDebuffs) then
			unitCache[unit].auras.debuffs.root[debuff] = {
			count = count,
			dispelType = dispelType,
			duration = duration,
			expirationTime = expirationTime,
			source = source,
			isStealable = isStealable,
			spellId = spellId,
			castByPlayer = castByPlayer,
			}
		end
		if IsInList(debuff, jungle.toFreedomDebuffs) then
			unitCache[unit].auras.debuffs.freedom[debuff] = {
			count = count,
			dispelType = dispelType,
			duration = duration,
			expirationTime = expirationTime,
			source = source,
			isStealable = isStealable,
			spellId = spellId,
			castByPlayer = castByPlayer,
			}
		end
	end)
end

local function buffParse(unit)
	AuraUtil.ForEachAura(unit, "HELPFUL", nil, function(buff, _, count, dispelType, duration, expirationTime, source, isStealable, _, spellId, _, _, castByPlayer, ...)
		if source == 'player' then
				unitCache[unit].auras.buffs.player[buff] = {
				count = count,
				dispelType = dispelType,
				duration = duration,
				expirationTime = expirationTime,
				source = source,
				isStealable = isStealable,
				spellId = spellId,
				castByPlayer = castByPlayer,

				}
				if buff == 'Beacon of Light' then
					BEACONED_unit = unit
				end
			else
				unitCache[unit].auras.buffs.nonplayer[buff] = {
				count = count,
				dispelType = dispelType,
				duration = duration,
				expirationTime = expirationTime,
				source = source,
				isStealable = isStealable,
				spellId = spellId,
				castByPlayer = castByPlayer,
				}
		end
		if IsInList(buff, jungle.slowImmunityBuffs) then
			unitCache[unit].auras.buffs.slowImmunity[buff] = {
			count = count,
			dispelType = dispelType,
			duration = duration,
			expirationTime = expirationTime,
			source = source,
			isStealable = isStealable,
			spellId = spellId,
			castByPlayer = castByPlayer,
			}
		end
		if IsInList(buff, jungle.unitIgnoreBuffCaster) then
			unitCache[unit].auras.buffs.unitIgnoreIfYouCaster[buff] = {
			count = count,
			dispelType = dispelType,
			duration = duration,
			expirationTime = expirationTime,
			source = source,
			isStealable = isStealable,
			spellId = spellId,
			castByPlayer = castByPlayer,
			}
		end
		if IsInList(buff, jungle.unitIgnoreBuffPhys) then
			unitCache[unit].auras.buffs.unitIgnoreIfYouPhys[buff] = {
			count = count,
			dispelType = dispelType,
			duration = duration,
			expirationTime = expirationTime,
			source = source,
			isStealable = isStealable,
			spellId = spellId,
			castByPlayer = castByPlayer,
			}
		end
	end)
end

local function auraParser(unit)
	debuffParse(unit)
	buffParse(unit)
	return unitAuras
end



local function cacheUnitData(unit, _identificator)
	
	unitCache[unit] = {
		identificator = _identificator,
		isMe = (UnitName(unit) == UnitName('player')),
		-- inRange = (UnitName(unit) == UnitName('player') or UnitInRange(unit)),
		-- inLoS = jungle.isTargetInLos(unit),
		isInCombat = UnitAffectingCombat(unit),
		currLife = jungle.LifePercent(unit),
		auras = {
			debuffs = {
				-- player = {}, there is no possible to have player's debuff on unitly target
				-- nonplayer= {},
				all = {},
				magic = {},
				magicExtreme = {},
				curse = {},
				curseExtreme = {},
				poison = {},
				poisonExtreme = {},
				disease = {},
				slow = {},
				root = {},
				freedom = {},
				freedomStun = {}, --like a stun remove for retri WOTLK talent
				stun = {},
				unitIgnore = {},
				heal = {},		
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
		isMainTank = GetPartyAssignment("MAINTANK", unit),
		isTank = UnitGroupRolesAssigned(unit)=='TANK',
		threatStatus = UnitThreatSituation(unit),
	}
end
jungle.cacheUnitData = cacheUnitData


local function clearCacheData(identificator)
  -- Iterate over the unitCache table
  for unitName, unitData in pairs(unitCache) do
    -- Check if the unit data's identifier is different from the current one
    if unitData.identificator ~= identificator then
      -- Remove the outdated entry
	  -- print('Remove the outdated entry:', unitName)
      unitCache[unitName] = nil
		BEACONED_FRIEND = ''
		TO_BEACON = nil
    end
  end
end


local function cacheEveryUnit(_identificator)
	local identificator = math.random(100, 999)
    local groupType
	local player = false -- with alone and in the group need to store "player" manualy
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
	
	if player
	and not UnitIsDeadOrGhost('player') then
		cacheUnitData('player', identificator)
		auraParser('player')
	end
	
    if groupType then
        for i = 1, GetNumGroupMembers() do
			if i > 25 then
				break
			end
			if UnitExists(groupType .. i)
			and not jungle.isTargetInLos(groupType .. i)
			and (UnitName(groupType .. i) == UnitName('player') or UnitInRange(groupType .. i)) -- inRange
			and not UnitIsDeadOrGhost(groupType .. i) then
				cacheUnitData(groupType .. i, identificator)
				auraParser(groupType .. i)
			end
         end
    end
	-- Cache arena units due we can hotkey target them
	if instanceType == 'arena' then
		for j = 1, 5 do
			if UnitExists('arena' .. j)
			and not jungle.isTargetInLos('arena' .. j)
			and not UnitIsDeadOrGhost('arena' .. j) 
				then
				cacheUnitData('arena' .. j, identificator)
				auraParser('arena' .. j)
			end
			-- if UnitExists('arenapet' .. j)
			-- and not jungle.isTargetInLos('arenapet' .. j)
			-- and not UnitIsDeadOrGhost('arenapet' .. j) then
				-- print('parsing', 'arenapet' .. j)
				-- cacheUnitData('arenapet' .. j, identificator)
				-- auraParser('arenapet' .. j)
			-- end
		end
	end
end


local function updateUnitsData()
  -- Update the unit data for all units in the raid or party
  cacheEveryUnit()
end
jungle.updateUnitsData = updateUnitsData


-- Function to get the number of auras for a specific unit
function GetUnitAuraCount(unit)
  if not unitCache[unit] then
    return 0
  end

  local auraCount = 0
  for _, buff in pairs(unitCache[unit].auras.buffs.player.buff) do
    for _, aura in pairs(unitCache[unit].auras.player[buff]) do
      auraCount = auraCount + 1
    end
  end

  return auraCount
end
jungle.GetUnitAuraCount = GetUnitAuraCount


local function getCacheFriend(_buff, _PLAYER)
--[[
	Get first unit from cache with buff
	]]
	for friend, unitData in pairs(jungle.unitCache) do
		if _PLAYER then
			if jungle.unitCacheBuff(friend, _buff, '_PLAYER', nil, nil) then
				return friend
			end
		else
			if jungle.unitCacheBuff(friend, _buff, nil, nil) then
				return friend
			end
		end
	end
end
jungle.getCacheFriend = getCacheFriend


-- local function getLowestLifeFriendInCombat(_lifeThreshold, _unitCondition)
  -- -- Find the unit with the lowest currLife
  -- local lowestLifeUnit = nil
  -- local lowestLife = nil
  

  -- for unitName, unitData in pairs(unitCache) do
    -- local currLife = unitData.currLife
	
	-- if  _lifeThreshold 
	-- and not _unitCondition
	-- and currLife <= _lifeThreshold
	-- and currLife <= lowestLife or lowestLife == nil then
	  -- lowestLife = currLife
	  -- lowestLifeUnit = unitName
	-- end

    -- if not _lifeThreshold
	-- and not _unitCondition
	-- and currLife <= lowestLife or lowestLife == nil then
      -- lowestLife = currLife
      -- lowestLifeUnit = unitName
    -- end
  -- end

  -- return lowestLifeUnit
 -- end
-- jungle.getLowestLifeFriendInCombat = getLowestLifeFriendInCombat


local function isUnitAvailable(_unit)
--[[
	Checks all units to cast available, checks first ignore debuffs
	for all units, then depends on your spec checks separately: enemies and friends
]]
	local _,engClass,_ = UnitClass('player')
	local mySpec = GetSpecialization()

	if UnitExists(_unit) 
	-- and not UnitIsUnit('player', _unit)
	and unitCache[_unit]
	and next(unitCache[_unit].auras.debuffs.unitIgnore)==nil
	then
		if UnitCanAttack('player', _unit)
		and (
			(engClass == "DEATHKNIGHT")
				or
			(engClass == "DRUID" and (mySpec == 1 or mySpec == 4))
				or
			(engClass == "EVOKER")
				or 
			(engClass == "MAGE")	
				or
			(engClass == "PALADIN" and mySpec == 1)
				or
			(engClass == "PRIEST")
				or
			(engClass == "SHAMAN" and (mySpec == 1 or mySpec == 3))
				or
			(engClass == "WARLOCK")
		) 
		and next(unitCache[_unit].auras.buffs.unitIgnoreIfYouCaster) == nil then
			return true
		elseif UnitCanAttack('player', _unit)
		and (
			(engClass == "WARRIOR")
				or
			(engClass == "PALADIN" and (mySpec == 2 or mySpec == 3))
				or
			(engClass == "HUNTER")
				or 
			(engClass == "ROGUE")	
				or
			(engClass == "SHAMAN" and mySpec == 2)
				or
			(engClass == "MONK")
				or
			(engClass == "DEMONHUNTER")
				or
			(engClass == "DRUID" and (mySpec == 2 or mySpec == 3))
		) 
		and next(unitCache[_unit].auras.buffs.unitIgnoreIfYouPhys) == nil then
			return true
		end
		return true
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
--[[
	Get count of friends with specific players with lifebloom
	(currently used for monitoring of 2 targets of lifebloom)
]]
	local count = 0
	local life = _life or 1
	for _, unitData in pairs(unitCache) do
		if unitData.currLife <= life
		and unitData.auras.buffs.player['Lifebloom']
			then
			count = count + 1
		end
	end
	return count
end
jungle.bloomFriendsCount = bloomFriendsCount


local function unitCacheBuff(_unit, _aura, _PLAYER, _expired, _counts)
	local _expired = _expired or 0
	local _counts = _counts or 0
	if _PLAYER then
		local auraData = unitCache[_unit].auras.buffs.player[_aura]
		if auraData then
			if (auraData.expirationTime - GetTime()) >= _expired
			and auraData.count >= _counts then
			 return true
			 end
		end
	else
		local auraData = unitCache[_unit].auras.buffs.player[_aura]
		if auraData then
			if (auraData.expirationTime - GetTime()) >= _expired
			and auraData.count >= _counts then
			 return true
			 end
		else
		local auraData = unitCache[_unit].auras.buffs.nonplayer[_aura]
		if auraData then
			if (auraData.expirationTime - GetTime()) >= _expired
			and auraData.count >= _counts then
			 return true
			 end
			end
		end
	end
	return false
end
jungle.unitCacheBuff = unitCacheBuff


local function unitDebuff(_friend, _aura, _expired, _counts)
	local _expired = _expired or 0
	local _counts = _counts or 0
		local auraData = unitCache[_friend].auras.debuffs.all[_aura]
		if auraData then
			if (auraData.expirationTime - GetTime()) >= _expired
			and auraData.count >= _counts then
			 return true
			 end
		end
	return false
end
jungle.unitDebuff = unitDebuff


local function countEntries(table)
  local count = 0

  for k, v in pairs(table) do
    if type(v) == 'table' then
      count = count + 1
    end
  end

  return count
end
jungle.countEntries = countEntries