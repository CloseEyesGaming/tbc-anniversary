local Jungle, jungle = ...

local Controlled_Root_id = {
	"Entangling Roots", -- 339, 1062, 5195, 5196, 9852, 9853, 26989
	"Nature's Grasp", -- 19975, 19974, 19973, 19972, 19971, 19970, 27010
	"Frost Nova", -- 122, 865, 6131, 10230, 27088
	"Freeze", -- 33395
	"Frost Grenade", -- 39965
	"Entrapment", -- 19185
	"Improved Wing Clip", -- 19229
	"Frostbite", -- 12494
	"Improved Hamstring", -- 23694
} 
jungle.Controlled_Root_id = Controlled_Root_id

local Controlled_Stun_id = {
	"Bash", -- 5211, 6798, 8983
	"Pounce", -- 9005, 9823, 9827, 27006
	"Intimidation", -- 24394
	"Hammer of Justice", -- 853, 5588, 5589, 10308
	"Cheap Shot", -- 1833
	"Shadowfury", -- 30283, 30413, 30414
	"Concussion Blow", -- 12809
	"Charge Stun", -- 7922
	"Intercept Stun", -- 20253, 20614, 20615, 25273, 25274
	"War Stomp", -- 20549
	"Goblin Mortar", -- 13237
	"Tidal Charm", -- 835
	"Celestial Focus", -- 16922
	"Improved Concussive Shot", -- 19410
	"Impact", -- 12355
	"Seal of Justice Stun", -- 20170
	"Blackout", -- 15269
	"Pyroclasm", -- 18093
	"Stoneclaw Stun", -- 39796
	"Revenge Stun", -- 12798
	"Mace Stun Effect", -- 5530
	"Stunning Blow", -- 15283
	"Stun", -- 56
	"Stormherald/Deep Thunder", -- 34510
	"Kidney Shot", -- 408, 8643
}
jungle.Controlled_Stun_id = Controlled_Stun_id

local Disorient_id = {
	"Cyclone", -- 33786
	"Blind", -- 2094
	"Scare Beast", -- 1513, 14326, 14327
	"Turn Evil", -- 10326
	"Psychic Scream", -- 8122, 8124, 10888, 10890
	"Fear", -- 5782, 6213, 6215
	"Seduction", -- 6358
	"Howl of Terror", -- 5484, 17928
	"Intimidating Shout", -- 5246
	"Flash Bomb Fear", -- 5134
	"Mind Control", -- 605, 10911, 10912
	"Gnomish Mind Control Cap", -- 13181
	"Death Coil", -- 6789, 17925, 17926, 27223
}
jungle.Disorient_id = Disorient_id

local Incapacitate_id = {
	"Hibernate", -- 2637, 18657, 18658
	"Maim", -- 22570
	"Freezing Trap Effect", -- 3355, 14308, 14309
	"Wyvern Sting", -- 19386, 24132, 24133, 27068
	"Polymorph", -- 118, 12824, 12825, 12826
	"Polymorph: Turtle", -- 28271
	"Polymorph: Pig", -- 28272
	"Repentance", -- 20066
	"Sap", -- 6770, 2070, 11297
	"Gouge", -- 1776, 1777, 8629, 11285, 11286, 38764
	"Banish", -- 710, 18647
	"Reckless Charge", -- 13327
	"Rough Copper Bomb", -- 4064
	"Large Copper Bomb", -- 4065
	"Small Bronze Bomb", -- 4066
	"Big Bronze Bomb", -- 4067
	"Iron Grenade", -- 4068
	"Mithril Frag Bomb", -- 12421
	"Big Iron Bomb", -- 4069
	"The Big One", -- 12562
	"Hi-Explosive Bomb", -- 12543
	"Thorium Grenade", -- 19769
	"Dark Iron Bomb", -- 19784
	"Fel Iron Bomb", -- 30216
	"The Bigger One", -- 30461
	"Adamantite Grenade", -- 30217
	"Scatter Shot", -- 19503
	"Dragon's Breath", -- 31661, 33041, 33042, 33043
	"Counterattack", -- 19306, 20909, 20910, 27067
	"Chastise", -- 44041, 44043, 44044, 44045, 44046, 44047
	"Unstable Affliction", -- 43523, 31117
}
jungle.Incapacitate_id = Incapacitate_id

local Silence_id = {
	"Silence", -- 15487
	"Spell Lock", -- 24259
	"Garrote", -- 1330
	"Silenced - Improved Counterspell", -- 18469, 55021
	"Arcane Torrent", -- 50613, 28730, 25046
	"Unstable Affliction", -- 43523, 31117
}
jungle.Silence_id = Silence_id

local DR_RESET_TIME = 18
local drLists = {
	Controlled_Root_id,
	Controlled_Stun_id,
	Disorient_id,
	Incapacitate_id,
	Silence_id,
}

--[[
	{{}, {}, {}}
	first subtable - dr 50%
	second subtable - dr 75%
	third subtable - immune
	
	Always need check from last table, coz of priority
]]--
Controlled_Root_table = {{}, {}, {}}
Controlled_Stun_table = {{}, {}, {}}
Disorient_table = {{}, {}, {}}
Incapacitate_table = {{}, {}, {}}
Silence_table = {{}, {}, {}}

function getDRTableIfo(tab)
	-- print('-----------------')
	for i=1, #tab do
		for j=1, #tab[i] do
			if i == 1 then
				-- print('table_1: ', tab[i][j].t, tab[i][j].unit)
			elseif i ==2 then
				-- print('table_2: ', tab[i][j].t, tab[i][j].unit)
			elseif i ==3 then
				-- print('table_3: ', tab[i][j].t, tab[i][j].unit)
			end
		end
	end
	-- print('-----------------')
end
jungle.getDRTableIfo = getDRTableIfo


local function subTableAdd(_table, _target)
--[[
	Always need check from last table, coz of priority	
]]--
	local now = GetTime()
	-- Physical cleanup is throttled, so remove expired entries before using the
	-- table to advance a new DR application.
	for i=1, #_table do
		for j=#_table[i], 1, -1 do
			if (now - _table[i][j].t) >= DR_RESET_TIME then
				table.remove(_table[i], j)
			end
		end
	end

	local isFound = false
	for i=#_table, 1, -1 do -- from last nested table
		for j=#_table[i], 1, -1 do
			if _target == _table[i][j]['unit'] then
				isFound = true
				if type(_table[i+1]) == 'table' then -- if next table exists
					table.insert(_table[i+1], { t=now, unit=_target } ) -- add to next table
					-- print('incerted ['.._target..'] to: ', 'table['..(i+1)..']') break
				elseif type(_table[i+1]) ~= 'table' then
					table.insert(_table[i], { t=now, unit=_target } ) -- add to current table
					-- print('incerted ['.._target..'] to: ', 'table['..i..']') break
				end	
			end	
		end	
	end
	if isFound == false then
		table.insert(_table[1], { t=now, unit=_target } ) return -- add to first table
		-- print('incerted ['.._target..'] to: ', 'table['..(1)..']')
	end
end

local function addToDRTable(_aura, _target)
	for _, list in ipairs(drLists) do
	  for _, v in pairs(list) do
		if v == _aura then
			if list == Controlled_Root_id then
				subTableAdd(Controlled_Root_table, _target)
			elseif list == Controlled_Stun_id then
				subTableAdd(Controlled_Stun_table, _target)
			elseif list == Disorient_id then
				subTableAdd(Disorient_table, _target)
			elseif list == Incapacitate_id then
				subTableAdd(Incapacitate_table, _target)
			elseif list == Silence_id then
				subTableAdd(Silence_table, _target)
			-- elseif list == Scatter_id then
				-- subTableAdd(Scatter_table, _target)
			end
		end
	 end
	end
end

local function subTableTimerRemove(_table, _time)
--[[
	_table - special table with nested tables, timeStamp: unit
	_time - int, how long target must be in table in seconds
]]--
		local now = GetTime()
		for i=1, #_table do
			for j=#_table[i], 1, -1 do
				if (now - _table[i][j].t) >= _time then
					table.remove(_table[i], j)
				end
			end
		end
end
jungle.subTableTimerRemove = subTableTimerRemove

local f = CreateFrame("Frame")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:SetScript("OnEvent", function(self, event)
	self:COMBAT_LOG_EVENT_UNFILTERED(CombatLogGetCurrentEventInfo())
end)

function f:COMBAT_LOG_EVENT_UNFILTERED(...)
	local _, instanceType = IsInInstance()
	if (instanceType == 'pvp' or instanceType == 'arena') and GetNumGroupMembers() <= 15 then
		local _, arg2, _, _, _, _, _, _, _, _, _ = ...
		if arg2 == "SPELL_AURA_APPLIED" then
			local _,_,_,_,_,_,_,_,arg9,_,_,_, arg13, _ = ...
			addToDRTable(arg13, arg9) -- arg9(Unit name), arg13(Spell name)
		end
	end
end

local function getDR(_target, _dr_table)
	local name, realm = UnitName(_target)
	local fullName
		if name and realm then
			fullName = name..'-'..realm
		else
			fullName = name
		end
	local dr = 0
	local now = GetTime()
	for i=#_dr_table, 1, -1 do -- from last nested table
		for j=#_dr_table[i], 1, -1 do
			if fullName == _dr_table[i][j]['unit']
			and (now - _dr_table[i][j].t) < DR_RESET_TIME then
				dr = i return dr
			end
		end
	end
	return dr
end
jungle.getDR = getDR
