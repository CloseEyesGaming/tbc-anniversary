-- Standalone mocked tests, deliberately NOT loaded by the production TOC.
-- Run from the addon directory: npx --yes --package=fengari-node-cli fengari tests/Options.test.lua
-- This verifies settings/control flow, not Blizzard's renderer or disk persistence.
unpack = unpack or table.unpack

local frames = {}
local playerClass = "WARRIOR"
local methods = {}
local function NewObject(parent)
    return setmetatable({ parent = parent, scripts = {}, events = {}, shown = true }, { __index = methods })
end
for _, name in ipairs({
    "SetColorTexture", "SetAllPoints", "SetTextColor", "SetJustifyH", "RegisterForClicks",
    "SetFrameStrata", "SetMovable", "EnableMouse", "SetBackdrop", "SetBackdropColor",
    "SetBackdropBorderColor", "RegisterForDrag", "StartMoving", "StopMovingOrSizing",
}) do
    methods[name] = function() end
end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:RegisterForClicks(...) self.clicks = { ... } end
function methods:SetBackdrop(backdrop) self.backdrop = backdrop end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:ClearAllPoints() self.x, self.y = nil, nil end
function methods:SetPoint(point, relative, relativePoint, x, y)
    self.anchors = self.anchors or {}
    self.anchors[point] = {relative=relative, relativePoint=relativePoint, x=x, y=y}
    if point == "CENTER" and type(relative) == "table" and relativePoint == "CENTER" then
        self.x, self.y = x, y
    end
end
function methods:GetCenter()
    if not self.parent then return self.width / 2, self.height / 2 end
    local x, y = self.parent:GetCenter()
    return x + (self.x or 0), y + (self.y or 0)
end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:IsShown() return self.shown end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:SetClampedToScreen(value) self.clamped = value end
function methods:SetText(value) self.textValue = value end
function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:UnregisterEvent(event) self.events[event] = nil end
function methods:CreateTexture() return NewObject(self) end
function methods:CreateFontString() return NewObject(self) end
function CreateFrame(_, _, parent, template)
    local frame = NewObject(parent)
    frame.template = template
    frames[#frames + 1] = frame
    return frame
end
function UnitClass() return playerClass, playerClass end
RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
UIParent = NewObject()
UIParent:SetSize(1024, 768)
GameTooltip = NewObject()
function GameTooltip:SetOwner(owner) self.owner = owner end
function GameTooltip:AddLine(text) self.description = text end

local checks = 0
local function Equal(actual, expected, message)
    assert(actual == expected, message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    checks = checks + 1
end
local function Load(saved, classToken)
    frames = {}
    playerClass = classToken or "WARRIOR"
    OliaEyes6_Settings = saved
    local jungle = {}
    assert(loadfile("Core/Options.lua"))("OliaEyes6", jungle)
    local loader = frames[1]
    loader.scripts.OnEvent(loader, "ADDON_LOADED", "AnotherAddon")
    Equal(jungle.Options.frame, nil, "ignore other addon load")
    loader.scripts.OnEvent(loader, "ADDON_LOADED", "OliaEyes6")
    return jungle.Options, OliaEyes6_Settings, loader, jungle
end

local options, db, loader = Load(nil)
Equal(db.schemaVersion, 1, "fresh schema")
Equal(options:IsEnabled("thread1_demoralizing_shout"), true, "default on")
Equal(options:IsEnabled("universal_arms_wowsims_st"), false, "new rotation defaults off")
Equal(options.rows[11].thread.textValue, "U", "universal mode scope marker")
options.rows[11].scripts.OnClick(options.rows[11])
Equal(options:IsEnabled("universal_arms_wowsims_st"), true, "mode row enables")
options, db, loader = Load(db)
Equal(options:IsEnabled("universal_arms_wowsims_st"), true, "mode survives reload")
options.rows[11].checkBox.scripts.OnEnter()
Equal(GameTooltip.textValue, "Universal: T1/T2/T3 fallback: Arms: WoWSims", "mode scope in tooltip")
options.rows[11].checkBox:SetChecked(false)
options.rows[11].checkBox.scripts.OnClick(options.rows[11].checkBox)
Equal(options:IsEnabled("universal_arms_wowsims_st"), true, "selected mode cannot be deselected")
options:SetEnabled("universal_arms_adaptive", true)
Equal(options:GetArmsPveMode(), "adaptive", "adaptive selected")
Equal(options:IsEnabled("universal_arms_wowsims_st"), false, "adaptive deselects wowsims")
Equal(options:IsEnabled("universal_arms_original"), false, "adaptive deselects original")
options, db, loader = Load(db)
Equal(options:GetArmsPveMode(), "adaptive", "adaptive survives reload")
options:SetEnabled("universal_arms_original", true)
Equal(options:GetArmsPveMode(), "original", "original explicitly selected")
Equal(options:IsEnabled("universal_arms_adaptive"), false, "original deselects adaptive")
for index, key in ipairs({'wowsims_sunder_initial','wowsims_sunder_stack','wowsims_sunder_refresh','wowsims_demoralizing_shout'}) do
    local row=options.rows[index+12]
    Equal(row.option.key,key,"maintenance row directly below WoWSims")
    Equal(options:IsEnabled(key),false,"maintenance defaults off")
    row.scripts.OnClick(row)
    Equal(options:IsEnabled(key),true,"maintenance row enables")
    options,db,loader=Load(db)
    Equal(options:IsEnabled(key),true,"maintenance preference persists")
    options.rows[index+12].checkBox:SetChecked(false)
    options.rows[index+12].checkBox.scripts.OnClick(options.rows[index+12].checkBox)
    Equal(options:IsEnabled(key),false,"maintenance checkbox disables")
end
for _, key in ipairs({"adaptive_berserker_rage", "adaptive_aoe_trinkets"}) do
    Equal(options:IsEnabled(key), true, "new Adaptive utility defaults on")
    options:SetEnabled(key, false)
    options, db, loader = Load(db)
    Equal(options:IsEnabled(key), false, "utility hold persists after reload")
    options:SetEnabled(key, true)
end
Equal(options:GetWarriorDefaultShout(), "Battle Shout", "fresh default shout is Battle")
Equal(options.rows[26].checked, true, "Battle default selected")
Equal(options.rows[27].checked, false, "Commanding default unselected")
Equal(options.rows[26].parentMode, nil, "default is independent of Arms modes")
Equal(options.rows[27].depth, 0, "shared default is not nested under Adaptive")
options.rows[27].scripts.OnClick(options.rows[27])
Equal(options:GetWarriorDefaultShout(), "Commanding Shout", "row selects Commanding")
Equal(options.rows[26].checked, false, "Commanding deselects Battle")
options, db, loader = Load(db)
Equal(options:GetWarriorDefaultShout(), "Commanding Shout", "default survives reload")
options.rows[27].checkBox:SetChecked(false)
options.rows[27].checkBox.scripts.OnClick(options.rows[27].checkBox)
Equal(options.rows[27].checked, true, "selected default cannot be unchecked")
options:SetEnabled("universal_arms_adaptive", true)
Equal(options:GetWarriorDefaultShout(), "Commanding Shout", "Arms mode leaves default intact")
options.rows[26].checkBox:SetChecked(true)
options.rows[26].checkBox.scripts.OnClick(options.rows[26].checkBox)
Equal(options:GetWarriorDefaultShout(), "Battle Shout", "checkbox selects Battle")
Equal(options.rows[27].checked, false, "Battle deselects Commanding")
options:SetEnabled("default_shout_commanding", true)
options:ResetClass("WARRIOR")
Equal(options:GetWarriorDefaultShout(), "Battle Shout", "class reset restores Battle")
db.classes.WARRIOR = {default_shout="invalid"}
Equal(options:GetWarriorDefaultShout(), "Battle Shout", "malformed preference falls back to Battle")
options:ResetClass("WARRIOR")
Equal(options.frame.clamped, true, "native screen clamp retained")
Equal(db.position.x, 0, "fresh centered x")
Equal(db.shown, true, "fresh visible")
Equal(#options.rows, 27, "three modes, support switches and shared default shout")
Equal(options.frame:GetWidth(), 190, "compact panel width")
Equal(options.rows[10].anchors.TOPLEFT.y, -18, "Original is first parent")
Equal(options.rows[1].anchors.TOPLEFT.y, -34, "original child follows parent")
Equal(options.rows[11].anchors.TOPLEFT.y, -184, "WoWSims follows original group")
Equal(options.rows[13].anchors.TOPLEFT.y, -200, "WoWSims child follows parent")
Equal(options.rows[12].anchors.TOPLEFT.y, -270, "Adaptive follows WoWSims group")
Equal(options.rows[17].anchors.TOPLEFT.y, -286, "Adaptive child follows parent")
Equal(options.rows[1].checkBox.anchors.LEFT.x, 12, "original checkbox nested")
Equal(options.rows[13].checkBox.anchors.LEFT.x, 12, "WoWSims checkbox nested")
Equal(options.rows[17].checkBox.anchors.LEFT.x, 12, "Adaptive checkbox nested")
Equal(options.rows[10].checkBox.anchors.LEFT.x, 0, "parent checkbox not nested")
Equal(options.frame:GetHeight(), 464, "nested groups and shared shout defaults fit")
Equal(options.frame.template, nil, "no backdrop template")
Equal(options.frame.backdrop, nil, "transparent panel without fill or border")
Equal(options.frame.accent, nil, "no full-height accent bar")
Equal(options.rows[1]:GetHeight(), 16, "tight row height")
Equal(options.rows[1].checkBox:GetWidth(), 16, "compact native checkbox")
Equal(options.frame.title.textValue, "OliaEyes", "header is addon name")
Equal(options.frame.hideButton:GetWidth(), 60, "click area fits addon name")
Equal(options.frame.hideButton.clicks[1], "LeftButtonUp", "hide accepts left click")
Equal(options.frame.hideButton.clicks[2], "RightButtonUp", "hide accepts right click")
for _, button in ipairs({ "LeftButton", "RightButton" }) do
    local _, oldY = options.frame:GetCenter()
    local oldTop = oldY + options.frame:GetHeight() / 2
    options.frame.hideButton.scripts.OnClick(options.frame.hideButton, button)
    Equal(options.frame:IsShown(), true, button .. " keeps header visible")
    Equal(db.shown, true, "collapse does not hide frame")
    Equal(db.collapsed, true, "collapse saved")
    Equal(options.frame.title.textValue, "OliaEyes", "collapsed header keeps addon name")
    Equal(options.frame:GetHeight(), 20, "collapsed hit area is header only")
    for _, row in ipairs(options.rows) do Equal(row:IsShown(), false, "collapsed row hidden") end
    local _, newY = options.frame:GetCenter()
    Equal(newY + options.frame:GetHeight() / 2, oldTop, "header stays fixed on collapse")
    options, db, loader = Load(db)
    Equal(db.collapsed, true, "reload preserves collapse")
    Equal(options.frame.title.textValue, "OliaEyes", "reload keeps addon name")
    Equal(options.rows[1]:IsShown(), false, "reload keeps rows hidden")
    options.frame.hideButton.scripts.OnClick(options.frame.hideButton, button)
    Equal(db.collapsed, false, "second click expands")
    Equal(options.frame:GetHeight(), 464, "expanded height restored")
    Equal(options.frame.title.textValue, "OliaEyes", "expanded header keeps addon name")
    for _, row in ipairs(options.rows) do Equal(row:IsShown(), true, "expanded row restored") end
    local _, restoredY = options.frame:GetCenter()
    Equal(restoredY + options.frame:GetHeight() / 2, oldTop, "header stays fixed on expand")
end
options.rows[3].checkBox.scripts.OnEnter()
Equal(GameTooltip:IsShown(), true, "checkbox hover shows description")
Equal(GameTooltip.textValue, "Original / shared - Thread 1: Sunder: initial", "tooltip names exact block")
Equal(GameTooltip.description, options.rows[3].option.description, "tooltip uses documented semantics")
options.rows[3].checkBox.scripts.OnLeave()
Equal(GameTooltip:IsShown(), false, "checkbox leave hides description")
Equal(options:RegisterOption("WARRIOR", { key = "bad", label = "Bad", thread = 0 }), false, "invalid thread rejected")

options, db, loader = Load({
    classes = {
        WARRIOR = { demoralizing_shout = false, sweeping_strikes = true, unrelated = 123 },
        DRUID = { thread_1_example = false },
    },
    shown = false,
    position = { x = 100000, y = -100000 },
})
Equal(options:IsEnabled("thread1_demoralizing_shout"), false, "migrate unchecked")
Equal(options:IsEnabled("thread2_sweeping_strikes"), true, "migrate checked")
Equal(db.classes.WARRIOR.demoralizing_shout, nil, "old key retired")
Equal(db.classes.WARRIOR.unrelated, 123, "unrelated data preserved")
Equal(db.classes.DRUID.thread_1_example, false, "other class preserved")
Equal(options.frame:IsShown(), false, "hidden state preserved")
Equal(db.position.x, 417, "offscreen x clamped")
Equal(db.position.y, -152, "offscreen y clamped")
Equal(options:AllowsForThread("thread1_demoralizing_shout", 1), false, "owner disabled")
Equal(options:AllowsForThread("thread1_demoralizing_shout", 7), true, "shared thread unchanged")
options:SetEnabled("thread2_sweeping_strikes", false)
Equal(options:AllowsForThread("thread2_sweeping_strikes", 2), false, "second owner disabled")
Equal(options:AllowsForThread("thread2_sweeping_strikes", 1), true, "second gate leaves first thread unchanged")
Equal(options:AllowsForThread("thread1_demoralizing_shout", "1"), false, "invalid caller thread")
Equal(options:AllowsForThread("missing", 1), false, "unknown gate rejected")
Equal(options:SetEnabled("thread1_demoralizing_shout", "false"), false, "nonboolean write rejected")
Equal(options:IsEnabled("thread_1_example", "DRUID"), false, "explicit other class read")

UIParent:SetSize(640, 480)
loader.scripts.OnEvent(loader, "DISPLAY_SIZE_CHANGED")
Equal(db.position.x, 225, "display shrink x")
Equal(db.position.y, -8, "display shrink y")
Equal(options.frame:IsShown(), false, "display event does not reopen")
UIParent:SetSize(500, 400)
loader.scripts.OnEvent(loader, "UI_SCALE_CHANGED")
Equal(db.position.x, 155, "scale change x")
Equal(db.position.y, 0, "scale change y")

options:Center()
Equal(db.position.x, 0, "center command x")
Equal(db.position.y, 0, "center command y")
Equal(db.shown, true, "center reopens")
Equal(options:IsEnabled("thread1_demoralizing_shout"), false, "center preserves choices")
UIParent:SetSize(1024, 768)
options.frame.x, options.frame.y = 50, -30
for _, frame in ipairs(frames) do
    if frame.scripts.OnDragStop then frame.scripts.OnDragStop(frame) end
end
Equal(db.position.x, 50, "drag stop saves x")
Equal(db.position.y, -30, "drag stop saves y")
options.rows[1].scripts.OnClick(options.rows[1])
Equal(options:IsEnabled("thread1_demoralizing_shout"), true, "row click enables")
options.rows[1].checkBox:SetChecked(false)
options.rows[1].checkBox.scripts.OnClick(options.rows[1].checkBox)
Equal(options:IsEnabled("thread1_demoralizing_shout"), false, "native checkbox disables")
options:Hide()
options, db = Load(db)
Equal(options:IsEnabled("thread1_demoralizing_shout"), false, "reload preserves false")
Equal(db.shown, false, "reload preserves hidden")
Equal(options.frame.x, 50, "reload restores dragged x")
Equal(options.frame.y, -30, "reload restores dragged y")

options, db = Load({ classes = { WARRIOR = {
    demoralizing_shout = true, thread1_demoralizing_shout = false,
    sweeping_strikes = false, thread2_sweeping_strikes = true,
} } })
Equal(options:IsEnabled("thread1_demoralizing_shout"), false, "new false wins migration conflict")
Equal(options:IsEnabled("thread2_sweeping_strikes"), true, "new true wins migration conflict")
options, db = Load({ classes = { WARRIOR = { demoralising_shout = false } } })
Equal(options:IsEnabled("thread1_demoralizing_shout"), false, "early spelling alias migrated")

options, db = Load({ classes = { WARRIOR = "invalid" }, shown = "invalid", position = { x = 0/0, y = math.huge } })
Equal(options:IsEnabled("thread1_demoralizing_shout"), true, "malformed class defaults")
Equal(options:SetEnabled("thread1_demoralizing_shout", false), true, "malformed class repaired on write")
Equal(db.position.x, 0, "nonfinite position recentered")
Equal(db.position.y, 0, "nonfinite position recentered y")
options, db = Load({ schemaVersion = 2, classes = { WARRIOR = { thread1_demoralizing_shout = false } } })
Equal(db.schemaVersion, 2, "future version not downgraded")
Equal(options:IsEnabled("thread1_demoralizing_shout"), false, "future known setting retained")

local jungle
options, db, loader, jungle = Load({ classes = {}, position = { x = 50, y = 50 }, shown = false })
SlashCmdList = {}
function SetCVar() end
assert(loadfile("Main.lua"))("OliaEyes6", jungle)
SlashCmdList.OLIA("center")
Equal(db.position.x, 0, "slash dispatch centers")
Equal(db.shown, true, "slash dispatch opens")
SlashCmdList.OLIA("options")
Equal(db.shown, false, "existing toggle retained")
print("Options hardening: " .. checks .. " checks passed (mocked UI).")
