-- Test-only registry bootstrap. Never listed in the production TOC.
local function Attach(j, env, class)
    env.UnitClass=function() return class or "WARRIOR", class or "WARRIOR" end
    env.UnitFullName=function() return "Fixture", "Realm" end
    env.GetRealmName=function() return "Realm" end
    env.InCombatLockdown=function() return false end
    env.IsEquippedItemType=env.IsEquippedItemType or function() return false end
    if not j.Options then j.Options={definitions={WARRIOR={}}} end
    local names={"universalPvPMatrix","universalHealSetV6","universalHealSetV5","universalHealSet","pveHealSet","pvpHealSet",
        "tankRollSet2","raidHealSet2","tankRollSet","raidHealSet","dispellSet","buffSet","druidHealingWeaponSet","druidDpsIdleSet","dpsSet",
        "warriorUniversal","warriorWowsims","warriorAdaptive","warriorKebab","warriorArms","warriorFury","warriorTank","warriorArmsPveMaintenance","warriorThread3AoE","rogueDpsSet","Fishing","followerSet"}
    local empty={}
    for _,name in ipairs(names) do j[name]=j[name] or function() return empty end end
    setfenv(assert(loadfile("Core/RoutineBehavior.lua")),env)("OliaEyes6",j)
    setfenv(assert(loadfile("Core/RoutineConfig.lua")),env)("OliaEyes6",j)
    setfenv(assert(loadfile("Core/RoutineSchemas.lua")),env)("OliaEyes6",j)
    setfenv(assert(loadfile("Core/RoutineDispatchViews.lua")),env)("OliaEyes6",j)
    setfenv(assert(loadfile("Core/RoutineCatalog.lua")),env)("OliaEyes6",j)
    local refresh=j.Options.Refresh
    j.Options.Refresh=function() end
    j.RoutineConfig:Initialize()
    j.Options.Refresh=refresh
    return j.RoutineConfig
end
return Attach
