-- Actual algorithms, binding metadata and compiled dispatch. Mocked client, Lua 5.1.
local function Read(path) local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local function Prefix(path,boundary,result)
    local s=Read(path);return assert(loadstring(s:sub(1,assert(s:find(boundary,1,true))-1)..'\nreturn '..result))()
end
local Adaptive=Prefix('tests/WarriorAdaptive.test.lua','for count=1,10 do','Fixture')
local Wowsims=Prefix('tests/WarriorWowsims.test.lua','-- Default-off is identical','Fixture')
local Attach=assert(loadfile('tests/RoutineConfigFixture.lua'))()
local checks=0
local function Check(ok,why) assert(ok,why);checks=checks+1 end
local function First(rows) for _,row in ipairs(rows) do if row[3] then return row[2] end end end
local function Register(j,e,id,following)
    local hotkeys=Read('Core/Hotkeys.lua')
    setfenv(assert(loadstring(hotkeys:sub(1,assert(hotkeys:find('function Hotkeys:CreateStaticBar()',1,true))-1))),e)('OliaEyes6',j)
    local threads={{},{},{},{},{},{},{}};threads[2]={{id=id}}
    e.OliaEyes6_Settings={characters={['Fixture - Realm']='isolation'},profiles={isolation={classes={WARRIOR={migrated=true,options={},threads=threads}}}}}
    local c=Attach(j,e,'WARRIOR');j.Options.Refresh=function() end
    local later=0;local emitted
    if following then
        Check(c:Register({id='test.next',label='Explicit next',source='tests/RoutineIsolation.test.lua',class='WARRIOR',kind='class',selector='dpsRotate',mode='original',behavior=j.RoutineBehaviors.warrior[2],
            functions={function() later=later+1;return {{'Next','Attack',true}} end},rowSets={},extraSteps={{id='Attack'}}}),'test placement registration')
        Check(c:Add(2,'test.next'),'explicit next placement')
    end
    local engine={activeThread=2,rotation={dpsRotate=function(_,functions)
        for _,fn in ipairs(functions) do
            for _,row in ipairs(fn('target')) do
                if row[3] and j.RoutineAllows(row[2]) then emitted=row[2];return true end
            end
        end
        return false
    end}}
    return c,function() emitted=nil;local result=c:Run(engine);return result,emitted,later end
end
local function Has(def,viewID,action)
    for _,view in ipairs(def.views) do if view.id==viewID then
        for _,section in ipairs(view.sections) do for _,step in ipairs(section.steps) do if step.id==action then return true end end end
    end end
end
-- Failed ownership must never call an Original or Fury core algorithm.
for _,args in ipairs({{pvp=true},{fury=true},{lost=true},{outOfRange=true},{outOfCombat=true},{dead=true},{totem=true}}) do
    local s,j=Wowsims(args)
    j.warriorArms=function() error('hidden Arms substitution') end
    j.warriorFury=function() error('hidden Fury substitution') end
    Check(First(j.warriorWowsims(args.lost and nil or 'target'))==nil,'WoWSims fails closed in unsupported context')
end
for _,args in ipairs({{fury=true},{mode='original'},{mode='wowsims'},{thread=5}}) do
    local s,j=Adaptive(args)
    j.warriorArms=function() error('hidden Arms substitution') end
    j.warriorFury=function() error('hidden Fury substitution') end
    Check(First(j.warriorAdaptive('target'))==nil,'Adaptive fails closed instead of redirecting')
end
-- The one valid Original dispatcher still selects its authored Arms/Fury branch.
for _,fury in ipairs({false,true}) do
    local s,j=Adaptive({fury=fury})
    j.warriorArms=function() return {{'Arms','Mortal Strike',true}} end
    j.warriorFury=function() return {{'Fury','Bloodthirst',true}} end
    Check(First(j.warriorUniversal('target'))==(fury and 'Bloodthirst' or 'Mortal Strike'),'Original owns its spec dispatcher')
    Check(j.warriorArmsPveMaintenance==s.oldMaintenance and j.WarriorThread3OwnsTarget==s.oldSweepingOwner,'Adaptive leaves explicit neighboring stages intact')
end
-- Compiled dispatch releases only to an explicit following placement, and holds waits.
for _,following in ipairs({false,true}) do
    local s,j,e=Wowsims({pvp=true});local c,run=Register(j,e,'warrior.wowsims',following)
    local held,action,later=run()
    Check(action==(following and 'Attack' or nil) and later==(following and 1 or 0),'only explicit thread order selects another placement')
    Check(held==following,'ineligible standalone placement releases ownership')
    local def=c.definitions['warrior.wowsims']
    Check(not Has(def,'pvp','Mortal Strike') and not def.stepByID.Bloodthirst and not def.stepByID.EquipDW,'no unrelated algorithm controls')
    for _,id in ipairs({'Sweeping Strikes','Whirlwind','Cleave','Slam','Mortal Strike'}) do Check(Has(def,'pve',id),'own WoWSims AoE action displayed: '..id) end
end
local s,j,e=Wowsims({casting=true});local c,run=Register(j,e,'warrior.wowsims',true)
local held,action,later=run();Check(held and action==nil and later==0,'eligible WoWSims cast wait never runs next placement')
s.casting=false;held,action,later=run();Check(action=='Slam' and later==0,'own eligible algorithm resumes after wait')
s,j,e=Adaptive();c,run=Register(j,e,'warrior.adaptive',false)
local def=c.definitions['warrior.adaptive']
for _,view in ipairs({'pve','pvp'}) do
    for _,id in ipairs({'Sweeping Strikes','Whirlwind','Cleave','Slam','Mortal Strike'}) do Check(Has(def,view,id),'own Adaptive branch displayed: '..view..'/'..id) end
end
Check(Has(def,'pvp','Equip2H'),'Adaptive PvP equipment preparation is displayed')
Check(not def.stepByID.Bloodthirst and not def.stepByID.EquipDW,'Adaptive excludes unrelated Fury controls')
for _,definition in ipairs(c.order) do
    if not definition.retired then
        for _,view in ipairs(definition.views) do for _,section in ipairs(view.sections) do
            Check(not section.label:find('fallback',1,true) and section.label~='Saved compatibility switches','no cross-routine menu section')
        end end
    end
end
local compatibility=c.variantIDs['warrior.arms'].adaptive[2]
Check(c.definitions[compatibility].functions==c.definitions['warrior.arms'].functions,'imported Arms mode cannot substitute Adaptive')
compatibility=c.variantIDs['warrior.original'].adaptive[2]
Check(c.definitions[compatibility].functions==c.definitions['warrior.adaptive'].functions and not c.definitions[compatibility].stepByID.Bloodthirst,'universal import uses selected algorithm metadata')
Check(not c:Add(3,'warrior.original.sweepingFallback'),'retired fallback cannot be added')
print('RoutineIsolation: '..checks..' routing, ownership, branch coverage and import checks passed (mocked client).')
