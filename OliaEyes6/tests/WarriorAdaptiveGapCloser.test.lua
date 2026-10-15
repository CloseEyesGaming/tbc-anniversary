-- Actual Adaptive/Original utilities with matched legacy and modern API mocks.
-- Standalone Lua 5.1 suite; never loaded by the production TOC.
local function Read(path) local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local source=Read('Tests/WarriorAdaptivePvp.test.lua')
local boundary=assert(source:find('local noUtilities={}',1,true))
local BaseFixture,Mask=assert(loadstring(source:sub(1,boundary-1)..'\nreturn Fixture,Mask'))()
local Attach=assert(loadfile('Tests/RoutineConfigFixture.lua'))()
local function Fixture(args)
    local s,j,e=BaseFixture(args)
    local oldChannel=e.UnitChannelInfo
    e.UnitChannelInfo=function(unit)
        if unit=='player' and s.channel then return 'Channel' end
        return oldChannel(unit)
    end
    Attach(j,e,'WARRIOR')
    return s,j,e
end
local checks=0
local function Check(ok,why) assert(ok,why);checks=checks+1 end
local cases={
    {name='Charge in Battle',outOfCombat=true,stance=1,expected='Charge'},
    {name='Charge preparation',outOfCombat=true,stance=2,expected='Battle Stance'},
    {name='Berserker rage prefers Intercept',outOfCombat=true,stance=3,rage=10,expected='Intercept'},
    {name='low rage prepares Charge',outOfCombat=true,stance=3,rage=5,expected='Battle Stance'},
    {name='combat Intercept preparation',stance=1,expected='Berserker Stance'},
    {name='combat Intercept',stance=3,expected='Intercept'},
    {name='Charge cooldown out of combat',outOfCombat=true,stance=1,cd={Charge=4},expected='Berserker Stance'},
    {name='Intercept cooldown permits Charge',outOfCombat=true,stance=3,cd={Intercept=4},expected='Battle Stance'},
    {name='recent Charge protects engagement',stance=3,cd={Charge=9}},
    {name='Charge protection expires',stance=3,cd={Charge=7},expected='Intercept'},
    {name='both on cooldown',stance=3,cd={Charge=4,Intercept=4}},
    {name='insufficient Intercept rage',stance=3,rage=5},
    {name='unknown Intercept',stance=3,unknown={Intercept=true}},
    {name='unknown Charge falls to Intercept',outOfCombat=true,stance=3,unknown={Charge=true},expected='Intercept'},
    {name='masked Charge and Intercept',stance=3,steps={Charge=false,Intercept=false}},
    {name='masked Charge preparation',outOfCombat=true,stance=2,steps={['Battle Stance']=false}},
    {name='masked Intercept preparation',stance=1,steps={['Berserker Stance']=false}},
}
for _,pvp in ipairs({false,true}) do
    for _,thread in ipairs({2,5}) do
        for _,case in ipairs(cases) do
            local args={pvp=pvp,thread=thread,outOfRange=true}
            for key,value in pairs(case) do args[key]=value end
            local s,j,e=Fixture(args)
            Mask(j,case.steps or {})
            local scratch={}
            local result=j.WarriorAdaptiveContext.gapCloser('target',pvp and j.ReadyCastSpell or nil,scratch)
            Check(result==scratch,'reusable result identity')
            local expected=result.useCharge and 'Charge'
                or result.useBattleStanceForCharge and 'Battle Stance'
                or result.useIntercept and 'Intercept'
                or result.useBerserkerStanceForIntercept and 'Berserker Stance' or nil
            Check(expected==case.expected,case.name..' helper expectation')
            local action=s:action()
            if expected then
                Check(action==expected,case.name..' Adaptive matches Original in '..(pvp and 'PvP' or 'PvE'))
            else
                Check(action~='Charge' and action~='Intercept',case.name..' no ineligible gap closer')
                if not pvp then
                    local reason=j.WarriorAdaptive.state.reason
                    Check(reason~='charge_stance' and reason~='intercept_stance',case.name..' no hidden preparation')
                end
            end
            s.mounted=true
            local mountedAction=s:action()
            Check(mountedAction==expected,case.name..' mounted gap-only decision matches Original')
            s.lost=true
            Check(s:action()==nil,'mounted target loss removes all actions')
        end
    end
    for _,value in ipairs({'nil','false','melee'}) do
        local s,j,e=Fixture({pvp=pvp,outOfRange=value~='melee',stance=3})
        if value~='melee' then
            local old=e.C_Spell.IsSpellInRange
            e.C_Spell.IsSpellInRange=function(name,unit)
                if name=='Charge' or name=='Intercept' then
                    if value=='nil' then return nil end
                    return false
                end
                return old(name,unit)
            end
        end
        local scratch={useCharge=true,useIntercept=true,useBattleStanceForCharge=true,useBerserkerStanceForIntercept=true}
        j.WarriorAdaptiveContext.gapCloser('target',nil,scratch)
        Check(not scratch.wantCharge and not scratch.wantIntercept,'range requires explicit true outside melee')
        Check(not scratch.useCharge and not scratch.useIntercept and not scratch.useBattleStanceForCharge and not scratch.useBerserkerStanceForIntercept,'scratch resets all stale preparation')
        local action=s:action()
        Check(action~='Charge' and action~='Intercept','invalid/outside-gap/melee range never emits gap closer')
    end
end
-- Mounted gap closers precede equipment; ordinary combat/support never starts from travel.
for _,pvp in ipairs({false,true}) do
    local s,j=Fixture({pvp=pvp,mounted=true,noWeapon=true,outOfRange=true,outOfCombat=true,stance=1})
    Mask(j,{})
    Check(s:action()=='Charge','mounted Charge does not wait for equipment')
    for _,guard in ipairs({'casting','channel','dead','lost','friendly','targetDead'}) do
        s,j=Fixture({pvp=pvp,mounted=true,outOfRange=true,outOfCombat=true,stance=1,[guard]=true})
        Mask(j,{})
        Check(s:action()==nil,'mounted gap guards: '..guard)
    end
    s,j=Fixture({pvp=pvp,mounted=true,noShout=true,noAttack=true,stance=3})
    Mask(j,{})
    Check(s:action()==nil,'mounted melee does not start combat, equipment or maintenance')
end
-- Each placement's switches govern the shared helper; reusable scratch stores no plan.
do
    local s,j=Fixture({pvp=false,outOfRange=true,outOfCombat=true,stance=1})
    local a={mode='adaptive',policy=2,state={},allEnabled=false,actions={Charge=false,Intercept=false},options={}}
    local b={mode='adaptive',policy=2,state={},allEnabled=true,actions={},options={}}
    j.RoutineContext=a;Check(s:action()~='Charge','disabled placement')
    j.RoutineContext=b;Check(s:action()=='Charge','enabled placement remains independent')
    j.RoutineContext=a;Check(s:action()~='Charge','disabled placement does not reuse enabled scratch')
    a.actions.Charge=true;Check(s:action()=='Charge','re-enabled action restores decision')
end
print('Adaptive gap closers: '..checks..' PvE/PvP parity, range, cooldown, masks and target-transition checks passed (mocked client).')
