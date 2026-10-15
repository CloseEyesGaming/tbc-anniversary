local AddonName, jungle = ...
local Config = jungle.RoutineConfig
local function ResetWarrior()
    if jungle.ResetWarriorRoutineState then jungle.ResetWarriorRoutineState() end
    if jungle.WarriorAdaptive then jungle.WarriorAdaptive:ResetConfiguration() end
end
-- Every authored dispatcher has its own branch projection; shared evaluators
-- without dispatch modes retain a single static action list.
local function DisplayViews(def)
    local views=jungle.RoutineDispatchViews(def)
    if views then return views end
    local id=def.legacyBase or def.id
    local label="Steps"
    if id=="warrior.maintenance" or id=="druid.legacyPve" then label="PvE" end
    if id=="druid.pvp" or id=="druid.legacyPvp" then label="PvP" end
    return {{id="shared",label=label,sections={{label="Actions",rowSets=def.rowSets,steps=def.extraSteps}},
        description="Shared action table; conditions are explained per step. This routine has no separate PvE/PvP or single-target/AoE dispatcher."}}
end
local function Register(id, label, class, selector, functions, rowSets, policy, mode, extras)
    local def = {id=id, label=label, class=class, kind=class and "class" or "support", selector=selector,
        functions=functions, rowSets=rowSets, policy=policy, mode=mode,
        source=class and ("Routines/" .. class:sub(1,1) .. class:sub(2):lower() .. ".lua") or "Routines/Follower.lua"}
    for key, value in pairs(extras or {}) do def[key] = value end
    if class=="WARRIOR" then
        def.algorithm=def.algorithm or id:match("^warrior%.(.+)$")
        def.behavior=jungle.RoutineBehaviors.warrior[policy or 2]
        def.policy=nil;def.mode=mode or "original";def.legacyBase=id;def.reset=ResetWarrior
    end
    def.displayViews=def.displayViews or DisplayViews(def)
    local ok, reason = Config:Register(def)
    if not ok then print("|cffff5555[OliaEyes]|r " .. reason) end
end
local function DruidRows(...)
    local list = {...}; for i, name in ipairs(list) do list[i] = "Druid." .. name end; return list
end
local function WarriorRows(...)
    local list = {...}; for i, name in ipairs(list) do list[i] = "Warrior." .. name end; return list
end
local healingExtras = {
    {id="Healing Touch",description="Nature's Swiftness preparation is disabled together with Healing Touch."},
    {id="Regrowth",description="Direct healing, including V6 urgent/additional selection and its scheduler admission."},
}
local healingLinks = {["Nature's Swiftness"]="Healing Touch"}
local function Heal(id, label, fn, rows, policy)
    Register(id,label,"DRUID","rotate",{fn},rows,policy,nil,{extraSteps=healingExtras,links=healingLinks,reset=jungle.ResetDruidRoutineState})
end
Heal("druid.pvp","PvP healing matrix",jungle.universalPvPMatrix,DruidRows("univPvPCache"),1)
Heal("druid.v6","V6 healing",jungle.universalHealSetV6,DruidRows("univHealCacheV6"),2)
Heal("druid.v5","V5 healing",jungle.universalHealSetV5,DruidRows("univHealCacheV5"),7)
Heal("druid.legacyHeal","Legacy universal healing",jungle.universalHealSet,DruidRows("pveHealCache","pvpHealCache"),7)
Heal("druid.legacyPve","Legacy PvE healing",jungle.pveHealSet,DruidRows("pveHealCache"),7)
Heal("druid.v6Legacy","V6 healing (legacy unit selection)",jungle.universalHealSetV6,DruidRows("univHealCacheV6"),7)
Heal("druid.legacyPvp","Legacy PvP healing",jungle.pvpHealSet,DruidRows("pvpHealCache"),7)
Heal("druid.tank","Tank healing",jungle.tankRollSet2,DruidRows("tankRollCache2"),4)
Heal("druid.raid","Raid healing",jungle.raidHealSet2,DruidRows("raidHealCache2"),4)
Heal("druid.legacyTank","Legacy tank healing",jungle.tankRollSet,DruidRows("tankRollSet"),4)
Heal("druid.legacyRaid","Legacy raid healing",jungle.raidHealSet,DruidRows("raidHealSet"),4)
Register("druid.raidCombined","Tank + raid (joint priority)","DRUID","rotate",{jungle.tankRollSet2,jungle.raidHealSet2},DruidRows("tankRollCache2","raidHealCache2"),4,nil,{extraSteps=healingExtras,links=healingLinks,reset=jungle.ResetDruidRoutineState})
Register("druid.dispelHeal","Dispel + V6 (joint priority)","DRUID","rotate",{jungle.dispellSet,jungle.universalHealSetV6},DruidRows("dispellCache","univHealCacheV6"),7,nil,{extraSteps=healingExtras,links=healingLinks,reset=jungle.ResetDruidRoutineState})
Register("druid.dispel","Dispel","DRUID","rotate",{jungle.dispellSet},DruidRows("dispellCache"),3)
Register("druid.buffs","Buffs","DRUID","rotate",{jungle.buffSet},DruidRows("buffCache"),6)
Register("druid.healingWeapon","Healing equipment","DRUID","rotate",{jungle.druidHealingWeaponSet},DruidRows("healingWeaponCache"),2)
Register("druid.idle","DPS idle / equipment","DRUID","rotate",{jungle.druidDpsIdleSet},DruidRows("dpsIdleWeaponCache"),5)
Register("druid.dps","DPS (form-aware)","DRUID","dpsRotate",{jungle.dpsSet},DruidRows("dpsCatStealthCache","dpsCatCache","dpsBearCache","dpsWeaponSwapCache","dpsCasterCache","dpsPvPCasterCache","dpsPowershiftCache"),5,nil,{reset=jungle.ResetDruidRoutineState,extraSteps={{id="Claw",description="Cat builder fallback when Mangle is unavailable."}}})

local optionDefinitions = jungle.Options.definitions.WARRIOR
local function Options(prefix)
    local result = {}
    for _, option in ipairs(optionDefinitions) do if option.key:sub(1,#prefix) == prefix then result[#result + 1] = option end end
    return result
end
local originalOptions = {
    {key="sunderInitial",label="Sunder: initial application",default=true,description="Original initial Sunder branches; Expose Armor and target conditions remain."},
    {key="sunderStack",label="Sunder: stack / refresh",default=true,description="Original stacking and refresh branches, independently of initial application."},
}
local commonWarrior = WarriorRows("warriorArmsCache","warriorArmsPvPCache","warriorFuryCache","warriorFuryPvPCache","equipCache2H","equipCacheDW","equipCacheFastOffHand","equipCacheSlowOffHand")
local extraWarrior = {
    {id="Shield Bash",description="PvP shield interrupt; preparation follows the available interrupt."},
    {id="Commanding Shout",description="Complements other Warriors and refreshes the player's existing shout."},
    {id="Mortal Strike",description="Core readiness and its resource reservation."},
    {id="Overpower",description="Arms tracked dodge opportunity replaces its filler row."},
    {id="Thunder Clap",description="Arms assigned maintenance stance handoff."},
    {id="Stopcasting",label="Queue/cast cleanup (required)",locked=true,description="Required cleanup of an existing cast or queued attack remains available."},
}
local function WarriorExtras(...)
    local wanted, result = {...}, {}
    for _, action in ipairs(wanted) do
        if action == "Sunder Armor" then
            result[#result + 1] = {id=action,description="Tank armor maintenance when Devastate is unavailable."}
        elseif action == "Devastate" then
            result[#result + 1] = {id=action,description="Tank armor maintenance when learned, with Sunder as its fallback."}
        elseif action == "Bloodthirst" then
            result[#result + 1] = {id=action,description="Enabled heavy-hitter fallback and its resource reservation."}
        else
            for _, step in ipairs(extraWarrior) do if step.id==action then result[#result + 1]=step end end
        end
    end
    return result
end
local function Wowsims(target)
    local entry=jungle.RoutineContext
    entry.wowsimsOwned=jungle.WarriorWowsimsOwns(target)
    return jungle.warriorWowsims(target)
end
Register("warrior.original","Universal — Original","WARRIOR","dpsRotate",{jungle.warriorUniversal},commonWarrior,2,"original",{
    options=originalOptions,extraSteps=extraWarrior})
local wowsimsOptions=Options("wowsims_")
Register("warrior.wowsims","Arms — WoWSims","WARRIOR","dpsRotate",{Wowsims},WarriorRows("rows","wowsimsAoE"),2,"wowsims",{
    options=wowsimsOptions,extraSteps=WarriorExtras("Commanding Shout","Stopcasting"),
    hold=function() return jungle.RoutineContext.wowsimsOwned end})
local adaptiveOptions={};for _,option in ipairs(originalOptions) do adaptiveOptions[#adaptiveOptions+1]=option end
for _,option in ipairs(Options("adaptive_")) do adaptiveOptions[#adaptiveOptions+1]=option end
Register("warrior.adaptive","Arms — Adaptive","WARRIOR","dpsRotate",{jungle.warriorAdaptive},WarriorRows("adaptivePve","adaptivePvp"),2,"adaptive",{
    options=adaptiveOptions,extraSteps=WarriorExtras("Stopcasting"),source="Routines/WarriorAdaptive.lua",
    hold=function() return jungle.WarriorAdaptive:HoldPlacement() end})
Register("warrior.arms","Arms — Original","WARRIOR","dpsRotate",{jungle.warriorArms},WarriorRows("warriorArmsCache","warriorArmsPvPCache","equipCache2H"),2,"original",{options=originalOptions,extraSteps=WarriorExtras("Shield Bash","Commanding Shout","Stopcasting","Overpower","Thunder Clap")})
Register("warrior.fury","Fury","WARRIOR","dpsRotate",{jungle.warriorFury},WarriorRows("warriorFuryCache","warriorFuryPvPCache","equipCacheDW","equipCacheFastOffHand","equipCacheSlowOffHand"),2,"original",{options=originalOptions,extraSteps=WarriorExtras("Commanding Shout","Stopcasting","Mortal Strike")})
Register("warrior.tank","Tank","WARRIOR","dpsRotate",{jungle.warriorTank},WarriorRows("warriorTankCache","equipCacheShield"),5,"original",{extraSteps=WarriorExtras("Devastate","Sunder Armor","Bloodthirst","Mortal Strike","Commanding Shout","Stopcasting")})
Register("warrior.maintenance","PvE maintenance","WARRIOR","dpsRotate",{jungle.warriorArmsPveMaintenance},WarriorRows("warriorArmsPveMaintenanceCache"),1,"original",{options=originalOptions})
local function Enemy()
    if UnitExists("target") and UnitCanAttack("player","target") and not UnitIsDeadOrGhost("target") then return "target" end
    if UnitExists("softenemy") and UnitCanAttack("player","softenemy") and not UnitIsDeadOrGhost("softenemy") then return "softenemy" end
end
Register("warrior.sweeping","Sweeping sequence / pooling","WARRIOR","dpsRotate",{jungle.warriorThread3AoE},WarriorRows("warriorThread3Cache"),3,"original",{
    extraSteps=WarriorExtras("Bloodthirst","Mortal Strike","Stopcasting"),reset=jungle.ResetWarriorRoutineState,
    owns=function() local target=Enemy(); return target and jungle.WarriorThread3OwnsTarget(target) end,
    hold=function() return true end,
})
Register("rogue.dps","DPS","ROGUE","dpsRotate",{jungle.rogueDpsSet},{"Rogue.dpsRogueCache"},5)
Register("support.fishing","Fishing",nil,"rotate",{jungle.Fishing},{},7,nil,{source="Routines/Fishing.lua",extraSteps={
    {id="Lure",description="Apply a missing lure; preserve cast/channel guards and bounded retry timing."},
    {id="Fishing",description="Fish when the existing fishing observation is inactive. Requires a fishing pole."},
}})
Register("support.follower","Follower",nil,"rotate",{jungle.followerSet},{"Follower.followerCache"},7)

-- Stable compatibility identities are registered once; their validated row/step
-- metadata is shared with the selected algorithm. Fallback-only variants remain
-- registered solely for migration and are archived out of saved thread lists.
local bases={}
for _,def in ipairs(Config.order) do if def.class=="WARRIOR" then bases[#bases+1]=def end end
for _,base in ipairs(bases) do
    local modes={};Config.variantIDs[base.id]=modes
    for _,mode in ipairs({"original","wowsims","adaptive"}) do
        local policies={};modes[mode]=policies
        for policy=1,7 do
            local behavior=jungle.RoutineBehaviors.warrior[policy]
            local id=base.id..".behavior-"..behavior.name..".mode-"..mode
            local label=base.label.." / saved "..behavior.label.." ("..mode..")"
            local hidden=true
            if mode==base.mode and behavior==base.behavior then id=base.id
            elseif base.id=="warrior.original" and mode=="original" and policy==1 then
                id="warrior.original.maintenance";label="Original combat / maintenance";hidden=false
            elseif base.id=="warrior.original" and mode=="original" and policy==3 then
                id="warrior.original.sweepingFallback";label="Retired Sweeping fallback"
            end
            policies[policy]=id
            if id~=base.id then
                local universal=base.algorithm=="original" or base.algorithm=="wowsims" or base.algorithm=="adaptive"
                local template=universal and Config.definitions["warrior."..mode] or base
                if hidden and id~="warrior.original.sweepingFallback" then label=template.label.." / saved "..behavior.label end
                local def={};for key,value in pairs(template) do def[key]=value end
                def.legacyBase=base.id
                def.retired=universal and policy==3 or nil
                def.id,def.label,def.behavior,def.mode,def.hidden=id,label,behavior,mode,hidden
                def.metadataFrom=template.id
                def.displayViews=DisplayViews(def)
                local ok,reason=Config:Register(def)
                if not ok then error(reason) end
            end
        end
    end
end
-- Kebab is a new authored identity, after compatibility expansion; no legacy variants/default replacement.
local kebabBehavior = assert(jungle.RoutineBehaviors:RegisterWarrior("kebab", {
    label="Kebab combat", projectedSlam=false, coreFirstAoE=false, demoFallback=false,
    earlyDemo=false, allowsWowsims=false, allowsAdaptive=false,
}))
local kebabDef = {
    id="warrior.kebab", label="Kebab", class="WARRIOR", kind="class", selector="dpsRotate",
    algorithm="kebab", mode="original", behavior=kebabBehavior,
    source="Routines/WarriorKebab.lua", functions={jungle.warriorKebab}, rowSets={"Warrior.kebab"},
    links={["Battle Stance"]="Charge"},
    options={
        {key="execute_ms",label="Execute: retain Mortal Strike",default=false,description="During Execute, fund MS only while retaining minimum Execute cost + 5 rage."},
        {key="execute_ww",label="Execute: retain Whirlwind",default=true,description="During Execute, fund safe WW only while retaining minimum Execute cost + 5 rage."},
        {key="execute_cleave",label="AoE Execute: allow paid Cleave",default=false,description="Allow funded Cleave in safe AoE Execute, retaining enabled core and minimum Execute funding. Otherwise cancel carried Cleave."},
        {key="execute_hs",label="Execute: allow paid Heroic Strike",default=false,description="Allow paid HS admission during Execute with the funded queue budget. When off, cancel carried HS; when on, abilities use current rage with HS still queued. Queuing spends no rage or GCD."},
        {key="sunder_initial",label="Init Sunder Armor",default=false,description="With the Sunder action enabled, prioritize a missing Sunder or refresh at <=3 seconds, including Execute. Uses current rage before damage, without a core reserve. Does not build healthy stacks. Skip Expose Armor."},
        {key="sunder_stack",label="Stack Sunder Armor",default=false,description="With the Sunder action enabled, prioritize the first stack or refresh at <=3 seconds, including Execute. Build healthy stacks up to five only after damage cores/free Victory Rush, in a >=1.5s core gap. Normal single target retains exact upcoming/next core costs plus any already funded queued HS payment; AoE/Execute retains its existing next-core funding +5. Skip Expose Armor."},
        {key="demo",label="Maintain Demoralizing Shout",default=false,description="Enable this preference and the Demo action step. Prioritize missing/five-second refresh before damage, queues, burst and self shouts, including Execute. Uses current rage with no core reserve. Skip other AP debuffs and unsafe nearby enemies."},
        {key="cooldowns",label="Automatic Death Wish / trinkets",default=true,description="Use learned Death Wish and on-use trinkets in combat/melee. Normal Death Wish waits for a ready GCD and >=1.5s core gap, retaining upcoming/next cores and any funded queued HS payment. Trinkets remain off GCD without this gap hold. Their action switches remain independent."},
        {key="burst_lust",label="Hold damage cooldowns for Bloodlust",default=false,description="Wait for an observed Bloodlust/Heroism aura for Death Wish, trinkets and enabled Recklessness. Can hold indefinitely if no aura arrives."},
        {key="recklessness",label="Allow boss Recklessness",default=false,description="Allow the long cooldown on a recognized boss in Berserker Stance; respects optional Bloodlust alignment. Normal single target requires a ready GCD and >=1.5s core gap."},
        {key="berserker_rage",label="Spare-global Berserker Rage",default=false,description="Enable this preference and the Berserker Rage action step. Outside Execute in a 1.5-second core gap; Normal HS admission precedes it. Can use its GCD with HS/Cleave queued. Not an immediate baseline rage grant."},
    },
    hold=function() return jungle.WarriorKebab and jungle.WarriorKebab:Hold() end,
    reset=function() if jungle.WarriorKebab then jungle.WarriorKebab:Reset() end end,
}
kebabDef.displayViews=DisplayViews(kebabDef)
local kebabOK,kebabError=Config:Register(kebabDef)
if not kebabOK then error(kebabError) end
local function Entry(id) return {id=id, enabled=true, steps={}, options={}} end
local function Threads() return {{},{},{},{},{},{},{Entry("support.fishing"),Entry("support.follower")}} end
Config.defaults.UNKNOWN = Threads()
for _, class in ipairs({"HUNTER","MAGE","PALADIN","PRIEST","SHAMAN","WARLOCK"}) do Config.defaults[class] = Threads() end
local d = Threads()
d[1]={Entry("druid.healingWeapon"),Entry("druid.pvp")}
d[2]={Entry("druid.healingWeapon"),Entry("druid.v6")}
d[3]={Entry("druid.dispel")}
d[4]={Entry("druid.healingWeapon"),Entry("druid.raidCombined")}
d[5]={Entry("druid.idle"),Entry("druid.dps")}
d[6]={Entry("druid.buffs")}
Config.defaults.DRUID = d
local w = Threads()
w[1]={Entry("warrior.maintenance"),Entry("warrior.original.maintenance")}
w[2]={Entry("warrior.original")}
w[3]={Entry("warrior.sweeping")}
w[5]={Entry("warrior.tank")}
Config.defaults.WARRIOR = w
local r = Threads(); r[5]={Entry("rogue.dps")}; Config.defaults.ROGUE = r
