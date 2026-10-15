local AddonName, jungle = ...
local Options, Config = jungle.Options, jungle.RoutineConfig
local WIDTH, ROW, VIEW = 400, 32, 416
local TEXT = {.90,.93,.96}
local MUTED = {.51,.58,.65}
local ACCENT = {.25,.81,.72}
local widgets, stepWidgets, menuWidgets = {}, {}, {}
local expanded = {true,true,true,true,true,true,true}
local EMPTY = {}
local popup, menu
local watcher = CreateFrame("Frame")

-- Simple frames only. Escape integration is verified against the Anniversary
-- UIParentPanelManager; outside clicks use the documented GLOBAL_MOUSE_DOWN event.
local function Visible(frame) return frame and frame:IsShown() end
local function Inside(frame) return Visible(frame) and frame:IsMouseOver() end
local function SyncWatcher()
    local prompt = Options.frame and Options.frame.namePrompt
    if Visible(popup) or Visible(menu) or Visible(prompt) then watcher:RegisterEvent("GLOBAL_MOUSE_DOWN")
    else watcher:UnregisterEvent("GLOBAL_MOUSE_DOWN") end
end
local function CloseSteps()
    if popup then popup:Hide() end
    GameTooltip:Hide()
end
local function CloseMenu()
    if menu then menu:Hide() end
    GameTooltip:Hide()
end
local function ClosePrompt()
    if Options.frame and Options.frame.namePrompt then Options.frame.namePrompt:Hide() end
end
local function CloseTransient()
    CloseSteps(); CloseMenu(); ClosePrompt()
end
watcher:SetScript("OnEvent",function(_, event, button)
    if event~="GLOBAL_MOUSE_DOWN" or (button~="LeftButton" and button~="RightButton") then return end
    local prompt = Options.frame and Options.frame.namePrompt
    if Inside(menu) or (Visible(menu) and Inside(menu.owner)) or Inside(prompt)
        or Inside(popup) or (Visible(popup) and Inside(popup.owner)) then return end
    CloseTransient()
end)
local function Tooltip(owner, title, description)
    GameTooltip:SetOwner(owner,"ANCHOR_RIGHT"); GameTooltip:SetText(title)
    GameTooltip:AddLine(description or "",1,1,1,true); GameTooltip:Show()
end
local function Label(text)
    -- Control labels are ASCII. Normalize old catalog dashes without changing IDs.
    return tostring(text or ""):gsub("\226\128\148","-"):gsub("\226\128\147","-")
end
local function Text(parent, font)
    local text=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlightSmall")
    text:SetTextColor(unpack(TEXT));text:SetJustifyH("LEFT");text:SetWordWrap(false)
    return text
end
local function Paint(frame)
    frame.edge=frame:CreateTexture(nil,"BACKGROUND")
    frame.edge:SetAllPoints();frame.edge:SetColorTexture(.18,.23,.28,.96)
    frame.fill=frame:CreateTexture(nil,"BACKGROUND",nil,1)
    frame.fill:SetPoint("TOPLEFT",1,-1);frame.fill:SetPoint("BOTTOMRIGHT",-1,1)
    frame.fill:SetColorTexture(.035,.049,.067,.96)
end
local function Button(parent, text, width, callback)
    local button=CreateFrame("Button",nil,parent)
    button:SetSize(width or 52,24);button:RegisterForClicks("LeftButtonUp")
    button.fill=button:CreateTexture(nil,"BACKGROUND");button.fill:SetAllPoints()
    button.fill:SetColorTexture(.10,.14,.18,.9)
    button.text=Text(button);button.text:SetAllPoints();button.text:SetJustifyH("CENTER");button.text:SetText(text)
    button:SetScript("OnClick",function(self) if not self.disabled then callback(self) end end)
    button:SetScript("OnEnter",function(self)
        if not self.disabled then self.fill:SetColorTexture(.14,.24,.27,1);self.text:SetTextColor(unpack(ACCENT)) end
        if self.hint then Tooltip(self,self.text:GetText(),self.hint) end
    end)
    button:SetScript("OnLeave",function(self)
        self.fill:SetColorTexture(.10,.14,.18,.9)
        self.text:SetTextColor(unpack(self.disabled and MUTED or TEXT));GameTooltip:Hide()
    end)
    return button
end
local function Checkbox(parent)
    local check=CreateFrame("CheckButton",nil,parent)
    check:SetSize(18,18)
    check.edge=check:CreateTexture(nil,"BACKGROUND");check.edge:SetAllPoints();check.edge:SetColorTexture(.28,.35,.41,1)
    check.fill=check:CreateTexture(nil,"BACKGROUND",nil,1)
    check.fill:SetPoint("TOPLEFT",2,-2);check.fill:SetPoint("BOTTOMRIGHT",-2,2);check.fill:SetColorTexture(.06,.09,.12,1)
    check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    check:GetCheckedTexture():SetVertexColor(unpack(ACCENT))
    return check
end
local function Scroll(parent, width, height)
    local scroll=CreateFrame("ScrollFrame",nil,parent);scroll:SetSize(width,height);scroll:EnableMouseWheel(true)
    local child=CreateFrame("Frame",nil,scroll);child:SetSize(width-8,1);scroll:SetScrollChild(child)
    scroll.track=scroll:CreateTexture(nil,"ARTWORK");scroll.track:SetPoint("TOPRIGHT",0,0);scroll.track:SetWidth(2)
    scroll.track:SetColorTexture(.12,.17,.21,1)
    scroll.thumb=scroll:CreateTexture(nil,"OVERLAY");scroll.thumb:SetWidth(2);scroll.thumb:SetColorTexture(.32,.46,.49,1)
    function scroll:Sync()
        local viewport,content=self:GetHeight(),child:GetHeight()
        local limit=math.max(0,content-viewport)
        self:SetVerticalScroll(math.max(0,math.min(limit,self:GetVerticalScroll())))
        if limit>0 then
            local thumb=math.max(18,viewport*viewport/content)
            self.track:SetHeight(viewport);self.track:Show()
            self.thumb:SetHeight(thumb);self.thumb:ClearAllPoints()
            self.thumb:SetPoint("TOPRIGHT",0,-(viewport-thumb)*self:GetVerticalScroll()/limit);self.thumb:Show()
        else self.track:Hide();self.thumb:Hide() end
    end
    scroll:SetScript("OnMouseWheel",function(self,delta)
        self:SetVerticalScroll(self:GetVerticalScroll()-delta*ROW*2);self:Sync()
    end)
    return scroll,child
end
local function Floating(name, width)
    local frame=CreateFrame("Frame",name,UIParent)
    frame:SetSize(width,80);frame:SetFrameStrata("TOOLTIP");frame:SetClampedToScreen(true);frame:EnableMouse(true)
    Paint(frame)
    frame.title=Text(frame,"GameFontHighlight");frame.title:SetPoint("TOPLEFT",12,-12);frame.title:SetPoint("TOPRIGHT",-68,-12)
    frame.close=Button(frame,"Close",48,function() frame:Hide() end);frame.close:SetPoint("TOPRIGHT",-8,-8)
    frame:SetScript("OnShow",SyncWatcher)
    frame:SetScript("OnHide",function(self)
        self.owner=nil;self.pinned=false;self.serial=(self.serial or 0)+1
        if self.input then self.input:ClearFocus() end
        GameTooltip:Hide();SyncWatcher()
    end)
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]=name end
    frame:Hide()
    return frame
end
local function ScheduleClose()
    if not Visible(popup) or popup.pinned then return end
    local serial=(popup.serial or 0)+1;popup.serial=serial
    C_Timer.After(.20,function()
        if popup.serial~=serial or not Visible(popup) or popup.pinned then return end
        if Inside(popup) or Inside(popup.owner) then return end
        CloseSteps()
    end)
end
local function Prompt(action)
    CloseTransient()
    local frame=Options.frame
    if not frame.namePrompt then
        local prompt=Floating("OliaEyes6_ProfilePrompt",WIDTH-16)
        prompt:SetHeight(118)
        prompt.label=Text(prompt);prompt.label:SetPoint("TOPLEFT",14,-82);prompt.label:SetPoint("TOPRIGHT",-14,-82)
        prompt.input=CreateFrame("EditBox",nil,prompt,"InputBoxTemplate")
        prompt.input:SetSize(WIDTH-118,24);prompt.input:SetPoint("TOPLEFT",16,-48)
        prompt.input:SetAutoFocus(false);prompt.input:SetMaxLetters(80)
        local function Submit()
            local name=(prompt.input:GetText() or ""):match("^%s*(.-)%s*$")
            local ok
            if prompt.action=="rename" then ok=Config:RenameProfile(name)
            else ok=Config:NewProfile(name,prompt.action=="copy") end
            if ok then prompt:Hide()
            else prompt.label:SetText("Choose a unique name (1-80 characters).");prompt.label:SetTextColor(1,.48,.42) end
        end
        prompt.ok=Button(prompt,"Save",58,Submit);prompt.ok:SetPoint("LEFT",prompt.input,"RIGHT",12,0)
        prompt.input:SetScript("OnEnterPressed",Submit)
        prompt.input:SetScript("OnEscapePressed",function() prompt:Hide() end)
        frame.namePrompt=prompt
    end
    local prompt=frame.namePrompt
    prompt.action=action;prompt:ClearAllPoints();prompt:SetPoint("TOPLEFT",frame,"TOPLEFT",8,-68)
    prompt.title:SetText(action=="rename" and "Rename profile" or action=="copy" and "Copy profile" or "New profile")
    prompt.label:SetText("Saved separately for each class.");prompt.label:SetTextColor(unpack(MUTED))
    prompt.input:SetText(action=="rename" and Config.selected or "");prompt:Show();prompt.input:SetFocus()
end
local function MenuRow(index)
    local row=menuWidgets[index]
    if row then return row end
    row=CreateFrame("Button",nil,menu.content);row:SetSize(308,28);row:RegisterForClicks("LeftButtonUp")
    row.fill=row:CreateTexture(nil,"BACKGROUND");row.fill:SetAllPoints();row.fill:SetColorTexture(1,1,1,0)
    row.dot=row:CreateTexture(nil,"ARTWORK");row.dot:SetSize(5,5);row.dot:SetPoint("LEFT",7,0);row.dot:SetColorTexture(unpack(ACCENT))
    row.label=Text(row);row.label:SetPoint("LEFT",20,0);row.label:SetPoint("RIGHT",-8,0)
    row:SetScript("OnClick",function()
        local item=row.item
        if not Visible(menu) or not item or item.disabled or not item.run then return end
        local run=item.run;CloseMenu();run()
    end)
    row:SetScript("OnEnter",function()
        local item=row.item
        if item and not item.disabled then row.fill:SetColorTexture(.14,.24,.27,1) end
        if item and item.description then Tooltip(row,item.label,item.description) end
    end)
    row:SetScript("OnLeave",function() row.fill:SetColorTexture(1,1,1,0);GameTooltip:Hide() end)
    menuWidgets[index]=row;return row
end
local function OpenMenu(owner, kind, thread)
    if Visible(menu) and menu.owner==owner and menu.kind==kind then CloseMenu();return end
    CloseTransient()
    if not menu then
        menu=Floating("OliaEyes6_RoutineMenu",336)
        menu.scroll,menu.content=Scroll(menu,316,280);menu.scroll:SetPoint("TOPLEFT",10,-42)
        menu.hint=Text(menu);menu.hint:SetPoint("BOTTOMLEFT",12,10);menu.hint:SetTextColor(unpack(MUTED))
        menu.hint:SetText("Click outside or press Escape to close")
        Options.routineMenu=menu
    end
    local items={}
    local function Add(label,run,checked,disabled,description)
        items[#items+1]={label=Label(label),run=run,checked=checked,disabled=disabled,description=description}
    end
    local function Heading(label) Add(label,nil,nil,true) end
    if kind=="profile" then
        menu.title:SetText("Profiles")
        for _,name in ipairs(Config:ProfileNames()) do
            local selected=name;Add(name,function() Config:SelectProfile(selected) end,Config.selected==name)
        end
        Heading("Manage profiles")
        Add("New profile",function() Prompt("new") end)
        Add("Copy current profile",function() Prompt("copy") end)
        Add("Rename current profile",function() Prompt("rename") end)
        for _,name in ipairs(Config:ProfileNames()) do
            if name~=Config.selected then local selected=name;Add("Delete: "..name,function() Config:DeleteProfile(selected) end) end
        end
    elseif kind=="routine" then
        local row=owner.row
        local saved=Config:GetEntry(row.thread,row.index)
        local def=saved and Config.definitions[saved.id]
        local entries=Config:GetThreads()[row.thread]
        menu.title:SetText(def and Label(def.label) or "Routine actions")
        Add("Move up",function() Config:Move(row.thread,row.index,-1) end,nil,row.index==1)
        Add("Move down",function() Config:Move(row.thread,row.index,1) end,nil,row.index==#entries)
        Add("Remove from this thread",function() Config:Remove(row.thread,row.index) end)
        if def and def.class=="WARRIOR" then
            Heading("Default shout")
            for _,name in ipairs({"Battle Shout","Commanding Shout"}) do
                local shout=name
                Add(name,function() saved.defaultShout=shout;Config:Changed() end,
                    (saved.defaultShout or Config:GetClass(true).options.default_shout or "Battle Shout")==shout)
            end
        end
    else
        menu.title:SetText("Add routine / Thread "..thread)
        local present={}
        for _,entry in ipairs(Config:GetThreads()[thread]) do if type(entry)=="table" then present[entry.id]=true end end
        local available=Config:Available(thread)
        if #available==0 then Add("No implemented routines for this class",nil,nil,true) end
        for _,def in ipairs(available) do
            local id=def.id
            local reason=def.validationError or (present[id] and "Already added to this thread.")
            Add(def.label..(present[id] and " (added)" or ""),function() Config:Add(thread,id) end,nil,reason~=nil,reason)
        end
    end
    menu.items,menu.owner,menu.kind=items,owner,kind
    for index,item in ipairs(items) do
        local row=MenuRow(index);row.item=item;row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-(index-1)*28)
        row.label:SetText(item.label);row.label:SetTextColor(unpack(item.disabled and MUTED or TEXT))
        row.fill:SetColorTexture(1,1,1,0)
        if item.checked then row.dot:Show() else row.dot:Hide() end
        row:Show()
    end
    for index=#items+1,#menuWidgets do menuWidgets[index]:Hide() end
    menu.content:SetHeight(math.max(1,#items*28))
    menu.scroll:SetHeight(math.min(280,UIParent:GetHeight()*.5,math.max(28,#items*28)))
    menu.scroll:SetVerticalScroll(0);menu.scroll:Sync();menu:SetHeight(menu.scroll:GetHeight()+74)
    menu.hint:SetText(#items*28>menu.scroll:GetHeight() and "Scroll for more / Escape to close" or "Click outside or press Escape to close")
    menu:ClearAllPoints();menu:SetPoint("TOPLEFT",owner,"BOTTOMLEFT",0,-4);menu:Show()
end
local function StepRow(index)
    local row=stepWidgets[index]
    if row then return row end
    row=CreateFrame("Button",nil,popup.content);row:SetSize(344,28)
    row.check=Checkbox(row);row.check:SetPoint("LEFT",4,0)
    row.label=Text(row);row.label:SetPoint("LEFT",row.check,"RIGHT",8,0);row.label:SetPoint("RIGHT",-8,0)
    row.summary=Text(row);row.summary:SetPoint("TOPLEFT",30,-23);row.summary:SetPoint("TOPRIGHT",-8,-23)
    row.summary:SetTextColor(unpack(MUTED))
    row.fill=row:CreateTexture(nil,"BACKGROUND");row.fill:SetAllPoints();row.fill:SetColorTexture(1,1,1,0)
    local function Click()
        if not Visible(popup) or not row:IsShown() or not popup.owner then return end
        if row.sectionClick then row.sectionClick();return end
        if row.locked then row.check:SetChecked(row.checked);return end
        if row.option then Config:SetOption(popup.thread,popup.index,row.id,not row.checked)
        else Config:SetStep(popup.thread,popup.index,row.id,not row.checked) end
    end
    row:SetScript("OnClick",Click);row.check:SetScript("OnClick",Click)
    local function Enter()
        popup.serial=(popup.serial or 0)+1;row.fill:SetColorTexture(.14,.24,.27,1);Tooltip(row,row.title,row.description)
    end
    local function Leave() row.fill:SetColorTexture(1,1,1,0);GameTooltip:Hide();ScheduleClose() end
    row:SetScript("OnEnter",Enter);row.check:SetScript("OnEnter",Enter)
    row:SetScript("OnLeave",Leave);row.check:SetScript("OnLeave",Leave)
    stepWidgets[index]=row;return row
end
local function PlaceSteps(owner)
    local screenWidth,screenHeight=UIParent:GetWidth(),UIParent:GetHeight()
    local left,right=owner:GetLeft(),owner:GetRight()
    local top,bottom=owner:GetTop(),owner:GetBottom()
    local width=math.min(384,screenWidth-16)
    local overhead=popup.overhead or 78
    local viewport=math.min(280,screenHeight*.5,math.max(28,screenHeight-overhead-16))
    popup:ClearAllPoints()
    if right and screenWidth-right-16>=280 then
        width=math.min(width,screenWidth-right-16)
        popup:SetPoint("TOPLEFT",owner,"TOPRIGHT",8,0)
    elseif left and left-16>=280 then
        width=math.min(width,left-16)
        popup:SetPoint("TOPRIGHT",owner,"TOPLEFT",-8,0)
    elseif top and bottom then
        local below,above=bottom-16,screenHeight-top-16
        if below>=above then
            viewport=math.min(viewport,math.max(28,below-overhead))
            popup:SetPoint("TOPLEFT",owner,"BOTTOMLEFT",0,-8)
        else
            viewport=math.min(viewport,math.max(28,above-overhead))
            popup:SetPoint("BOTTOMLEFT",owner,"TOPLEFT",0,8)
        end
    else
        -- Rect APIs may return nothing before layout; screen clamping is the fallback.
        popup:SetPoint("TOPLEFT",owner,"TOPRIGHT",8,0)
    end
    popup:SetWidth(width);popup.scroll:SetWidth(width-32);popup.content:SetWidth(width-40)
    return viewport
end
local ShowSteps
ShowSteps=function(owner, pinned)
    if Visible(popup) and popup.pinned and popup.owner~=owner and not pinned then return end
    if Visible(menu) or (Options.frame and Visible(Options.frame.namePrompt)) then return end
    local saved=Config:GetEntry(owner.thread,owner.index)
    local def=saved and Config.definitions[saved.id]
    if not def or owner.error then return end
    if not popup then
        popup=Floating("OliaEyes6_RoutineSteps",384)
        popup.scroll,popup.content=Scroll(popup,352,280);popup.scroll:SetPoint("TOPLEFT",12,-46)
        popup.hint=Text(popup);popup.hint:SetPoint("BOTTOMLEFT",12,10);popup.hint:SetTextColor(unpack(MUTED))
        popup.hint:SetPoint("BOTTOMRIGHT",-12,10)
        popup.hint:SetText("Switches shared across views / scroll for more")
        popup.tabs={}
        popup:SetScript("OnEnter",function() popup.serial=(popup.serial or 0)+1 end)
        popup:SetScript("OnLeave",ScheduleClose)
        Options.routineSteps=popup
    end
    local same=popup.thread==owner.thread and popup.index==owner.index and popup.id==saved.id
    if not same then popup.pinned=false;popup.viewID=nil;popup.sectionState={} end
    if pinned then popup.pinned=true end
    popup.owner,popup.thread,popup.index,popup.id=owner,owner.thread,owner.index,saved.id
    popup.serial=(popup.serial or 0)+1
    local view=def.views[1]
    for _,candidate in ipairs(def.views) do if candidate.id==popup.viewID then view=candidate end end
    local changedView=popup.viewID~=view.id
    popup.viewID=view.id
    local multiple=#def.views>1
    popup.hint:SetText(multiple and "Switches shared across views / scroll for more" or "Saved automatically / scroll for more")
    popup.overhead=multiple and 108 or 78
    popup.scroll:ClearAllPoints();popup.scroll:SetPoint("TOPLEFT",12,multiple and -76 or -46)
    for index,candidate in ipairs(def.views) do
        local tab=popup.tabs[index]
        if not tab then
            tab=Button(popup,"",64,function(self)
                if not Visible(popup) or not self:IsShown() or not popup.owner then return end
                popup.viewID=self.viewID;popup.scroll:SetVerticalScroll(0)
                ShowSteps(popup.owner,true)
            end)
            tab:HookScript("OnEnter",function() popup.serial=(popup.serial or 0)+1 end)
            tab:HookScript("OnLeave",function(self)
                self.text:SetTextColor(unpack(self.disabled and ACCENT or TEXT));ScheduleClose()
            end)
            popup.tabs[index]=tab
        end
        tab.viewID=candidate.id;tab.text:SetText(candidate.label)
        tab.hint="Display only. Action switches apply across all views in this placement."
        tab.disabled=candidate.id==view.id
        tab.text:SetTextColor(unpack(tab.disabled and ACCENT or TEXT))
        tab:ClearAllPoints();tab:SetPoint("TOPLEFT",12+(index-1)*70,-40)
        if multiple then tab:Show() else tab:Hide() end
    end
    for index=#def.views+1,#popup.tabs do popup.tabs[index]:Hide() end
    local viewport=PlaceSteps(owner)
    popup.title:SetText(Label(def.label)..(not multiple and view.label~="Steps" and " / "..view.label or ""))
    local count,height=0,0
    local function Add(id,label,description,checked,locked,option,summary,sectionClick)
        count=count+1;local row=StepRow(count);row:SetWidth(popup.content:GetWidth())
        row.id,row.checked,row.locked,row.option=id,checked,locked,option
        row.title,row.description,row.sectionClick=label,description,sectionClick
        row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-height)
        local rowHeight=summary and summary~="" and (id and 44 or 60) or 28
        -- Set the height after measuring wrapped activation text.
        row.label:ClearAllPoints()
        row.label:SetPoint("TOPLEFT",id and 30 or 4,-6);row.label:SetPoint("TOPRIGHT",-8,-6)
        row.label:SetText(Label(label)..(id and locked and def.stepByID[id] and def.stepByID[id].locked and " (required)" or ""))
        row.check:SetChecked(checked)
        if id then row.check:Show() else row.check:Hide() end
        row.label:SetTextColor(unpack(not id and ACCENT or checked and TEXT or MUTED))
        row.summary:SetWordWrap(not id)
        row.summary:SetWidth(math.max(1,row:GetWidth()-38))
        row.summary:SetText(Label(summary))
        if summary and summary~="" then
            row.summary:Show()
            if not id then rowHeight=math.max(rowHeight,31+row.summary:GetStringHeight()) end
        else row.summary:Hide() end
        row:SetHeight(rowHeight);height=height+rowHeight
        row.fill:SetColorTexture(1,1,1,0);row:Show()
    end
    Add(nil,"About this view",view.description or "Authored action conditions and priority.",false,true)
    for index,section in ipairs(view.sections) do
        local key=view.id..":"..index
        local collapsed=popup.sectionState[key]
        if collapsed==nil then collapsed=section.collapsed==true end
        Add(nil,(collapsed and "+ " or "- ")..section.label,section.description or "Expand or collapse this section. Action switches apply across views.",false,true,false,section.when,function()
            popup.sectionState[key]=not collapsed;ShowSteps(owner,true)
        end)
        if not collapsed then
            for _,step in ipairs(section.steps) do
                local checked=step.locked or type(saved.steps)~="table" or saved.steps[step.id]~=false
                local description=step.description
                if #description>1600 then description=description:sub(1,1600).."..." end
                local requirement=def.links and def.links[step.id]
                local blocked=requirement and type(saved.steps)=="table" and saved.steps[requirement]==false
                if requirement then description="Requires enabled "..requirement..".\n"..description end
                Add(step.id,step.label..(blocked and " (requires "..requirement..")" or ""),description,checked and not blocked,step.locked or blocked,false,step.summary)
            end
        end
    end
    if #view.options>0 then Add(nil,"Preferences", "Behavior preferences for this routine and its displayed branches.",false,true) end
    for _,option in ipairs(view.options) do
        local value=type(saved.options)=="table" and saved.options[option.key]
        if type(value)~="boolean" then value=option.default~=false end
        Add(option.key,option.label:gsub("^%s+",""),option.description,value,false,true)
    end
    for index=count+1,#stepWidgets do stepWidgets[index]:Hide() end
    popup.content:SetHeight(math.max(1,height))
    popup.scroll:SetHeight(math.min(viewport,math.max(28,height)))
    if not same or changedView then popup.scroll:SetVerticalScroll(0) end
    popup.scroll:Sync();popup:SetHeight(popup.scroll:GetHeight()+popup.overhead);popup:Show()
end
local function ToggleSteps(owner)
    CloseMenu();ClosePrompt()
    if Visible(popup) and popup.owner==owner and popup.pinned then CloseSteps()
    else ShowSteps(owner,true) end
end
local function ToggleThread(row)
    expanded[row.thread]=not expanded[row.thread];CloseTransient();Options:Refresh()
end
local function Widget(index)
    if widgets[index] then return widgets[index] end
    local row=CreateFrame("Button",nil,Options.routineContent);row:SetSize(WIDTH-32,ROW);row:RegisterForClicks("LeftButtonUp","RightButtonUp")
    row.fill=row:CreateTexture(nil,"BACKGROUND");row.fill:SetAllPoints()
    row.accent=row:CreateTexture(nil,"ARTWORK");row.accent:SetSize(2,ROW-4);row.accent:SetPoint("LEFT",0,0);row.accent:SetColorTexture(unpack(ACCENT))
    row.label=Text(row);row.label:SetPoint("LEFT",36,0);row.label:SetPoint("RIGHT",-114,0)
    row.subtitle=Text(row);row.subtitle:SetPoint("LEFT",36,-9);row.subtitle:SetTextColor(unpack(MUTED))
    row.check=Checkbox(row);row.check:SetPoint("LEFT",10,0)
    row.check:SetScript("OnClick",function() Config:SetEnabled(row.thread,row.index,not row.checked) end)
    row.expand=Button(row,"-",22,function() ToggleThread(row) end);row.expand:SetPoint("LEFT",6,0)
    row.run=Button(row,"Run",44,function() CloseTransient();jungle.Engine:SetThread(row.thread) end);row.run:SetPoint("RIGHT",-64,0)
    row.run.hint="Select this thread."
    row.reset=Button(row,"Reset",50,function() CloseTransient();Config:ResetThread(row.thread) end);row.reset:SetPoint("RIGHT",-8,0)
    row.reset.hint="Restore the original routines and switches for this thread."
    row.stepsButton=Button(row,"Steps",48,function() ToggleSteps(row) end);row.stepsButton:SetPoint("RIGHT",-60,0)
    row.more=Button(row,"More",44,function(self) OpenMenu(self,"routine") end);row.more:SetPoint("RIGHT",-10,0);row.more.row=row
    row.more.hint="Move or remove this routine. Warrior shout selection is also here."
    row:SetScript("OnEnter",function()
        if row.error then Tooltip(row,"Unavailable routine",row.error)
        elseif row.kind=="routine" then ShowSteps(row) end
    end)
    row:SetScript("OnLeave",function() GameTooltip:Hide();ScheduleClose() end)
    row.check:SetScript("OnEnter",function() ShowSteps(row) end);row.check:SetScript("OnLeave",ScheduleClose)
    row:SetScript("OnClick",function(_,button)
        if row.kind=="thread" then ToggleThread(row)
        elseif row.kind=="add" then OpenMenu(row,"add",row.thread)
        elseif button=="RightButton" then OpenMenu(row.more,"routine")
        else ToggleSteps(row) end
    end)
    widgets[index]=row;return row
end
function Options:RefreshRoutineUI()
    local frame=self:CreateFrame()
    CloseMenu()
    for _,row in ipairs(self.rows) do row:Hide() end
    frame:SetWidth(WIDTH)
    if not self.routineScroll then
        Paint(frame)
        frame.headerFill=frame:CreateTexture(nil,"BACKGROUND",nil,2)
        frame.headerFill:SetPoint("TOPLEFT",1,-1);frame.headerFill:SetPoint("TOPRIGHT",-1,-1);frame.headerFill:SetHeight(26)
        frame.headerFill:SetColorTexture(.07,.10,.14,1)
        frame.title:SetTextColor(unpack(ACCENT));frame.title:ClearAllPoints();frame.title:SetPoint("LEFT",frame.hideButton,"LEFT",8,0)
        if frame.header then frame.header:SetHeight(26) end
        if frame.hideButton then frame.hideButton:SetHeight(26) end
        if frame.closeButton then frame.closeButton:SetSize(24,24) end
        frame.subtitle:ClearAllPoints();frame.subtitle:SetPoint("TOPRIGHT",-30,-8)
        self.profileButton=Button(frame,"",WIDTH-24,function(self) OpenMenu(self,"profile") end)
        self.profileButton:SetHeight(28);self.profileButton:SetPoint("TOPLEFT",12,-34)
        self.profileButton.hint="Choose a profile, or create, copy and rename one. Click again to close."
        self.routineScroll,self.routineContent=Scroll(frame,WIDTH-24,VIEW);self.routineScroll:SetPoint("TOPLEFT",12,-72)
        self.status=Text(frame);self.status:SetPoint("BOTTOMLEFT",12,12);self.status:SetPoint("BOTTOMRIGHT",-82,12)
        self.stopButton=Button(frame,"Stop",56,function() CloseTransient();jungle.Engine:SetThread(0) end);self.stopButton:SetPoint("BOTTOMRIGHT",-12,8)
        self.stopButton.hint="Stop all routine threads."
        frame:HookScript("OnHide",CloseTransient)
    end
    local collapsed=Config.db.collapsed
    self.profileButton.text:SetText("Profile: "..Config.selected.." / Change")
    local className,class=UnitClass("player");frame.subtitle:SetText(className);frame.subtitle:SetTextColor(unpack(MUTED))
    local threads=Config:GetThreads();local count=0
    local function Add(kind,thread,index,label,checked,error)
        count=count+1;local row=Widget(count)
        row.kind,row.thread,row.index,row.checked,row.error=kind,thread,index,checked,error
        row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-(count-1)*ROW)
        row.label:ClearAllPoints();row.label:SetPoint("LEFT",36,kind=="thread" and 6 or 0);row.label:SetPoint("RIGHT",-114,kind=="thread" and 6 or 0)
        row.label:SetText(Label(label));row.label:SetTextColor(unpack(error and {1,.48,.42} or checked==false and MUTED or TEXT))
        row.check:Hide();row.expand:Hide();row.reset:Hide();row.run:Hide();row.stepsButton:Hide();row.more:Hide();row.subtitle:Hide();row.accent:Hide()
        row.fill:SetColorTexture(.06,.08,.11,kind=="thread" and 1 or .45)
        if kind=="routine" then
            row.check:Show();row.check:SetChecked(checked);row.stepsButton:Show();row.more:Show()
            row.stepsButton.disabled=error~=nil;row.stepsButton.text:SetTextColor(unpack(error and MUTED or TEXT))
        elseif kind=="thread" then
            row.expand.text:SetText(expanded[thread] and "-" or "+");row.expand:Show();row.reset:Show();row.run:Show()
            local active=jungle.Engine and jungle.Engine.activeThread==thread
            row.run.text:SetText(active and "Active" or "Run");row.run.disabled=active
            row.run.text:SetTextColor(unpack(active and ACCENT or TEXT));if active then row.accent:Show() end
            local n=#(threads[thread] or EMPTY)
            row.subtitle:SetText(n==0 and "No routines" or n..(n==1 and " routine" or " routines"));row.subtitle:Show()
        else
            row.label:ClearAllPoints();row.label:SetPoint("LEFT",36,0);row.label:SetPoint("RIGHT",-8,0)
            row.label:SetTextColor(unpack(ACCENT));row.fill:SetColorTexture(1,1,1,0)
        end
        row:Show()
    end
    for thread=1,7 do
        Add("thread",thread,nil,"Thread "..thread..(thread==7 and " / Support" or ""))
        if expanded[thread] then
            for index,entry in ipairs(threads[thread] or EMPTY) do
                local def=type(entry)=="table" and Config.definitions[entry.id]
                local err=Config.errors and Config.errors[thread..":"..index]
                Add("routine",thread,index,def and def.label or "Unavailable routine",type(entry)=="table" and entry.enabled~=false,err)
            end
            Add("add",thread,nil,"+ Add routine")
        end
    end
    for index=count+1,#widgets do widgets[index]:Hide() end
    self.routineContent:SetHeight(math.max(1,count*ROW))
    local height=math.min(VIEW,UIParent:GetHeight()*.62,math.max(ROW,UIParent:GetHeight()-132),count*ROW)
    self.routineScroll:SetHeight(height);self.routineScroll:Sync()
    if collapsed then
        self.profileButton:Hide();self.routineScroll:Hide();self.status:Hide();self.stopButton:Hide();CloseTransient();frame:SetHeight(26)
    else
        self.profileButton:Show();self.routineScroll:Show();self.status:Show();self.stopButton:Show();frame:SetHeight(height+116)
        self.status:SetText(Config.pending and "Saved / applies after combat" or "Saved automatically")
        self.status:SetTextColor(unpack(Config.pending and {1,.72,.38} or MUTED))
    end
    if Visible(popup) and popup.owner then
        local owner=popup.owner;local entry=Config:GetEntry(owner.thread,owner.index)
        if owner.kind=="routine" and entry and entry.id==popup.id then ShowSteps(owner) else CloseSteps() end
    end
    self:RestorePosition()
end
