local Jungle, jungle = ...

-- TBC melee timing. Use GetTime, as do cast timestamps and the routines.
-- CLEU timestamps identify events; they are not mixed into the local clock.
-- Completed Slam resets even if avoided; a failed cast does not complete.
-- TBC reset model, pending live Anniversary verification (see docs/SWING_TIMER.md).
-- References: wowsims/tbc sim/warrior/slam.go; LibClassicSwingTimerAPI BCC path.
local SwingTimer = {}
jungle.SwingTimer = SwingTimer
local mh, oh = {}, {}
local swingCallbacks, resetCallbacks, slamCallbacks = {}, {}, {}
local slamCast, lastSlamCompletion
local extraAttacks, extraAttackUntil = 0, 0
local replacementName, replacementAt, replacementStamp, replacementTargets
local lastForm
local STALE_GRACE, EXTRA_ATTACK_WINDOW = 0.25, 0.25

local slamSpells, replacementSpells = {}, {}
local function AddSpells(lookup, name, ids)
    lookup[name] = name
    for _, id in ipairs(ids) do
        lookup[id] = name
        local localized = GetSpellInfo(id)
        if localized then lookup[localized] = name end
    end
end
AddSpells(slamSpells, "Slam", {1464, 8820, 11604, 11605, 25241, 25242})
AddSpells(replacementSpells, "Heroic Strike", {78, 284, 285, 1608, 11564, 11565, 11566, 25286, 29707, 30324})
AddSpells(replacementSpells, "Cleave", {845, 7369, 11608, 11609, 20569, 25231})
AddSpells(replacementSpells, "Maul", {6807, 6808, 6809, 8972, 9745, 9880, 9881, 26996})
AddSpells(replacementSpells, "Raptor Strike", {2973, 14260, 14261, 14262, 14263, 14264, 14265, 14266, 27014})

local function ValidSpeed(speed)
    return type(speed) == "number" and speed > 0 and speed < math.huge
end

local function ClearHand(hand)
    hand.speed, hand.expiresAt, hand.lastSwingAt, hand.targetGUID = nil, nil, nil, nil
end

local function Invalidate(reason)
    ClearHand(mh)
    ClearHand(oh)
    slamCast, lastSlamCompletion = nil, nil
    extraAttacks, extraAttackUntil = 0, 0
    replacementName, replacementAt, replacementStamp, replacementTargets = nil, nil, nil, nil
    for i = 1, #resetCallbacks do resetCallbacks[i](reason) end
end

local function Rescale(hand, speed, now)
    if not ValidSpeed(speed) then
        ClearHand(hand)
        return
    end
    if hand.expiresAt and ValidSpeed(hand.speed) and hand.speed ~= speed then
        -- Preserve remaining progress through consecutive haste gains/losses.
        -- Never resurrect an overdue swing when a haste buff expires.
        if hand.expiresAt > now then
            hand.expiresAt = now + (hand.expiresAt - now) * speed / hand.speed
        end
    end
    hand.speed = speed
end

local function SyncSpeeds(now)
    local mainSpeed, offSpeed = UnitAttackSpeed("player")
    Rescale(mh, mainSpeed, now)
    Rescale(oh, offSpeed, now)
end

local function StartCycle(hand, now)
    hand.expiresAt = ValidSpeed(hand.speed) and (now + hand.speed) or nil
end

local function ConfirmSwing(hand, now, targetGUID, attackName, result)
    if slamCast and now >= slamCast.endsAt then slamCast = nil end
    SyncSpeeds(now)
    StartCycle(hand, now)
    hand.lastSwingAt, hand.targetGUID = now, targetGUID
    if hand == mh then
        for i = 1, #swingCallbacks do
            swingCallbacks[i](now, attackName, result, targetGUID)
        end
    end
end

function SwingTimer:RegisterMainhandSwingCallback(callback)
    swingCallbacks[#swingCallbacks + 1] = callback
end
function SwingTimer:RegisterResetCallback(callback)
    resetCallbacks[#resetCallbacks + 1] = callback
end
function SwingTimer:RegisterSlamCompletionCallback(callback)
    slamCallbacks[#slamCallbacks + 1] = callback
end

local function ReadSlamCast(now, castGUID, spellID)
    local name, _, _, _, endMS = UnitCastingInfo("player")
    if name and slamSpells[name] and endMS then
        slamCast = { guid = castGUID or (slamCast and slamCast.guid), endsAt = endMS / 1000 }
    elseif not slamCast then
        local _, _, _, castMS = GetSpellInfo(spellID or "Slam")
        -- Talent-modified, not spell-haste-scaled in TBC.
        slamCast = { guid = castGUID, endsAt = now + (castMS or 1500) / 1000 }
    elseif castGUID then
        slamCast.guid = castGUID
    end
end

local function FinishSlam(now, castGUID, timestamp, evidence)
    castGUID = castGUID or (slamCast and slamCast.guid)
    -- Unit success, combat-log success, and damage/miss describe one completion.
    -- GUID/stamp identity also catches delayed duplicate notifications. Across
    -- channels with no shared identity, use a short grace below Slam's TBC GCD.
    local last = lastSlamCompletion
    if last and ((castGUID and castGUID == last.guid)
        or (timestamp and last.stamps[timestamp])
        or (now - last.at < 0.5 and not (castGUID and last.guid and castGUID ~= last.guid))) then
        last.guid = last.guid or castGUID
        if timestamp then last.stamps[timestamp] = true end
        return
    end
    lastSlamCompletion = {at = now, guid = castGUID, stamps = {}}
    if timestamp then lastSlamCompletion.stamps[timestamp] = true end
    slamCast = nil
    SyncSpeeds(now)
    StartCycle(mh, now)
    StartCycle(oh, now)
    -- A spell reset is not a white hit and must not reopen a Slam window.
    for i = 1, #slamCallbacks do slamCallbacks[i](now, evidence) end
end

local function IsReliable(hand, now)
    return hand.expiresAt ~= nil and ValidSpeed(hand.speed)
        and now <= hand.expiresAt + STALE_GRACE and not slamCast
end

local function ExpireUnfinishedCast(now)
    if slamCast and now > slamCast.endsAt + 0.5 then
        Invalidate("missing_cast_completion")
    end
end

local function StopSlam(now)
    slamCast = nil
    SyncSpeeds(now)
    -- A failed/cancelled Slam does not complete the TBC swing reset. Preserve
    -- an unexpired cycle; if a swing was due during the cast, its next deadline
    -- is uncertain until the combat log confirms an attack.
    if mh.expiresAt and mh.expiresAt <= now then mh.expiresAt = nil end
    if oh.expiresAt and oh.expiresAt <= now then oh.expiresAt = nil end
end

local function Remaining(hand)
    local now = GetTime()
    ExpireUnfinishedCast(now)
    SyncSpeeds(now)
    if slamCast and ValidSpeed(hand.speed) then
        return math.max(0, slamCast.endsAt - now) + hand.speed
    end
    return hand.expiresAt and math.max(0, hand.expiresAt - now) or 0
end

function SwingTimer:GetTimeRemaining() return Remaining(mh) end
function SwingTimer:GetMainhandTimeRemaining() return Remaining(mh) end
function SwingTimer:GetSlamTimeRemaining() return Remaining(mh) end
function SwingTimer:GetOffhandTimeRemaining() return Remaining(oh) end
function SwingTimer:GetMainhandTimerSource() return "internal" end
function SwingTimer:GetSlamTimerSource() return "internal" end
function SwingTimer:GetTimeSinceLastSwing()
    return mh.lastSwingAt and math.max(0, GetTime() - mh.lastSwingAt) or 999
end
function SwingTimer:GetOffhandTimeSinceLastSwing()
    return oh.lastSwingAt and math.max(0, GetTime() - oh.lastSwingAt) or 999
end
function SwingTimer:IsMainhandTimingReliable()
    local now = GetTime()
    ExpireUnfinishedCast(now)
    SyncSpeeds(now)
    return IsReliable(mh, now)
end
function SwingTimer:IsTimerStale()
    local now = GetTime()
    ExpireUnfinishedCast(now)
    SyncSpeeds(now)
    return not IsReliable(mh, now) or (ValidSpeed(oh.speed) and not IsReliable(oh, now))
end
function SwingTimer:HasConfirmedMainhandSwing() return mh.lastSwingAt ~= nil end
function SwingTimer:GetLastConfirmedMainhandSwingTime() return mh.lastSwingAt end
function SwingTimer:GetLastConfirmedMainhandSwingTargetGUID() return mh.targetGUID end

-- Action requests are not proof of a swing. Wait for game events rather than
-- creating a fake mainhand hit when the routine recommends /startattack.
function SwingTimer:OnAttackStarted() Invalidate("attack_request") end
function SwingTimer:OnAttackStopped() Invalidate("attack_request") end
function SwingTimer:ResetMainhand()
    ClearHand(mh)
    local now = GetTime()
    SyncSpeeds(now)
    StartCycle(mh, now)
    for i = 1, #resetCallbacks do resetCallbacks[i]("mainhand_reset") end
end
function SwingTimer:ResetOffhand()
    ClearHand(oh)
    local now = GetTime()
    SyncSpeeds(now)
    StartCycle(oh, now)
end

local function ConsumeExtraAttack(now)
    if now > extraAttackUntil then extraAttacks = 0 end
    if extraAttacks > 0 then
        extraAttacks = extraAttacks - 1
        return true
    end
    return false
end

local function IsDuplicateReplacement(name, timestamp, now, targetGUID)
    -- One Cleave creates several damage/miss records, but only one weapon cycle.
    if name == replacementName and ((timestamp ~= nil and timestamp == replacementStamp)
        or (now - replacementAt <= 0.05 and not replacementTargets[targetGUID or false])) then
        replacementTargets[targetGUID or false] = true
        return true
    end
    replacementName, replacementAt, replacementStamp = name, now, timestamp
    replacementTargets = {[targetGUID or false] = true}
    return false
end

local function ApplyParryHaste(now)
    SyncSpeeds(now)
    if not IsReliable(mh, now) then return end
    local remaining, minimum = mh.expiresAt - now, mh.speed * 0.2
    if remaining > minimum then
        mh.expiresAt = now + math.max(minimum, remaining - mh.speed * 0.4)
    end
end

local swingFrame = CreateFrame("Frame")
for _, event in ipairs({
    "COMBAT_LOG_EVENT_UNFILTERED", "UNIT_ATTACK_SPEED", "PLAYER_ENTERING_WORLD",
    "PLAYER_EQUIPMENT_CHANGED", "PLAYER_DEAD", "PLAYER_LEAVE_COMBAT",
    "UPDATE_SHAPESHIFT_FORM", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_STOP",
}) do swingFrame:RegisterEvent(event) end

swingFrame:SetScript("OnEvent", function(_, event, unit, castGUID, spellID)
    local now = GetTime()
    if event == "UNIT_ATTACK_SPEED" then
        if unit == "player" then SyncSpeeds(now) end
    elseif event == "UPDATE_SHAPESHIFT_FORM" then
        -- Warrior stance changes do not reset swings. Only a Druid form change
        -- changes the underlying melee weapon, not every form UI notification.
        local _, class = UnitClass("player")
        if class == "DRUID" then
            local form = GetShapeshiftForm()
            if form ~= lastForm then Invalidate(event) end
            lastForm = form
        end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_DEAD"
        or event == "PLAYER_LEAVE_COMBAT" then
        -- LEAVE_COMBAT means autoattack stopped, unlike PLAYER_REGEN_ENABLED.
        Invalidate(event)
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        if unit == 16 or unit == 17 then Invalidate(event) end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, kind, _, sourceGUID, _, _, _, destGUID, _, _, _, arg12,
            arg13, _, arg15, _, _, _, _, _, arg21 = CombatLogGetCurrentEventInfo()
        local playerGUID = UnitGUID("player")
        if not playerGUID then return end
        if sourceGUID == playerGUID then
            if kind == "SPELL_EXTRA_ATTACKS" then
                if now > extraAttackUntil then extraAttacks = 0 end
                extraAttacks = extraAttacks + (tonumber(arg15) or 1)
                extraAttackUntil = now + EXTRA_ATTACK_WINDOW
            elseif kind == "SWING_DAMAGE" or kind == "SWING_MISSED" then
                local offhand = (kind == "SWING_DAMAGE" and arg21) or (kind == "SWING_MISSED" and arg13)
                if not offhand and ConsumeExtraAttack(now) then return end
                ConfirmSwing(offhand and oh or mh, now, destGUID, "Auto Attack",
                    kind == "SWING_DAMAGE" and "hit" or string.lower(tostring(arg12)))
            elseif kind == "SPELL_DAMAGE" or kind == "SPELL_MISSED" then
                -- An avoided attack still proves that the Slam cast completed.
                -- This recovers a missing success event without requiring damage.
                if slamSpells[arg12] or slamSpells[arg13] then
                    FinishSlam(now, nil, timestamp, kind)
                    return
                end
                local name = replacementSpells[arg12] or replacementSpells[arg13]
                if name and not IsDuplicateReplacement(name, timestamp, now, destGUID)
                    and not ConsumeExtraAttack(now) then
                    ConfirmSwing(mh, now, destGUID, name,
                        kind == "SPELL_DAMAGE" and "hit" or string.lower(tostring(arg15)))
                end
            elseif kind == "SPELL_CAST_SUCCESS" and (slamSpells[arg12] or slamSpells[arg13]) then
                FinishSlam(now, nil, timestamp, kind)
            elseif kind == "SPELL_CAST_START" and (slamSpells[arg12] or slamSpells[arg13]) then
                ReadSlamCast(now, nil, arg12)
            end
        elseif destGUID == playerGUID and ((kind == "SWING_MISSED" and arg12 == "PARRY")
            or (kind == "SPELL_MISSED" and arg15 == "PARRY")) then
            ApplyParryHaste(now)
        end
    elseif unit == "player" and slamSpells[spellID] then
        if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_DELAYED" then
            ReadSlamCast(now, castGUID, spellID)
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            FinishSlam(now, castGUID, nil, event)
        elseif slamCast and (not slamCast.guid or not castGUID or slamCast.guid == castGUID) then
            -- STOP may precede SUCCESS; SUCCESS establishes the new cycle.
            StopSlam(now)
        end
    end
end)

jungle.RaidTrace:WatchEventFrame(swingFrame, "swing")
