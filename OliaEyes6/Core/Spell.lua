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

    -- 2. Immediate pass for completely ready or Off-GCD spells
    if spellDuration <= 0.05 then
        return false
    end

    -- 3. Logic: If spell duration > GCD duration, it's on real CD
    local gcdStart, gcdDuration = GetGCDValues()
    if (spellDuration - gcdDuration) <= 0.05 then 
        -- [NEW] Early Fire Window Check for GCD-locked spells
        if gcdStart and gcdStart > 0 then
            local gcdRemaining = (gcdStart + gcdDuration) - GetTime()
            -- If GCD has more than 0.5s left, don't fire the pixel yet
            if gcdRemaining > 0.5 then
                return true
            end
        end
        return false -- Ready (or GCD is within 0.5s of expiring)
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
    
    -- 4. Cooldown Check [UPDATED]
    -- The user requested we ignore GCD to allow "prespamming" via the engine.
    -- We only return false if the spell is on a REAL cooldown.
    if SpellOnCD(_spell) then
        return false
    end
    
    -- 5. Player State
    if UnitIsDeadOrGhost('player') then return false end

    return true
end
jungle.ReadyCastSpell = ReadyCastSpell

-- Checks if a spell is ready (has mana/stance, known) and NOT on a real cooldown, ignoring GCD.
-- This allows rotations to check if they should "prespam" a spell.
local function IsSpellReadyIgnoreGCD(_spell)
    -- 1. Check if spell exists and is known
    local name = GetSpellInfo(_spell)
    if not name or not GetSpellBookItemInfo(_spell) then 
        return false 
    end
    
    -- 2. Check Usable (Mana/Stance)
    local usable, nomana = IsUsableSpell(_spell)
    if (not usable) or nomana then return false end
    
    -- 3. Check Cooldown (ignoring GCD)
    if SpellOnCD(_spell) then
        return false
    end
    
    -- 4. Player State
    if UnitIsDeadOrGhost('player') then return false end

    return true
end
jungle.IsSpellReadyIgnoreGCD = IsSpellReadyIgnoreGCD

function jungle.IsTrinketReady(slotID)
    local itemID = GetInventoryItemID("player", slotID)
    if itemID then
        local isUsable = IsUsableItem(itemID)
        local start, duration = GetInventoryItemCooldown("player", slotID)
        local isOnCooldown = (start and start > 0 and duration > 0)

        if isUsable and not isOnCooldown then
            return true
        end
    end
    return false
end

function jungle.AreTrinketsReady()
    return jungle.IsTrinketReady(13) or jungle.IsTrinketReady(14)
end