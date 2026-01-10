local Jungle, jungle = ...

-- Initialize a table to store the last cast times for all spells cast by the player
local lastSpellCastTimes = {}

-- Function to get the current time in seconds
local function GetCurrentTime()
    return GetTime()
end

-- Function to handle combat log events
local function OnCombatLogEvent(self, event)
    -- Get the necessary details from the combat log
    local _, eventType, _, sourceGUID, _, _, _, _, _, _, _, _, spellName = CombatLogGetCurrentEventInfo()

    -- Check if the event is a SPELL_CAST_SUCCESS and the source is the player
    if eventType == "SPELL_CAST_SUCCESS" and sourceGUID == UnitGUID("player") then
        -- Record the time when any spell is cast by the player
        lastSpellCastTimes[spellName] = GetCurrentTime()
    end
end

-- Function to check if a specific spell was cast within the time limit
function jungle.CheckIfSpellCastedRecently(timeLimit, spellName)
    local lastCastTime = lastSpellCastTimes[spellName]
    
    -- If the spell was cast and the time since the last cast is within the time limit
    if lastCastTime and (GetCurrentTime() - lastCastTime < timeLimit) then
        return true
    end
    
    return false
end

-- Frame to handle events
local frame = CreateFrame("Frame")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:SetScript("OnEvent", OnCombatLogEvent)

-- Expose the CheckIfSpellCastedRecently function to the addon table
jungle.CheckIfSpellCastedRecently = jungle.CheckIfSpellCastedRecently
