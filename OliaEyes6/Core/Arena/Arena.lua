local Jungle, jungle = ...

local Arena = {}
jungle.Arena = Arena

Arena.timeToStart = 0
Arena.matchStarted = false
Arena.enemies = {}
Arena.cooldowns = {}
Arena.targets = {}

-- Trinket tracking (2 min CD)
local pvpTrinkets = {
    [42292] = true, -- PvP Trinket
    [7744] = true,  -- Will of the Forsaken
}

-- Major Cooldowns (ID to Data)
local majorCooldowns = {
    -- MAGE
    [1953] = { class = "MAGE", type = "GapCloser", cd = 15, range = "melee" }, -- Blink
    [2139] = { class = "MAGE", type = "Interrupt", cd = 24, range = "range" }, -- Counterspell
    [45438] = { class = "MAGE", type = "Defensive", cd = 300, range = "melee" }, -- Ice Block
    [12472] = { class = "MAGE", type = "Burst", cd = 180, spec = "Frost", range = "melee" }, -- Icy Veins
    [31687] = { class = "MAGE", type = "Utility", cd = 180, spec = "Frost", range = "melee" }, -- Summon Water Elemental
    [12043] = { class = "MAGE", type = "Burst", cd = 180, spec = "Arcane", range = "melee" }, -- Presence of Mind
    [11129] = { class = "MAGE", type = "Burst", cd = 180, spec = "Fire", range = "melee" }, -- Combustion
    [31661] = { class = "MAGE", type = "CC", cd = 20, spec = "Fire", range = "melee" }, -- Dragon's Breath
    [12042] = { class = "MAGE", type = "Burst", cd = 180, spec = "Arcane", range = "melee" }, -- Arcane Power
    [11958] = { class = "MAGE", type = "Utility", cd = 384, spec = "Frost", range = "melee" }, -- Cold Snap

    -- ROGUE
    [1766] = { class = "ROGUE", type = "Interrupt", cd = 10, range = "melee" }, -- Kick
    [8643] = { class = "ROGUE", type = "CC", cd = 20, range = "melee" }, -- Kidney Shot
    [31224] = { class = "ROGUE", type = "Defensive", cd = 60, range = "melee" }, -- Cloak of Shadows
    [26889] = { class = "ROGUE", type = "Defensive", cd = 300, range = "melee" }, -- Vanish
    [2094] = { class = "ROGUE", type = "CC", cd = 180, range = "range" }, -- Blind
    [11305] = { class = "ROGUE", type = "Utility", cd = 300, range = "melee" }, -- Sprint
    [26669] = { class = "ROGUE", type = "Defensive", cd = 300, range = "melee" }, -- Evasion
    [14177] = { class = "ROGUE", type = "Burst", cd = 180, spec = "Assassination", range = "melee" }, -- Cold Blood
    [13750] = { class = "ROGUE", type = "Burst", cd = 300, spec = "Combat", range = "melee" }, -- Adrenaline Rush
    [13877] = { class = "ROGUE", type = "Burst", cd = 120, spec = "Combat", range = "melee" }, -- Blade Flurry
    [36554] = { class = "ROGUE", type = "GapCloser", cd = 30, spec = "Subtlety", range = "range" }, -- Shadowstep
    [14185] = { class = "ROGUE", type = "Utility", cd = 600, spec = "Subtlety", range = "melee" }, -- Preparation

    -- WARLOCK
    [17928] = { class = "WARLOCK", type = "CC", cd = 40, range = "melee" }, -- Howl of Terror
    [27223] = { class = "WARLOCK", type = "CC", cd = 120, range = "range" }, -- Death Coil
    [19647] = { class = "WARLOCK", type = "Interrupt", cd = 24, range = "range" }, -- Spell Lock
    [30414] = { class = "WARLOCK", type = "CC", cd = 20, spec = "Destruction", range = "range" }, -- Shadowfury
    [18708] = { class = "WARLOCK", type = "Utility", cd = 900, spec = "Demonology", range = "melee" }, -- Fel Domination

    -- WARRIOR
    [6552] = { class = "WARRIOR", type = "Interrupt", cd = 10, range = "melee" }, -- Pummel
    [72] = { class = "WARRIOR", type = "Interrupt", cd = 12, range = "melee" }, -- Shield Bash
    [23920] = { class = "WARRIOR", type = "Defensive", cd = 10, range = "melee" }, -- Spell Reflection
    [3411] = { class = "WARRIOR", type = "Utility", cd = 30, range = "range" }, -- Intervene
    [676] = { class = "WARRIOR", type = "CC", cd = 60, range = "melee" }, -- Disarm
    [5246] = { class = "WARRIOR", type = "CC", cd = 180, range = "melee" }, -- Intimidating Shout
    [18499] = { class = "WARRIOR", type = "Utility", cd = 30, range = "melee" }, -- Berserker Rage
    [2565] = { class = "WARRIOR", type = "Defensive", cd = 60, range = "melee" }, -- Shield Block
    [12292] = { class = "WARRIOR", type = "Burst", cd = 180, spec = "Arms", range = "melee" }, -- Death Wish
    [20252] = { class = "WARRIOR", type = "GapCloser", cd = 25, range = "range" }, -- Intercept

    -- PALADIN
    [10278] = { class = "PALADIN", type = "Defensive", cd = 180, range = "range" }, -- Blessing of Protection
    [1044] = { class = "PALADIN", type = "Utility", cd = 25, range = "range" }, -- Blessing of Freedom
    [10308] = { class = "PALADIN", type = "CC", cd = 60, range = "range" }, -- Hammer of Justice
    [642] = { class = "PALADIN", type = "Defensive", cd = 300, range = "melee" }, -- Divine Shield
    [31884] = { class = "PALADIN", type = "Burst", cd = 180, range = "melee" }, -- Avenging Wrath
    [20066] = { class = "PALADIN", type = "CC", cd = 60, spec = "Retribution", range = "range" }, -- Repentance
    [31842] = { class = "PALADIN", type = "Burst", cd = 180, spec = "Holy", range = "melee" }, -- Divine Illumination

    -- PRIEST
    [10890] = { class = "PRIEST", type = "CC", cd = 27, range = "melee" }, -- Psychic Scream
    [15487] = { class = "PRIEST", type = "Interrupt", cd = 45, spec = "Shadow", range = "range" }, -- Silence
    [10060] = { class = "PRIEST", type = "Burst", cd = 180, spec = "Discipline", range = "range" }, -- Power Infusion
    [33206] = { class = "PRIEST", type = "Defensive", cd = 120, spec = "Discipline", range = "range" }, -- Pain Suppression
    [34433] = { class = "PRIEST", type = "Burst", cd = 300, range = "range" }, -- Shadowfiend
    [6346] = { class = "PRIEST", type = "Utility", cd = 180, range = "range" }, -- Fear Ward

    -- DRUID
    [22812] = { class = "DRUID", type = "Defensive", cd = 60, range = "melee" }, -- Barkskin
    [29166] = { class = "DRUID", type = "Utility", cd = 360, range = "range" }, -- Innervate
    [8983] = { class = "DRUID", type = "CC", cd = 60, range = "melee" }, -- Bash
    [16689] = { class = "DRUID", type = "Defensive", cd = 60, range = "melee" }, -- Nature's Grasp
    [17116] = { class = "DRUID", type = "Utility", cd = 180, spec = "Restoration", range = "melee" }, -- Nature's Swiftness
    [16979] = { class = "DRUID", type = "Interrupt", cd = 15, spec = "Feral", range = "range" }, -- Feral Charge

    -- HUNTER
    [19503] = { class = "HUNTER", type = "CC", cd = 30, spec = "Survival", range = "range" }, -- Scatter Shot
    [19263] = { class = "HUNTER", type = "Defensive", cd = 300, range = "melee" }, -- Deterrence
    [14311] = { class = "HUNTER", type = "CC", cd = 30, range = "melee" }, -- Freezing Trap
    [34490] = { class = "HUNTER", type = "Interrupt", cd = 20, spec = "Marksmanship", range = "range" }, -- Silencing Shot
    [19386] = { class = "HUNTER", type = "CC", cd = 120, spec = "Survival", range = "range" }, -- Wyvern Sting
    [19577] = { class = "HUNTER", type = "CC", cd = 60, spec = "Beast Mastery", range = "melee" }, -- Intimidation
    [34471] = { class = "HUNTER", type = "Burst", cd = 120, spec = "Beast Mastery", range = "melee" }, -- The Beast Within

    -- SHAMAN
    [8042] = { class = "SHAMAN", type = "Interrupt", cd = 6, range = "range" }, -- Earth Shock
    [30823] = { class = "SHAMAN", type = "Defensive", cd = 120, spec = "Enhancement", range = "melee" }, -- Shamanistic Rage
    [16166] = { class = "SHAMAN", type = "Burst", cd = 180, spec = "Elemental", range = "melee" }, -- Elemental Mastery
    [16188] = { class = "SHAMAN", type = "Utility", cd = 180, spec = "Restoration", range = "melee" }, -- Nature's Swiftness
    [16190] = { class = "SHAMAN", type = "Utility", cd = 300, spec = "Restoration", range = "melee" }, -- Mana Tide Totem
    [8177] = { class = "SHAMAN", type = "Utility", cd = 15, range = "melee" }, -- Grounding Totem
}

-- Event Frame
local f = CreateFrame("Frame")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:RegisterEvent("START_TIMER")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        Arena:OnCombatLog(CombatLogGetCurrentEventInfo())
    elseif event == "START_TIMER" then
        local timerType, timeRemaining, totalTime = ...
        if timerType == 1 then -- PvP start timer
            Arena.prepExpiration = GetTime() + timeRemaining
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        Arena.prepExpiration = 0
    end
end)

function Arena:Initialize()
    self.timeToStart = 0
    self.matchStarted = false
    self.prepExpiration = 0
    self.enemies = {}
    self.cooldowns = {}
    self.targets = {}
    print("|cff00FF00[OliaEyes]|r Arena tracking initialized.")
end

function Arena:OnCombatLog(...)
    local _, instanceType = IsInInstance()
    if instanceType ~= "arena" then return end
    
    local timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName, spellSchool = ...

    -- Spell Cast Tracking
    if eventType == "SPELL_CAST_SUCCESS" then
        if pvpTrinkets[spellId] then
            self:RegisterCooldown(sourceName, "Trinket", spellName, 120)
        elseif majorCooldowns[spellId] then
            local cdInfo = majorCooldowns[spellId]
            self:RegisterCooldown(sourceName, cdInfo.type, spellName, cdInfo.cd)
        end
    end
end

function Arena:RegisterCooldown(unitName, cdType, spellName, duration)
    if not unitName then return end
    if not self.cooldowns[unitName] then self.cooldowns[unitName] = {} end
    self.cooldowns[unitName][spellName] = {
        type = cdType,
        expires = GetTime() + duration,
        duration = duration
    }
end

function Arena:UpdateTimer()
    -- Check Arena Preparation Aura
    local hasPrep = false
    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not aura then break end
        if aura.name == "Arena Preparation" then
            hasPrep = true
            break
        end
    end
    
    if hasPrep then
        if self.prepExpiration and self.prepExpiration > GetTime() then
            self.timeToStart = math.max(0, self.prepExpiration - GetTime())
        else
            -- If we missed START_TIMER (e.g. reload UI), we just keep timeToStart at 0 or guess
            self.timeToStart = 0
        end
    else
        self.timeToStart = 0
        self.prepExpiration = 0
    end
end

function Arena:UpdateRoster()
    self.enemies = {}
    for i = 1, 5 do
        local unit = "arena" .. i
        if UnitExists(unit) then
            local name = UnitName(unit)
            local _, class = UnitClass(unit)
            local isDead = UnitIsDeadOrGhost(unit)
            
            -- Spec inference via our new Combat Log SpecDetection
            local spec = "Unknown"
            if jungle.EnemyPlayerSpec then
                spec = jungle.EnemyPlayerSpec(unit) or "Unknown"
            end

            self.enemies[unit] = {
                name = name,
                class = class,
                spec = spec,
                isDead = isDead
            }
        end
    end
end

function Arena:UpdateTargets()
    self.targets = {}
    local unitsToCheck = { "player", "target", "focus" }
    
    for i = 1, 4 do table.insert(unitsToCheck, "party"..i) end
    for i = 1, 5 do table.insert(unitsToCheck, "arena"..i) end

    for _, unit in ipairs(unitsToCheck) do
        if UnitExists(unit) then
            local targetUnit = unit .. "target"
            if UnitExists(targetUnit) then
                self.targets[UnitName(unit)] = UnitName(targetUnit)
            end
        end
    end
end

function Arena:OnUpdate()
    local _, instanceType = IsInInstance()
    if instanceType ~= "arena" then
        if self.matchStarted then
            self.matchStarted = false
            self.enemies = {}
            self.cooldowns = {}
            self.targets = {}
        end
        return
    end

    if not self.matchStarted then
        self.matchStarted = true
        if jungle.ClearDetectedSpecs then
            jungle.ClearDetectedSpecs()
        end
    end

    self:UpdateTimer()
    self:UpdateRoster()
    self:UpdateTargets()
    
    -- Cleanup expired cooldowns
    local time = GetTime()
    for unitName, cds in pairs(self.cooldowns) do
        for spellName, cdData in pairs(cds) do
            if time > cdData.expires then
                cds[spellName] = nil
            end
        end
    end
end

function Arena:GetExpectedCooldowns(unitName)
    local expected = {}
    local rosterUnit = nil
    for unit, data in pairs(self.enemies) do
        if data.name == unitName then
            rosterUnit = data
            break
        end
    end
    
    if not rosterUnit then return expected end
    
    local class = rosterUnit.class
    local spec = rosterUnit.spec
    
    for spellId, cdInfo in pairs(majorCooldowns) do
        if cdInfo.class == class then
            if not cdInfo.spec or spec == "Unknown" or cdInfo.spec == spec then
                table.insert(expected, spellId)
            end
        end
    end
    
    return expected
end

function Arena:GetEnemyTrinketReady(unitName)
    if not self.cooldowns[unitName] then return true end
    for spellName, cdData in pairs(self.cooldowns[unitName]) do
        if cdData.type == "Trinket" and cdData.expires > GetTime() then
            return false
        end
    end
    return true
end

function Arena:GetDiminishingReturns(unitName)
    -- Interfaces with existing DRreturns.lua module logic
    -- DRreturns saves units as fullName "Name-Realm"
    return jungle.getDR(unitName, Controlled_Stun_table) -- example lookup
end

-- Opt-in event timing; original scripts remain installed while tracing is off.
jungle.RaidTrace:WatchEventFrame(f, "arena")
