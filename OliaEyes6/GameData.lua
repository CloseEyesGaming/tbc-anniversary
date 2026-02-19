local Jungle, jungle = ...


local slowDebuffs = {

}
jungle.slowDebuffs = slowDebuffs

local rootDebuffs = {

}
jungle.rootDebuffs = rootDebuffs

local toFreedomDebuffs = {

}
jungle.toFreedomDebuffs = toFreedomDebuffs

local healDebuffs = {
    -- [[ PRIORITY HEAL DEBUFFS ]]
    -- Add debuffs here that require immediate healing attention (e.g. Mortal Strike)
    "Mortal Strike",
	"Wound Poison",
	"Curse of Tongues",
	"Fear",
	"Silence",
}
jungle.healDebuffs = healDebuffs

local slowImmunityBuffs = {
	"Master's Call",
	"Cauterize",
	"Blessing of Freedom",
	"Blessing of Protection",
	"Dispersion",
	"Bladestorm",
}
jungle.slowImmunityBuffs = slowImmunityBuffs

local unitIgnoreDebuffs = {
	"Cyclone",
	"Banish",
	"Enfeeble",
	"Chains of Kel'Thuzad",
	"Shadowy Duel",
}
jungle.unitIgnoreDebuffs = unitIgnoreDebuffs

local unitIgnoreBuffCaster = {
	"Cloak of Shadows",
	"Anti-Magic Shield",
	"Rain from Above",
	"Ice Block",
	"Diffuse Magic",
	"Life Cocoon",
	"Guardian of the Forgotten Queen",
	"Phase Shift",
	"Divine Ascension",
	"Burrow",
	"Aspect of the Turtle",
}
jungle.unitIgnoreBuffCaster = unitIgnoreBuffCaster

local unitIgnoreBuffPhys = {
	"Ice Block",
	"Divine Shield",
	"Blessing of Protection",
	"Rain from Above",
	"Deterrence",
	"Life Cocoon",
	"Guardian of the Forgotten Queen",
	"Phase Shift",
	"Divine Ascension",
	"Burrow",
	"Aspect of the Turtle",
}
jungle.unitIgnoreBuffPhys = unitIgnoreBuffPhys

local purgeBuffs = {
	-- "Predatory Swiftness",
	-- "Innervate",
	-- "Thorns",
	"Nature's Swiftness",
	"Nullifying Shroud",
	"Blistering Scales",
	"Temporal Shield",
	"Ice Form",
	"Alter Time",
	-- "Blessing of Protection",
	-- "Blessing of Freedom",
	"Divine Favor",
	"Blessing of Spellwarding",
	"Power Infusion",
	"Holy Ward",
	"Spiritwalker's Grace",
	"Nether Ward",
	"Blessing of Spellwarding",
	"Ultimate Penitence",
	"Clarity of Will",
}
jungle.purgeBuffs = purgeBuffs

local absorbToDamageBuffs = {
--[[
	Absorbs to damage with special abilities aka sp swd + perk
]]
	"Tombstone",
	"Shield of Vengeance",
	"Dark Pact",
}
jungle.absorbToDamageBuffs = absorbToDamageBuffs

local burstBuffs = {
	"Metamorphosis",
	"Fodder to the Flame",
	"Incarnation: Chosen of Elune",
	"Incarnation: Avatar of Ashamane",
	"Incarnation: Guardian of Ursoc",
	"Berserk",
	"Celestial Alignment",
	"Dragonrage",
	"Trueshot",
	"Spearhead",
	"Coordinated Assault",
	"Icy Veins",
	"Ice Form",
	"Combustion",
	"Serenity",
	"Avenging Wrath",
	"Crusade",
	"Power Infusion",
	"Voidform",
	"Shadow Dance",
	"Shadow Blades",
	"Dreadblades",
	"Ascendance",
	"Dark Soul: Misery",
	"Dark Soul: Instability",
	"Avatar",
}
jungle.burstBuffs = burstBuffs

local ccImmunityBuffs = {
	"Glimpse",
	"Dream Flight",
	"Nullifying Shroud",
	"Holy Ward",
	"Phase Shift",
	"Divine Ascension",
	"Blessing of Spellwarding",
	"Bladestorm",
	"Ultimate Penitence",
}
jungle.ccImmunityBuffs = ccImmunityBuffs

local spellsBigHealsInterrupt = {
	"Dream Breath",
	"Emerald Slumber",
	"Spiritbloom",
	"Dream Projection",
	"Tyr's Deliverance",
	"Holy Word: Salvation",
	"Greater Heal",
	"Penance",
	"Heal",
	"Holy Light",
	"Healing Wave",
	"Surging Mist",
	"Power Word: Radiance",
	"Clarity of Will",
	"Nourish",
}
jungle.spellsBigHealsInterrupt = spellsBigHealsInterrupt

local spellsImportantInterrupt = {
	"The Hunt",
	"Entangling Roots",
	"Eternity Surge",
	"Fire Breath",
	"Upheaval",
	"Revive Pet",
	"Arcane Surge",
	"Summon Water Elemental",
	"Greater Pyroblast",
	"Glacial Spike",
	"Ebonbolt",
	"Radiant Spark",
	"Ring of Fire",
	"Ice Wall",
	"Searing Glare",
	"Denounce",
	"Mass Dispel",
	"Mindgames",
	"Stormkeeper",
	"Elemental Blast",
	"Cataclysm",
	"Chaos Bolt",
	"Summon Demonic Tyrant",
	"Soul Rot",
	"Soul Fire",
	"Bonds of Fel",
	"Nether Portal",
}
jungle.spellsImportantInterrupt = spellsImportantInterrupt

local spellsCcInterrupt = {
	"Cyclone",
	"Hibernate",
	"Sleep Walk",
	"Scare Beast",
	"Polymorph",
	"Ring of Frost",
	"Song of Chi-Ji",
	"Repentance",
	"Turn Evil",
	"Shackle Undead",
	"Mind Control",
	"Hex",
	"Banish",
	"Fear",
	"Shadowfury",
	"Seduction",
}
jungle.spellsCcInterrupt = spellsCcInterrupt

-- Magic, Curse, Poison
local allCcList = {
	"Strangulate",
	"Sigil of Silence",
	"Reactive Resin",
	"Spider Sting",
	"Spider Venom",
	"Wailing Arrow",
	"Shield of Virtue",
	"Silence",
	"Garrote",
	"Unstable Affliction Silence Effect",
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
jungle.allCcList = allCcList


local druidGoToFormAntiCC = {
	"Polymorph",
	"Hex",
}
jungle.druidGoToFormAntiCC = druidGoToFormAntiCC


local druidGoToShadowmeltAntiCC = {
	"Fear",
	"Repentance",
	"Mind Control",
	"Banish",
	"Sleep Walk",
}
jungle.druidGoToShadowmeltAntiCC = druidGoToShadowmeltAntiCC