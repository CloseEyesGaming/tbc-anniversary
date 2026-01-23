local Jungle, jungle = ...

-- Static Cast Engine
local Cast = {}
jungle.Cast = Cast

-- Pre-allocate helpers ONCE
local colorHelper = jungle.Color:new()
local pixelHelper = jungle.Pixel:new({0,0,0}, 1) 

function Cast:CastSpell(spell, target, pix)
    if pix then pixelHelper.size = pix end

    -- Prepare variables for decision
    local finalColor = nil
    local finalAction = ""

    if not UnitExists('focus') or not UnitIsUnit('focus', target) then
        -- Logic: Set Focus Color
        finalColor = colorHelper:makeColor(target)
        finalAction = "Set Focus: " .. (target or "?")
    elseif UnitIsUnit('focus', target) then
        -- Logic: Cast Spell Color
        finalColor = colorHelper:makeColor(spell)
        finalAction = "Cast: " .. (spell or "?")
    end

    -- [DEBUG HOOK] Send data to the fancy panel
    if jungle.Debug then
        jungle.Debug:UpdateCast(finalAction, target, finalColor)
    end

    -- Execute
    if finalColor then
        pixelHelper.color = finalColor
        return pixelHelper:set()
    end
end

function Cast:Reset(pix)
    if pix then pixelHelper.size = pix end
    
    local defColor
    local statusText = "Idle"

    if UnitExists('focus') then
        defColor = colorHelper:makeColor('clearfocus')
        statusText = "Clear Focus"
    else
        defColor = colorHelper:makeColor('dummyColor')
        statusText = "Idle (Black)"
    end
    
    -- [DEBUG HOOK] Update panel to show idle state
    if jungle.Debug then
        jungle.Debug:UpdateCast(statusText, "None", defColor)
    end
    
    pixelHelper.color = defColor
    return pixelHelper:set()
end