local Jungle, jungle = ...
if not jungle.Arena then return end

local Arena = jungle.Arena

local CLASS_ICON_TCOORDS = {
	["WARRIOR"] = {0, 0.25, 0, 0.25},
	["MAGE"] = {0.25, 0.49609375, 0, 0.25},
	["ROGUE"] = {0.49609375, 0.7421875, 0, 0.25},
	["DRUID"] = {0.7421875, 0.98828125, 0, 0.25},
	["HUNTER"] = {0, 0.25, 0.25, 0.5},
	["SHAMAN"] = {0.25, 0.49609375, 0.25, 0.5},
	["PRIEST"] = {0.49609375, 0.7421875, 0.25, 0.5},
	["WARLOCK"] = {0.7421875, 0.98828125, 0.25, 0.5},
	["PALADIN"] = {0, 0.25, 0.5, 0.75}
}

local SPEC_ICONS = {
    ["Arms"] = 12294, ["Fury"] = 23881, ["Protection"] = 23922,
    ["Holy"] = 20473, ["Retribution"] = 35395,
    ["Discipline"] = 10060, ["Shadow"] = 15473,
    ["Assassination"] = 34411, ["Combat"] = 13750, ["Subtlety"] = 36554,
    ["Balance"] = 33831, ["Feral"] = 33876, ["Restoration"] = 18562,
    ["Elemental"] = 16166, ["Enhancement"] = 30823,
    ["Arcane"] = 12042, ["Fire"] = 31661, ["Frost"] = 11426,
    ["Affliction"] = 30108, ["Demonology"] = 18708, ["Destruction"] = 30283,
    ["Beast Mastery"] = 19577, ["Marksmanship"] = 34490, ["Survival"] = 19386
}

local DR_CATEGORIES = {
    { name = "Root", tab = "Controlled_Root_table", icon = 339 },
    { name = "Stun", tab = "Controlled_Stun_table", icon = 8643 },
    { name = "Disorient", tab = "Disorient_table", icon = 2094 },
    { name = "Incapacitate", tab = "Incapacitate_table", icon = 118 },
    { name = "Silence", tab = "Silence_table", icon = 15487 },
}

local debugFrame = CreateFrame("Frame", "OliaArenaDebugFrame", UIParent, "BackdropTemplate")
debugFrame:SetSize(450, 200)
debugFrame:SetPoint("CENTER")
debugFrame:SetMovable(true)
debugFrame:EnableMouse(true)
debugFrame:RegisterForDrag("LeftButton")
debugFrame:SetScript("OnDragStart", debugFrame.StartMoving)
debugFrame:SetScript("OnDragStop", debugFrame.StopMovingOrSizing)
debugFrame:Hide()

if debugFrame.SetBackdrop then
    debugFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
end

local title = debugFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
title:SetPoint("TOP", 0, -10)
title:SetText("Olia Arena Debug")

local rows = {}
local ICON_SIZE = 24
local SPACING = 4

local function GetOrCreateRow(index)
    if not rows[index] then
        local row = CreateFrame("Frame", nil, debugFrame)
        row:SetSize(430, ICON_SIZE)
        row:SetPoint("TOPLEFT", 10, -30 - (index - 1) * (ICON_SIZE + SPACING))
        
        row.classIcon = row:CreateTexture(nil, "ARTWORK")
        row.classIcon:SetSize(ICON_SIZE, ICON_SIZE)
        row.classIcon:SetPoint("LEFT", 0, 0)
        row.classIcon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")

        row.specIcon = row:CreateTexture(nil, "ARTWORK")
        row.specIcon:SetSize(ICON_SIZE, ICON_SIZE)
        row.specIcon:SetPoint("LEFT", row.classIcon, "RIGHT", SPACING, 0)
        
        row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.nameText:SetPoint("LEFT", row.specIcon, "RIGHT", SPACING, 0)
        row.nameText:SetWidth(60)
        row.nameText:SetJustifyH("LEFT")

        row.spells = {}
        row.drs = {}
        rows[index] = row
    end
    return rows[index]
end

local function GetOrCreateSpellIcon(row, index)
    if not row.spells[index] then
        local icon = CreateFrame("Frame", nil, row)
        icon:SetSize(ICON_SIZE, ICON_SIZE)
        if index == 1 then
            icon:SetPoint("LEFT", row.nameText, "RIGHT", SPACING, 0)
        else
            icon:SetPoint("LEFT", row.spells[index - 1], "RIGHT", SPACING, 0)
        end
        
        icon.tex = icon:CreateTexture(nil, "ARTWORK")
        icon.tex:SetAllPoints()
        
        icon.cdText = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        icon.cdText:SetPoint("CENTER", 1, -1)
        icon.cdText:SetTextColor(1, 1, 0)
        
        row.spells[index] = icon
    end
    return row.spells[index]
end

local function GetOrCreateDRIcon(row, index)
    if not row.drs[index] then
        local icon = CreateFrame("Frame", nil, row)
        icon:SetSize(ICON_SIZE, ICON_SIZE)
        if index == 1 then
            icon:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        else
            icon:SetPoint("RIGHT", row.drs[index - 1], "LEFT", -SPACING, 0)
        end
        
        icon.tex = icon:CreateTexture(nil, "ARTWORK")
        icon.tex:SetAllPoints()
        
        icon.drText = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        icon.drText:SetPoint("CENTER", 1, -1)
        icon.drText:SetTextColor(1, 0.2, 0.2)
        
        row.drs[index] = icon
    end
    return row.drs[index]
end

local function UpdateUI()
    if not debugFrame:IsVisible() then return end
    
    -- Hide all components first
    for _, row in ipairs(rows) do
        row:Hide()
        for _, s in ipairs(row.spells) do s:Hide() end
        for _, d in ipairs(row.drs) do d:Hide() end
    end
    
    local rowIndex = 1
    local time = GetTime()
    
    for unit, data in pairs(Arena.enemies) do
        local row = GetOrCreateRow(rowIndex)
        row:Show()
        
        -- Class
        if CLASS_ICON_TCOORDS[data.class] then
            row.classIcon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[data.class]))
        end
        
        -- Spec
        local specSpell = SPEC_ICONS[data.spec]
        if specSpell then
            row.specIcon:SetTexture(GetSpellTexture(specSpell))
            row.specIcon:SetTexCoord(0, 1, 0, 1)
        else
            row.specIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            row.specIcon:SetTexCoord(0, 1, 0, 1)
        end
        
        row.nameText:SetText(data.name)
        
        -- Spells
        local expected = Arena:GetExpectedCooldowns(data.name)
        for i, spellId in ipairs(expected) do
            local sIcon = GetOrCreateSpellIcon(row, i)
            sIcon:Show()
            
            local name, iconTex
            local spellInfo = C_Spell.GetSpellInfo(spellId)
            if spellInfo then
                name = spellInfo.name
                iconTex = spellInfo.iconID
            end
            sIcon.tex:SetTexture(iconTex)
            
            local cdData = Arena.cooldowns[data.name] and Arena.cooldowns[data.name][name]
            if cdData and cdData.expires > time then
                sIcon.tex:SetDesaturated(true)
                sIcon.tex:SetVertexColor(0.5, 0.5, 0.5)
                sIcon.cdText:SetText(math.ceil(cdData.expires - time))
            else
                sIcon.tex:SetDesaturated(false)
                sIcon.tex:SetVertexColor(1, 1, 1)
                sIcon.cdText:SetText("")
            end
        end
        
        -- DRs
        local drIndex = 1
        for _, cat in ipairs(DR_CATEGORIES) do
            local drTab = _G[cat.tab]
            if drTab and jungle.getDR then
                local drLevel = jungle.getDR(data.name, drTab)
                if drLevel > 0 then
                    local dIcon = GetOrCreateDRIcon(row, drIndex)
                    dIcon:Show()
                    dIcon.tex:SetTexture(GetSpellTexture(cat.icon))
                    
                    if drLevel == 1 then dIcon.drText:SetText("1/2")
                    elseif drLevel == 2 then dIcon.drText:SetText("1/4")
                    else dIcon.drText:SetText("Imm") end
                    
                    drIndex = drIndex + 1
                end
            end
        end
        
        rowIndex = rowIndex + 1
    end
end

debugFrame:SetScript("OnUpdate", function(self, elapsed)
    self.timer = (self.timer or 0) + elapsed
    if self.timer > 0.2 then
        self.timer = 0
        UpdateUI()
    end
end)

SLASH_OLIAARENADEBUG1 = "/olia"
local origSlash = SlashCmdList["OLIA"]
SlashCmdList["OLIA"] = function(msg)
    if msg:lower() == "arena debug" then
        if debugFrame:IsVisible() then
            debugFrame:Hide()
            print("|cff00FF00[OliaEyes]|r Arena Debug Disabled")
        else
            debugFrame:Show()
            print("|cff00FF00[OliaEyes]|r Arena Debug Enabled")
        end
    elseif origSlash then
        origSlash(msg)
    end
end
