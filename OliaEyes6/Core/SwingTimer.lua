local Jungle, jungle = ...

local SwingTimer = {}
jungle.SwingTimer = SwingTimer

local lastSwingTime = 0
local lastOffhandSwingTime = 0
local isTimerStale = false

local swingFrame = CreateFrame("Frame")
swingFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
swingFrame:SetScript("OnEvent", function(...)
    local _, eventType, _, sourceGUID, _, _, _, _, _, _, _, spellId, spellName = CombatLogGetCurrentEventInfo()
    if sourceGUID == UnitGUID("player") then
        if eventType == "SWING_DAMAGE" then
            local isOffHand = select(21, CombatLogGetCurrentEventInfo())
            if isOffHand then
                lastOffhandSwingTime = GetTime()
            else
                lastSwingTime = GetTime()
            end
            isTimerStale = false
        elseif eventType == "SWING_MISSED" then
            local isOffHand = select(13, CombatLogGetCurrentEventInfo())
            if isOffHand then
                lastOffhandSwingTime = GetTime()
            else
                lastSwingTime = GetTime()
            end
            isTimerStale = false
        elseif eventType == "SPELL_DAMAGE" or eventType == "SPELL_MISSED" then
            if spellName == "Heroic Strike" or spellName == "Cleave" or spellName == "Slam" then
                lastSwingTime = GetTime()
                isTimerStale = false
            end
        end
    end
end)

function SwingTimer:GetTimeSinceLastSwing()
    return GetTime() - lastSwingTime
end

function SwingTimer:GetTimeRemaining()
    local speed = UnitAttackSpeed("player") or 3.0
    local timeSince = self:GetTimeSinceLastSwing()
    local rem = speed - timeSince
    if rem < 0 then rem = 0 end
    return rem
end

function SwingTimer:GetOffhandTimeSinceLastSwing()
    return GetTime() - lastOffhandSwingTime
end

function SwingTimer:GetOffhandTimeRemaining()
    local _, offSpeed = UnitAttackSpeed("player")
    if not offSpeed then return 0 end
    local timeSince = self:GetOffhandTimeSinceLastSwing()
    local rem = offSpeed - timeSince
    if rem < 0 then rem = 0 end
    return rem
end

-- Called when we emit a StartAttack action (after desync recovery)
-- Resets the mainhand timer since the game resets the mainhand swing timer on /startattack
function SwingTimer:OnAttackStarted()
    lastSwingTime = GetTime()
    isTimerStale = true
end

-- Called when we emit a StopAttack action for desync purposes
function SwingTimer:OnAttackStopped()
    -- Currently a no-op, but available for future tracking
end

-- Returns true if timers were recently reset by OnAttackStarted and no real
-- swing event has confirmed the new timing yet. Callers should avoid making
-- desync decisions based on stale data.
function SwingTimer:IsTimerStale()
    return isTimerStale
end

function SwingTimer:ResetMainhand()
    lastSwingTime = GetTime()
end

function SwingTimer:ResetOffhand()
    lastOffhandSwingTime = GetTime()
end
