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
jungle.GetGCDValues = GetGCDValues

-- Checks if a spell is on a "Real" Cooldown (Ignoring GCD)
-- Used for decision making (e.g., "Is Swiftmend available?")
local function SpellOnCD(_spell)
    -- 1. Get Target Spell Cooldown
    local start, spellDuration, enabled = GetSpellCooldown(_spell)
    
    -- FACT: If you don't know the spell, start will be nil or 0
    if not start or not GetSpellBookItemInfo(_spell) then 
        return true -- Treat unknown spells as "on cooldown" to skip them
    end

    -- 2. Logic: If spell duration > GCD duration, it's on real CD
    local _, gcdDuration = GetGCDValues()
    if (spellDuration - gcdDuration) <= 0.05 then 
        return false -- Ready (or just on GCD)
    else
        return true -- On actual cooldown
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

-- Strict Execution Gate
-- Returns TRUE only if the spell can physically be cast RIGHT NOW.
local function ReadyCastSpell(_spell, _target)
    local _, _, lagHome, _ = GetNetStats()
    lagHome = (lagHome or 0) / 1000
    
    -- 1. Check if Spell Exists in game AND if the player knows it
    local name = GetSpellInfo(_spell)
    if not name or not GetSpellBookItemInfo(_spell) then 
        return false 
    end
    
    -- 2. Check Usable (Mana/Stance)
    local usable, nomana = IsUsableSpell(_spell)
    if (not usable) or nomana then return false end
    
    -- 3. Check Range (Classic Specific Logic)
    if _target and _target ~= 'player' then
        -- IsSpellInRange: 1=Yes, 0=No, nil=Invalid Target
        local inRange = IsSpellInRange(_spell, _target)
        if inRange ~= 1 then return false end
    end
    
    -- 4. Cooldown & GCD Check [UPDATED]
    local start, duration = GetSpellCooldown(_spell)
    if not start then return false end

    -- If duration > 0, the spell is "busy" (either Global CD or Spell CD)
    if duration > 0 then
        local readyAt = start + duration - lagHome
        local rem = readyAt - GetTime()

        -- STRICT GCD THROTTLE:
        -- Only return true if we are within the "Spell Queue Window" (0.2s).
        -- Otherwise, we are too early, and casting now would just spam errors.
        if rem > 0.2 then
            return false
        end
    end
    
    -- 5. Player State
    if UnitIsDeadOrGhost('player') then return false end

    return true
end
jungle.ReadyCastSpell = ReadyCastSpell