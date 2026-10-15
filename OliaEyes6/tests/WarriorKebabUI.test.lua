-- Lua 5.1: actual overlay callbacks and profile state; no live rendering claim.
local checks=0
local function Check(ok,why) assert(ok,why);checks=checks+1 end
local f=assert(io.open('tests/RoutineConfig.test.lua'));local source=f:read('*a');f:close()
local Fixture=assert(loadstring(source:sub(1,assert(source:find('local legacy=',1,true))-1)..'\nreturn Fixture'))()
local j,e,state,frames=Fixture(nil,'WARRIOR')
local c,options=j.RoutineConfig,j.Options
Check(c:Add(2,'warrior.kebab'),'Kebab can be added through registry')
local function Owner()
    for _,row in ipairs(frames) do if row:IsShown() and row.kind=='routine' and row.thread==2 and row.index==2 then return row end end
    error('missing Kebab overlay row')
end
local owner=Owner();Check(owner~=nil,'Kebab appears in overlay')
owner.stepsButton.scripts.OnClick(owner.stepsButton)
local popup=options.routineSteps
local function Visible(id,option)
    for _,row in ipairs(frames) do if row.parent==popup.content and row:IsShown() and row.id==id and not not row.option==not not option then return row end end
end
local def=c.definitions['warrior.kebab']
Check(#def.options==11 and #def.steps==24,'all authored controls registered')
Check(not Visible('mainhand_queue',true),'obsolete experiment preference is not displayed')
Check(not Visible('aggressive_filler',true),'aggressive Hamstring exception is absent from HUD')
local hs=assert(Visible('Heroic Strike',false))
Check(hs.description:find('42/37/67',1,true) and hs.description:find('shared GCD',1,true),'HUD tooltip explains exact payment and clustered cores')
Check(assert(Visible('Hamstring',false)).description:find('already funded',1,true),'HUD describes preserving a funded queue')
Check(assert(Visible('Battle Shout',false)).description:find('>=1.5s',1,true),'HUD shows ordinary buff core-gap guard')
local labels={};for _,option in ipairs(def.options) do labels[option.key]=option.label end
Check(labels.sunder_initial=='Init Sunder Armor' and labels.sunder_stack=='Stack Sunder Armor','requested Sunder mode labels retain saved keys')
Check(#def.views[1].sections==2,'exactly two PvE blocks')
Check(def.views[1].sections[1].label=='PvE Single target' and def.views[1].sections[2].label=='PvE AoE','clear PvE block names')
Check(def.views[1].sections[1].description:find('No enemy:',1,true)~=nil,'targetless guard is documented without an extra block')
-- Every branch exposes readable conditions and preserves authored priorities.
for _,view in ipairs(def.views) do
    for _,section in ipairs(view.sections) do
        local order={}
        for index,step in ipairs(section.steps) do
            Check(type(step.summary)=='string' and #step.summary>0,'visible condition '..section.label..'/'..step.id)
            order[step.id]=index
        end
        if order.Hamstring then
            Check(order['Mortal Strike']<order.Hamstring and order['Victory Rush']<order.Hamstring,'cores and free filler precede paid filler '..section.label)
            if order['Demoralizing Shout'] then
                Check(order['Demoralizing Shout']<order['Heroic Strike'] and order['Demoralizing Shout']<order.Hamstring,'Demo maintenance precedes new queue/filler '..section.label)
            end
        end
        if order['Demoralizing Shout'] then
            Check(order['Demoralizing Shout']<order['Sunder Armor'] and order['Sunder Armor']<order['Mortal Strike'],'urgent maintenance is visible ahead of damage')
        end
        if order.Cleave then Check(order['Sweeping Strikes']<order.Cleave and order.Cleave<order.Whirlwind and order.Whirlwind<order['Mortal Strike'],'AoE funded queue and WW precede spare MS') end
        if order['Heroic Strike'] and order.Bloodrage then
            Check(section.description:find('before Bloodrage',1,true)~=nil,'queued HS early-core priority is explained '..section.label)
        end
    end
end
for _,step in ipairs(def.steps) do
    local row=assert(Visible(step.id,false),'missing action control '..step.id)
    Check(row.check~=nil,'action has checkbox '..step.id)
    if step.locked then Check(row.locked,'cleanup is required')
    else
        row.check.scripts.OnClick(row.check)
        Check(c:GetEntry(2,2).steps[step.id]==false and not c.plans[2][2].actions[step.id],'action switch compiles '..step.id)
        assert(Visible(step.id,false)).check.scripts.OnClick(assert(Visible(step.id,false)).check)
        Check(c:GetEntry(2,2).steps[step.id]==true and c.plans[2][2].actions[step.id],'action re-enabled '..step.id)
    end
end
for _,option in ipairs(def.options) do
    local row=assert(Visible(option.key,true),'missing preference '..option.key)
    local expected=not row.checked;row.check.scripts.OnClick(row.check)
    Check(c:GetEntry(2,2).options[option.key]==expected and c.plans[2][2].options[option.key]==expected,'preference saves/compiles '..option.key)
end
state.combat=true
Visible('Heroic Strike',false).check.scripts.OnClick(Visible('Heroic Strike',false).check)
Check(c.pending and c:GetEntry(2,2).steps['Heroic Strike']==false and c.plans[2][2].actions['Heroic Strike'],'combat defers action change')
Visible('execute_ms',true).check.scripts.OnClick(Visible('execute_ms',true).check)
Check(c.plans[2][2].options.execute_ms==true and c:GetEntry(2,2).options.execute_ms==false,'combat defers preference change')
state.combat=false;c:Compile()
Check(not c.plans[2][2].actions['Heroic Strike'] and c.plans[2][2].options.execute_ms==false,'combat-end applies both changes')
popup.tabs[2].scripts.OnClick(popup.tabs[2])
Check(popup.viewID=='pvp' and not Visible('execute_ms',true),'PvP unavailable view has no irrelevant preferences')
popup.tabs[1].scripts.OnClick(popup.tabs[1])
Check(Visible('execute_ms',true)~=nil,'PvE preferences restored')
Check(c:Add(4,'warrior.kebab'),'independent placement allowed')
Check(c.plans[4][1].actions['Heroic Strike'] and c.plans[4][1].options.execute_ms==false and c.plans[4][1].options.mainhand_queue==nil,'standard queue uses HS action switch without experiment preference')
c:GetEntry(2,2).options.mainhand_queue=false
c:GetEntry(2,2).options.aggressive_filler=true
c:Compile()
Check(c:GetEntry(2,2).options.mainhand_queue==false and c.plans[2][2].options.mainhand_queue==nil,'historical experiment false is preserved raw but not compiled')
-- Rebuild the real registry/UI against the same saved profiles to verify reload semantics.
local db=e.OliaEyes6_Settings
local j2,e2=Fixture(db,'WARRIOR')
Check(j2.RoutineConfig:GetEntry(2,2).id=='warrior.kebab','identity survives reload')
Check(j2.RoutineConfig.plans[2][2].options.mainhand_queue==nil and j2.RoutineConfig:GetEntry(2,2).options.mainhand_queue==false,'retired experiment false survives reload only as raw historical data')
Check(j2.RoutineConfig.plans[2][2].options.aggressive_filler==nil and j2.RoutineConfig:GetEntry(2,2).options.aggressive_filler==true,'retired aggressive true survives reload only as raw historical data')
Check(j2.RoutineConfig.plans[2][2].actions['Heroic Strike']==false and j2.RoutineConfig.plans[2][2].options.execute_ms==false,'explicit false survives reload')
for _,frame in ipairs(frames) do Check(not frame.scripts.OnUpdate,'Kebab controls add no UI polling') end
print('WarriorKebabUI: '..checks..' checks passed')
