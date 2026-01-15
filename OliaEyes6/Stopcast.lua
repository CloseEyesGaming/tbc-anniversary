local Jungle, jungle = ...

--[[
	Extdends default CastGUID with desired UnitGUID
	]]
local currentSpellGUID = nil
local myFrame = CreateFrame("Frame");
local myCurrentCast;
myFrame:RegisterEvent("UNIT_SPELLCAST_SENT");
myFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED");
myFrame:SetScript("OnEvent",
    function(self, event, arg1, arg2, arg3, arg4)
        if (event == "UNIT_SPELLCAST_SENT" and arg1 == "player") then
			if UnitExists('focus') then
				currentSpellGUID = arg3..'-'..UnitGUID('focus')
			else
				currentSpellGUID = arg3..'-'..UnitGUID('player')
			end
            -- print("I am casting something", currentSpellGUID);
        end
    end
);


local function unlitGUID2unitID(GUID)
--[[
	Converts any players UnitGUID to UnitID, based on jungle.allFriends()
	]]
	for i, unit in ipairs(jungle.activeFriends()) do
		if UnitGUID(unit) == GUID then
			return unit
		end
	end
end
jungle.unlitGUID2unitID = unlitGUID2unitID


local function specialNoStop(_spell, _target)
--[[
	Additional checks when no need to stop cast
	return true - there is no stop casting
	return false - pass
	]]
	local result = false
	local name, text, texture, startTimeMS, endTimeMS, isTradeSkill, castID, spellId = UnitCastingInfo('player')
	
	-- do not stop cast if casting on active tank without hots
	if UnitExists(_target)
	and GetUnitSpeed('player')==0 
	and name == _spell
	and UnitAffectingCombat(_target)
	and GetPartyAssignment("MAINTANK", _target)
	and (jungle.targetedByCount(_target)>=1 or jungle.isTanking(_target))
	and not jungle.Buff("Regrowth", _target, "|PLAYER")
	and not jungle.Buff("Lifebloom", _target, "|PLAYER") then
		result = true
	end
	
	-- do not stop cast if casting on mosttargeted
	if UnitExists(_target)
	and GetUnitSpeed('player')==0 
	and name == _spell
	and UnitAffectingCombat(_target)
	and not GetPartyAssignment("MAINTANK", _target)
	and (jungle.targetedByCount(_target)>=1 or jungle.isTanking(_target))
	and not jungle.Buff("Regrowth", _target, "|PLAYER")
	then
		result = true
	end
	
	return result
end


local function CurrentCastStoP(_spell, _life, pix)
--[[Stop current cast depending on desired unit(only players) status
	coloring pixel
	_spell: spell to trigger (str)
	_target: UnitID (str)
	_life: [0:1] life treshold (float/Integer)
	_pix: desired pixel to color (str)
	]]
	currentSpellGUID = currentSpellGUID or nil
	local name, text, texture, startTimeMS, endTimeMS, isTradeSkill, castID, spellId = UnitCastingInfo('player')
	if UnitCastingInfo('player') 
	and currentSpellGUID then
		local _, _, _, _, _, spellID, castID, unitType, realmID, destTarget = strsplit("-", currentSpellGUID)
		local desiredUnitGUID = unitType..'-'..realmID..'-'..destTarget
		local desiredUnitID = jungle.unlitGUID2unitID(desiredUnitGUID)
		local currSpell = C_Spell.GetSpellInfo(spellID)
		if _spell == currSpell 
		and UnitExists(desiredUnitID)
		and specialNoStop(currSpell, desiredUnitID)==false then
			--do conditions suff:
			if not GetPartyAssignment("MAINTANK", desiredUnitID) 
			and jungle.LifePercent(desiredUnitID) >= _life
			and (endTimeMS/1000 - GetTime())<=0.9 then
				local color = jungle.Color:new()
				local stopColor = color:makeColor('Stopcasting')
				local pixel = jungle.Pixel:new(stopColor, pix)
				if jungle.isDebug then
					print('Stopcast: ', currSpell, '->', desiredUnitID, jungle.LifePercent(desiredUnitID))
				end
				return pixel:set()
			end
			--^^do conditions suff:
		
		elseif not UnitCastingInfo('player') or currentSpellGUID==nil then
			if jungle.isDebug then
				print('No current cast!')
			end
			currentSpellGUID = nil
		end
	end
end
jungle.CurrentCastStoP = CurrentCastStoP

