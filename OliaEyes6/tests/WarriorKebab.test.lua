-- Lua 5.1. Real Kebab evaluator, schema/catalog and binding registries; mocked client.
local checks=0
local function Check(ok,why) assert(ok,why);checks=checks+1 end
local function Read(path) local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local function First(rows) for _,row in ipairs(rows) do if row[3] then return row[2] end end end
local actualOptions=Read('tests/WarriorOptions.test.lua')
local base=assert(loadstring(actualOptions:sub(1,assert(actualOptions:find('local function Snapshot(rows)',1,true))-1)..'\nreturn Context'))()
local Attach=assert(loadfile('tests/RoutineConfigFixture.lua'))()
local function Fixture(s)
    s=s or {};s.now=s.now or 100;s.rage=s.rage or 50;s.stance=s.stance or 3
    local j,e=base(s)
    local known={['Mortal Strike']=true,Whirlwind=true,Execute=true,['Heroic Strike']=true,Cleave=true,Hamstring=true,
        ['Berserker Stance']=true,['Battle Stance']=true,Pummel=true,Charge=true,Intercept=true,
        ['Sunder Armor']=true,['Demoralizing Shout']=true,['Battle Shout']=true,['Commanding Shout']=true}
    local cost={['Mortal Strike']=30,Whirlwind=25,Execute=15,['Sweeping Strikes']=30,['Heroic Strike']=15,Cleave=20,Hamstring=10,
        ['Sunder Armor']=15,['Demoralizing Shout']=10,['Battle Shout']=10,['Commanding Shout']=10,['Death Wish']=10}
    local frames={}
    e.CreateFrame=function() local f={scripts={}};function f:RegisterEvent() end;function f:SetScript(event,fn) self.scripts[event]=fn end;frames[#frames+1]=f;return f end
    e.GetTime=function() return s.now end
    e.IsInInstance=function() return true,s.instance or 'raid' end
    e.IsMounted=function() return s.mounted or false end
    e.UnitExists=function(unit) return unit=='player' or unit=='target' and not s.lost or unit=='nameplate1' or unit=='nameplate2' and s.second or false end
    e.UnitCanAttack=function(_,unit) assert(unit and e.UnitExists(unit),'invalid enemy read');return not s.friendly and unit~='player' end
    e.UnitIsDeadOrGhost=function(unit) return unit=='player' and s.dead or unit=='target' and s.targetDead or false end
    e.UnitIsPlayer=function(unit) return unit=='player' or s.pvp or false end
    e.UnitPlayerControlled=function() return s.controlled or false end
    e.UnitGUID=function(unit) assert(unit and e.UnitExists(unit));return (unit=='target' or unit=='nameplate1') and 'enemy1' or 'enemy2' end
    e.UnitHealthMax=function(unit) assert(unit and e.UnitExists(unit));return s.maxHP or 100000 end
    e.UnitHealth=function(unit) assert(unit and e.UnitExists(unit));return s.hp or (s.execute and 10000 or 90000) end
    e.UnitAffectingCombat=function() return not s.outOfCombat end
    e.UnitAttackSpeed=function() return s.mainhand or 2.6,not s.noDW and 1.5 or nil end
    e.GetShapeshiftForm=function() return s.stance end
    e.UnitClassification=function() return s.boss and 'worldboss' or 'normal' end
    e.UnitLevel=function() return s.boss and -1 or 70 end
    e.UnitCastingInfo=function(unit) return unit=='player' and s.casting and 'Cast' or nil end
    e.UnitChannelInfo=function(unit) return unit=='player' and s.channel and 'Channel' or nil end
    e.GetSpellBookItemInfo=function(name)
        if s.unknown and s.unknown[name] then return nil end
        return (known[name] or s.learned and s.learned[name]) and 'SPELL' or nil
    end
    e.C_Spell.GetSpellPowerCost=function(name) local c=s.costs and s.costs[name] or cost[name] or 0;return {{type=1,cost=c,minCost=c,requiredAuraID=0}} end
    e.C_Spell.GetSpellCooldown=function(name)
        if s.missingCD==name then return nil end
        if s.disabledCD==name then return {startTime=0,duration=0,isEnabled=false} end
        local cd=s.cd and s.cd[name] or 0
        if cd>0 then return {startTime=s.now+cd-10,duration=10,isEnabled=true} end
        if (s.gcd or 0)>0 then return {startTime=s.now+s.gcd-1.5,duration=1.5,isEnabled=true} end
        return {startTime=0,duration=0,isEnabled=true}
    end
    e.C_Spell.IsSpellUsable=function(name)
        if s.blocked and s.blocked[name] then return false,false end
        if name=='Whirlwind' and s.stance~=3 then return false,false end
        local short=s.rage<(s.costs and s.costs[name] or cost[name] or 0)
        return not short,short
    end
    e.C_Spell.IsSpellInRange=function(_,unit) assert(unit and e.UnitExists(unit));return not s.outOfRange end
    e.C_Spell.IsCurrentSpell=function(name) return name==6603 and not s.noAttack or name==s.queued end
    j.inMeleeRange=function(unit) assert(unit and e.UnitExists(unit));return not s.outOfRange end
    j.GetGCDValues=function() return (s.gcd or 0)>0 and s.now+s.gcd-1.5 or 0,(s.gcd or 0)>0 and 1.5 or 0 end
    j.IsTotemUnit=function(unit) return s.totem and unit=='target' end
    j.IsEnemyNameplateEligibleForAoE=function(unit) return not (s.excluded and unit=='nameplate2') end
    j.checkPveInterrupt=function() return s.interrupt end
    j.GetWarriorDpsShout=function() return s.commanding and 'Commanding Shout' or 'Battle Shout',s.noShout or false end
    j.unitCacheBuff=function(_,name) return s.buffs and s.buffs[name] or false end
    j.AreTrinketsReady=function() return s.trinket end
    j.SwingTimer={
        IsMainhandTimingReliable=function() return not s.unreliable end,
        GetMainhandTimeRemaining=function() return s.swing or 0.3 end,
        GetLastConfirmedMainhandSwingTime=function() return not s.unconfirmed and (s.cycle or 99) or nil end,
        GetLastConfirmedMainhandSwingTargetGUID=function() return s.swingTarget or 'enemy1' end,
        GetOffhandTimeRemaining=function() error('Kebab must not read the OH timer') end,
        RegisterMainhandSwingCallback=function(self,fn) self.onMH=fn end,
    }
    local sharedWarriorUtility=j.WarriorAdaptiveContext
    j.WarriorAdaptiveContext={
        hasTwoHand=function() return s.twoHand end,
        armorDebuff=function() return s.sunder or 0,s.stacks or 0,s.expose or 0 end,
        canDebuff=function() return not s.totem end,
        hasOtherAttackPowerDebuff=function() return s.otherAP end,
        debuffRemaining=function() return s.demo or 0 end,
        gapCloser=function(_,_,out)
            out.useCharge=s.outOfRange and s.outOfCombat and j.RoutineAllows('Charge') and s.stance==1
            out.useBattleStanceForCharge=s.outOfRange and s.outOfCombat and j.RoutineAllows('Charge') and s.stance~=1
            out.useIntercept=s.outOfRange and not s.outOfCombat and j.RoutineAllows('Intercept') and s.stance==3
            out.useBerserkerStanceForIntercept=s.outOfRange and not s.outOfCombat and j.RoutineAllows('Intercept') and s.stance~=3
        end,
    }
    if s.sharedDebuffs then
        for _,key in ipairs({'canDebuff','hasOtherAttackPowerDebuff','debuffRemaining','armorDebuff'}) do
            j.WarriorAdaptiveContext[key]=sharedWarriorUtility[key]
        end
    end
    setfenv(assert(loadfile('Routines/WarriorKebab.lua')),e)('OliaEyes6',j)
    -- Load real action identities; bar creation stays outside this fixture.
    local hotkeys=Read('Core/Hotkeys.lua');hotkeys=hotkeys:sub(1,assert(hotkeys:find('function Hotkeys:CreateStaticBar()',1,true))-1)
    setfenv(assert(loadstring(hotkeys)),e)('OliaEyes6',j)
    local c=Attach(j,e,'WARRIOR')
    j.Options.Refresh=function() end -- UI callbacks are covered by RoutineUI/RoutineViews.
    Check(c.definitions['warrior.kebab'] and not c.definitions['warrior.kebab'].validationError,'real registry/bindings accept Kebab')
    c:GetThreads()[2]={{id='warrior.kebab',steps=s.steps or {},options=s.options or {}}};c:Compile()
    local entry=c.plans[2][1]
    local function Evaluate()
        j.RoutineContext=entry
        local result=j.warriorKebab(s.lost and nil or 'target')
        local action=First(result)
        if action then Check(entry.definition.stepByID[action]~=nil,'eligible action declared: '..action) end
        return action,result,entry
    end
    return s,j,e,c,entry,Evaluate,frames
end
local function Expect(input,want,why) local _,_,_,_,_,run=Fixture(input);local action=run();Check(action==want,why..': '..tostring(action));return action end
Expect({rage=50},'Mortal Strike','ready MS precedes new HS admission')
Expect({rage=44},'Mortal Strike','core funding blocks low HS')
Expect({rage=40,steps={['Mortal Strike']=false}},'Whirlwind','WW reservation remains when MS disabled')
Expect({rage=30,steps={['Heroic Strike']=false}},'Mortal Strike','MS wins simultaneous core readiness')
Expect({rage=30,cd={['Mortal Strike']=1}},'Whirlwind','available WW does not wait for imminent MS')
Expect({rage=70,gcd=1},'Heroic Strike','off-GCD queue during a locked global')
Expect({rage=44,gcd=1},nil,'GCD core cannot consume queue tick')
Expect({rage=44,queued='Heroic Strike'},'Mortal Strike','ordinary HS queue does not reserve rage against a ready core')
Expect({rage=80,queued='Cleave'},'Stopcasting','cancel carried AoE queue')
Expect({rage=80,queued='Heroic Strike',steps={['Heroic Strike']=false}},'Stopcasting','disabling HS preserves required cleanup')
Expect({rage=80,queued='Heroic Strike'},'Mortal Strike','funded existing HS survives core selection')
Expect({rage=50,steps={['Heroic Strike']=false},cd={['Mortal Strike']=3,Whirlwind=3}},'Hamstring','funded safe filler')
Expect({rage=39,steps={['Heroic Strike']=false},cd={['Mortal Strike']=3,Whirlwind=3}},nil,'filler preserves resource reserve')
Expect({rage=95,steps={['Heroic Strike']=false},cd={['Mortal Strike']=0.8,Whirlwind=3}},nil,'aggressive filler held by default')
Expect({rage=95,steps={['Heroic Strike']=false},cd={['Mortal Strike']=0.8,Whirlwind=3},options={aggressive_filler=true}},nil,'retired cap exception cannot shorten the full core gap')
Expect({rage=80,steps={['Heroic Strike']=false},cd={['Mortal Strike']=0.8,Whirlwind=3},options={aggressive_filler=true}},nil,'cap filler needs high current rage')
Expect({rage=95,steps={['Heroic Strike']=false},cd={['Mortal Strike']=0.5,Whirlwind=3},options={aggressive_filler=true}},nil,'cap filler still protects too-close core')
Expect({rage=50,execute=true},'Whirlwind','funded Execute WW retains minimum Execute funding')
Expect({rage=30,execute=true},'Execute','Execute wins when WW cannot retain funding')
Expect({rage=80,execute=true,options={execute_ww=false}},'Execute','Execute MS held by default')
Expect({rage=80,execute=true,options={execute_ms=true}},'Mortal Strike','explicit funded Execute MS')
Expect({rage=80,execute=true,queued='Heroic Strike'},'Stopcasting','cancel HS on Execute entry')
Expect({rage=80,execute=true,options={execute_hs=true}},'Heroic Strike','explicit funded Execute HS')
Expect({rage=55,execute=true,options={execute_hs=true}},'Whirlwind','Execute HS cannot consume funded WW plus Execute reserve')
Expect({rage=80,execute=true,steps={Execute=false}},'Mortal Strike','disabled Execute releases phase reservations')
Expect({rage=50,execute=true,maxHP=0},'Mortal Strike','unknown health never becomes Execute')
Expect({rage=50,blocked={['Heroic Strike']=true}},'Mortal Strike','explicit false usability fails closed')
Expect({rage=50,missingCD='Mortal Strike'},'Whirlwind','unknown core CD not admitted or reserved')
Expect({rage=25,disabledCD='Whirlwind',steps={['Mortal Strike']=false,['Heroic Strike']=false}},'Hamstring','disabled cooldown is not ready')
Expect({rage=50,costs={['Heroic Strike']=25}},'Mortal Strike','actual queue cost adjusts funding')
Expect({rage=80,costs={Execute=10},execute=true,options={execute_ww=false}},'Execute','actual Execute minimum cost')
Expect({rage=50,noAttack=true},'Attack','normal autoattack start')
Expect({rage=50,stance=1},'Berserker Stance','damage stance preparation')
Expect({rage=50,interrupt=true},'Pummel','interrupt before queue/core')
Expect({rage=50,interrupt=true,stance=1},'Berserker Stance','interrupt stance preparation')
Expect({rage=50,interrupt=true,steps={Pummel=false}},'Mortal Strike','disabled Pummel removes preparation')
Expect({rage=50,outOfRange=true},'Intercept','gap closer owns out-of-range action')
Expect({rage=50,outOfRange=true,steps={Intercept=false}},nil,'disabled gap closer releases')
Expect({rage=50,outOfRange=true,outOfCombat=true,stance=1},'Charge','out-of-combat Charge')
Expect({rage=50,outOfRange=true,outOfCombat=true},'Battle Stance','Charge stance preparation')
Expect({rage=50,outOfRange=true,outOfCombat=true,steps={Charge=false}},nil,'disabled Charge removes stance preparation')
Expect({cd={['Mortal Strike']=3,Whirlwind=3},rage=50,noShout=true},'Battle Shout','maintain selected shout')
Expect({cd={['Mortal Strike']=3,Whirlwind=3},rage=50,noShout=true,commanding=true},'Commanding Shout','dynamic shout alternative declared')
Expect({rage=50,lost=true,noShout=true},'Battle Shout','targetless shout without absent enemy reads')
Expect({rage=50,friendly=true,noShout=true},'Battle Shout','friendly context retains self maintenance')
for _,field in ipairs({'pvp','controlled','dead','mounted','noDW','twoHand','totem','targetDead'}) do
    local case={rage=80};case[field]=true;Expect(case,nil,'ineligible context '..field)
end
Expect({rage=80,learned={Bloodthirst=true}},nil,'Bloodthirst builds excluded')
Expect({rage=80,instance='arena'},nil,'arena instance excluded regardless of target')
Expect({rage=80,casting=true},nil,'active cast protected')
Expect({rage=80,channel=true},nil,'active channel protected')
do local s,j,e,c,entry,run,frames=Fixture({rage=80,second=true});frames[1].scripts.OnEvent(nil,'NAME_PLATE_UNIT_ADDED','nameplate2');Check(run()=='Cleave' and j.WarriorKebab:Hold(),'multiple eligible enemies run owned AoE') end
do local s,j,e,c,entry,run,frames=Fixture({rage=30,second=true,excluded=true,steps={['Mortal Strike']=false,['Heroic Strike']=false}});frames[1].scripts.OnEvent(nil,'NAME_PLATE_UNIT_ADDED','nameplate2');Check(run()=='Hamstring','excluded nearby enemy blocks WW while direct filler remains possible');frames[1].scripts.OnEvent(nil,'NAME_PLATE_UNIT_REMOVED','nameplate2');Check(run()=='Whirlwind','removal restores safe WW') end
Expect({cd={['Mortal Strike']=3,Whirlwind=3},rage=82,learned={Bloodrage=true}},'Bloodrage','proactive Bloodrage at high but fundable rage')
Expect({rage=95,learned={Bloodrage=true}},'Mortal Strike','do not overflow Bloodrage')
Expect({cd={['Mortal Strike']=3,Whirlwind=3},rage=80,learned={['Death Wish']=true}},'Death Wish','automatic learned cooldown')
Expect({rage=80,learned={['Death Wish']=true},options={burst_lust=true}},'Mortal Strike','optional Bloodlust hold')
Expect({cd={['Mortal Strike']=3,Whirlwind=3},rage=80,learned={['Death Wish']=true},options={burst_lust=true},buffs={Bloodlust=true}},'Death Wish','observed Bloodlust releases cooldown')
Expect({rage=80,learned={Recklessness=true},boss=true},'Mortal Strike','long cooldown held by default')
Expect({cd={['Mortal Strike']=3,Whirlwind=3},rage=80,learned={Recklessness=true},boss=true,options={recklessness=true}},'Recklessness','explicit boss long cooldown')
Expect({rage=80,learned={Recklessness=true},options={recklessness=true}},'Mortal Strike','ordinary enemy cannot consume long cooldown')
Expect({rage=80,options={sunder_initial=true}},'Sunder Armor','explicit first Sunder assignment')
Expect({rage=80,options={sunder_stack=true}},'Sunder Armor','Stack mode independently applies the first stack')
Expect({rage=80,stacks=2,sunder=20,options={sunder_stack=true}},'Mortal Strike','healthy extra Sunder stacks do not preempt new dump/core actions')
Expect({rage=80,expose=20,options={sunder_initial=true}},'Mortal Strike','Expose Armor suppresses Sunder')
Expect({rage=50,steps={['Heroic Strike']=false,Hamstring=false},cd={['Mortal Strike']=3,Whirlwind=3},options={demo=true}},'Demoralizing Shout','assigned funded Demo gap')
Expect({rage=50,steps={['Heroic Strike']=false,Hamstring=false},cd={['Mortal Strike']=3,Whirlwind=3},options={demo=true},otherAP=true},nil,'other AP debuff suppresses Demo')
Expect({rage=50,steps={['Heroic Strike']=false},cd={['Mortal Strike']=3,Whirlwind=3},options={demo=true}},'Demoralizing Shout','assigned Demo cannot be starved by paid filler')
Expect({rage=50,steps={['Heroic Strike']=false},cd={['Mortal Strike']=3,Whirlwind=3},learned={['Victory Rush']=true}},'Victory Rush','free filler precedes paid filler')
Expect({rage=25,steps={['Heroic Strike']=false,Hamstring=false},cd={['Mortal Strike']=3,Whirlwind=3},learned={['Berserker Rage']=true},options={berserker_rage=true}},'Berserker Rage','explicit spare-global utility')
Expect({rage=40,steps={['Heroic Strike']=false,['Mortal Strike']=false,Whirlwind=false}},'Hamstring','disabled cores leave no phantom rage reserve')
do
    local s,j,e,c,entry,run=Fixture({rage=80,trinket=true,cd={['Mortal Strike']=3,Whirlwind=3}})
    Check(run()=='Trinkets','trinket first attempt');s.now=s.now+0.2;Check(run()=='Heroic Strike','failed trinket cannot starve core');s.now=s.now+5;Check(run()=='Trinkets','bounded trinket retry')
end
do
    local s,j,e,c,entry,run=Fixture({rage=80})
    local action,result=run();Check(action=='Mortal Strike','target present first decision');s.lost=true;local _,after=run();for _,row in ipairs(result) do Check(not row[3],'target loss clears stale eligibility') end
    s.lost=false;Check(run()=='Mortal Strike','reacquisition rebuilds decisions')
    Check(#result==#c.rows['Warrior.kebab'].rows,'evaluator/schema row parity')
    for i,row in ipairs(result) do Check(row[2]==c.rows['Warrior.kebab'].rows[i][2],'schema action order parity') end
    local allowed={};for _,step in ipairs(entry.definition.steps) do allowed[step.id]=true end
    for _,view in ipairs(entry.definition.views) do for _,section in ipairs(view.sections) do Check(section.when and #section.when>0,'visible activation condition');for _,step in ipairs(section.steps) do Check(allowed[step.id],'view action declared') end end end
    c:GetThreads()[4]={{id='warrior.kebab',options={execute_ms=true},steps={['Heroic Strike']=false}}};c:Compile()
    Check(c.plans[2][1].state~=c.plans[4][1].state,'placements own independent state')
    Check(c.plans[2][1].options.execute_ms==false and c.plans[4][1].options.execute_ms==true,'independent placement preferences')
    Check(c.plans[2][1].actions['Heroic Strike'] and not c.plans[4][1].actions['Heroic Strike'],'independent action masks')
    local off={};for _,step in ipairs(entry.definition.steps) do if not step.locked then off[step.id]=false end end
    c:GetThreads()[2]={{id='warrior.kebab',steps=off}};c:Compile();Check(#c.plans[2]==0,'all optional actions off releases placement')
    Check(not c:Add(7,'warrior.kebab'),'support thread rejects Kebab')
end
-- Standard Normal-phase queue uptime and exact paid budgets (actual HS cost 12).
local function Budget(input,reserve,paid,why)
    input.costs=input.costs or {['Heroic Strike']=12}
    local _,j,e,c,entry,run=Fixture(input);run()
    Check(entry.state.hsReserve==reserve,why..' core reserve: '..tostring(entry.state.hsReserve))
    Check(entry.state.hsThreshold==12+reserve,why..' exact payment threshold')
    Check(entry.state.paidHS==paid,why..' payment permission')
end
for _,case in ipairs({
    {ms=1,ww=8,reserve=30,threshold=42,label='MS only'},
    {ms=8,ww=1,reserve=25,threshold=37,label='WW only'},
    {ms=1,ww=2,reserve=55,threshold=67,label='both upcoming'},
}) do
    for _,delta in ipairs({-1,0,1}) do
        Budget({rage=case.threshold+delta,swing=0.2,gcd=0.1,cd={['Mortal Strike']=case.ms,Whirlwind=case.ww}},case.reserve,delta>=0,case.label..' delta '..delta)
    end
end
Budget({rage=12,swing=0.2,cd={['Mortal Strike']=8,Whirlwind=8}},0,true,'no core due before next possible white MH')
Budget({rage=42,swing=0.2,gcd=0.1,cd={['Mortal Strike']=1,Whirlwind=1}},55,false,'simultaneous cooldowns reserve two sequential GCDs')
Budget({rage=42,swing=0.2,gcd=1.5,cd={['Mortal Strike']=0,Whirlwind=0}},55,false,'shared GCD cannot exclude a second ready core')
Budget({rage=42,swing=0.2,cd={['Mortal Strike']=1,Whirlwind=1},steps={Whirlwind=false}},30,true,'disabled WW removes its reservation')
Budget({rage=37,swing=0.2,cd={['Mortal Strike']=1,Whirlwind=1},steps={['Mortal Strike']=false}},25,true,'disabled MS removes its reservation')
Budget({rage=12,swing=0.2,steps={['Mortal Strike']=false,Whirlwind=false}},0,true,'both cores disabled')
Budget({rage=67,unreliable=true,gcd=1},55,true,'unknown timing conservatively funds both enabled cores')
Budget({rage=66,unreliable=true,gcd=1},55,false,'unknown timing below complete funding')
Budget({rage=42,swing=0.2,cd={['Mortal Strike']=1},disabledCD='Whirlwind'},30,true,'unavailable WW removes reservation')
Expect({rage=20,swing=2,costs={['Heroic Strike']=12}},'Heroic Strike','default temporary queue while pooling both ready cores')
Expect({rage=11,swing=2,costs={['Heroic Strike']=12}},nil,'client shortage prevents new queue')
Expect({rage=25,swing=2,costs={['Heroic Strike']=12}},'Whirlwind','affordable WW does not wait for unaffordable MS')
Expect({rage=30,swing=2,costs={['Heroic Strike']=12}},'Mortal Strike','ready MS precedes new queue')
Expect({rage=80,swing=2},'Mortal Strike','even fully funded new HS never delays ready MS')
Expect({rage=20,swing=0.9,costs={['Heroic Strike']=12}},nil,'temporary queue needs cancellation headroom')
Expect({rage=42,swing=0.1,costs={['Heroic Strike']=12},cd={['Mortal Strike']=1,Whirlwind=8}},'Heroic Strike','fully paid queue can be admitted inside cancellation margin')
for _,field in ipairs({'unreliable','unconfirmed'}) do
    local input={rage=20,swing=2,costs={['Heroic Strike']=12}};input[field]=true
    Expect(input,nil,'unfunded queue fails closed on '..field)
end
Expect({rage=20,swing=2,costs={['Heroic Strike']=12},swingTarget='other'},nil,'unfunded queue cannot reuse another target cycle')
Expect({rage=20,swing=2,costs={['Heroic Strike']=12},options={mainhand_queue=false}},'Heroic Strike','retired saved experiment false does not disable standard behavior')
Expect({rage=20,swing=2,costs={['Heroic Strike']=12},steps={['Heroic Strike']=false}},nil,'HS action switch disables standard queuing')
Expect({rage=30,swing=2,costs={['Heroic Strike']=12},execute=true,options={execute_hs=true}},'Execute','no temporary queue in Execute')
Expect({rage=30,swing=0.1,queued='Heroic Strike',costs={['Heroic Strike']=12}},'Mortal Strike','ready MS precedes deadline cancellation')
Expect({rage=25,swing=0.1,queued='Heroic Strike',costs={['Heroic Strike']=12}},'Whirlwind','ready WW precedes deadline cancellation')
Expect({rage=30,swing=0.1,gcd=1,queued='Heroic Strike',costs={['Heroic Strike']=12}},'Stopcasting','GCD-blocked core cannot prevent required cancellation')
Expect({rage=11,swing=0.1,queued='Heroic Strike',costs={['Heroic Strike']=12}},nil,'below HS cost preserves factual queue without rage-only cancellation')
Expect({rage=0,swing=0.1,queued='Heroic Strike',costs={['Heroic Strike']=12}},nil,'zero rage never manufactures queue removal')
Expect({rage=0,queued='Heroic Strike',steps={['Heroic Strike']=false}},'Stopcasting','disabled HS cleanup is independent of rage')
Expect({rage=15,execute=true,queued='Heroic Strike',costs={['Heroic Strike']=12},options={execute_hs=true,execute_ms=false,execute_ww=false}},'Execute','permitted Execute spends actual rage')
do
    local s,j,e,c,entry,run=Fixture({rage=20,swing=2,costs={['Heroic Strike']=12}})
    Check(run()=='Heroic Strike' and entry.state.reason=='temporary_mh_queue','standard temporary admission is diagnosed')
    s.queued='Heroic Strike';s.swing=0.61
    Check(run()==nil and entry.state.queuedCost==12 and entry.state.rage==20,'retain queue until deadline without deducting its cost')
    s.swing=0.6;s.interrupt=true
    Check(run()=='Stopcasting','cancel before interrupt at deadline')
    Check(run()=='Stopcasting','unconfirmed cancellation retries')
    s.queued=nil;s.interrupt=false;s.swing=1.5
    Check(run()==nil,'no temporary requeue in cancelled cycle after timing extension')
    s.cycle=100;s.swing=2
    Check(run()=='Heroic Strike','new confirmed cycle reopens queue')
    s.queued='Heroic Strike';s.rage=30
    Check(run()=='Mortal Strike' and entry.state.queuedCost==12,'MS spends actual 30 rage directly with queue observed')
    s.rage=0;s.cd={['Mortal Strike']=6,Whirlwind=5};s.gcd=1.5;s.swing=0.2
    Check(run()==nil and entry.state.queuedCost==12,'post-core zero rage preserves factual queue')
    s.queued=nil
    Check(run()==nil and entry.state.queuedCost==0,'only client observation clears queued cost')
end
for _,field in ipairs({'lost','outOfRange','pvp','dead','noDW','unreliable','outOfCombat','second','execute','casting','channel'}) do
    local s,j,e,c,entry,run,frames=Fixture({rage=20,swing=2,costs={['Heroic Strike']=12}})
    Check(run()=='Heroic Strike','prepare witnessed queue '..field)
    s.queued='Heroic Strike';Check(run()==nil,'witness queue '..field)
    s[field]=true
    if field=='second' then frames[1].scripts.OnEvent(nil,'NAME_PLATE_UNIT_ADDED','nameplate2') end
    local action=run()
    if field=='casting' or field=='channel' then Check(action==nil,'never cancel live '..field)
    else Check(action=='Stopcasting','cleanup on '..field) end
end
do
    local s,j,e,c,entry,run=Fixture({rage=20,swing=2,costs={['Heroic Strike']=12}})
    run();s.lost=true;Check(run()==nil,'intent alone cannot manufacture queue cleanup')
    s.queued='Heroic Strike';Check(run()=='Stopcasting','first actual confirmation after target loss cleans queue')
end
do
    local s,j,e,c,entry,run=Fixture({rage=20,swing=2,costs={['Heroic Strike']=12}})
    run();s.queued='Heroic Strike';run();c:ResetDecisionState();s.lost=true
    Check(run()=='Stopcasting','observed queue survives decision reset')
    s.lost=false
    c:GetThreads()[4]={{id='warrior.kebab',steps={['Heroic Strike']=false},options={mainhand_queue=false}}};c:Compile();j.RoutineContext=c.plans[4][1]
    Check(First(j.warriorKebab('target'))=='Stopcasting','another placement applies its own switch to factual carried queue')
    Check(c:GetThreads()[4][1].options.mainhand_queue==false and c.plans[4][1].options.mainhand_queue==nil,'retired saved key preserved but not compiled')
end
-- Haste, custom costs, core masks and placement resets affect prospective budgets.
do
    local s,j,e,c,entry,run=Fixture({rage=42,swing=0.2,mainhand=2.6,costs={['Heroic Strike']=12},cd={['Mortal Strike']=1,Whirlwind=2.5}})
    run();Check(entry.state.hsReserve==55 and math.abs(entry.state.hsHorizon-2.8)<0.000001,'current MH period sets payment horizon')
    s.mainhand=1.8
    run();Check(entry.state.hsReserve==30 and entry.state.hsThreshold==42,'haste shortens funding horizon without invented rage')
    s.mainhand=3
    run();Check(entry.state.hsReserve==55,'slower swing expands reserve again')
end
do
    local s,j,e,c,entry,run=Fixture({rage=66,swing=0.2,gcd=0.1,costs={['Heroic Strike']=11,['Mortal Strike']=29,Whirlwind=24},cd={['Mortal Strike']=1,Whirlwind=2}})
    run();Check(entry.state.hsReserve==53 and entry.state.hsThreshold==64 and entry.state.paidHS,'actual modified costs replace all defaults')
end
Expect({rage=64,swing=1,queued='Heroic Strike',costs={['Heroic Strike']=12},stacks=1,sunder=20,options={sunder_stack=true},cd={['Mortal Strike']=2,Whirlwind=3},steps={Hamstring=false}},nil,'Sunder filler cannot spend either upcoming core reserve')
Expect({rage=64,swing=1,queued='Heroic Strike',costs={['Heroic Strike']=12},cd={['Mortal Strike']=2,Whirlwind=3}},nil,'Hamstring cannot spend either upcoming core reserve')
Expect({rage=65,swing=1,queued='Heroic Strike',costs={['Heroic Strike']=12},cd={['Mortal Strike']=2,Whirlwind=3}},'Hamstring','Hamstring exact cost plus both upcoming cores')
do
    local s,j,e,c,entry,run=Fixture({rage=20,swing=0.6,queued='Heroic Strike',costs={['Heroic Strike']=12}})
    Check(run()=='Stopcasting','first placement cancels current cycle')
    s.queued=nil;s.swing=2
    Check(run()==nil,'first placement cycle guard is active')
    c:GetThreads()[4]={{id='warrior.kebab'}};c:Compile()
    j.RoutineContext=c.plans[4][1]
    Check(First(j.warriorKebab('target'))=='Heroic Strike','new placement owns its prospective cycle state')
    Check(c.plans[2][1].state~=c.plans[4][1].state,'independent queue decision tables')
end
-- Three reviewed failures: independent close-CD reserve, guarded buffs, funded queue preservation.
for _,case in ipairs({
    {ms=0,ww=0,gcd=1.5}, {ms=0.1,ww=0.2,gcd=1.5},
    {ms=1.4,ww=1.5,gcd=1.5}, {ms=2.6,ww=2.7,gcd=0.1},
    {ms=0,ww=0,gcd=1.5,mainhand=0.8},
}) do
    for _,rage in ipairs({42,66,67}) do
        Budget({rage=rage,swing=0.2,gcd=case.gcd,mainhand=case.mainhand,cd={['Mortal Strike']=case.ms,Whirlwind=case.ww}},55,rage>=67,'closely due cores independent of GCD at rage '..rage)
    end
end
Expect({rage=42,gcd=1.5,swing=0.2,costs={['Heroic Strike']=12}},nil,'42 cannot pay HS with both ready cores behind a GCD')
Expect({rage=42,gcd=1.5,swing=0.2,queued='Heroic Strike',costs={['Heroic Strike']=12}},'Stopcasting','unfunded second core requires cancellation at deadline')
Expect({rage=42,gcd=1.5,swing=2,costs={['Heroic Strike']=12}},'Heroic Strike','full two-core reserve does not block temporary pooling admission')
-- Pay one HS, cast both cores without depending on subsequent rage income.
do
    local s,j,e,c,entry,run=Fixture({rage=67,gcd=1.5,swing=0.2,queued='Heroic Strike',costs={['Heroic Strike']=12}})
    Check(run()==nil and entry.state.paidHS and entry.state.hsReserve==55,'67 funds paid HS and both GCD-blocked cores')
    s.now=100.2;s.rage=55;s.gcd=1.3;s.swing=2.6;s.cycle=100.2;s.queued=nil
    Check(run()=='Heroic Strike','requeue temporarily after confirmed paid HS')
    s.queued='Heroic Strike';s.now=101.5;s.gcd=0;s.swing=1.3
    Check(run()=='Mortal Strike','first core uses actual rage with queue observed')
    s.rage=25;s.cd={['Mortal Strike']=6};s.gcd=1.5
    Check(run()==nil and entry.state.rage==25,'MS payment retains exactly WW cost; no utility spending')
    s.now=102.2;s.gcd=0.8;s.swing=0.6;s.cd['Mortal Strike']=5.3
    Check(run()=='Stopcasting','unfunded next HS cancels without spending WW rage')
    s.queued=nil;s.now=103;s.gcd=0;s.swing=2.4;s.cycle=102.8;s.cd['Mortal Strike']=4.5
    Check(run()=='Whirlwind','second core casts after GCD without assumed white/OH rage income')
end
-- Optional Hamstring/Sunder cannot turn a funded queue into a deadline cancellation.
for _,kind in ipairs({'hamstring','sunder'}) do
    local ownCost=kind=='sunder' and 15 or 10
    for _,rage in ipairs({67,67+ownCost-1,67+ownCost}) do
        local input={rage=rage,queued='Heroic Strike',swing=0.7,costs={['Heroic Strike']=12},cd={['Mortal Strike']=1.6,Whirlwind=1.7}}
        if kind=='sunder' then input.options={sunder_stack=true};input.sunder=20;input.stacks=1;input.steps={Hamstring=false} end
        local st,j,e,c,entry,run=Fixture(input)
        local action=run();Check(entry.state.optionalReserve==67 and entry.state.paidHS,'preserve full paid queue reserve '..kind)
        Check(action==(rage>=67+ownCost and (kind=='sunder' and 'Sunder Armor' or 'Hamstring') or nil),'exact optional cost boundary '..kind..'/'..rage)
        if action then st.rage=st.rage-ownCost;st.gcd=1.4 end
        st.now=100.1;st.swing=0.6;st.cd={['Mortal Strike']=1.5,Whirlwind=1.6}
        Check(run()==nil and entry.state.paidHS and st.rage>=67,'optional spending never forces next-tick HS cancel '..kind)
    end
end
-- A queued HS only adds its real cost to optional funding when already paid/funded.
do
    local s,j,e,c,entry,run=Fixture({rage=65,queued='Heroic Strike',swing=1,costs={['Heroic Strike']=12},cd={['Mortal Strike']=2,Whirlwind=3}})
    Check(run()=='Hamstring' and entry.state.optionalReserve==55 and not entry.state.paidHS,'temporary queue does not falsely reserve a paid HS')
end
-- Ordinary shouts and burst cannot start a GCD across imminent enabled cores.
for _,kind in ipairs({'battle','commanding','deathwish','recklessness'}) do
    local input={rage=100,queued='Heroic Strike',swing=2,costs={['Heroic Strike']=12},cd={['Mortal Strike']=0.1,Whirlwind=0.2}}
    if kind=='battle' or kind=='commanding' then input.noShout=true;input.commanding=kind=='commanding'
    elseif kind=='deathwish' then input.learned={['Death Wish']=true}
    elseif kind=='recklessness' then input.learned={Recklessness=true};input.options={recklessness=true};input.boss=true
    else input.trinket=true end
    local st,j,e,c,entry,run=Fixture(input)
    Check(run()==nil and not entry.state.utilityGap,'hold ordinary buff across imminent core '..kind)
    st.now=100.1;st.cd={['Mortal Strike']=0,Whirlwind=0.1};st.swing=1.9
    Check(run()=='Mortal Strike','ordinary buff never preempts newly ready MS '..kind)
end
-- Reproduce the reviewed 55-rage shout case through both actual core payments.
do
    local s,j,e,c,entry,run=Fixture({rage=55,queued='Heroic Strike',swing=2,noShout=true,costs={['Heroic Strike']=12},cd={['Mortal Strike']=0.1,Whirlwind=0.2}})
    Check(run()==nil and not entry.state.utilityGap,'imminent cores hold an ordinary shout without starting a GCD')
    s.now=100.1;s.swing=1.9;s.cd={['Mortal Strike']=0,Whirlwind=0.1}
    Check(run()=='Mortal Strike' and s.rage==55,'MS uses untouched rage as its cooldown finishes')
    s.rage=25;s.gcd=1.5;s.cd={['Mortal Strike']=6,Whirlwind=0.1}
    Check(run()==nil,'shout still cannot spend the retained WW funding during the GCD')
    s.now=101.6;s.swing=0.4;s.gcd=0;s.cd={['Mortal Strike']=4.5,Whirlwind=0}
    Check(run()=='Whirlwind' and s.rage==25,'WW uses exact retained cost after the shared GCD, before HS cancellation or shout')
end
-- Full resource preservation at the exact shout/Death Wish boundary.
for _,kind in ipairs({'battle','commanding','deathwish'}) do
    for _,rage in ipairs({67,76,77}) do
        local input={rage=rage,queued='Heroic Strike',swing=0.7,costs={['Heroic Strike']=12},cd={['Mortal Strike']=1.6,Whirlwind=1.7}}
        if kind=='deathwish' then input.learned={['Death Wish']=true} else input.noShout=true;input.commanding=kind=='commanding' end
        local st,j,e,c,entry,run=Fixture(input)
        local want=kind=='deathwish' and 'Death Wish' or kind=='commanding' and 'Commanding Shout' or 'Battle Shout'
        Check(run()==(rage>=77 and want or nil) and entry.state.optionalReserve==67,'ordinary buff exact own cost plus cores and paid HS '..kind..'/'..rage)
        if rage==77 then
            st.rage=67;st.gcd=1.4;st.now=100.1;st.swing=0.6;st.cd={['Mortal Strike']=1.5,Whirlwind=1.6};st.noShout=false
            Check(run()==nil and entry.state.paidHS,'buff preserves paid queue at next deadline '..kind)
        end
    end
end
Expect({rage=55,swing=2,noShout=true,costs={['Heroic Strike']=12},cd={['Mortal Strike']=0.1,Whirlwind=0.2}},'Heroic Strike','held shout leaves off-GCD temporary admission available')
Expect({rage=50,gcd=1,swing=2,queued='Heroic Strike',learned={Bloodrage=true},cd={['Mortal Strike']=0.1,Whirlwind=0.2}},'Bloodrage','off-GCD Bloodrage remains available while pooling')
Expect({rage=67,gcd=1,queued='Heroic Strike',costs={['Heroic Strike']=12},trinket=true,cd={['Mortal Strike']=0.1,Whirlwind=0.2}},'Trinkets','off-GCD trinkets remain available across imminent cores and active GCD')
Expect({rage=67,queued='Heroic Strike',trinket=true},'Mortal Strike','ready core precedes off-GCD trinkets')
Expect({rage=100,queued='Heroic Strike',swing=1,cd={['Mortal Strike']=1.49,Whirlwind=8},noShout=true},nil,'ordinary buff needs full 1.5-second core gap')
Expect({rage=100,queued='Heroic Strike',swing=1,cd={['Mortal Strike']=1.5,Whirlwind=8},noShout=true},'Battle Shout','ordinary buff admits at full GCD boundary')
-- Ready() tolerates the final 10ms of a GCD; optional actions must still fit
-- their next complete GCD after that remainder instead of overlapping a core.
for _,kind in ipairs({'shout','hamstring','sunder','victory','berserker'}) do
    local input={rage=100,gcd=0.005,swing=1,queued='Heroic Strike',cd={['Mortal Strike']=1.5,Whirlwind=8}}
    local want
    if kind=='shout' then input.noShout=true;want='Battle Shout'
    elseif kind=='sunder' then input.options={sunder_stack=true};input.stacks=1;input.sunder=20;input.steps={Hamstring=false};want='Sunder Armor'
    elseif kind=='victory' then input.learned={['Victory Rush']=true};want='Victory Rush'
    elseif kind=='berserker' then input.learned={['Berserker Rage']=true};input.options={berserker_rage=true};want='Berserker Rage'
    else want='Hamstring' end
    local st,j,e,c,entry,run=Fixture(input)
    Check(run()==nil,'optional GCD must include the current remainder '..kind)
    st.cd['Mortal Strike']=1.505
    Check(run()==want,'optional GCD admits when the remainder plus full GCD fits '..kind)
end
for _,rage in ipairs({90,95,100}) do
    Expect({rage=rage,queued='Heroic Strike',steps={['Heroic Strike']=false},cd={['Mortal Strike']=0.75,Whirlwind=3},options={aggressive_filler=true}},'Stopcasting','disabled factual queue still cleans before retired filler')
    Expect({rage=rage,steps={['Heroic Strike']=false},cd={['Mortal Strike']=0.75,Whirlwind=3},options={aggressive_filler=true}},nil,'retired aggressive option never shortens gap at cap '..rage)
end
do
    local st,j,e,c,entry,run=Fixture({rage=100,steps={['Heroic Strike']=false},cd={['Mortal Strike']=0.75,Whirlwind=3},options={aggressive_filler=true}})
    Check(c:GetThreads()[2][1].options.aggressive_filler==true and entry.options.aggressive_filler==nil,'retired cap true survives raw but never compiles')
    Check(not c:SetOption(2,1,'aggressive_filler',true),'retired cap option cannot be changed through active configuration')
end
-- Enabled utility cannot be starved by new queues or paid damage fillers.
Expect({rage=50,cd={['Mortal Strike']=3,Whirlwind=3},options={demo=true}},'Demoralizing Shout','Demo precedes default paid HS')
Expect({rage=50,cd={['Mortal Strike']=3,Whirlwind=3},options={berserker_rage=true},learned={['Berserker Rage']=true}},'Heroic Strike','Normal queue admission precedes optional Berserker Rage')
Expect({rage=50,cd={['Mortal Strike']=3,Whirlwind=3},steps={['Heroic Strike']=false},options={berserker_rage=true},learned={['Berserker Rage']=true}},'Berserker Rage','Berserker Rage precedes repeated Hamstring')
Expect({rage=50,cd={['Mortal Strike']=3,Whirlwind=3},options={demo=true},steps={['Demoralizing Shout']=false}},'Heroic Strike','disabled Demo leaves queue priority')
Expect({rage=50,cd={['Mortal Strike']=3,Whirlwind=3},options={berserker_rage=true},learned={['Berserker Rage']=true},steps={['Berserker Rage']=false}},'Heroic Strike','disabled Berserker Rage leaves queue priority')
Expect({rage=30,options={demo=true,berserker_rage=true},learned={['Berserker Rage']=true}},'Demoralizing Shout','Demo maintenance precedes a ready core')
Expect({rage=50,cd={['Mortal Strike']=1,Whirlwind=3},options={demo=true,berserker_rage=true},learned={['Berserker Rage']=true}},'Demoralizing Shout','Demo maintenance ignores the core gap')
Expect({rage=44,cd={['Mortal Strike']=3,Whirlwind=3},options={demo=true}},'Demoralizing Shout','urgent Demo does not reserve core rage')
Expect({rage=50,cd={['Mortal Strike']=3,Whirlwind=3},options={demo=true},demo=6},'Heroic Strike','healthy Demo coverage leaves queue priority')
Expect({rage=50,cd={['Mortal Strike']=3,Whirlwind=3},options={berserker_rage=true},learned={['Berserker Rage']=true},buffs={['Berserker Rage']=true}},'Heroic Strike','active Berserker Rage is not refreshed')
Expect({rage=50,gcd=1,cd={['Mortal Strike']=3,Whirlwind=3},options={demo=true,berserker_rage=true},learned={['Berserker Rage']=true}},'Heroic Strike','GCD utilities cannot block an off-GCD queue')
-- Safe AoE priority and transitions through the real evaluator/compiled masks.
local function AoE(s, expected, reason)
    s.second=true
    local _,j,e,c,entry,run,frames=Fixture(s)
    frames[1].scripts.OnEvent(nil,'NAME_PLATE_UNIT_ADDED','nameplate2')
    local action=run();Check(action==expected,reason..': '..tostring(action))
    local label=entry.state.aoe and 'PvE AoE' or 'PvE Single target'
    local ids={}
    for _,section in ipairs(entry.definition.views[1].sections) do
        if section.label==label then for _,step in ipairs(section.steps) do ids[step.id]=true end end
    end
    Check(not action or ids[action],reason..' is represented in its actual branch')
    return s,j,e,c,entry,run,frames
end
AoE({rage=80,cd={['Mortal Strike']=3,Whirlwind=3},options={demo=true}},'Demoralizing Shout','AoE Demo precedes paid Cleave')
AoE({rage=80,cd={['Mortal Strike']=3,Whirlwind=3},options={berserker_rage=true},learned={['Berserker Rage']=true}},'Berserker Rage','AoE Berserker Rage precedes paid Cleave')
AoE({rage=80,cd={['Mortal Strike']=3,Whirlwind=3},options={demo=true},learned={['Sweeping Strikes']=true}},'Demoralizing Shout','funded Demo retains SS and next core cost')
AoE({rage=50,cd={['Mortal Strike']=3,Whirlwind=3},options={demo=true},learned={['Sweeping Strikes']=true}},'Demoralizing Shout','urgent Demo precedes ready SS funding')
AoE({rage=80,cd={['Mortal Strike']=3,Whirlwind=3},options={demo=true},excluded=true},'Heroic Strike','unsafe area still excludes Demo')
AoE({rage=80,execute=true,options={demo=true,berserker_rage=true},learned={['Berserker Rage']=true}},'Demoralizing Shout','Demo maintenance continues during Execute')
AoE({rage=60,learned={['Sweeping Strikes']=true}},'Sweeping Strikes','fund SS and immediate WW')
AoE({rage=59,learned={['Sweeping Strikes']=true}},nil,'pool below funded SS budget')
AoE({rage=60,gcd=1,learned={['Sweeping Strikes']=true}},'Sweeping Strikes','SS off-GCD policy')
AoE({rage=80,learned={['Sweeping Strikes']=true},steps={['Sweeping Strikes']=false}},'Cleave','disabled SS releases its pooling')
AoE({rage=80,learned={['Sweeping Strikes']=true},buffs={['Sweeping Strikes']=true}},'Cleave','active SS does not reserve reapplication')
AoE({rage=80,learned={['Sweeping Strikes']=true},cd={['Sweeping Strikes']=10}},'Cleave','future SS cooldown does not pool')
AoE({rage=30,learned={['Sweeping Strikes']=true},blocked={['Sweeping Strikes']=true}},'Whirlwind','unusable SS cannot hold WW')
AoE({rage=50},'Cleave','funded Cleave')
AoE({rage=30,blocked={Cleave=true},cd={Whirlwind=10}},'Mortal Strike','unusable Cleave releases MS reserve')
AoE({rage=30,unknown={Cleave=true},cd={Whirlwind=10}},'Mortal Strike','unknown Cleave releases MS reserve')
AoE({rage=49},'Whirlwind','WW before MS below Cleave admission')
AoE({rage=70,gcd=1},'Cleave','Cleave during global')
AoE({rage=50,queued='Cleave'},'Whirlwind','funded queue stays while WW spends')
AoE({rage=44,queued='Cleave'},'Whirlwind','queued Cleave has not spent WW rage')
AoE({rage=80,queued='Heroic Strike'},'Stopcasting','enter AoE clears HS')
AoE({rage=80,queued='Cleave',steps={Cleave=false}},'Stopcasting','disable Cleave keeps factual cleanup')
AoE({rage=30,steps={Cleave=false,['Whirlwind']=false}},'Mortal Strike','disabled area attacks remove MS reserves')
AoE({rage=44,cd={Whirlwind=10}},'Mortal Strike','unqueued Cleave cannot reserve MS into an idle tick')
AoE({rage=50,queued='Cleave',cd={Whirlwind=10}},'Mortal Strike','spare MS with existing Cleave funded')
AoE({rage=15,execute=true},'Execute','low rage Execute')
AoE({rage=45,execute=true},'Whirlwind','Execute WW keeps minimum Execute reserve')
AoE({rage=80,execute=true,queued='Cleave'},'Stopcasting','Execute Cleave off by default')
AoE({rage=80,execute=true,options={execute_cleave=true}},'Cleave','explicit funded Execute Cleave')
AoE({rage=60,execute=true,options={execute_cleave=true}},'Whirlwind','Execute Cleave cannot starve WW/Execute')
AoE({rage=80,execute=true,options={execute_ww=false,execute_ms=true},steps={Cleave=false}},'Mortal Strike','Execute MS remains optional')
AoE({rage=80,excluded=true,learned={['Sweeping Strikes']=true}},'Mortal Strike','excluded observation blocks area attacks while ready direct MS wins')
AoE({rage=80,excluded=true,queued='Cleave'},'Stopcasting','unsafe area cleans Cleave')
AoE({rage=40,steps={Cleave=false},cd={Whirlwind=3,['Mortal Strike']=3}},nil,'no AoE Hamstring filler')
AoE({rage=30,options={mainhand_queue=true},cd={Whirlwind=10,['Mortal Strike']=10}},nil,'no AoE temporary HS')
do
    local s,j,e,c,entry,run,frames=AoE({rage=80,queued='Cleave'},'Whirlwind','AoE initially owns')
    frames[1].scripts.OnEvent(nil,'NAME_PLATE_UNIT_REMOVED','nameplate2');s.second=false
    Check(run()=='Stopcasting' and not entry.state.aoe,'count drop cleans Cleave immediately')
    s.queued=nil;Check(run()=='Mortal Strike','count drop restores core-first single target')
    s.queued='Cleave';s.lost=true;Check(run()=='Stopcasting','target loss cleans observed Cleave')
    s.queued=nil;Check(run()==nil and not j.WarriorKebab:Hold(),'missing enemy releases after cleanup')
end
for _,field in ipairs({'lost','outOfRange','pvp','dead','noDW'}) do
    local s,j,e,c,entry,run=AoE({rage=80,queued='Cleave'},'Whirlwind','queue before '..field)
    s[field]=true;Check(run()=='Stopcasting','carried Cleave cleanup on '..field)
end
do
    local s,j,e,c,entry,run=AoE({rage=59,learned={['Sweeping Strikes']=true}},nil,'SS pool begins')
    Check(j.WarriorKebab:Hold(),'SS pool owns eligible combat tick')
    s.second=false;e.UnitExists=function(unit) return unit=='player' or unit=='target' or unit=='nameplate1' end
    Check(run()=='Mortal Strike' and not entry.state.aoe,'count drop releases SS pool immediately to ready MS')
end
do
    local s,j,e,c,entry,run=AoE({rage=80},'Cleave','first AoE placement')
    c:GetThreads()[4]={{id='warrior.kebab',steps={Cleave=false,['Sweeping Strikes']=false},options={execute_cleave=true}}};c:Compile()
    j.RoutineContext=c.plans[4][1]
    Check(First(j.warriorKebab('target'))=='Whirlwind','second placement uses independent AoE switches')
    j.RoutineContext=c.plans[2][1]
    Check(First(j.warriorKebab('target'))=='Cleave','first placement preserves its Cleave switch')
    s.queued='Cleave';c:ResetDecisionState();s.lost=true
    Check(First(j.warriorKebab(nil))=='Stopcasting','witnessed Cleave survives prospective state reset')
end
-- A queue is an observation, never a prior rage payment or GCD.
Expect({rage=45,queued='Heroic Strike',cd={['Mortal Strike']=3,Whirlwind=3},options={demo=true}},'Demoralizing Shout','Demo spends current rage with HS queued')
Expect({rage=10,queued='Heroic Strike',noShout=true,cd={['Mortal Strike']=3,Whirlwind=3}},nil,'ordinary shout cannot spend unfunded future core rage')
Expect({rage=10,queued='Heroic Strike',noShout=true,steps={['Mortal Strike']=false,Whirlwind=false}},'Battle Shout','with cores disabled, self shout uses current rage without deducting an unaffordable HS')
Expect({rage=15,queued='Heroic Strike',cd={['Mortal Strike']=3,Whirlwind=3},options={sunder_initial=true}},'Sunder Armor','assigned Sunder uses actual rage with HS queued')
Expect({rage=10,queued='Heroic Strike',cd={['Mortal Strike']=3,Whirlwind=3},learned={['Death Wish']=true}},nil,'Death Wish cannot spend unfunded future core rage')
Expect({rage=10,queued='Heroic Strike',steps={['Mortal Strike']=false,Whirlwind=false},learned={['Death Wish']=true}},'Death Wish','with cores disabled, burst uses actual rage without deducting an unaffordable HS')
Expect({rage=5,queued='Heroic Strike',cd={['Mortal Strike']=3,Whirlwind=3},options={berserker_rage=true},learned={['Berserker Rage']=true}},'Berserker Rage','low-rage HS queue does not block utility global')
Expect({rage=45,queued='Heroic Strike',gcd=1,cd={['Mortal Strike']=3,Whirlwind=3},options={demo=true}},nil,'Demo still requires the real GCD')
AoE({rage=40,queued='Cleave',cd={['Mortal Strike']=3,Whirlwind=3},options={demo=true}},'Demoralizing Shout','Demo uses current rage with Cleave queued')
AoE({rage=5,queued='Cleave',cd={['Mortal Strike']=3,Whirlwind=3},options={berserker_rage=true},learned={['Berserker Rage']=true}},'Berserker Rage','queued unaffordable Cleave does not block utility')
AoE({rage=25,queued='Cleave'},'Whirlwind','WW spends all 25 current rage while Cleave remains queued')
AoE({rage=50,queued='Cleave',blocked={Cleave=true}},'Whirlwind','transient queue usability is not obsolete-context cleanup')
AoE({rage=50,queued='Cleave',missingCD='Cleave'},'Whirlwind','unknown new-queue cooldown does not erase an existing queue')
AoE({rage=80,blocked={Cleave=true}},'Whirlwind','new Cleave still requires explicit client usability')
AoE({rage=30,queued='Cleave',cd={Whirlwind=10}},'Mortal Strike','MS does not double-budget Cleave')
AoE({rage=10,queued='Cleave',noShout=true,cd={['Mortal Strike']=3,Whirlwind=3}},'Battle Shout','AoE shout does not deduct queue cost')
AoE({rage=35,queued='Cleave',cd={['Mortal Strike']=3,Whirlwind=3},learned={['Sweeping Strikes']=true}},'Sweeping Strikes','SS uses current rage while Cleave is queued')
AoE({rage=15,queued='Cleave',execute=true,options={execute_cleave=true,execute_ww=false}},'Execute','permitted Cleave does not deduct Execute rage')
AoE({rage=1,queued='Cleave',cd={['Mortal Strike']=3,Whirlwind=3}},nil,'low rage alone does not cancel factual Cleave')
do
    local s,j,e,c,entry,run=AoE({rage=40,queued='Cleave',cd={['Mortal Strike']=3,Whirlwind=3},options={demo=true}},'Demoralizing Shout','Demo while queued')
    Check(entry.state.queuedCost==20 and entry.state.rage==40,'intent has not removed queue or paid rage')
    s.rage=30;s.gcd=1.5;s.demo=30
    Check(run()==nil and entry.state.queuedCost==20,'post-Demo GCD/actual rage changes do not cancel Cleave')
    s.rage=25;s.gcd=0;s.cd.Whirlwind=0
    Check(run()=='Whirlwind' and entry.state.queuedCost==20,'next ready WW uses actual rage with factual queue intact')
    s.queued=nil;s.rage=5;s.gcd=1.5
    Check(run()==nil and entry.state.queuedCost==0,'only client observation clears Cleave queue')
end
-- Both compact sections cover Normal/Execute, area exclusions and missing enemies.
for _,execute in ipairs({false,true}) do for _,lost in ipairs({false,true}) do for _,excluded in ipairs({false,true}) do
    local s,j,e,c,entry,run,frames=Fixture({rage=80,execute=execute,lost=lost,second=excluded,excluded=excluded,noShout=lost})
    if excluded then frames[1].scripts.OnEvent(nil,'NAME_PLATE_UNIT_ADDED','nameplate2') end
    local action=run();local view=entry.definition.views[1]
    Check(#view.sections==2,'exactly two PvE blocks')
    local ids={};for _,step in ipairs(view.sections[1].steps) do ids[step.id]=true end
    Check(not action or ids[action],'single-target section covers phase/exclusion/no-enemy outputs')
end end end
-- Assigned debuff maintenance is urgent; healthy extra Sunder stacks are filler.
for _,queued in ipairs({'none','Heroic Strike'}) do
    local q=queued~='none' and queued or nil
    Expect({rage=10,queued=q,options={demo=true}},'Demoralizing Shout','Demo needs only its own rage, before a ready core/queue')
    Expect({rage=30,queued=q,execute=true,options={demo=true,execute_hs=true}},'Demoralizing Shout','Execute and queued HS do not bypass Demo')
    Expect({rage=50,queued=q,demo=5,options={demo=true}},'Demoralizing Shout','Demo refresh boundary includes five seconds')
    Expect({rage=30,queued=q,demo=5.01,options={demo=true}},'Mortal Strike','healthy Demo coverage releases ready core')
end
Expect({rage=9,options={demo=true}},nil,'insufficient Demo rage does not emit a cast')
Expect({rage=30,options={demo=true},steps={['Demoralizing Shout']=false}},'Mortal Strike','disabled Demo releases priority')
Expect({rage=30,options={demo=true},otherAP=true},'Mortal Strike','other AP coverage still suppresses Demo')
Expect({rage=30,options={demo=true,sunder_initial=true}},'Demoralizing Shout','Demo precedes assigned Sunder')
Expect({rage=30,options={demo=true},interrupt=true},'Pummel','interrupt keeps priority over maintenance')
for _,mode in ipairs({'sunder_initial','sunder_stack'}) do
    Expect({rage=15,options={[mode]=true}},'Sunder Armor','either Sunder mode independently initializes with own cost')
    Expect({rage=30,queued='Heroic Strike',options={[mode]=true}},'Sunder Armor','urgent Sunder precedes ready queued-HS MS')
    Expect({rage=15,stacks=5,sunder=3,options={[mode]=true}},'Sunder Armor','either mode refreshes five stacks at three seconds')
    Expect({rage=30,stacks=1,sunder=2,options={[mode]=true}},'Sunder Armor','refresh takes priority below five stacks')
    Expect({rage=15,stacks=5,sunder=-0.1,options={[mode]=true}},'Sunder Armor','elapsed aura observation triggers refresh')
    Expect({rage=30,execute=true,options={[mode]=true}},'Sunder Armor','first Sunder remains urgent during Execute')
    Expect({rage=30,execute=true,stacks=5,sunder=2,options={[mode]=true}},'Sunder Armor','Sunder refresh remains urgent during Execute')
    Expect({rage=30,stacks=5,sunder=3.01,options={[mode]=true}},'Mortal Strike','healthy five-stack coverage releases damage')
    Expect({rage=30,stacks=1,sunder=20,options={[mode]=true}},'Mortal Strike','healthy extra stacks never preempt a ready core')
    Expect({rage=30,options={[mode]=true},steps={['Sunder Armor']=false}},'Mortal Strike','Sunder action mask disables urgent and filler paths')
    Expect({rage=30,options={[mode]=true},expose=10},'Mortal Strike','Expose Armor suppresses either mode')
    Expect({rage=14,options={[mode]=true}},nil,'insufficient Sunder rage does not emit maintenance')
end
Expect({rage=60,queued='Heroic Strike',stacks=1,sunder=20,cd={['Mortal Strike']=3,Whirlwind=3},options={sunder_stack=true}},'Sunder Armor','healthy stack fills safe core gap with existing HS queue')
Expect({rage=60,queued='Heroic Strike',stacks=1,sunder=20,cd={['Mortal Strike']=3,Whirlwind=3},options={sunder_initial=true}},'Hamstring','Init mode does not build healthy stacks')
Expect({rage=59,queued='Heroic Strike',stacks=1,sunder=20,cd={['Mortal Strike']=3,Whirlwind=3},options={sunder_stack=true},steps={Hamstring=false}},nil,'extra stack retains actual next-core cost plus funded HS without a buffer')
Expect({rage=60,queued='Heroic Strike',stacks=1,sunder=20,cd={['Mortal Strike']=3,Whirlwind=3},options={sunder_stack=true},steps={Hamstring=false}},'Sunder Armor','extra stack admits at exact own cost plus next core and funded HS')
Expect({rage=50,queued='Heroic Strike',stacks=1,sunder=20,cd={['Mortal Strike']=1,Whirlwind=3},options={sunder_stack=true}},nil,'short core gap prevents healthy stack filler')
Expect({rage=50,queued='Heroic Strike',stacks=5,sunder=20,cd={['Mortal Strike']=3,Whirlwind=3},options={sunder_stack=true},steps={Hamstring=false}},nil,'healthy stack filler stops at five')
Expect({rage=50,queued='Heroic Strike',stacks=1,sunder=20,cd={['Mortal Strike']=3,Whirlwind=3},options={sunder_stack=true},learned={['Victory Rush']=true}},'Victory Rush','free damage takes priority over extra Sunder stack')
Expect({rage=60,queued='Heroic Strike',stacks=1,sunder=20,cd={['Mortal Strike']=3,Whirlwind=3},options={sunder_initial=true,sunder_stack=true}},'Sunder Armor','both modes cooperate without disabling stack filler')
AoE({rage=10,queued='Cleave',options={demo=true}},'Demoralizing Shout','urgent AoE Demo uses actual rage before ready WW')
AoE({rage=30,queued='Cleave',options={sunder_stack=true}},'Sunder Armor','AoE missing Sunder precedes WW and Cleave funding')
AoE({rage=30,execute=true,options={sunder_initial=true},stacks=5,sunder=2},'Sunder Armor','AoE Execute refresh precedes damage')
AoE({rage=50,queued='Cleave',stacks=1,sunder=20,cd={['Mortal Strike']=3,Whirlwind=3},options={sunder_stack=true}},'Sunder Armor','AoE healthy stack uses a funded idle gap')
AoE({rage=30,queued='Cleave',stacks=1,sunder=20,options={sunder_stack=true}},'Whirlwind','healthy stack never preempts ready AoE WW')
-- Exercise actual aura stack/expiry observations through Warrior.lua's helper.
for _,case in ipairs({
    {auras={},want='Sunder Armor',label='missing'},
    {auras={{'Sunder Armor',5,2}},want='Sunder Armor',label='expiring five stacks'},
    {auras={{'Sunder Armor',1,20}},want='Mortal Strike',label='healthy one stack'},
    {auras={{'Sunder Armor',5}},want='Mortal Strike',label='permanent aura'},
    {auras={{'Expose Armor',1,20}},want='Mortal Strike',label='Expose'},
}) do
    Expect({rage=30,options={sunder_initial=true},sharedDebuffs=true,auras=case.auras},case.want,'real Sunder helper: '..case.label)
end
-- Current-rage/readiness guards avoid aura work when a maintenance GCD is impossible.
for _,input in ipairs({{rage=30,gcd=1},{rage=30,steps={['Demoralizing Shout']=false,['Sunder Armor']=false}},{rage=5}}) do
    input.options={demo=true,sunder_initial=true,sunder_stack=true}
    local _,j,e,c,entry,run=Fixture(input)
    j.WarriorAdaptiveContext.debuffRemaining=function() error('unready/disabled Demo must not scan auras') end
    j.WarriorAdaptiveContext.armorDebuff=function() error('unready/disabled Sunder must not scan auras') end
    run();Check(true,'unready or disabled maintenance skips aura scans')
end
-- AoE and Execute retain the exact pre-refactor decisions across resource/GCD/queue states.
do
    local path='C:/Users/freeker0k/.codex/task-checkpoints/olia-kebab-core-guards-20261014/before/Routines/WarriorKebab.lua'
    for _,rage in ipairs({0,12,15,25,30,40,44,50,67,80,95}) do
        for _,mode in ipairs({'aoe','execute','aoe_execute'}) do for _,gcd in ipairs({0,1}) do for _,queued in ipairs({'none','Cleave','Heroic Strike'}) do
            local s,j,e,c,entry,run,frames=Fixture({rage=rage,execute=mode~='aoe',second=mode~='execute',gcd=gcd,queued=queued~='none' and queued or nil})
            if s.second then frames[1].scripts.OnEvent(nil,'NAME_PLATE_UNIT_ADDED','nameplate2') end
            local current=run()
            setfenv(assert(loadfile(path)),e)('OliaEyes6',j)
            entry.state={};frames[#frames].scripts.OnEvent(nil,'PLAYER_ENTERING_WORLD')
            Check(First(j.warriorKebab('target'))==current,'unchanged '..mode..' parity rage '..rage..' GCD '..gcd..' queue '..queued)
        end end end
    end
end
-- Exercise the actual Warrior.lua debuff bridge rather than a substitute helper.
for _,case in ipairs({
    {auras={},want='Demoralizing Shout',label='missing Demo'},
    {auras={{'Demoralizing Shout',0,4}},want='Demoralizing Shout',label='four-second refresh'},
    {auras={{'Demoralizing Shout',0,6}},want='Heroic Strike',label='healthy coverage'},
    {auras={{'Demoralizing Shout'}},want='Heroic Strike',label='permanent coverage'},
    {auras={{'Demoralizing Roar',0,20}},want='Heroic Strike',label='Roar coverage'},
    {auras={{'Curse of Weakness',0,20}},want='Heroic Strike',label='Curse coverage'},
    {auras={{'Screech',0,20}},want='Heroic Strike',label='Screech coverage'},
}) do
    Expect({rage=50,cd={['Mortal Strike']=3,Whirlwind=3},options={demo=true},sharedDebuffs=true,auras=case.auras},case.want,'real Warrior helpers: '..case.label)
end
-- On-demand live diagnosis reports actual compiled/saved gates without evaluating.
do
    local s,j,e,c,entry,run=Fixture({rage=50,cd={['Mortal Strike']=3,Whirlwind=3}})
    local output={};e.print=function(line) output[#output+1]=line end
    j.Engine.activeThread=2
    local before=entry.state.reason
    assert(e.SlashCmdList.OLIAEYES6_KEBABCHECK)()
    local report=table.concat(output,'\n')
    Check(report:find('preference=false saved=nil',1,true)~=nil,'diagnostic exposes default-off empty saved preferences')
    Check(report:find('unevaluated',1,true)~=nil,'diagnostic marks unevaluated placement')
    Check(entry.state.reason==before,'diagnostic does not evaluate or mutate decision state')
    c:SetOption(2,1,'demo',true);c:SetOption(2,1,'berserker_rage',true)
    output={};assert(e.SlashCmdList.OLIAEYES6_KEBABCHECK)()
    Check(table.concat(output,'\n'):find('preference=true saved=true',1,true)~=nil,'diagnostic exposes enabled compiled and saved preference')
    s.lost=true;output={};j.Engine.activeThread=0
    assert(e.SlashCmdList.OLIAEYES6_KEBABCHECK)()
    Check(table.concat(output,'\n'):find('No compiled Kebab',1,true)~=nil,'inactive thread diagnosis is explicit')
end
print('WarriorKebab: '..checks..' checks passed')
