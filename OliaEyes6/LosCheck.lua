local Jungle, jungle = ...

-- Hook 'target' or 'focus', depends on rotation type: dpsRotate()/rotate()
LOS_CONTEXT_TARGET = ''

local frame = CreateFrame("Frame")
-- When the frame is shown, reset the update timer
frame:SetScript("OnShow", function(self)
	TimeSinceLastUpdate = 0
end)

 LoSTable = { }
 UnitBehindTable = { }
 UnitInFrontTable = { }

function getTableIfo(tab)
		print('-----------------')
		for i=1, #tab do
			print(tab[i].t, tab[i].unit)
			print('In Los: ', tab[i].unit)
		end
		print('-----------------')
end
jungle.getTableIfo = getTableIfo


-- local function getUnitIndex(unit)
	-- if UnitIsFriend("player", unit) then
		-- if UnitExists('raid1') then
			-- for i=1, GetNumGroupMembers() do
				-- if UnitIsUnit(unit, 'raid'..i) then
					-- return 'raid'..i
				-- end
			-- end
		-- end
		-- if not UnitExists('raid1') and UnitExists('party1') then
			-- for i=1, GetNumGroupMembers() do
				-- if UnitIsUnit(unit, 'party'..i) then
					-- return 'party'..i
				-- end
			-- end
		-- end
	-- elseif not UnitIsFriend("player", unit) then
		-- for i=1, 5 do
			-- if UnitIsUnit(unit, 'arena'..i) then
				-- return 'arena'..i
			-- elseif UnitIsUnit(unit, 'arenapet'..i) then
				-- return 'arenapet'..i
			-- end
		-- end
		-- if LOS_CONTEXT_TARGET == 'target'
		-- and UnitIsUnit(unit, 'target') then
			-- return 'target'
		-- elseif LOS_CONTEXT_TARGET == 'focus'
		-- and UnitIsUnit(unit, 'focus') then
			-- return 'focus'
		-- end
	-- end
-- end
-- jungle.getUnitIndex = getUnitIndex


frame:RegisterEvent'UI_ERROR_MESSAGE'
frame:SetScript('OnEvent', function(self, event, _, msg)
	-- if (instanceType == 'pvp' or instanceType == 'arena') and GetNumGroupMembers() <= 15 then
				-- print(msg) -- for debug any msg
		if LOS_CONTEXT_TARGET == 'focus' then
			if msg == 'Target not in line of sight'
			and UnitExists(LOS_CONTEXT_TARGET)
			and not UnitIsUnit(LOS_CONTEXT_TARGET, 'player') then
				table.insert(LoSTable, { t=GetTime(), unit=UnitName(LOS_CONTEXT_TARGET) } )
				-- print('table.insert', 'LoSTable', GetTime(), UnitName(LOS_CONTEXT_TARGET))
			elseif msg == 'Target needs to be in front of you.'
			and UnitExists(LOS_CONTEXT_TARGET)
			and not UnitIsUnit(LOS_CONTEXT_TARGET, 'player') then
				table.insert(UnitBehindTable, { t=GetTime(), unit=UnitName(LOS_CONTEXT_TARGET) } )					
			elseif msg == 'You must be behind your target.'
			and UnitExists(LOS_CONTEXT_TARGET)
			and not UnitIsUnit(LOS_CONTEXT_TARGET, 'player') then
				table.insert(UnitInFrontTable, { t=GetTime(), unit=UnitName(LOS_CONTEXT_TARGET) } )					
			end
		elseif LOS_CONTEXT_TARGET == 'target' then
			if msg == 'Target not in line of sight' then
				table.insert(LoSTable, { t=GetTime(), unit=UnitName(LOS_CONTEXT_TARGET) } )	
				-- print('table.insert', 'LoSTable', GetTime(), UnitName(LOS_CONTEXT_TARGET))					
			elseif msg == 'Target needs to be in front of you.'
			and UnitExists(LOS_CONTEXT_TARGET)
			and not UnitIsUnit(LOS_CONTEXT_TARGET, 'player') then
				table.insert(UnitBehindTable, { t=GetTime(), unit=UnitName(LOS_CONTEXT_TARGET) } )					
			elseif msg == 'You must be behind your target.'
			and UnitExists(LOS_CONTEXT_TARGET)
			and not UnitIsUnit(LOS_CONTEXT_TARGET, 'player') then
				table.insert(UnitInFrontTable, { t=GetTime(), unit=UnitName(LOS_CONTEXT_TARGET) } )					
			end
	end
end)


local frame = CreateFrame("Frame")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:SetScript("OnEvent", OnEvent)


local function TableTimerRemove(_table, _time)
--[[
	_table - special global table with timeStamp: unit
	_time - int, how long target must be in table in seconds
	]]
	-- if (instanceType == 'pvp' or instanceType == 'arena') and GetNumGroupMembers() <= 15 then
		if #_table > 0 then
			for i=#_table, 1, -1 do
				if (GetTime() - _table[i].t) >= _time then
					-- print('--table---')
					-- print(_table[1]['unit'])
					-- print('--table---')
					-- print('Removing: ', _table[i].unit)
					table.remove (_table, i)
				end
			end
		end
	-- end
end
jungle.TableTimerRemove = TableTimerRemove


local function isTargetInLos(_target)
-- if (instanceType == 'pvp' or instanceType == 'arena') and GetNumGroupMembers() <= 15 then
	if UnitExists(_target) then
		for _, value in ipairs(LoSTable) do
		-- and UnitExists(value.unit)
			if UnitName(_target) == value.unit then
			-- print('isTargetInLos:', UnitName(_target), '=', value.unit, UnitName(_target) == value.unit)
				return true 
			end
		end
-- end
    return false
	end
end
jungle.isTargetInLos = isTargetInLos


local function isTargetBehind(_target)
		for _, value in ipairs(UnitBehindTable) do
			if UnitExists(_target)
			and UnitExists(value.unit)
			and UnitIsUnit(value.unit, _target) then
				return true 
			end
		end
    return false
end
jungle.isTargetBehind = isTargetBehind


local function isTargetFront(_target)
		for _, value in ipairs(UnitInFrontTable) do
			if UnitExists(_target)
			and UnitExists(value.unit)
			and UnitIsUnit(value.unit, _target) then
				return true 
			end
		end
    return false
end
jungle.isTargetFront = isTargetFront