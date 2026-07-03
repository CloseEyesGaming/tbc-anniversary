local Jungle, jungle = ...

-- =============================================================
--  TESTING SUITE
-- =============================================================

-- [tst0] Local Developer Scratchpad
-- Purpose: Diagnostic check for Pick Pocket unit info
function tst0()
local inRange = CheckInteractDistance("target", 3)
print(inRange)
    
end

function tst2()
    print("|cFF00FF00[TEST]|r STARTING SIMULATION...")
    
    -- 1. BACKUP REAL API (Safety First)
    local _UnitCastingInfo = UnitCastingInfo
    local _GetTime = GetTime
    local _GetPartyAssignment = GetPartyAssignment
    local _ReadyCastSpell = jungle.ReadyCastSpell
    local _UnitIsDeadOrGhost = UnitIsDeadOrGhost
    
    -- 2. DEFINE MOCKS
    local MOCK_TIME = 1000
    -- Simulates player casting "Regrowth" with 2.0s remaining
    UnitCastingInfo = function(u) 
        if u == 'player' then 
            return "Regrowth", "Regrowth", "", 0, (MOCK_TIME*1000 + 2000), false, nil, 12345 
        end 
    end
    GetTime = function() return MOCK_TIME end
    GetPartyAssignment = function(r, u) return (r == "MAINTANK" and u == "raid1") end
    jungle.ReadyCastSpell = function() return true end
    UnitIsDeadOrGhost = function() return false end

    -- 3. SETUP JUNGLE CACHE (The Scenario)
    -- Scenario: 'raid1' is a Tank. He has 3 Stacks of Lifebloom.
    -- They expire in 0.5 seconds (CRITICAL DANGER).
    jungle.unitCache['raid1'] = {
        isTank = true,
        isInCombat = true,
        currLife = 0.8,
        auras = { 
            buffs = { 
                player = { 
                    ['Lifebloom'] = { count=3, expirationTime=(MOCK_TIME + 0.5) } 
                },
                nonplayer = {}, slowImmunity = {}, unitIgnoreIfYouCaster = {}, unitIgnoreIfYouPhys = {}
            },
            debuffs = { all={}, magic={}, curse={}, poison={}, disease={}, slow={}, root={}, freedom={}, unitIgnore={} }
        }
    }

    -- ------------------------------------------------------------------------
    -- TEST CASE 1: INTERRUPT LOGIC
    -- ------------------------------------------------------------------------
    print("Test 1: Interrupt Tank Emergency (LB < 1.0s)...")
    -- We are casting Regrowth. Tank LB is 0.5s. Interrupt MUST return true.
    local intResult = jungle.Interrupt(1)
    
    if intResult then 
        print("|cFF00FF00[PASS]|r Interrupt Triggered Correctly.") 
    else 
        print("|cFFFF0000[FAIL]|r Interrupt FAILED to trigger.") 
    end

    -- ------------------------------------------------------------------------
    -- TEST CASE 2: PvE OOC ROLLING
    -- ------------------------------------------------------------------------
    print("Test 2: PvE Out-of-Combat Rolling...")
    -- Change State: Not in combat, LB count is 1.
    jungle.unitCache['raid1'].isInCombat = false
    jungle.unitCache['raid1'].auras.buffs.player['Lifebloom'] = { count=1, expirationTime=(MOCK_TIME + 1.0) }
    
    local rot = jungle.pveHealSet('raid1')
    local found = false
    
    -- Look for the specific rule "LB Tank OOC" being true
    for _, v in ipairs(rot) do
        if v[1] == "LB Tank OOC" and v[2] == "Lifebloom" and v[3] == true then 
            found = true 
            break 
        end
    end

    if found then 
        print("|cFF00FF00[PASS]|r OOC Roll Logic Selected.") 
    else 
        print("|cFFFF0000[FAIL]|r OOC Roll Logic NOT selected.") 
    end

    -- 5. RESTORE REAL API
    UnitCastingInfo = _UnitCastingInfo
    GetTime = _GetTime
    GetPartyAssignment = _GetPartyAssignment
    jungle.ReadyCastSpell = _ReadyCastSpell
    UnitIsDeadOrGhost = _UnitIsDeadOrGhost
    print("|cFF00FF00[TEST]|r SIMULATION COMPLETE.")
end

-- =============================================================
--  COMPLEX SWING MISS LOGGER FOR WARRIOR HS/CLEAVE ROTATIONS
-- =============================================================

JungleMissLog = JungleMissLog or {}
jungle.CastHistory = jungle.CastHistory or {}
jungle.DesyncHistory = jungle.DesyncHistory or {}
jungle.DesyncCount = jungle.DesyncCount or 0

-- 1. Hook jungle.Cast:CastSpell to track commands sent by the bot
local origCastSpell = jungle.Cast.CastSpell
if origCastSpell then
    jungle.Cast.CastSpell = function(self, spell, target, pix)
        table.insert(jungle.CastHistory, 1, {
            spell = spell,
            target = target,
            time = GetTime()
        })
        if #jungle.CastHistory > 10 then
            table.remove(jungle.CastHistory)
        end

        if spell == "Desync" or (spell == "Stopattack" and jungle.isSyncedDesyncTrigger) then
            jungle.desyncCastSinceLastSwing = true
            jungle.isSyncedDesyncTrigger = false
            jungle.DesyncHistory = jungle.DesyncHistory or {}
            jungle.DesyncCount = (jungle.DesyncCount or 0) + 1
            
            local beforeMH = jungle.SwingTimer and jungle.SwingTimer:GetTimeRemaining() or 0
            local beforeOH = jungle.SwingTimer and jungle.SwingTimer:GetOffhandTimeRemaining() or 0
            
            local entry = {
                time = GetTime(),
                realTime = date("%H:%M:%S"),
                beforeMH = beforeMH,
                beforeOH = beforeOH,
                afterMH = "pending",
                afterOH = "pending"
            }
            
            table.insert(jungle.DesyncHistory, 1, entry)
            if #jungle.DesyncHistory > 20 then
                table.remove(jungle.DesyncHistory)
            end
            
            C_Timer.After(0.4, function()
                if jungle.SwingTimer and entry then
                    entry.afterMH = jungle.SwingTimer:GetTimeRemaining()
                    entry.afterOH = jungle.SwingTimer:GetOffhandTimeRemaining()
                end
            end)
        end

        return origCastSpell(self, spell, target, pix)
    end
end

-- 2. Create Event Listener for Swing and Spell Misses
local missFrame = CreateFrame("Frame")
missFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
missFrame:SetScript("OnEvent", function()
    local timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()
    
    if sourceGUID ~= UnitGUID("player") then return end
    if eventType ~= "SWING_MISSED" and eventType ~= "SPELL_MISSED" then return end
    
    local missType, isOffHand, spellId, spellName
    if eventType == "SWING_MISSED" then
        missType = select(12, CombatLogGetCurrentEventInfo())
        isOffHand = select(13, CombatLogGetCurrentEventInfo())
        spellName = "Auto Shot/Melee Swing"
    else
        spellId = select(12, CombatLogGetCurrentEventInfo())
        spellName = select(13, CombatLogGetCurrentEventInfo())
        missType = select(15, CombatLogGetCurrentEventInfo())
        isOffHand = select(16, CombatLogGetCurrentEventInfo())
    end

    -- We only care about actual MISS type, not Dodge, Parry, Resist, Block, etc.
    if missType ~= "MISS" then return end
    
    -- Gather swing timers and combat state telemetry
    local mhTimeRem = jungle.SwingTimer:GetTimeRemaining()
    local ohTimeRem = jungle.SwingTimer:GetOffhandTimeRemaining()
    local mhSpeed, ohSpeed = UnitAttackSpeed("player")
    
    -- Check queue state for HS / Cleave
    local hsQueued = C_Spell.IsCurrentSpell("Heroic Strike") or (spellName == "Heroic Strike") or false
    local cleaveQueued = C_Spell.IsCurrentSpell("Cleave") or (spellName == "Cleave") or false
    
    local currentRage = UnitPower("player", 1)
    local currentStance = GetShapeshiftForm()
    
    local targetName = UnitName("target") or "No Target"
    local targetHP = UnitExists("target") and UnitHealth("target") or 0
    local targetHPMax = UnitExists("target") and UnitHealthMax("target") or 0
    local targetHPPercent = targetHPMax > 0 and (targetHP / targetHPMax * 100) or 0
    
    -- Capture last 5 commands from CastHistory
    local historySnippet = {}
    for i = 1, math.min(5, #jungle.CastHistory) do
        local entry = jungle.CastHistory[i]
        table.insert(historySnippet, string.format("[%s on %s at %.2f]", entry.spell or "nil", entry.target or "nil", entry.time))
    end

    -- Find a recent Desync event within the last 3.0s
    local recentDesync = nil
    if jungle.DesyncHistory then
        for i = 1, #jungle.DesyncHistory do
            local d = jungle.DesyncHistory[i]
            if GetTime() - d.time < 3.0 then
                recentDesync = d
                break
            end
        end
    end
    
    local logEntry = {
        time = GetTime(),
        realTime = date("%H:%M:%S"),
        eventType = eventType,
        spellName = spellName,
        spellId = spellId,
        missType = missType,
        hand = isOffHand and "Offhand" or "Mainhand",
        mhTimeRemaining = mhTimeRem,
        ohTimeRemaining = ohTimeRem,
        mhSpeed = mhSpeed,
        ohSpeed = ohSpeed,
        hsQueued = hsQueued,
        cleaveQueued = cleaveQueued,
        rage = currentRage,
        stance = currentStance,
        target = targetName,
        targetHP = targetHPPercent,
        history = historySnippet,
        totalSyncs = jungle.DesyncCount or 0,
        recentSync = recentDesync and {
            time = recentDesync.time,
            realTime = recentDesync.realTime,
            beforeMH = recentDesync.beforeMH,
            beforeOH = recentDesync.beforeOH,
            afterMH = recentDesync.afterMH,
            afterOH = recentDesync.afterOH
        } or nil
    }
    
    table.insert(JungleMissLog, 1, logEntry)
    if #JungleMissLog > 100 then
        table.remove(JungleMissLog)
    end
    
    -- Print color-coded message to chat frame in real-time
    local color = isOffHand and "|cFFFF5555" or "|cFFFFCC00" -- Red for Offhand, Yellow/Gold for Mainhand
    local debugMsg = string.format(
        "|cFF00FFFF[JungleMiss]|r %s%s Missed!|r Type: |cFFFF9900%s|r | Rage: %d | HS Q: %s | MH Rem: %.2fs | OH Rem: %.2fs",
        color,
        isOffHand and "Offhand" or "Mainhand",
        missType,
        currentRage,
        hsQueued and "YES" or "NO",
        mhTimeRem,
        ohTimeRem
    )
    print(debugMsg)
end)

-- 3. Slash command to dump the logs
SLASH_JUNGLEMISSLOG1 = "/misslog"
SlashCmdList["JUNGLEMISSLOG"] = function(msg)
    if not JungleMissLog or #JungleMissLog == 0 then
        print("|cFF00FFFF[JungleMiss]|r No misses logged yet.")
        return
    end
    
    local limit = tonumber(msg) or 5
    print(string.format("|cFF00FFFF[JungleMiss]|r Showing last %d misses:", limit))
    for i = 1, math.min(limit, #JungleMissLog) do
        local entry = JungleMissLog[i]
        local historyStr = table.concat(entry.history, ", ")
        
        local syncStr = ""
        if entry.recentSync then
            local secAgo = entry.time - entry.recentSync.time
            local beforeMH = type(entry.recentSync.beforeMH) == "number" and string.format("%.2fs", entry.recentSync.beforeMH) or tostring(entry.recentSync.beforeMH)
            local beforeOH = type(entry.recentSync.beforeOH) == "number" and string.format("%.2fs", entry.recentSync.beforeOH) or tostring(entry.recentSync.beforeOH)
            local afterMH = type(entry.recentSync.afterMH) == "number" and string.format("%.2fs", entry.recentSync.afterMH) or tostring(entry.recentSync.afterMH)
            local afterOH = type(entry.recentSync.afterOH) == "number" and string.format("%.2fs", entry.recentSync.afterOH) or tostring(entry.recentSync.afterOH)
            
            syncStr = string.format(" | Sync: %s/%s -> %s/%s (%.2fs ago)", beforeMH, beforeOH, afterMH, afterOH, secAgo)
        end
        
        print(string.format(
            "[%d] %s at %s | Type: %s (%s) | Rage: %d | HS/Cleave Q: %s/%s | MH Rem: %.2fs | OH Rem: %.2fs | Target: %s (%.1f%%)%s | Total Syncs: %d | History: %s",
            i,
            entry.hand,
            entry.realTime,
            entry.missType,
            entry.spellName or "Swing",
            entry.rage,
            entry.hsQueued and "Y" or "N",
            entry.cleaveQueued and "Y" or "N",
            entry.mhTimeRemaining,
            entry.ohTimeRemaining,
            entry.target,
            entry.targetHP,
            syncStr,
            entry.totalSyncs,
            historyStr
        ))
    end
end

-- 4. Clear logs on reload / login
local clearFrame = CreateFrame("Frame")
clearFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
clearFrame:SetScript("OnEvent", function()
    JungleMissLog = {}
    jungle.DesyncCount = 0
    jungle.DesyncHistory = {}
    jungle.desyncCastSinceLastSwing = false
    print("|cFF00FFFF[JungleMiss]|r Miss logs cleared on reload.")
end)

-- 5. Slash command to show desync statistics and history in-game
SLASH_JUNGLEDESYNCLOG1 = "/desynclog"
SlashCmdList["JUNGLEDESYNCLOG"] = function(msg)
    if not jungle.DesyncHistory or #jungle.DesyncHistory == 0 then
        print("|cFF00FFFF[JungleDesync]|r No desyncs logged yet.")
        return
    end
    
    local limit = tonumber(msg) or 10
    print(string.format("|cFF00FFFF[JungleDesync]|r Showing last %d desync events (Total: %d):", limit, jungle.DesyncCount or 0))
    for i = 1, math.min(limit, #jungle.DesyncHistory) do
        local entry = jungle.DesyncHistory[i]
        local beforeMH = type(entry.beforeMH) == "number" and string.format("%.2fs", entry.beforeMH) or tostring(entry.beforeMH)
        local beforeOH = type(entry.beforeOH) == "number" and string.format("%.2fs", entry.beforeOH) or tostring(entry.beforeOH)
        local afterMH = type(entry.afterMH) == "number" and string.format("%.2fs", entry.afterMH) or tostring(entry.afterMH)
        local afterOH = type(entry.afterOH) == "number" and string.format("%.2fs", entry.afterOH) or tostring(entry.afterOH)
        
        print(string.format(
            "[%d] %s | Timers Before: MH %s, OH %s | Timers After (0.4s): MH %s, OH %s",
            i,
            entry.realTime,
            beforeMH,
            beforeOH,
            afterMH,
            afterOH
        ))
    end
end


