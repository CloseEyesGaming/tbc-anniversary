local Jungle, jungle = ...
jungle.RoutineAllows = jungle.RoutineAllows or function() return true end

-- Populated by Hotkeys before button creation; refreshed with macros outside combat.
jungle.actionHasRange = {}

-- Helper: Safe GCD Check using Global API
local function GetGCDValues(snapshot)
    if snapshot and snapshot.gcdRead then return snapshot.gcdStart, snapshot.gcdDuration end
    if jungle.RaidTrace.sample then jungle.RaidTrace:Count("GetGCDValuesCalls") end
    -- UPDATED: Uses GCD_SPELL_ID now
    local gcdID = jungle.offsets.GCD_SPELL_ID or 61304
    
    -- GetSpellCooldown(id) returns: start, duration, enabled
    local start, duration = GetSpellCooldown(gcdID)
    
    if not start then 
        -- Fallback: If the class specific ID fails, try the generic dummy
        start, duration = GetSpellCooldown(61304)
    end
    
    if not start then start, duration = 0, 0 end
    if snapshot then
        snapshot.gcdRead, snapshot.gcdStart, snapshot.gcdDuration = true, start, duration
    end
    return start, duration
end
jungle.GetGCDValues = GetGCDValues

-- Equipment requests wait for full GCD expiry only while the player is in combat.
function jungle.CanSwapWeapons()
    if not UnitAffectingCombat("player") then return true end
    local start, duration = GetGCDValues()
    return start <= 0 or duration <= 0 or start + duration <= GetTime()
end

-- Checks if a spell is on a "Real" Cooldown (Ignoring GCD)
-- Used for decision making (e.g., "Is Swiftmend available?")
local function SpellOnCD(_spell, snapshot)
    if not jungle.RoutineAllows(_spell) then return true end
    if jungle.RaidTrace.sample then jungle.RaidTrace:Count("SpellOnCDCalls") end
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
    local gcdStart, gcdDuration = GetGCDValues(snapshot)
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
local function ReadyCastSpell(_spell, _target, snapshot)
    if not jungle.RoutineAllows(_spell) then return false end
    if jungle.RaidTrace.sample then jungle.RaidTrace:Count("ReadyCastSpellCalls") end
    -- Opt-in healing snapshot: player/spell checks are shared; target checks
    -- remain live. Callers without a snapshot retain the original path below.
    if snapshot then
        if not jungle.IsSpellReadyIgnoreGCD(_spell, snapshot) then return false end
        if _target and jungle.IsTargetImmuneToDruidDamageSpell
            and jungle.IsTargetImmuneToDruidDamageSpell(_spell, _target) then return false end
        if jungle.actionHasRange[_spell] and _target and _target ~= 'player'
            and IsSpellInRange(_spell, _target) ~= 1 then return false end
        return true
    end
    -- 1. Check if Spell Exists in game AND if the player knows it
    local name = GetSpellInfo(_spell)
    if not name or not GetSpellBookItemInfo(_spell) then 
        return false 
    end

    -- GameData loads after this module, so resolve the optional target-school
    -- validator at call time. This prevents known immune NPCs from entering any
    -- Druid caster rotation without coupling those lists to this core helper.
    if _target
    and jungle.IsTargetImmuneToDruidDamageSpell
    and jungle.IsTargetImmuneToDruidDamageSpell(_spell, _target) then
        return false
    end
    
    -- 2. Check Usable (Mana/Stance)
    local usable, nomana = IsUsableSpell(_spell)
    if (not usable) or nomana then return false end
    
    -- 3. Only range-bearing actions need a live context-unit range check.
    if jungle.actionHasRange[_spell] and _target and _target ~= 'player' then
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
local function IsSpellReadyIgnoreGCD(_spell, snapshot)
    if not jungle.RoutineAllows(_spell) then return false end
    if jungle.RaidTrace.sample then jungle.RaidTrace:Count("IsSpellReadyIgnoreGCDCalls") end
    -- 1. Check if spell exists and is known
    local name = GetSpellInfo(_spell)
    if not name or not GetSpellBookItemInfo(_spell) then 
        return false 
    end
    
    -- 2. Check Usable (Mana/Stance)
    local usable, nomana = IsUsableSpell(_spell)
    if (not usable) or nomana then return false end
    
    -- 3. Check Cooldown (ignoring GCD)
    if SpellOnCD(_spell, snapshot) then
        return false
    end
    
    -- 4. Player State
    if UnitIsDeadOrGhost('player') then return false end

    return true
end
jungle.IsSpellReadyIgnoreGCD = function(spell, snapshot)
    if not jungle.RoutineAllows(spell) then return false end
    if not snapshot then return IsSpellReadyIgnoreGCD(spell) end
    local ready = snapshot.ready[spell]
    if ready == nil then
        ready = IsSpellReadyIgnoreGCD(spell, snapshot)
        snapshot.ready[spell] = ready
    end
    return ready
end

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
