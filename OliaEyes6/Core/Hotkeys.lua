local Jungle, jungle = ...
jungle.Hotkeys = {}
local Hotkeys = jungle.Hotkeys

-- 1. Initialize Debug State
Hotkeys.DebugMode = false
Hotkeys.EquipMacroTargets = {}

-- ----------------------------------------------------------------------------
-- 0. MACRO OVERRIDES (Universal)
-- ----------------------------------------------------------------------------
-- Define custom macros here by ID. These take precedence over everything.
Hotkeys.MacroOverrides = {
    -- Druid Powershifting & Safety
    ["Cat Form"]       = "/cast !Cat Form",
    ["Dire Bear Form"] = "/cast !Dire Bear Form",
    ["Travel Form"]    = "/cast !Travel Form",
    ["Pummel"]    = "/use [@mouseover,harm,stance:1/2,worn:shield][stance:1/2,worn:shield][@focus]Shield Bash\n/use [noworn:shield,nostance:3]Berserker Stance\n/use [mod,@focus,harm][@focus,exists,harm][@mouseover,harm][]Pummel",
    ["Battle Stance"]    = "/cast Battle Stance\n/cast Charge",
    ["Backstab"]    = "/cast [stealth] Pick Pocket\n/cast Backstab",
	--["Slam"]	= "/startattack\n/cast Slam\n/stopattack",

    -- Moonweaver reuses the existing Druid spell buttons so the established
    -- dynamic action indices and external key map remain unchanged.
    ["Starfire"] = "/startattack\n/cast [exists,harm,nodead] Starfire",
    ["Wrath"]    = "/startattack\n/cast [exists,harm,nodead] Wrath",
    ["Moonfire"] = "/startattack\n/cast [@focus,exists,harm,nodead] Moonfire",
    ["Insect Swarm"] = "/startattack\n/cast [exists,harm,nodead] Insect Swarm",
   
    -- Example: Stopcasting on specific spells if needed
    -- ["Healing Touch"] = "/stopcasting\n/cast Healing Touch",
}

-- Shared function that runs AFTER a button is clicked
local function Debug_PostClick(self, button, down)
    if down == false then return end
    if Hotkeys.DebugMode then
        local spell = self.debugName or "Unknown"
        if self.debugFallbackName and self.debugPrimaryUnit
        and not UnitExists(self.debugPrimaryUnit) then
            spell = self.debugFallbackName
        end
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
    { id = "Stopattack",      macro = "/stopattack",        icon = "Interface\\Icons\\Inv_Sword_04" }, 
    { id = "Stopcasting", macro = "/stopcasting",        icon = "Interface\\Icons\\Spell_Shadow_Manaburn" },
    { id = "ClearFocus",  macro = "/clearfocus",         icon = "Interface\\Icons\\Spell_Shadow_SacrificialShield" },
    { id = "player",      macro = "/focus player",       icon = "Interface\\Icons\\Ability_Mage_Invisibility" },
    { id = "target",      macro = "/focus target",       icon = "Interface\\Icons\\Ability_Mage_Invisibility" },
    { id = "targettarget",macro = "/focus targettarget", icon = "Interface\\Icons\\Ability_Mage_Invisibility" },
    { id = "mouseover",   macro = "/focus mouseover",    icon = "Interface\\Icons\\Ability_Mage_Invisibility" },
    { id = "pettarget",   macro = "/focus pettarget",    icon = "Interface\\Icons\\Ability_Mage_Invisibility" },
    { id = "Fishing",     macro = "/run OliaFishingBagMaintenance()\n/cast Fishing", icon = "Interface\\Icons\\Trade_Fishing" },
    { id = "Lure", macro = "/use Sharpened Fish Hook\n/use 16\n/use Bright Baubles\n/use 16", icon = "Interface\\Icons\\Trade_Fishing" },
    { id = "Trinkets", macro = "/use 13\n/use 14", icon = "Interface\\Icons\\INV_Jewelry_TrinketPVP_01" },
    { id = "Desync", macro = "/cleartarget[exists, harm]\n/targetlasttarget[noexists]\n/startattack[exists, harm]", icon = "Interface\\Icons\\Ability_Warrior_DecisiveStrike" },
    -- { id = "Desync", macro = "/stopattack\n/startattack", icon = "Interface\\Icons\\Ability_Warrior_DecisiveStrike" },

    -- Follower Support Macros
    { id = "Mount", macro = "/cancelform [outdoors,nocombat]\n/cast [outdoors,nocombat] Reins of the Striped Nightsaber", icon = "Interface\\Icons\\Spell_Nature_Swiftness" },
    { id = "Follow", macro = "/follow target", icon = "Interface\\Icons\\Ability_Rogue_Sprint" },
    { id = "StopFollow", macro = "/follow player", icon = "Interface\\Icons\\Ability_Rogue_Sprint" },
    { id = "Food", macro = "/use Roasted Quail", icon = "Interface\\Icons\\INV_Misc_Food_10" },
    { id = "Drink", macro = "/use Sweet Nectar", icon = "Interface\\Icons\\INV_Drink_05" },

    -- Shared weapon-swap button slots. Warrior and Druid update the same
    -- hidden buttons dynamically, preserving the established key pool.
    { id = "Equip2H",     macro = "/eq [noworn:two-hand] placeholder",                                           icon = "Interface\\Icons\\INV_Sword_04" },
    { id = "EquipDW",     macro = "/equipslot 16 placeholder\n/equipslot 17 placeholder",                        icon = "Interface\\Icons\\INV_Sword_04" },
    { id = "EquipShield", macro = "/eq [noworn:shield] placeholder\n/equipslot [noworn:one-hand] 16 placeholder", icon = "Interface\\Icons\\INV_Shield_05" },
    { id = "EquipFastOffHand", macro = "/equipslot 17 placeholder",                                              icon = "Interface\\Icons\\INV_Sword_04" },
    { id = "EquipSlowOffHand", macro = "/equipslot 17 placeholder",                                              icon = "Interface\\Icons\\INV_Sword_04" },
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
		{ id = "Maim", icon = "Interface\\Icons\\Ability_Druid_Maim" },
        { id = "Mangle (Bear)", icon = "Interface\\Icons\\Ability_Druid_Mangle2" },
        { id = "Maul", icon = "Interface\\Icons\\Ability_Druid_Maul" },
        { id = "Lacerate", icon = "Interface\\Icons\\Ability_Druid_Lacerate" },
        { id = "Swipe", icon = "Interface\\Icons\\Inv_Misc_MonsterClaw_03" },
        { id = "Bash", icon = "Interface\\Icons\\Ability_Druid_Bash" },
        { id = "Feral Charge", icon = "Interface\\Icons\\Ability_Hunter_Pet_Bear" },
        { id = "Claw", icon = "Interface\\Icons\\Ability_Druid_Rake" },
        { id = "Cat Form", icon = "Interface\\Icons\\Ability_Druid_CatForm" },
        { id = "Dire Bear Form", icon = "Interface\\Icons\\Ability_Racial_BearForm" },
        { id = "Travel Form", icon = "Interface\\Icons\\Ability_Druid_TravelForm" },
        { id = "Moonkin Form", icon = "Interface\\Icons\\Spell_Nature_ForceOfNature" },
        { id = "Tree of Life", icon = "Interface\\Icons\\Ability_Druid_TreeofLife" },
        { id = "Mark of the Wild", icon = "Interface\\Icons\\Spell_Nature_Regeneration" },
        { id = "Thorns", icon = "Interface\\Icons\\Spell_Nature_Thorns" },
        { id = "Omen of Clarity", icon = "Interface\\Icons\\Spell_Nature_CrystalBall" },
        { id = "Remove Curse", icon = "Interface\\Icons\\Spell_Holy_RemoveCurse" },
        { id = "Abolish Poison", icon = "Interface\\Icons\\Spell_Nature_NullifyPoison_02" },
        { id = "Rebirth", icon = "Interface\\Icons\\Spell_Nature_Reincarnation" },
		{ id = "Faerie Fire (Feral)", icon = "Interface\\Icons\\Spell_Nature_FaerieFire" },
		{ id = "Faerie Fire", icon = "Interface\\Icons\\Spell_Nature_FaerieFire" },
		{ id = "Ravage", icon = "Interface\\Icons\\Ability_Druid_Ravage" },
		{ id = "Tiger's Fury", icon = "Interface\\Icons\\Ability_Mount_JungleTiger" },
        { id = "Demoralizing Roar", icon = "Interface\\Icons\\Ability_Druid_DemoralizingRoar" },
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
        { id = "Pick Pocket", icon = "Interface\\Icons\\INV_Misc_Bag_11" },
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
        { id = "Thunder Clap", icon = "Interface\\Icons\\Spell_Nature_ThunderClap" },
        { id = "Shield Block", icon = "Interface\\Icons\\Ability_Defend" },
        { id = "Taunt", icon = "Interface\\Icons\\Spell_Nature_Reincarnation" },
        { id = "Bloodrage", icon = "Interface\\Icons\\Ability_Racial_BloodRage" },
        { id = "Challenging Shout", icon = "Interface\\Icons\\Ability_BullRush" },
        { id = "Defensive Stance", icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance" },
        { id = "Battle Stance", icon = "Interface\\Icons\\Ability_Warrior_OffensiveStance" },
        { id = "Berserker Stance", icon = "Interface\\Icons\\Ability_Racial_Avatar" },
        { id = "Berserker Rage", icon = "Interface\\Icons\\Spell_Nature_AncestralGuardian" },
        { id = "Piercing Howl", icon = "Interface\\Icons\\Spell_Shadow_DeathScream" },
        { id = "Hamstring", icon = "Interface\\Icons\\Ability_ShockWave" },
        { id = "Rend", icon = "Interface\\Icons\\Ability_Gouge" },
        { id = "Mocking Blow", icon = "Interface\\Icons\\Ability_Warrior_PunishingBlow" },
        { id = "Concussion Blow", icon = "Interface\\Icons\\Ability_ThunderBolt" },
        { id = "Sweeping Strikes", icon = "Interface\\Icons\\Ability_Rogue_SliceDice" },
        { id = "Death Wish", icon = "Interface\\Icons\\Spell_Shadow_DeathPact" },
        { id = "Recklessness", icon = "Interface\\Icons\\Ability_CriticalStrike" },
        { id = "Retaliation", icon = "Interface\\Icons\\Ability_Warrior_Challange" },
        { id = "Shield Wall", icon = "Interface\\Icons\\Ability_Warrior_ShieldWall" },
        { id = "Rampage", icon = "Interface\\Icons\\Ability_Warrior_Rampage" },
        { id = "Victory Rush", icon = "Interface\\Icons\\Ability_Warrior_Devastate" },
		{ id = "Slam", icon = "Interface\\Icons\\Ability_Warrior_DecisiveStrike" },
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

-- 1. POOL ROTATION (CTRL + Keyboard Only - 45 Slots)
-- Removed CTRL+Gamepad and non-functional tokens.
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

    -- Symbols & Backspace (7)
    "CTRL-[", "CTRL-]", "CTRL-;", "CTRL-'", "CTRL-,", "CTRL-.", "CTRL-BACKSPACE",

    -- Unmodified Numbers for overlap (5)
    "0", "6", "7", "8", "9",
    "ALT-0", "ALT-6", "ALT-7", "ALT-8", "ALT-9"
}

-- 2. POOL TARGETING (Unmodified Base Keys - 51 Slots)
-- Pruned: PAD5, PAD6, PADPADDLE 1-4, and all Analog Sticks.
Hotkeys.Pool_Targeting = {
    -- Letters (7)
    "I", "J", "K", "L", "O", "U", "Y",

    -- Function Keys (11)
    "F1", "F2", "F3", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12",

    -- Navigation (10)
    "INSERT", "DELETE", "HOME", "END", "PAGEUP", "PAGEDOWN", 
    "UP", "DOWN", "LEFT", "RIGHT",

    -- Symbols & Backspace (7)
    "[", "]", ";", "'", ",", ".", "BACKSPACE",

    -- GamePad Buttons (11 Verified)
    "PADDUP", "PADDRIGHT", "PADDDOWN", "PADDLEFT",
    "PAD1", "PAD2", "PAD3", "PAD4",
    "PADLSTICK", "PADRSTICK",
    "PADFORWARD",

    -- Gamepad Aliases (5 Verified)
    "PADLSHOULDER", "PADRSHOULDER", "PADLTRIGGER", "PADRTRIGGER", "PADBACK",
    
    
    "ALT-I", "ALT-J", "ALT-K", "ALT-L", "ALT-O", "ALT-U", "ALT-Y",
    "ALT-[", "ALT-]", "ALT-;", "ALT-'", "ALT-,", "ALT-.", "ALT-BACKSPACE", "ALT-B",
    "ALT-P", "ALT-H",

    "CTRL-B", "CTRL-P", "CTRL-H",

    -- Weapon Equip Keys (3)
    "CTRL-N", "ALT-N", "ALT-M",

    -- Soft target focus fallback
    "ALT-INSERT"
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
    self.StaticAliases = {}
    
    local keyIndex = 1
    local btnSize = 30
    local spacing = 2
    local columns = 8 

    -- Universal Button Creator
    -- If 'forcedKey' is provided, it uses it. Otherwise, it pulls from the Pool.
    local function CreateBtn(id, macroText, iconPath, forcedKey)
        -- ----------------------------------------------------
        -- OVERRIDE CHECK: Intercept ID for Custom Macros
        -- ----------------------------------------------------
        if Hotkeys.MacroOverrides[id] then
            macroText = Hotkeys.MacroOverrides[id]
        end
        -- ----------------------------------------------------

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
        btn:RegisterForClicks("AnyUp", "AnyDown")
        
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
        return btn
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
    local _, playerClass = UnitClass("player")
    for _, data in ipairs(self.GlobalDefaults) do
        if not data.class or data.class == playerClass then
            CreateBtn(data.id, data.macro, data.icon)
        end
    end

    -- 2. Missing Core Units
    CreateBtn("focus", "/focus focus", "Interface\\Icons\\Ability_Hunter_SniperShot")
    CreateBtn("pet", "/focus pet", "Interface\\Icons\\Ability_Hunter_BeastCall")
    
    -- 3. Group Units
    for i = 1, 4 do CreateBtn("party"..i, "/focus party"..i) end
    for i = 5, 5 do CreateBtn("arena"..i, "/focus arena"..i) end -- Adjusted loop start to 5 for remaining Arena unit
    for i = 1, 4 do CreateBtn("arena"..i, "/focus arena"..i) end -- Correct loop for Arena 1-4
    for i = 1, 40 do
        local raidUnit = "raid" .. i
        local macroText = "/focus " .. raidUnit
        local fallbackUnit
        local fallbackActionId

        if i >= 28 then
            fallbackUnit = "raid" .. (i - 27) .. "target"
            fallbackActionId = jungle.EnemyFocus:GetActionId(fallbackUnit)
            macroText = "/focus [@" .. raidUnit .. ",exists] " .. raidUnit
                .. "; [@" .. fallbackUnit .. ",exists,harm,nodead] " .. fallbackUnit
        end

        local btn = CreateBtn(raidUnit, macroText)
        if btn and fallbackUnit then
            btn.debugPrimaryUnit = raidUnit
            btn.debugFallbackName = fallbackUnit
            local key = self.StaticBindings[raidUnit]
            self.StaticBindings[fallbackActionId] = key
            table.insert(self.StaticAliases, {
                id = fallbackActionId,
                unit = fallbackUnit,
                key = key,
                sourceId = raidUnit,
            })
        end
    end
    CreateBtn("softenemy", "/focus softenemy", "Interface\\Icons\\Ability_Hunter_SniperShot")

    self.StaticBarFrame = parent
end

-- Range metadata is shared by readiness, focus selection, and default macros.
-- Custom macro contents remain authoritative, including any explicit focus use.
function Hotkeys:GetActionMacroText(actionID, actionHasRange)
    if self.MacroOverrides[actionID] then return self.MacroOverrides[actionID] end
    local ranges = actionHasRange or jungle.actionHasRange
    return (ranges[actionID] and "/cast [@focus,exists] " or "/cast ") .. actionID
end

function Hotkeys:RefreshActionRanges()
    if InCombatLockdown() then
        self.actionRangesDirty = true
        return false
    end

    local actionHasRange = {}
    local _, class = UnitClass("player")
    for _, action in ipairs(self.GlobalDefaults) do
        if not action.class or action.class == class then
            actionHasRange[action.id] = C_Spell.SpellHasRange(action.id)
        end
    end
    for _, action in ipairs(self.ClassSpells[class] or {}) do
        actionHasRange[action.id] = C_Spell.SpellHasRange(action.id)
    end

    -- Publish only after buttons match; combat keeps the previous pair intact.
    for _, button in ipairs(self.DynamicButtons or {}) do
        local macro = self:GetActionMacroText(button.spell, actionHasRange)
        if button.frame:GetAttribute("macrotext") ~= macro then
            button.frame:SetAttribute("macrotext", macro)
        end
    end
    jungle.actionHasRange = actionHasRange
    self.actionRangesDirty = false
    return true
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
        
        -- ----------------------------------------------------
        -- OVERRIDE CHECK: Dynamic Bar
        -- ----------------------------------------------------
        btn:SetAttribute("macrotext", self:GetActionMacroText(spellData.id))
        -- ----------------------------------------------------
        
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

local last2H, last1H, lastShield, lastMH, lastOH, lastThird, lastFastOH, lastSlowOH
local lastVelocityMH, lastVelocityOH, lastBatteryMH, lastVelocitySP, lastBatteryFAP
local lastHealingMH, lastHealingOH, lastHealingPower
local equipMacrosDirty = false
function Hotkeys:UpdateEquipMacros()
    if InCombatLockdown() then return end
    local _, engClass = UnitClass('player')
    if not self.StaticButtons then return end

    if engClass == "DRUID" then
        local velocityMH, velocityOH, batteryMH, velocitySP, batteryFAP
        local healingMH, healingOH, healingPower
        if jungle.GetBestMoonweaverWeapons then
            velocityMH, velocityOH, batteryMH, velocitySP, batteryFAP,
                healingMH, healingOH, healingPower = jungle.GetBestMoonweaverWeapons()
        end

        -- Druids reuse the established Warrior button IDs: Battery is the
        -- 2H slot and Velocity is the DW/weapon-set slot.
        self.EquipMacroTargets.EquipDW = velocityMH and {
            mainHand = velocityMH,
            offHand = velocityOH,
        } or nil
        self.EquipMacroTargets.Equip2H = batteryMH and {
            mainHand = batteryMH,
        } or nil
        self.EquipMacroTargets.EquipShield = healingMH and {
            mainHand = healingMH,
            offHand = healingOH,
        } or nil

        for _, btnData in ipairs(self.StaticButtons) do
            if btnData.id == "EquipDW" then
                local macro = ""
                if velocityMH then
                    macro = "/equipslot 16 " .. velocityMH
                    if velocityOH then
                        macro = macro .. "\n/equipslot 17 " .. velocityOH
                    end
                end
                btnData.frame:SetAttribute("macrotext", macro)
            elseif btnData.id == "Equip2H" then
                btnData.frame:SetAttribute("macrotext", batteryMH and ("/equipslot 16 " .. batteryMH) or "")
            elseif btnData.id == "EquipShield" then
                local macro = ""
                if healingMH then
                    macro = "/equipslot 16 " .. healingMH
                    if healingOH then
                        macro = macro .. "\n/equipslot 17 " .. healingOH
                    end
                end
                btnData.frame:SetAttribute("macrotext", macro)
            elseif btnData.id == "EquipFastOffHand"
            or btnData.id == "EquipSlowOffHand" then
                btnData.frame:SetAttribute("macrotext", "")
            end
        end
        equipMacrosDirty = false

        if velocityMH ~= lastVelocityMH or velocityOH ~= lastVelocityOH
        or batteryMH ~= lastBatteryMH or velocitySP ~= lastVelocitySP
        or batteryFAP ~= lastBatteryFAP or healingMH ~= lastHealingMH
        or healingOH ~= lastHealingOH or healingPower ~= lastHealingPower then
            lastVelocityMH, lastVelocityOH, lastBatteryMH = velocityMH, velocityOH, batteryMH
            lastVelocitySP, lastBatteryFAP = velocitySP, batteryFAP
            lastHealingMH, lastHealingOH, lastHealingPower = healingMH, healingOH, healingPower
            local function item(name) return name and ("|cFF00CCFF" .. name .. "|r") or "|cFF666666none|r" end
            local velocityText = item(velocityMH)
            if velocityOH then velocityText = velocityText .. " |cFF888888/|r " .. item(velocityOH) end
            local healingText = item(healingMH)
            if healingOH then healingText = healingText .. " |cFF888888/|r " .. item(healingOH) end
            print("|cFF00FF00[Olia]|r |cFFFFFFFFMoonweaver equip macros updated:|r")
            print("  |cFF00FFFF[Velocity " .. tostring(velocitySP or 0) .. " SP]|r " .. velocityText)
            print("  |cFF00FF00[Battery " .. tostring(batteryFAP or 0) .. " FAP]|r " .. item(batteryMH))
            print("  |cFFFF69B4[Healing " .. tostring(healingPower or 0) .. "]|r " .. healingText)
        end
        return
    end

    if engClass ~= "WARRIOR" then return end
    
    local best2H = jungle.GetBest2HWeapon and jungle.GetBest2HWeapon() or nil
    local best1H = jungle.GetBest1HWeapon and jungle.GetBest1HWeapon() or nil
    local bestShield = jungle.GetBestShield and jungle.GetBestShield() or nil
    local bestMH, bestOH, bestThird
    if jungle.GetBestDWWeapons then
        bestMH, bestOH, bestThird = jungle.GetBestDWWeapons()
    end
    
    local fastOH = nil
    local slowOH = nil
    if bestOH and bestThird and jungle.GetItemSpeed then
        local speedOH = jungle.GetItemSpeed(bestOH) or 2.0
        local speedThird = jungle.GetItemSpeed(bestThird) or 2.0
        if speedOH <= speedThird then
            fastOH = bestOH
            slowOH = bestThird
        else
            fastOH = bestThird
            slowOH = bestOH
        end
    elseif bestOH then
        fastOH = bestOH
        slowOH = bestOH
    end

    for _, btnData in ipairs(self.StaticButtons) do
        if btnData.id == "Equip2H" and best2H then
            btnData.frame:SetAttribute("macrotext", "/eq [noworn:two-hand] " .. best2H)
        elseif btnData.id == "EquipDW" and bestMH then
            local macro = "/equipslot 16 " .. bestMH
            if bestOH then
                macro = macro .. "\n/equipslot 17 " .. bestOH
            end
            btnData.frame:SetAttribute("macrotext", macro)
        elseif btnData.id == "EquipShield" then
            local parts = {}
            if bestShield then
                table.insert(parts, "/eq [noworn:shield] " .. bestShield)
            end
            if best1H then
                table.insert(parts, "/equipslot [noworn:one-hand] 16 " .. best1H)
            end
            if #parts > 0 then
                btnData.frame:SetAttribute("macrotext", table.concat(parts, "\n"))
            end
        elseif btnData.id == "EquipFastOffHand" then
            self.EquipMacroTargets.EquipFastOffHand = fastOH
            btnData.frame:SetAttribute("macrotext", fastOH and ("/equipslot 17 " .. fastOH) or "")
        elseif btnData.id == "EquipSlowOffHand" then
            self.EquipMacroTargets.EquipSlowOffHand = slowOH
            btnData.frame:SetAttribute("macrotext", slowOH and ("/equipslot 17 " .. slowOH) or "")
        end
    end
    equipMacrosDirty = false
    
    if best2H ~= last2H or best1H ~= last1H or bestShield ~= lastShield or bestMH ~= lastMH or bestOH ~= lastOH or bestThird ~= lastThird or fastOH ~= lastFastOH or slowOH ~= lastSlowOH then
        last2H, last1H, lastShield, lastMH, lastOH, lastThird, lastFastOH, lastSlowOH = best2H, best1H, bestShield, bestMH, bestOH, bestThird, fastOH, slowOH
        local function item(name) return name and ("|cFF00CCFF" .. name .. "|r") or "|cFF666666none|r" end
        print("|cFF00FF00[Olia]|r |cFFFFFFFFEquip macros updated:|r")
        print("  |cFFFFD700[2H]|r " .. item(best2H) .. "    |cFFFFD700[1H]|r " .. item(best1H))
        print("  |cFFFFD700[DW]|r " .. item(bestMH) .. " |cFF888888/|r " .. item(bestOH) .. (bestThird and (" (3rd: " .. item(bestThird) .. ")") or ""))
        print("  |cFFFFD700[Shield]|r " .. item(bestShield))
        print("  |cFFFFD700[OH Fast]|r " .. item(fastOH) .. " |cFFFFD700[OH Slow]|r " .. item(slowOH))
    end
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

    if self.StaticAliases then
        for _, alias in ipairs(self.StaticAliases) do
            AddEntry("GLOBAL", "StaticAlias", alias.id, alias.key)
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

Hotkeys:RefreshActionRanges()
Hotkeys:CreateStaticBar()
Hotkeys:CreateDynamicBar()

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("SPELLS_CHANGED")
f:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(self, event) 
    if event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD"
    or event == "ACTIVE_TALENT_GROUP_CHANGED"
    or (event == "PLAYER_REGEN_ENABLED" and Hotkeys.actionRangesDirty) then
        Hotkeys:RefreshActionRanges()
    end

    if event == "PLAYER_ENTERING_WORLD" then
        OliaDebugLog = {} 
        Hotkeys:DumpBindings()
        Hotkeys:ApplyBindings()
        print("|cFF00FF00[Olia]|r System Ready: Logs Cleared & Bindings Exported.")
    end
    
    if event == "BAG_UPDATE_DELAYED" or event == "PLAYER_EQUIPMENT_CHANGED"
    or event == "GET_ITEM_INFO_RECEIVED" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
        if InCombatLockdown() then
            equipMacrosDirty = true
        else
            Hotkeys:UpdateEquipMacros()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if equipMacrosDirty then
            Hotkeys:UpdateEquipMacros()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Update equip macros (delayed to ensure item data is loaded)
        C_Timer.After(1, function()
            if not InCombatLockdown() then
                Hotkeys:UpdateEquipMacros()
            end
        end)
    end
end)

-- Opt-in event timing; original scripts remain installed while tracing is off.
jungle.RaidTrace:WatchEventFrame(f, "hotkeyMaintenance")
