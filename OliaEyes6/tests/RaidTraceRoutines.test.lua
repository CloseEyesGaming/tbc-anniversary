-- Lua 5.1. Optional argument: exact pre-edit directory for differential testing.
-- Uses the complete Druid module and compares every returned row for 25 units.
local baseline = ...
local checks = 0
local function Check(value, why) assert(value, why); checks = checks + 1 end
local function Setup(path, sampled, scenario)
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
        Engine = {activeThread = 2}, currentTick = 1, unitCache = {},
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
    setfenv(assert(loadfile(path)), env)("OliaEyes6", j)
    return j, queries
end

local scenarios = {
    {}, {boss=true}, {manyTanks=true, expiring=true}, {manyTanks=true, haste=true, gcd=true},
    {ooc=true}, {moving=true}, {cooldown=true}, {noBloom=true}, {dead=true, range=true}, {ns=true},
}
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
for _, scenario in ipairs(scenarios) do
    for _, sampled in ipairs({false, true}) do
        local current, currentQueries = Setup("Routines/Druid.lua", sampled, scenario)
        local control, controlQueries = Setup(baseline and (baseline .. "/Routines/Druid.lua") or "Routines/Druid.lua", false, scenario)
        for tick = 1, 2 do
            current.currentTick, control.currentTick = tick, tick
            Check(Snapshot(current) == Snapshot(control), "Druid rows/metadata changed")
        end
        local shared = {known=true, combat=true, speed=true, haste=true, spellInfo=true, buff=true}
        for name, count in pairs(controlQueries) do
            Check(shared[name] and (currentQueries[name] or 0) <= count or currentQueries[name] == count,
                "Druid API call count unexpectedly changed: " .. name)
        end
        for name, count in pairs(currentQueries) do Check(count <= (controlQueries[name] or 0), "Druid extra API calls: " .. name) end
    end
end
io.write("RaidTrace Druid: ", checks, " differential assertions passed\n")
