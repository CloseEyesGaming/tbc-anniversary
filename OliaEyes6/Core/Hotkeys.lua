local Jungle, jungle = ...
jungle.Hotkeys = {}
local Hotkeys = jungle.Hotkeys

-- 1. Initialize Debug State
Hotkeys.DebugMode = false

-- Shared function that runs AFTER a button is clicked
local function Debug_PostClick(self)
    if Hotkeys.DebugMode then
        local spell = self.debugName or "Unknown"
        local key = self.debugKey or "Unknown"
        local timestamp = date("%H:%M:%S")

        print("|cff00ccff[Olia]|r DEBUG: [" .. spell .. "] via [" .. key .. "] at " .. timestamp)

        if not OliaDebugLog then OliaDebugLog = {} end
        table.insert(OliaDebugLog, {
            ["timestamp"] = timestamp,
            ["spell"] = spell,
            ["key"] = key
        })
    end
end

-- ----------------------------------------------------------------------------
-- 1. DATA: GLOBAL ACTIONS
-- ----------------------------------------------------------------------------
-- NOTE: Threads 1-6 are removed from here. They are hardcoded in CreateStaticBar.
Hotkeys.GlobalDefaults = {
    { id = "Attack",      macro = "/startattack",        icon = "Interface\\Icons\\Inv_Sword_04" }, 
    { id = "Stopcasting", macro = "/stopcasting",        icon = "Interface\\Icons\\Spell_Shadow_Manaburn" },
    { id = "ClearFocus",  macro = "/clearfocus",         icon = "Interface\\Icons\\Spell_Shadow_SacrificialShield" },
    { id = "player",      macro = "/focus player",       icon = "Interface\\Icons\\Ability_Mage_Invisibility" },
    { id = "target",      macro = "/focus target",       icon = "Interface\\Icons\\Ability_Mage_Invisibility" },
    { id = "targettarget",macro = "/focus targettarget", icon = "Interface\\Icons\\Ability_Mage_Invisibility" },
    { id = "mouseover",   macro = "/focus mouseover",    icon = "Interface\\Icons\\Ability_Mage_Invisibility" },
    { id = "pettarget",   macro = "/focus pettarget",    icon = "Interface\\Icons\\Ability_Mage_Invisibility" },
    { id = "Fishing",   macro = "/cast Fishing",		 icon = "Interface\\Icons\\Trade_Fishing" },
}

-- ----------------------------------------------------------------------------
-- 2. DATA: SPELL DATABASE (TBC CLASSIC)
-- ----------------------------------------------------------------------------
Hotkeys.ClassSpells = {
    ["DRUID"] = {
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
        { id = "Cat Form", icon = "Interface\\Icons\\Ability_Druid_CatForm" },
        { id = "Bear Form", icon = "Interface\\Icons\\Ability_Racial_BearForm" },
        { id = "Dire Bear Form", icon = "Interface\\Icons\\Ability_Racial_BearForm" },
        { id = "Travel Form", icon = "Interface\\Icons\\Ability_Druid_TravelForm" },
        { id = "Moonkin Form", icon = "Interface\\Icons\\Spell_Nature_ForceOfNature" },
        { id = "Tree of Life", icon = "Interface\\Icons\\Ability_Druid_TreeofLife" },
        { id = "Mark of the Wild", icon = "Interface\\Icons\\Spell_Nature_Regeneration" },
        { id = "Thorns", icon = "Interface\\Icons\\Spell_Nature_Thorns" },
        { id = "Gift of the Wild", icon = "Interface\\Icons\\Spell_Nature_Regeneration" },
        { id = "Omen of Clarity", icon = "Interface\\Icons\\Spell_Nature_CrystalBall" },
        { id = "Remove Curse", icon = "Interface\\Icons\\Spell_Holy_RemoveCurse" },
        { id = "Abolish Poison", icon = "Interface\\Icons\\Spell_Nature_NullifyPoison_02" },
        { id = "Rebirth", icon = "Interface\\Icons\\Spell_Nature_Reincarnation" },
		{ id = "Faerie Fire (Feral)", icon = "Interface\\Icons\\Spell_Nature_FaerieFire" },
		{ id = "Faerie Fire", icon = "Interface\\Icons\\Spell_Nature_FaerieFire" },
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

-- 1. POOL ROTATION (CTRL + Keyboard Only - 44 Slots)
-- Removed CTRL+Gamepad as requested.
Hotkeys.Pool_Rotation = {
    -- Numbers (5)
    "CTRL-0", "CTRL-6", "CTRL-7", "CTRL-8", "CTRL-9",

    -- Letters (7)
    "CTRL-I", "CTRL-J", "CTRL-K", "CTRL-L", "CTRL-O", "CTRL-U", "CTRL-Y",

    -- Function Keys (11)
    "CTRL-F1", "CTRL-F2", "CTRL-F3", "CTRL-F5", "CTRL-F6", "CTRL-F7", 
    "CTRL-F8", "CTRL-F9", "CTRL-F10", "CTRL-F11", "CTRL-F12",

    -- Navigation (10)
    "CTRL-INSERT", "CTRL-DELETE", "CTRL-HOME", "CTRL-END", "CTRL-PAGEUP", "CTRL-PAGEDOWN", 
    "CTRL-UP", "CTRL-DOWN", "CTRL-LEFT", "CTRL-RIGHT",

    -- Symbols & Backspace (11)
    "CTRL-[", "CTRL-]", "CTRL-\\", "CTRL-;", "CTRL-'", 
    "CTRL-,", "CTRL-.", "CTRL-BACKSPACE",
	
	-- [NEW] Readable Aliases
    "PADLSHOULDER", "PADRSHOULDER",
    "PADLTRIGGER", "PADRTRIGGER",
    "PADBACK"
}

-- 2. POOL TARGETING (Unmodified Base Keys - 71 Slots)
Hotkeys.Pool_Targeting = {
    -- Numbers (5)
    "0", "6", "7", "8", "9",

    -- Letters (7)
    "I", "J", "K", "L", "O", "U", "Y",

    -- Function Keys (11)
    "F1", "F2", "F3", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12",

    -- Navigation (10)
    "INSERT", "DELETE", "HOME", "END", "PAGEUP", "PAGEDOWN", 
    "UP", "DOWN", "LEFT", "RIGHT",

    -- Symbols & Backspace (11)
    "[", "]", "\\", ";", "'", ",", ".", "BACKSPACE",

    -- GamePad Buttons (27)
    "PADDUP", "PADDRIGHT", "PADDDOWN", "PADDLEFT",
    "PAD1", "PAD2", "PAD3", "PAD4", "PAD5", "PAD6",
    "PADLSTICK", "PADRSTICK",
    "PADLSTICKUP", "PADLSTICKRIGHT", "PADLSTICKDOWN", "PADLSTICKLEFT",
    "PADRSTICKUP", "PADRSTICKRIGHT", "PADRSTICKDOWN", "PADRSTICKLEFT",
    "PADPADDLE1", "PADPADDLE2", "PADPADDLE3", "PADPADDLE4",
    "PADFORWARD", "PADSYSTEM", "PADSOCIAL"
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

    -- Universal Button Creator
    -- If 'forcedKey' is provided, it uses it. Otherwise, it pulls from the Pool.
    local function CreateBtn(id, macroText, iconPath, forcedKey)
        local key = forcedKey
        
        -- If no forced key, grab next one from pool
        if not key then
            key = self.Pool_Targeting[keyIndex]
            if not key then 
                print("|cFFFF0000[Hotkeys]|r ERROR: Pool Exhausted at '" .. id .. "'")
                return 
            end
            keyIndex = keyIndex + 1
        end
        
        -- Generate name: Use fixed name for forced keys, indexed name for pool keys
        local btnName
        if forcedKey then
             btnName = "CA_Static_" .. id:gsub(" ", "")
        else
             btnName = "CA_Static_" .. (keyIndex - 1)
        end
        
        local btn = CreateFrame("Button", btnName, parent, "SecureActionButtonTemplate")
        btn:SetSize(btnSize, btnSize)
        btn:RegisterForClicks("AnyDown")
        
        -- Layout (Simple grid, threads separate)
        if forcedKey then
             btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 40, 0) -- Hidden/Offside for threads
        else
            local index = keyIndex - 2 -- Reset to 0-based from current index (since we inc'd)
            local row = math.floor(index / columns)
            local col = index % columns
            btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -(col * (btnSize + spacing)), -(row * (btnSize + spacing)))
        end
        
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
		
		-- Store info for the debugger
		btn.debugName = id 
		btn.debugKey  = key 
		
		-- Attach listener (SKIP Threads)
        if not string.find(id, "Thread") then
		    btn:SetScript("PostClick", Debug_PostClick)
        end
        
        table.insert(self.StaticButtons, { frame = btn, key = key, id = id })
        self.StaticBindings[id] = key
    end
    
    -- 0. HARDCODED THREADS (Num 1-6) - Does NOT use Pool
    for i = 1, 6 do
        local t_key = "NUMPAD"..i
        local t_id = "Thread "..i
        local t_macro = "/run run_thread"..i.."()"
        local t_icon = (i % 2 == 1) and "Interface\\Icons\\Spell_ChargePositive" or "Interface\\Icons\\Spell_ChargeNegative"
        CreateBtn(t_id, t_macro, t_icon, t_key)
    end
	-- Mostly for fihsing loop mode
	CreateBtn("Thread 7", "/run run_thread7()", "Interface\\Icons\\Spell_ChargePositive", "F4")

    -- 1. Global Defaults (Attack, Stopcast, etc)
    for _, data in ipairs(self.GlobalDefaults) do
        CreateBtn(data.id, data.macro, data.icon)
    end

    -- 2. Missing Core Units
    CreateBtn("focus", "/focus focus", "Interface\\Icons\\Ability_Hunter_SniperShot")
    CreateBtn("pet", "/focus pet", "Interface\\Icons\\Ability_Hunter_BeastCall")
	
    -- 3. Group Units
    for i = 1, 4 do CreateBtn("party"..i, "/focus party"..i) end
    for i = 5, 5 do CreateBtn("arena"..i, "/focus arena"..i) end -- Adjusted loop start to 5 for remaining Arena unit
    for i = 1, 4 do CreateBtn("arena"..i, "/focus arena"..i) end -- Correct loop for Arena 1-4
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
        if not key then 
            print("|cFFFF0000[Hotkeys]|r ERROR: Rotation Pool Exhausted!")
            break 
        end 
        
        local btnName = "CA_Dynamic_" .. keyIndex
        local btn = CreateFrame("Button", btnName, parent, "SecureActionButtonTemplate")
        btn:SetSize(btnSize, btnSize)
        btn:RegisterForClicks("AnyDown")

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
		
		btn.debugName = spellData.id 
		btn.debugKey  = key 
		btn:SetScript("PostClick", Debug_PostClick)
        
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

function Hotkeys:ToggleDebug()
    self.DebugMode = not self.DebugMode
	
	if jungle.Debug then
        jungle.Debug:Toggle(self.DebugMode)
    end
	
    local status = self.DebugMode and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r"
    print("|cFF00FFFF[Hotkeys]|r Debug Mode: " .. status)

    if InCombatLockdown() then return end
    local alpha = self.DebugMode and 1 or 0
    if self.StaticBarFrame then self.StaticBarFrame:SetAlpha(alpha) end
    if self.DynamicBarFrame then self.DynamicBarFrame:SetAlpha(alpha) end
end

function Hotkeys:GenerateColor(str)
    if not jungle.Color then return "000000" end
    local colorObj = jungle.Color:new()
    local rgb = colorObj:makeColor(str)
    local r = math.floor(rgb[1] * 255 + 0.5)
    local g = math.floor(rgb[2] * 255 + 0.5)
    local b = math.floor(rgb[3] * 255 + 0.5)
    return string.format("%02x%02x%02x", r, g, b)
end

function Hotkeys:DumpBindings()
    OliaEyes_Export = {}
    local count = 0
    local colorMap = {}
    
    print("|cFF00FFFF[Hotkeys]|r Dump Started (Using jungle.Color)...")

    local function AddEntry(className, typeName, id, key)
        local color = self:GenerateColor(id)
        if colorMap[color] and colorMap[color] ~= id then
            print("|cFFFF0000[COLLISION]|r " .. color .. " : " .. colorMap[color] .. " vs " .. id)
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

    if self.StaticButtons then
        for _, btn in ipairs(self.StaticButtons) do
            AddEntry("GLOBAL", "Static", btn.id, btn.key)
        end
    end

    for className, spellList in pairs(self.ClassSpells) do
        local keyIndex = 1
        for _, spellData in ipairs(spellList) do
            local key = self.Pool_Rotation[keyIndex]
            if not key then break end
            AddEntry(className, "Dynamic", spellData.id, key)
            keyIndex = keyIndex + 1
        end
    end

    print("|cFF00FF00[Hotkeys]|r Dump Complete. " .. count .. " items.")
end

Hotkeys:CreateStaticBar()
Hotkeys:CreateDynamicBar()

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function() 
    OliaDebugLog = {} 
    Hotkeys:DumpBindings()
    Hotkeys:ApplyBindings()
    print("|cFF00FF00[Olia]|r System Ready: Logs Cleared & Bindings Exported.")
end)