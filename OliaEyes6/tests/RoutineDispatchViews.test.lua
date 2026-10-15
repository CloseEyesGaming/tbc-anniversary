-- Lua 5.1: authored mode coverage against real evaluator outputs; no live client claim.
local checks=0
local function Check(ok,why) assert(ok,why);checks=checks+1 end
local function Read(path) local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local function Factory(path,boundary,result)
 local s=Read(path);return assert(loadstring(s:sub(1,assert(s:find(boundary,1,true))-1)..'\nreturn '..result))()
end
local actual=Factory('tests/RoutineSteps.test.lua','-- Every mask','{Context=Context,Mask=Mask,DruidSetup=DruidSetup}')
local function View(def,id) for _,v in ipairs(def.views) do if v.id==id then return v end end;error('missing view '..id) end
local function Section(def,view,label)
 for _,s in ipairs(View(def,view).sections) do if s.label==label then Check(type(s.when)=='string' and #s.when>0,'visible activation rule '..label);return s end end
 error('missing section '..def.id..' / '..view..' / '..label)
end
local function Has(s,id) for _,step in ipairs(s.steps) do if step.id==id then return true end end end
local function Covered(def,view,label,rows)
 local section=Section(def,view,label)
 for _,row in ipairs(rows) do if row[3] then
  Check(def.stepByID[row[2]]~=nil,'eligible action declared '..def.id..' / '..row[2])
  local shown=Has(section,row[2])
  if row[2]:find('^Equip') then for _,extra in ipairs(View(def,view).sections) do if extra.label:find('^Equipment') and Has(extra,row[2]) then shown=true end end end
  Check(shown,'eligible action absent from mode '..def.id..' / '..label..' / '..row[2])
 end end
end
local function Entry(j,c,id)
 local d=assert(c.definitions[id]);local e={definition=d,actions={},options={},behavior=d.behavior,policy=d.policy,mode=d.mode,defaultShout='Battle Shout',state={}}
 j.RoutineContext=e;return d,e
end
-- Use the real fixed action registries. Assert every canonical and saved variant registers.
local j,e=actual.Context({thread=2});local c=actual.Mask(j,e,'WARRIOR')
for _,id in ipairs({'warrior.original','warrior.arms','warrior.fury','warrior.wowsims','warrior.adaptive','warrior.tank','warrior.sweeping','warrior.maintenance'}) do Check(c.definitions[id]~=nil,'canonical registered '..id) end
for base,modes in pairs(c.variantIDs) do for _,policies in pairs(modes) do for _,id in pairs(policies) do Check(c.definitions[id]~=nil,'saved variant registered '..id) end end end
for _,pvp in ipairs({false,true}) do for _,aoe in ipairs({false,true}) do for _,fury in ipairs({false,true}) do for _,stance in ipairs({1,2,3}) do for _,rage in ipairs({10,50,120}) do for _,execute in ipairs({false,true}) do for _,sweeping in ipairs({false,true}) do
 local state={thread=2,pvp=pvp,fury=fury,enemies=aoe and 3 or 1,stance=stance,rage=rage,execute=execute,sweepingActive=sweeping}
 local j,e=actual.Context(state);local c=actual.Mask(j,e,'WARRIOR');local id=fury and 'warrior.fury' or 'warrior.arms';local d=Entry(j,c,id)
 local label=(fury and 'Fury' or 'Arms')..' / '..(aoe and 'AoE' or 'Single target')
 if fury then label=label..' / Bloodthirst' elseif aoe and not pvp and d.behavior.coreFirstAoE then label=label..' / Sweeping '..(sweeping and 'active' or 'inactive') end
 Covered(d,pvp and 'pvp' or 'pve',label,j[fury and 'warriorFury' or 'warriorArms']('target'))
 e.IsEquippedItemType=function(kind) return kind=='Shields' end
 local tank=Entry(j,c,'warrior.tank');Covered(tank,'shared',aoe and 'Tank / AoE' or 'Tank / Single target',j.warriorTank('target'))
 local sweep=Entry(j,c,'warrior.sweeping');local phase=sweeping and 'Burst' or aoe and 'AoE pooling' or 'Single overflow'
 Covered(sweep,pvp and 'pvp' or 'pve',(not pvp and not fury and 'Arms schedule' or 'Unscheduled')..' / '..phase,j.warriorThread3AoE('target'))
end end end end end end end
-- Exercise the Fury Mortal Strike branch with Bloodthirst actually unlearned.
for _,pvp in ipairs({false,true}) do for _,aoe in ipairs({false,true}) do
 local j,e=actual.Context({thread=2,fury=true,pvp=pvp,enemies=aoe and 3 or 1,rage=90})
 e.IsPlayerSpell=function(id) return id==12294 or id==12328 or id==1464 end;e.IsSpellKnown=e.IsPlayerSpell
 local c=actual.Mask(j,e,'WARRIOR');local d=Entry(j,c,'warrior.fury')
 Covered(d,pvp and 'pvp' or 'pve','Fury / '..(aoe and 'AoE' or 'Single target')..' / Mortal Strike',j.warriorFury('target'))
end end
-- Real off-hand return branches must remain selectable through their own declared metadata.
for _,aoe in ipairs({false,true}) do
 local j,e=actual.Context({thread=2,fury=true,enemies=aoe and 3 or 1})
 local c=actual.Mask(j,e,'WARRIOR');local d,entry=Entry(j,c,'warrior.fury')
 j.GetBestDWWeapons=function() return 'Main','Fast','Slow' end
 j.GetItemSpeed=function(item) return item=='Fast' and 1.5 or 2.5 end
 j.IsWeaponAvailable=function() return true end;j.CanSwapWeapons=function() return true end
 j.SwingTimer.GetTimeSinceLastSwing=function() return 0 end
 j.Hotkeys.EquipMacroTargets={EquipFastOffHand='Fast',EquipSlowOffHand='Slow'}
 local action=aoe and 'EquipSlowOffHand' or 'EquipFastOffHand';local rows=j.warriorFury('target')
 Check(rows[1][2]==action and rows[1][3],'real equipment branch '..action)
 Covered(d,'pve','Equipment / '..action,rows)
 entry.actions[action]=false;rows=j.warriorFury('target');Check(not rows[1][3],'equipment step disable respected')
end
-- Adaptive's mode also changes when nearby enemies make AoE unsafe.
local AdaptiveFixture=Factory('tests/WarriorAdaptive.test.lua','for count=1,10 do','Fixture')
for _,pvp in ipairs({false,true}) do for _,boss in ipairs({false,true}) do for _,aoe in ipairs({false,true}) do for _,unsafe in ipairs({false,true}) do
 local s,j,e=AdaptiveFixture({pvp=pvp,boss=boss,enemies=aoe and 3 or 1,excluded=unsafe and {nameplate2=true} or nil,rage=90,options={adaptive_sunder_initial=false,adaptive_sunder_stack=false,adaptive_thunder_clap=false,adaptive_demoralizing_shout=false}})
 local c=actual.Mask(j,e,'WARRIOR');local d,entry=Entry(j,c,'warrior.adaptive')
 local rows=j.warriorAdaptive('target');local state=j.WarriorAdaptive.state
 local label=state.unsafeAoE and 'Adaptive / AoE blocked' or state.aoe and 'Adaptive / AoE' or (not pvp and state.boss) and 'Adaptive / Boss' or 'Adaptive / Single target'
 Covered(d,pvp and 'pvp' or 'pve',label,rows)
end end end end
-- Production form fixtures with guarded API reads, including dynamic Claw/Lacerate replacements.
local optional=Read('tests/OptionalEnemy.test.lua')
local a=assert(optional:find('local function GuardUnitReads',1,true));local b=assert(optional:find('local function Warrior(s,path)',a,true))
local ds=assert(optional:find('local function Druid(s,path)',1,true));local de=assert(optional:find('local druidSelf=',ds,true))
local fs=assert(optional:find('local function FollowerSetup(driver)',1,true));local fe=assert(optional:find('local f,fe=FollowerSetup(nil)',fs,true))
local helpers=assert(loadstring('local DruidSetup=...\n'..optional:sub(a,b-1)..optional:sub(ds,de-1)..optional:sub(fs,fe-1)..'\nreturn {Druid=Druid,Follower=FollowerSetup}'))(actual.DruidSetup)
for _,pvp in ipairs({false,true}) do for _,aoe in ipairs({false,true}) do for _,form in ipairs({0,1,3,5}) do for _,moving in ipairs({false,true}) do for _,builder in ipairs({true,false}) do
 local state={hasEnemy=true,combat=true,pvp=pvp,enemies=aoe and 3 or 1,form=form,cp=2,blocked=builder and {} or {['Mangle (Cat)']=true,['Mangle (Bear)']=true}}
 local j,e=helpers.Druid(state);e.GetUnitSpeed=function() return moving and 7 or 0 end
 e.UnitGUID=function(unit) return unit=='target' and 'nameplate1' or unit end
 local c=actual.Mask(j,e,'DRUID');local d,entry=Entry(j,c,'druid.dps')
 if not builder then entry.actions['Mangle (Cat)']=false;entry.actions['Mangle (Bear)']=false end
 local label
 if form==3 then label='Cat / '..(builder and 'Mangle' or 'Claw')
 elseif form==1 then label='Bear / '..(aoe and 'AoE' or 'Single target')..' / '..(builder and 'Mangle' or 'Lacerate')
 else label=((form==5 and not pvp) and 'Moonkin' or 'Caster')..' / '..(moving and 'Moving' or 'Stationary') end
 Covered(d,pvp and 'pvp' or 'pve',label,j.dpsSet('target'))
end end end end end
-- The corrected Follower schema admits Tree of Life through the compiled support selector.
local f,env=helpers.Follower(nil);local c=actual.Mask(f,env,'DRUID');local d=Entry(f,c,'support.follower')
Covered(d,'shared','Driverless self maintenance',f.followerSet('player'))
Check(c.rows['Follower.followerCache'].rows[4][2]=='Tree of Life','schema matches the real fourth row')
f.actionHasRange={};f.actionIdentities={};local selected
f.Cast={CastSpell=function(_,spell) selected=spell;return true end}
setfenv(assert(loadfile('Rotation.lua')),env)('OliaEyes6',f);local rot=f.Rotation:new();f.Rotation=rot
c:SetEnabled(7,1,false);c:SetEnabled(7,2,true)
Check(c:Run({activeThread=7,rotation=rot}) and selected=='Tree of Life','Tree admitted by compiled support routine')
c:SetStep(7,2,'Tree of Life',false);selected=nil;Check(not c:Run({activeThread=7,rotation=rot}) and selected==nil,'Tree switch suppresses preparation and selection')
-- Shape assertions distinguish real branches from a union with relabeled headings.
local w,env=actual.Context({thread=2});local wc=actual.Mask(w,env,'WARRIOR')
for _,id in ipairs({'warrior.original','warrior.arms','warrior.fury'}) do
 local d=wc.definitions[id]
 for _,v in ipairs({'pve','pvp'}) do
  if id~='warrior.fury' then Check(Has(Section(d,v,'Arms / Single target'),'Mortal Strike'),'Arms core present') end
  if id~='warrior.arms' then Check(Has(Section(d,v,'Fury / AoE / Bloodthirst'),'Sweeping Strikes'),'Fury AoE branch present') end
 end
end
local fury=wc.definitions['warrior.fury'];Check(fury.stepByID.EquipFastOffHand and fury.stepByID.EquipSlowOffHand,'both real off-hand returns declared')
Check(not Has(Section(fury,'pve','Fury / Single target / Bloodthirst'),'Sweeping Strikes'),'single-target branch does not include AoE-only Sweeping')
local adaptive=wc.definitions['warrior.adaptive'];Check(not Has(Section(adaptive,'pve','Adaptive / Single target'),'Recklessness') and Has(Section(adaptive,'pve','Adaptive / Boss'),'Recklessness'),'boss cooldown branch separate')
Check(not Has(Section(adaptive,'pve','Adaptive / AoE'),'Heroic Strike'),'AoE has own queue branch')
Check(not Has(Section(adaptive,'pve','Adaptive / AoE blocked'),'Whirlwind'),'excluded enemy suppresses area attacks')
local druid,de=helpers.Druid({hasEnemy=true});local dc=actual.Mask(druid,de,'DRUID')
Check(not Has(Section(dc.definitions['druid.dps'],'pvp','Caster / Moving'),'Starfire'),'moving caster omits stationary casts')
Check(not Has(Section(dc.definitions['druid.dps'],'pvp','Caster / Stationary'),'Insect Swarm'),'stationary PvP omits moving-only DoT')
Check(#dc.definitions['druid.v6'].views==1 and Section(dc.definitions['druid.v6'],'shared','Raid scheduler / Filler'),'V6 exposes actual scheduler stages without invented PvP/AoE tabs')
for _,id in ipairs({'druid.v5','druid.buffs','druid.dispel','druid.tank','druid.raid','support.follower','support.fishing'}) do Check(#dc.definitions[id].views==1,'shared context table '..id) end
for _,class in ipairs({'HUNTER','MAGE','PALADIN','PRIEST','SHAMAN','WARLOCK'}) do local other,env=actual.Context({thread=2});local config=actual.Mask(other,env,class);for _,d in ipairs(config:Available(5)) do Check(d.class==class,'no placeholder routine invented') end end
print('RoutineDispatchViews: '..checks..' actual branch, registration and compiled selection checks passed (mocked client).')
