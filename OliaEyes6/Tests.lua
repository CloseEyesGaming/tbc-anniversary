local Jungle, jungle = ...

-- =============================================================
--  TESTING SUITE
-- =============================================================

-- [tst0] Local Developer Scratchpad
-- [tst0] Local Developer Scratchpad
-- Purpose: Diagnostic check for non-targetable Soft Interact objects (Fishing Bobber)
function tst0()
	print(jungle.IsFishing())
end

-- [tst] Core Module Integrity Check
function tst()
    print("|cFF00FF00- OliaEyes Refactor Check (Basic)|r")
    local pass = true
    
    -- 1. Existence Check
    if not jungle.ReadyCastSpell then print("FAIL ReadyCastSpell missing"); pass = false end
    if not jungle.Debuff then print("FAIL Debuff missing"); pass = false end
    if not jungle.LifePercent then print("FAIL LifePercent missing"); pass = false end
    if not jungle.unitCache then print("FAIL unitCache missing"); pass = false end
    if not jungle.updateUnitsData then print("FAIL updateUnitsData missing"); pass = false end
    
    -- 2. Functionality Check (GCD)
    local cdCheck = jungle.SpellOnCD("Swiftmend") 
    if type(cdCheck) ~= "boolean" then 
        print("FAIL SpellOnCD returned non-boolean ", type(cdCheck)) 
        pass = false 
    end
    
    if pass then
        print("|cFF00FF00PASS Core Modules Loaded & Linked Successfully|r")
    else
        print("|cFFFF0000FAIL Verification Failed - Check Logs|r")
    end
end

-- [tst2] Deep Integration Test (DruidStrings)
function tst2()
    print("|cFF00FFFF - OliaEyes Druid Deep Test (Regression) -|r")
    
    local _, playerClass = UnitClass("player")
    if playerClass ~= "DRUID" then
        print("|cFFFF0000[STOP] Player is not a Druid (Found " .. playerClass .. ")|r")
        return
    end

    -- 1. Spell Cooldown
    local spell1 = "Swiftmend"
    local onCD = jungle.SpellOnCD(spell1)
    local readyTime = jungle.TimeToReady(spell1)
    local onCDStr = onCD and "|cFFFF0000TRUE|r" or "|cFF00FF00FALSE|r"
    print(string.format("[Test 1] Spell '%s' OnCD %s  TimeToReady %.2fs", spell1, onCDStr, readyTime))

    -- 2. Buff Scanning
    local buff1 = "Rejuvenation"
    local hasRejuv = jungle.Buff(buff1, "player")
    if hasRejuv then
        local _, _, _, _, _, expirationTime = AuraUtil.FindAuraByName(buff1, "player", "HELPFUL")
        local remaining = (expirationTime or 0) - GetTime()
        print(string.format("[Test 2] Buff '%s' |cFF00FF00FOUND|r  Expires in %.1fs", buff1, remaining))
    else
        print(string.format("[Test 2] Buff '%s' |cFFFF0000NOT FOUND|r (Cast it on yourself)", buff1))
    end

    -- 3. Debuff Scanning
    local debuff1 = "Moonfire"
    local targetExists = UnitExists("target")
    if not targetExists then
        print("[Test 3] Debuff Scan |cFF888888SKIPPED (No Target)|r")
    else
        local hasMoonfire = jungle.Debuff(debuff1, "target", nil)
        if hasMoonfire then
            local _, _, _, _, _, expirationTime = AuraUtil.FindAuraByName(debuff1, "target", "HARMFUL")
            local remaining = (expirationTime or 0) - GetTime()
            print(string.format("[Test 3] Debuff '%s' |cFF00FF00FOUND|r  Expires in %.1fs", debuff1, remaining))
        else
            print(string.format("[Test 3] Debuff '%s' |cFFFF0000NOT FOUND|r (Cast on target)", debuff1))
        end
    end

    -- 4. Castability
    local canCastRejuv = jungle.ReadyCastSpell(buff1, "player")
    local canCastStr = canCastRejuv and "|cFF00FF00YES|r" or "|cFFFF0000NO|r"
    print(string.format("[Test 4] Can Cast '%s' %s", buff1, canCastStr))

    print("|cFF00FFFF--- End Test ---|r")
end

-- [tst3] Optimization Verification (Table Recycling)
function tst3()
    print("|cFF00FFFF - OliaEyes Memory Stability Test -|r")
    
    -- 1. Populate Cache
    jungle.updateUnitsData()
    local unit1 = jungle.unitCache['player']
    
    if not unit1 then
        print("|cFFFF0000[FAIL] Player not in cache (Run /reload or target self)|r")
        return
    end
    
    -- Capture Memory Pointer (Lua treats table variables as references/pointers)
    local addr1 = tostring(unit1)
    
    -- 2. Force Update Cycle (Should Trigger Recycling)
    jungle.updateUnitsData()
    local unit2 = jungle.unitCache['player']
    local addr2 = tostring(unit2)
    
    -- 3. Compare Pointers
    print(string.format("Cycle 1 Pointer: %s", addr1))
    print(string.format("Cycle 2 Pointer: %s", addr2))
    
    if addr1 == addr2 then
        print("|cFF00FF00[PASS] Memory Stable - Tables are Recycled|r")
    else
        print("|cFFFF0000[FAIL] Memory Unstable - New Table Allocated (Bottleneck Persists)|r")
    end
end