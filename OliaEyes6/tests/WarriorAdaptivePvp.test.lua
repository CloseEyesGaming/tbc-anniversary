-- Actual Adaptive/Original/registry code, Lua 5.1. Game APIs are mocked.
local function Read(path) local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local src=Read('tests/WarriorAdaptive.test.lua')
local stop=assert(src:find('for count=1,10 do',1,true))
local Base=assert(loadstring(src:sub(1,stop-1)..'\nreturn Fixture'))()
local Attach=assert(loadfile('tests/RoutineConfigFixture.lua'))()
local checks=0
local function Check(ok,why) assert(ok,why);checks=checks+1 end
local function First(rows) for _,r in ipairs(rows) do if r[3] then return r[2] end end end
local function Copy(v) if type(v)~='table' then return v end;local t={};for k,x in pairs(v) do t[k]=Copy(x) end;return t end
local disabled={Bloodrage=true,['Berserker Rage']=true,['Death Wish']=true,Trinkets=true}
local core={Slam=true,['Mortal Strike']=true,Whirlwind=true,Execute=true,['Heroic Strike']=true,Cleave=true,['Sweeping Strikes']=true}
local utility={['Demoralizing Shout']=true,Hamstring=true,['Piercing Howl']=true,Overpower=true,['Thunder Clap']=true,['Sunder Armor']=true,['Battle Shout']=true,['Commanding Shout']=true,Pummel=true,['Shield Bash']=true,Charge=true,Intercept=true,Attack=true}
local function Fixture(args)
    args=Copy(args or {});if args.pvp==nil then args.pvp=true end
    args.costs=args.costs or {};args.costs['Demoralizing Shout']=10
    local s,j,e=Base(args)
    e.UnitIsPlayer=function(unit) return unit=='player' or (s.pvp and not (s.pets and s.pets[unit]) and not (s.npcs and s.npcs[unit])) or false end
    e.UnitPlayerControlled=function(unit) return e.UnitIsPlayer(unit) or (s.pets and s.pets[unit]) or false end
    local oldKnown=e.GetSpellBookItemInfo
    e.GetSpellBookItemInfo=function(name)
        if s.unknown and s.unknown[name] then return nil end
        return oldKnown(name) or (utility[name] and 'SPELL')
    end
    e.GetSpellCooldown=function(name)
        local info=e.C_Spell.GetSpellCooldown(name);if info then return info.startTime,info.duration,info.isEnabled and 1 or 0 end
    end
    e.IsUsableSpell=e.C_Spell.IsSpellUsable
    j.SpellOnCD=function(name) return not j.RoutineAllows(name) or (s.cd and (s.cd[name] or 0)>0) or false end
    j.ReadyCastSpell=function(name,unit)
        if not j.RoutineAllows(name) or not e.GetSpellBookItemInfo(name) or j.SpellOnCD(name) or (s.gcd or 0)>.5 then return false end
        local usable,short=e.C_Spell.IsSpellUsable(name)
        return usable==true and not short and (not unit or e.C_Spell.IsSpellInRange(name,unit)==true)
    end
    j.isSlowed=function() return s.slowed~=false end
    j.isSlowProtected=function() return s.slowProtected or false end
    e.CheckInteractDistance=function(unit) return not (s.far and s.far[unit]) end
    e.UnitClass=function(unit) return unit=='player' and 'Warrior' or (s.targetClass or 'Warrior'),unit=='player' and 'WARRIOR' or (s.targetClass or 'WARRIOR') end
    e.IsEquippedItemType=function(kind) return kind=='Shields' and s.shield or false end
    j.WarriorAdaptiveContext.canSlam=function() return not s.noSlam and not s.noWeapon and j.RoutineAllows('Slam') end
    e.UnitCastingInfo=function(unit)
        if unit=='player' then return s.casting and 'Slam' or nil end
        if s.targetCast then return s.targetCast,nil,nil,(s.now-1)*1000,(s.now+.2)*1000,nil,nil,s.notInterruptible end
    end
    e.UnitChannelInfo=function(unit) if unit~='player' and s.targetChannel then return s.targetChannel,nil,nil,nil,nil,nil,s.notInterruptible end end
    j.spellsBigHealsInterrupt={'Flash Heal'};j.spellsImportantInterrupt={};j.spellsCcInterrupt={'Polymorph'}
    function s:dodge()
        e.CombatLogGetCurrentEventInfo=function() return self.now,'SWING_MISSED',false,'player',nil,nil,nil,'enemy1',nil,nil,nil,'DODGE',false end
        self:warriorEvent('COMBAT_LOG_EVENT_UNFILTERED')
    end
    return s,j,e
end
local function Mask(j,actions,options)
    j.RoutineContext={mode='adaptive',policy=2,state={},allEnabled=false,actions=actions or {},options=options or {},defaultShout='Battle Shout'}
end
local noUtilities={}
for action in pairs(utility) do noUtilities[action]=false end
noUtilities['Battle Stance']=false
-- Identical core state yields identical core decisions in PvE and PvP.
for _,count in ipairs({1,2,4}) do
    for _,rage in ipairs({15,25,40,60,100}) do
        for _,moving in ipairs({false,true}) do
            for _,cd in ipairs({0,4}) do
                local args={enemies=count,rage=rage,moving=moving,cd={['Mortal Strike']=cd,Whirlwind=cd},options={adaptive_cooldowns=false,adaptive_berserker_rage=false,adaptive_aoe_trinkets=false}}
                local p,jp=Fixture(args);Mask(jp,Copy(noUtilities),args.options)
                args.pvp=false;local v,jv=Fixture(args);Mask(jv,Copy(noUtilities),args.options)
                local pa,va=p:action(),v:action()
                Check(pa==va,'shared core decision N'..count..' R'..rage..' move='..tostring(moving)..' CD'..cd..' '..tostring(pa)..' / '..tostring(va))
            end
        end
    end
end
local s,j,e=Fixture({enemies=2,rage=25,cd={['Mortal Strike']=4,Whirlwind=4},options={adaptive_sweeping=false}})
Check(s:action()=='Slam','PvP AoE Slam uses actual cost instead of Original 60/90 gate')
s,j=Fixture({rage=25,cd={['Mortal Strike']=4,Whirlwind=4},slowed=false})
Check(s:action()=='Slam','immediate Slam remains ahead of slow utility')
s,j=Fixture({rage=80,moving=true,slowed=false})
Check(s:action()=='Hamstring','Original slow preempts ordinary core damage')
s.slowProtected=true;Check(s:action()~='Hamstring','slow immunity preserved')
s.slowProtected=false;s.auras={{'Hamstring',0,2}};s.slowed=true
Check(s:action()=='Hamstring','Original under-3s slow refresh preserved')
s.auras={{'Hamstring',0,10}};Check(s:action()~='Hamstring','healthy slow does not refresh')
s,j=Fixture({enemies=2,rage=80,moving=true,slowed=false})
Check(s:action()=='Piercing Howl','Original AoE slow preserved')
s,j=Fixture({rage=80,moving=true,slowed=false,buffs={Evasion=true}})
Check(s:action()=='Piercing Howl','Evasion uses Original Howl condition')
s,j=Fixture({targetCast='Flash Heal',casting=true})
Check(s:action()=='Stopcasting','priority interrupt cancels current Slam')
s.casting=false;Check(s:action()=='Pummel','Pummel follows cancellation')
s.stance=1;Check(s:action()=='Berserker Stance','Original Pummel stance preparation')
s.shield=true;s.noWeapon=true;Check(s:action()=='Shield Bash','equipped shield interrupt precedes two-hand enforcement')
s,j=Fixture({targetCast='Unlisted spell'})
Check(s:action()~='Pummel','Original priority interrupt list retained')
s,j=Fixture({targetChannel='Flash Heal'})
Check(s:action()=='Pummel','Original channel interrupt retained')
s,j=Fixture({targetCast='Flash Heal',notInterruptible=true})
Check(s:action()~='Pummel','non-interruptible target excluded')
s,j=Fixture({outOfRange=true,outOfCombat=true,stance=1})
Check(s:action()=='Charge','Original Charge retained')
s,j=Fixture({outOfRange=true,stance=1})
Check(s:action()=='Berserker Stance','Original Intercept preparation retained')
s.stance=3;Check(s:action()=='Intercept','Original Intercept retained')
s,j=Fixture({outOfRange=true,slowed=false,noShout=true,cd={Intercept=4}})
Check(s:action()=='Piercing Howl','range-gap slow precedes missing shout')
s,j=Fixture({stance=1,rage=25,moving=true,cd={['Mortal Strike']=4,Whirlwind=4}})
Check(s:action()=='Thunder Clap','Original TC class/stance rule retained despite Adaptive PvE TC default off')
s.auras={{'Thunder Clap',0,10}};Check(s:action()~='Thunder Clap','existing TC suppresses repeat')
s,j=Fixture({stance=1,rage=25,moving=true,targetClass='MAGE',cd={['Mortal Strike']=4,Whirlwind=4}})
Check(s:action()~='Thunder Clap','TC does not expand to caster targets')
s,j=Fixture({rage=25,moving=true,cd={['Mortal Strike']=4,Whirlwind=4},auras={{'Demoralizing Shout',0,20}}})
Check(s:action()=='Sunder Armor','Original PvP Sunder remains on while Adaptive PvE support is off')
Mask(j,{['Sunder Armor']=false});Check(s:action()~='Sunder Armor','Sunder action off suppresses utility')
s,j=Fixture({rage=25,moving=true,cd={['Mortal Strike']=4,Whirlwind=4},auras={{'Expose Armor',0,20}}})
Check(s:action()~='Sunder Armor','Original Expose suppression retained')
s,j=Fixture({rage=10,targetClass='ROGUE',since=2,swing=1.5,cd={['Mortal Strike']=4,Whirlwind=4}})
s:dodge();Check(s:action()=='Battle Stance','Rogue Overpower preparation skips forbidden Berserker Rage')
s.stance=1;Check(s:action()=='Overpower','Original Overpower follows stance')
-- Explicit Demo request: same established refresh rule, as a core-safe PvP fallback.
s,j=Fixture({rage=25,moving=true,cd={['Mortal Strike']=4,Whirlwind=4}})
Check(s:action()=='Demoralizing Shout','missing Demo fallback even with adaptive_demo default off')
s.auras={{'Demoralizing Shout',0,6}};Check(s:action()~='Demoralizing Shout','healthy Demo is retained')
s.auras={{'Demoralizing Shout',0,5}};Check(s:action()=='Demoralizing Shout','Demo refresh at five seconds')
Mask(j,{['Demoralizing Shout']=false});Check(s:action()~='Demoralizing Shout','Demo step disabled')
Mask(j,{}, {demo=false});Check(s:action()~='Demoralizing Shout','Original Demo preference disabled')
s,j=Fixture({rage=5,moving=true,cd={['Mortal Strike']=4,Whirlwind=4}})
Check(s:action()~='Demoralizing Shout','Demo requires actual rage')
s,j=Fixture({rage=100,moving=true});Check(core[s:action()],'ready core precedes Demo')
s,j=Fixture({rage=15,since=3.3,swing=.2,cd={['Mortal Strike']=4,Whirlwind=4}})
Check(s:action()~='Demoralizing Shout' and j.WarriorAdaptive.state.reason=='wait_swing','Demo respects imminent Slam wait')
s,j=Fixture({rage=25,gcd=1,moving=true,cd={['Mortal Strike']=4,Whirlwind=4}})
Check(s:action()~='Demoralizing Shout','Demo respects GCD')
-- Always-off policy overrides all old/new settings, both single and AoE.
for _,count in ipairs({1,3}) do
    for _,stance in ipairs({1,3}) do
        for _,rage in ipairs({0,10,20,50,100}) do
            s,j=Fixture({enemies=count,stance=stance,rage=rage,execute=true,moving=true,since=2,swing=1.5,trinket=true,
                learned={Bloodrage=true,['Berserker Rage']=true,['Death Wish']=true,Recklessness=true},
                options={adaptive_cooldowns=true,adaptive_aoe_trinkets=true,adaptive_berserker_rage=true,adaptive_recklessness=true}})
            for tick=1,3 do
                Check(not disabled[s:action()],'forbidden PvP ability never selected');s.now=s.now+.2
            end
        end
    end
end
for _,instance in ipairs({'arena','pvp'}) do
    s,j=Fixture({pvp=false,instance=instance,enemies=3,npcs={target=true,nameplate1=true,nameplate2=true,nameplate3=true},trinket=true,learned={Bloodrage=true,['Death Wish']=true}})
    Check(j.WarriorAdaptive:Owns('target'),'PvP instance activates adaptive even for selected NPC')
    Check(not disabled[s:action()] and j.WarriorAdaptive.state.enemies==1,'unselected NPCs do not inflate PvP coverage')
end
s,j=Fixture({enemies=4,pets={nameplate2=true},npcs={nameplate3=true},totems={nameplate4=true}})
s:action();Check(j.WarriorAdaptive.state.enemies==2,'player and pet counted; NPC and totem excluded')
s,j=Fixture({enemies=3,excluded={nameplate3=true},options={adaptive_sweeping=false}})
Check(s:action()~='Whirlwind' and s:action()~='Cleave' and s:action()~='Sweeping Strikes','observed CC suppresses area damage')
s,j=Fixture({queued='Heroic Strike',rage=40})
Check(s:action()=='Stopcasting','Adaptive PvP cancels unfunded queue')
s,j=Fixture({queued='Cleave',enemies=1})
Check(s:action()=='Stopcasting','Adaptive PvP cleans up AoE-to-single queue')
s,j=Fixture({queued='Heroic Strike',enemies=3})
Check(s:action()=='Stopcasting','Adaptive PvP cleans up single-to-AoE queue')
s,j=Fixture({gcd=1,rage=100,swing=.4,since=3.1})
Check(s:action()=='Heroic Strike','PvP funded HS shares PvE swing gate')
s,j=Fixture({gcd=1,rage=100,swing=.4,since=3.1,enemies=3,options={adaptive_sweeping=false}})
Check(s:action()=='Cleave','PvP funded Cleave shares PvE budget')
s,j=Fixture({rage=15,since=3.3,swing=.2,cd={['Mortal Strike']=4,Whirlwind=4}})
Mask(j,Copy(noUtilities))
Check(s:action()==nil and j.WarriorAdaptive.state.reason=='wait_swing','short prospective swing wait shared')
j.RoutineContext.actions.Slam=false
Check(s:action()~= 'Slam' and j.WarriorAdaptive.state.reason~='wait_swing','disabled Slam releases prospective wait')
for _,args in ipairs({{lost=true},{friendly=true},{targetDead=true},{dead=true},{mounted=true},{casting=true},{unreliable=true},{moving=true},{swingGUID='other'}}) do
    args.rage=25;args.cd={['Mortal Strike']=4,Whirlwind=4}
    s,j=Fixture(args);Check(s:action()~='Slam','invalid/movement/cast/foreign swing rejects Slam')
end
s,j=Fixture({rage=25,cd={['Mortal Strike']=4,Whirlwind=4}})
Check(s:action()=='Slam','valid initial target');s.lost=true
Check(not core[s:action()],'target loss clears core intent');s.lost=false;s.swingGUID='other';s.now=s.now+.2
Check(s:action()~='Slam','reacquisition cannot reuse foreign swing')
-- Actual catalog, production binding identities, independent compiled placements.
s,j,e=Fixture({enemies=3,rage=80,moving=true,options={adaptive_sweeping=false}})
local hotkeys=Read('Core/Hotkeys.lua');hotkeys=hotkeys:sub(1,assert(hotkeys:find('function Hotkeys:CreateStaticBar()',1,true))-1)
setfenv(assert(loadstring(hotkeys)),e)('OliaEyes6',j)
local c=Attach(j,e,'WARRIOR')
j.Options.Refresh=function() end -- Routine behavior fixture, no live UI widgets.
Check(not c.definitions['warrior.adaptive'].validationError,'Adaptive validates against production action identities')
for _,row in ipairs(c.rows['Warrior.adaptivePvp'].rows) do Check(c.definitions['warrior.adaptive'].stepByID[row[2]],'declared PvP action '..row[2]) end
c:GetThreads()[1]={{id='warrior.adaptive',steps={Whirlwind=false},options={adaptive_sweeping=false}}}
c:GetThreads()[2]={{id='warrior.adaptive',steps={},options={adaptive_sweeping=false}}}
c:Compile();local a,b=c.plans[1][1],c.plans[2][1]
j.RoutineContext=a;local without=First(j.warriorAdaptive('target'))
j.RoutineContext=b;local with=First(j.warriorAdaptive('target'))
Check(without~='Whirlwind' and with=='Whirlwind','independent compiled PvP masks')
Check(a.state~=b.state,'independent PvP decision state')
for _,step in ipairs(c.definitions['warrior.adaptive'].steps) do
    if not step.locked then
        b.actions[step.id]=false;b.allEnabled=false;j.RoutineContext=b
        Check(First(j.warriorAdaptive('target'))~=step.id,'disabled PvP step '..step.id)
        b.actions[step.id]=true
    end
end
j.RoutineContext=nil
local alloff={};for _,step in ipairs(c.definitions['warrior.adaptive'].steps) do if not step.locked then alloff[step.id]=false end end
c:GetThreads()[2]={{id='warrior.adaptive',steps=alloff,options={}}};c:Compile()
Check(#c.plans[2]==0,'all optional actions off releases dispatch ownership')
-- Original and WoWSims preserve the exact original PvP row output.
local function Snapshot(rows) local out={};for i,r in ipairs(rows) do out[i]=tostring(r[1])..':'..tostring(r[2])..':'..tostring(r[3]) end;return table.concat(out,'|') end
for _,mode in ipairs({'original','wowsims'}) do
    for _,count in ipairs({1,3}) do
        for _,stance in ipairs({1,3}) do
            s,j=Fixture({mode=mode,enemies=count,stance=stance,slowed=false})
            Check(Snapshot(s.oldUniversal('target'))==Snapshot(j.warriorUniversal('target')),'Original/WoWSims PvP untouched')
        end
    end
end
print('Adaptive PvP: '..checks..' shared-core, Original-utility, masks and context checks passed (mocked client).')
