local Jungle, jungle = ...


-- TBC 2.4.3 NPC names with spell-school immunity. These are name sets because
-- the Classic API does not expose an NPC's SchoolImmuneMask to addons.
-- Hydross changes immunity with his form; name-only validation deliberately
-- blocks Nature damage in both forms rather than risking casts in Tainted form.
local function BuildUnitNameSet(names)
	local set = {}
	for i = 1, #names do
		set[names[i]] = true
	end
	return set
end

local natureDamageImmuneTargetNames = BuildUnitNameSet({
	"Rock Elemental",
	"Earth Elemental",
	"Dust Devil",
	"Earth Miser",
	"Stone Fury",
	"Elemental Slave",
	"Brutus",
	"Rumbling Exile",
	"Rough Stone Elemental",
	"Lesser Rock Elemental",
	"Greater Rock Elemental",
	"Rumbler",
	"Thundering Exile",
	"Enraged Rock Elemental",
	"Fam'retor Guardian",
	"Skum",
	"Enraged Stone Spirit",
	"Furious Stone Spirit",
	"Thundering Boulderkin",
	"Rok'Alim the Pounder",
	"Wind Howler",
	"Stone Rumbler",
	"Gelkis Rumbler",
	"Phantim",
	"Gnarl Leafbrother",
	"Land Rager",
	"Shade of Eranikus",
	"Rothos",
	"Morphaz",
	"Weaver",
	"Dreamscythe",
	"Hazzas",
	"Margol the Rager",
	"Magma Elemental",
	"Minor Manifestation of Earth",
	"Air Spirit",
	"Minor Manifestation of Air",
	"Cyclonian",
	"Vile Ooze",
	"Toxic Horror",
	"Felcular",
	"Smoldar",
	"Atal'ai Deathwalker's Spirit",
	"Gusting Vortex",
	"Swirling Vortex",
	"Living Storm",
	"Risen Aberration",
	"Branch Snapper",
	"Molten Elemental",
	"Whirlwind Ripper",
	"Whirlwind Stormwalker",
	"Whirlwind Shredder",
	"Dust Stormer",
	"Cyclone Warrior",
	"Shadowshard Rumbler",
	"Shadowshard Smasher",
	"Ambershard Crusher",
	"Ambershard Destroyer",
	"Theradrim Shardling",
	"Theradrim Guardian",
	"Ambereye Basilisk",
	"Ambereye Reaver",
	"Princess Theradras",
	"Meshlok the Harvester",
	"Blackwing Spellbinder",
	"Dreamtracker",
	"Dreamstalker",
	"Whip Lasher",
	"Massive Geyser",
	"Prince Thunderaan",
	"The Windreaver",
	"Whirling Invader",
	"Thundering Invader",
	"Avalanchion",
	"Huricanian",
	"Ysondre",
	"Lethon",
	"Emeriss",
	"Taerar",
	"Emperor Vek'nilash",
	"Shade of Taerar",
	"Greater Earth Elemental",
	"Magma Lord Bokk",
	"Spectral Trainee",
	"Spectral Deathknight",
	"Spectral Horse",
	"Spectral Rider",
	"Mana Feeder",
	"Plague Slime (Green)",
	"Aeranas",
	"Muck Spawn",
	"Tortured Earth Spirit",
	"Shattered Rumbler",
	"Dust Howler",
	"Storm Rager",
	"Living Cyclone",
	"Enraged Crusher",
	"Minion of Gurok",
	"Gurok the Usurper",
	"Rokdar the Sundered Lord",
	"Sundered Rumbler",
	"Sundered Thunderer",
	"Raging Flames",
	"Sundered Shard",
	"Akkiris Lightning-Waker",
	"Enraged Earth Spirit",
	"Enraged Air Spirit",
	"Hydross the Unstable",
	"Tainted Water Elemental",
	"Corrupted Air Elemental",
	"Corrupted Earth Elemental",
	"Tainted Spawn of Hydross",
	"Enraged Earth Shard",
	"Rotting Forest-Rager",
	"Storming Wind-Ripper",
	"Rumbling Earth-Heart",
	"Talonsworn Forest-Rager",
	"Shadowy Construct",
	"Promenade Sentinel",
})
jungle.natureDamageImmuneTargetNames = natureDamageImmuneTargetNames

local arcaneDamageImmuneTargetNames = BuildUnitNameSet({
	"Azuregos",
	"Mana Surge",
	"Occulus",
	"Chronalis",
	"Tick",
	"Atal'ai Deathwalker's Spirit",
	"Azurous",
	"Risen Aberration",
	"Spellmaw",
	"Manaclaw",
	"Scryer",
	"Arcane Aberration",
	"Mana Remnant",
	"Residual Monstrosity",
	"Blackwing Spellbinder",
	"Mana Burst",
	"Arcane Torrent",
	"Arcane Feedback",
	"Emperor Vek'nilash",
	"Mana Fiend",
	"The Curator",
	"Spectral Trainee",
	"Spectral Deathknight",
	"Spectral Horse",
	"Spectral Rider",
	"Arcane Anomaly",
	"Mana Feeder",
	"Mana Warp",
	"Eldinarcus",
	"Mana Wraith",
	"Warp Aberration",
	"Mageslayer",
	"Mana Seeker",
	"Syth Arcane Elemental",
	"Raging Flames",
	"Warp Monstrosity",
	"Dreadwing",
	"Mana Beast",
	"Arcane Burst",
	"Unbound Ethereal",
	"Shadowy Construct",
})
jungle.arcaneDamageImmuneTargetNames = arcaneDamageImmuneTargetNames

local natureDamageSpells = {
	["Insect Swarm"] = true,
	["Wrath"] = true,
}

local arcaneDamageSpells = {
	["Starfire"] = true,
	["Moonfire"] = true,
}

local function IsTargetImmuneToDruidDamageSpell(spell, target)
	if not spell or not target then return false end

	local immuneTargetNames
	if natureDamageSpells[spell] then
		immuneTargetNames = natureDamageImmuneTargetNames
	elseif arcaneDamageSpells[spell] then
		immuneTargetNames = arcaneDamageImmuneTargetNames
	else
		return false
	end

	local targetName = UnitName(target)
	return targetName and immuneTargetNames[targetName] == true or false
end
jungle.IsTargetImmuneToDruidDamageSpell = IsTargetImmuneToDruidDamageSpell
