local AddonName, jungle = ...
-- Construction-time contracts. Placements reference these tables; never mutate them.
local Behavior = {warrior = {}, byName = {}}
jungle.RoutineBehaviors = Behavior
local optionKeys = {
    [1]={demo="thread1_demoralizing_shout",thunderClap="thread1_thunder_clap",sunderInitial="thread1_sunder_initial",sunderStack="thread1_sunder_stack"},
    [2]={demo="thread2_demoralizing_shout",sweeping="thread2_sweeping_strikes",sunderInitial="thread2_sunder_routine",sunderStack="thread2_sunder_routine"},
    [3]={demo="thread3_demoralizing_shout",sunderInitial="thread3_sunder_fallback",sunderStack="thread3_sunder_fallback"},
}
local names={"maintenance","baseline","sweeping-fallback","legacy-four","class-fallback","legacy-six","legacy-support"}
local labels={"maintenance combat","baseline combat","AoE combat","legacy combat 4","legacy combat 5","legacy combat 6","legacy support combat"}
for policy=1,7 do
    local behavior={name=names[policy],label=labels[policy],legacyPolicy=policy,
        projectedSlam=policy==2 or policy==3,coreFirstAoE=policy==2,
        demoFallback=policy==1 or policy==2 or policy==3,earlyDemo=policy==2,
        allowsWowsims=policy==1 or policy==2 or policy==3,
        allowsAdaptive=policy==1 or policy==2 or policy==3 or policy==7,
        handoff=names[policy],optionKeys=optionKeys[policy] or {}}
    Behavior.warrior[policy]=behavior;Behavior.byName[behavior.name]=behavior
end
-- New definitions may author a named contract without inheriting a thread number.
function Behavior:RegisterWarrior(name, values)
    if type(name)~="string" or name=="" or self.byName[name] or type(values)~="table" then return nil,"Invalid/duplicate behavior" end
    local behavior={name=name,label=values.label or name,handoff=values.handoff or name,optionKeys=values.optionKeys or {}}
    for _,key in ipairs({"projectedSlam","coreFirstAoE","demoFallback","earlyDemo","allowsWowsims","allowsAdaptive"}) do
        if type(values[key])~="boolean" then return nil,"Missing behavior property: "..key end
        behavior[key]=values[key]
    end
    if type(behavior.label)~="string" or type(behavior.handoff)~="string" or type(behavior.optionKeys)~="table" then return nil,"Invalid behavior metadata" end
    for kind,key in pairs(behavior.optionKeys) do if type(kind)~="string" or type(key)~="string" then return nil,"Invalid option mapping" end end
    if values.legacyPolicy~=nil then
        local policy=values.legacyPolicy
        if type(policy)~="number" or policy<1 or policy>7 or policy~=math.floor(policy) then return nil,"Invalid legacy adapter" end
        behavior.legacyPolicy=policy
    end
    self.byName[name]=behavior;return behavior
end
-- Unbound/idle legacy calls have no policy-specific branches, as before.
local unbound={name="legacy-unbound",handoff="legacy-unbound",optionKeys={},
    projectedSlam=false,coreFirstAoE=false,demoFallback=false,earlyDemo=false,
    allowsWowsims=false,allowsAdaptive=false}
function jungle.GetWarriorRoutineBehavior()
    local entry=jungle.RoutineContext
    if not entry and jungle.GetRoutineEntry then entry=jungle.GetRoutineEntry() end
    if entry then
        if entry.behavior then return entry.behavior end
        -- Standalone/legacy callers may supply the old context; compiled placements never do.
        if entry.policy and Behavior.warrior[entry.policy] then return Behavior.warrior[entry.policy] end
        if entry.definition and entry.definition.behavior then return entry.definition.behavior end
    end
    local policy=jungle.GetRoutineThread and jungle.GetRoutineThread() or (jungle.Engine and jungle.Engine.activeThread)
    return Behavior.warrior[policy] or unbound
end
