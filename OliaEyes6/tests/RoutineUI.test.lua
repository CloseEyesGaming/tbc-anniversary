-- Actual Lua 5.1 UI callbacks with mocked frames/events. No claim of live rendering.
local checks=0
local function Check(ok,why) assert(ok,why);checks=checks+1 end
local f=assert(io.open('tests/RoutineConfig.test.lua'));local source=f:read('*a');f:close()
local boundary=assert(source:find('local legacy=',1,true))
local Fixture=assert(loadstring(source:sub(1,boundary-1)..'\nreturn Fixture'))()
local j,e,s,frames,timers=Fixture()
local options,c=j.Options,j.RoutineConfig
local function Row(kind,thread,index)
    for _,frame in ipairs(frames) do
        if frame:IsShown() and frame.kind==kind and frame.thread==thread and frame.index==index then return frame end
    end
    error('missing row: '..kind..'/'..thread..'/'..tostring(index))
end
local function Pointer(frame)
    for _,f in ipairs(frames) do f.mouseOver=false end
    if frame then frame.mouseOver=true end
end
local function Align(text,left,right,why)
    local a,b=text.anchors[left],text.anchors[right]
    Check(a and b and a.relativePoint==b.relativePoint,why)
end
local function Listening()
    local count=0
    for _,frame in ipairs(frames) do if frame.events.GLOBAL_MOUSE_DOWN then count=count+1 end end
    return count
end
local function Mouse(button)
    for _,frame in ipairs(frames) do
        if frame.events.GLOBAL_MOUSE_DOWN then frame.scripts.OnEvent(frame,'GLOBAL_MOUSE_DOWN',button or 'LeftButton') end
    end
end
local function Escape()
    -- Same name lookup/hide contract as the verified UIParentPanelManager.
    for _,name in ipairs(e.UISpecialFrames) do if e[name] and e[name]:IsShown() then e[name]:Hide() end end
end
local function Timers() for _,callback in ipairs(timers) do callback() end end
local function MenuChoice(label)
    local menu=options.routineMenu
    Check(menu and menu:IsShown(),'menu open before selection')
    for _,frame in ipairs(frames) do
        if frame.parent==menu.content and frame:IsShown() and frame.item and frame.item.label==label then
            frame.scripts.OnClick(frame);return
        end
    end
    error('missing menu choice: '..label)
end
local function OpenAdd(thread)
    local row=Row('add',thread);Pointer(row);row.scripts.OnClick(row,'LeftButton')
    return options.routineMenu,row
end
Check(options.frame:GetWidth()==400 and options.frame.fill.color[4]>.9,'readable dark panel')
Check(Listening()==0,'no global click listener without a popup')
Align(options.status,'BOTTOMLEFT','BOTTOMRIGHT','footer stays on one horizontal line')
Align(Row('thread',1).label,'LEFT','RIGHT','thread title stays above its subtitle')
Check(Row('routine',1,1).more.text:GetText()=='More','readable routine action control')
Check(Row('routine',1,1).stepsButton.text:GetText()=='Steps','readable step control')
for _,frame in ipairs(frames) do
    Check(not frame.scripts.OnUpdate,'UI has no polling loop')
    if frame.text and frame.text.GetText then
        local text=frame.text:GetText() or ''
        Check(not text:find('[\128-\255]'),'control label does not require unsupported glyphs: '..text)
    end
end
local menu,anchor=OpenAdd(4)
Check(menu:IsShown() and Listening()==1,'opening registers the outside-click event')
Align(menu.title,'TOPLEFT','TOPRIGHT','menu title stays in header')
Check(menu.clamped and options.frame.clamped,'panels clamp to screen')
Pointer(menu);Mouse();Check(menu:IsShown(),'clicking inside menu retains it')
Pointer(anchor);Mouse();anchor.scripts.OnClick(anchor,'LeftButton')
Check(not menu:IsShown() and Listening()==0,'second opener click closes the menu')
menu=OpenAdd(4);Pointer();Mouse('MiddleButton');Check(menu:IsShown(),'unrelated mouse button does not dismiss')
Mouse('RightButton');Check(not menu:IsShown() and Listening()==0,'outside right click dismisses')
menu=OpenAdd(4);Pointer();Mouse();Check(not menu:IsShown(),'outside left click dismisses')
menu=OpenAdd(4);Escape();Check(not menu:IsShown() and Listening()==0,'Escape closes the menu')
menu=OpenAdd(4);MenuChoice('Universal - Original')
Check(c:GetEntry(4,1).id=='warrior.original' and not menu:IsShown(),'selection adds exactly one placement and closes menu')
menu=OpenAdd(4);MenuChoice('Universal - Original (added)')
Check(#c:GetThreads()[4]==1 and menu:IsShown(),'disabled duplicate item does not add or dismiss')
menu.close.scripts.OnClick(menu.close);Check(not menu:IsShown(),'explicit Close button dismisses')
Check(c:Add(4,'warrior.fury'),'second routine fixture')
local row=Row('routine',4,1);row.more.scripts.OnClick(row.more)
MenuChoice('Move up');Check(menu:IsShown() and c:GetEntry(4,1).id=='warrior.original','first placement cannot move above start')
MenuChoice('Move down');Check(c:GetEntry(4,2).id=='warrior.original' and not menu:IsShown(),'More reorders the selected placement')
row=Row('routine',4,2);row.more.scripts.OnClick(row.more)
for _,item in ipairs(menu.items) do
    Check(item.label~='Priority preset' and item.label~='Tank' and item.label~='Baseline' and item.label~='Sweeping fallback','preset menu removed')
end
Check(c:GetEntry(4,2).policy==nil and c.plans[4][2].behavior.name=='baseline' and j.Engine.activeThread==0,'definition owns behavior without starting Engine')
menu:Hide()
row.more.scripts.OnClick(row.more);MenuChoice('Commanding Shout')
Check(c:GetEntry(4,2).defaultShout=='Commanding Shout','More selects default shout')
row.more.scripts.OnClick(row.more);MenuChoice('Remove from this thread')
Check(#c:GetThreads()[4]==1 and c:GetEntry(4,1).id=='warrior.fury','More removes only the selected placement')
row=Row('routine',4,1);Pointer(row);row.scripts.OnEnter()
local popup=options.routineSteps
Check(popup:IsShown() and not popup.pinned and Listening()==1,'hover opens dismissible step popup')
Pointer(popup);row.scripts.OnLeave();Timers();Check(popup:IsShown(),'entering hover popup keeps it open')
Pointer();popup.scripts.OnLeave();Timers();Check(not popup:IsShown(),'hover popup closes after leaving')
Pointer(row);row.stepsButton.scripts.OnClick(row.stepsButton)
Check(popup:IsShown() and popup.pinned,'Steps button pins the popup')
Pointer();popup.scripts.OnLeave();Timers();Check(popup:IsShown(),'pinned popup is usable after leaving opener')
Mouse();Check(not popup:IsShown() and Listening()==0,'outside click closes pinned popup')
Pointer(row);row.stepsButton.scripts.OnClick(row.stepsButton);row.stepsButton.scripts.OnClick(row.stepsButton)
Check(not popup:IsShown(),'second Steps click closes pinned popup')
row.stepsButton.scripts.OnClick(row.stepsButton);Escape();Check(not popup:IsShown(),'Escape closes step popup')
-- Exact rectangle scenarios supplement the intentionally simplified frame mock.
local getLeft,getRight,getTop,getBottom=row.GetLeft,row.GetRight,row.GetTop,row.GetBottom
local function Rect(left,right,top,bottom)
    row.GetLeft=function() return left end;row.GetRight=function() return right end
    row.GetTop=function() return top end;row.GetBottom=function() return bottom end
    popup:Hide();row.stepsButton.scripts.OnClick(row.stepsButton)
end
Rect(200,500,500,468)
Check(popup:GetWidth()==384 and popup.anchors.TOPLEFT.relativePoint=='TOPRIGHT','right-side space uses full width')
Rect(320,688,500,468)
Check(popup:GetWidth()==320 and popup.content:GetWidth()==280 and popup.scroll:GetWidth()==288,'narrow right-side popup resizes all content')
for _,frame in ipairs(frames) do
    if frame.parent==popup.content and frame:IsShown() then Check(frame:GetWidth()==280,'reused step row fits resized popup') end
end
Rect(640,1008,500,468)
Check(popup:GetWidth()==384 and popup.anchors.TOPRIGHT.relativePoint=='TOPLEFT','right screen edge opens steps to the left')
e.UIParent:SetSize(640,480)
Rect(136,504,400,368)
Check(popup.anchors.TOPLEFT.relativePoint=='BOTTOMLEFT' and popup:GetHeight()<=352,'no side space uses bounded space below toolbar')
Rect(136,504,100,68)
Check(popup.anchors.BOTTOMLEFT.relativePoint=='TOPLEFT' and popup:GetHeight()<=364,'near bottom opens above toolbar')
Rect(nil,nil,nil,nil)
Check(popup:IsShown() and popup.clamped,'unknown rectangle safely uses screen clamp')
e.UIParent:SetSize(640,200);options:Refresh()
Check(options.frame:GetHeight()<=e.UIParent:GetHeight()-16,'short viewport bounds main overlay height')
e.UIParent:SetSize(1024,768);options:Refresh();popup:Hide()
row.GetLeft,row.GetRight,row.GetTop,row.GetBottom=getLeft,getRight,getTop,getBottom
row.stepsButton.scripts.OnClick(row.stepsButton)
local other=Row('routine',1,1);other.scripts.OnEnter()
Check(popup.owner==row and popup.pinned,'hovering another routine does not replace pinned steps')
other.stepsButton.scripts.OnClick(other.stepsButton)
Check(popup.owner==other and popup.pinned,'explicit Steps selects another routine')
popup:Hide()
-- Combat edits show saved state immediately while retaining the compiled plan.
s.combat=true;row.stepsButton.scripts.OnClick(row.stepsButton)
local step
for _,frame in ipairs(frames) do if frame.parent==popup.content and frame.id=='Cleave' then step=frame end end
Check(step and step.checked,'authored enabled step is visible')
Pointer(popup);Mouse();step.check.scripts.OnClick(step.check)
Check(c:GetEntry(4,1).steps.Cleave==false and popup:IsShown(),'step click saves and keeps popup usable')
Check(c.plans[4][1].actions.Cleave==true and options.status:GetText()=='Saved / applies after combat','pending state matches unchanged active plan')
s.combat=false;c:Compile();Check(c.plans[4][1].actions.Cleave==false,'combat-end compilation applies edit')
options.profileButton.scripts.OnClick(options.profileButton)
Check(not popup:IsShown() and menu:IsShown(),'another menu replaces step popup')
MenuChoice('New profile')
local prompt=options.frame.namePrompt
Check(prompt:IsShown() and prompt.input.focused and Listening()==1,'profile prompt owns focus and outside dismissal')
Align(prompt.label,'TOPLEFT','TOPRIGHT','prompt validation message stays below input')
local previous=c.selected;prompt.input:SetText('Discard this');Pointer();Mouse()
Check(not prompt:IsShown() and not prompt.input.focused and c.selected==previous,'outside prompt click cancels without saving')
options.profileButton.scripts.OnClick(options.profileButton);MenuChoice('New profile')
prompt.input:SetText('');prompt.ok.scripts.OnClick(prompt.ok)
Check(prompt:IsShown() and prompt.label:GetText():find('unique',1,true),'invalid name stays open with useful message')
prompt.input:SetText('UI profile');prompt.ok.scripts.OnClick(prompt.ok)
Check(c.selected=='UI profile' and not prompt:IsShown() and not prompt.input.focused,'Save creates profile and releases focus')
options.profileButton.scripts.OnClick(options.profileButton);MenuChoice('Rename current profile')
Check(prompt.input:GetText()=='UI profile','rename prefills current name')
prompt.input:SetText('Unsaved');prompt.input.scripts.OnEscapePressed(prompt.input)
Check(c.selected=='UI profile' and not prompt:IsShown() and Listening()==0,'Escape cancels prompt and listener')
Check(options.routineScroll.track:IsShown(),'long thread list has scroll affordance')
options.routineScroll.scripts.OnMouseWheel(options.routineScroll,-10000)
local limit=options.routineContent:GetHeight()-options.routineScroll:GetHeight()
Check(options.routineScroll:GetVerticalScroll()==limit,'scroll clamps at bottom')
options.routineScroll.scripts.OnMouseWheel(options.routineScroll,10000)
Check(options.routineScroll:GetVerticalScroll()==0,'scroll clamps at top')
options.profileButton.scripts.OnClick(options.profileButton);options.frame:Hide()
Check(not menu:IsShown() and Listening()==0,'hiding main overlay closes separate popups and unsubscribes')
print('RoutineUI: '..checks..' layout, dismissal, focus and interaction checks passed (mocked client).')
