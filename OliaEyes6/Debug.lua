local Jungle, jungle = ...
local Debug = {}
jungle.Debug = Debug

-- 1. Configuration
Debug.enabled = false

-- 2. Create the Dashboard Frame
local frame = CreateFrame("Frame", "OliaDebugPanel", UIParent, "BackdropTemplate")
frame:SetSize(220, 110)
frame:SetPoint("CENTER", 0, -100)
frame:SetFrameStrata("TOOLTIP") -- Always on top
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:Hide() -- Hidden by default

-- Backdrop (Dark Styling)
frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
frame:SetBackdropColor(0, 0, 0, 0.85)

-- 3. UI Elements
local function CreateLabel(y, text)
    local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", 10, y)
    fs:SetText(text)
    return fs
end

local function CreateValue(y)
    local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", 60, y)
    fs:SetText("-")
    return fs
end

-- Header
local header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
header:SetPoint("TOP", 0, -10)
header:SetText("OliaEyes Debugger")

-- Rows
CreateLabel(-35, "Thread:")
local valThread = CreateValue(-35)

CreateLabel(-50, "Action:")
local valAction = CreateValue(-50)

CreateLabel(-65, "Target:")
local valTarget = CreateValue(-65)

CreateLabel(-80, "Color:")
local valColor = CreateValue(-80)

-- Color Swatch (Visual Box)
local colorSwatch = frame:CreateTexture(nil, "OVERLAY")
colorSwatch:SetSize(16, 16)
colorSwatch:SetPoint("LEFT", valColor, "RIGHT", 5, 0)
colorSwatch:SetColorTexture(0, 0, 0, 1)

-- 4. Logic Functions

function Debug:Toggle(state)
    self.enabled = state
    if state then 
        frame:Show() 
        print("|cff00ccff[OliaEyes]|r Debug Panel: SHOWN")
    else 
        frame:Hide() 
        print("|cff00ccff[OliaEyes]|r Debug Panel: HIDDEN")
    end
end

-- Called by Cast.lua to update the display
function Debug:UpdateCast(spellName, targetName, rgb)
    if not self.enabled then return end

    -- Update Thread
    local thread = (jungle.Engine and jungle.Engine.activeThread) or 0
    valThread:SetText(thread)

    -- Update Action
    valAction:SetText(spellName or "Idle")

    -- Update Target
    valTarget:SetText(targetName or "None")

    -- Update Color Logic
    if rgb then
        valColor:SetText(string.format("%.2f, %.2f, %.2f", rgb[1], rgb[2], rgb[3]))
        colorSwatch:SetColorTexture(rgb[1], rgb[2], rgb[3], 1)
    else
        valColor:SetText("0, 0, 0")
        colorSwatch:SetColorTexture(0, 0, 0, 1)
    end
end

-- Optional: Reset display when idle
function Debug:Reset()
    if not self.enabled then return end
    self:UpdateCast("Waiting...", nil, {0,0,0})
end