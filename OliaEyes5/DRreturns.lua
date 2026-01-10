local Jungle, jungle = ...

local _, instanceType = IsInInstance()

local Controlled_Root_id = {
	"Deathchill",
	"Entangling Roots",
	"Mass Entanglement",
	"Landslide",
	"Entrapment",
	"Steel Trap",
	"Steelclaw Trap",
	"Tracker's Net",
	"Frost Nova",
	"Paralysis",
	"Earthgrab",
	"Super Sticky Tar",
	"Freeze",
	"Freezing Cold",
	"Frostbite",
	"Void Tendril's Grasp",
	"Tormenting Backlash",
	"Entrenched in Flame",
	"Disable",
	"Clash",
	"Thunderstruck",
	"Frost Grenade",
	"Embersilk Net",
	"Frostweave Net",
	"Hooked Deep Sea Net",
} 
jungle.Controlled_Root_id = Controlled_Root_id

local Controlled_Stun_id = {
	"Zombie Explosion",
	"Absolute Zero",
	"Asphyxiate",
	"Gnaw",
	"Monstrous Blow",
	"Dead of Winter",
	"Chaos Nova",
	"Illidan's Grasp",
	"Fel Eruption",
	"Metamorphosis",
	"Maim",
	"Rake",
	"Mighty Bash",
	"Overrun",
	"Wild Hunt's Charge",
	"Terror of the Skies",
	"Binding Shot",
	"Consecutive Concussion",
	"Intimidation",
	"Snowdrift",
	"Leg Sweep",
	"Double Barrel",
	"Exorcism",
	"Hammer of Justice",
	"Wake of Ashes",
	"Psychic Horror",
	"Holy Word: Chastise Censure",
	"Cheap Shot",
	"Static Charge",
	"Pulverize",
	"Lightning Lasso",
	"Axe Toss",
	"Meteor Strike",
	"Shadowfury",
	"Shield Charge",
	"Shockwave",
	"Storm Bolt",
	"Warpath",
	"War Stomp",
	"Bull Rush",
	"Sparkling Driftglobe Core",
}
jungle.Controlled_Stun_id = Controlled_Stun_id

local Disorient_id = {
	"Blinding Sleet", -- 207167,  -- "disorient",       -- Blinding Sleet
	"Sigil of Misery", -- 207685,  -- "disorient",       -- Sigil of Misery
	"Cyclone", -- 33786,   -- "disorient",       -- Cyclone
	"Scare Beast", -- 1513,    -- "disorient",       -- Scare Beast
	"Dragon's Breath", -- 31661,   -- "disorient",       -- Dragon's Breath
	"Song of Chi-ji", -- 198909,  -- "disorient",       -- Song of Chi-ji
	"Incendiary Brew", --  202274,  -- "disorient",       -- Incendiary Brew
	"Blinding Light", --  105421,  -- "disorient",       -- Blinding Light
	"Turn Evil", --  10326,   -- "disorient",       -- Turn Evil
	"Mind Control", --  605,     -- "disorient",       -- Mind Control
	"Psychic Scream", --   8122,    -- "disorient",       -- Psychic Scream
	"Mind Bomb", --  226943,  -- "disorient",       -- Mind Bomb
	"Blind", --   2094,    -- "disorient",       -- Blind
	"Fear", --   118699,  -- "disorient",       -- Fear
	"Howl of Terror", --  5484,    -- "disorient",       -- Howl of Terror
	"Seduction", --  261589,  -- "disorient",       -- Seduction (Grimoire of Sacrifice)
	"Intimidating Shout", --   5246,    -- "disorient",       -- Intimidating Shout 1
	"Agent of Chaos", --  331866,  -- "disorient",       -- Agent of Chaos (Venthyr Covenant)
}
jungle.Disorient_id = Disorient_id

local Incapacitate_id = {
	"Imprison",
	"Hibernate",
	"Incapacitating Roar",
	"Time Stop",
	"Freezing Trap",
	"Scatter Shot",
	"Mass Polymorph",
	"Polymorph",
	"Ring of Frost",
	"Paralysis",
	"Repentance",
	"Shackle Undead",
	"Holy Word: Chastise",
	"Gouge",
	"Sap",
	"Hex",
	"Sundering",
	"Banish",
	"Mortal Coil",
	"Quaking Palm",
}
jungle.Incapacitate_id = Incapacitate_id

local Silence_id = {
	"Strangulate",
	"Sigil of Silence",
	"Reactive Resin",
	"Spider Sting",
	"Spider Venom",
	"Wailing Arrow",
	"Shield of Virtue",
	"Silence",
	"Unstable Affliction",
	"Garrote",
	"Unstable Affliction Silence Effect",
}
jungle.Silence_id = Silence_id

local function Controlled_Root()
	local tbl = {}
	local id_tbl = Controlled_Root_id
	for i = 1, #id_tbl do
		local name, _, _, _, _, _, _, _ = GetSpellInfo(id_tbl[i])
		table.insert(tbl, name)
	end
	return tbl
end

local function Controlled_Stun()
	local tbl = {}
	local id_tbl = Controlled_Stun_id
	for i = 1, #id_tbl do
		local name, _, _, _, _, _, _, _ = GetSpellInfo(id_tbl[i])
		table.insert(tbl, name)	end
	return tbl
end

local function Disorient()
	local tbl = {}
	local id_tbl = Disorient_id
	for i = 1, #id_tbl do
		local name, _, _, _, _, _, _, _ = GetSpellInfo(id_tbl[i])
		table.insert(tbl, name)	end
	return tbl
end

local function Incapacitate()
	local tbl = {}
	local id_tbl = Incapacitate_id
	for i = 1, #id_tbl do
		local name, _, _, _, _, _, _, _ = GetSpellInfo(id_tbl[i])
		table.insert(tbl, name)	end
	return tbl
end

local function Silence()	
	local tbl = {}
	local id_tbl = Silence_id
	for i = 1, #id_tbl do
		local name, _, _, _, _, _, _, _ = GetSpellInfo(id_tbl[i])
		table.insert(tbl, name)	end
	return tbl
end

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
	local isFound = false
	for i=#_table, 1, -1 do -- from last nested table
		for j=#_table[i], 1, -1 do
			if _target == _table[i][j]['unit'] then
				isFound = true
				if type(_table[i+1]) == 'table' then -- if next table exists
					table.insert(_table[i+1], { t=GetTime(), unit=_target } ) -- add to next table
					-- print('incerted ['.._target..'] to: ', 'table['..(i+1)..']') break
				elseif type(_table[i+1]) ~= 'table' then
					table.insert(_table[i], { t=GetTime(), unit=_target } ) -- add to current table
					-- print('incerted ['.._target..'] to: ', 'table['..i..']') break
				end	
			end	
		end	
	end
	if isFound == false then
		table.insert(_table[1], { t=GetTime(), unit=_target } ) return -- add to first table
		-- print('incerted ['.._target..'] to: ', 'table['..(1)..']')
	end
end

local function addToDRTable(_aura, _target)
	local drLists = {
		Controlled_Root_id, 
		Controlled_Stun_id,
		Disorient_id,
		Incapacitate_id,
		Silence_id,
	}
	
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
		for i=1, #_table do
			for j=1, #_table[i] do
				if #_table[i] > 0 then
					if (GetTime() - _table[i][j].t) >= _time then
						-- print('--table---')
						-- print(_table[i][j]['unit'])
						-- print('--table---')
						-- print('Removing  ['.._table[i][j].unit..'] from [table]:', i)
						table.remove (_table[i], j) return
					end
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
	for i=#_dr_table, 1, -1 do -- from last nested table
		for j=#_dr_table[i], 1, -1 do
			if fullName == _dr_table[i][j]['unit'] then
				dr = i return dr
			end
		end
	end
	return dr
end
jungle.getDR = getDR