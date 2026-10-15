-- Actual evaluators and compiled placements; mocked client, no live cast claim.
local function Read(path) local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local src=Read('Tests/WarriorAdaptive.test.lua')
src=src:sub(1,assert(src:find('for count=1,10 do',1,true))-1)
-- Keep the actual Warrior aura helpers instead of the broad fixture's support stubs.
src=src:gsub('    j%.WarriorAdaptiveContext%.hasAttackPowerDebuff = function%(%) return s%.demo or false end','')
src=src:gsub("    j%.WarriorAdaptiveContext%.debuffRemaining = function%(%) return s%.thunder or 0 end",'')
local Base=assert(loadstring(src..'\nreturn Fixture'))()
local Attach=assert(loadfile('Tests/RoutineConfigFixture.lua'))()
local checks=0
local function Check(ok,why) assert(ok,why);checks=checks+1 end
local function Fixture(args,options,steps)
    args=args or {};args.rage=args.rage or 25
    args.costs=args.costs or {};args.costs['Demoralizing Shout']=10
    args.cd=args.cd or {['Mortal Strike']=4,Whirlwind=4}
    local s,j,e=Base(args)
    local c=Attach(j,e,'WARRIOR');c.RefreshUI=function() end
    local opts={adaptive_demo=true}
    for k,v in pairs(options or {}) do opts[k]=v end
    for _,thread in ipairs({2,5}) do
        local copyOpts={};for k,v in pairs(opts) do copyOpts[k]=v end
        local copySteps={};for k,v in pairs(steps or {}) do copySteps[k]=v end
        c:GetThreads()[thread]={{id='warrior.adaptive',steps=copySteps,options=copyOpts}}
    end
    c:Compile()
    function s:run(thread)
        thread=thread or 2;j.Engine.activeThread=thread;j.RoutineContext=c.plans[thread][1]
        return self:action()
    end
    return s,j,e,c
end
for _,thread in ipairs({2,5}) do
    local s,j=Fixture({moving=true})
    Check(s:run(thread)=='Demoralizing Shout','moving unknown-lifetime single NPC uses enabled Demo')
    Check(j.RoutineContext.options.adaptive_demo and j.RoutineContext.actions['Demoralizing Shout'],'both overlay switches compiled enabled')
    Check(j.WarriorAdaptive.state.pendingSlam,'test actually has a pending swing')
    s,j=Fixture({since=2})
    Check(s:run(thread)=='Demoralizing Shout','stationary unknown-lifetime target outside Slam window')
    s.now=102;s.hp=10000
    Check(s:run(thread)=='Demoralizing Shout','short known lifetime does not silently disable Demo')
    s,j=Fixture({boss=true,moving=true})
    Check(s:run(thread)=='Demoralizing Shout','moving boss does not reserve an unusable Slam')
    s,j=Fixture({noSlam=true})
    Check(s:run(thread)=='Demoralizing Shout','unavailable Slam releases Demo')
    s,j=Fixture({rage=10})
    Check(s:run(thread)=='Demoralizing Shout','unfunded Slam does not reserve a funded Demo')
    s,j=Fixture({boss=true})
    Check(s:run(thread)=='Slam','funded stationary ready Slam retains its window')
    s,j=Fixture({},nil,{Slam=false})
    Check(s:run(thread)=='Demoralizing Shout','disabled Slam releases Demo')
    for _,remaining in ipairs({5,1}) do
        s,j=Fixture({moving=true,auras={{'Demoralizing Shout',0,remaining}}})
        Check(s:run(thread)=='Demoralizing Shout','Demo refresh at <=5 seconds')
    end
    for _,remaining in ipairs({6,20,0}) do
        s,j=Fixture({moving=true,auras={{'Demoralizing Shout',0,remaining>0 and remaining or nil}}})
        Check(s:run(thread)~='Demoralizing Shout','healthy/permanent Demo does not refresh')
    end
    for _,aura in ipairs({'Demoralizing Roar','Curse of Weakness','Screech'}) do
        s,j=Fixture({moving=true,auras={{aura,0,20}}})
        Check(s:run(thread)~='Demoralizing Shout','alternative AP debuff suppresses Demo: '..aura)
    end
    s,j=Fixture({enemies=3,moving=true})
    Check(s:run(thread)=='Demoralizing Shout','eligible AoE coverage')
    s,j=Fixture({enemies=3,moving=true,excluded={nameplate2=true}})
    Check(s:run(thread)~='Demoralizing Shout','excluded nearby enemy blocks offensive area shout')
    for _,args in ipairs({{rage=5},{gcd=1},{casting=true},{channel=true},{mounted=true},{lost=true},{friendly=true},{targetDead=true},{totem=true,totems={target=true}},{unknown={['Demoralizing Shout']=true}},{cd={['Demoralizing Shout']=4}}}) do
        args.moving=true;s,j=Fixture(args)
        Check(s:run(thread)~='Demoralizing Shout','target, cast, rage, GCD, capability and cooldown guards')
    end
end
-- Real configuration methods preserve independent action/option switches and placements.
do
    local s,j,e,c=Fixture({moving=true})
    Check(s:run(2)=='Demoralizing Shout' and s:run(5)=='Demoralizing Shout','both placements initially enabled')
    c:SetStep(2,1,'Demoralizing Shout',false)
    Check(s:run(2)~='Demoralizing Shout' and s:run(5)=='Demoralizing Shout','disabled action is placement-specific')
    c:SetStep(2,1,'Demoralizing Shout',true)
    Check(s:run(2)=='Demoralizing Shout','action re-enable restores Demo')
    c:SetOption(2,1,'adaptive_demo',false)
    Check(s:run(2)~='Demoralizing Shout' and s:run(5)=='Demoralizing Shout','false option survives compile and remains placement-specific')
    c:SetOption(2,1,'adaptive_demo',true)
    Check(s:run(2)=='Demoralizing Shout','option re-enable restores Demo')
end
-- The shared AP predicates retain all-debuff behavior for Original callers.
do
    for _,aura in ipairs({'Demoralizing Shout','Demoralizing Roar','Curse of Weakness','Screech'}) do
        local s,j=Fixture({auras={{aura,0,20}}})
        Check(j.WarriorAdaptiveContext.hasAttackPowerDebuff('target'),'Original sees all existing AP debuffs')
    end
end
print('Adaptive PvE Demo: '..checks..' enabled-setting, movement, lifetime, Slam, aura, readiness and placement checks passed (mocked client).')
