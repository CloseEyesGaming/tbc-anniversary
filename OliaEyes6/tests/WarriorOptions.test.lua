-- Standalone Lua 5.1 tests of the actual Warrior routines with mocked game APIs.
-- Optional first argument: exact pre-change Warrior.lua for all-enabled comparison.
-- Not loaded by the addon TOC. Does not validate real spell mechanics/rendering.
local baselinePath = ...
local checks, comparisons = 0, 0
local function Check(value, message)
    assert(value, message)
    checks = checks + 1
end
local function Context(s, path, disabled)
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.SlashCmdList = {}
    env.OliaEyes6_Settings = { schemaVersion = 1, classes = { WARRIOR = disabled or {} } }
    env.OliaArmsLog = { enabled = false }
    local frames = {}
    env.CreateFrame = function()
        local f = { scripts = {} }
        function f:RegisterEvent() end
        function f:UnregisterEvent() end
        function f:SetScript(name, callback) self.scripts[name] = callback end
        frames[#frames + 1] = f
        return f
    end
    env.GetTime = function() return 100 end
    env.debugprofilestop = function() return 100 end
    env.UnitExists = function(unit) return unit ~= nil and unit ~= "missing" end
    env.UnitCanAttack = function() return true end
    env.UnitIsDeadOrGhost = function() return s.dead or false end
    env.UnitIsPlayer = function(unit) return unit == "player" or s.pvp or false end
    env.UnitPlayerControlled = function(unit) return unit == "player" or s.pvp or false end
    env.UnitAffectingCombat = function() return true end
    env.UnitPower = function() return s.rage or 80 end
    env.UnitHealthMax = function() return 100000 end
    env.UnitHealth = function() return s.execute and 10000 or 90000 end
    env.UnitGUID = function(unit) return (unit == "target" or unit == "nameplate1") and "enemy1" or unit end
    env.UnitIsUnit = function(a, b) return a == b end
    env.UnitGroupRolesAssigned = function() return "DAMAGER" end
    env.GetPartyAssignment = function() return false end
    env.UnitClass = function() return "Warrior", "WARRIOR" end
    env.GetUnitSpeed = function() return s.moving and 7 or 0 end
    env.UnitSpellHaste = function() return 0 end
    env.GetShapeshiftForm = function() return s.stance or 3 end
    env.CheckInteractDistance = function() return not s.outOfRange end
    env.GetNetStats = function() return 0, 0, 50, 50 end
    env.UnitCastingInfo = function(unit) if unit == "player" and s.casting then return "Slam" end end
    env.UnitChannelInfo = function() end
    env.UnitAttackSpeed = function() return 3.5, s.fury and 2.5 or nil end
    env.GetInventoryItemLink = function(_, slot) if slot == 16 or s.fury then return "weapon" end end
    env.GetItemInfo = function() return "weapon", nil, nil, nil, nil, nil, nil, nil, s.fury and "INVTYPE_WEAPON" or "INVTYPE_2HWEAPON" end
    env.IsEquippedItemType = function(kind) return s.thread == 5 and kind == "Shields" end
    env.IsPlayerSpell = function(id) return id == 12294 or id == 12328 or (s.fury and id == 23881) or id == 1464 end
    env.IsSpellKnown = env.IsPlayerSpell
    env.GetSpellBookItemInfo = function(spell) if spell ~= "Devastate" then return 1 end end
    env.GetSpellInfo = function(spell) return spell, nil, nil, 500 end
    env.GetSpellCooldown = function(spell)
        if s.cooldowns and s.cooldowns[spell] then return 99, 10 end
        return 0, 0
    end
    env.IsUsableSpell = function(spell) return not (s.blocked and s.blocked[spell]), false end
    env.IsCurrentSpell = function(spell) return spell == 6603 or (s.queued and spell == "Cleave") or false end
    env.IsSpellInRange = function() return s.outOfRange and 0 or 1 end
    env.C_Spell = {
        IsCurrentSpell = env.IsCurrentSpell,
        IsSpellInRange = function() return not s.outOfRange end,
    }
    env.C_SpecializationInfo = { GetTalentInfo = function(info)
        if info.specializationIndex == 1 and info.talentIndex == 1 then
            return { name = "Improved Slam", rank = 2 }
        end
    end }
    local plates = {}
    for i = 1, (s.enemies or 1) do plates[i] = { unit = "nameplate" .. i } end
    env.C_NamePlate = { GetNamePlates = function() return plates end }
    local function FindAura(name)
        for _, aura in ipairs(s.auras or {}) do
            if aura[1] == name then return aura end
        end
    end
    env.UnitAura = function(_, index)
        local a = (s.auras or {})[index]
        if a then return a[1], nil, a[2] or 0, nil, 30, a[3] and (100 + a[3]) or 0 end
    end
    local jungle = {
        -- This options fixture treats spells as ranged; ActionRange covers classification.
        actionHasRange = setmetatable({}, { __index = function() return true end }),
        RaidTrace = {
            sample = OLIA_TEST_TRACE_SAMPLE or false,
            Count = function() end, Detail = function() end,
            Finish = function(_, _, _, a, b, c) return a, b, c end,
            WatchEventFrame = function() end,
        },
        Engine = { activeThread = s.thread or 1 },
        unitCache = {},
        IsTotemUnit = function() return s.totem or false end,
        IsEnemyNameplateEligibleForAoE = function() return not s.totem and not s.dead end,
        GetNameplateUnitToken = function(p) return p.unit end,
        inMeleeRange = function() return not s.outOfRange end,
        GetGCDValues = function() return 0, 1.5 end,
        SpellOnCD = function(spell) return s.cooldowns and s.cooldowns[spell] or false end,
        ReadyCastSpell = function(spell) return not (s.blocked and s.blocked[spell]) and not (s.cooldowns and s.cooldowns[spell]) end,
        IsSpellReadyIgnoreGCD = function(spell) return not (s.blocked and s.blocked[spell]) and not (s.cooldowns and s.cooldowns[spell]) end,
        Debuff = function(name) return FindAura(name) ~= nil end,
        unitCacheBuff = function(_, name) return (name == "Sweeping Strikes" and s.sweepingActive) or false end,
        checkPveInterrupt = function() return false end,
        AreTrinketsReady = function() return false end,
        isCasting = function() return false end,
        isSlowed = function() return false end,
        isSlowProtected = function() return false end,
        IsWeaponAvailable = function() return false end,
    }
    setfenv(assert(loadfile("Core/SwingTimer.lua")), env)("OliaEyes6", jungle)
    -- Timing scenarios have their own tests; preserve this options fixture's
    -- fixed prediction while delivering real swing callbacks to the routine.
    if not s.realSwingTimer then
        jungle.SwingTimer.GetTimeRemaining = function() return 2 end
        jungle.SwingTimer.GetOffhandTimeRemaining = function() return 1 end
        jungle.SwingTimer.GetSlamTimeRemaining = function() return 2 end
        jungle.SwingTimer.IsMainhandTimingReliable = function() return true end
    end
    local swapHelpers = { offsets = { GCD_SPELL_ID = 61304 }, RaidTrace = jungle.RaidTrace }
    setfenv(assert(loadfile("Core/Spell.lua")), env)("OliaEyes6", swapHelpers)
    jungle.CanSwapWeapons = swapHelpers.CanSwapWeapons
    setfenv(assert(loadfile("Core/Options.lua")), env)("OliaEyes6", jungle)
    setfenv(assert(loadfile("Core/RoutineBehavior.lua")), env)("OliaEyes6", jungle)
    setfenv(assert(loadfile(path or "Routines/Warrior.lua")), env)("OliaEyes6", jungle)
    -- Equipment scanning is unrelated to these switches; isolate it identically
    -- in the checkpoint and current routine without constructing game tooltips.
    jungle.GetBestDWWeapons = function() end
    jungle.GetItemSpeed = function() return 2.5 end
    return jungle, env, frames
end

local function Snapshot(rows)
    local result = {}
    for i, row in ipairs(rows) do
        result[#result + 1] = tostring(i) .. ":" .. tostring(row[1]) .. ":" .. tostring(row[2]) .. ":" .. tostring(row[3])
    end
    return table.concat(result, "\n")
end
local function HasAction(rows, action)
    for _, row in ipairs(rows) do if row[2] == action and row[3] then return true end end
    return false
end
local optionCases = {
    { "thread1_demoralizing_shout", 1, "Demoralizing Shout" },
    { "thread1_thunder_clap", 1, "Thunder Clap" },
    { "thread1_sunder_initial", 1, "Sunder Armor", 0 },
    { "thread1_sunder_stack", 1, "Sunder Armor", 2 },
    { "thread2_demoralizing_shout", 2, "Demoralizing Shout" },
    { "thread2_sunder_routine", 2, "Sunder Armor" },
    { "thread2_sweeping_strikes", 2, "Sweeping Strikes" },
    { "thread3_demoralizing_shout", 3, "Demoralizing Shout" },
    { "thread3_sunder_fallback", 3, "Sunder Armor" },
}

-- Compare real returned rows against an exact checkpoint across the live routes.
if baselinePath then
    for _, thread in ipairs({ 1, 2, 3, 5, 7 }) do
        for _, fury in ipairs({ false, true }) do
            for _, pvp in ipairs({ false, true }) do
                for _, stance in ipairs({ 1, 3 }) do
                    for _, enemies in ipairs({ 1, 3 }) do
                        for _, auraCase in ipairs({ {}, { { "Sunder Armor", 2, 3 } }, { { "Expose Armor", 0, 20 }, { "Demoralizing Roar", 0, 20 } } }) do
                            local s = { thread = thread, fury = fury, pvp = pvp, stance = stance, enemies = enemies, auras = auraCase }
                            local old, new = Context(s, baselinePath), Context(s)
                            local routines = { "warriorArmsPveMaintenance", fury and "warriorFury" or "warriorArms", "warriorThread3AoE" }
                            if thread == 5 then routines = { "warriorTank" } end
                            for _, routine in ipairs(routines) do
                                Check(Snapshot(old[routine]("target")) == Snapshot(new[routine]("target")), "all-on regression: " .. routine .. " thread " .. thread)
                                comparisons = comparisons + 1
                            end
                            Check(old.WarriorThread3OwnsTarget("target") == new.WarriorThread3OwnsTarget("target"), "ownership unchanged")
                        end
                    end
                end
            end
        end
    end
end

-- Every requested switch suppresses existing matching actions in both specs
-- and PvE/PvP. This does not assert that every fixture makes that action ready.
for _, option in ipairs(optionCases) do
    for _, fury in ipairs({ false, true }) do
        for _, pvp in ipairs({ false, true }) do
            for _, stance in ipairs({ 1, 3 }) do
                local auras = option[4] == 0 and {} or { { "Sunder Armor", 2, 3 } }
                local s = { thread = option[2], fury = fury, pvp = pvp, stance = stance, enemies = 3, auras = auras }
                local jungle = Context(s, nil, { [option[1]] = false })
                for _, name in ipairs({ "warriorArmsPveMaintenance", fury and "warriorFury" or "warriorArms", "warriorThread3AoE" }) do
                    if name ~= "warriorThread3AoE" or s.thread == 3 then
                        Check(not HasAction(jungle[name]("target"), option[3]), option[1] .. " leaked through " .. name)
                    end
                end
            end
        end
    end
end

-- Narrow tests for independent initial/stack preferences and preserved aura rules.
local s = { thread = 1, stance = 1, auras = {} }
local j = Context(s, nil, { thread1_sunder_initial = false })
Check(not HasAction(j.warriorArmsPveMaintenance("target"), "Sunder Armor"), "stack does not invent first application")
s.auras = { { "Sunder Armor", 2, 20 } }
Check(HasAction(j.warriorArmsPveMaintenance("target"), "Sunder Armor"), "stack independent of initial")
s.auras = { { "Expose Armor", 0, 20 } }
Check(not HasAction(j.warriorArmsPveMaintenance("target"), "Sunder Armor"), "original Expose guard preserved")
s.auras = { { "Demoralizing Roar", 0, 20 } }
s.blocked = { ["Mortal Strike"] = true, Whirlwind = true, Slam = true }
Check(HasAction(j.warriorArmsPveMaintenance("target"), "Demoralizing Shout"), "original refresh rule not silently redesigned")

-- Flip a checkbox on the same loaded routine to catch stale rows/stance holds.
s = { thread = 1, stance = 3, auras = {}, blocked = { ["Mortal Strike"] = true, Whirlwind = true, Slam = true } }
local env
j, env = Context(s)
Check(HasAction(j.warriorArmsPveMaintenance("target"), "Battle Stance"), "TC stance preparation present")
env.OliaEyes6_Settings.classes.WARRIOR.thread1_thunder_clap = false
Check(not HasAction(j.warriorArmsPveMaintenance("target"), "Battle Stance"), "TC OFF clears stance preparation")
env.OliaEyes6_Settings.classes.WARRIOR.thread1_demoralizing_shout = false
Check(not HasAction(j.warriorArmsPveMaintenance("target"), "Demoralizing Shout"), "Demo OFF clears cached row")
env.OliaEyes6_Settings.classes.WARRIOR.thread1_demoralizing_shout = true
Check(HasAction(j.warriorArmsPveMaintenance("target"), "Demoralizing Shout"), "Demo ON restores original row")

-- Existing buff consumption and thread-3 ownership must not depend on T2's flag.
s = { thread = 3, enemies = 3, sweepingActive = true }
local on, off = Context(s), Context(s, nil, { thread2_sweeping_strikes = false, thread3_sunder_fallback = false })
Check(Snapshot(on.warriorThread3AoE("target")) == Snapshot(off.warriorThread3AoE("target")), "T3 owned routine unchanged by T2 SS/T3 fallback Sunder")
Check(off.WarriorThread3OwnsTarget("target"), "T3 ownership retained")

-- Disabled preparation must not keep waiting for a spell that cannot be chosen.
s = { thread = 2, fury = true, enemies = 3, stance = 3, queued = true }
on, off = Context(s), Context(s, nil, { thread2_sweeping_strikes = false })
Check(HasAction(on.warriorFury("target"), "Sweeping Strikes"), "Fury fixture has original SS")
Check(not HasAction(on.warriorFury("target"), "Whirlwind"), "Fury originally waits for SS")
Check(HasAction(off.warriorFury("target"), "Whirlwind"), "SS OFF releases Fury WW")
s = { thread = 2, enemies = 3, stance = 1, rage = 80 }
on, off = Context(s), Context(s, nil, { thread2_sweeping_strikes = false })
Check(not HasAction(on.warriorArms("target"), "Berserker Stance"), "Arms originally holds stance for SS")
Check(HasAction(off.warriorArms("target"), "Berserker Stance"), "SS OFF releases Arms stance hold")

local allDisabled = {}
for _, option in ipairs(optionCases) do allDisabled[option[1]] = false end
for _, thread in ipairs({ 5, 7 }) do
    for _, fury in ipairs({ false, true }) do
        s = { thread = thread, fury = fury, enemies = 3, stance = 1, auras = { { "Sunder Armor", 2, 3 } } }
        on, off = Context(s), Context(s, nil, allDisabled)
        local routines = thread == 5 and { "warriorTank" } or { "warriorArmsPveMaintenance", "warriorArms", "warriorFury" }
        for _, name in ipairs(routines) do
            Check(Snapshot(on[name]("target")) == Snapshot(off[name]("target")), "all switches OFF leaves thread " .. thread .. " unchanged: " .. name)
        end
    end
end
print("Warrior options: " .. checks .. " checks passed; " .. comparisons .. " all-enabled baseline row comparisons (mocked APIs).")
