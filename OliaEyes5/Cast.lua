local Jungle, jungle = ...

-- Static Cast Engine (No more :new())
local Cast = {}
jungle.Cast = Cast

-- Pre-allocate helpers ONCE (Singleton pattern)
local colorHelper = jungle.Color:new()
local pixelHelper = jungle.Pixel:new({0,0,0}, 1) -- We will update this pixel's data, not create new ones

function Cast:CastSpell(spell, target, pix)
    -- Update the re-usable pixel's position/size if 'pix' changes (rare, but safe)
    if pix then pixelHelper.size = pix end

    if not UnitExists('focus') or not UnitIsUnit('focus', target) then
        -- Logic: Set Focus Color
        local trgColor = colorHelper:makeColor(target)
        pixelHelper.color = trgColor
        return pixelHelper:set() 
    elseif UnitIsUnit('focus', target) then
        -- Logic: Cast Spell Color
        local spColor = colorHelper:makeColor(spell)
        pixelHelper.color = spColor
        return pixelHelper:set()
    end
end

function Cast:Reset(pix)
    if pix then pixelHelper.size = pix end
    
    local defColor
    if UnitExists('focus') then
        defColor = colorHelper:makeColor('clearfocus')
    else
        defColor = colorHelper:makeColor('dummyColor')
    end
    
    pixelHelper.color = defColor
    return pixelHelper:set()
end