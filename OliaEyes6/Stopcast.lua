local Jungle, jungle = ...

--[[
    UNIVERSAL STOPCAST ENGINE (Metadata-Driven)
    -------------------------------------------
    This engine monitors active player casts and evaluates whether they should be 
    aborted based on custom rules provided by the rotation.

    HOW TO USE:
    In your class rotation file (e.g., Druid.lua), define your rules in the 4th parameter:
    { target, "Spell Name", start_condition, stop_condition_func }

    PARAMETER 4 (Metadata Closure):
    - Receives one argument: 't' (The stable UnitToken resolved from the original GUID).
    - MUST return TRUE to trigger a /stopcasting command.
    - MUST return FALSE to allow the cast to continue.

    WHY THIS APPROACH?
    1. Stability: Uses GUID-to-Token resolution so target swaps don't break the check.
    2. Performance: Only evaluates the specific rule for the active spell.
    3. Safety: Decoupled from start conditions to avoid Global Cooldown (GCD) loops.

    EXAMPLE (Overheal Prevention):
    { _target, "Regrowth", true, function(t) return jungle.predictedLife(t) > 0.95 end }
--]]

function jungle.CurrentCastStop()
    -- 1. Identify current player activity
    local castingSpell = UnitCastingInfo("player")
    
    -- 2. Exit if not casting or if the cast doesn't match our recorded state
    if not castingSpell or castingSpell ~= jungle.CurrentCast.spellName then 
        return false 
    end

    -- 3. Retrieve the metadata closure passed from the rotation
    local rule = jungle.CurrentCast.stopcastFunc
    
    if type(rule) == "function" then
        -- 4. Resolve the GUID back to a usable UnitToken (player, party1, etc.)
        local stableToken = jungle.GetTokenByGUID(jungle.CurrentCast.targetGUID)
        
        if stableToken and UnitExists(stableToken) then
            -- 5. Execute the custom rule logic
            return rule(stableToken)
        end
    end
    
    return false
end