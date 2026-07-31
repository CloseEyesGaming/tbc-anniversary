local Jungle, jungle = ...

-- Static Cast Engine
local Cast = {}
jungle.Cast = Cast

-- Pre-allocate helpers ONCE
local colorHelper = jungle.Color:new()
local pixelColor = {0, 0, 0}
local pixelHelper = jungle.Pixel:new(pixelColor, 1) 

local function GetFocusUnit(target)
    if target == 'target'
    and UnitExists('softenemy')
    and UnitIsUnit('target', 'softenemy') then
        return 'softenemy'
    end
    return target
end

function Cast:CastSpell(spell, target, pix)
    if pix then pixelHelper.size = pix end

    -- Prepare variables for decision
    local r, g, b
    local debugEnabled = jungle.Debug and jungle.Debug.enabled
    local finalAction
    local focusUnit = GetFocusUnit(target)

    if not UnitExists('focus') or not UnitIsUnit('focus', target) then
        -- Logic: Set Focus Color
        r, g, b = colorHelper:getRGB(focusUnit)
        if debugEnabled then
            finalAction = "Set Focus: " .. (focusUnit or "?")
        end
    elseif UnitIsUnit('focus', target) then
        -- Logic: Cast Spell Color
        r, g, b = colorHelper:getRGB(spell)
        if debugEnabled then
            finalAction = "Cast: " .. (spell or "?")
        end
    end

    -- [DEBUG HOOK] Send data to the fancy panel
    if debugEnabled then
        jungle.Debug:UpdateCast(finalAction, target, {r, g, b})
    end

    -- Execute
    if r then
        pixelColor[1], pixelColor[2], pixelColor[3] = r, g, b
        return pixelHelper:set()
    end
end

function Cast:Reset(pix)
    if pix then pixelHelper.size = pix end
    
    local r, g, b
    local debugEnabled = jungle.Debug and jungle.Debug.enabled
    local statusText

    if UnitExists('focus') then
        r, g, b = colorHelper:getRGB('clearfocus')
        if debugEnabled then statusText = "Clear Focus" end
    else
        r, g, b = colorHelper:getRGB('dummyColor')
        if debugEnabled then statusText = "Idle (Black)" end
    end
    
    -- [DEBUG HOOK] Update panel to show idle state
    if debugEnabled then
        jungle.Debug:UpdateCast(statusText, "None", {r, g, b})
    end
    
    pixelColor[1], pixelColor[2], pixelColor[3] = r, g, b
    return pixelHelper:set()
end
