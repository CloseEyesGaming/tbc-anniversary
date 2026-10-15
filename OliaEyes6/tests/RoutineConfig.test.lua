-- Lua 5.1. Uses the real registry, catalog, Engine, profile migration and overlay.
-- Rendering, SavedVariables disk flush and actual WoW API outcomes require live verification.
local checks=0
local function Check(ok,why) assert(ok,why);checks=checks+1 end
local function Copy(value)
    if type(value)~="table" then return value end
    local out={};for k,v in pairs(value) do out[k]=Copy(v) end;return out
end
local file=assert(io.open("tests/Options.test.lua"));local source=file:read("*a");file:close()
local prefix=source:sub(1,assert(source:find("local checks = 0",1,true))-1)
local function Fixture(saved,class,character)
    local env=setmetatable({}, {__index=_G});env._G=env
    local base=setfenv(assert(loadstring(prefix.."\nreturn {methods=methods,frames=frames}")),env)()
    local methods,frames=base.methods,base.frames
    function methods:SetScrollChild(child) self.scrollChild=child end
    function methods:GetVerticalScroll() return self.scroll or 0 end
    function methods:SetVerticalScroll(value) self.scroll=value end
    function methods:EnableMouseWheel() end
    function methods:HookScript(event,callback)
        local old=self.scripts[event];self.scripts[event]=function(...) if old then old(...) end;callback(...) end
    end
    function methods:IsMouseOver() return self.mouseOver or false end
    function methods:ClearAllPoints() self.x,self.y,self.anchors=nil,nil,{} end
    function methods:GetLeft() local x=self:GetCenter();return x and x-self:GetWidth()/2 end
    function methods:GetRight() local x=self:GetCenter();return x and x+self:GetWidth()/2 end
    function methods:GetTop() local _,y=self:GetCenter();return y and y+self:GetHeight()/2 end
    function methods:GetBottom() local _,y=self:GetCenter();return y and y-self:GetHeight()/2 end
    function methods:SetAutoFocus() end
    function methods:SetMaxLetters() end
    function methods:SetFocus() self.focused=true end
    function methods:ClearFocus() self.focused=false end
    function methods:SetWordWrap(wrap) self.wordWrap=wrap end
    function methods:GetStringHeight()
        local length=#(self:GetText() or "")
        return self.wordWrap and 12*math.max(1,math.ceil(length/math.max(1,math.floor((self:GetWidth() or 300)/6)))) or 12
    end
    function methods:SetVertexColor(...) self.vertexColor={...} end
    function methods:SetColorTexture(...) self.color={...} end
    function methods:SetCheckedTexture(asset) self.checkedTexture=self:CreateTexture();self.checkedTexture.asset=asset end
    function methods:GetCheckedTexture() return self.checkedTexture end
    function methods:GetText() return self.textValue end
    function methods:Show()
        local hidden=not self.shown;self.shown=true
        if hidden and self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function methods:Hide()
        local shown=self.shown;self.shown=false
        if shown and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    env.UISpecialFrames={}
    local create=env.CreateFrame
    env.CreateFrame=function(kind,name,parent,template)
        local frame=create(kind,name,parent,template);frame.frameType=kind;frame.name=name
        if name then env[name]=frame end
        return frame
    end
    local timers={}
    env.C_Timer={After=function(_,callback) timers[#timers+1]=callback end}
    local state={class=class or "WARRIOR",name=character or "Tester",combat=false,pole=false}
    env.UnitClass=function() return state.class,state.class end
    env.UnitFullName=function() return state.name,"Realm" end
    env.GetRealmName=function() return "Realm" end
    env.InCombatLockdown=function() return state.combat end
    env.IsEquippedItemType=function() return state.pole end
    env.UnitCastingInfo=function() end
    local j={GetPlayerClass=function() return state.class end,CurrentCast={},RaidTrace={enabled=false}}
    env.OliaEyes6_Settings=saved
    setfenv(assert(loadfile("Core/Options.lua")),env)("OliaEyes6",j)
    local config=assert(loadfile("tests/RoutineConfigFixture.lua"))()(j,env,state.class)
    -- Restore the controllable identity/lockdown APIs after the helper bootstrap.
    env.UnitClass=function() return state.class,state.class end
    env.UnitFullName=function() return state.name,"Realm" end
    env.InCombatLockdown=function() return state.combat end
    local old=config.character;config.character=state.name.." - Realm"
    config.db.characters[config.character]=config.selected;config.db.characters[old]=nil
    setfenv(assert(loadfile("Core/Engine.lua")),env)("OliaEyes6",j)
    j.Engine.initialized=true;j.Engine.pixelReset={clear=function() end}
    j.Engine.rotation={rotate=function() return false end,dpsRotate=function() return false end}
    setfenv(assert(loadfile("Core/RoutineUI.lua")),env)("OliaEyes6",j)
    j.Options:Refresh()
    return j,env,state,frames,timers
end
local legacy={classes={WARRIOR={arms_pve_mode="wowsims",thread1_thunder_clap=false,
    thread2_sunder_routine=false,thread2_sweeping_strikes=false,wowsims_sunder_stack=true,default_shout="Commanding Shout"}}}
local j,e,s,frames,timers=Fixture(legacy)
local c=j.RoutineConfig
Check(c.definitions[c:GetEntry(1,2).id].legacyBase=="warrior.wowsims" and c.plans[1][2].behavior.name=="maintenance","migrate mode and behavior into routine identity")
Check(c.plans[1][1].actions["Thunder Clap"]==false,"migrate explicit false preparation switch")
Check(c.plans[2][1].options.sunderInitial==false and c.plans[2][1].options.sunderStack==false,"migrate Sunder switches")
Check(c.plans[2][1].actions["Sweeping Strikes"]==false,"migrate Sweeping false")
Check(c.plans[2][1].options.wowsims_sunder_stack==true,"migrate mode-specific options")
Check(c.plans[2][1].defaultShout=="Commanding Shout","migrate shout preference")
Check(j.Engine.activeThread==0,"Engine starts idle")
Check(#c.order>=25,"all implemented production routines registered")
for thread=1,6 do
    local list=c:Available(thread)
    Check(#list==#c:Available(1),"same class dropdown on every class thread")
    for _,def in ipairs(list) do Check(def.class=="WARRIOR" and def.kind=="class","class-only choices") end
end
for _,def in ipairs(c:Available(7)) do Check(def.kind=="support" and not def.class,"support has no class filter") end
Check(not c:Add(7,"warrior.original") and not c:Add(1,"support.follower"),"thread categories validated")
Check(c:Add(4,"warrior.original") and not c:Add(4,"warrior.original"),"add and reject duplicate")
Check(c:SetStep(4,1,"Slam",false),"disable selected placement step")
Check(c.plans[4][1].actions.Slam==false and c.plans[2][1].actions.Slam==true,"switch is independent across threads")
Check(c:SetStep(4,1,"Slam",true) and c.plans[4][1].actions.Slam==true,"re-enable restores step")
Check(not c:SetStep(4,1,"unknown",false),"reject unknown step")
Check(not c:SetStep(4,1,"Stopcasting",false),"required cleanup cannot be disabled")
local original=c.plans[4][1]
s.combat=true
c:SetStep(4,1,"Slam",false)
Check(c.pending and c.plans[4][1]==original and original.actions.Slam,"combat change leaves live plan intact")
Check(c:GetEntry(4,1).steps.Slam==false,"pending preference is saved")
s.combat=false;c:Compile()
Check(not c.pending and c.plans[4][1].actions.Slam==false,"combat end applies plan atomically")
local stored=Copy(c.db)
local reloaded=Fixture(stored)
Check(reloaded.RoutineConfig:GetEntry(4,1).steps.Slam==false,"step survives session initialization")
Check(reloaded.Engine.activeThread==0,"session restoration does not activate engine")
Check(c:NewProfile("Raid",true),"copy profile")
c:SetStep(4,1,"Slam",true)
local copied=c.selected
Check(c:SelectProfile("Fixture - Realm") and c:GetEntry(4,1).steps.Slam==false,"copy is independent")
Check(c:SelectProfile(copied) and c:GetEntry(4,1).steps.Slam==true,"copied changes persist")
Check(c:RenameProfile("Raid renamed") and c.db.characters[c.character]=="Raid renamed","rename updates character selection")
Check(not c:DeleteProfile(c.selected),"active profile is protected from deletion")
Check(c:DeleteProfile("Fixture - Realm"),"delete unused profile")
Check(not c:NewProfile("Raid renamed") and not c:NewProfile("bad|name"),"validate profile names")
s.class="DRUID";c:Compile()
Check(c:GetEntry(2,2).id=="druid.v6" and c:GetEntry(5,2).id=="druid.dps","class defaults are independent")
c:SetStep(2,2,"Healing Touch",false)
Check(c.plans[2][2].actions["Nature's Swiftness"]==false,"linked preparation follows action")
local v6Row
for _,frame in ipairs(frames) do if frame.kind=="routine" and frame.thread==2 and frame.index==2 then v6Row=frame end end
v6Row.scripts.OnEnter()
local preparation
for _,frame in ipairs(frames) do if frame.id=="Nature's Swiftness" and frame.check then preparation=frame end end
Check(preparation and preparation.locked and not preparation.checked,"popup shows blocked preparation")
preparation.scripts.OnClick()
Check(c:GetEntry(2,2).steps["Nature's Swiftness"]==nil,"blocked checkbox preserves independent saved choice")
c:SetStep(2,2,"Healing Touch",true);c:SetStep(2,2,"Nature's Swiftness",false)
Check(c.plans[2][2].actions["Nature's Swiftness"]==false and c.plans[2][2].actions["Healing Touch"],"independent prerequisite switch is retained")
local linked=c:GetEntry(2,2)
for _,step in ipairs(c.definitions[linked.id].steps) do linked.steps[step.id]=false end
linked.steps["Nature's Swiftness"]=true;c:Compile()
Check(#c.plans[2]==1,"only blocked preparation does not keep routine active")
linked.steps={};c:Compile()
s.class="WARRIOR";c:Compile()
Check(c:GetEntry(4,1).steps.Slam==true,"class switch retains Warrior configuration")
Check(c:Add(4,"warrior.fury"),"multiple routines")
Check(c:Move(4,2,-1) and c:GetEntry(4,1).id=="warrior.fury","change priority order")
Check(c:Remove(4,1) and c:GetEntry(4,1).id=="warrior.original","remove routine")
local calls={}
j.Engine:SetThread(4)
j.Engine.rotation.dpsRotate=function() calls[#calls+1]=j.RoutineContext.definition.id;return false end
Check(c:Add(4,"warrior.fury"),"add fallback")
c.definitions["warrior.original"].hold=function() return true end
Check(j.Engine:ProcessRotation() and #calls==1,"intentional wait stops fallback")
c.definitions["warrior.original"].hold=nil;calls={}
j.Engine:ProcessRotation()
Check(#calls==2 and calls[1]=="warrior.original" and calls[2]=="warrior.fury","fallthrough follows configured priority")
Check(j.RoutineContext==nil,"context is cleared after dispatch")
j.Engine.rotation.dpsRotate=function() return true end
c:SetEnabled(4,1,false);c:SetEnabled(4,2,false)
Check(not j.Engine:ProcessRotation(),"fully disabled thread emits no routine action")
c:ResetThread(4)
Check(#c:GetThreads()[4]==0,"reset restores originally empty thread")
-- Pole exclusivity is limited to an enabled fishing placement, not imposed on a manual follower-only list.
j.Engine:SetThread(7);s.pole=true
j.Engine.rotation.rotate=function() calls[#calls+1]=j.RoutineContext.definition.id;return true end
calls={};j.Engine:ProcessRotation();Check(calls[1]=="support.fishing","pole selects Fishing")
s.pole=false;calls={};j.Engine:ProcessRotation();Check(calls[1]=="support.follower","without pole selects Follower")
s.pole=true;c:SetEnabled(7,1,false);calls={};j.Engine:ProcessRotation();Check(calls[1]=="support.follower","manual follower remains usable with pole")
c:SetEnabled(7,1,true)
local threads=c:GetThreads();threads[4]={{id="missing",enabled=true},"corrupt",{id="warrior.original"},{id="warrior.original"}}
c:Compile()
Check(c.errors["4:1"] and c.errors["4:2"] and c.errors["4:4"] and #c.plans[4]==1,"invalid and duplicate placements are isolated")
Check(c:Remove(4,2),"corrupt placement remains removable")
-- Overlay interaction: real handlers update the selected placement and keep the hover menu open.
c:ResetThread(7);j.Options:Refresh()
local routineRow
for _,frame in ipairs(frames) do if frame.kind=="routine" and frame.thread==7 and frame.index==2 then routineRow=frame end end
Check(routineRow~=nil,"nested routine row is rendered")
routineRow.mouseOver=true;routineRow.scripts.OnEnter()
local popup,step
for _,frame in ipairs(frames) do
    if frame.owner==routineRow and frame.scroll and frame.content then popup=frame end
    if frame.id=="Mount" and frame.option==false then step=frame end
end
Check(popup and popup:IsShown() and step,"hover opens step dropdown")
step.scripts.OnClick()
Check(c:GetEntry(7,2).steps.Mount==false and popup:IsShown(),"step click saves and retains popup")
routineRow.mouseOver=false;popup.mouseOver=true;routineRow.scripts.OnLeave()
for _,timer in ipairs(timers) do timer() end
Check(popup:IsShown(),"moving into dropdown does not close it")
popup.mouseOver=false;popup.scripts.OnLeave()
for _,timer in ipairs(timers) do timer() end
Check(not popup:IsShown(),"leaving both surfaces closes dropdown")
j.Options.profileButton.scripts.OnClick(j.Options.profileButton)
Check(j.Options.routineMenu and #j.Options.routineMenu.items>=4,"profile dropdown provides management actions")
-- Every all-disabled action list is omitted from the runtime, rather than owning a pointless wait.
for _,def in ipairs(c:Available(1)) do
    local entries=c:GetThreads()[6];entries[1]={id=def.id,steps={}}
    for _,step in ipairs(def.steps) do if not step.locked then entries[1].steps[step.id]=false end end
    c:Compile();Check(#c.plans[6]==0,"all-disabled routine releases tick: "..def.id)
end
print("Routine configuration: "..checks.." profile, dispatch and UI checks passed (mocked client).")
