local Jungle, jungle = ...

-- Metadata storage (Initialized in Main or Engine)
jungle.CurrentCast = jungle.CurrentCast or {
    targetGUID = nil,
    spellName = nil,
    priority = 999,
    routineFunc = nil
}

function jungle.CurrentCastStop(spell, minPriority, maxPriority)
    -- 1. Verify we are actually casting the spell we think we are
    local castingName = UnitCastingInfo("player")
    if not castingName or castingName ~= spell then 
        return false 
    end

    local target = "focus" -- Engine logic uses focus for cast targets
    local routine = jungle.CurrentCast.routineFunc
    if not routine then return false end

    -- 2. Execute the routine to check for higher priority shifts
    -- We only care about indices from 1 up to our current cast's priority
    local tbl = routine(target)
    for i = minPriority, maxPriority do
        if tbl[i] then
            local isConditionMet = tbl[i][3]
            
            -- If a HIGHER priority (lower index) condition is now true: STOP
            if isConditionMet and i < jungle.CurrentCast.priority then
                return true
            end

            -- If our OWN condition is no longer true (e.g. overheal/topped off): STOP
            if not isConditionMet and i == jungle.CurrentCast.priority then
                return true
            end
        end
    end

    return false
end