local Jungle, jungle = ...


local slowDebuffs = {
    "Hamstring",
    "Piercing Howl",
    "Crippling Poison",
    "Cone of Cold",
    "Slow",
    "Mind Flay",
    "Curse of Exhaustion",
    "Frost Shock",
    "Earthbind",
    "Wing Clip",
    "Concussive Shot",
    "Blast Wave",
    "Frostbolt",
    "Frost Trap",
    "Chains of Ice",
    "Infected Wounds",
    "Desecration",
    "Chilled",
    "Dazed",
}
jungle.slowDebuffs = slowDebuffs

local rootDebuffs = {
    "Entangling Roots",
    "Nature's Grasp",
    "Frost Nova",
    "Freeze",
    "Frost Grenade",
    "Entrapment",
    "Improved Wing Clip",
    "Frostbite",
    "Improved Hamstring",
}
jungle.rootDebuffs = rootDebuffs

local toFreedomDebuffs = {
    "Entangling Roots",
    "Nature's Grasp",
    "Frost Nova",
    "Freeze",
    "Frost Grenade",
    "Entrapment",
    "Improved Wing Clip",
    "Frostbite",
    "Improved Hamstring",
    "Hamstring",
    "Piercing Howl",
    "Crippling Poison",
    "Cone of Cold",
    "Slow",
    "Mind Flay",
    "Curse of Exhaustion",
    "Frost Shock",
    "Earthbind",
    "Wing Clip",
    "Concussive Shot",
    "Blast Wave",
    "Frostbolt",
    "Frost Trap",
    "Chains of Ice",
    "Infected Wounds",
    "Desecration",
    "Chilled",
    "Dazed",
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
	"Blessing of Freedom",
	"Blessing of Protection",
	"The Beast Within",
}
jungle.slowImmunityBuffs = slowImmunityBuffs

local unitIgnoreDebuffs = {
	"Cyclone",
	"Banish",
}
jungle.unitIgnoreDebuffs = unitIgnoreDebuffs

-- Enemy nameplates with these auras do not contribute to AoE-mode counts.
-- This is intentionally separate from unitIgnoreDebuffs: these units remain
-- valid direct targets and their presence never disables an existing AoE
-- rotation.
local enemyNameplateAoEIgnoreDebuffs = {
	"Cyclone",
	"Banish",
	"Entangling Roots",
	"Nature's Grasp",
	"Frost Nova",
	"Freeze",
	"Frost Grenade",
	"Entrapment",
	"Improved Wing Clip",
	"Frostbite",
	"Improved Hamstring",
	"Hibernate",
	"Shackle Undead",
	"Freezing Trap Effect",
	"Wyvern Sting",
	"Polymorph",
	"Polymorph: Turtle",
	"Polymorph: Pig",
	"Repentance",
	"Sap",
	"Gouge",
	"Blind",
	"Scare Beast",
	"Turn Evil",
	"Psychic Scream",
	"Fear",
	"Seduction",
	"Howl of Terror",
	"Intimidating Shout",
	"Scatter Shot",
	"Dragon's Breath",
}
jungle.enemyNameplateAoEIgnoreDebuffs = enemyNameplateAoEIgnoreDebuffs

local enemyNameplateAoEIgnoreBuffs = {
	"Mind Control",
	"Ice Block",
	"Divine Shield",
	"Blessing of Protection",
	"Divine Intervention",
}
jungle.enemyNameplateAoEIgnoreBuffs = enemyNameplateAoEIgnoreBuffs

local unitIgnoreBuffCaster = {
	"Cloak of Shadows",
	"Ice Block",
}
jungle.unitIgnoreBuffCaster = unitIgnoreBuffCaster

local unitIgnoreBuffPhys = {
	"Ice Block",
	"Divine Shield",
	"Blessing of Protection",
	"Deterrence",
}
jungle.unitIgnoreBuffPhys = unitIgnoreBuffPhys

local purgeBuffs = {
	"Nature's Swiftness",
	"Divine Favor",
	"Power Infusion",
	"Nether Ward",
}
jungle.purgeBuffs = purgeBuffs

local absorbToDamageBuffs = {

}
jungle.absorbToDamageBuffs = absorbToDamageBuffs

local burstBuffs = {
	"Icy Veins",
	"Combustion",
	"Avenging Wrath",
	"Power Infusion",
}
jungle.burstBuffs = burstBuffs

local ccImmunityBuffs = {

}
jungle.ccImmunityBuffs = ccImmunityBuffs

local spellsBigHealsInterrupt = {
	"Greater Heal",
	"Heal",
	"Holy Light",
	"Healing Wave",
	"Healing Touch",
	"Regrowth",
	"Lesser Healing Wave",
	"Flash Heal",
	"Flash of Light",
}
jungle.spellsBigHealsInterrupt = spellsBigHealsInterrupt

local spellsImportantInterrupt = {
	"Entangling Roots",
	"Revive Pet",
	"Summon Water Elemental",
	"Mass Dispel",
	"Soul Fire",
	"Cyclone",
	"Fear",
	"Polymorph",
}
jungle.spellsImportantInterrupt = spellsImportantInterrupt

local spellsCcInterrupt = {
	"Cyclone",
	"Hibernate",
	"Scare Beast",
	"Polymorph",
	"Repentance",
	"Shackle Undead",
	"Mind Control",
	"Banish",
	"Fear",
	"Shadowfury",
	"Seduction",
}
jungle.spellsCcInterrupt = spellsCcInterrupt

-- Magic, Curse, Poison
local allCcList = {
	-- Strangulate/Silence
	"Silence", -- 15487
	"Spell Lock", -- 24259
	"Garrote", -- 1330
	"Silenced - Improved Counterspell", -- 18469, 55021
	"Arcane Torrent", -- 50613, 28730, 25046
	"Unstable Affliction", -- 43523, 31117

	-- Incapacitates
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

	-- Disorients / Fears / Mind Control / Death Coil
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

	-- Stuns
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

	-- Roots
	"Entangling Roots", -- 339, 1062, 5195, 5196, 9852, 9853, 26989
	"Nature's Grasp", -- 19975, 19974, 19973, 19972, 19971, 19970, 27010
	"Frost Nova", -- 122, 865, 6131, 10230, 27088
	"Freeze", -- 33395
	"Frost Grenade", -- 39965
	"Entrapment", -- 19185
	"Improved Wing Clip", -- 19229
	"Frostbite", -- 12494
	"Improved Hamstring", -- 23694

	-- Other / Scatters / Counterattack / Chastise
	"Scatter Shot", -- 19503
	"Dragon's Breath", -- 31661, 33041, 33042, 33043
	"Counterattack", -- 19306, 20909, 20910, 27067
	"Chastise", -- 44041, 44043, 44044, 44045, 44046, 44047
}
jungle.allCcList = allCcList

local druidGoToFormAntiCC = {
	"Polymorph",
}
jungle.druidGoToFormAntiCC = druidGoToFormAntiCC

local druidGoToShadowmeltAntiCC = {
	"Fear",
	"Repentance",
	"Mind Control",
	"Banish",
}
jungle.druidGoToShadowmeltAntiCC = druidGoToShadowmeltAntiCC

local classSpells = {
    ["WARRIOR"] = {
        [1] = { -- Arms
            ["interrupt"] = {
                [6552] = "Pummel",
                [6554] = "Pummel",
                [72] = "Shield Bash",
                [1671] = "Shield Bash",
                [1672] = "Shield Bash",
                [29704] = "Shield Bash",
            },
            ["defensive"] = {
                [23920] = "Spell Reflection",
                [18499] = "Berserker Rage",
                [871] = "Shield Wall",
                [3411] = "Intervene",
                [20230] = "Retaliation",
            },
            ["gapcloser"] = {
                [20252] = "Intercept",
                [20616] = "Intercept",
                [20617] = "Intercept",
                [25272] = "Intercept",
                [25275] = "Intercept",
            },
            ["cc"] = {
                [5246] = "Intimidating Shout",
                [676] = "Disarm",
            },
            ["offensive"] = {
                [1719] = "Recklessness",
                [12328] = "Sweeping Strikes",
            },
        },
        [2] = { -- Fury
            ["interrupt"] = {
                [6552] = "Pummel",
                [6554] = "Pummel",
                [72] = "Shield Bash",
                [1671] = "Shield Bash",
                [1672] = "Shield Bash",
                [29704] = "Shield Bash",
            },
            ["defensive"] = {
                [23920] = "Spell Reflection",
                [18499] = "Berserker Rage",
                [871] = "Shield Wall",
                [3411] = "Intervene",
            },
            ["gapcloser"] = {
                [20252] = "Intercept",
                [20616] = "Intercept",
                [20617] = "Intercept",
                [25272] = "Intercept",
                [25275] = "Intercept",
            },
            ["cc"] = {
                [5246] = "Intimidating Shout",
                [676] = "Disarm",
            },
            ["offensive"] = {
                [1719] = "Recklessness",
                [12292] = "Death Wish",
            },
        },
        [3] = { -- Protection
            ["interrupt"] = {
                [6552] = "Pummel",
                [6554] = "Pummel",
                [72] = "Shield Bash",
                [1671] = "Shield Bash",
                [1672] = "Shield Bash",
                [29704] = "Shield Bash",
            },
            ["defensive"] = {
                [23920] = "Spell Reflection",
                [18499] = "Berserker Rage",
                [871] = "Shield Wall",
                [3411] = "Intervene",
                [12975] = "Last Stand",
            },
            ["gapcloser"] = {
                [20252] = "Intercept",
                [20616] = "Intercept",
                [20617] = "Intercept",
                [25272] = "Intercept",
                [25275] = "Intercept",
            },
            ["cc"] = {
                [5246] = "Intimidating Shout",
                [676] = "Disarm",
            },
            ["offensive"] = {
                [1719] = "Recklessness",
            },
            ["stun"] = {
                [12809] = "Concussion Blow",
            },
        },
    },
    ["ROGUE"] = {
        [1] = { -- Assassination
            ["interrupt"] = {
                [1766] = "Kick",
                [1767] = "Kick",
                [1768] = "Kick",
                [1769] = "Kick",
                [38768] = "Kick",
            },
            ["cc"] = {
                [2094] = "Blind",
                [1776] = "Gouge",
                [1777] = "Gouge",
                [8629] = "Gouge",
                [11285] = "Gouge",
                [11286] = "Gouge",
                [38764] = "Gouge",
            },
            ["defensive"] = {
                [1856] = "Vanish",
                [1857] = "Vanish",
                [26889] = "Vanish",
                [31224] = "Cloak of Shadows",
                [5277] = "Evasion",
                [26669] = "Evasion",
            },
            ["gapcloser"] = {
                [2983] = "Sprint",
                [8696] = "Sprint",
                [11305] = "Sprint",
            },
            ["stun"] = {
                [408] = "Kidney Shot",
                [8643] = "Kidney Shot",
                [1833] = "Cheap Shot",
            },
            ["offensive"] = {
                [14177] = "Cold Blood",
            },
        },
        [2] = { -- Combat
            ["interrupt"] = {
                [1766] = "Kick",
                [1767] = "Kick",
                [1768] = "Kick",
                [1769] = "Kick",
                [38768] = "Kick",
            },
            ["cc"] = {
                [2094] = "Blind",
                [1776] = "Gouge",
                [1777] = "Gouge",
                [8629] = "Gouge",
                [11285] = "Gouge",
                [11286] = "Gouge",
                [38764] = "Gouge",
            },
            ["defensive"] = {
                [1856] = "Vanish",
                [1857] = "Vanish",
                [26889] = "Vanish",
                [31224] = "Cloak of Shadows",
                [5277] = "Evasion",
                [26669] = "Evasion",
            },
            ["gapcloser"] = {
                [2983] = "Sprint",
                [8696] = "Sprint",
                [11305] = "Sprint",
            },
            ["stun"] = {
                [408] = "Kidney Shot",
                [8643] = "Kidney Shot",
                [1833] = "Cheap Shot",
            },
            ["offensive"] = {
                [13750] = "Adrenaline Rush",
                [13877] = "Blade Flurry",
            },
        },
        [3] = { -- Subtlety
            ["interrupt"] = {
                [1766] = "Kick",
                [1767] = "Kick",
                [1768] = "Kick",
                [1769] = "Kick",
                [38768] = "Kick",
            },
            ["cc"] = {
                [2094] = "Blind",
                [1776] = "Gouge",
                [1777] = "Gouge",
                [8629] = "Gouge",
                [11285] = "Gouge",
                [11286] = "Gouge",
                [38764] = "Gouge",
            },
            ["defensive"] = {
                [1856] = "Vanish",
                [1857] = "Vanish",
                [26889] = "Vanish",
                [31224] = "Cloak of Shadows",
                [5277] = "Evasion",
                [26669] = "Evasion",
            },
            ["gapcloser"] = {
                [2983] = "Sprint",
                [8696] = "Sprint",
                [11305] = "Sprint",
                [36554] = "Shadowstep",
            },
            ["stun"] = {
                [408] = "Kidney Shot",
                [8643] = "Kidney Shot",
                [1833] = "Cheap Shot",
            },
            ["cdreset"] = {
                [14185] = "Preparation",
            },
        },
    },
    ["MAGE"] = {
        [1] = { -- Arcane
            ["interrupt"] = {
                [2139] = "Counterspell",
            },
            ["defensive"] = {
                [45438] = "Ice Block",
            },
            ["gapcloser"] = {
                [1953] = "Blink",
            },
            ["cc"] = {
                [122] = "Frost Nova",
                [865] = "Frost Nova",
                [6131] = "Frost Nova",
                [10230] = "Frost Nova",
                [27088] = "Frost Nova",
            },
            ["offensive"] = {
                [12042] = "Arcane Power",
                [12043] = "Presence of Mind",
            },
        },
        [2] = { -- Fire
            ["interrupt"] = {
                [2139] = "Counterspell",
            },
            ["defensive"] = {
                [45438] = "Ice Block",
            },
            ["gapcloser"] = {
                [1953] = "Blink",
            },
            ["cc"] = {
                [122] = "Frost Nova",
                [865] = "Frost Nova",
                [6131] = "Frost Nova",
                [10230] = "Frost Nova",
                [27088] = "Frost Nova",
                [31661] = "Dragon's Breath",
                [33041] = "Dragon's Breath",
                [33042] = "Dragon's Breath",
                [33043] = "Dragon's Breath",
                [11113] = "Blast Wave",
                [13018] = "Blast Wave",
                [13019] = "Blast Wave",
                [13020] = "Blast Wave",
                [13021] = "Blast Wave",
                [27133] = "Blast Wave",
                [33933] = "Blast Wave",
            },
            ["offensive"] = {
                [11129] = "Combustion",
            },
        },
        [3] = { -- Frost
            ["interrupt"] = {
                [2139] = "Counterspell",
            },
            ["defensive"] = {
                [45438] = "Ice Block",
                [11426] = "Ice Barrier",
                [13031] = "Ice Barrier",
                [13032] = "Ice Barrier",
                [13033] = "Ice Barrier",
                [27134] = "Ice Barrier",
                [33405] = "Ice Barrier",
            },
            ["gapcloser"] = {
                [1953] = "Blink",
            },
            ["cc"] = {
                [122] = "Frost Nova",
                [865] = "Frost Nova",
                [6131] = "Frost Nova",
                [10230] = "Frost Nova",
                [27088] = "Frost Nova",
            },
            ["cdreset"] = {
                [11958] = "Cold Snap",
            },
            ["offensive"] = {
                [12472] = "Icy Veins",
                [31687] = "Summon Water Elemental",
            },
        },
    },
    ["WARLOCK"] = {
        [1] = { -- Affliction
            ["interrupt"] = {
                [19244] = "Spell Lock",
                [19647] = "Spell Lock",
            },
            ["cc"] = {
                [6789] = "Death Coil",
                [17925] = "Death Coil",
                [17926] = "Death Coil",
                [27223] = "Death Coil",
                [5484] = "Howl of Terror",
                [17928] = "Howl of Terror",
            },
            ["dispel"] = {
                [19505] = "Devour Magic",
                [19731] = "Devour Magic",
                [19734] = "Devour Magic",
                [19736] = "Devour Magic",
                [27276] = "Devour Magic",
                [27277] = "Devour Magic",
            },
            ["offensive"] = {
                [18288] = "Amplify Curse",
            },
        },
        [2] = { -- Demonology
            ["interrupt"] = {
                [19244] = "Spell Lock",
                [19647] = "Spell Lock",
            },
            ["cc"] = {
                [6789] = "Death Coil",
                [17925] = "Death Coil",
                [17926] = "Death Coil",
                [27223] = "Death Coil",
                [5484] = "Howl of Terror",
                [17928] = "Howl of Terror",
            },
            ["dispel"] = {
                [19505] = "Devour Magic",
                [19731] = "Devour Magic",
                [19734] = "Devour Magic",
                [19736] = "Devour Magic",
                [27276] = "Devour Magic",
                [27277] = "Devour Magic",
            },
            ["defensive"] = {
                [18708] = "Fel Domination",
            },
        },
        [3] = { -- Destruction
            ["interrupt"] = {
                [19244] = "Spell Lock",
                [19647] = "Spell Lock",
            },
            ["cc"] = {
                [6789] = "Death Coil",
                [17925] = "Death Coil",
                [17926] = "Death Coil",
                [27223] = "Death Coil",
                [5484] = "Howl of Terror",
                [17928] = "Howl of Terror",
            },
            ["dispel"] = {
                [19505] = "Devour Magic",
                [19731] = "Devour Magic",
                [19734] = "Devour Magic",
                [19736] = "Devour Magic",
                [27276] = "Devour Magic",
                [27277] = "Devour Magic",
            },
            ["stun"] = {
                [30283] = "Shadowfury",
                [30413] = "Shadowfury",
                [30414] = "Shadowfury",
            },
            ["offensive"] = {
                [17877] = "Shadowburn",
                [18867] = "Shadowburn",
                [18868] = "Shadowburn",
                [18869] = "Shadowburn",
                [18870] = "Shadowburn",
                [18871] = "Shadowburn",
                [27263] = "Shadowburn",
                [30545] = "Shadowburn",
                [17962] = "Conflagrate",
                [18930] = "Conflagrate",
                [18931] = "Conflagrate",
                [18932] = "Conflagrate",
                [27266] = "Conflagrate",
                [30912] = "Conflagrate",
            },
        },
    },
    ["HUNTER"] = {
        [1] = { -- Beast Mastery
            ["defensive"] = {
                [19263] = "Deterrence",
                [5384] = "Feign Death",
            },
            ["cc"] = {
                [1499] = "Freezing Trap",
                [14310] = "Freezing Trap",
                [14311] = "Freezing Trap",
                [13809] = "Frost Trap",
                [34600] = "Snake Trap",
            },
            ["offensive"] = {
                [13813] = "Explosive Trap",
                [14316] = "Explosive Trap",
                [14317] = "Explosive Trap",
                [27025] = "Explosive Trap",
                [3045] = "Rapid Fire",
                [34026] = "Kill Command",
                [19574] = "Bestial Wrath",
            },
            ["stun"] = {
                [19577] = "Intimidation",
            },
        },
        [2] = { -- Marksmanship
            ["defensive"] = {
                [19263] = "Deterrence",
                [5384] = "Feign Death",
            },
            ["cc"] = {
                [1499] = "Freezing Trap",
                [14310] = "Freezing Trap",
                [14311] = "Freezing Trap",
                [13809] = "Frost Trap",
                [34600] = "Snake Trap",
                [19503] = "Scatter Shot",
            },
            ["offensive"] = {
                [13813] = "Explosive Trap",
                [14316] = "Explosive Trap",
                [14317] = "Explosive Trap",
                [27025] = "Explosive Trap",
                [3045] = "Rapid Fire",
                [34026] = "Kill Command",
            },
            ["interrupt"] = {
                [34490] = "Silencing Shot",
            },
            ["cdreset"] = {
                [23989] = "Readiness",
            },
        },
        [3] = { -- Survival
            ["defensive"] = {
                [19263] = "Deterrence",
                [5384] = "Feign Death",
            },
            ["cc"] = {
                [1499] = "Freezing Trap",
                [14310] = "Freezing Trap",
                [14311] = "Freezing Trap",
                [13809] = "Frost Trap",
                [34600] = "Snake Trap",
                [19386] = "Wyvern Sting",
                [24132] = "Wyvern Sting",
                [24133] = "Wyvern Sting",
                [27068] = "Wyvern Sting",
            },
            ["offensive"] = {
                [13813] = "Explosive Trap",
                [14316] = "Explosive Trap",
                [14317] = "Explosive Trap",
                [27025] = "Explosive Trap",
                [3045] = "Rapid Fire",
                [34026] = "Kill Command",
            },
        },
    },
    ["PALADIN"] = {
        [1] = { -- Holy
            ["defensive"] = {
                [642] = "Divine Shield",
                [1020] = "Divine Shield",
                [1022] = "Blessing of Protection",
                [5599] = "Blessing of Protection",
                [10278] = "Blessing of Protection",
                [633] = "Lay on Hands",
                [2800] = "Lay on Hands",
                [10310] = "Lay on Hands",
                [27154] = "Lay on Hands",
                [6940] = "Blessing of Sacrifice",
                [20729] = "Blessing of Sacrifice",
                [27147] = "Blessing of Sacrifice",
                [27148] = "Blessing of Sacrifice",
                [31842] = "Divine Illumination",
            },
            ["stun"] = {
                [853] = "Hammer of Justice",
                [5588] = "Hammer of Justice",
                [5589] = "Hammer of Justice",
                [10308] = "Hammer of Justice",
            },
            ["dispel"] = {
                [1044] = "Blessing of Freedom",
            },
            ["offensive"] = {
                [31884] = "Avenging Wrath",
                [20216] = "Divine Favor",
            },
        },
        [2] = { -- Protection
            ["defensive"] = {
                [642] = "Divine Shield",
                [1020] = "Divine Shield",
                [1022] = "Blessing of Protection",
                [5599] = "Blessing of Protection",
                [10278] = "Blessing of Protection",
                [633] = "Lay on Hands",
                [2800] = "Lay on Hands",
                [10310] = "Lay on Hands",
                [27154] = "Lay on Hands",
                [6940] = "Blessing of Sacrifice",
                [20729] = "Blessing of Sacrifice",
                [27147] = "Blessing of Sacrifice",
                [27148] = "Blessing of Sacrifice",
            },
            ["stun"] = {
                [853] = "Hammer of Justice",
                [5588] = "Hammer of Justice",
                [5589] = "Hammer of Justice",
                [10308] = "Hammer of Justice",
            },
            ["dispel"] = {
                [1044] = "Blessing of Freedom",
            },
            ["offensive"] = {
                [31884] = "Avenging Wrath",
            },
            ["interrupt"] = {
                [31935] = "Avenger's Shield",
                [32699] = "Avenger's Shield",
                [32700] = "Avenger's Shield",
            },
        },
        [3] = { -- Retribution
            ["defensive"] = {
                [642] = "Divine Shield",
                [1020] = "Divine Shield",
                [1022] = "Blessing of Protection",
                [5599] = "Blessing of Protection",
                [10278] = "Blessing of Protection",
                [633] = "Lay on Hands",
                [2800] = "Lay on Hands",
                [10310] = "Lay on Hands",
                [27154] = "Lay on Hands",
                [6940] = "Blessing of Sacrifice",
                [20729] = "Blessing of Sacrifice",
                [27147] = "Blessing of Sacrifice",
                [27148] = "Blessing of Sacrifice",
            },
            ["stun"] = {
                [853] = "Hammer of Justice",
                [5588] = "Hammer of Justice",
                [5589] = "Hammer of Justice",
                [10308] = "Hammer of Justice",
            },
            ["dispel"] = {
                [1044] = "Blessing of Freedom",
            },
            ["offensive"] = {
                [31884] = "Avenging Wrath",
            },
            ["cc"] = {
                [20066] = "Repentance",
            },
        },
    },
    ["PRIEST"] = {
        [1] = { -- Discipline
            ["defensive"] = {
                [6346] = "Fear Ward",
                [33206] = "Pain Suppression",
            },
            ["cc"] = {
                [8122] = "Psychic Scream",
                [8124] = "Psychic Scream",
                [10888] = "Psychic Scream",
                [10890] = "Psychic Scream",
            },
            ["offensive"] = {
                [34433] = "Shadowfiend",
                [32379] = "Shadow Word: Death",
                [32996] = "Shadow Word: Death",
                [10060] = "Power Infusion",
                [14751] = "Inner Focus",
            },
        },
        [2] = { -- Holy
            ["defensive"] = {
                [6346] = "Fear Ward",
                [19236] = "Desperate Prayer",
                [19238] = "Desperate Prayer",
                [19240] = "Desperate Prayer",
                [19241] = "Desperate Prayer",
                [19242] = "Desperate Prayer",
                [19243] = "Desperate Prayer",
                [25437] = "Desperate Prayer",
            },
            ["cc"] = {
                [8122] = "Psychic Scream",
                [8124] = "Psychic Scream",
                [10888] = "Psychic Scream",
                [10890] = "Psychic Scream",
            },
            ["offensive"] = {
                [34433] = "Shadowfiend",
                [32379] = "Shadow Word: Death",
                [32996] = "Shadow Word: Death",
            },
        },
        [3] = { -- Shadow
            ["defensive"] = {
                [6346] = "Fear Ward",
            },
            ["cc"] = {
                [8122] = "Psychic Scream",
                [8124] = "Psychic Scream",
                [10888] = "Psychic Scream",
                [10890] = "Psychic Scream",
            },
            ["offensive"] = {
                [34433] = "Shadowfiend",
                [32379] = "Shadow Word: Death",
                [32996] = "Shadow Word: Death",
            },
            ["interrupt"] = {
                [15487] = "Silence",
            },
        },
    },
    ["SHAMAN"] = {
        [1] = { -- Elemental
            ["interrupt"] = {
                [8042] = "Earth Shock",
                [8044] = "Earth Shock",
                [8045] = "Earth Shock",
                [8046] = "Earth Shock",
                [10412] = "Earth Shock",
                [10413] = "Earth Shock",
                [10414] = "Earth Shock",
                [25454] = "Earth Shock",
            },
            ["defensive"] = {
                [8177] = "Grounding Totem",
            },
            ["dispel"] = {
                [8143] = "Tremor Totem",
            },
            ["offensive"] = {
                [2825] = "Bloodlust",
                [32182] = "Heroism",
                [2062] = "Earth Elemental Totem",
                [2894] = "Fire Elemental Totem",
                [16166] = "Elemental Mastery",
            },
        },
        [2] = { -- Enhancement
            ["interrupt"] = {
                [8042] = "Earth Shock",
                [8044] = "Earth Shock",
                [8045] = "Earth Shock",
                [8046] = "Earth Shock",
                [10412] = "Earth Shock",
                [10413] = "Earth Shock",
                [10414] = "Earth Shock",
                [25454] = "Earth Shock",
            },
            ["defensive"] = {
                [8177] = "Grounding Totem",
                [30823] = "Shamanistic Rage",
            },
            ["dispel"] = {
                [8143] = "Tremor Totem",
            },
            ["offensive"] = {
                [2825] = "Bloodlust",
                [32182] = "Heroism",
                [2062] = "Earth Elemental Totem",
                [2894] = "Fire Elemental Totem",
                [17364] = "Stormstrike",
            },
        },
        [3] = { -- Restoration
            ["interrupt"] = {
                [8042] = "Earth Shock",
                [8044] = "Earth Shock",
                [8045] = "Earth Shock",
                [8046] = "Earth Shock",
                [10412] = "Earth Shock",
                [10413] = "Earth Shock",
                [10414] = "Earth Shock",
                [25454] = "Earth Shock",
            },
            ["defensive"] = {
                [8177] = "Grounding Totem",
                [16190] = "Mana Tide Totem",
            },
            ["dispel"] = {
                [8143] = "Tremor Totem",
            },
            ["offensive"] = {
                [2825] = "Bloodlust",
                [32182] = "Heroism",
                [2062] = "Earth Elemental Totem",
                [2894] = "Fire Elemental Totem",
                [16188] = "Nature's Swiftness",
            },
        },
    },
    ["DRUID"] = {
        [1] = { -- Balance
            ["defensive"] = {
                [22812] = "Barkskin",
                [29166] = "Innervate",
                [22842] = "Frenzied Regeneration",
                [22895] = "Frenzied Regeneration",
                [22896] = "Frenzied Regeneration",
                [26999] = "Frenzied Regeneration",
            },
            ["stun"] = {
                [5211] = "Bash",
                [6798] = "Bash",
                [8983] = "Bash",
            },
            ["gapcloser"] = {
                [1850] = "Dash",
                [9821] = "Dash",
                [33357] = "Dash",
            },
            ["cc"] = {
                [16689] = "Nature's Grasp",
                [16810] = "Nature's Grasp",
                [16811] = "Nature's Grasp",
                [16812] = "Nature's Grasp",
                [16813] = "Nature's Grasp",
                [17329] = "Nature's Grasp",
                [27009] = "Nature's Grasp",
                [33786] = "Cyclone",
            },
            ["offensive"] = {
                [33831] = "Force of Nature",
            },
        },
        [2] = { -- Feral Combat
            ["defensive"] = {
                [22812] = "Barkskin",
                [29166] = "Innervate",
                [22842] = "Frenzied Regeneration",
                [22895] = "Frenzied Regeneration",
                [22896] = "Frenzied Regeneration",
                [26999] = "Frenzied Regeneration",
            },
            ["stun"] = {
                [5211] = "Bash",
                [6798] = "Bash",
                [8983] = "Bash",
            },
            ["gapcloser"] = {
                [1850] = "Dash",
                [9821] = "Dash",
                [33357] = "Dash",
                [16979] = "Feral Charge",
            },
            ["cc"] = {
                [16689] = "Nature's Grasp",
                [16810] = "Nature's Grasp",
                [16811] = "Nature's Grasp",
                [16812] = "Nature's Grasp",
                [16813] = "Nature's Grasp",
                [17329] = "Nature's Grasp",
                [27009] = "Nature's Grasp",
                [33786] = "Cyclone",
            },
        },
        [3] = { -- Restoration
            ["defensive"] = {
                [22812] = "Barkskin",
                [29166] = "Innervate",
                [22842] = "Frenzied Regeneration",
                [22895] = "Frenzied Regeneration",
                [22896] = "Frenzied Regeneration",
                [26999] = "Frenzied Regeneration",
                [18562] = "Swiftmend",
            },
            ["stun"] = {
                [5211] = "Bash",
                [6798] = "Bash",
                [8983] = "Bash",
            },
            ["gapcloser"] = {
                [1850] = "Dash",
                [9821] = "Dash",
                [33357] = "Dash",
            },
            ["cc"] = {
                [16689] = "Nature's Grasp",
                [16810] = "Nature's Grasp",
                [16811] = "Nature's Grasp",
                [16812] = "Nature's Grasp",
                [16813] = "Nature's Grasp",
                [17329] = "Nature's Grasp",
                [27009] = "Nature's Grasp",
                [33786] = "Cyclone",
            },
            ["offensive"] = {
                [17116] = "Nature's Swiftness",
            },
        },
    },
}
jungle.classSpells = classSpells

local racialSpells = {
    ["defensive"] = {
        [7744] = "Will of the Forsaken",
        [20594] = "Stoneform",
        [20589] = "Escape Artist",
    },
    ["stun"] = {
        [20549] = "War Stomp",
    },
    ["offensive"] = {
        [20572] = "Blood Fury",
        [33697] = "Blood Fury",
        [33702] = "Blood Fury",
        [26297] = "Berserking",
        [20600] = "Perception",
        [28730] = "Arcane Torrent",
        [25046] = "Arcane Torrent",
        [50613] = "Arcane Torrent",
    },
}
jungle.racialSpells = racialSpells

local trinketSpells = {
    ["trinket"] = {
        [42292] = "PvP Trinket",
        [23453] = "Battlemaster Trinket",
    },
}
jungle.trinketSpells = trinketSpells
