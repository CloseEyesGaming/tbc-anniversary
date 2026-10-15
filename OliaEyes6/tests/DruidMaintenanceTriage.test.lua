-- Lua 5.1. Optional argument: exact pre-edit Druid.lua for differential testing.
-- Exercises real Druid selection, shared cast bookkeeping, and HoT padding.
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
    env.frames = {}
    env.CreateFrame = function()
        local frame = {events={},scripts={}}
        frame.RegisterEvent=function(self,event) self.events[event]=true end
        frame.SetScript=function(self,event,callback) self.scripts[event]=callback end
        env.frames[#env.frames+1]=frame
        return frame
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
    return j, env, queries
end


local modulePath = "Routines/Druid.lua"
local unitSource = assert(io.open("UnitsData.lua")):read("*a")
local derived = assert(string.match(unitSource, "(local function ApplyAuraDerivedState.-)local function UpdateUnitAuras"))
local function Case(options)
    options = options or {}
    local j, env, queries = Setup(modulePath, false, options)
    local function Buff(count, remaining) return {isActive=true,count=count,expirationTime=100+remaining} end
    local function Unit(hp, tank, full)
        return {guid=tank and "tank" or "raid", currLife=hp, realHP=hp, maxHP=tank and 20000 or 10000,
            isInCombat=not options.ooc, isTank=tank, threatStatus=tank and (options.noThreat and 0 or 3) or 0,
            auras={buffs={player=full and {Lifebloom=Buff(3,options.expiry or 6), Regrowth=Buff(0,15), Rejuvenation=Buff(0,10)} or {},nonplayer={}}}}
    end
    j.unitCache={tank=Unit(options.tankHP or 0.40,true,true),raid=Unit(options.raidHP or 0.70,false,options.raidFull)}
    j.LifePercent=function(unit) return j.unitCache[unit].realHP end
    j.ReadyCastSpell=function(spell,unit)
        if unit == options.blocked then return false end
        if spell == "Swiftmend" then return options.swift or false end
        if spell == "Regrowth" and options.noRegrowth then return false end
        if spell == "Lifebloom" and options.noBloom then return false end
        return true
    end
    j.IsSpellReadyIgnoreGCD=function(spell)
        return (spell == "Swiftmend" and options.swift) or (spell == "Nature's Swiftness" and options.nsReady) or false
    end
    j.isUnitAvailable=function(unit) return unit ~= options.unavailable end
    env.UnitIsDeadOrGhost=function(unit) return unit == options.dead end
    j.Engine.activeThread=options.thread or 2
    j.Cast={CastSpell=function(_,spell,unit) j.selected={spell,unit}; return true end}
    setfenv(assert(loadfile("Rotation.lua")),env)("OliaEyes6",j)
    env.unitCache=j.unitCache
    local apply=setfenv(assert(loadstring(derived.." return ApplyAuraDerivedState")),env)()
    local function Select()
        for _, data in pairs(j.unitCache) do
            data.currLife=data.realHP
            data.missingHP=data.maxHP*(1-data.realHP)
        end
        for unit,data in pairs(j.unitCache) do apply(unit,data.maxHP) end
        j.currentTick=j.currentTick+1
        j.selected=nil
        j.Rotation:new():rotate({j.universalHealSetV6},1)
        return j.selected
    end
    return j,Select,queries,env
end
local function Expect(options,spell,unit,why)
    local j,select=Case(options)
    local result=select()
    Check(result and result[1]==spell and result[2]==unit,why..": "..(result and table.concat(result,"/") or "idle"))
    return j,select
end
Expect({},"Regrowth","tank","40% tank full HoTs beats 70% raid")
Expect({tankHP=0.75,raidHP=0.50},"Rejuvenation","raid","Stable tank allows lower raid")
Expect({tankHP=0.60,raidHP=0.58,raidFull=true},"Regrowth","tank","65% virtual tank beats 78% virtual raid")
Expect({tankHP=0.65,raidHP=0.40,raidFull=true},"Regrowth","raid","60% virtual raid with full HoTs remains eligible")
Expect({tankHP=0.60,raidHP=0.60},"Rejuvenation","raid","Equal real HP favors uncovered raid")
Expect({tankHP=0.85,raidHP=0.50,expiry=0.8},"Lifebloom","tank","Due tank bloom precedes lower raid")
Expect({tankHP=0.40,raidHP=0.70,expiry=0.8},"Lifebloom","tank","Low tank never bypasses bloom deadline")
Expect({tankHP=0.40,raidHP=0.70,expiry=1.8},"Rejuvenation","raid","Skip blocked tank cast; use available instant on next friend")
Expect({tankHP=0.40,raidHP=0.70,moving=true},"Rejuvenation","raid","Moving prevents direct heal; consider next candidate")
Expect({tankHP=0.40,raidHP=0.70,blocked="tank"},"Regrowth","raid","Unavailable spells do not block next friend")
Expect({unavailable="tank"},"Regrowth","raid","Unserviceable tank skipped")
Expect({dead="tank"},"Regrowth","raid","Dead tank skipped")
Expect({tankHP=0.40,raidHP=0.70,swift=true},"Swiftmend","tank","Existing emergency wins")
Expect({tankHP=0.40,raidHP=0.70,expiry=0.8,swift=true},"Lifebloom","tank","Existing bloom-before-Swiftmend retained")
Expect({tankHP=0.30,nsReady=true},"Nature's Swiftness","tank","Existing NS threshold retained")
Expect({tankHP=0.30,ns=true},"Healing Touch","tank","Existing NS touch retained")
Expect({tankHP=0.48,swift=true},"Regrowth","tank","HoT-adjusted threshold unchanged at 53%")
Expect({tankHP=0.40,raidHP=0.55,noThreat=true},"Rejuvenation","raid","Threat-lost tank keeps existing 20 point allowance")
-- Opening tank maintenance: Regrowth before bloom start/build, never refresh.
for _,options in ipairs({{tankHP=1,raidHP=0.10}, {tankHP=1,raidHP=0.10,raidFull=true},
    {tankHP=1,raidHP=0.10,moving=true}, {tankHP=1,raidHP=0.10,noRegrowth=true},
    {tankHP=1,raidHP=0.10,expiry=0.8}, {tankHP=1,raidHP=0.10,nsReady=true}}) do
    local urgent,choose=Case(options)
    urgent.unitCache.tank.auras.buffs.player.Regrowth=nil
    local result=choose()
    local spell,unit="Regrowth","raid"
    if options.moving or options.noRegrowth then spell="Rejuvenation" end
    if options.expiry then spell,unit="Lifebloom","tank" end
    if options.nsReady then spell="Nature's Swiftness" end
    Check(result and result[1]==spell and result[2]==unit,"10% friend must precede healthy tank maintenance, preserving emergency/deadline rules")
end
Expect({tankHP=0.95,raidHP=0.20},"Regrowth","raid","Urgent direct heal precedes HoT setup")
local urgent,choose=Case({tankHP=1,raidHP=0.35})
urgent.unitCache.tank.auras.buffs.player.Regrowth=nil
Check(choose()[2]=="raid","35% actual HP boundary gets urgent healing")
urgent,choose=Case({tankHP=1,raidHP=0.35,raidFull=true})
urgent.unitCache.tank.auras.buffs.player.Regrowth=nil
Check(choose()[1]=="Regrowth" and urgent.selected[2]=="raid","HoT padding cannot hide the 35% actual HP boundary")
urgent,choose=Case({tankHP=0.85,raidHP=0.30,raidFull=true})
urgent.unitCache.tank.auras.buffs.player.Regrowth=nil
Check(choose()[1]=="Regrowth" and urgent.selected[2]=="raid","Padded 30% friend precedes healthy tank Regrowth")
urgent,choose=Case({tankHP=1,raidHP=0.36})
urgent.unitCache.tank.auras.buffs.player.Regrowth=nil
Check(choose()[2]=="tank","Above urgent threshold retains maintenance policy")
urgent,choose=Case({tankHP=0.20,raidHP=0.10})
Check(choose()[2]=="raid","Lowest actual HP wins among urgent direct heals")
urgent,choose=Case({tankHP=0.30,raidHP=0.25,raidFull=true})
Check(choose()[1]=="Regrowth" and urgent.selected[2]=="raid","Actual HP outranks reversed virtual HP among urgent targets")
urgent,choose=Case({tankHP=0.25,raidHP=0.30,raidFull=true})
Check(choose()[1]=="Regrowth" and urgent.selected[2]=="tank","Lower actual HP tank wins urgent direct healing")
urgent,choose=Case({tankHP=1,raidHP=0.10,blocked="raid"})
urgent.unitCache.tank.auras.buffs.player.Regrowth=nil
Check(choose()[2]=="tank","Uncastable urgent target does not block available maintenance")
for _,options in ipairs({{}, {boss=true}, {moving=true}, {noRegrowth=true}, {thread=7}, {noThreat=true}}) do
    local opening,choose=Case(options)
    opening.unitCache.tank.auras.buffs.player={}
    local action=choose()
    local expected=(options.moving or options.noRegrowth or options.thread==7) and "Lifebloom" or "Regrowth"
    Check(action and action[1]==expected and action[2]=="tank","Bare tank opening honors active-tank and cast gates")
end
local opening,choose=Case({})
opening.unitCache.tank.auras.buffs.player.Regrowth=nil
opening.unitCache.tank.auras.buffs.player.Lifebloom.count=1
Check(choose()[1]=="Regrowth" and opening.selected[2]=="tank","Missing Regrowth before building bloom")
opening,choose=Case({expiry=0.8})
opening.unitCache.tank.auras.buffs.player.Regrowth=nil
Check(choose()[1]=="Lifebloom" and opening.selected[2]=="tank","Due bloom protected even without Regrowth")
opening,choose=Case({expiry=1.8})
opening.unitCache.tank.auras.buffs.player.Regrowth=nil
opening.unitCache.tank.auras.buffs.player.Lifebloom.count=1
Check(choose()[1]=="Lifebloom" and opening.selected[2]=="tank","Unsafe Regrowth window falls back to stacking bloom")
opening,choose=Case({tankHP=0.30,nsReady=true})
opening.unitCache.tank.auras.buffs.player={}
Check(choose()[1]=="Nature's Swiftness","NS still precedes opening maintenance")
-- The new rank must apply between tanks as well as within one tank's rows.
opening,choose=Case({tankHP=0.85,raidHP=0.70})
opening.unitCache.tank.auras.buffs.player.Lifebloom=nil
opening.unitCache.raid.isTank=true;opening.unitCache.raid.threatStatus=3
Check(choose()[1]=="Regrowth" and opening.selected[2]=="raid","Missing Regrowth outranks another tank's bloom start")
local j,select=Case({tankHP=0.70,raidHP=0.60})
j.unitCache.tank.auras.buffs.player.Regrowth=nil
Check(select()[1]=="Regrowth" and j.selected[2]=="tank","Missing tank Regrowth precedes raid healing")
j,select=Case({tankHP=0.70,raidHP=0.60})
j.unitCache.tank.auras.buffs.player.Rejuvenation=nil
Check(select()[1]=="Rejuvenation" and j.selected[2]=="tank","Missing tank Rejuvenation precedes raid")
j,select=Case({tankHP=0.70,raidHP=0.60})
j.unitCache.tank.auras.buffs.player.Lifebloom.count=2
Check(select()[1]=="Lifebloom" and j.selected[2]=="tank","Stack tank Lifebloom before additional healing")
j,select=Expect({},"Regrowth","tank","Initial choice")
Check(j.CurrentCast.stopcastFunc==nil,"Tank direct-heal metadata retained")
j.unitCache.tank.realHP=0.65
j.unitCache.raid.realHP=0.60
Check(select()[2]=="raid","Reconsider target next tick after tank recovery")
Check(j.CurrentCast.targetGUID=="raid" and j.CurrentCast.spellName==j.selected[1],"Shared cast bookkeeping preserved")
j,select=Expect({tankHP=0.65,raidHP=0.40,raidFull=true},"Regrowth","raid","Full HoT raid direct heal")
Check(type(j.CurrentCast.stopcastFunc)=="function","Raid direct heal retains overheal stop rule")
Check(not j.CurrentCast.stopcastFunc("raid"),"Raid heal continues while injured")
j.unitCache.raid.realHP=0.96
Check(j.CurrentCast.stopcastFunc("raid"),"Raid heal cancels at existing full-health threshold")
local q
j,select,q=Case({})
select()
local before=q.buff
j.universalHealSetV6("tank");j.universalHealSetV6("raid")
Check(q.buff==before,"Selection cached within one engine tick")
j.Engine.activeThread=7
Check(#j.universalHealSetV6("tank")==27,"Thread 7 returns original matrix")
-- Multiple tanks still share the earliest-deadline scheduler.
j,select=Case({tankHP=0.85,expiry=1.0})
j.unitCache.tank2={guid="tank2",realHP=0.90,maxHP=20000,isInCombat=true,isTank=true,threatStatus=3,
    auras={buffs={player={Lifebloom={isActive=true,count=3,expirationTime=100.6},
    Rejuvenation={isActive=true,count=0,expirationTime=110},Regrowth={isActive=true,count=0,expirationTime=115}},nonplayer={}}}}
Check(select()[1]=="Lifebloom" and j.selected[2]=="tank2","Earliest bloom wins across tanks")
-- No stale winner when a later frame has no healing candidates.
j,select=Case({})
select()
j.unitCache.tank.realHP=1;j.unitCache.raid.realHP=1
Check(select()==nil,"Recovered group clears previous selection")
-- Preserve the event-confirmed Regrowth -> Rejuvenation sequence.
local env
j,select,q,env=Case({tankHP=0.60,raidHP=0.70})
j.unitCache.tank.auras.buffs.player.Regrowth=nil
j.unitCache.tank.auras.buffs.player.Rejuvenation=nil
Check(select()[1]=="Regrowth" and j.selected[2]=="tank","Establish Regrowth first")
env.CombatLogGetCurrentEventInfo=function()
    return 100,"SPELL_CAST_SUCCESS",nil,"player",nil,nil,nil,"tank",nil,nil,nil,1,"Regrowth"
end
for _,frame in ipairs(env.frames) do
    if frame.events.COMBAT_LOG_EVENT_UNFILTERED then frame.scripts.OnEvent(frame,"COMBAT_LOG_EVENT_UNFILTERED") end
end
j.unitCache.tank.auras.buffs.player.Regrowth={isActive=true,count=0,expirationTime=115}
Check(select()[1]=="Rejuvenation" and j.selected[2]=="tank","Successful Regrowth still inserts Rejuvenation")

-- Compare unaffected contexts to the exact saved preimage, when supplied.
if baseline then
    for _, scenario in ipairs({{}, {boss=true}, {moving=true}, {ooc=true}, {noBloom=true}, {expiring=true}, {ns=true}}) do
        local current=Setup(modulePath,false,scenario)
        local old=Setup(baseline,false,scenario)
        current.Engine.activeThread,old.Engine.activeThread=7,7
        for i=1,25 do
            local a,b=current.universalHealSetV6("raid"..i),old.universalHealSetV6("raid"..i)
            Check(#a==#b,"Unchanged context row count")
            for n=1,#a do for c=1,4 do
                Check(type(a[n][c])=="function" and type(b[n][c])=="function" or a[n][c]==b[n][c],"Thread 7 differential")
            end end
        end
    end
    for _,scenario in ipairs({{ooc=true},{noBloom=true}}) do
        local a=Setup(modulePath,false,scenario)
        local b=Setup(baseline,false,scenario)
        for i=1,25 do
            local x,y=a.universalHealSetV6("raid"..i),b.universalHealSetV6("raid"..i)
            for n=1,#x do for c=1,4 do
                Check(type(x[n][c])=="function" and type(y[n][c])=="function" or x[n][c]==y[n][c],"OOC/pre-Lifebloom unchanged")
            end end
        end
    end
end
io.write("Druid maintenance triage: ",checks," assertions passed\n")
