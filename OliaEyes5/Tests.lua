local Jungle, jungle = ...

-- =============================================================
--  TESTING SUITE
-- =============================================================

-- [tst0] Local Developer Scratchpad (Static Cast Execution)
function tst0()
    print("--- TEST: Static Cast Execution ---")
    local _oldUnitExists = UnitExists
    local _oldUnitIsUnit = UnitIsUnit
    
    UnitExists = function(u) return (u == 'focus' or u == 'target') end
    UnitIsUnit = function(u1, u2) return (u1 == 'focus' and u2 == 'target') end 
    
    local _oldPixelSet = jungle.Pixel.set
    local lastColor = nil
    
    jungle.Pixel.set = function(self)
        lastColor = self.color
        return true
    end

    print("Attempting Cast: Moonfire...")
    jungle.Cast:CastSpell("Moonfire", "target", 1)
    
    if lastColor then
        print("PASS: Cast triggered pixel change.")
        print("Color Data: ", lastColor[1], lastColor[2], lastColor[3])
    else
        print("FAIL: No pixel change detected.")
    end
    
    UnitExists = _oldUnitExists
    UnitIsUnit = _oldUnitIsUnit
    jungle.Pixel.set = _oldPixelSet
end

-- [tst] Core Module Integrity Check
function tst()
    print("|cFF00FF00- OliaEyes Refactor Check (Basic)|r")
    local pass = true
    
    -- 1. Existence Check
    if not jungle.ReadyCastSpell then print("FAIL ReadyCastSpell missing"); pass = false end
    if not jungle.Debuff then print("FAIL Debuff missing"); pass = false end
    if not jungle.LifePercent then print("FAIL LifePercent missing"); pass = false end
    
    -- 2. NEW: Engine Module Check (Phase 2 Refactor)
    if not jungle.Engine then 
        print("FAIL Engine Module missing"); pass = false 
    else
        -- Force init if not already done
        if not jungle.Engine.initialized then jungle.Engine:Initialize() end
        if not jungle.Engine.initialized then
            print("FAIL Engine failed to Initialize"); pass = false 
        end
    end

    -- 3. Functionality Check (GCD)
    local cdCheck = jungle.SpellOnCD("Swiftmend") 
    if type(cdCheck) ~= "boolean" then 
        print("FAIL SpellOnCD returned non-boolean ", type(cdCheck)) 
        pass = false 
    end
    
    if pass then
        print("|cFF00FF00PASS Core Modules, Engine & Logic Linked|r")
    else
        print("|cFFFF0000FAIL Verification Failed - Check Logs|r")
    end
end

-- [tst2] Deep Integration Test (Druid + Refactors)
function tst2()
    print("|cFF00FFFF - OliaEyes Druid Deep Test (Full Suite) -|r")
    
    local _, playerClass = UnitClass("player")
    if playerClass ~= "DRUID" then
        print("|cFFFF0000[STOP] Player is not a Druid|r")
        return
    end

    -- [Test 1] Spell Cooldown (Original)
    local spell1 = "Swiftmend"
    local onCD = jungle.SpellOnCD(spell1)
    local readyTime = jungle.TimeToReady(spell1)
    local onCDStr = onCD and "|cFFFF0000TRUE|r" or "|cFF00FF00FALSE|r"
    print(string.format("[Test 1] Spell '%s' OnCD %s  TimeToReady %.2fs", spell1, onCDStr, readyTime))

    -- [Test 2] Buff Scanning (Original)
    local buff1 = "Rejuvenation"
    local hasRejuv = jungle.Buff(buff1, "player")
    if hasRejuv then
        local _, _, _, _, _, expirationTime = AuraUtil.FindAuraByName(buff1, "player", "HELPFUL")
        local remaining = (expirationTime or 0) - GetTime()
        print(string.format("[Test 2] Buff '%s' |cFF00FF00FOUND|r  Expires in %.1fs", buff1, remaining))
    else
        print(string.format("[Test 2] Buff '%s' |cFFFF0000NOT FOUND|r (Cast it on yourself)", buff1))
    end

    -- [Test 3] Debuff Scanning (Original)
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

    -- [Test 4] Castability (Original)
    local canCastRejuv = jungle.ReadyCastSpell(buff1, "player")
    local canCastStr = canCastRejuv and "|cFF00FF00YES|r" or "|cFFFF0000NO|r"
    print(string.format("[Test 4] Can Cast '%s' %s", buff1, canCastStr))

    -- =========================================================
    -- NEW REFACTOR TESTS (Sections 5-8)
    -- =========================================================

    -- [Test 5] Engine & Threading (Phase 2 Fix)
    if jungle.Engine then
        jungle.Engine:SetThread(2) -- Switch to Healing
        if jungle.Engine.activeThread == 2 then
            print("[Test 5] Engine Thread Switching: |cFF00FF00PASS|r")
        else
            print("[Test 5] Engine Thread Switching: |cFFFF0000FAIL|r (Value: "..tostring(jungle.Engine.activeThread)..")")
        end
    else
        print("[Test 5] Engine: |cFFFF0000MISSING|r")
    end

    -- [Test 6] UnitsData Crash Test (Phase 3 Fix)
    -- specifically tests GetTalentSpec() which crashed on TBC strings
    local status, err = pcall(function() return jungle.isUnitAvailable('player') end)
    if status then
        print("[Test 6] Talent API Safety (TBC Fix): |cFF00FF00PASS|r (No Crash)")
    else
        print("[Test 6] Talent API Safety: |cFFFF0000CRASHED|r - " .. tostring(err))
    end

    -- [Test 7] Static Cast Library (Phase 3 Fix)
    -- Ensure Cast is a table, not a Class constructor
    if type(jungle.Cast) == "table" and jungle.Cast.CastSpell and not jungle.Cast.new then
        print("[Test 7] Cast Library (Zero-Alloc): |cFF00FF00PASS|r")
    elseif jungle.Cast.new then
        print("[Test 7] Cast Library: |cFFFF0000FAIL|r (Still has :new method)")
    else
        print("[Test 7] Cast Library: |cFFFF0000FAIL|r (Structure invalid)")
    end

    -- [Test 8] Pixel Class Structure (Phase 4 Fix)
    -- Ensure Pixel IS a Class with __index
    if jungle.Pixel and jungle.Pixel.__index == jungle.Pixel then
        print("[Test 8] Pixel Class (Metatables): |cFF00FF00PASS|r")
    else
        print("[Test 8] Pixel Class: |cFFFF0000FAIL|r (Missing __index)")
    end

    print("|cFF00FFFF--- End Test Suite ---|r")
end