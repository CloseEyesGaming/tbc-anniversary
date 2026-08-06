local Jungle, jungle = ...

local SwingTimer = {}
jungle.SwingTimer = SwingTimer

local lastSwingTime = 0
local lastOffhandSwingTime = 0
local isTimerStale = false

-- Super Swing Timer keeps its addon namespace private, but its live main-hand
-- status bar is a named global frame.  Read that frame defensively for Arms
-- Slam planning while leaving this tracker running as an always-hot fallback.
local SUPER_SWING_TIMER_ADDON = "SuperSwingTimer"
local SUPER_SWING_TIMER_MH_BAR = "SuperSwingTimerMHBar"
local SUPER_SWING_TIMER_STALE_AFTER = 0.5
local superSwingObservation = {
    frame = nil,
    value = nil,
    progressAt = 0,
}
local slamTimerSource = "internal"

local function IsSuperSwingTimerLoaded()
    local addonAPI = rawget(_G, "C_AddOns")
    local isLoaded = addonAPI and addonAPI.IsAddOnLoaded
    if type(isLoaded) == "function" then
        local ok, loaded = pcall(isLoaded, SUPER_SWING_TIMER_ADDON)
        return ok and loaded == true
    end

    isLoaded = rawget(_G, "IsAddOnLoaded")
    if type(isLoaded) == "function" then
        local ok, loaded = pcall(isLoaded, SUPER_SWING_TIMER_ADDON)
        return ok and loaded == true
    end

    -- Older clients without either query can still prove availability by the
    -- named frame that Super Swing Timer creates during initialization.
    return rawget(_G, SUPER_SWING_TIMER_MH_BAR) ~= nil
end

local function ResetSuperSwingObservation(frame)
    superSwingObservation.frame = frame
    superSwingObservation.value = nil
    superSwingObservation.progressAt = 0
end

local function ReadSuperSwingTimerMainhand()
    if not IsSuperSwingTimerLoaded() then
        ResetSuperSwingObservation(nil)
        return nil
    end

    local frame = rawget(_G, SUPER_SWING_TIMER_MH_BAR)
    local frameType = type(frame)
    if frameType ~= "table" and frameType ~= "userdata" then
        ResetSuperSwingObservation(nil)
        return nil
    end

    local okMethods, getMinMaxValues, getValue = pcall(function()
        return frame.GetMinMaxValues, frame.GetValue
    end)
    if not okMethods
        or type(getMinMaxValues) ~= "function"
        or type(getValue) ~= "function" then
        ResetSuperSwingObservation(nil)
        return nil
    end

    if superSwingObservation.frame ~= frame then
        ResetSuperSwingObservation(frame)
    end

    local okRange, minimum, maximum = pcall(getMinMaxValues, frame)
    local okValue, value = pcall(getValue, frame)
    if not okRange or not okValue
        or type(minimum) ~= "number"
        or type(maximum) ~= "number"
        or type(value) ~= "number" then
        ResetSuperSwingObservation(frame)
        return nil
    end

    local duration = maximum - minimum
    local elapsed = value - minimum
    if duration < 0.2 or duration > 10
        or elapsed < -0.05 or elapsed > duration + 0.05 then
        ResetSuperSwingObservation(frame)
        return nil
    end

    -- An idle SST bar uses the literal "Main Hand" label with a synthetic
    -- 0..1 range.  Active timers use a numeric countdown label.  Checking the
    -- label prevents that idle display from being mistaken for a one-second
    -- swing when SST has not observed a real attack yet.
    local okLabelObject, label = pcall(function()
        return frame.labelText
    end)
    local labelType = type(label)
    if not okLabelObject or (labelType ~= "table" and labelType ~= "userdata") then
        ResetSuperSwingObservation(frame)
        return nil
    end
    local okLabelMethod, getLabelText = pcall(function()
        return label.GetText
    end)
    if not okLabelMethod or type(getLabelText) ~= "function" then
        ResetSuperSwingObservation(frame)
        return nil
    end
    local okLabel, labelText = pcall(getLabelText, label)
    if not okLabel or type(labelText) ~= "string" or tonumber(labelText) == nil then
        ResetSuperSwingObservation(frame)
        return nil
    end

    local weaponSpeed = UnitAttackSpeed("player")
    if type(weaponSpeed) ~= "number" or weaponSpeed <= 0 then
        ResetSuperSwingObservation(frame)
        return nil
    end
    local speedTolerance = math.max(0.15, weaponSpeed * 0.25)
    if math.abs(duration - weaponSpeed) > speedTolerance then
        ResetSuperSwingObservation(frame)
        return nil
    end

    local now = GetTime()
    local previousValue = superSwingObservation.value
    if previousValue == nil or math.abs(value - previousValue) > 0.001 then
        superSwingObservation.value = value
        superSwingObservation.progressAt = now
    elseif elapsed < duration - 0.05
        and UnitCastingInfo("player") ~= "Slam"
        and now - superSwingObservation.progressAt > SUPER_SWING_TIMER_STALE_AFTER then
        -- A live timer must advance.  If SST's update loop is broken or frozen,
        -- stop trusting it until movement resumes and use the internal tracker.
        return nil
    end

    return math.max(0, duration - elapsed), duration
end

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

-- Optional Super Swing Timer integration for Warrior Slam prediction only.
-- Returns the existing internal result whenever SST is missing, disabled,
-- uninitialized, invalid, or no longer advancing.
function SwingTimer:GetSlamTimeRemaining(lastConfirmedSwingTime)
    local remaining = ReadSuperSwingTimerMainhand()
    if remaining ~= nil then
        -- SST updates its state during the combat-log event, but its status bar
        -- is rendered on the following frame.  If our earlier-loaded combat-log
        -- tracker has just confirmed a new swing while SST's bar still shows the
        -- previous cycle at zero, use the freshly reset internal timer for this
        -- one-frame handoff.
        if type(lastConfirmedSwingTime) == "number" and lastConfirmedSwingTime > 0 then
            local sinceConfirmedSwing = GetTime() - lastConfirmedSwingTime
            if sinceConfirmedSwing >= 0 and sinceConfirmedSwing < 0.1 and remaining <= 0.05 then
                slamTimerSource = "internal"
                return self:GetTimeRemaining()
            end
        end

        slamTimerSource = "SuperSwingTimer"
        return remaining
    end

    slamTimerSource = "internal"
    return self:GetTimeRemaining()
end

function SwingTimer:GetSlamTimerSource()
    return slamTimerSource
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
