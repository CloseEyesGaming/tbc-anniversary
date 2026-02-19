local Jungle, jungle = ...

--[[
    ========================================================================
    Module: Energy Tracker
    ========================================================================
    Tracks the 2-second server-side energy tick for Druids/Rogues.
    Essential for Feral Powershifting logic to avoid clipping ticks.
]]

local Energy = {}
jungle.Energy = Energy

-- Internal State
local lastTickTime = 0
local previousEnergy = 0
local TICK_INTERVAL = 2.0

-- Frame for Event Listening
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UNIT_POWER_UPDATE")

-- Event Handler
frame:SetScript("OnEvent", function(self, event, unit, powerType)
    if event == "PLAYER_ENTERING_WORLD" then
        previousEnergy = UnitPower("player", 3)
        lastTickTime = GetTime()
    elseif event == "UNIT_POWER_UPDATE" then
        if unit == "player" and powerType == "ENERGY" then
            local currentEnergy = UnitPower("player", 3)
            
            -- Detect Tick: If energy increased
            if currentEnergy > previousEnergy then
                -- Heuristic: A natural tick is usually 20 (or 22 with talents), 
                -- but any increase suggests a sync point unless it's an instant refund.
                -- For stability, we sync on any increase for now.
                
                -- Refine sync: Only sync if it's been roughly 2s since last recorded tick
                -- OR if this is the first sync.
                local now = GetTime()
                local timeSinceLast = now - lastTickTime
                
                -- If the gap is plausible for a tick (close to 2s) or we are desynced
                if timeSinceLast >= 1.9 or timeSinceLast > 10 then
                     lastTickTime = now
                end
            end
            
            previousEnergy = currentEnergy
        end
    end
end)

--[[
    Function: TimeUntilTick
    Returns: Number (Seconds remaining until next energy tick)
]]
function jungle.TimeUntilTick()
    local now = GetTime()
    local nextTick = lastTickTime + TICK_INTERVAL
    local remaining = nextTick - now
    
    -- Safety: If we drifted past 0 without an event (lag), clamp it
    if remaining < 0 then
        -- Assume we just missed the event or are lagging; wrap around
        -- Modulo arithmetic for precision handling
        local drift = math.abs(remaining)
        local cycles = math.floor(drift / TICK_INTERVAL) + 1
        return (nextTick + (cycles * TICK_INTERVAL)) - now
    end
    
    return remaining
end