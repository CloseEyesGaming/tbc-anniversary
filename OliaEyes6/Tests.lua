local Jungle, jungle = ...

-- =============================================================
--  TESTING SUITE
-- =============================================================

-- [tst0] Local Developer Scratchpad
-- [tst0] Local Developer Scratchpad
-- Purpose: Diagnostic check for non-targetable Soft Interact objects (Fishing Bobber)
-- We need a persistent table to store health history
function tst0()
print(jungle.isTargetInLos("Mouseover"))
end

function tst()
    print("--- Running Regression Tests ---")

    -- 1. LoS Module Integrity
    assert(jungle.Los, "CRITICAL: jungle.Los module is missing!")
    
    -- 2. API Name Checks
    assert(type(jungle.isTargetInLos) == "function", "API: isTargetInLos missing")
    assert(type(jungle.UnitIsBehindMe) == "function", "API: UnitIsBehindMe missing")
    assert(type(jungle.ImNotBehindUnit) == "function", "API: ImNotBehindUnit missing")
    
    -- 3. Logic Check (Self-Test)
    local selfBlocked = jungle.isTargetInLos('player')
    assert(selfBlocked == false, "Logic Error: Player is LoS of themselves?")

    print("--- All Tests Passed ---")
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
