-- Lua 5.1, actual configuration/UI callbacks with mocked frames. No live-client claim.
local checks=0
local function Check(ok,why) assert(ok,why);checks=checks+1 end
local function Read(path) local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local source=Read('tests/RoutineConfig.test.lua')
local stop=assert(source:find('local legacy=',1,true))
local Fixture=assert(loadstring(source:sub(1,stop-1)..'\nreturn Fixture'))()
local function Copy(v) if type(v)~='table' then return v end;local out={};for k,x in pairs(v) do out[k]=Copy(x) end;return out end
local function Threads(entry) return {{entry},{},{},{},{},{},{}} end
local db={schemaVersion=1,routineSchemaVersion=1,profiles={},characters={['Fixture - Realm']='migration-1'}}
local expected={};local n=0
for _,id in ipairs({'warrior.original','warrior.wowsims','warrior.adaptive','warrior.arms','warrior.fury','warrior.tank','warrior.maintenance','warrior.sweeping'}) do
    for _,mode in ipairs({'original','wowsims','adaptive'}) do
        for policy=1,7 do
            n=n+1;local name='migration-'..n
            local entry={id=id,policy=policy,mode=mode,enabled=n%2==0,steps={Slam=false,Cleave=true},
                options={sunderInitial=false,sunderStack=true,unknownPreference=false},defaultShout='Commanding Shout'}
            db.profiles[name]={classes={WARRIOR={migrated=true,options={},threads=Threads(entry)},DRUID={sentinel='untouched'}}}
            expected[name]={base=id,mode=mode,policy=policy,enabled=entry.enabled}
        end
    end
end
local j,e,state,frames=Fixture(db);local c=j.RoutineConfig
Check(c.db.routineSchemaVersion==3,'global schema upgraded')
for name,want in pairs(expected) do
    local profile=c.db.profiles[name];local settings=profile.classes.WARRIOR;local entry=settings.threads[1][1]
    local retired=want.policy==3 and (want.base=='warrior.original' or want.base=='warrior.wowsims' or want.base=='warrior.adaptive')
    if retired then
        Check(entry==nil and #settings.removedRoutineFallbacks==1,'fallback removed from saved thread: '..name)
        entry=settings.removedRoutineFallbacks[1].entry
    end
    local def=c.definitions[entry.id]
    Check(def and def.legacyBase==want.base and def.mode==want.mode and def.behavior.legacyPolicy==want.policy,'all profiles preserve effective behavior: '..name)
    Check(entry.policy==nil and entry.mode==nil and entry.enabled==want.enabled,'no saved behavior override: '..name)
    Check(entry.steps.Slam==false and entry.steps.Cleave==true and entry.options.sunderInitial==false and entry.options.unknownPreference==false,'preferences survive: '..name)
    Check(entry.defaultShout=='Commanding Shout' and profile.classes.DRUID.sentinel=='untouched','shout and another class preserved: '..name)
    Check(settings.routineBehaviorVersion==2,'class migration marked')
end
local stored=Copy(c.db);local reloaded=Fixture(Copy(stored));local again=reloaded.RoutineConfig
for name in pairs(expected) do
    local sa=stored.profiles[name].classes.WARRIOR;local sb=again.db.profiles[name].classes.WARRIOR
    local a=sa.threads[1][1] or sa.removedRoutineFallbacks[1].entry
    local b=sb.threads[1][1] or sb.removedRoutineFallbacks[1].entry
    Check(not sb.removedRoutineFallbacks or #sb.removedRoutineFallbacks==1,'archive idempotent')
    Check(a.id==b.id and b.policy==nil and b.mode==nil and b.steps.Slam==false,'stable IDs and idempotent reload: '..name)
end
local visible={};for _,def in ipairs(c:Available(1)) do visible[def.id]=true;Check(not def.hidden,'compatibility not in Add list') end
Check(visible['warrior.original'] and visible['warrior.original.maintenance'] and not visible['warrior.original.sweepingFallback'],'meaningful combat variants available')
local compatibility=c.variantIDs['warrior.adaptive'].adaptive[5]
Check(c.definitions[compatibility].hidden and not c:Add(4,compatibility),'unusual imported behavior cannot be added as a new routine')
Check(c:SelectProfile('migration-54'),'select another migrated profile')
local oldEntry=c:GetEntry(1,1);local oldPlan=c.plans[1]
state.combat=true;c:SetEnabled(1,1,true)
Check(c.pending and c.plans[1]==oldPlan and oldEntry.enabled,'saved change defers compilation')
state.combat=false;c:Compile();Check(not c.pending,'combat-end compile applies')
-- Existing defaults are definition identities, independent of thread placement.
Check(c:NewProfile('clean'),'new profile')
Check(c:GetEntry(1,2).id=='warrior.original.maintenance' and c.plans[1][2].behavior.name=='maintenance','thread1 defaults preserved')
Check(c:GetEntry(2,1).id=='warrior.original' and c.plans[2][1].behavior.name=='baseline','thread2 defaults preserved')
Check(c:GetEntry(3,2)==nil and #c.plans[3]==1 and c.plans[3][1].definition.id=='warrior.sweeping','thread3 owns only Sweeping by default')
Check(c:GetEntry(5,1).id=='warrior.tank','actual Tank stays Tank')
for thread=1,6 do
    c:ResetThread(thread)
    if thread==4 or thread==6 then Check(c:Add(thread,'warrior.original.maintenance'),'add movable maintenance combat') end
end
Check(c.plans[4][1].behavior==c.plans[1][2].behavior and c.plans[6][1].behavior==c.plans[1][2].behavior,'same definition has identical behavior in every slot')
local before=c.plans[4][1]
c:GetEntry(4,1).policy=5;c:Changed()
Check(c:GetEntry(4,1).policy==nil and c.plans[4][1].behavior.name=='class-fallback' and c:GetEntry(4,1).id~=before.definition.id,'incoming legacy override becomes visible routine identity')
local rows
for _,frame in ipairs(frames) do if frame.kind=='routine' and frame.thread==4 and frame.index==1 then rows=frame end end
Check(rows and rows.label:GetText():find('saved',1,true),'compatibility placement is labelled')
rows.more.scripts.OnClick(rows.more)
for _,item in ipairs(j.Options.routineMenu.items) do Check(item.label~='Priority preset','no selectable behavior menu') end
-- Invalid/duplicate imported rows remain invalid and removable; do not enable them during migration.
c:GetThreads()[4]={{id='warrior.original',policy=1},{id='warrior.original',policy=2},{id='missing',policy=3,mode='adaptive'}}
c:Compile()
Check(#c.plans[4]==1 and c.errors['4:2'] and c.errors['4:3'],'pre-migration duplicate does not become an active second variant')
Check(c:GetEntry(4,3).policy==3 and c:GetEntry(4,3).mode=='adaptive','unknown routine data retained')
Check(c:Remove(4,2),'invalid saved placement removable')
-- Authoring API accepts a semantic definition without a legacy thread adapter.
local b,why=j.RoutineBehaviors:RegisterWarrior('example-contract',{projectedSlam=true,coreFirstAoE=false,demoFallback=true,earlyDemo=false,allowsWowsims=false,allowsAdaptive=false})
Check(b and not why and b.legacyPolicy==nil,'new behavior needs no numeric policy')
Check(not j.RoutineBehaviors:RegisterWarrior('example-contract',{}),'duplicate behavior rejected')
local base=c.definitions['warrior.original'];local resets=0;local function Reset() resets=resets+1 end
for _,id in ipairs({'test.authored-one','test.authored-two'}) do
    local def=Copy({id=id,label=id,source=base.source,class=base.class,kind=base.kind,selector=base.selector,mode='original'})
    def.behavior=b;def.functions=base.functions;def.rowSets=base.rowSets;def.extraSteps=base.extraSteps;def.options=base.options;def.links=base.links;def.metadataFrom=base.id;def.reset=Reset
    Check(c:Register(def),'register authored behavior and reusable metadata')
end
Check(c:Add(6,'test.authored-one'),'add authored routine')
local entry=c.plans[6][2];j.RoutineContext=entry
Check(j.GetWarriorRoutineBehavior()==b and j.GetRoutineThread()==nil,'definition never inherits physical thread behavior')
j.RoutineContext=nil;entry.state.pending='decision';local previous=resets
j.Engine:SetThread(6)
Check(resets==previous+1 and entry.state.pending==nil,'reset callback deduplicated and prospective state cleared')
local other=c.plans[4][1]
Check(entry.state~=other.state,'independent runtime state per placement')
c.db.routineSchemaVersion=9;c:GetClass().routineBehaviorVersion=9;c:Compile()
Check(c.db.routineSchemaVersion==9 and c:GetClass().routineBehaviorVersion==9,'newer schema never downgraded')
j.CurrentCast=nil;j.Engine.activeThread=0
local idle=j.GetWarriorRoutineBehavior()
Check(not idle.projectedSlam and not idle.demoFallback and not idle.allowsWowsims and not idle.allowsAdaptive,'unbound idle calls retain neutral legacy behavior')
print('RoutineBehavior: '..checks..' migration, identity, defaults, UI and lifecycle checks passed (mocked client).')
