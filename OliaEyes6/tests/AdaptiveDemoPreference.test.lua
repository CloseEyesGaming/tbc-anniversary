-- Actual saved-profile migration and compiled Adaptive evaluator; mocked client.
local function Read(p) local f=assert(io.open(p));local s=f:read('*a');f:close();return s end
local src=Read('Tests/WarriorAdaptive.test.lua')
local Base=assert(loadstring(src:sub(1,assert(src:find('for count=1,10 do',1,true))-1)..'\nreturn Fixture'))()
local Attach=assert(loadfile('Tests/RoutineConfigFixture.lua'))()
local checks=0
local function Check(ok,why) assert(ok,why);checks=checks+1 end
local function Copy(v) if type(v)~='table' then return v end;local t={};for k,x in pairs(v) do t[k]=Copy(x) end;return t end
local function Class(pref,overrides,steps,version)
    return {migrated=true,routineBehaviorVersion=2,routineIsolationVersion=1,
        adaptiveDemoPreferenceVersion=version,options={adaptive_demo=pref},
        threads={{{id='warrior.adaptive',enabled=true,options=overrides or {},steps=steps or {}}},{},{},{},{},{},{}}}
end
local function Build(saved)
    local s,j,e=Base({moving=true,rage=25,cd={['Mortal Strike']=4,Whirlwind=4}})
    e.OliaEyes6_Settings=Copy(saved)
    local c=Attach(j,e,'WARRIOR');c.RefreshUI=function() end
    j.Engine.activeThread=1;j.RoutineContext=c.plans[1][1]
    return s,j,e,c
end
-- Matches the failure on disk: enabled action, empty placement options, enabled profile preference.
local saved={schemaVersion=1,routineSchemaVersion=3,classes={WARRIOR={adaptive_demo=true}},
    characters={['Fixture - Realm']='selected'},profiles={
        selected={classes={WARRIOR=Class(true),DRUID={untouched=true}}},
        unselected={classes={WARRIOR=Class(true,{sunderInitial=false,unknownPreference='retain'})}},
        explicitlyOff={classes={WARRIOR=Class(true,{adaptive_demo=false})}},
        falseProfile={classes={WARRIOR=Class(false)}},
        actionOff={classes={WARRIOR=Class(true,nil,{['Demoralizing Shout']=false})}},
        missingPreference={classes={WARRIOR=Class(nil)}},
        higherVersion={classes={WARRIOR=Class(true,nil,nil,4)}}}}
local s,j,e,c=Build(saved)
Check(c.plans[1][1].options.adaptive_demo==true,'enabled profile Demo preference must reach compiled Adaptive placement')
Check(s:action()=='Demoralizing Shout','previously failing profile selects Demo while moving')
for _,name in ipairs({'selected','unselected'}) do
    local settings=e.OliaEyes6_Settings.profiles[name].classes.WARRIOR
    Check(settings.threads[1][1].options.adaptive_demo==true,'import across every profile')
    Check(settings.adaptiveDemoPreferenceVersion==1,'one-time preference migration recorded')
end
local profiles=e.OliaEyes6_Settings.profiles
Check(profiles.explicitlyOff.classes.WARRIOR.threads[1][1].options.adaptive_demo==false,'explicit placement false preserved')
Check(profiles.falseProfile.classes.WARRIOR.threads[1][1].options.adaptive_demo==false,'profile false imported exactly')
Check(profiles.actionOff.classes.WARRIOR.threads[1][1].steps['Demoralizing Shout']==false,'disabled action remains disabled')
Check(profiles.unselected.classes.WARRIOR.threads[1][1].options.sunderInitial==false and profiles.unselected.classes.WARRIOR.threads[1][1].options.unknownPreference=='retain','unrelated preferences preserved')
Check(profiles.missingPreference.classes.WARRIOR.threads[1][1].options.adaptive_demo==nil,'missing preference keeps authored default')
Check(profiles.higherVersion.classes.WARRIOR.adaptiveDemoPreferenceVersion==4 and profiles.higherVersion.classes.WARRIOR.threads[1][1].options.adaptive_demo==nil,'higher migration version preserved')
Check(profiles.selected.classes.DRUID.untouched,'class isolation')
-- Reload does not reapply an old enabled preference over the user's later explicit off.
c:SetOption(1,1,'adaptive_demo',false)
local reload=e.OliaEyes6_Settings
local s2,j2,e2,c2=Build(reload)
Check(c2.plans[1][1].options.adaptive_demo==false,'reload migration is idempotent and preserves later false')
Check(s2:action()~='Demoralizing Shout','later disabled Demo remains disabled after reload')
-- New Add/Reset behavior remains the authored off default after the one-time import.
c2:ResetThread(1)
c2:GetThreads()[1]={{id='warrior.adaptive',options={},steps={}}};c2:Compile()
Check(c2.plans[1][1].options.adaptive_demo==false,'new empty placement uses default after migration')
-- A disabled saved action cannot be revived by importing its support preference.
local off=Copy(saved);off.characters['Fixture - Realm']='actionOff'
local so,jo,eo,co=Build(off)
Check(co.plans[1][1].options.adaptive_demo and not co.plans[1][1].actions['Demoralizing Shout'],'import preserves effective action-off state')
jo.RoutineContext=co.plans[1][1];Check(so:action()~='Demoralizing Shout','disabled action never executes')
-- One-shot diagnostics read saved/active flags and last decisions without running an evaluator.
local lines={};e.print=function(line) lines[#lines+1]=line end
j.RoutineContext=nil;j.warriorAdaptive=function() error('diagnostic must not evaluate') end
j.WarriorAdaptive:PrintDemoDiagnostics()
local output=table.concat(lines,'\n')
Check(output:find('profile%-import%-1') and output:find('action=true') and output:find('option=false'),'diagnostic reports loaded revision and actual compiled flags')
Check(j.RoutineContext==nil,'diagnostic leaves evaluation context alone')
local main=Read('Main.lua');main='local AddonName,jungle=...\n'..main:sub((assert(main:find('SLASH_OLIA1 = "/olia"',1,true))))
setfenv(assert(loadstring(main)),e)('OliaEyes6',j)
lines={};e.SlashCmdList.OLIA('demo');Check(#lines>0,'slash command reaches one-shot diagnostic')
print('Adaptive Demo preference: '..checks..' exact-profile, migration, false-preservation, reload and diagnostic checks passed (mocked client).')
