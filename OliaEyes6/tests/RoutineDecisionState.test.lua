-- Actual evaluators and compiled placement state; mocked client, Lua 5.1.
local function Read(path) local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local source=Read('tests/WarriorAdaptive.test.lua')
local Fixture=assert(loadstring(source:sub(1,assert(source:find('for count=1,10 do',1,true))-1)..'\nreturn Fixture'))()
local Attach=assert(loadfile('tests/RoutineConfigFixture.lua'))()
local checks=0
local function Check(ok,why) assert(ok,why);checks=checks+1 end
local function First(rows,action)
    for _,row in ipairs(rows) do if row[3] and (not action or row[2]==action) then return row[2] end end
end
local function Compiled(input,stepsA,stepsB)
    local s,j,e=Fixture(input)
    local threads={{},{},{},{},{},{},{}}
    threads[1]={{id='warrior.adaptive',steps=stepsA or {},options={adaptive_thunder_clap=true}}}
    threads[2]={{id='warrior.adaptive',steps=stepsB or {},options={adaptive_thunder_clap=false}}}
    e.OliaEyes6_Settings={characters={['Fixture - Realm']='isolation'},profiles={isolation={classes={WARRIOR={threads=threads,migrated=true}}}}}
    local c=Attach(j,e,'WARRIOR')
    local function Evaluate(thread)
        j.Engine.activeThread=thread;j.RoutineContext=c.plans[thread][1]
        local result=First(j.warriorAdaptive('target'))
        j.RoutineContext=nil
        return result
    end
    return s,j,c,Evaluate
end
local s,j,c,eval=Compiled({boss=true,rage=25,since=2})
Check(eval(1)=='Battle Stance','first placement prepares Thunder Clap')
s.stance=1
Check(eval(2)=='Berserker Stance','second placement has no inherited Thunder Clap hold')
Check(eval(1)=='Thunder Clap','first placement retains its preparation after second evaluates')
-- Same target inside the sampling throttle must not reuse another placement's count.
Check(c.plans[1][1].state~=c.plans[2][1].state,'separate compiled state identities')
s.enemies=3;s:event('NAME_PLATE_UNIT_ADDED','nameplate2');s:event('NAME_PLATE_UNIT_ADDED','nameplate3')
eval(1);Check(j.WarriorAdaptive.state.enemies==3,'first placement invalidated by nameplate events')
eval(2);Check(j.WarriorAdaptive.state.enemies==3,'second placement invalidated by nameplate events')
-- Success can be attributed to a different placement from the last evaluated one.
s.enemies=1;s.stance=3;s:event('NAME_PLATE_UNIT_REMOVED','nameplate2');s:event('NAME_PLATE_UNIT_REMOVED','nameplate3')
c:ResetDecisionState();Check(eval(1)=='Battle Stance','preparation restarts after lifecycle reset')
s.stance=1;eval(2)
j.CurrentCast={configEntry=c.plans[1][1],configRevision=c.revision,engineThread=1};j.Engine.activeThread=1
s:event('UNIT_SPELLCAST_SUCCEEDED','player','cast2','Thunder Clap')
Check(eval(1)=='Berserker Stance','cast event clears its recorded owner preparation')
-- Trinket intent dwell belongs to the placement, not the global Adaptive module.
s,j,c,eval=Compiled({trinket=true})
Check(eval(1)=='Trinkets','first placement begins bounded trinket attempt')
s.now=101.1
Check(eval(1)~='Trinkets','first placement exits failed attempt dwell')
Check(eval(2)=='Trinkets','second placement receives its own attempt dwell')
Check(eval(1)~='Trinkets','second attempt does not restart the first')
c:ResetDecisionState();Check(eval(1)=='Trinkets','thread/configuration lifecycle releases prospective retry state')
-- Independent masks must remove prospective Slam planning for just that placement.
s,j,c,eval=Compiled({rage=25,cd={['Mortal Strike']=4,Whirlwind=4}},nil,{Slam=false})
Check(eval(1)=='Slam','enabled placement plans funded Slam')
Check(eval(2)~='Slam' and not j.WarriorAdaptive.state.pendingSlam and not j.WarriorAdaptive.state.canSlam,'disabled placement has no prospective Slam')
Check(eval(1)=='Slam','disabled placement cannot erase enabled placement decision')
-- Preserve maintenance -> combat cooperation, scoped by thread/revision/behavior.
source=Read('tests/WarriorOptions.test.lua')
local Context=assert(loadstring(source:sub(1,assert(source:find('local function Snapshot(rows)',1,true))-1)..'\nreturn Context'))()
s={thread=1,stance=1,rage=80,cooldowns={['Mortal Strike']=true,Whirlwind=true,['Sweeping Strikes']=true}}
local e;j,e=Context(s);c=Attach(j,e,'WARRIOR')
j.Options.Refresh=function() end
c:SetStep(1,2,'Slam',false);c:SetStep(2,1,'Slam',false)
local maintenance=c.plans[1][1];local combat=c.plans[1][2]
local function Zerk(entry,thread)
    j.Engine.activeThread=thread or 1;j.RoutineContext=entry
    local active=First(j.warriorArms('target'),'Berserker Stance')
    j.RoutineContext=nil;return active
end
Check(Zerk(combat)=='Berserker Stance','combat otherwise returns to damage stance')
j.RoutineContext=maintenance;j.warriorArmsPveMaintenance('target');j.RoutineContext=nil
Check(Zerk(combat)==nil,'maintenance preparation holds Battle for compatible combat')
Check(Zerk(combat,2)=='Berserker Stance','handoff cannot leak into another physical thread')
Check(Zerk(c.plans[2][1],1)=='Berserker Stance','handoff cannot leak into another named behavior')
c.revision=c.revision+1
Check(Zerk(combat)=='Berserker Stance','handoff cannot survive a configuration revision')
c:ResetDecisionState()
Check(Zerk(combat)=='Berserker Stance','reset releases preparation hold')
print('RoutineDecisionState: '..checks..' checks passed (mocked client).')
