local Jungle, jungle = ...
jungle.Hotkeys = {}
local Hotkeys = jungle.Hotkeys

-- ----------------------------------------------------------------------------
-- 1. DATA: GLOBAL ACTIONS & DEFAULTS (Static Bar)
-- ----------------------------------------------------------------------------
Hotkeys.GlobalDefaults = {
    -- A. THREAD SWITCHERS (Numpad 1-6)
    { id = "Thread 1", macro = "/run run_thread1()", icon = "Interface\\Icons\\Spell_ChargePositive" },
    { id = "Thread 2", macro = "/run run_thread2()", icon = "Interface\\Icons\\Spell_ChargeNegative" },
    { id = "Thread 3", macro = "/run run_thread3()", icon = "Interface\\Icons\\Spell_ChargePositive" },
    { id = "Thread 4", macro = "/run run_thread4()", icon = "Interface\\Icons\\Spell_ChargeNegative" },
    { id = "Thread 5", macro = "/run run_thread5()", icon = "Interface\\Icons\\Spell_ChargePositive" },
    { id = "Thread 6", macro = "/run run_thread6()", icon = "Interface\\Icons\\Spell_ChargeNegative" },

    -- B. USER ACTIONS
    { id = "Attack",      macro = "/startattack",        icon = "Interface\\Icons\\Inv_Sword_04" }, 
    { id = "Stopcasting", macro = "/stopcasting",        icon = "Interface\\Icons\\Spell_Shadow_Manaburn" },
    { id = "ClearFocus",  macro = "/clearfocus",         icon = "Interface\\Icons\\Spell_Shadow_SacrificialShield" },
    { id = "player",      macro = "/focus player",       icon = "Interface\\Icons\\Ability_Mage_Invisibility" },
    { id = "target",      macro = "/focus target",       icon = "Interface\\Icons\\Ability_Mage_Invisibility" },
    { id = "targettarget",macro = "/focus targettarget", icon = "Interface\\Icons\\Ability_Mage_Invisibility" },
    { id = "mouseover",   macro = "/focus mouseover",    icon = "Interface\\Icons\\Ability_Mage_Invisibility" },
    { id = "pettarget",   macro = "/focus pettarget",    icon = "Interface\\Icons\\Ability_Mage_Invisibility" },
}

-- ----------------------------------------------------------------------------
-- 2. DATA: SPELL DATABASE (TBC CLASSIC)
-- ----------------------------------------------------------------------------
Hotkeys.ClassSpells = {
    ["DRUID"] = {
        -- Balance / Resto Core
        { id = "Lifebloom", icon = "Interface\\Icons\\INV_Misc_Herb_Felblossom" },
        { id = "Rejuvenation", icon = "Interface\\Icons\\Spell_Nature_Rejuvenation" },
        { id = "Regrowth", icon = "Interface\\Icons\\Spell_Nature_ResistNature" },
        { id = "Healing Touch", icon = "Interface\\Icons\\Spell_Nature_HealingTouch" },
        { id = "Swiftmend", icon = "Interface\\Icons\\Inv_Relics_Idol_Life" },
        { id = "Moonfire", icon = "Interface\\Icons\\Spell_Nature_StarFall" },
        { id = "Insect Swarm", icon = "Interface\\Icons\\Spell_Nature_InsectSwarm" },
        { id = "Wrath", icon = "Interface\\Icons\\Spell_Nature_AbolishMagic" },
        { id = "Starfire", icon = "Interface\\Icons\\Spell_Arcane_StarFire" },
        { id = "Entangling Roots", icon = "Interface\\Icons\\Spell_Nature_StrangleVines" },
        { id = "Cyclone", icon = "Interface\\Icons\\Spell_Nature_EarthBind" },
        { id = "Faerie Fire", icon = "Interface\\Icons\\Spell_Nature_FaerieFire" },
        { id = "Hibernate", icon = "Interface\\Icons\\Spell_Nature_Sleep" },
        { id = "Innervate", icon = "Interface\\Icons\\Spell_Nature_Lightning" },
        { id = "Barkskin", icon = "Interface\\Icons\\Spell_Nature_StoneSkin" },
        { id = "Nature's Swiftness", icon = "Interface\\Icons\\Spell_Nature_RavenForm" },
        { id = "Force of Nature", icon = "Interface\\Icons\\Ability_Druid_ForceOfNature" },
        
        -- Feral
        { id = "Mangle (Cat)", icon = "Interface\\Icons\\Ability_Druid_Mangle2" },
        { id = "Shred", icon = "Interface\\Icons\\Spell_Shadow_VampiricAura" },
        { id = "Rip", icon = "Interface\\Icons\\Ability_GhoulFrenzy" },
        { id = "Ferocious Bite", icon = "Interface\\Icons\\Ability_Druid_FerociousBite" },
        { id = "Rake", icon = "Interface\\Icons\\Ability_Druid_Disembowel" },
        { id = "Pounce", icon = "Interface\\Icons\\Ability_Druid_SupriseAttack" },
        { id = "Mangle (Bear)", icon = "Interface\\Icons\\Ability_Druid_Mangle2" },
        { id = "Maul", icon = "Interface\\Icons\\Ability_Druid_Maul" },
        { id = "Lacerate", icon = "Interface\\Icons\\Ability_Druid_Lacerate" },
        { id = "Swipe", icon = "Interface\\Icons\\Inv_Misc_MonsterClaw_03" },
        { id = "Bash", icon = "Interface\\Icons\\Ability_Druid_Bash" },
        { id = "Feral Charge", icon = "Interface\\Icons\\Ability_Hunter_Pet_Bear" },
		{ id = "Claw", icon = "Interface\\Icons\\Ability_Druid_Rake" },
        
        -- Forms
        { id = "Cat Form", icon = "Interface\\Icons\\Ability_Druid_CatForm" },
        { id = "Bear Form", icon = "Interface\\Icons\\Ability_Racial_BearForm" },
        { id = "Dire Bear Form", icon = "Interface\\Icons\\Ability_Racial_BearForm" },
        { id = "Travel Form", icon = "Interface\\Icons\\Ability_Druid_TravelForm" },
        { id = "Moonkin Form", icon = "Interface\\Icons\\Spell_Nature_ForceOfNature" },
        { id = "Tree of Life", icon = "Interface\\Icons\\Ability_Druid_TreeofLife" },
        
        -- Buffs & Utility
        { id = "Mark of the Wild", icon = "Interface\\Icons\\Spell_Nature_Regeneration" },
        { id = "Thorns", icon = "Interface\\Icons\\Spell_Nature_Thorns" },
        { id = "Gift of the Wild", icon = "Interface\\Icons\\Spell_Nature_Regeneration" },
        { id = "Omen of Clarity", icon = "Interface\\Icons\\Spell_Nature_CrystalBall" },
        { id = "Remove Curse", icon = "Interface\\Icons\\Spell_Holy_RemoveCurse" },
        { id = "Abolish Poison", icon = "Interface\\Icons\\Spell_Nature_NullifyPoison_02" },
        { id = "Rebirth", icon = "Interface\\Icons\\Spell_Nature_Reincarnation" },
    },

    ["PRIEST"] = {
        { id = "Flash Heal", icon = "Interface\\Icons\\Spell_Holy_FlashHeal" },
        { id = "Greater Heal", icon = "Interface\\Icons\\Spell_Holy_GreaterHeal" },
        { id = "Renew", icon = "Interface\\Icons\\Spell_Holy_Renew" },
        { id = "Power Word: Shield", icon = "Interface\\Icons\\Spell_Holy_PowerWordShield" },
        { id = "Prayer of Mending", icon = "Interface\\Icons\\Spell_Holy_PrayerOfMendingtga" },
        { id = "Prayer of Healing", icon = "Interface\\Icons\\Spell_Holy_PrayerOfHealing02" },
        { id = "Circle of Healing", icon = "Interface\\Icons\\Spell_Holy_CircleOfRenewal" },
        { id = "Binding Heal", icon = "Interface\\Icons\\Spell_Holy_BlindingHeal" },
        { id = "Smite", icon = "Interface\\Icons\\Spell_Holy_HolySmite" },
        { id = "Holy Fire", icon = "Interface\\Icons\\Spell_Holy_SearingLight" },
        { id = "Shadow Word: Pain", icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain" },
        { id = "Mind Blast", icon = "Interface\\Icons\\Spell_Shadow_UnholyFrenzy" },
        { id = "Mind Flay", icon = "Interface\\Icons\\Spell_Shadow_SiphonMana" },
        { id = "Vampiric Touch", icon = "Interface\\Icons\\Spell_Holy_Stoicism" },
        { id = "Shadow Word: Death", icon = "Interface\\Icons\\Spell_Shadow_DemonicFortitude" },
        { id = "Devouring Plague", icon = "Interface\\Icons\\Spell_Shadow_BlackPlague" },
        { id = "Dispel Magic", icon = "Interface\\Icons\\Spell_Holy_DispelMagic" },
        { id = "Mass Dispel", icon = "Interface\\Icons\\Spell_Arcane_MassDispel" },
        { id = "Cure Disease", icon = "Interface\\Icons\\Spell_Holy_NullifyDisease" },
        { id = "Abolish Disease", icon = "Interface\\Icons\\Spell_Nature_NullifyDisease" },
        { id = "Psychic Scream", icon = "Interface\\Icons\\Spell_Shadow_PsychicScream" },
        { id = "Fade", icon = "Interface\\Icons\\Spell_Magic_LesserInvisibilty" },
        { id = "Shadowfiend", icon = "Interface\\Icons\\Spell_Shadow_Shadowfiend" },
        { id = "Power Infusion", icon = "Interface\\Icons\\Spell_Holy_PowerInfusion" },
        { id = "Pain Suppression", icon = "Interface\\Icons\\Spell_Holy_PainSupression" },
        { id = "Power Word: Fortitude", icon = "Interface\\Icons\\Spell_Holy_WordFortitude" },
        { id = "Prayer of Fortitude", icon = "Interface\\Icons\\Spell_Holy_PrayerOfFortitude" },
        { id = "Shadow Protection", icon = "Interface\\Icons\\Spell_Shadow_AntiShadow" },
        { id = "Prayer of Shadow Protection", icon = "Interface\\Icons\\Spell_Holy_PrayerOfShadowProtection" },
        { id = "Inner Fire", icon = "Interface\\Icons\\Spell_Holy_InnerFire" },
    },

    ["SHAMAN"] = {
        { id = "Lightning Bolt", icon = "Interface\\Icons\\Spell_Nature_Lightning" },
        { id = "Chain Lightning", icon = "Interface\\Icons\\Spell_Nature_ChainLightning" },
        { id = "Earth Shock", icon = "Interface\\Icons\\Spell_Nature_EarthShock" },
        { id = "Frost Shock", icon = "Interface\\Icons\\Spell_Nature_FrostShock" },
        { id = "Flame Shock", icon = "Interface\\Icons\\Spell_Fire_FlameShock" },
        { id = "Lesser Healing Wave", icon = "Interface\\Icons\\Spell_Nature_HealingWaveLesser" },
        { id = "Healing Wave", icon = "Interface\\Icons\\Spell_Nature_HealingWaveGreater" },
        { id = "Chain Heal", icon = "Interface\\Icons\\Spell_Nature_HealingWaveLesser" },
        { id = "Earth Shield", icon = "Interface\\Icons\\Spell_Nature_SkinofEarth" },
        { id = "Water Shield", icon = "Interface\\Icons\\Ability_Shaman_WaterShield" },
        { id = "Lightning Shield", icon = "Interface\\Icons\\Spell_Nature_LightningShield" },
        { id = "Stormstrike", icon = "Interface\\Icons\\Spell_Holy_SealOfMight" },
        { id = "Shamanistic Rage", icon = "Interface\\Icons\\Spell_Nature_ShamanRage" },
        { id = "Purge", icon = "Interface\\Icons\\Spell_Nature_Reincarnation" },
        { id = "Cure Poison", icon = "Interface\\Icons\\Spell_Nature_NullifyPoison" },
        { id = "Grounding Totem", icon = "Interface\\Icons\\Spell_Nature_GroundingTotem" },
        { id = "Tremor Totem", icon = "Interface\\Icons\\Spell_Nature_TremorTotem" },
        { id = "Earthbind Totem", icon = "Interface\\Icons\\Spell_Nature_StrengthOfEarthTotem02" },
        { id = "Bloodlust", icon = "Interface\\Icons\\Spell_Nature_BloodLust" },
        { id = "Heroism", icon = "Interface\\Icons\\Spell_Nature_BloodLust" },
    },

    ["PALADIN"] = {
        { id = "Flash of Light", icon = "Interface\\Icons\\Spell_Holy_FlashHeal" },
        { id = "Holy Light", icon = "Interface\\Icons\\Spell_Holy_HolyBolt" },
        { id = "Holy Shock", icon = "Interface\\Icons\\Spell_Holy_SearingLight" },
        { id = "Cleanse", icon = "Interface\\Icons\\Spell_Holy_Purify" },
        { id = "Purify", icon = "Interface\\Icons\\Spell_Holy_Purify" },
        { id = "Judgement", icon = "Interface\\Icons\\Spell_Holy_RighteousnessAura" },
        { id = "Consecration", icon = "Interface\\Icons\\Spell_Holy_InnerFire" },
        { id = "Hammer of Justice", icon = "Interface\\Icons\\Spell_Holy_SealOfMight" },
        { id = "Hammer of Wrath", icon = "Interface\\Icons\\Ability_ThunderClap" },
        { id = "Exorcism", icon = "Interface\\Icons\\Spell_Holy_Excorcism_02" },
        { id = "Crusader Strike", icon = "Interface\\Icons\\Spell_Holy_CrusaderStrike" },
        { id = "Holy Shield", icon = "Interface\\Icons\\Spell_Holy_BlessingOfProtection" },
        { id = "Avenger's Shield", icon = "Interface\\Icons\\Spell_Holy_AvengersShield" },
        { id = "Righteous Defense", icon = "Interface\\Icons\\Ability_Paladin_RighteousDefense" },
        { id = "Blessing of Freedom", icon = "Interface\\Icons\\Spell_Holy_SealOfValor" },
        { id = "Blessing of Protection", icon = "Interface\\Icons\\Spell_Holy_SealOfProtection" },
        { id = "Blessing of Sacrifice", icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice" },
        { id = "Divine Shield", icon = "Interface\\Icons\\Spell_Holy_DivineIntervention" },
        { id = "Divine Protection", icon = "Interface\\Icons\\Spell_Holy_Restoration" },
        { id = "Blessing of Kings", icon = "Interface\\Icons\\Spell_Magic_MageArmor" },
        { id = "Blessing of Might", icon = "Interface\\Icons\\Spell_Holy_FistOfJustice" },
        { id = "Blessing of Wisdom", icon = "Interface\\Icons\\Spell_Holy_SealOfWisdom" },
    },

    ["MAGE"] = {
        { id = "Frostbolt", icon = "Interface\\Icons\\Spell_Frost_FrostBolt02" },
        { id = "Ice Lance", icon = "Interface\\Icons\\Spell_Frost_FrostBlast" },
        { id = "Cone of Cold", icon = "Interface\\Icons\\Spell_Frost_Glacier" },
        { id = "Frost Nova", icon = "Interface\\Icons\\Spell_Frost_FrostNova" },
        { id = "Ice Block", icon = "Interface\\Icons\\Spell_Frost_Frost" },
        { id = "Icy Veins", icon = "Interface\\Icons\\Spell_Frost_ColdHearted" },
        { id = "Summon Water Elemental", icon = "Interface\\Icons\\Spell_Frost_SummonWaterElemental" },
        { id = "Fireball", icon = "Interface\\Icons\\Spell_Fire_FlameBolt" },
        { id = "Pyroblast", icon = "Interface\\Icons\\Spell_Fire_Fireball02" },
        { id = "Scorch", icon = "Interface\\Icons\\Spell_Fire_SoulBurn" },
        { id = "Fire Blast", icon = "Interface\\Icons\\Spell_Fire_Fireball" },
        { id = "Combustion", icon = "Interface\\Icons\\Spell_Fire_SealOfFire" },
        { id = "Dragon's Breath", icon = "Interface\\Icons\\Inv_Misc_Head_Dragon_01" },
        { id = "Blast Wave", icon = "Interface\\Icons\\Spell_Holy_Excorcism_02" },
        { id = "Arcane Blast", icon = "Interface\\Icons\\Spell_Arcane_Blast" },
        { id = "Arcane Missiles", icon = "Interface\\Icons\\Spell_Nature_StarFall" },
        { id = "Arcane Explosion", icon = "Interface\\Icons\\Spell_Nature_WispSplode" },
        { id = "Counterspell", icon = "Interface\\Icons\\Spell_Frost_IceShock" },
        { id = "Spellsteal", icon = "Interface\\Icons\\Spell_Arcane_Arcane02" },
        { id = "Polymorph", icon = "Interface\\Icons\\Spell_Nature_Polymorph" },
        { id = "Blink", icon = "Interface\\Icons\\Spell_Arcane_Blink" },
        { id = "Evocation", icon = "Interface\\Icons\\Spell_Nature_TimeStop" },
        { id = "Invisibility", icon = "Interface\\Icons\\Ability_Mage_Invisibility" },
        { id = "Arcane Intellect", icon = "Interface\\Icons\\Spell_Holy_MagicalSentry" },
        { id = "Arcane Brilliance", icon = "Interface\\Icons\\Spell_Holy_ArcaneIntellect" },
        { id = "Ice Armor", icon = "Interface\\Icons\\Spell_Frost_FrostArmor02" },
        { id = "Molten Armor", icon = "Interface\\Icons\\Ability_Mage_MoltenArmor" },
        { id = "Mage Armor", icon = "Interface\\Icons\\Spell_MageArmor" },
    },

    ["WARLOCK"] = {
        { id = "Curse of Agony", icon = "Interface\\Icons\\Spell_Shadow_CurseOfSargeras" },
        { id = "Corruption", icon = "Interface\\Icons\\Spell_Shadow_AbominationExplosion" },
        { id = "Unstable Affliction", icon = "Interface\\Icons\\Spell_Shadow_UnstableAffliction_3" },
        { id = "Drain Life", icon = "Interface\\Icons\\Spell_Shadow_LifeDrain02" },
        { id = "Fear", icon = "Interface\\Icons\\Spell_Shadow_Possession" },
        { id = "Howl of Terror", icon = "Interface\\Icons\\Spell_Shadow_DeathScream" },
        { id = "Death Coil", icon = "Interface\\Icons\\Spell_Shadow_DeathCoil" },
        { id = "Curse of the Elements", icon = "Interface\\Icons\\Spell_Shadow_ChillTouch" },
        { id = "Curse of Tongues", icon = "Interface\\Icons\\Spell_Shadow_CurseOfTongues" },
        { id = "Seed of Corruption", icon = "Interface\\Icons\\Spell_Shadow_SeedOfDestruction" },
        { id = "Shadow Bolt", icon = "Interface\\Icons\\Spell_Shadow_ShadowBolt" },
        { id = "Immolate", icon = "Interface\\Icons\\Spell_Fire_Immolation" },
        { id = "Incinerate", icon = "Interface\\Icons\\Spell_Fire_Burnout" },
        { id = "Conflagrate", icon = "Interface\\Icons\\Spell_Fire_Fireball" },
        { id = "Searing Pain", icon = "Interface\\Icons\\Spell_Fire_SoulBurn" },
        { id = "Shadowburn", icon = "Interface\\Icons\\Spell_Shadow_ScourgeBuild" },
        { id = "Shadowfury", icon = "Interface\\Icons\\Spell_Shadow_Shadowfury" },
        { id = "Demon Armor", icon = "Interface\\Icons\\Spell_Shadow_RagingScream" },
        { id = "Fel Armor", icon = "Interface\\Icons\\Spell_Shadow_FelArmor" },
        { id = "Soul Link", icon = "Interface\\Icons\\Spell_Shadow_GatherShadows" },
        { id = "Summon Felhunter", icon = "Interface\\Icons\\Spell_Shadow_SummonFelHunter" },
        { id = "Summon Felguard", icon = "Interface\\Icons\\Spell_Shadow_SummonFelGuard" },
    },

    ["ROGUE"] = {
        { id = "Sinister Strike", icon = "Interface\\Icons\\Spell_Shadow_RitualOfSacrifice" },
        { id = "Eviscerate", icon = "Interface\\Icons\\Ability_Rogue_Eviscerate" },
        { id = "Kidney Shot", icon = "Interface\\Icons\\Ability_Rogue_KidneyShot" },
        { id = "Cheap Shot", icon = "Interface\\Icons\\Ability_CheapShot" },
        { id = "Backstab", icon = "Interface\\Icons\\Ability_BackStab" },
        { id = "Ambush", icon = "Interface\\Icons\\Ability_Rogue_Ambush" },
        { id = "Garrote", icon = "Interface\\Icons\\Ability_Rogue_Garrote" },
        { id = "Rupture", icon = "Interface\\Icons\\Ability_Rogue_Rupture" },
        { id = "Slice and Dice", icon = "Interface\\Icons\\Ability_Rogue_SliceDice" },
        { id = "Mutilate", icon = "Interface\\Icons\\Ability_Rogue_ShadowStrikes" },
        { id = "Hemorrage", icon = "Interface\\Icons\\Spell_Shadow_LifeDrain" },
        { id = "Ghostly Strike", icon = "Interface\\Icons\\Spell_Shadow_Curse" },
        { id = "Shiv", icon = "Interface\\Icons\\Inv_ThrowingKnife_04" },
        { id = "Gouge", icon = "Interface\\Icons\\Ability_Gouge" },
        { id = "Blind", icon = "Interface\\Icons\\Spell_Shadow_MindSteal" },
        { id = "Kick", icon = "Interface\\Icons\\Ability_Kick" },
        { id = "Cloak of Shadows", icon = "Interface\\Icons\\Spell_Shadow_NetherCloak" },
        { id = "Vanish", icon = "Interface\\Icons\\Ability_Vanish" },
        { id = "Evasion", icon = "Interface\\Icons\\Spell_Shadow_ShadowWard" },
        { id = "Sprint", icon = "Interface\\Icons\\Ability_Rogue_Sprint" },
        { id = "Preparation", icon = "Interface\\Icons\\Spell_Shadow_AntiShadow" },
        { id = "Shadowstep", icon = "Interface\\Icons\\Ability_Rogue_Shadowstep" },
    },

    ["WARRIOR"] = {
        { id = "Mortal Strike", icon = "Interface\\Icons\\Ability_Warrior_SavageBlow" },
        { id = "Bloodthirst", icon = "Interface\\Icons\\Spell_Nature_BloodLust" },
        { id = "Shield Slam", icon = "Interface\\Icons\\Inv_Shield_05" },
        { id = "Execute", icon = "Interface\\Icons\\Inv_Sword_48" },
        { id = "Overpower", icon = "Interface\\Icons\\Ability_MeleeDamage" },
        { id = "Whirlwind", icon = "Interface\\Icons\\Ability_Whirlwind" },
        { id = "Heroic Strike", icon = "Interface\\Icons\\Ability_Rogue_Ambush" },
        { id = "Cleave", icon = "Interface\\Icons\\Ability_Warrior_Cleave" },
        { id = "Devastate", icon = "Interface\\Icons\\Inv_Sword_11" },
        { id = "Sunder Armor", icon = "Interface\\Icons\\Ability_Warrior_Sunder" },
        { id = "Revenge", icon = "Interface\\Icons\\Ability_Warrior_Revenge" },
        { id = "Charge", icon = "Interface\\Icons\\Ability_Warrior_Charge" },
        { id = "Intercept", icon = "Interface\\Icons\\Ability_Rogue_Sprint" },
        { id = "Intervene", icon = "Interface\\Icons\\Ability_Warrior_VictoryRush" },
        { id = "Pummel", icon = "Interface\\Icons\\Inv_Gauntlets_04" },
        { id = "Shield Bash", icon = "Interface\\Icons\\Ability_Warrior_ShieldBash" },
        { id = "Disarm", icon = "Interface\\Icons\\Ability_Warrior_Disarm" },
        { id = "Intimidating Shout", icon = "Interface\\Icons\\Ability_GolemThunderClap" },
        { id = "Battle Shout", icon = "Interface\\Icons\\Ability_Warrior_BattleShout" },
        { id = "Commanding Shout", icon = "Interface\\Icons\\Ability_Warrior_RallyingCry" },
        { id = "Demoralizing Shout", icon = "Interface\\Icons\\Ability_Warrior_WarCry" },
        { id = "Spell Reflection", icon = "Interface\\Icons\\Ability_Warrior_ShieldReflection" },
    },

    ["HUNTER"] = {
        { id = "Steady Shot", icon = "Interface\\Icons\\Ability_Hunter_SteadyShot" },
        { id = "Auto Shot", icon = "Interface\\Icons\\Ability_Whirlwind" },
        { id = "Arcane Shot", icon = "Interface\\Icons\\Ability_ImpalingBolt" },
        { id = "Aimed Shot", icon = "Interface\\Icons\\Inv_Spear_07" },
        { id = "Multi-Shot", icon = "Interface\\Icons\\Ability_UpgradeMoonGlaive" },
        { id = "Serpent Sting", icon = "Interface\\Icons\\Ability_Hunter_Quickshot" },
        { id = "Viper Sting", icon = "Interface\\Icons\\Ability_Hunter_AimedShot" },
        { id = "Scorpid Sting", icon = "Interface\\Icons\\Ability_Hunter_CriticalShot" },
        { id = "Kill Command", icon = "Interface\\Icons\\Ability_Hunter_KillCommand" },
        { id = "Bestial Wrath", icon = "Interface\\Icons\\Ability_Druid_FerociousBite" },
        { id = "Intimidation", icon = "Interface\\Icons\\Ability_Devour" },
        { id = "Scatter Shot", icon = "Interface\\Icons\\Ability_GolemStormBolt" },
        { id = "Silencing Shot", icon = "Interface\\Icons\\Ability_TheBlackArrow" },
        { id = "Wyvern Sting", icon = "Interface\\Icons\\Inv_Spear_02" },
        { id = "Feign Death", icon = "Interface\\Icons\\Ability_Rogue_FeignDeath" },
        { id = "Freezing Trap", icon = "Interface\\Icons\\Spell_Frost_ChainsOfIce" },
        { id = "Frost Trap", icon = "Interface\\Icons\\Spell_Frost_FreezingBreath" },
        { id = "Explosive Trap", icon = "Interface\\Icons\\Spell_Fire_SelfDestruct" },
        { id = "Snake Trap", icon = "Interface\\Icons\\Ability_Hunter_SnakeTrap" },
        { id = "Hunter's Mark", icon = "Interface\\Icons\\Ability_Hunter_SniperShot" },
        { id = "Flare", icon = "Interface\\Icons\\Spell_Fire_Flare" },
        { id = "Aspect of the Hawk", icon = "Interface\\Icons\\Spell_Nature_RavenForm" },
        { id = "Aspect of the Viper", icon = "Interface\\Icons\\Ability_Hunter_AspectOfTheViper" },
        { id = "Aspect of the Cheetah", icon = "Interface\\Icons\\Ability_Mount_JungleTiger" },
        { id = "Aspect of the Pack", icon = "Interface\\Icons\\Ability_Mount_WhiteTiger" },
    },
}

-- ----------------------------------------------------------------------------
-- 3. KEY POOLS
-- ----------------------------------------------------------------------------
Hotkeys.Pool_Rotation = {
    -- CTRL Set (Spell Engine)
    "CTRL-F1", "CTRL-F2", "CTRL-F3", "CTRL-F4", "CTRL-F5", "CTRL-F6", 
    "CTRL-F7", "CTRL-F8", "CTRL-F9", "CTRL-F10", "CTRL-F11", "CTRL-F12",
    "CTRL-INSERT", "CTRL-DELETE", "CTRL-HOME", "CTRL-END", "CTRL-PAGEUP", "CTRL-PAGEDOWN",
    "CTRL-UP", "CTRL-DOWN", "CTRL-LEFT", "CTRL-RIGHT", "CTRL-MINUS", "CTRL-EQUALS", "CTRL-SPACE",

    -- SHIFT Set (Spell Engine)
    "SHIFT-F1", "SHIFT-F2", "SHIFT-F3", "SHIFT-F4", "SHIFT-F5", "SHIFT-F6", 
    "SHIFT-F7", "SHIFT-F8", "SHIFT-F9", "SHIFT-F10", "SHIFT-F11", "SHIFT-F12",
    "SHIFT-INSERT", "SHIFT-DELETE", "SHIFT-HOME", "SHIFT-END", "SHIFT-PAGEUP", "SHIFT-PAGEDOWN",
    "SHIFT-UP", "SHIFT-DOWN", "SHIFT-LEFT", "SHIFT-RIGHT", "SHIFT-MINUS", "SHIFT-EQUALS", "SHIFT-SPACE",
}

Hotkeys.Pool_Targeting = {
    -- 1. THREAD CONTROLS
    "NUMPAD1", "NUMPAD2", "NUMPAD3", "NUMPAD4", "NUMPAD5", "NUMPAD6",

    -- 2. ALT Set (Static Focus Engine)
    "ALT-F1", "ALT-F2", "ALT-F3", "ALT-F5", "ALT-F6", 
    "ALT-F7", "ALT-F8", "ALT-F9", "ALT-F10", "ALT-F11", "ALT-F12",
    "ALT-INSERT", "ALT-DELETE", "ALT-HOME", "ALT-END", "ALT-PAGEUP", "ALT-PAGEDOWN",
    "ALT-UP", "ALT-DOWN", "ALT-LEFT", "ALT-RIGHT", "ALT-MINUS", "ALT-EQUALS", "ALT-SPACE",

    -- 3. DOUBLE MODIFIERS
    "CTRL-SHIFT-F1", "CTRL-SHIFT-F2", "CTRL-SHIFT-F3", "CTRL-SHIFT-F4", 
    "CTRL-SHIFT-F5", "CTRL-SHIFT-F6", "CTRL-SHIFT-F7", "CTRL-SHIFT-F8", 
    "CTRL-SHIFT-F9", "CTRL-SHIFT-F10", "CTRL-SHIFT-F11", "CTRL-SHIFT-F12",
    "CTRL-SHIFT-INSERT", "CTRL-SHIFT-DELETE", "CTRL-SHIFT-HOME", "CTRL-SHIFT-END", 
    "CTRL-SHIFT-PAGEUP", "CTRL-SHIFT-PAGEDOWN", "CTRL-SHIFT-UP", "CTRL-SHIFT-DOWN", 
    "CTRL-SHIFT-LEFT", "CTRL-SHIFT-RIGHT",

    "ALT-SHIFT-F1", "ALT-SHIFT-F2", "ALT-SHIFT-F3", "ALT-SHIFT-F4", 
    "ALT-SHIFT-F5", "ALT-SHIFT-F6", "ALT-SHIFT-F7", "ALT-SHIFT-F8", 
    "ALT-SHIFT-F9", "ALT-SHIFT-F10", "ALT-SHIFT-F11", "ALT-SHIFT-F12",
    "ALT-SHIFT-INSERT", "ALT-SHIFT-DELETE", "ALT-SHIFT-HOME", "ALT-SHIFT-END", 
    "ALT-SHIFT-PAGEUP", "ALT-SHIFT-PAGEDOWN", "ALT-SHIFT-UP", "ALT-SHIFT-DOWN", 
    "ALT-SHIFT-LEFT", "ALT-SHIFT-RIGHT",

    "CTRL-ALT-F1", "CTRL-ALT-F2", "CTRL-ALT-F3", 
    "CTRL-ALT-F5", "CTRL-ALT-F6", "CTRL-ALT-F7", "CTRL-ALT-F8", 
    "CTRL-ALT-F9", "CTRL-ALT-F10", "CTRL-ALT-F11", "CTRL-ALT-F12",
    "CTRL-ALT-INSERT", "CTRL-ALT-HOME", "CTRL-ALT-END", 
    "CTRL-ALT-PAGEUP", "CTRL-ALT-PAGEDOWN", "CTRL-ALT-UP", "CTRL-ALT-DOWN", 
    "CTRL-ALT-LEFT", "CTRL-ALT-RIGHT",
}

-- ----------------------------------------------------------------------------
-- 4. BAR CREATION
-- ----------------------------------------------------------------------------

-- A. STATIC BAR (DEFAULTS + UNITS)
function Hotkeys:CreateStaticBar()
    local parent = CreateFrame("Frame", "CA_Static_Bar", UIParent, "SecureHandlerStateTemplate")
    parent:SetSize(1, 1)
    parent:SetPoint("RIGHT", UIParent, "RIGHT", -50, 0)
    parent:SetAlpha(0) 
    
    local bg = parent:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 0, 0, 0.2) 
    parent.bg = bg

    self.StaticButtons = {}
    self.StaticBindings = {} 
    
    local keyIndex = 1
    local btnSize = 30
    local spacing = 2
    local columns = 8 

    -- Helper to create button
    local function CreateBtn(id, macroText, iconPath)
        local key = self.Pool_Targeting[keyIndex]
        if not key then return end
        
        local btnName = "CA_Static_" .. keyIndex
        local btn = CreateFrame("Button", btnName, parent, "SecureActionButtonTemplate")
        btn:SetSize(btnSize, btnSize)
        btn:RegisterForClicks("AnyUp", "AnyDown")
        
        -- Grid
        local index = keyIndex - 1
        local row = math.floor(index / columns)
        local col = index % columns
        btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -(col * (btnSize + spacing)), -(row * (btnSize + spacing)))
        
        -- Visuals
        local t = btn:CreateTexture(nil, "ARTWORK")
        t:SetAllPoints()
        if iconPath then
            t:SetTexture(iconPath)
            t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        else
            t:SetColorTexture(0.1, 0.1, 0.1, 0.8)
        end
        
        -- Tooltips
        btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        btn:SetScript("OnEnter", function(self)
            if parent:GetAlpha() > 0 then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine("Action: " .. id)
                GameTooltip:AddLine("Key: " .. key, 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Logic
        btn:SetAttribute("type", "macro")
        btn:SetAttribute("macrotext", macroText)
        
        table.insert(self.StaticButtons, { frame = btn, key = key, id = id })
        self.StaticBindings[id] = key
        keyIndex = keyIndex + 1
    end
    
    -- 1. Global Defaults
    for _, data in ipairs(self.GlobalDefaults) do
        CreateBtn(data.id, data.macro, data.icon)
    end

    -- 2. Missing Core Units
    CreateBtn("focus", "/focus focus", "Interface\\Icons\\Ability_Hunter_SniperShot")
    CreateBtn("pet", "/focus pet", "Interface\\Icons\\Ability_Hunter_BeastCall")

    -- 3. Group Units
    for i = 1, 4 do CreateBtn("party"..i, "/focus party"..i) end
    for i = 1, 5 do CreateBtn("arena"..i, "/focus arena"..i) end
    for i = 1, 40 do CreateBtn("raid"..i, "/focus raid"..i) end

    self.StaticBarFrame = parent
end

-- B. DYNAMIC BAR (SPELL ENGINE)
function Hotkeys:CreateDynamicBar()
    local parent = CreateFrame("Frame", "CA_Dynamic_Bar", UIParent, "SecureHandlerStateTemplate")
    parent:SetSize(1, 1)
    parent:SetPoint("RIGHT", UIParent, "RIGHT", -350, 0)
    parent:SetAlpha(0) 
    
    local bg = parent:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 1, 0, 0.2) 
    parent.bg = bg

    self.DynamicButtons = {}
    
    local _, class = UnitClass("player")
    local spellList = self.ClassSpells[class]
    if not spellList then return end

    local keyIndex = 1
    local btnSize = 30
    local spacing = 2
    local columns = 6 
    
    for _, spellData in ipairs(spellList) do
        local key = self.Pool_Rotation[keyIndex]
        if not key then break end 
        
        local btnName = "CA_Dynamic_" .. keyIndex
        local btn = CreateFrame("Button", btnName, parent, "SecureActionButtonTemplate")
        btn:SetSize(btnSize, btnSize)
        btn:RegisterForClicks("AnyUp", "AnyDown")

        local index = keyIndex - 1
        local row = math.floor(index / columns)
        local col = index % columns
        btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -(col * (btnSize + spacing)), -(row * (btnSize + spacing)))
        
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexture(spellData.icon)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        
        btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        btn:SetScript("OnEnter", function(self)
            if parent:GetAlpha() > 0 then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine("Spell: " .. spellData.id)
                GameTooltip:AddLine("Key: " .. key, 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        btn:SetAttribute("type", "macro")
        btn:SetAttribute("macrotext", "/cast [@focus, exists] " .. spellData.id)
        
        table.insert(self.DynamicButtons, { frame = btn, key = key, spell = spellData.id })
        keyIndex = keyIndex + 1
    end
    
    self.DynamicBarFrame = parent
end

function Hotkeys:ApplyBindings()
    if InCombatLockdown() then return end
    
    if self.StaticBarFrame then
        ClearOverrideBindings(self.StaticBarFrame)
        for _, btnData in ipairs(self.StaticButtons) do
            SetOverrideBindingClick(self.StaticBarFrame, true, btnData.key, btnData.frame:GetName())
        end
    end
    
    if self.DynamicBarFrame then
        ClearOverrideBindings(self.DynamicBarFrame)
        for _, btnData in ipairs(self.DynamicButtons) do
            SetOverrideBindingClick(self.DynamicBarFrame, true, btnData.key, btnData.frame:GetName())
        end
    end
    
    print("|cFF00FF00[Hotkeys]|r All Bindings Applied.")
end

-- ----------------------------------------------------------------------------
-- 5. DEBUG MODE
-- ----------------------------------------------------------------------------
function Hotkeys:ToggleDebug()
    if InCombatLockdown() then 
        print("|cFFFF0000[Hotkeys]|r Cannot toggle debug in combat.")
        return 
    end

    local f1 = self.StaticBarFrame
    local f2 = self.DynamicBarFrame
    
    if f1:GetAlpha() == 0 then
        f1:SetAlpha(1)
        if f2 then f2:SetAlpha(1) end
        print("|cFF00FFFF[Hotkeys]|r Debug Mode: |cFF00FF00ON|r")
    else
        f1:SetAlpha(0)
        if f2 then f2:SetAlpha(0) end
        print("|cFF00FFFF[Hotkeys]|r Debug Mode: |cFFFF0000OFF|r")
    end
end

-- ----------------------------------------------------------------------------
-- 5. EXPORT / DUMP
-- ----------------------------------------------------------------------------

-- [CHANGED]: Uses jungle.Color class to ensure 100% match with Pixel engine
function Hotkeys:GenerateColor(str)
    -- Safety check if Color.lua loaded
    if not jungle.Color then 
        print("|cFFFF0000[Error]|r jungle.Color class missing!") 
        return "000000" 
    end
    
    -- 1. Create Instance
    local colorObj = jungle.Color:new()
    
    -- 2. Generate RGB (Returns table {0-1, 0-1, 0-1})
    local rgb = colorObj:makeColor(str)
    
    -- 3. Convert to 0-255 Integer
    -- Note: Color.lua uses round(val, 4). We simply scale that to 255.
    local r = math.floor(rgb[1] * 255 + 0.5)
    local g = math.floor(rgb[2] * 255 + 0.5)
    local b = math.floor(rgb[3] * 255 + 0.5)
    
    -- 4. Return Hex String
    return string.format("%02x%02x%02x", r, g, b)
end

function Hotkeys:DumpBindings()
    OliaEyes_Export = {}
    local count = 0
    local colorMap = {}
    local collisionCount = 0
    
    print("|cFF00FFFF[Hotkeys]|r Dump Started (Using jungle.Color)...")

    local function AddEntry(className, typeName, id, key)
        local color = self:GenerateColor(id)
        
        if colorMap[color] and colorMap[color] ~= id then
            print("|cFFFF0000[COLLISION]|r " .. color .. " : " .. colorMap[color] .. " vs " .. id)
            collisionCount = collisionCount + 1
        else
            colorMap[color] = id
        end

        table.insert(OliaEyes_Export, {
            class = className,
            type  = typeName,
            id    = id,
            key   = key,
            color = color
        })
        count = count + 1
    end

    -- Static
    if self.StaticButtons then
        for _, btn in ipairs(self.StaticButtons) do
            AddEntry("GLOBAL", "Static", btn.id, btn.key)
        end
    end

    -- Dynamic
    for className, spellList in pairs(self.ClassSpells) do
        local keyIndex = 1
        for _, spellData in ipairs(spellList) do
            local key = self.Pool_Rotation[keyIndex]
            if not key then break end
            AddEntry(className, "Dynamic", spellData.id, key)
            keyIndex = keyIndex + 1
        end
    end

    print("|cFF00FF00[Hotkeys]|r Dump Complete. " .. count .. " items. Collisions: " .. collisionCount)
end

-- ----------------------------------------------------------------------------
-- 6. AUTO-INITIALIZATION
-- ----------------------------------------------------------------------------
Hotkeys:CreateStaticBar()
Hotkeys:CreateDynamicBar()

local f = CreateFrame("Frame")
--f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function() 
    Hotkeys:ApplyBindings()
    -- Auto-Dump on login/reload to keep Python sync
end)