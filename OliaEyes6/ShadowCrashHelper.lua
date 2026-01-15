local Jungle, jungle = ...

-- Initialize variable to store the target name for "Shadow Crash"
local shadowCrashTarget = nil

-- Function to get the cooldown remaining for a spell
local function GetCooldownRemaining(spellName)
    local start, duration = GetSpellCooldown(spellName)
    if start == 0 and duration == 0 then
        return 0
    else
        return (start + duration - GetTime())
    end
end

-- Function to handle unit spellcast events
local function OnUnitSpellcastSent(self, event, unit, targetName, castGUID, spellID)
    -- Ensure the unit is the player and the spell is "Shadow Crash"
    if unit == "player" and spellID == 457042 then  -- Shadow Crash spell ID
        -- Update the variable with the target name when "Shadow Crash" is cast
        shadowCrashTarget = targetName
    end
end

-- Function to clear shadowCrashTarget if cooldown is less than 18 seconds
local function CheckShadowCrashCooldown()
    if IsSpellKnown(457042) and GetCooldownRemaining("Shadow Crash") < 17 then
        shadowCrashTarget = nil
    end
end

-- Frame to handle events
local frame = CreateFrame("Frame")
frame:RegisterEvent("UNIT_SPELLCAST_SENT")
frame:SetScript("OnEvent", OnUnitSpellcastSent)

-- Set up a repeating timer to check Shadow Crash cooldown every second
C_Timer.NewTicker(1, CheckShadowCrashCooldown)

-- Expose the shadowCrashTarget variable for use in other parts of the addon
jungle.shadowCrashTarget = function() return shadowCrashTarget end
