-- Standalone Lua 5.1 tests of actual routines with optional enemy contexts.
-- Optional first argument: task checkpoint directory for valid-target comparisons.
local baseline = ...
local checks = 0
local function Check(value, why) assert(value, why); checks = checks + 1 end
local function Read(path) local f=assert(io.open(path)); local s=f:read('*a'); f:close(); return s end
local function PrefixFactory(path, boundary, factory)
    local s=Read(path); local stop=assert(s:find(boundary,1,true))
    return assert(loadstring(s:sub(1,stop-1)..'\nreturn '..factory))()
end
local WarriorContext = PrefixFactory('tests/WarriorOptions.test.lua', 'local function Snapshot(rows)', 'Context')
local targetless = { ['Battle Shout']=true, ['Commanding Shout']=true, ['Berserker Stance']=true,
    ['Defensive Stance']=true, ['Berserker Rage']=true, Bloodrage=true, ['Shield Block']=true,
    Whirlwind=true, ['Sweeping Strikes']=true, ['Demoralizing Shout']=true, ['Thunder Clap']=true,
    Rampage=true, Stopcasting=true, Stopattack=true, Equip2H=true, EquipDW=true, EquipShield=true,
    EquipFastOffHand=true, EquipSlowOffHand=true, Trinkets=true }
local function Eligible(rows, action)
    for _, row in ipairs(rows) do if row[2]==action and row[3] then return true end end
    return false
end
local function AssertNoEnemyAttacks(rows, label)
    for _, row in ipairs(rows) do
        if row[3] then Check(targetless[row[2]],label..': unexpected no-enemy action '..tostring(row[2])) end
    end
end
local function GuardUnitReads(env, j)
    local function Guard(holder, name, positions)
        local old=holder[name]
        if not old then return end
        holder[name]=function(...)
            for _, index in ipairs(positions) do
                local unit=select(index,...)
                assert(unit~=nil and unit~=false, name..' received absent unit')
            end
            return old(...)
        end
    end
    for _, name in ipairs({'UnitExists','UnitHealth','UnitHealthMax','UnitGUID','UnitIsPlayer','UnitPlayerControlled','UnitIsDeadOrGhost','UnitClassification','UnitLevel','UnitName','UnitCreatureType','UnitIsPVP','UnitAura','UnitCastingInfo','UnitChannelInfo','CheckInteractDistance'}) do Guard(env,name,{1}) end
    Guard(env,'UnitCanAttack',{1,2}); Guard(env,'UnitIsUnit',{1,2})
    Guard(env,'GetComboPoints',{1,2}); Guard(env,'IsSpellInRange',{2})
    if env.C_Spell then Guard(env.C_Spell,'IsSpellInRange',{2}) end
    Guard(j,'inMeleeRange',{1}); Guard(j,'Debuff',{2}); Guard(j,'unitCacheBuff',{1})
    Guard(j,'checkPveInterrupt',{1}); Guard(j,'isCasting',{1})
end
local function Warrior(s,path)
    local j,env=WarriorContext(s,path)
    local exists=env.UnitExists
    env.UnitExists=function(unit)
        if unit=='target' or unit=='softenemy' then return s.hasEnemy and true or false end
        return exists(unit)
    end
    env.UnitCanAttack=function(_,unit) return unit~="player" and unit~="friendly" end
    env.UnitAffectingCombat=function() return s.combat or false end
    local usable=env.IsUsableSpell
    env.IsUsableSpell=function(spell)
        if (spell=='Battle Shout' or spell=='Commanding Shout') and (s.rage or 0)<10 then return false,true end
        return usable(spell)
    end
    j.ReadyCastSpell=function(spell)
        local ok,noPower=env.IsUsableSpell(spell)
        return ok and not noPower and not (s.cooldowns and s.cooldowns[spell]) and not s.dead
    end
    j.actionHasRange=setmetatable({}, {__index=function(_,spell) return not targetless[spell] end})
    GuardUnitReads(env,j)
    return j,env
end
local warriorCases=0
for _, form in ipairs({1,2,3}) do
 for _, combat in ipairs({false,true}) do
  for _, enemies in ipairs({0,1,3}) do
   for _, kind in ipairs({'arms','fury','tank'}) do
    local s={hasEnemy=false,combat=combat,enemies=enemies,stance=form,rage=80,fury=kind=='fury',thread=kind=='tank' and 5 or 2}
    local j,env=Warrior(s)
    local routine=kind=='arms' and j.warriorArms or kind=='fury' and j.warriorFury or j.warriorTank
    for _, context in ipairs({false,'target','player'}) do
        local rows=routine(context or nil)
        AssertNoEnemyAttacks(rows,kind)
        Check(#rows>0,kind..' still evaluates its own rows')
        if enemies==0 then
            Check(Eligible(rows,kind=='tank' and 'Commanding Shout' or 'Battle Shout'),kind..' keeps shout eligible without enemy')
            Check(not Eligible(rows,'Whirlwind'),kind..' does not use offensive AoE in an empty area')
        end
    end
    -- Reuse the same routine caches across target appearance and loss.
    s.hasEnemy=true; routine('target'); s.hasEnemy=false
    AssertNoEnemyAttacks(routine(nil),kind..' target lost')
    warriorCases=warriorCases+1
   end
  end
 end
end
for _, kind in ipairs({'arms','fury','tank'}) do
 for _, reason in ipairs({'rage','cooldown'}) do
    local s={enemies=0,stance=3,rage=reason=='rage' and 0 or 80,fury=kind=='fury',thread=kind=='tank' and 5 or 2}
    if reason=='cooldown' then s.cooldowns={['Battle Shout']=true,['Commanding Shout']=true} end
    local j=Warrior(s)
    local rows=(kind=='arms' and j.warriorArms or kind=='fury' and j.warriorFury or j.warriorTank)(nil)
    Check(not Eligible(rows,'Battle Shout') and not Eligible(rows,'Commanding Shout'),kind..' preserves shout '..reason..' gate')
 end
end
-- Dead enemies do not suppress self maintenance or leave hostile rows eligible.
for _,kind in ipairs({'arms','fury','tank'}) do
    local j,env=Warrior({hasEnemy=true,rage=80,stance=3,enemies=0,fury=kind=='fury',thread=kind=='tank' and 5 or 2})
    env.UnitIsDeadOrGhost=function(unit) return unit=='target' end
    local rows=(kind=='arms' and j.warriorArms or kind=='fury' and j.warriorFury or j.warriorTank)('target')
    AssertNoEnemyAttacks(rows,kind..' dead target')
    Check(Eligible(rows,kind=='tank' and 'Commanding Shout' or 'Battle Shout'),kind..' shout survives dead target')
end
-- Defensive conditions use actual observed attackers, even without selection.
local defenseState={combat=true,rage=80,stance=2,enemies=3,thread=5}
local defense,defenseEnv=Warrior(defenseState)
defenseEnv.UnitIsUnit=function(a,b) return a==b or (a:match('^nameplate%d+target$')~=nil and b=='player') end
Check(Eligible(defense.warriorTank(nil),'Shield Block'),'Shield Block uses observed attackers without selected enemy')
defenseState.combat=false
Check(not Eligible(defense.warriorTank(nil),'Shield Block'),'Shield Block retains combat gate')
defenseState.combat=true;defenseState.rage=0
Check(not Eligible(defense.warriorTank(nil),'Shield Block'),'Shield Block retains rage gate')
-- Actual dispatcher and Engine: each active Warrior route reaches existing rows.
for _, thread in ipairs({1,2,3,5}) do
 local j,env=Warrior({enemies=0,stance=thread==5 and 2 or 3,rage=80,thread=thread})
 j.GetPlayerClass=function() return 'WARRIOR' end
 local action,context
 j.Cast={CastSpell=function(_,spell,unit) action,context=spell,unit;return true end}
 setfenv(assert(loadfile('Rotation.lua')),env)('OliaEyes6',j)
 setfenv(assert(loadfile('Core/Engine.lua')),env)('OliaEyes6',j)
 local e=j.Engine
 e.initialized=true;e.activeThread=thread;e.rotation=j.Rotation:new();e.pixelReset={clear=function() end}
 e.rotationSets={warriorArmsPveMaintenance={j.warriorArmsPveMaintenance},warriorUniversal={j.warriorUniversal},warriorArms={j.warriorArms},warriorTank={j.warriorTank},warriorThread3AoE={j.warriorThread3AoE},follower={function() return {} end}}
 assert(loadfile('tests/RoutineConfigFixture.lua'))()(j,env,'WARRIOR')
 e:ProcessRotation()
 Check(thread==3 and action==nil or thread~=3 and action==(thread==5 and 'Commanding Shout' or 'Battle Shout'),'Engine executes only owned default branches on thread '..thread..', got '..tostring(action))
 if thread~=3 then Check(context=='player' and j.CurrentCast.targetGUID=='player','player execution context on thread '..thread) end
end
print('OptionalEnemy Warrior: '..warriorCases..' context combinations; '..checks..' checks passed')

local DruidSetup = PrefixFactory('tests/DruidMaintenanceTriage.test.lua', 'local modulePath =', 'Setup')
local function Druid(s,path)
    local j,env=DruidSetup(path or 'Routines/Druid.lua',false,{})
    env.GetShapeshiftForm=function() return s.form or 0 end
    env.UnitExists=function(unit) return unit~='target' and unit~='softenemy' or s.hasEnemy or false end
    env.UnitCanAttack=function(_,unit) return unit~='player' and unit~='friendly' end
    env.UnitIsDeadOrGhost=function(unit) return s.dead and unit=='target' or false end
    env.UnitIsPlayer=function(unit) return unit=='player' or s.pvp or false end
    env.UnitIsPVP=function() return s.pvp or false end
    env.UnitCreatureType=function() return 'Humanoid' end
    env.UnitName=function(unit) return unit end
    env.UnitClassification=function() return 'normal' end
    env.UnitHealth=function() return 10000 end
    env.UnitHealthMax=function() return 10000 end
    env.UnitPower=function(_,kind) if kind==0 then return 1000 end; return s.energy or 80 end
    env.UnitPowerMax=function() return 1000 end
    env.UnitAttackPower=function() return 1000,0,0 end
    env.UnitAffectingCombat=function() return s.combat or false end
    env.GetComboPoints=function() return s.cp or 0 end
    env.IsStealthed=function() return s.stealth or false end
    env.IsCurrentSpell=function() return false end
    env.IsPlayerSpell=function() return true end
    env.IsSpellInRange=function(_,unit) return s.outOfRange and 0 or 1 end
    env.CheckInteractDistance=function() return not s.outOfRange end
    env.GetInventoryItemLink=function() return nil end
    env.GetInventoryItemID=function() return nil end
    env.GetNumGroupMembers=function() return 0 end
    local plates={}; for i=1,(s.enemies or 0) do plates[i]={unit='nameplate'..i} end
    env.C_NamePlate={GetNamePlates=function() return plates end}
    j.GetNameplateUnitToken=function(p) return p.unit end
    j.IsEnemyNameplateEligibleForAoE=function(unit) return unit~=nil and unit~='player' and env.UnitExists(unit) end
    j.Debuff=function(name) return s.demoCovered and name=='Demoralizing Roar' or false end
    j.DebuffEffectValues=function() return nil,0,0 end
    j.unitCacheBuff=function() return false end
    j.inMeleeRange=function() return not s.outOfRange end
    j.TimeUntilTick=function() return 0.4 end
    j.isSlowed=function() return s.slowed or false end
    j.ImNotBehindUnit=function() return false end
    j.targetedByCount=function() return s.attackers or 0 end
    j.ReadyCastSpell=function(spell) return not (s.blocked and s.blocked[spell]) end
    j.GetPlayerClass=function() return 'DRUID' end
    j.actionHasRange=setmetatable({}, {__index=function(_,spell)
        return spell~='Cat Form' and spell~="Tiger's Fury" and spell~='Swipe' and spell~='Demoralizing Roar'
            and spell~='Equip2H' and spell~='EquipDW' and spell~='EquipShield' and spell~='Omen of Clarity'
    end})
    GuardUnitReads(env,j)
    return j,env
end
local druidSelf={['Cat Form']=true,["Tiger's Fury"]=true,Swipe=true,['Demoralizing Roar']=true,Equip2H=true,EquipDW=true,EquipShield=true}
local function CheckDruidRows(rows)
    for _,row in ipairs(rows) do if row[3] then Check(druidSelf[row[2]],'unexpected Druid action without enemy '..row[2]) end end
end
for _,form in ipairs({0,1,3,5}) do
 for _,enemies in ipairs({0,1,3}) do
  for _,stealth in ipairs({false,true}) do
    local s={form=form,enemies=enemies,stealth=stealth,energy=80}
    local j,env=Druid(s)
    for _,unit in ipairs({false,'target','player'}) do CheckDruidRows(j.dpsSet(unit or nil)) end
    s.hasEnemy=true;j.dpsSet('target');s.hasEnemy=false
    CheckDruidRows(j.dpsSet(nil))
    if enemies==0 then
        local rows=j.dpsSet(nil)
        Check(not Eligible(rows,'Swipe') and not Eligible(rows,"Tiger's Fury") and not Eligible(rows,'Cat Form'),'Druid does not spam idle offensive actions')
    end
    if form==1 and enemies>=2 then Check(Eligible(j.dpsSet(nil),'Swipe'),'Bear Swipe uses nearby enemies without selection') end
  end
 end
end
for _,form in ipairs({0,1,3,5}) do
    local j=Druid({hasEnemy=true,dead=true,form=form,enemies=0})
    CheckDruidRows(j.dpsSet('target'))
end
local s={form=3,enemies=0,energy=80,slowed=true}
local d,de=Druid(s)
Check(Eligible(d.dpsSet(nil),'Cat Form'),'root/slow break keeps existing full-Furor gate without enemy')
s.form=0;s.slowed=false
Check(Eligible(d.dpsSet(nil),'Cat Form'),'powershift recovery survives target loss')
s={form=1,enemies=3,attackers=3}
d,de=Druid(s)
Check(Eligible(d.dpsSet(nil),'Demoralizing Roar'),'Bear checks nearby debuffs without selected enemy')
s.demoCovered=true
Check(not Eligible(d.dpsSet(nil),'Demoralizing Roar'),'Bear does not reapply covered area debuff')
-- Friendly Omen route remains independent of the optional enemy path.
d.unitCache.player={isMe=true,isTank=false}
Check(Eligible(d.buffSet('player'),'Omen of Clarity'),'Omen still uses original friendly buff block')

-- Rogue has only hostile actions; nil/friendly/dead contexts remain inert.
local r,re=Druid({hasEnemy=true,dead=true})
setfenv(assert(loadfile('Routines/Rogue.lua')),re)('OliaEyes6',r)
Check(#r.rogueDpsSet(nil)==0 and #r.rogueDpsSet('player')==0 and #r.rogueDpsSet('target')==0,'Rogue safely handles optional enemy')

local function RowSnapshot(rows)
    local result={}
    for i,row in ipairs(rows) do result[#result+1]=table.concat({i,tostring(row[1]),tostring(row[2]),tostring(row[3])},'|') end
    return table.concat(result,'\n')
end
if baseline then
 for _,form in ipairs({0,1,3,5}) do
  for _,enemies in ipairs({0,1,3}) do
   for _,pvp in ipairs({false,true}) do
    for _,stealth in ipairs({false,true}) do
     local state={form=form,enemies=enemies,pvp=pvp,stealth=stealth,energy=80,hasEnemy=true}
     local current=Druid(state)
     local old=Druid(state,baseline..'/Routines/Druid.lua')
     Check(RowSnapshot(current.dpsSet('target'))==RowSnapshot(old.dpsSet('target')),'Druid valid-target rows preserved')
    end
   end
  end
 end
end
-- Include a selected enemy without any visible nameplate and out-of-range states.
if baseline then
 for _,kind in ipairs({'arms','fury','tank'}) do
  for _,stance in ipairs({1,2,3}) do
   for _,enemies in ipairs({0,1,3}) do
    for _,combat in ipairs({false,true}) do
     for _,outOfRange in ipairs({false,true}) do
      for _,rage in ipairs({0,15,80}) do
       local state={hasEnemy=true,combat=combat,stance=stance,enemies=enemies,outOfRange=outOfRange,rage=rage,fury=kind=='fury',thread=kind=='tank' and 5 or 2}
       local current=Warrior(state)
       local old=Warrior(state,baseline..'/Routines/Warrior.lua')
       local routine=kind=='arms' and 'warriorArms' or kind=='fury' and 'warriorFury' or 'warriorTank'
       Check(RowSnapshot(current[routine]('target'))==RowSnapshot(old[routine]('target')),'Warrior valid-target rows preserved: '..kind..' stance='..stance..' plates='..enemies..' rage='..rage..' range='..tostring(not outOfRange))
      end
     end
    end
   end
  end
 end
end
-- Driverless follower: self form/rest checks remain in the same routine block.
local function FollowerSetup(driver)
    local j,env=Druid({combat=true})
    j.unitCache={player={currLife=0.5}}
    j.GetPlayerClass=function() return 'DRUID' end
    env.UnitExists=function(unit) return unit=='player' or unit==driver end
    env.UnitIsFriend=function(_,unit) return unit=='player' or unit==driver end
    env.UnitIsUnit=function(a,b) return a==b end
    env.IsInInstance=function() return false,'none' end
    env.IsOutdoors=function() return true end
    env.UnitCastingInfo=function() return nil end
    env.UnitChannelInfo=function() return nil end
    env.IsMounted=function() return false end
    env.IsFlyableArea=function() return false end
    env.GetUnitSpeed=function() return 0 end
    env.GetCurrentMapContinent=function() return 1 end
    env.GetContainerNumSlots=function() return 0 end
    env.UnitAura=function() return nil end
    env.GetSpellInfo=function(spell) return spell end
    setfenv(assert(loadfile('Routines/Follower.lua')),env)('OliaEyes6',j)
    GuardUnitReads(env,j)
    return j,env
end
local f,fe=FollowerSetup(nil)
local rows=f.followerSet('player')
Check(Eligible(rows,'Tree of Life'),'driverless Tree of Life keeps original danger conditions')
Check(not Eligible(rows,'Follow') and not Eligible(rows,'Mount'),'no driver means no follow or mirrored mount')
-- Selection ignores a ranged row in nil context without starving a later self row.
local selected,selectedUnit
f.Cast={CastSpell=function(_,spell,unit) selected,selectedUnit=spell,unit;return true end}
f.actionHasRange={Moonfire=true,['Omen of Clarity']=false}
setfenv(assert(loadfile('Rotation.lua')),fe)('OliaEyes6',f)
local rot=f.Rotation:new()
Check(rot:dpsRotate({function(unit) Check(unit==nil,'nil reaches existing routine');return {{'bad enemy','Moonfire',true},{'self','Omen of Clarity',true}} end},1),'nil context selects eligible lower self row')
Check(selected=='Omen of Clarity' and selectedUnit=='player','ranged spell never redirected to player')
print('OptionalEnemy complete: '..checks..' checks passed')
