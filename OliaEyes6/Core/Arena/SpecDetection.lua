local Jungle, jungle = ...

-- Table to store detected specs by GUID
local detectedSpecs = {}
jungle.detectedSpecs = detectedSpecs

function jungle.ClearDetectedSpecs()
    table.wipe(detectedSpecs)
end

local classSpecs = {
    ["DRUID"] = { ["Balance"] = true, ["Feral"] = true, ["Restoration"] = true },
    ["WARRIOR"] = { ["Arms"] = true, ["Fury"] = true, ["Protection"] = true },
    ["PALADIN"] = { ["Holy"] = true, ["Protection"] = true, ["Retribution"] = true },
    ["SHAMAN"] = { ["Elemental"] = true, ["Enhancement"] = true, ["Restoration"] = true },
    ["MAGE"] = { ["Arcane"] = true, ["Fire"] = true, ["Frost"] = true },
    ["WARLOCK"] = { ["Affliction"] = true, ["Demonology"] = true, ["Destruction"] = true },
    ["PRIEST"] = { ["Discipline"] = true, ["Holy"] = true, ["Shadow"] = true },
    ["ROGUE"] = { ["Assassination"] = true, ["Combat"] = true, ["Subtlety"] = true },
    ["HUNTER"] = { ["Beast Mastery"] = true, ["Marksmanship"] = true, ["Survival"] = true },
}

-- Spells cast that immediately identify a specialization
local specSpells = {
    -- Druid
    [33831] = "Balance",      -- Force of Nature
    [33876] = "Feral",        -- Mangle (Cat)
    [33878] = "Feral",        -- Mangle (Bear)
    [18562] = "Restoration",  -- Swiftmend
    [33763] = "Restoration",  -- Lifebloom
    
    -- Warrior
    [12294] = "Arms",         -- Mortal Strike
    [12328] = "Arms",         -- Sweeping Strikes
    [23881] = "Fury",         -- Bloodthirst
    [29801] = "Fury",         -- Rampage
    [23922] = "Protection",   -- Shield Slam
    [12809] = "Protection",   -- Concussion Blow
    [20243] = "Protection",   -- Devastate
    
    -- Paladin
    [20473] = "Holy",         -- Holy Shock
    [31842] = "Holy",         -- Divine Illumination
    [20216] = "Holy",         -- Divine Favor
    [27179] = "Protection",   -- Holy Shield
    [35395] = "Retribution",  -- Crusader Strike
    [20066] = "Retribution",  -- Repentance
    
    -- Shaman
    [16166] = "Elemental",    -- Elemental Mastery
    [30706] = "Elemental",    -- Totem of Wrath
    [30823] = "Enhancement",  -- Shamanistic Rage
    [17364] = "Enhancement",  -- Stormstrike
    [16190] = "Restoration",  -- Mana Tide Totem
    [974]   = "Restoration",  -- Earth Shield
    
    -- Mage
    [12042] = "Arcane",       -- Arcane Power
    [31589] = "Arcane",       -- Slow
    [11113] = "Fire",         -- Blast Wave
    [31661] = "Fire",         -- Dragon's Breath
    [11366] = "Fire",         -- Pyroblast
    [11426] = "Frost",        -- Ice Barrier
    [31687] = "Frost",        -- Summon Water Elemental
    [12472] = "Frost",        -- Icy Veins
    [11958] = "Frost",        -- Cold Snap
    
    -- Warlock
    [30108] = "Affliction",   -- Unstable Affliction
    [18220] = "Affliction",   -- Dark Pact
    [18265] = "Affliction",   -- Siphon Life
    [30283] = "Destruction",  -- Shadowfury
    [17962] = "Destruction",  -- Conflagrate
    [18708] = "Demonology",   -- Fel Domination
    [30146] = "Demonology",   -- Summon Felguard
    
    -- Priest
    [10060] = "Discipline",   -- Power Infusion
    [33206] = "Discipline",   -- Pain Suppression
    [14752] = "Discipline",   -- Divine Spirit
    [34861] = "Holy",         -- Circle of Healing
    [15473] = "Shadow",       -- Shadowform
    [34914] = "Shadow",       -- Vampiric Touch
    [15487] = "Shadow",       -- Silence
    
    -- Rogue
    [34411] = "Assassination",-- Mutilate
    [14177] = "Assassination",-- Cold Blood
    [13750] = "Combat",       -- Adrenaline Rush
    [13877] = "Combat",       -- Blade Flurry
    [36554] = "Subtlety",     -- Shadowstep
    [16511] = "Subtlety",     -- Hemorrhage
    [14183] = "Subtlety",     -- Premeditation
    
    -- Hunter
    [19577] = "Beast Mastery",-- Intimidation
    [19574] = "Beast Mastery",-- Bestial Wrath
    [34490] = "Marksmanship", -- Silencing Shot
    [19386] = "Survival",     -- Wyvern Sting
    [19306] = "Survival",     -- Counterattack
}

-- Buffs/Forms that dynamically indicate a specialization
local specBuffs = {
    [24858] = "Balance",      -- Moonkin Form
    [33891] = "Restoration",  -- Tree of Life
    [17007] = "Feral",        -- Leader of the Pack (Aura)
    [15473] = "Shadow",       -- Shadowform
    [15286] = "Shadow",       -- Vampiric Embrace
    [11426] = "Frost",        -- Ice Barrier
    [12472] = "Frost",        -- Icy Veins
    [12042] = "Arcane",       -- Arcane Power
    [974]   = "Restoration",  -- Earth Shield
    [30823] = "Enhancement",  -- Shamanistic Rage
    [20218] = "Retribution",  -- Sanctity Aura
    [27179] = "Protection",   -- Holy Shield
    [34471] = "Beast Mastery",-- The Beast Within
    [19506] = "Marksmanship", -- Trueshot Aura
    [19028] = "Demonology",   -- Soul Link
    [36563] = "Subtlety",     -- Shadowstep DMG
}

-- Populated dynamically on load to map localized spell names to specs
local specSpellsByName = {}
local specBuffsByName = {}

-- Frame for Event Listening
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        -- Build the name-keyed lookup tables since GetSpellInfo requires player load
        for spellID, spec in pairs(specSpells) do
            local name = C_Spell.GetSpellName(spellID)
            if name then
                specSpellsByName[name] = spec
            end
        end
        for spellID, spec in pairs(specBuffs) do
            local name = C_Spell.GetSpellName(spellID)
            if name then
                specBuffsByName[name] = spec
            end
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, eventType, _, sourceGUID, _, _, _, destGUID, _, _, _, spellID, spellName = CombatLogGetCurrentEventInfo()
        
        -- Detect by signature spell cast
        if sourceGUID and (eventType == "SPELL_CAST_SUCCESS" or eventType == "SPELL_CAST_START" or eventType == "SPELL_CREATE") then
            local spec = specSpells[spellID] or specSpellsByName[spellName]
            if spec then
                local _, classToken = GetPlayerInfoByGUID(sourceGUID)
                if classToken and classSpecs[classToken] and classSpecs[classToken][spec] then
                    detectedSpecs[sourceGUID] = spec
                end
            end
        end
        
        -- Detect by aura application
        if destGUID and (eventType == "SPELL_AURA_APPLIED" or eventType == "SPELL_AURA_REFRESH") then
            local spec = specBuffs[spellID] or specBuffsByName[spellName]
            if spec then
                local _, classToken = GetPlayerInfoByGUID(destGUID)
                if classToken and classSpecs[classToken] and classSpecs[classToken][spec] then
                    detectedSpecs[destGUID] = spec
                end
            end
        end
    end
end)

-- Main helper function: Returns specialization name (string) or nil
function jungle.EnemyPlayerSpec(unitid)
    if not unitid or not UnitExists(unitid) then return nil end
    
    -- Only evaluate players
    if not UnitIsPlayer(unitid) then return nil end
    
    local guid = UnitGUID(unitid)
    if not guid then return nil end
    
    -- 1. Check dynamic cache
    if detectedSpecs[guid] then
        return detectedSpecs[guid]
    end
    
    -- Get localized class and class token
    local _, classToken = UnitClass(unitid)
    if not classToken or not classSpecs[classToken] then return nil end
    
    -- 2. Fallback check: Active Forms / Auras scan
    for spellID, spec in pairs(specBuffs) do
        local name = C_Spell.GetSpellName(spellID)
        if name and classSpecs[classToken][spec] then
            if AuraUtil.FindAuraByName(name, unitid, "HELPFUL") then
                detectedSpecs[guid] = spec
                return spec
            end
        end
    end
    
    -- 3. Fallback check: Current Casts
    local castingName = UnitCastingInfo(unitid) or UnitChannelInfo(unitid)
    if castingName then
        local spec = specSpellsByName[castingName]
        if spec and classSpecs[classToken][spec] then
            detectedSpecs[guid] = spec
            return spec
        end
    end
    
    -- 4. Fallback check: Active signature Pet summons (Felguard / Water Elemental)
    local petUnit = unitid .. "pet"
    if UnitExists(petUnit) then
        local petName = UnitName(petUnit)
        if petName == "Felguard" and classToken == "WARLOCK" then
            detectedSpecs[guid] = "Demonology"
            return "Demonology"
        elseif petName == "Water Elemental" and classToken == "MAGE" then
            detectedSpecs[guid] = "Frost"
            return "Frost"
        end
    end
    
    return nil
end
