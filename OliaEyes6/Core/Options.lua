--[=[
OliaEyes6 options widget / integration guide

This module provides UI and preferences. Routines/Warrior.lua consumes the
Warrior switches to restrict existing routine blocks. The mutually exclusive
Registered Original / WoWSims / Adaptive variants select the Arms policy; Original is default.
Other classes still show
unconnected prototype rows.
The integration snippets below are documentation, not additional live logic.

In game:
  /olia options   Toggle the widget (aliases: /olia config, /olia ui).
  /olia center    Open and recenter it without resetting checkbox choices.
  Drag the header to move it; click a checkbox or its row to change a value.

Register an option once, at file-load time after Core/Options.lua and before
this addon's ADDON_LOADED event. Registration order determines row order.
Example shape (this Warrior option is already registered below):

  jungle.Options:RegisterOption("WARRIOR", {
      key = "thread1_demoralizing_shout", -- stable, unique within this class
      thread = 1,                       -- integer Engine thread ID, 1..7
      label = "Demoralizing Shout",      -- display text, safe to rename
      default = true,                    -- boolean; omitted means true
      description = "Existing routine block", -- optional hover explanation
  })

RegisterOption returns false for invalid definitions or duplicate class/key
pairs. Use a separate key for each thread-specific preference. Classes without
registered options display generic prototype rows. Runtime registration needs
an explicit Options:Refresh() to redraw an already-created widget.

Future routine integration (inside the existing class-specific evaluation):

  local allowDemo = jungle.Options:AllowsForThread(
      "thread1_demoralizing_shout", jungle.Engine.activeThread, "WARRIOR")
  routine[rowIndex][3] = existingCondition and allowDemo

Keep ALL existing readiness/target/resource conditions. Assign the row condition
on every evaluation, including false, so cached routine rows cannot stay enabled.
Do not cache the preference at file-load time: a later click must be observed.

AllowsForThread(key, threadID, classToken) is a restriction, NOT a scheduler:
  * Owning thread: returns the saved preference, or its definition's default.
  * Other valid thread: returns true, leaving the existing condition unchanged.
  * Unknown key or invalid thread ID (including idle 0): returns false.
It does not select a thread, cast a spell, or make an otherwise-invalid action
ready. Audit every relevant routine branch when wiring a real toggle; adding a
gate to one occurrence does not disable other occurrences automatically.

IsEnabled(key, classToken) returns the raw preference and ignores thread scope.
Use it for UI/inspection or a mode selector with explicit caller/context gates.
WoWSims gates threads 1/2/3; Adaptive gates 1/2/3/7. Mode rows set scopeLabel for
the U marker/tooltip; ordinary restriction gates still use AllowsForThread.
Unknown keys return false. Both query methods default classToken to the player's class.

After ADDON_LOADED, SetEnabled(key, boolean, classToken) saves and refreshes the
UI; it returns true on success, false for invalid input or unavailable storage.
Arms mode rows use radio semantics: any click selects that mode, even if the
checkbox attempted to uncheck it. GetArmsPveMode returns the canonical selection.
The old WoWSims boolean is read when no canonical selection has been saved.
Default: Battle / Default: Commanding also use radio semantics. Their shared
DPS choice is returned by GetWarriorDefaultShout and stored as default_shout.
Battle is the initial default; aura ownership/coverage takes priority.
ResetClass(classToken) restores that class's defaults, leaving position and
visibility alone. Its class argument also defaults to the player's class.

Persistence: OliaEyes6_Settings is declared in the TOC's SavedVariables list.
classes[classToken][key] holds choices, shared by all characters of that class.
position, shown and collapsed are account-wide window settings, shared across classes.
Initialization/migration waits for ADDON_LOADED; queries before it use defaults
when saved data is unavailable. WoW writes changes on /reload or normal logout/
exit, not on each click; a crash can lose recent changes. Use the API rather
than editing saved fields directly. Keep keys stable; if renaming them, add a
versioned migration in InitializeSettings that preserves explicit false values.

Position is validated/clamped on load, show, drag-stop and display/UI-scale
events, with Blizzard screen clamping retained. /olia center is the recovery
command. All UI work is event-driven; this module adds no OnUpdate handler.
The compact widget has no panel fill/border; drag the header beside "OliaEyes" to
move. Left- or right-click "OliaEyes" to collapse/expand the checkboxes,
keeping the header visible. The x button hides everything; /olia options reopens it.

Standalone mocked tests (not loaded by the TOC), from the addon directory:
  npx --yes --package=fengari-node-cli fengari tests/Options.test.lua
]=]

local AddonName, jungle = ...

local Options = {
    definitions = {},
    rows = {},
}
jungle.Options = Options

local SETTINGS_VERSION = 1
local PANEL_WIDTH, HEADER_HEIGHT, ROW_HEIGHT, BOTTOM_PADDING = 190, 18, 16, 2

local function IsFiniteNumber(value)
    return type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end

local function IsThreadID(value)
    return IsFiniteNumber(value) and value >= 1 and value <= 7 and value == math.floor(value)
end

local function InitializeSettings()
    if type(_G.OliaEyes6_Settings) ~= "table" then
        _G.OliaEyes6_Settings = {}
    end
    local db = _G.OliaEyes6_Settings
    if type(db.classes) ~= "table" then db.classes = {} end
    if type(db.shown) ~= "boolean" then db.shown = true end
    if type(db.collapsed) ~= "boolean" then db.collapsed = false end

    local version = IsFiniteNumber(db.schemaVersion) and db.schemaVersion or 0
    if version < 1 then
        local warrior = db.classes.WARRIOR
        if type(warrior) == "table" then
            local renames = {
                { "demoralizing_shout", "thread1_demoralizing_shout" },
                { "demoralising_shout", "thread1_demoralizing_shout" },
                { "sweeping_strikes", "thread2_sweeping_strikes" },
            }
            for i = 1, #renames do
                local oldKey, newKey = renames[i][1], renames[i][2]
                -- An explicit new value wins; false must survive migration too.
                if type(warrior[newKey]) ~= "boolean" and type(warrior[oldKey]) == "boolean" then
                    warrior[newKey] = warrior[oldKey]
                end
                warrior[oldKey] = nil
            end
        end
        db.schemaVersion = SETTINGS_VERSION
    end
    -- Do not downgrade a newer schema when an older addon version is loaded.
    return db
end

-- Shared bootstrap: profile migration must run after the legacy key migration.
function Options:InitializeSettings() return InitializeSettings() end

local GENERIC_PROTOTYPE_OPTIONS = {
    { key = "thread_1_example", thread = 1, label = "Primary routine option", default = true },
    { key = "thread_2_example", thread = 2, label = "Secondary routine option", default = true },
}

local COLORS = {
    muted = { 0.48, 0.48, 0.48 },
    text = { 0.88, 0.88, 0.88 },
}

local function GetPlayerClass()
    local className, classToken = UnitClass("player")
    return classToken or "UNKNOWN", className or "Unknown"
end

local function GetDefinitions(classToken)
    local definitions = Options.definitions[classToken]
    if definitions and #definitions > 0 then
        return definitions
    end
    return GENERIC_PROTOTYPE_OPTIONS
end

local function FindDefinition(classToken, optionKey)
    local definitions = GetDefinitions(classToken)
    for i = 1, #definitions do
        if definitions[i].key == optionKey then
            return definitions[i]
        end
    end
end

local function GetClassSettings(classToken, create)
    local db = _G.OliaEyes6_Settings
    if type(db) ~= "table" or type(db.classes) ~= "table" then return nil end

    local classSettings = db.classes[classToken]
    if type(classSettings) ~= "table" and create then
        classSettings = {}
        db.classes[classToken] = classSettings
    end
    if type(classSettings) == "table" then return classSettings end
end

function Options:RegisterOption(classToken, option)
    if type(classToken) ~= "string" or type(option) ~= "table" then return false end
    if type(option.key) ~= "string" or type(option.label) ~= "string" then return false end
    if not IsThreadID(option.thread) then return false end
    if option.default ~= nil and type(option.default) ~= "boolean" then return false end

    local definitions = self.definitions[classToken]
    if not definitions then
        definitions = {}
        self.definitions[classToken] = definitions
    end

    for i = 1, #definitions do
        if definitions[i].key == option.key then return false end
    end

    definitions[#definitions + 1] = option
    return true
end

-- One canonical selection; migrate the old opt-in lazily without changing its choice.
local ARMS_MODES = {
    universal_arms_original = "original",
    universal_arms_wowsims_st = "wowsims",
    universal_arms_adaptive = "adaptive",
}
function Options:GetArmsPveMode()
    if jungle.RoutineContext then return jungle.RoutineContext.mode end
    local settings = GetClassSettings("WARRIOR", false)
    local mode = settings and settings.arms_pve_mode
    if mode == "original" or mode == "wowsims" or mode == "adaptive" then return mode end
    return settings and settings.universal_arms_wowsims_st == true and "wowsims" or "original"
end

-- One saved default shared by every DPS mode; existing aura ownership wins.
local WARRIOR_DEFAULT_SHOUTS = {
    default_shout_battle = "Battle Shout",
    default_shout_commanding = "Commanding Shout",
}
function Options:GetWarriorDefaultShout()
    if jungle.RoutineContext then return jungle.RoutineContext.defaultShout end
    local settings = GetClassSettings("WARRIOR", false)
    return settings and settings.default_shout == "Commanding Shout" and "Commanding Shout" or "Battle Shout"
end

function Options:IsEnabled(optionKey, classToken)
    local entry = jungle.RoutineContext
    if entry and entry.options[optionKey] ~= nil then return entry.options[optionKey] end
    classToken = classToken or GetPlayerClass()
    local definition = FindDefinition(classToken, optionKey)
    if not definition then return false end
    if classToken == "WARRIOR" and ARMS_MODES[optionKey] then
        return self:GetArmsPveMode() == ARMS_MODES[optionKey]
    elseif classToken == "WARRIOR" and WARRIOR_DEFAULT_SHOUTS[optionKey] then
        return self:GetWarriorDefaultShout() == WARRIOR_DEFAULT_SHOUTS[optionKey]
    end

    local classSettings = GetClassSettings(classToken, false)
    if classSettings and type(classSettings[optionKey]) == "boolean" then
        return classSettings[optionKey]
    end
    return definition.default ~= false
end

-- Future shared-routine gate: combine this result with the existing condition.
-- Outside the option's owning thread, leave behavior unchanged (return true).
-- Unknown keys/invalid thread IDs fail closed, rather than silently enabling a typo.
-- IsEnabled remains the raw stored preference used by the UI.
function Options:AllowsForThread(optionKey, threadID, classToken)
    local entry = jungle.RoutineContext
    if entry and entry.options[optionKey] ~= nil then return entry.options[optionKey] end
    classToken = classToken or GetPlayerClass()
    local definition = FindDefinition(classToken, optionKey)
    if not definition or not IsThreadID(threadID) then return false end
    if definition.thread ~= threadID then return true end
    return self:IsEnabled(optionKey, classToken)
end

function Options:SetEnabled(optionKey, enabled, classToken)
    if type(enabled) ~= "boolean" then return false end
    classToken = classToken or GetPlayerClass()
    if not FindDefinition(classToken, optionKey) then return false end

    local classSettings = GetClassSettings(classToken, true)
    if not classSettings then return false end
    if classToken == "WARRIOR" and ARMS_MODES[optionKey] then
        -- Radio semantics: clicking the selected row cannot leave no mode selected.
        classSettings.arms_pve_mode = ARMS_MODES[optionKey]
        for key, mode in pairs(ARMS_MODES) do
            classSettings[key] = mode == classSettings.arms_pve_mode
        end
    elseif classToken == "WARRIOR" and WARRIOR_DEFAULT_SHOUTS[optionKey] then
        -- Like mode rows, the selected default cannot be unchecked.
        classSettings.default_shout = WARRIOR_DEFAULT_SHOUTS[optionKey]
    else
        classSettings[optionKey] = enabled == true
    end
    self:Refresh()
    return true
end

function Options:ResetClass(classToken)
    classToken = classToken or GetPlayerClass()
    local db = _G.OliaEyes6_Settings
    if type(db) == "table" and type(db.classes) == "table" then
        db.classes[classToken] = nil
    end
    self:Refresh()
end

local function SetRowChecked(row, checked)
    row.checked = checked
    row.checkBox:SetChecked(checked)
    if checked then
        row.label:SetTextColor(unpack(COLORS.text))
    else
        row.label:SetTextColor(unpack(COLORS.muted))
    end
end

local function CreateOptionRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 1, -HEADER_HEIGHT - ((index - 1) * ROW_HEIGHT))
    row:SetPoint("TOPRIGHT", -1, -HEADER_HEIGHT - ((index - 1) * ROW_HEIGHT))
    row:RegisterForClicks("LeftButtonUp")

    row.highlight = row:CreateTexture(nil, "BACKGROUND")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, 0.04)
    row.highlight:Hide()

    row.checkBox = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.checkBox:SetSize(16, 16)
    row.checkBox:SetPoint("LEFT", 0, 0)
    row.checkBox:SetScript("OnClick", function(self)
        if row.option then
            Options:SetEnabled(row.option.key, self:GetChecked() == true, row.classToken)
        end
    end)

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.label:SetPoint("LEFT", row.checkBox, "RIGHT", 1, 0)
    row.label:SetPoint("RIGHT", row, "RIGHT", -22, 0)
    row.label:SetJustifyH("LEFT")

    row.thread = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.thread:SetPoint("RIGHT", -1, 0)
    row.thread:SetTextColor(unpack(COLORS.muted))

    local function OnEnter()
        row.highlight:Show()
        row.label:SetTextColor(1, 1, 1)
        if row.option and row.option.description then
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            local owner = row.parentMode == "original" and "Original / shared - " or ""
            GameTooltip:SetText(owner .. (row.option.scopeLabel or ("Thread " .. row.option.thread)) .. ": " .. row.option.label)
            GameTooltip:AddLine(row.option.description, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end
    local function OnLeave()
        row.highlight:Hide()
        SetRowChecked(row, row.checked)
        GameTooltip:Hide()
    end
    row:SetScript("OnEnter", OnEnter)
    row:SetScript("OnLeave", OnLeave)
    row.checkBox:SetScript("OnEnter", OnEnter)
    row.checkBox:SetScript("OnLeave", OnLeave)
    row:SetScript("OnClick", function(self)
        if self.option then
            Options:SetEnabled(self.option.key, not self.checked, self.classToken)
        end
    end)

    return row
end

local function ApplyPosition(frame, x, y)
    if not IsFiniteNumber(x) or not IsFiniteNumber(y) then x, y = 0, 0 end
    -- This frame inherits UIParent's scale, so both sizes use the same UI units.
    local maxX = math.max(0, (UIParent:GetWidth() - frame:GetWidth()) / 2)
    local maxY = math.max(0, (UIParent:GetHeight() - frame:GetHeight()) / 2)
    x = math.max(-maxX, math.min(maxX, x))
    y = math.max(-maxY, math.min(maxY, y))
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", x, y)

    local db = _G.OliaEyes6_Settings
    if type(db) == "table" then db.position = { x = x, y = y } end
end

local function SavePosition(frame)
    local centerX, centerY = frame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if not centerX or not centerY or not parentX or not parentY then return end

    ApplyPosition(frame, centerX - parentX, centerY - parentY)
end

function Options:RestorePosition()
    if not self.frame then return end
    local db = _G.OliaEyes6_Settings
    local position = type(db) == "table" and db.position
    if type(position) == "table" then
        ApplyPosition(self.frame, position.x, position.y)
    else
        ApplyPosition(self.frame, 0, 0)
    end
end

function Options:Center()
    self:Show()
    self.frame:StopMovingOrSizing()
    ApplyPosition(self.frame, 0, 0)
end

function Options:CreateFrame()
    if self.frame then return self.frame end

    -- No backdrop or panel alpha: text and native checkboxes remain opaque.
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(PANEL_WIDTH, HEADER_HEIGHT + BOTTOM_PADDING)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    self.frame = frame

    local header = CreateFrame("Button", nil, frame)
    header:SetPoint("TOPLEFT", 1, 0)
    header:SetPoint("TOPRIGHT", -16, 0)
    header:SetHeight(HEADER_HEIGHT)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() frame:StartMoving() end)
    header:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SavePosition(frame)
    end)

    -- Separate from the drag surface so releasing a drag never hides the menu.
    local hide = CreateFrame("Button", nil, header)
    hide:SetSize(60, HEADER_HEIGHT)
    hide:SetPoint("TOPLEFT", 0, 0)
    hide:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    hide:SetScript("OnClick", function() Options:ToggleCollapsed() end)
    frame.hideButton = hide
    frame.header = header

    frame.title = hide:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.title:SetPoint("TOPLEFT", 1, -2)
    frame.title:SetText("OliaEyes")
    frame.title:SetTextColor(unpack(COLORS.text))
    hide:SetScript("OnEnter", function() frame.title:SetTextColor(1, 1, 1) end)
    hide:SetScript("OnLeave", function() frame.title:SetTextColor(unpack(COLORS.text)) end)

    frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.subtitle:SetPoint("TOPRIGHT", -18, -2)
    frame.subtitle:SetTextColor(unpack(COLORS.muted))

    local close = CreateFrame("Button", nil, frame)
    close:SetSize(14, 16)
    close:SetPoint("TOPRIGHT", 0, 0)
    close.text = close:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    close.text:SetPoint("CENTER")
    close.text:SetText("x")
    close.text:SetTextColor(unpack(COLORS.muted))
    close:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
    close:SetScript("OnLeave", function(self) self.text:SetTextColor(unpack(COLORS.muted)) end)
    close:SetScript("OnClick", function() Options:Hide() end)
    frame.closeButton = close

    return frame
end

-- Presentation ownership only: do not reorder the registered preference keys.
-- Original controls remain accessible because fallback paths can still use them.
local function OptionParent(option, classToken)
    if classToken ~= "WARRIOR" or ARMS_MODES[option.key] then return nil end
    if option.key:match("^adaptive_") then return "adaptive" end
    if option.key:match("^wowsims_") then return "wowsims" end
    if option.key:match("^thread%d+_") then return "original" end
end

local function DisplayOrder(definitions, classToken)
    local order, added = {}, {}
    if classToken == "WARRIOR" then
        for _, mode in ipairs({"original", "wowsims", "adaptive"}) do
            for index, option in ipairs(definitions) do
                if ARMS_MODES[option.key] == mode then
                    order[#order + 1], added[index] = index, true
                end
            end
            for index, option in ipairs(definitions) do
                if OptionParent(option, classToken) == mode then
                    order[#order + 1], added[index] = index, true
                end
            end
        end
    end
    for index in ipairs(definitions) do
        if not added[index] then order[#order + 1] = index end
    end
    return order
end

function Options:Refresh()
    if jungle.RoutineConfig and jungle.RoutineConfig.ready and self.RefreshRoutineUI then
        return self:RefreshRoutineUI()
    end
    local frame = self:CreateFrame()
    local db = _G.OliaEyes6_Settings
    local collapsed = type(db) == "table" and db.collapsed == true
    local classToken, className = GetPlayerClass()
    local definitions = GetDefinitions(classToken)
    local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]

    frame.subtitle:SetText(className)
    if classColor then
        frame.subtitle:SetTextColor(classColor.r, classColor.g, classColor.b)
    else
        frame.subtitle:SetTextColor(unpack(COLORS.muted))
    end

    local order = DisplayOrder(definitions, classToken)
    local offset = HEADER_HEIGHT
    for position, i in ipairs(order) do
        local row = self.rows[i]
        if not row then
            row = CreateOptionRow(frame, i)
            self.rows[i] = row
        end
        local option = definitions[i]
        row.option = option
        row.classToken = classToken
        row.parentMode = OptionParent(option, classToken)
        row.depth = row.parentMode and 1 or 0
        local modeRow = classToken == "WARRIOR" and ARMS_MODES[option.key]
        if modeRow and position > 1 then offset = offset + 6 end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -offset)
        row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -offset)
        row.checkBox:ClearAllPoints()
        row.checkBox:SetPoint("LEFT", row, "LEFT", row.depth * 12, 0)
        -- Real indentation includes the checkbox, rather than padding only its text.
        row.label:SetText((option.label:gsub("^%s+", "")))
        offset = offset + ROW_HEIGHT
        row.thread:SetText(option.scopeLabel and "U" or ("T" .. tostring(option.thread or "-")))
        SetRowChecked(row, self:IsEnabled(option.key, classToken))
        if collapsed then row:Hide() else row:Show() end
    end

    for i = #definitions + 1, #self.rows do
        self.rows[i]:Hide()
    end

    local height = (collapsed and HEADER_HEIGHT or offset) + BOTTOM_PADDING
    frame:SetHeight(height)
end

function Options:ToggleCollapsed()
    local db = _G.OliaEyes6_Settings
    if type(db) ~= "table" then return end
    local frame = self:CreateFrame()
    frame:StopMovingOrSizing()
    local x, y = frame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    local oldHeight = frame:GetHeight()
    db.collapsed = not (db.collapsed == true)
    GameTooltip:Hide()
    self:Refresh()
    -- Center-anchored storage: compensate for height to keep the header fixed.
    if x and y and parentX and parentY then
        ApplyPosition(frame, x - parentX, y - parentY + (oldHeight - frame:GetHeight()) / 2)
    else
        self:RestorePosition()
    end
end

function Options:Show()
    self:Refresh()
    self:RestorePosition()
    self.frame:Show()
    if _G.OliaEyes6_Settings then _G.OliaEyes6_Settings.shown = true end
end

function Options:Hide()
    if self.frame then self.frame:Hide() end
    if _G.OliaEyes6_Settings then _G.OliaEyes6_Settings.shown = false end
end

function Options:Toggle()
    local frame = self:CreateFrame()
    if frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

Options:RegisterOption("WARRIOR", {
    key = "thread1_demoralizing_shout",
    thread = 1,
    label = "Demoralizing Shout",
    default = true,
    description = "Existing PvE maintenance refresh and normal routine Shout blocks. Original debuff checks and priorities are unchanged.",
})
Options:RegisterOption("WARRIOR", {
    key = "thread1_thunder_clap",
    thread = 1,
    label = "Thunder Clap",
    default = true,
    description = "Original Thunder Clap blocks, including stance preparation. Also applies to the retained T1 Thunder Clap prepass with WoWSims. Adaptive has its own switch.",
})
Options:RegisterOption("WARRIOR", {
    key = "thread1_sunder_initial",
    thread = 1,
    label = "Sunder: initial",
    default = true,
    description = "Existing initial Sunder when no stacks are present. Can reapply after expiry; this is not one successful cast per target per combat. Existing Expose Armor checks remain unchanged.",
})
Options:RegisterOption("WARRIOR", {
    key = "thread1_sunder_stack",
    thread = 1,
    label = "Sunder: stack/refresh",
    default = true,
    description = "Existing stacking and refresh blocks when Sunder is already present, including refresh at five stacks. Does not apply the first stack when Initial is disabled.",
})
Options:RegisterOption("WARRIOR", {
    key = "thread2_demoralizing_shout",
    thread = 2,
    label = "Demoralizing Shout",
    default = true,
    description = "Existing core PvE Demoralizing Shout refresh. Also gates Adaptive PvP Demo fallback when missing or at 5 seconds. The Demo action switch applies independently.",
})
Options:RegisterOption("WARRIOR", {
    key = "thread2_sunder_routine",
    thread = 2,
    label = "Sunder: routine",
    default = true,
    description = "Existing Arms/Fury Sunder branches, which differ by spec and PvE/PvP. Includes only the original application, stacking or refresh behavior; not a new once-per-target rule.",
})
Options:RegisterOption("WARRIOR", {
    key = "thread2_sweeping_strikes",
    thread = 2,
    label = "Sweeping Strikes",
    default = true,
    description = "Shared by Original and WoWSims on T2. Controls Sweeping Strikes casts and preparation; an already-active buff is still used. Adaptive has its own switch.",
})
Options:RegisterOption("WARRIOR", {
    key = "thread3_demoralizing_shout",
    thread = 3,
    label = "Demoralizing Shout",
    default = true,
    description = "Existing AoE Shout in the Sweeping routine and Shout in normal fallback. Pooling ownership and original conditions are unchanged.",
})
Options:RegisterOption("WARRIOR", {
    key = "thread3_sunder_fallback",
    thread = 3,
    label = "Sunder: fallback",
    default = true,
    description = "Existing Sunder in the normal Arms/Fury fallback only. The dedicated thread-3 Sweeping/pooling routine has no Sunder action; this switch does not add one.",
})

-- A mode selector for the universal dispatcher, explicitly scoped there.
-- Uses IsEnabled, not AllowsForThread (which is only a restriction gate).
Options:RegisterOption("WARRIOR", {
    key = "universal_arms_original", thread = 2,
    scopeLabel = "Arms PvE mode (choose one)",
    label = "Arms: Original", default = true,
    description = "Default original routines and thread behavior. Nested thread controls belong to the original routines, including paths retained by other modes; shared cases are documented in their tooltips. Select exactly one Arms mode.",
})
Options:RegisterOption("WARRIOR", {
    key = "universal_arms_wowsims_st",
    thread = 2,
    scopeLabel = "Universal: T1/T2/T3 fallback",
    label = "Arms: WoWSims",
    default = false,
    description = "Opt-in Arms PvE rotation with single-target and 2+ eligible-target priorities (2H Slam / DW Arms). Choose Original to restore the original rotation. Applies to universal T1/T2/T3 fallback; Sunder/Demo use the four switches below; dedicated AoE ownership remains. Source: https://github.com/wowsims/tbc-new. See docs/WARRIOR_WOWSIMS.md for live adaptations.",
})

Options:RegisterOption("WARRIOR", {
    key = "universal_arms_adaptive", thread = 2,
    scopeLabel = "Arms mode (choose one)",
    label = "Arms: Adaptive", default = false,
    description = "Two-handed Arms scheduler sharing core PvE/PvP damage, Slam, queue and Sweeping decisions. PvE uses Adaptive support switches; PvP keeps Original utilities and Demo refresh. Bloodrage, Berserker Rage, Death Wish and trinkets are always disabled in Adaptive PvP.",
})

-- Independent WoWSims maintenance controls; the legacy thread switches remain
-- attached to their original routines. Registration order keeps these under U.
Options:RegisterOption("WARRIOR", {
    key = "wowsims_sunder_initial", thread = 2,
    scopeLabel = "WoWSims: T1/T2/T3 fallback",
    label = "  Sunder: first stack", default = false,
    description = "WoWSims single-target only: apply Sunder when no stacks are present. Never cast while Expose Armor is active. Independent of the legacy thread switches.",
})
Options:RegisterOption("WARRIOR", {
    key = "wowsims_sunder_stack", thread = 2,
    scopeLabel = "WoWSims: T1/T2/T3 fallback",
    label = "  Sunder: stack to 5", default = false,
    description = "WoWSims single-target only: build an existing 1-4 stacks to five. Does not apply the first stack or refresh five stacks. Never cast while Expose Armor is active.",
})
Options:RegisterOption("WARRIOR", {
    key = "wowsims_sunder_refresh", thread = 2,
    scopeLabel = "WoWSims: T1/T2/T3 fallback",
    label = "  Sunder: refresh", default = false,
    description = "WoWSims single-target only: refresh existing Sunder at 10 seconds or less when Mortal Strike and Whirlwind are both at least 1.5 seconds away. Never cast while Expose Armor is active. Works independently of stacking.",
})
Options:RegisterOption("WARRIOR", {
    key = "wowsims_demoralizing_shout", thread = 2,
    scopeLabel = "WoWSims: T1/T2/T3 fallback",
    label = "  Demoralizing Shout", default = false,
    description = "WoWSims only: optional filler when both core cooldowns are at least 1.5 seconds away and Demo has 5 seconds or less remaining. Skip while Demoralizing Roar, Curse of Weakness or Screech is active. The source Arms preset has no Demo action.",
})

-- Adaptive support assignments are independent of both older modes.
for _, option in ipairs({
    {"adaptive_sunder_initial", "  Sunder: first stack", false, "PvE: apply initial Sunder on bosses or targets estimated to live at least 12 seconds. PvP uses the Original Sunder switches. Skip Expose Armor."},
    {"adaptive_sunder_stack", "  Sunder: stack/refresh", false, "PvE: build existing Sunder on durable targets and refresh before expiry. PvP uses the Original Sunder switches. Does not apply the first stack."},
    {"adaptive_demo", "  PvE: maintain Demo", false, "PvE support only: apply missing Demo or refresh at 5 seconds on an eligible melee enemy, including ordinary NPCs without a lifetime estimate. Skip Roar/Curse of Weakness/Screech and unsafe area coverage. Protect only a currently usable stationary Slam window; moving/unavailable/unfunded Slam does not block Demo. PvP uses the Original Demo preference; this PvE switch does not control it."},
    {"adaptive_thunder_clap", "  Thunder Clap", false, "PvE support only: maintain assigned Thunder Clap, including stance preparation. PvP retains Original Thunder Clap conditions."},
    {"adaptive_sweeping", "  Sweeping Strikes", true, "Use Sweeping Strikes with two or more observed eligible nearby enemies; no health-percentage exclusion or indefinite pooling."},
    {"adaptive_cooldowns", "  Damage cooldowns", true, "PvE only: use learned Death Wish in melee and on-use trinkets on single targets/bosses. AoE trinkets have their own switch. Death Wish and trinkets are always disabled in Adaptive PvP."},
    {"adaptive_berserker_rage", "  Berserker Rage", true, "Use in spare combat globals in Berserker Stance. Preserve current and upcoming Slam opportunities and affordable core cooldowns. Skip while already active. Always disabled in Adaptive PvP."},
    {"adaptive_aoe_trinkets", "  AoE: both trinkets", true, "With two or more eligible nearby enemies, attempt equipped trinkets in slots 13 and 14 through the existing macro. PvE only; independent of Damage cooldowns. Item/shared cooldowns still apply. Always disabled in Adaptive PvP."},
    {"adaptive_recklessness", "  Recklessness", false, "PvE only: allow the long cooldown on a boss during Bloodlust or an estimated final 15 seconds. Held by default."},
}) do
    Options:RegisterOption("WARRIOR", {
        key = option[1], label = option[2], default = option[3], description = option[4],
        thread = 2, scopeLabel = "Adaptive: T1/T2/T3/T7",
    })
end

-- Shared DPS preference, outside the mode-specific groups.
Options:RegisterOption("WARRIOR", {
    key = "default_shout_battle", thread = 2,
    scopeLabel = "All DPS rotations: default shout (choose one)",
    label = "Default: Battle", default = true,
    description = "Cast Battle Shout when neither shout is active. Keep and refresh your own active shout, or supply the missing shout when another warrior supplies one. Applies to every DPS rotation; tanking is unchanged.",
})
Options:RegisterOption("WARRIOR", {
    key = "default_shout_commanding", thread = 2,
    scopeLabel = "All DPS rotations: default shout (choose one)",
    label = "Default: Commanding", default = false,
    description = "Cast Commanding Shout when neither shout is active. Keep and refresh your own active shout, or supply the missing shout when another warrior supplies one. Applies to every DPS rotation; tanking is unchanged.",
})

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, loadedAddon)
    if event ~= "ADDON_LOADED" then
        -- Event-driven recovery after a display/UI-scale change; no polling.
        Options:RestorePosition()
        return
    end
    if loadedAddon ~= AddonName then return end

    local db = InitializeSettings()
    local frame = Options:CreateFrame()
    Options:Refresh()
    Options:RestorePosition()
    if db.shown then frame:Show() else frame:Hide() end
    self:UnregisterEvent("ADDON_LOADED")
    self:RegisterEvent("DISPLAY_SIZE_CHANGED")
    self:RegisterEvent("UI_SCALE_CHANGED")
end)
