-- Lua 5.1: production metadata and actual UI callbacks. No live-rendering claim.
local checks=0
local function Check(ok,why) assert(ok,why);checks=checks+1 end
local function Factory(path,boundary,result)
    local f=assert(io.open(path));local source=f:read('*a');f:close()
    return assert(loadstring(source:sub(1,assert(source:find(boundary,1,true))-1)..'\nreturn '..result))()
end
local Fixture=Factory('tests/RoutineConfig.test.lua','local legacy=','Fixture')
local actual=Factory('tests/RoutineSteps.test.lua','-- Every mask','{Context=Context,Mask=Mask,DruidSetup=DruidSetup}')
local function View(def,id)
    for _,view in ipairs(def.views) do if view.id==id then return view end end
    error('missing view '..def.id..'/'..id)
end
local function Section(view,label)
    for _,section in ipairs(view.sections) do if section.label==label then return section end end
    error('missing section '..label)
end
local function Actions(section)
    local ids={};for _,step in ipairs(section.steps) do ids[#ids+1]=step.id end
    return table.concat(ids,'|')
end
local function Has(section,id)
    for index,step in ipairs(section.steps) do if step.id==id then return step,index end end
end
-- Load actual evaluators and the actual fixed binding registries, not just UI stubs.
local warrior,we=actual.Context({thread=2});local wc=actual.Mask(warrior,we,'WARRIOR')
local druid,de=actual.DruidSetup('Routines/Druid.lua',false,{});local dc=actual.Mask(druid,de,'DRUID')
for _,c in ipairs({wc,dc}) do
    for _,def in ipairs(c.order) do
        Check(type(def.views)=='table' and #def.views>0,'every registered definition has validated views: '..def.id)
        local covered={}
        for _,view in ipairs(def.views) do
            for _,section in ipairs(view.sections) do
                local seen={}
                for _,step in ipairs(section.steps) do
                    Check(def.stepByID[step.id]~=nil and not seen[step.id],'declared, deduplicated view action: '..def.id..'/'..step.id)
                    Check(step.locked==def.stepByID[step.id].locked,'required cleanup preserved')
                    seen[step.id]=true;covered[step.id]=true
                end
            end
        end
        for _,step in ipairs(def.steps) do Check(covered[step.id],'all existing switches reachable: '..def.id..'/'..step.id) end
    end
end
local dps=dc.definitions['druid.dps']
local pve=Section(View(dps,'pve'),'Moonkin / Moving');local pvp=Section(View(dps,'pvp'),'Caster / Moving')
Check(Actions(pve)=='Faerie Fire|Moonfire|Insect Swarm|Attack','PvE caster order')
Check(Actions(pvp)=='Moonfire|Insect Swarm|Faerie Fire|Attack','PvP caster order')
Check(not Has(pvp,'Equip2H') and Has(pvp,'Moonfire').summary:find('Moving',1,true),'context-specific short descriptions')
Check(not Has(pvp,'Faerie Fire').description:find('hasImprovedFaerieFire',1,true),'PvE conditions do not leak into PvP tooltips')
local cat=Section(View(dps,'pve'),'Cat / Mangle');local claw=Section(View(dps,'pve'),'Cat / Claw')
Check(Has(cat,'Mangle (Cat)') and not Has(cat,'Claw') and Has(claw,'Claw') and not Has(claw,'Mangle (Cat)'),'Cat builder dispatch has separate steps')
local arms=Section(View(wc.definitions['warrior.arms'],'pvp'),'Arms / Single target')
local _,pummel=Has(arms,'Pummel');local _,bash=Has(arms,'Shield Bash');local _,slam=Has(arms,'Slam');local _,slow=Has(arms,'Hamstring')
Check(bash==pummel+1 and slam+1==slow,'dynamic PvP alternatives stay beside their authored rows')
local furyMS=Section(View(wc.definitions['warrior.original'],'pve'),'Fury / Single target / Mortal Strike')
Check(not Has(furyMS,'Mortal Strike').description:find('msReadyNoGCD',1,true),'Fury dynamic action excludes Arms-only source conditions')
local adaptive=wc.definitions['warrior.adaptive']
local primary=Section(View(adaptive,'pvp'),'Adaptive / Single target')
for _,id in ipairs({'Bloodrage','Berserker Rage','Death Wish','Recklessness','Trinkets'}) do Check(not Has(primary,id),'Adaptive PvP omits forbidden primary action '..id) end
for _,view in ipairs(adaptive.views) do for _,section in ipairs(view.sections) do Check(not section.label:find('fallback',1,true),'no cross-routine fallback section') end end
Check(Section(View(adaptive,'pve'),'Adaptive / Single target').description:find('not a fixed',1,true),'planner explains non-linear decisions')
for _,option in ipairs(View(adaptive,'pvp').options) do
    Check(not option.key:find('^adaptive_') or option.key=='adaptive_sweeping','only applicable Adaptive preferences in PvP')
end
local wowsims=View(wc.definitions['warrior.wowsims'],'pve')
Check(Has(Section(wowsims,'WoWSims AoE'),'Cleave') and Has(Section(wowsims,'WoWSims AoE'),'Sweeping Strikes'),'WoWSims dynamic AoE actions explained')
Check(#wc.definitions['support.follower'].views==1 and #dc.definitions['druid.v6'].views==1,'shared routines avoid unnecessary tabs')
-- Registration fails cleanly for incomplete or malformed presentation declarations.
wc:AddRows('View.fixture',{{'One','ViewOne',false},{'Two','ViewTwo',false}}, {'first','second'})
local calls=0
local function Register(views)
    return wc:Register({id='view.fixture',label='Fixture',source='tests/RoutineViews.test.lua',kind='support',selector='rotate',
        functions={function() calls=calls+1;error('UI discovery ran evaluator') end},rowSets={'View.fixture'},
        options={{key='viewOption',label='Option',default=true}},displayViews=views})
end
local function Block(steps,options) return {{id='shared',label='Steps',sections={{label='Actions',steps=steps}},options=options}} end
local ok,reason=Register(Block({{id='ViewOne'}},{}));Check(not ok and reason:find('missing',1,true),'missing declared switch rejected')
ok=Register(Block({{id='ViewOne'},{id='ViewTwo'}},{}));Check(not ok,'missing declared option rejected')
ok=Register(Block({{id='Unknown'}},{}));Check(not ok,'undeclared display action rejected')
ok=Register({{id='shared',label='Steps',sections={{label='Actions',rowSets={'Druid.dpsCasterCache'}}}}});Check(not ok,'foreign schema rejected')
ok=Register(Block({{id='ViewOne',before='Unknown'},{id='ViewTwo'}},{'viewOption'}));Check(not ok,'invalid dynamic anchor rejected')
ok=Register({{id='same',label='A',sections={{label='Actions',rowSets={'View.fixture'}}}},
    {id='same',label='B',sections={{label='Actions',rowSets={'View.fixture'}}}}});Check(not ok,'duplicate view rejected')
ok=Register({{id='shared',label='Steps',sections={{label='Actions',steps=true}}}});Check(not ok,'malformed section rejected')
ok=Register({{id='shared',label='Steps',sections={{label='Actions',when=true,rowSets={'View.fixture'}}}}});Check(not ok,'non-string activation rule rejected')
ok=Register({{id='shared',label='Steps',sections={{label='Actions',when='',rowSets={'View.fixture'}}}}});Check(not ok,'empty activation rule rejected')
ok=Register(nil);Check(ok and calls==0,'new definitions receive generic static view without evaluation')
-- Actual UI callbacks: tab selection, section state, masks and combat deferral.
local j,e,state,frames,timers=Fixture(nil,'DRUID')
local c,options=j.RoutineConfig,j.Options
local function Row(thread,index)
    for _,row in ipairs(frames) do if row:IsShown() and row.kind=='routine' and row.thread==thread and row.index==index then return row end end
    error('missing routine row')
end
local owner=Row(5,2);owner.stepsButton.scripts.OnClick(owner.stepsButton)
local popup=options.routineSteps
local function VisibleStep(id)
    for _,row in ipairs(frames) do if row.parent==popup.content and row:IsShown() and row.id==id then return row end end
end
local function Heading(text)
    for _,row in ipairs(frames) do if row.parent==popup.content and row:IsShown() and row.title==text then return row end end
    error('missing heading '..text)
end
local revision=c.revision
Check(popup.viewID=='pve' and popup.tabs[1]:IsShown() and popup.tabs[2]:IsShown(),'dual view opens with tabs')
popup.scroll:SetVerticalScroll(180);popup.tabs[2].scripts.OnClick(popup.tabs[2])
Check(popup.viewID=='pvp' and popup.pinned and popup.scroll:GetVerticalScroll()==0,'manual tab selection pins and resets scroll')
Check(c.revision==revision and c.definitions[c:GetEntry(5,2).id].id=='druid.dps','display tab does not change runtime mode or recompile')
local branch=Heading('- Caster / Moving')
Check(branch.summary:IsShown() and branch.summary:GetText():find('PvP-flagged',1,true) and branch.summary.wordWrap,'activation rule rendered with wrapping')
Check(branch:GetHeight()>=31+branch.summary:GetStringHeight(),'section height contains its activation text')
local moonfire=assert(VisibleStep('Moonfire'))
Check(moonfire.summary:IsShown() and moonfire.summary:GetText():find('Moving',1,true),'short branch explanation rendered')
state.combat=true;moonfire.check.scripts.OnClick(moonfire.check)
Check(c:GetEntry(5,2).steps.Moonfire==false and c.plans[5][2].actions.Moonfire==true,'combat edits retain active mask')
Check(popup.viewID=='pvp' and not VisibleStep('Moonfire').checked,'refresh retains tab and displays saved state')
popup.tabs[1].scripts.OnClick(popup.tabs[1])
Check(not VisibleStep('Moonfire').checked,'same switch shown disabled in other context')
Heading('- Moonkin / Moving').scripts.OnClick()
Check(Heading('+ Moonkin / Moving') and VisibleStep('Moonfire'),'collapsed branch leaves the stationary branch available')
options:Refresh();Check(Heading('+ Moonkin / Moving')~=nil,'refresh retains section state')
popup.tabs[2].scripts.OnClick(popup.tabs[2]);Check(VisibleStep('Moonfire')~=nil,'section collapse state independent per view')
state.combat=false;c:Compile();Check(c.plans[5][2].actions.Moonfire==false,'combat-end applies existing shared action mask')
Check(c:Add(6,'druid.dps'),'same routine can be placed in another thread')
Check(c.plans[6][2].actions.Moonfire==true,'different placement retains independent switches')
popup:Hide();owner=Row(1,2);owner.stepsButton.scripts.OnClick(owner.stepsButton)
Check(not popup.tabs[1]:IsShown() and not popup.tabs[2]:IsShown() and popup.viewID=='shared','switching to single view hides old tabs')
local ns=assert(VisibleStep("Nature's Swiftness"));c:SetStep(1,2,'Healing Touch',false)
Check(VisibleStep("Nature's Swiftness").locked and not VisibleStep("Nature's Swiftness").checked,'preparation dependency preserved in single view')
popup:Hide();local old=c:GetEntry(1,2).steps["Nature's Swiftness"];ns.check.scripts.OnClick(ns.check)
Check(c:GetEntry(1,2).steps["Nature's Swiftness"]==old,'hidden step callbacks cannot change settings')
for _,frame in ipairs(frames) do Check(not frame.scripts.OnUpdate,'views add no polling loop') end
print('RoutineViews: '..checks..' metadata, branch presentation and UI checks passed (mocked client).')
