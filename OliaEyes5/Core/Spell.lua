local Jungle, jungle = ...

-- Helper: Safe GCD Check using Global API
local function GetGCDValues()
    -- UPDATED: Uses GCD_SPELL_ID now
    local gcdID = jungle.offsets.GCD_SPELL_ID or 61304
    
    -- GetSpellCooldown(id) returns: start, duration, enabled
    local start, duration = GetSpellCooldown(gcdID)
    
    if not start then 
        -- Fallback: If the class specific ID fails, try the generic dummy
        start, duration = GetSpellCooldown(61304)
    end
    
    if not start then return 0, 0 end
    return start, duration
end

local function SpellOnCD(_spell)
    -- 1. Get GCD
    local _, gcdDuration = GetGCDValues()
    
    -- 2. Get Target Spell Cooldown (Global API supports Strings)
    local start, spellDuration, enabled = GetSpellCooldown(_spell)
    
    if not start then 
        -- Spell not found in spellbook
        return false 
    end

    -- 3. Logic: If spell duration > GCD duration, it's on real CD
    if (spellDuration - gcdDuration) <= 0.05 then -- 0.05 tolerance
        return false
    else
        return true
    end
end
jungle.SpellOnCD = SpellOnCD


local function TimeToReady(_spell)
    local start, duration = GetSpellCooldown(_spell)
    if not start then return 0 end
    
    if SpellOnCD(_spell) then
        return (start + duration - GetTime())
    else 
        return 0
    end
end
jungle.TimeToReady = TimeToReady


local function ReadyCastSpell(_spell, _target)
    local _, _, lagHome, _ = GetNetStats()
    lagHome = lagHome or 0
    
    -- 1. Check if Spell Exists (Name or ID)
    local name = GetSpellInfo(_spell)
    if not name then return false end
    
    -- 2. Check Usable (Mana/Stance)
    local usable, nomana = IsUsableSpell(_spell)
    if (not usable) or nomana then return false end
    
    -- 3. Check Range (Classic Specific Logic)
    -- IsSpellInRange: 1=Yes, 0=No, nil=Invalid Target
    if _target and _target ~= 'player' then
        local inRange = IsSpellInRange(_spell, _target)
        if inRange ~= 1 then return false end
    end
    -- Note: We skip range check for 'player' (always in range of self)
    
    -- 4. Check Cooldown vs GCD
    local start, duration = GetSpellCooldown(_spell)
    local start1, duration1 = GetGCDValues()
    
    local onCooldown = false
    if (duration - duration1) > 0.1 then -- If CD is significantly longer than GCD
         local readyAt = start + duration - (lagHome/1000)
         if (GetTime() < readyAt) then
             onCooldown = true
         end
    end
    
    if onCooldown then return false end
    
    -- 5. Player State
    if UnitIsDeadOrGhost('player') then return false end

    return true
end
jungle.ReadyCastSpell = ReadyCastSpell