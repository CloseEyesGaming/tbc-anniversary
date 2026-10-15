-- Lua 5.1, actual routine implementations. API stubs model conditions, not spell outcomes.
-- Optional argument: exact task checkpoint directory for support comparisons.
local baseline=...
local checks=0
local function Check(ok,why) assert(ok,why);checks=checks+1 end
local function Read(path) local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local function Factory(path,boundary,result)
    local s=Read(path);local p=assert(s:find(boundary,1,true))
    return assert(loadstring(s:sub(1,p-1)..'\nreturn '..result))()
end
local Context=Factory('tests/WarriorOptions.test.lua','local function Snapshot(rows)','Context')
local AdaptiveFixture=Factory('tests/WarriorAdaptive.test.lua','for count=1,10 do','Fixture')
local DruidSetup=Factory('tests/DruidMaintenanceTriage.test.lua','local modulePath =','Setup')
local DruidCase=Factory('tests/DruidMaintenanceTriage.test.lua','local function Expect(options','Case')
local Attach=assert(loadfile('tests/RoutineConfigFixture.lua'))()
local function Mask(j,env,class)
    -- Load the actual fixed registries without executing bar creation.
    local source=Read('Core/Hotkeys.lua')
    local stop=assert(source:find('function Hotkeys:CreateStaticBar()',1,true))
    setfenv(assert(loadstring(source:sub(1,stop-1))),env)('OliaEyes6',j)
    local config=Attach(j,env,class)
    for _,def in ipairs(config.order) do Check(not def.validationError,'registered action identities: '..def.id) end
    -- These fixtures override readiness. Retain the actual helper's mask contract.
    for _,key in ipairs({'ReadyCastSpell','IsSpellReadyIgnoreGCD'}) do
        local original=j[key]
        if original then j[key]=function(action,...) return j.RoutineAllows(action) and original(action,...) end end
    end
    local original=j.SpellOnCD
    if original then j.SpellOnCD=function(action,...) return not j.RoutineAllows(action) or original(action,...) end end
    return config
end
local function Eligible(rows,action)
    for _,row in ipairs(rows) do if row[2]==action and row[3] then return true end end
    return false
end
local function Snapshot(rows)
    local result={}
    for i,row in ipairs(rows) do result[#result+1]=i..':'..tostring(row[2])..':'..tostring(not not row[3]) end
    return table.concat(result,'\n')
end
local function Entry(c,id)
    local def=assert(c.definitions[id]);return {definition=def,actions={},options={},policy=def.policy,mode=def.mode or 'original',defaultShout='Battle Shout'}
end
-- Every mask in the real Warrior routines suppresses all authored rows of that action.
for _,state in ipairs({{thread=2},{thread=1},{thread=3,enemies=3},{thread=5},{thread=2,fury=true},{thread=2,pvp=true},{thread=2,moving=true}}) do
    local j,e=Context(state);local c=Mask(j,e,'WARRIOR')
    local id=state.thread==5 and 'warrior.tank' or (state.fury and 'warrior.fury' or 'warrior.arms')
    local entry=Entry(c,id);j.RoutineContext=entry
    local fn=id=='warrior.tank' and j.warriorTank or id=='warrior.fury' and j.warriorFury or j.warriorArms
    for _,step in ipairs(entry.definition.steps) do
        if not step.locked then
            entry.actions[step.id]=false
            Check(not Eligible(fn('target'),step.id),'disabled Warrior action: '..id..' / '..step.id)
            entry.actions[step.id]=nil
        end
    end
end
-- Disabling Slam releases prospective holds and does not query movement/latency/swing projection.
do
    local state={thread=2};local j,e=Context(state);local c=Mask(j,e,'WARRIOR')
    local entry=Entry(c,'warrior.arms');entry.actions.Slam=false;j.RoutineContext=entry
    e.GetUnitSpeed=function() error('disabled Slam sampled movement') end
    e.GetNetStats=function() error('disabled Slam sampled latency') end
    j.SwingTimer.GetSlamTimeRemaining=function() error('disabled Slam projected swing') end
    local slam=j.GetWarriorSlamDecisionState(true,true,40,false,false)
    Check(not slam.reserveSlamWindow and not slam.reserveInitialSwingForSlam and not slam.reserveSlamPreSwing,'disabled Slam releases reservations')
    Check(not slam.holdGCDForSlam and not slam.blockCoreForSlam and not slam.canSlamAfterSwing,'disabled Slam releases core GCD')
    state.casting=true;slam=j.GetWarriorSlamDecisionState(true,true,40,false,false)
    Check(slam.isCastingSlam and slam.holdGCDForSlam,'real in-progress Slam remains protected')
end
-- Disabled core spells release their AoE Slam funding; the authored default threshold remains.
do
    local j,e=Context({thread=2});local c=Mask(j,e,'WARRIOR')
    local entry=Entry(c,'warrior.arms');j.RoutineContext=entry
    entry.actions['Sweeping Strikes']=false;entry.actions['Mortal Strike']=false;entry.actions.Whirlwind=false
    Check(j.GetWarriorSlamDecisionState(true,true,20,true,false).slamRageThreshold==15,'Slam does not fund disabled AoE core actions')
    entry.actions.Whirlwind=nil
    Check(j.GetWarriorSlamDecisionState(true,true,50,true,false).slamRageThreshold==30,'Slam retains enabled Whirlwind funding')
    entry.actions['Mortal Strike']=nil
    Check(j.GetWarriorSlamDecisionState(true,true,80,true,false).slamRageThreshold==60,'all-enabled authored core threshold restored')
end
-- The dedicated Sweeping owner releases immediately when its defining action is disabled.
do
    local j,e=Context({thread=3,enemies=3});local c=Mask(j,e,'WARRIOR')
    local entry=Entry(c,'warrior.sweeping');j.RoutineContext=entry
    Check(j.WarriorThread3OwnsTarget('target'),'Sweeping default ownership')
    entry.actions['Sweeping Strikes']=false
    Check(not j.WarriorThread3OwnsTarget('target'),'disabled Sweeping releases ownership')
end
-- Adaptive preparation and funding use the placement's enabled actions.
do
    local s,j,e=AdaptiveFixture({rage=40,enemies=3,options={adaptive_sunder_initial=false,adaptive_sunder_stack=false,adaptive_thunder_clap=false,adaptive_demoralizing_shout=false}})
    local c=Mask(j,e,'WARRIOR');local entry=Entry(c,'warrior.adaptive');j.RoutineContext=entry
    for _,opt in ipairs(entry.definition.options) do entry.options[opt.key]=s.settings[opt.key] end
    entry.actions.Whirlwind=false;entry.actions.Slam=false
    local rows=j.warriorAdaptive('target')
    Check(Eligible(rows,'Sweeping Strikes'),'disabled Whirlwind releases its Sweeping funding requirement')
    Check(not j.WarriorAdaptive.state.pendingSlam and not j.WarriorAdaptive.state.canSlam,'Adaptive clears disabled Slam planning')
end
for _,case in ipairs({
    {action='Charge',state={stance=3,outOfRange=true,outOfCombat=true}},
    {action='Intercept',state={stance=1,outOfRange=true}},
    {action='Pummel',state={stance=1,interrupt=true}},
    {action='Thunder Clap',state={stance=3,options={adaptive_sunder_initial=false,adaptive_sunder_stack=false,adaptive_demoralizing_shout=false}}},
}) do
    local s,j,e=AdaptiveFixture(case.state);local c=Mask(j,e,'WARRIOR');local entry=Entry(c,'warrior.adaptive');j.RoutineContext=entry
    for _,opt in ipairs(entry.definition.options) do entry.options[opt.key]=s.settings[opt.key] end
    entry.actions[case.action]=false;s:action()
    local reason=j.WarriorAdaptive.state.reason or (s.diagnostic and s.diagnostic.reason)
    Check(reason~='charge_stance' and reason~='intercept_stance' and reason~='interrupt_stance' and reason~='prepare_thunder_clap','disabled action releases Adaptive preparation: '..case.action)
end
-- V6 caches must distinguish different masks evaluated in the same tick.
do
    local j,select,_,e=DruidCase({tankHP=0.85,raidHP=0.50,expiry=0.8});select()
    local c=Mask(j,e,'DRUID');local a=Entry(c,'druid.v6');local b=Entry(c,'druid.v6')
    a.actions.Lifebloom=false;j.RoutineContext=a
    for _,unit in ipairs({'tank','raid'}) do Check(not Eligible(j.universalHealSetV6(unit),'Lifebloom'),'disabled bloom excluded from schedule and candidates') end
    j.RoutineContext=b;local enabled=false
    for _,unit in ipairs({'tank','raid'}) do if Eligible(j.universalHealSetV6(unit),'Lifebloom') then enabled=true end end
    Check(enabled,'second placement gets its own bloom schedule within same tick')
    j.RoutineContext=a
    for _,unit in ipairs({'tank','raid'}) do Check(not Eligible(j.universalHealSetV6(unit),'Lifebloom'),'same-tick return to disabled bloom placement') end
    for _,action in ipairs({'Healing Touch',"Nature's Swiftness",'Regrowth','Swiftmend','Rejuvenation','Tranquility'}) do
        a.actions[action]=false
        for _,unit in ipairs({'tank','raid'}) do Check(not Eligible(j.universalHealSetV6(unit),action),'disabled V6 action '..action) end
        a.actions[action]=nil
    end
end
-- Reuse optional-enemy API fixtures without running their test loops.
local optional=Read('tests/OptionalEnemy.test.lua')
local ds=assert(optional:find('local function Druid(s,path)',1,true))
local de=assert(optional:find('local druidSelf=',ds,true))
local fs=assert(optional:find('local function FollowerSetup(driver)',1,true))
local fe=assert(optional:find('local f,fe=FollowerSetup(nil)',fs,true))
local guardStart=assert(optional:find('local function GuardUnitReads',1,true))
local guardEnd=assert(optional:find('local function Warrior(s,path)',guardStart,true))
local helpers=assert(loadstring('local DruidSetup=...\n'..optional:sub(guardStart,guardEnd-1)..optional:sub(ds,de-1)..optional:sub(fs,fe-1)..'\nreturn {Druid=Druid,Follower=FollowerSetup}'))(DruidSetup)
-- Rogue's behind-a-dagger builder has a valid fallback when Backstab is disabled.
do
    local j,e=helpers.Druid({hasEnemy=true,cp=1});setfenv(assert(loadfile('Routines/Rogue.lua')),e)('OliaEyes6',j)
    e.GetInventoryItemID=function() return 1 end;e.GetItemInfoInstant=function() return nil,nil,nil,nil,nil,2,15 end
    local c=Mask(j,e,'ROGUE');local entry=Entry(c,'rogue.dps');j.RoutineContext=entry
    Check(Eligible(j.rogueDpsSet('target'),'Backstab'),'Rogue authored Backstab')
    entry.actions.Backstab=false
    Check(Eligible(j.rogueDpsSet('target'),'Sinister Strike'),'disabled Backstab releases Sinister Strike fallback')
end
-- Follower's authored default conditions remain exact; disabled Tree no longer blocks Follow.
do
    local j,e=helpers.Follower('target');local c=Mask(j,e,'DRUID');local entry=Entry(c,'support.follower');j.RoutineContext=entry
    j.inMeleeRange=function() return false end
    local original=Snapshot(j.followerSet('target'))
    if baseline then
        local old,oe=helpers.Follower('target');setfenv(assert(loadfile(baseline..'/Routines/Follower.lua')),oe)('OliaEyes6',old)
        old.inMeleeRange=function() return false end
        Check(original==Snapshot(old.followerSet('target')),'Follower default output equals checkpoint')
    end
    entry.actions['Tree of Life']=false
    local rows=j.followerSet('target')
    Check(not Eligible(rows,'Tree of Life') and Eligible(rows,'Follow'),'disabled Tree releases authored Follow decision')
    entry.actions.Follow=false;Check(not Eligible(j.followerSet('target'),'Follow'),'disabled Follow stays disabled')
    entry.actions.Mount=false
    e.UnitAffectingCombat=function() return false end
    e.UnitAura=function(unit,index) if unit=='target' and index==1 then return 'Cerulean Phase-Hunter',nil,nil,nil,0,0 end end
    j.Hotkeys.UpdateStaticMacro=function() error('disabled Mount updated macro') end
    Check(not Eligible(j.followerSet('target'),'Mount'),'disabled Mount suppresses macro preparation')
end
-- Fishing's disabled Lure neither records an attempt nor prevents Fishing.
local function Fishing(path)
    local state={now=100,cast=false,channel=false,enchant=false,fishing=false}
    local e=setmetatable({}, {__index=_G});e._G=e
    e.GetTime=function() return state.now end;e.UnitCastingInfo=function() return state.cast and 'Lure' end
    e.UnitChannelInfo=function() return state.channel and 'Fishing' end
    e.GetWeaponEnchantInfo=function() return state.enchant end
    local j={unitCache={},IsFishing=function() return state.fishing end}
    setfenv(assert(loadfile(path or 'Routines/Fishing.lua')),e)('OliaEyes6',j)
    j.RoutineContext={actions=setmetatable({}, {__index=function(_,action) return not state.disabled or action~='Lure' end})}
    return state,j,e
end
do
    local s,j=Fishing();s.disabled=true
    Check(Eligible(j.Fishing(),'Fishing') and not Eligible(j.Fishing(),'Lure'),'disabled Lure preserves Fishing')
    Check(j.lastLureAttemptTime==nil,'disabled Lure does not poison retry timestamp')
    s.disabled=false;Check(Eligible(j.Fishing(),'Lure') and j.lastLureAttemptTime==100,'reenabled Lure immediately follows authored retries')
    if baseline then
        for _,case in ipairs({{},{enchant=true},{channel=true},{cast=true},{fishing=true}}) do
            local a,current=Fishing();local b,old=Fishing(baseline..'/Routines/Fishing.lua')
            for key,value in pairs(case) do a[key]=value;b[key]=value end
            for _,time in ipairs({100,102,104,110,120}) do
                a.now=time;b.now=time
                Check(Snapshot(current.Fishing())==Snapshot(old.Fishing()),'Fishing default checkpoint comparison')
                Check(current.lastLureAttemptTime==old.lastLureAttemptTime,'Fishing default retry timestamps')
            end
        end
    end
end
-- Invalid evaluator results fail closed at the real shared selection boundary.
do
    local j,e=Context({thread=2});local c=Mask(j,e,'WARRIOR')
    local entry=Entry(c,'warrior.arms');j.RoutineContext=entry
    setfenv(assert(loadfile('Rotation.lua')),e)('OliaEyes6',j)
    local rotation=j.Rotation:new()
    Check(not rotation:condition({function() return {{'bad','UndeclaredAction',true}} end,function() return {{'valid','Slam',true}} end},1,'target'),'undeclared output is never selected')
    Check(entry.invalid and entry.invalid:find('undeclared',1,true),'undeclared output identifies invalid evaluator')
    entry.invalid=nil
    Check(not rotation:condition({function() return false end},1,'target'),'non-table evaluator result is rejected')
    Check(entry.invalid=='Evaluator must return a row table','non-table output identifies invalid evaluator')
    entry.invalid=nil;j.unitCache={one={},two={}};j.isUnitAvailable=function() return true end
    e.UnitIsFriend=function() return true end
    j.Cast={CastSpell=function() error('invalid composite emitted action') end}
    local count=0
    Check(not rotation:rotate({function() count=count+1;return {{'mixed',count==1 and 'Slam' or 'UndeclaredAction',true}} end},1),'invalid friendly output discards an earlier candidate')
end
print('RoutineSteps: '..checks..' checks passed')
