-- Lua 5.1. Optional argument: exact pre-edit directory for differential testing.
-- Uses the complete Druid module and compares every returned row for 25 units.
local baseline, mode = ...
assert(baseline, "Pass the exact pre-edit checkpoint directory")
local checks = 0
local function Check(value, why) assert(value, why); checks = checks + 1 end
local function Setup(path, sampled, scenario, spellPath)
    local env = setmetatable({}, {__index = _G})
    env._G = env
    local time = 100
    local queries = {}
    local function API(name, result)
        return function(...) queries[name] = (queries[name] or 0) + 1; return result(...) end
    end
    env.GetTime = function() return time end
    env.debugprofilestop = function() return 1 end
    env.CreateFrame = function()
        return {RegisterEvent = function() end, SetScript = function() end}
    end
    env.GetSpellBookItemInfo = API("known", function(spell) return not (scenario.noBloom and spell == "Lifebloom") and 1 or nil end)
    env.UnitIsDeadOrGhost = API("dead", function(unit) return scenario.dead and unit == "raid25" or false end)
    env.UnitAffectingCombat = API("combat", function() return not scenario.ooc end)
    env.GetUnitSpeed = API("speed", function() return scenario.moving and 7 or 0 end)
    env.UnitIsUnit = API("sameUnit", function(a, b) return a == b end)
    env.UnitLevel = API("level", function() return scenario.boss and -1 or 70 end)
    env.UnitClassification = API("classification", function() return scenario.boss and "worldboss" or "normal" end)
    env.UnitExists = API("exists", function() return true end)
    env.UnitIsFriend = API("friend", function() return true end)
    env.IsSpellInRange = API("range", function(_, unit) return scenario.range and unit == "raid1" and 0 or 1 end)
    env.UnitGUID = API("guid", function(unit) return unit end)
    env.UnitSpellHaste = API("haste", function() return scenario.haste and 30 or 0 end)
    env.GetSpellInfo = API("spellInfo", function(spell) return spell, nil, nil, spell == "Regrowth" and 2000 or 0 end)
    env.GetNetStats = API("latency", function() return 0, 0, 40, 50 end)
    local j = {
        Engine = {activeThread = scenario.thread or 2}, offsets = {GCD_SPELL_ID = 61304}, currentTick = 1, unitCache = {},
        RaidTrace = {sample = sampled, Count = function() end, Detail = function() end, WatchEventFrame = function() end},
        GetGCDValues = API("gcd", function() return scenario.gcd and 99.6 or 0, scenario.gcd and 1.5 or 0 end),
        isUnitAvailable = function() return true end,
        isCasting = API("casting", function() return false end),
        ReadyCastSpell = API("ready", function(spell) return not (scenario.cooldown and spell == "Regrowth") end),
        IsSpellReadyIgnoreGCD = API("readyIgnore", function(spell) return not (scenario.cooldown and spell == "Swiftmend") end),
        LifePercent = function() return 0.6 end,
    }
    for i = 1, 25 do
        local buffs = {}
        if i % 2 == 0 or i <= 3 then
            buffs.Lifebloom = {isActive = true, count = i % 3 + 1, expirationTime = time + (scenario.expiring and 0.6 or 4) + i * 0.1}
        end
        if i % 3 == 0 then buffs.Regrowth = {isActive = true, count = 0, expirationTime = time + 10} end
        if i % 4 == 0 then buffs.Rejuvenation = {isActive = true, count = 0, expirationTime = time + 10} end
        j.unitCache["raid" .. i] = {
            guid = "raid" .. i, currLife = (i % 8 + 1) / 10, isInCombat = not scenario.ooc,
            isTank = i <= (scenario.manyTanks and 6 or 2), threatStatus = i <= (scenario.manyTanks and 6 or 2) and 3 or 0,
            auras = {buffs = {player = buffs, nonplayer = {}}},
        }
    end
    j.unitCacheBuff = API("buff", function(unit, aura, source, remaining, count)
        if unit == "player" then return scenario.ns and aura == "Nature's Swiftness" or false end
        local data = j.unitCache[unit].auras.buffs.player[aura]
        return data and data.isActive and data.expirationTime - time >= (remaining or 0) and data.count >= (count or 0) or false
    end)
    env.GetSpellCooldown = API("cooldownAPI", function(spell)
        if spell == 61304 then
            if scenario.gcd then return 99.2, 1.5 end
            return 98.8, 1.5
        end
        if scenario.cooldown and spell == "Swiftmend" then return 90, 15 end
        return scenario.gcd and 99.2 or 98.8, 1.5
    end)
    env.IsUsableSpell = API("usableAPI", function(spell) return not scenario.noMana, scenario.noMana or false end)
    j.IsTargetImmuneToDruidDamageSpell = function(_, unit) return scenario.immune and unit == "raid2" or false end
    setfenv(assert(loadfile(spellPath)), env)("OliaEyes6", j)
    -- Supply initialization metadata for the unit-targeted healing fixture.
    j.actionHasRange = { Lifebloom = true, Rejuvenation = true, Regrowth = true,
        Swiftmend = true, ["Healing Touch"] = true }
    setfenv(assert(loadfile(path)), env)("OliaEyes6", j)
    return j, queries, env
end


local function Snapshot(j)
    local result = {}
    for i = 1, 25 do
        local rows = j.universalHealSetV6("raid" .. i)
        for index, row in ipairs(rows) do
            result[#result + 1] = table.concat({i, index, tostring(row[1]), tostring(row[2]), tostring(row[3]), type(row[4]) == "function" and "function" or tostring(row[4])}, ":")
        end
    end
    return table.concat(result, "\n")
end
local firstBefore, firstAfter
for index = 0, 127 do
    local scenario = {
        boss = index % 2 == 1, moving = math.floor(index / 2) % 2 == 1,
        gcd = math.floor(index / 4) % 2 == 1, noMana = math.floor(index / 8) % 2 == 1,
        manyTanks = math.floor(index / 16) % 2 == 1, expiring = math.floor(index / 32) % 2 == 1,
        haste = math.floor(index / 64) % 2 == 1, range = true, immune = true,
    }
    for _, thread in ipairs({2, 7}) do
        scenario.thread = thread
        local current, cq = Setup("Routines/Druid.lua", true, scenario, "Core/Spell.lua")
        local control, bq = Setup(baseline .. "/Routines/Druid.lua", false, scenario, baseline .. "/Core/Spell.lua")
        for tick = 1, 3 do
            current.currentTick, control.currentTick = tick, tick
            -- Change the same live facts between ticks to catch stale caches.
            if tick == 2 then scenario.gcd = not scenario.gcd; scenario.noMana = not scenario.noMana end
            if tick == 3 then scenario.haste = not scenario.haste; scenario.moving = not scenario.moving; scenario.ns = true end
            Check(Snapshot(current) == Snapshot(control), "selection mismatch case " .. index .. " thread " .. thread .. " tick " .. tick)
        end
        if thread == 7 then
            for name, n in pairs(bq) do Check(cq[name] == n, "thread 7 API calls changed: " .. name) end
        elseif index == 0 then firstBefore, firstAfter = bq, cq end
    end
end
for _, scenario in ipairs({{ooc=true},{noBloom=true},{dead=true},{ns=true},{cooldown=true}}) do
    local current = Setup("Routines/Druid.lua", false, scenario, "Core/Spell.lua")
    local control = Setup(baseline .. "/Routines/Druid.lua", false, scenario, baseline .. "/Core/Spell.lua")
    Check(Snapshot(current) == Snapshot(control), "fallback scenario mismatch")
end
if mode == "preserve" then
    -- A later refactor compares against the already-optimized exact checkpoint.
    Check(firstAfter.cooldownAPI <= firstBefore.cooldownAPI, "cooldown API work increased")
    Check(firstAfter.usableAPI <= firstBefore.usableAPI, "usability API work increased")
else
    Check(firstAfter.cooldownAPI < firstBefore.cooldownAPI / 5, "cooldown API work did not drop")
    Check(firstAfter.usableAPI < firstBefore.usableAPI / 5, "usability API work did not drop")
end
io.write("Full Druid + spell helpers: ", checks, " differential checks passed\n")
io.write("Example 3-tick fixture cooldown API calls: ", firstBefore.cooldownAPI, " -> ", firstAfter.cooldownAPI,
    "; usability: ", firstBefore.usableAPI, " -> ", firstAfter.usableAPI, "\n")

-- Exercise the actual readiness policy at GCD boundaries and target failures.
local after, _, ae = Setup("Routines/Druid.lua", false, {}, "Core/Spell.lua")
local before, _, be = Setup(baseline .. "/Routines/Druid.lua", false, {}, baseline .. "/Core/Spell.lua")
local state = {}
for _, env in ipairs({ae, be}) do
    env.GetSpellInfo = function(spell) if state.info then return spell end end
    env.GetSpellBookItemInfo = function() if state.known then return 1 end end
    env.IsUsableSpell = function() return state.usable, state.noMana end
    env.IsSpellInRange = function(_, unit) if unit == "raid1" then return state.range else return 1 end end
    env.UnitIsDeadOrGhost = function() return state.dead end
    env.GetSpellCooldown = function(spell)
        if spell == 61304 then return 98.5 + state.remaining, 1.5 end
        if state.realCD then return 90, 15 end
        if state.offGCD then return 0, 0 end
        return 98.5 + state.remaining, 1.5
    end
end
local cases = 0
for _, remaining in ipairs({0, 0.49, 0.5, 0.5001, 1.5}) do
    for mask = 0, 127 do
        state.remaining = remaining
        state.info = mask % 2 == 0
        state.known = math.floor(mask / 2) % 2 == 0
        state.usable = math.floor(mask / 4) % 2 == 0
        state.noMana = math.floor(mask / 8) % 2 == 1
        state.dead = math.floor(mask / 16) % 2 == 1
        state.realCD = math.floor(mask / 32) % 2 == 1
        state.offGCD = math.floor(mask / 64) % 2 == 1
        for rangeCase = 1, 3 do
            state.range = rangeCase == 1 and 1 or rangeCase == 2 and 0 or nil
            local snapshot = {ready = {}}
            for _, unit in ipairs({"raid1", "raid2", "player"}) do
                Check(after.ReadyCastSpell("Regrowth", unit, snapshot) == before.ReadyCastSpell("Regrowth", unit), "readiness/target mismatch")
            end
            Check(after.IsSpellReadyIgnoreGCD("Regrowth", snapshot) == before.IsSpellReadyIgnoreGCD("Regrowth"), "shared readiness mismatch")
            cases = cases + 1
        end
    end
end
state.info, state.known, state.usable, state.noMana, state.dead = true, true, nil, false, false
Check(not after.IsSpellReadyIgnoreGCD("Regrowth", {ready={}}), "nil usability is not ready")
io.write("Readiness edge cases: ", cases, "; cumulative checks: ", checks, " passed\n")
