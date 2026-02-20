local Jungle, jungle = ...
local unitCache = jungle.unitCache

jungle.TTD_Cache = jungle.TTD_Cache or {}

-- [[ STATE TRACKING ]]
-- Remembers which form we want to return to and for how long the window is open.
local powershiftTarget = 0   -- 1=Bear, 3=Cat
local powershiftEndTime = 0  -- GetTime() timestamp
local tigerFuryLastActive = 0 -- [[ NEW: Internal CD Tracker for Tiger's Fury ]]

--------------------------------------------------------------------------------
-- TBC DRUID CONSOLIDATED ROUTINE
--------------------------------------------------------------------------------

-- THREAD 1 & 2: HEALING (Raid & Tank Logic)
--------------------------------------------------------------------------------

-- Helper: Universal Rank Detection
-- Returns the rank index (1-8) of the highest known version of the spell
local function GetHighestLearnedRank(idTable)
    for i = #idTable, 1, -1 do
        if IsPlayerSpell(idTable[i]) then
            return i
        end
    end
    return 1 -- Default to Rank 1 if none found
end

-- [[ UNIFIED POWERSHIFT FUNCTION ]]
-- Returns TRUE if we should shift, and updates the Memory state.
local function CheckPowershift(formName, formID)
    -- 1. Global Checks (Mana & Cooldown)
    local currentMana = UnitPower("player", 0)
    if currentMana < 600 then return false end -- Safety buffer
    if jungle.SpellOnCD(formName) then return false end

    local shouldShift = false

    -- 2. Escape Logic (Roots/Slows) - Valid for ALL forms
    -- Triggers if we are slowed or rooted to break the effect immediately
    if jungle.isSlowed('player') then
        shouldShift = true
    end

    -- 3. Resource Logic (Form Specific)
    if formID == 3 then -- CAT FORM
        local energy = UnitPower("player", 3)
        local timeToTick = jungle.TimeUntilTick()
        -- Shift if Energy is low AND we won't clip a tick
        if energy <= 11 and timeToTick <= 1 then
            shouldShift = true
        end

    elseif formID == 1 then -- BEAR FORM
        local rage = UnitPower("player", 1)
        -- Shift if Rage is empty (to trigger Furor talent for 10 Rage)
        -- Only if NOT tanking something actively hitting us (safety)
        if rage < 10 and not jungle.isTanking('player') then
            shouldShift = true
        end
    end

    -- 4. Update Memory & Return
    if shouldShift then
        powershiftTarget = formID
        powershiftEndTime = GetTime() + 1.5 -- 1.5s window to return
        return true
    end

    return false
end

-- ============================================================================
-- UNIVERSAL BLOOM WINDOW
-- Scans the Engine's Execution Tracker. Prevents casting long spells 
-- if a marked Lifebloom will expire during the cast time.
-- ============================================================================
function jungle.bloomWindow(spellName)
    -- If no blooms are marked for protection, safe to cast
    if not jungle.protectedBlooms then return true end

    -- Dynamically get the cast time of any spell (e.g., Regrowth is usually 2.0s)
    local _, _, _, castTimeMs = GetSpellInfo(spellName)
    if not castTimeMs then return true end

    local castTime = castTimeMs / 1000
    local safeWindowEnd = GetTime() + castTime + 0.5 -- Cast Time + 0.5s Latency Buffer

    for friend, unitData in pairs(jungle.unitCache) do
        local guid = unitData.guid
        
        -- Is this unit currently marked for protection?
        if guid and jungle.protectedBlooms[guid] then
            local lb = unitData.auras.buffs.player['Lifebloom']
            
            if lb and lb.expirationTime > 0 then
                -- DANGER: The marked bloom will expire while we are casting!
                if lb.expirationTime < safeWindowEnd then
                    return false 
                end
            else
                -- The bloom fell off or bloomed naturally. 
                -- We no longer need to protect it. Clean the registry.
                jungle.protectedBlooms[guid] = nil
            end
        end
    end
    
    return true -- Safe to hardcast!
end

--------------------------------------------------------------------------------
-- THREAD 3: DISPEL (Refactored for ANY Poison/Curse)
--------------------------------------------------------------------------------
function jungle.dispellSet(friend)
    -- FACT: Check if the unit exists in cache before indexing
    local data = unitCache[friend]
    if not data then return {} end

    -- Refactor: Check if the 'poison' or 'curse' sub-tables have ANY entries
    local hasPoison = next(data.auras.debuffs.poison) ~= nil
    local hasCurse = next(data.auras.debuffs.curse) ~= nil

    return {
        -- Priority 1: Abolish Poison (Cast if unit has ANY poison and doesn't have our buff)
        [1] = {'Dispel Poison', "Abolish Poison", 
            (jungle.ReadyCastSpell('Abolish Poison', friend) and hasPoison 
            and not jungle.unitCacheBuff(friend, 'Abolish Poison', '_PLAYER')), 1, 0},
            
        -- Priority 2: Remove Curse (Cast if unit has ANY curse)
        [2] = {'Decurse', "Remove Curse", 
            (jungle.ReadyCastSpell('Remove Curse', friend) and hasCurse), 1, 0},
    }
end

-- THREAD 5: STANCE-AWARE DPS
function jungle.dpsSet(_target)
    if not UnitExists(_target) or not UnitCanAttack("player", _target) then return {} end
    
    local guid = UnitGUID(_target)
    local form = GetShapeshiftForm()
    local isStealthed = IsStealthed()
    local cp = GetComboPoints('player', _target)
    local targetHP = UnitHealth(_target)
    local targetHPPercent = (targetHP / UnitHealthMax(_target)) * 100
    local isElite = (UnitClassification(_target) == "elite" or UnitClassification(_target) == "worldboss")
    
    local shouldAttack = (not isStealthed and not IsCurrentSpell(6603))

    -- 1. TTD PROGNOSIS (For Elites/Bosses)
    local ttd = 999
    if isElite then
        local currentTime = GetTime()
        local data = jungle.TTD_Cache[guid]
        if not data or (targetHP > (data.startHP or 0)) then
            jungle.TTD_Cache[guid] = { startHP = targetHP, startTime = currentTime }
        else
            local totalDamage = data.startHP - targetHP
            local totalTime = currentTime - data.startTime
            if totalTime > 1.5 and totalDamage > 0 then
                ttd = targetHP / (totalDamage / totalTime)
            end
        end
    end

    -- 2. UNIVERSAL RANK DETECTION
    local fbIDs = {22568, 22827, 22828, 22829, 31018, 24248, 27006, 31018}
    local fbRank = GetHighestLearnedRank(fbIDs)
    
    -- 3. FACT-BASED CALCULATION (Ferocious Bite)
    local fbData = {
        [1]={b=10, m=32}, [2]={b=20, m=56}, [3]={b=27, m=82}, [4]={b=35, m=109},
        [5]={b=53, m=146}, [6]={b=62, m=174}, [7]={b=72, m=203}, [8]={b=82, m=233}
    }
    local currentFB = fbData[fbRank] or fbData[1]
    local baseAP, posAP, negAP = UnitAttackPower("player")
    local totalAP = baseAP + posAP + negAP
    
    local predictedDamage = (currentFB.b + (currentFB.m * cp)) + (totalAP * 0.03 * cp)
    local isKillShot = (cp >= 1 and predictedDamage >= (targetHP * 1.2))

    -- 4. SMART RAKE LOGIC
    local livesLongEnough = isElite and (ttd > 9) or (targetHPPercent > 40)
    local shouldRake = (not jungle.Debuff('Rake', _target, '|PLAYER') and cp < 4 and livesLongEnough) and UnitCreatureType(_target)~="Elemental" and UnitCreatureType(_target)~="Totem"

    -- 5. FINISHER LOGIC (Rip vs FB)
    local useRip = (isElite and ttd > 12 and not jungle.Debuff('Rip', _target, '|PLAYER') and cp >= 4)
    local useFB = isKillShot or (cp == 5 and not useRip)

    -- BEGIN STANCE LOGIC
    if form == 3 then -- CAT FORM
		local energy = UnitPower("player", 3)
		local timeToTick = jungle.TimeUntilTick()
        
        -- [[ NEW: UPDATE TIGER'S FURY TRACKER ]]
        -- If we have the buff, we mark the time. This prevents 'LastActive' 
        -- from falling behind. When the buff is lost (powershift), this stops updating, 
        -- and the cooldown logic below takes over.
        if jungle.unitCacheBuff('player', "Tiger's Fury") then
            tigerFuryLastActive = GetTime()
        end

        if isStealthed then
            return { 
                [1]= {'Ravage', 'Ravage', (jungle.ReadyCastSpell('Ravage', _target)), 1, 0},
                [2]= {'Tiger Fury', "Tiger's Fury", (not jungle.unitCacheBuff('player', "Tiger's Fury") and jungle.ReadyCastSpell("Tiger's Fury") and cp <= 1 and timeToTick <= 1), 1, 0},
            }
        else
            -- [[ POWERSHIFT CONDITIONAL ]]
            local limitPowershift = (UnitPower("player", 0) / UnitPowerMax("player", 0) < 0.5) 
                                    and UnitIsUnit("player", _target .. "target") 
                                    and not UnitIsPlayer(_target)

            return {
                [1]= {'Rip', 'Rip', (jungle.ReadyCastSpell('Rip', _target) and useRip), 1, 0},
                [2]= {'Ferocious Bite', 'Ferocious Bite', (jungle.ReadyCastSpell('Ferocious Bite', _target) and useFB), 1, 0},
                [3]= {'FF Feral', 'Faerie Fire (Feral)', (jungle.ReadyCastSpell('Faerie Fire (Feral)', _target) and not jungle.Debuff('Faerie Fire (Feral)', _target) and  not jungle.Debuff('Faerie Fire', _target) and UnitCreatureType(_target)~="Elemental" and UnitCreatureType(_target)~="Totem"), 1, 0},
                
                -- [[ UPDATED TIGER'S FURY ]]
                -- Added: (GetTime() - tigerFuryLastActive > 3)
                -- Prevents casting if we just lost the buff (e.g. from powershifting)
                [4]= {'Tiger Fury', "Tiger's Fury", (
                    not jungle.unitCacheBuff('player', "Tiger's Fury") 
                    and jungle.ReadyCastSpell("Tiger's Fury") 
                    and cp == 0
                    and (GetTime() - tigerFuryLastActive > 3)
					and (timeToTick <= 0.5 and energy >= 60)
                ), 1, 0},
                
                -- [[ POWERSHIFT CALL ]]
                [5]= {'Rake', 'Rake', (jungle.ReadyCastSpell('Rake', _target) and shouldRake and jungle.ImNotBehindUnit(_target)), 1, 0},
                [6]= {'Mangle Cat', 'Mangle (Cat)', (jungle.ReadyCastSpell('Mangle (Cat)', _target) and cp < 5 and (jungle.ImNotBehindUnit(_target) or ( not UnitIsPlayer(_target) and UnitIsUnit('player', _target..'target')))), 1, 0},
                [7]= {'Shred', 'Shred', (jungle.ReadyCastSpell('Shred', _target) and cp < 5 and  not jungle.ImNotBehindUnit(_target)), 1, 0},

                [8]= {'Attack', 'Attack', (shouldAttack), 1, 0},
                [9]= {'Powershift Cat', 'Cat Form', (not limitPowershift and CheckPowershift('Cat Form', 3) and IsSpellInRange("Rake", "target") == 1 and not jungle.unitCacheBuff('player', "Clearcasting")), 1, 0},
            }
        end

    elseif form == 1 then -- BEAR FORM
        local rage = UnitPower("player", 1)
        
        local needsDemo = not jungle.Debuff('Demoralizing Shout', _target)
        local demoContext = (jungle.targetedByCount('player', 'phys') >= 2 or isElite)
        local inDemoRange = CheckInteractDistance(_target, 3) 
        local useDemo = (jungle.ReadyCastSpell('Demoralizing Shout') and needsDemo and demoContext and inDemoRange)

        local maulIDs = {6807, 6808, 6809, 8972, 9745, 9880, 9881, 26996}
        local isMaulQueued = false
        for _, id in ipairs(maulIDs) do
            if IsCurrentSpell(id) then isMaulQueued = true break end
        end

        local canMaul = (not isMaulQueued and rage >= 45 and inDemoRange)

        return {
            [1]= {'Demo Shout', 'Demoralizing Shout', (useDemo), 1, 0},
            [2]= {'Mangle Bear', 'Mangle (Bear)', (jungle.ReadyCastSpell('Mangle (Bear)', _target)), 1, 0},
            
            -- [[ POWERSHIFT CALL ]]
            [3]= {'Powershift Bear', 'Dire Bear Form', (CheckPowershift('Dire Bear Form', 1)), 1, 0},

            [4]= {'Maul', 'Maul', (jungle.ReadyCastSpell('Maul', _target) and canMaul), 1, 0},
            [5]= {'Lacerate', 'Lacerate', (jungle.ReadyCastSpell('Lacerate', _target) and not jungle.Debuff('Lacerate', _target, nil, 5)), 1, 0}, 
            [6]= {'FF Feral', 'Faerie Fire (Feral)', (jungle.ReadyCastSpell('Faerie Fire (Feral)', _target) and not jungle.Debuff('Faerie Fire (Feral)', _target) and  not jungle.Debuff('Faerie Fire', _target) and UnitCreatureType(_target)~="Elemental" and UnitCreatureType(_target)~="Totem"), 1, 0},
            [7]= {'Attack', 'Attack', (shouldAttack), 1, 0},
        }

    else -- CASTER / HUMAN (Default)
        
        -- [[ POWERSHIFT RECOVERY LOGIC ]]
        -- If we are in the powershift window (timer active), we IGNORE caster spells 
        -- and FORCE the return to the target form immediately.
        if GetTime() < powershiftEndTime and powershiftTarget > 0 then
            local returnSpell = (powershiftTarget == 1 and "Dire Bear Form") or (powershiftTarget == 3 and "Cat Form")
            if returnSpell then
                return {
                    [1]= {'Powershift Return', returnSpell, (jungle.ReadyCastSpell(returnSpell)), 1, 0},
                }
            end
        end

        -- Standard Caster Rotation (Only if window expired or manual shift)
        return {
            [1]= {'Wrath DPS', 'Wrath', (jungle.ReadyCastSpell('Wrath', _target) and GetUnitSpeed('player') == 0 and UnitAffectingCombat('player')), 1, 0},
            [2]= {'MF DoT', 'Moonfire', (jungle.ReadyCastSpell('Moonfire', _target) and not jungle.Debuff('Moonfire', _target, '|PLAYER')), 1, 0},
            [3]= {'Attack', 'Attack', (shouldAttack), 1, 0},
        }
    end
end

-- THREAD 6: BUFF LOGIC
--------------------------------------------------------------------------------
function jungle.buffSet(friend)
    local data = unitCache[friend]
    -- Check group status (0 = solo)
    local inGroup = GetNumGroupMembers() > 0
    local isPlayer = UnitIsUnit(friend, "player")
    -- Check for assigned tank role (Main Tank or assigned Tank role in cache)
    local isAssignedTank = data.isTank

    -- Thorns Conditions:
    -- 1. Solo: Buff self
    -- 2. Group: Buff Tanks ONLY (and self)
    local shouldBuffThorns = false
    
    if not inGroup and isPlayer then
        shouldBuffThorns = true
    elseif inGroup and (isAssignedTank or isPlayer) then
        shouldBuffThorns = true
    end

    -- MotW Conditions:
    -- ALWAYS buff if missing. (Removed 'not inGroup' restriction)
    local shouldBuffMotW = true

    return {
        -- 1. Self Buffs (Highest Priority)
        [1]= {'Omen', "Omen of Clarity", (
            isPlayer
            and jungle.ReadyCastSpell('Omen of Clarity', friend)
            -- Rebuff if missing OR < 10 min (600s)
            and not jungle.unitCacheBuff(friend, "Omen of Clarity", nil, 600)
        ), 1, 0},

        [2]= {'MotW Self', "Mark of the Wild", (
            isPlayer -- Only check self here
            and jungle.ReadyCastSpell('Mark of the Wild', friend) 
            -- Rebuff if missing OR < 10 min (600s)
            and not jungle.unitCacheBuff(friend, "Mark of the Wild", nil, 600) 
            and not jungle.unitCacheBuff(friend, "Gift of the Wild")
        ), 1, 0},

        -- 2. Group Buffs (Medium Priority)
        [3]= {'MotW Group', "Mark of the Wild", (
            not isPlayer -- Only check others here (Self handles above)
            and jungle.ReadyCastSpell('Mark of the Wild', friend) 
            -- Rebuff if missing OR < 10 min (600s)
            and not jungle.unitCacheBuff(friend, "Mark of the Wild", nil, 600) 
            and not jungle.unitCacheBuff(friend, "Gift of the Wild")
        ), 1, 0},
        
        -- 3. Thorns (Self & Tank - Low Priority)
        [4]= {'Thorns', "Thorns", (
            shouldBuffThorns 
            and jungle.ReadyCastSpell('Thorns', friend) 
            -- Rebuff if missing OR < 5 min (300s)
            and not jungle.unitCacheBuff(friend, "Thorns", nil, 300)
        ), 1, 0},
    }
end

local Jungle, jungle = ...

-- ----------------------------------------------------------------------------
-- PvE ROTATION: Efficiency & Tank Maintenance
-- ----------------------------------------------------------------------------
local Jungle, jungle = ...

-- ----------------------------------------------------------------------------
-- PvE ROTATION: Efficiency & Tank Maintenance
-- ----------------------------------------------------------------------------
-- [[ REFACTORED PVE HEAL SET ]]
local function pveHealSet(friend)
    local data = jungle.unitCache[friend]
    if not data or UnitIsDeadOrGhost(friend) then return {} end

    -- Definitions
    local isTank = GetPartyAssignment("MAINTANK", friend) or data.isTank
    local isTanking = jungle.isTanking(friend) -- Actually holding aggro
    local hp = data.currLife
	local _, noManaLB = IsUsableSpell("Lifebloom")

    -- Auras
    local hasRejuv     = jungle.unitCacheBuff(friend, 'Rejuvenation', '_PLAYER')
    local hasRegrowth  = jungle.unitCacheBuff(friend, 'Regrowth', '_PLAYER')
    local hasLifebloom = jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER')
    local hasNS        = jungle.unitCacheBuff("player", "Nature's Swiftness", '_PLAYER')

    -- Lifebloom State
    local lbExpireLimit = 1.5
	if jungle.isCasting('player', 2,'Regrowth') then
		lbExpireLimit = 1.8
	end
    local lbCount = 0
    local lbExpiring = nil
    
   if hasLifebloom then
        -- ROBUST STACK COUNTING
        if jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', nil, 3) then lbCount = 3
        elseif jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', nil, 2) then lbCount = 2
        elseif jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', nil, 1) then lbCount = 1
        else
            -- FAIL-SAFE: Buff exists (hasLifebloom=true) but count check failed.
            -- Assume 3 stacks to prevent Rule [5] from spamming.
            lbCount = 3
        end
        
        lbExpiring = not jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', lbExpireLimit)
    end
    return {
        -- 1. Emergency: Nature's Swiftness + HT
		[1] = { "NS Emergency", "Nature's Swiftness",
			(hp <= 0.3 and jungle.ReadyCastSpell('Healing Touch', friend) and not jungle.SpellOnCD("Nature's Swiftness") and not hasNS and data.isInCombat) },
		[2] = { "NS Cast", "Healing Touch",
			(jungle.ReadyCastSpell('Healing Touch', friend) and hasNS) },

		-- 2. Swiftmend Save
		[3] = { "Swiftmend Save", "Swiftmend",
			(not jungle.SpellOnCD("Swiftmend") and hp <= 0.60 and (hasRejuv or hasRegrowth) and data.isInCombat) },

		-- 3. [Logic] "update tank lb before expires"
		[4] = { "LB Tank Refresh", "Lifebloom",
			(not noManaLB and isTank and isTanking and lbExpiring) },

		-- 4. [Logic] "if tank is tanking we should stack 3 lb"
		[5] = { "LB Tank Stack", "Lifebloom",
			(not noManaLB and isTanking and lbCount < 3) },

		-- 5. [Logic] "put regrowth as hot to tanking tank" (Maintenance)
		[6] = { "Regrowth Tank HoT", "Regrowth",
			(jungle.ReadyCastSpell('Regrowth', friend) and hp <= 0.80 and isTanking and not hasRegrowth and GetUnitSpeed('player') == 0) },

		-- 6. [Logic] "stack next lb count if counts less than 3 if life less 0.7"
		[7] = { "LB Crisis Stack", "Lifebloom",
			(not noManaLB and hp < 0.70 and lbCount < 3) },

		-- 7. [Logic] "put regrowth on any/tank if life threshold less than 0.6"
		[8] = { "Regrowth Crisis", "Regrowth",
			(jungle.ReadyCastSpell('Regrowth', friend) and hp < 0.60 and not hasRegrowth and GetUnitSpeed('player') == 0) },

		-- 8. [Logic] "put rejuvenation on tank/any if life threshold less 0.7/0.9"
		[9] = { "Rejuv Fill", "Rejuvenation",
			(jungle.ReadyCastSpell('Rejuvenation', friend) and (hp < 0.85 or (isTank and hp <0.9)) and not hasRejuv) },

		-- 9. [Logic] "update lb before expires if life less than 0.9" (Non-Tank)
		[10] = { "LB Refresh", "Lifebloom",
			(jungle.ReadyCastSpell('Lifebloom', friend) and hp < 0.70 and lbExpiring) },

		-- 10. [Logic] "if health less than full of any of party put lb one stack"
		[11] = { "LB Base", "Lifebloom",
			(jungle.ReadyCastSpell('Lifebloom', friend) and hp < 0.90 and not hasLifebloom) },
		-- 11. [Logic] "put one lifebloom on tank while not combat and update if expires"
		[12] = { "LB Tank OOC", "Lifebloom",
            (jungle.ReadyCastSpell('Lifebloom', friend) and isTank and not data.isInCombat and (not hasLifebloom or lbExpiring)) }
    }
end

-- ----------------------------------------------------------------------------
-- PvP ROTATION: Triage & Burst Protection
-- ----------------------------------------------------------------------------
local function pvpHealSet(friend)
    local data = jungle.unitCache[friend]
    if not data or data.currLife >= 0.99 or UnitIsDeadOrGhost(friend) then return {} end

    -- PvP Logic: Focus on whoever is being attacked NOW
    local attackers = jungle.targetedByCount(friend)
    local isFocused = (attackers >= 1)
    
    local hasLifebloom = jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER')
    local lbFull       = jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', 0, 3)

    return {
        -- 1. NS Emergency
        [1] = { "NS PvP", "Nature's Swiftness",
            (data.currLife <= 0.40 and not jungle.SpellOnCD("Nature's Swiftness") and data.isInCombat)
        },
        [2] = { "HT PvP", "Healing Touch",
            (data.currLife <= 0.40 and jungle.unitCacheBuff("player", "Nature's Swiftness", "_PLAYER"))
        },

        -- 2. Swiftmend (Burst Recovery)
        [3] = { "Swiftmend PvP", "Swiftmend",
            (not jungle.SpellOnCD("Swiftmend") and data.currLife <= 0.60 
            and (jungle.unitCacheBuff(friend, "Rejuvenation") or jungle.unitCacheBuff(friend, "Regrowth")))
        },

        -- 3. Lifebloom STACK (High Priority on Focused Targets)
        [4] = { "LB PvP Stack", "Lifebloom",
            (jungle.ReadyCastSpell('Lifebloom', friend) and isFocused and not lbFull)
        },

        -- 4. Lifebloom REFRESH
        [5] = { "LB PvP Refresh", "Lifebloom",
            (jungle.ReadyCastSpell('Lifebloom', friend) and hasLifebloom 
            and not jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', 1.5))
        },

        -- 5. Rejuvenation (Cover)
        [6] = { "Rejuv PvP", "Rejuvenation",
            (jungle.ReadyCastSpell('Rejuvenation', friend) 
            and not jungle.unitCacheBuff(friend, "Rejuvenation", "_PLAYER"))
        },

        -- 6. Lifebloom Maintain (1 Stack Buffer)
        [7] = { "LB Maintain", "Lifebloom",
            (jungle.ReadyCastSpell('Lifebloom', friend) and not hasLifebloom and data.currLife < 0.95)
        }
    }
end

-- ----------------------------------------------------------------------------
-- DISPATCHER
-- ----------------------------------------------------------------------------
local function universalHealSet(friend)
    local _, instanceType = IsInInstance()
    if instanceType == 'pvp' or instanceType == 'arena' then
        return pvpHealSet(friend)
    else
        return pveHealSet(friend)
    end
end

jungle.pveHealSet = pveHealSet
jungle.pvpHealSet = pvpHealSet
jungle.universalHealSet = universalHealSet

-- ----------------------------------------------------------------------------
-- RAID ROTATION: Ported Logic (Priority & Critical Saving)
-- ----------------------------------------------------------------------------
local function raidHealSet(friend)
    local data = jungle.unitCache[friend]
    if not data or UnitIsDeadOrGhost(friend) then return {} end

    -- STRICT FILTER: Only Non-Tanks
    -- The external logic explicitly excludes the Main Tank from this specific routine.
    if data.isTank then 
        return {} 
    end

    local hp = data.currLife
    local inCombat = data.isInCombat
    local isMoving = (GetUnitSpeed('player') > 0)
    local isPriority = jungle.isPriority(friend) -- Uses Unit.lua logic
    local targetedCount = jungle.targetedByCount(friend)
    
    -- Auras (Player Source)
    local hasRejuv     = jungle.unitCacheBuff(friend, 'Rejuvenation', '_PLAYER')
    local hasRegrowth  = jungle.unitCacheBuff(friend, 'Regrowth', '_PLAYER')
    local hasLifebloom = jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER')
    local hasNS        = jungle.unitCacheBuff("player", "Nature's Swiftness", '_PLAYER')

    -- Auras (Any Source - For Snipe Logic)
    -- unitCacheBuff without _PLAYER flag checks nonplayer list
    local hasRegrowthAny = jungle.unitCacheBuff(friend, 'Regrowth')
    local hasRejuvAny    = jungle.unitCacheBuff(friend, 'Rejuvenation')

    -- Lifebloom State
    local lbExpireLimit = 1.5 -- Matched to external logic
    local lbCount = 0
    local lbExpiring = false
    
    if hasLifebloom then
        if jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', nil, 3) then lbCount = 3
        elseif jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', nil, 2) then lbCount = 2
        elseif jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', nil, 1) then lbCount = 1
        else lbCount = 3 end -- Fail-safe
        
        -- Logic: If NOT safe (>= limit), then it IS expiring.
        lbExpiring = not jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', lbExpireLimit)
    end

    return {
        -- [1] NS Emergency (Critical < 45%)
		[1] = { "NS Emergency", "Nature's Swiftness",
			(hp <= 0.3 and jungle.ReadyCastSpell('Healing Touch', friend) and not jungle.SpellOnCD("Nature's Swiftness") and not hasNS and data.isInCombat) },
		[2] = { "NS Cast", "Healing Touch",
			(jungle.ReadyCastSpell('Healing Touch', friend) and hasNS) },

        -- [2] Swiftmend Save (Critical < 60% + Hot)
        [3] = { "Swiftmend Save", "Swiftmend",
            (inCombat and hp <= 0.60 and not jungle.SpellOnCD("Swiftmend") 
            and (hasRegrowthAny or hasRejuvAny)) 
        },

        -- [3] Update Bloom Critical (< 45% + Expiring)
        [4] = { "LB Refresh Crit", "Lifebloom",
            (inCombat and hp <= 0.45 and hasLifebloom and lbExpiring and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },

        -- [4] Update Bloom Priority (Expiring)
        [5] = { "LB Refresh Prio", "Lifebloom",
            (inCombat and isPriority and hasLifebloom and lbExpiring and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },

        -- [5] Update Bloom Most Targeted (Aggro + Expiring)
        [6] = { "LB Refresh Aggro", "Lifebloom",
            (inCombat and (targetedCount >= 1) and hasLifebloom and lbExpiring and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },

        -- [6] Update Bloom General (< 90% + Expiring)
        [7] = { "LB Refresh Gen", "Lifebloom",
            (hp < 0.90 and hasLifebloom and lbExpiring and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },

        -- [7] Swiftmend Snipe (Non-Player Hots + < 85%)
        -- Logic: Cast if they have a hot, but NOT ours.
        [8] = { "Swiftmend Snipe", "Swiftmend",
            (inCombat and not jungle.SpellOnCD("Swiftmend") and hp <= 0.85 
            and ((hasRegrowthAny and not hasRegrowth) or (hasRejuvAny and not hasRejuv))) 
        },

        -- [8] Swiftmend Recycle (My Hot Expiring + < 85%)
        -- Logic: My hot exists, but is NOT safe for 5 seconds (expires < 5s)
        [9] = { "Swiftmend Recycle", "Swiftmend",
            (inCombat and not jungle.SpellOnCD("Swiftmend") and hp <= 0.85
            and ( (hasRegrowth and not jungle.unitCacheBuff(friend, 'Regrowth', '_PLAYER', 5)) 
               or (hasRejuv and not jungle.unitCacheBuff(friend, 'Rejuvenation', '_PLAYER', 5)) )) 
        },

        -- [9] Regrowth Standing Critical (< 45% + No Hots)
        [10] = { "Regrowth Crit", "Regrowth",
            (not isMoving and inCombat and hp <= 0.45 
            and not hasRejuv and not hasLifebloom and not hasRegrowth
            and jungle.ReadyCastSpell('Regrowth', friend)) 
        },

        -- [10] Regrowth Standing Priority (< 85% + No Hots)
        [11] = { "Regrowth Prio", "Regrowth",
            (not isMoving and inCombat and isPriority and hp <= 0.85
            and not hasRejuv and not hasLifebloom and not hasRegrowth
            and jungle.ReadyCastSpell('Regrowth', friend)) 
        },

        -- [11] Regrowth Standing Aggro (< 85% + No Hots)
        [12] = { "Regrowth Aggro", "Regrowth",
            (not isMoving and inCombat and hp <= 0.85 and (targetedCount >= 1)
            and not hasRejuv and not hasLifebloom and not hasRegrowth
            and jungle.ReadyCastSpell('Regrowth', friend)) 
        },

        -- [12] Stack 3 Critical (< 45% + Has 2 Stacks)
        [13] = { "LB Stack 3 Crit", "Lifebloom",
            (inCombat and isPriority and hp <= 0.45 and lbCount == 2 and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },

        -- [13] Stack 3 Priority (Has 2 Stacks)
        [14] = { "LB Stack 3 Prio", "Lifebloom",
            (inCombat and isPriority and lbCount == 2 and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },

        -- [14] Stack 3 Any (< 75% + Has 2 Stacks)
        [15] = { "LB Stack 3 Any", "Lifebloom",
            (inCombat and isPriority and hp < 0.75 and lbCount == 2 and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },

        -- [15] Stack 2 Critical (< 45% + Has 1 Stack)
        [16] = { "LB Stack 2 Crit", "Lifebloom",
            (inCombat and isPriority and hp <= 0.45 and lbCount == 1 and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },

        -- [16] Stack 2 Priority (Has 1 Stack)
        [17] = { "LB Stack 2 Prio", "Lifebloom",
            (inCombat and isPriority and lbCount == 1 and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },

        -- [17] Stack 2 Any (< 75% + Has 1 Stack)
        [18] = { "LB Stack 2 Any", "Lifebloom",
            (inCombat and isPriority and hp < 0.75 and lbCount == 1 and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },

        -- [18] Stack 1 Critical (< 45% + No Stacks)
        [19] = { "LB Stack 1 Crit", "Lifebloom",
            (inCombat and isPriority and hp <= 0.45 and not hasLifebloom and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },

        -- [19] Stack 1 Priority (No Hots)
        [20] = { "LB Stack 1 Prio", "Lifebloom",
            (inCombat and isPriority and not hasRegrowth and not hasRejuv and not hasLifebloom 
            and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },

        -- [20] Stack 1 Any (< 75% + No Stacks)
        [21] = { "LB Stack 1 Any", "Lifebloom",
            (inCombat and isPriority and hp < 0.75 and not hasLifebloom and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },

        -- [21] Regrowth Backup Critical (< 45% + Missing Regrowth)
        [22] = { "Regrowth Back Crit", "Regrowth",
            (not isMoving and inCombat and hp <= 0.45 and not hasRegrowth and jungle.ReadyCastSpell('Regrowth', friend)) 
        },

        -- [22] Regrowth Backup Priority (< 85% + Missing Regrowth)
        [23] = { "Regrowth Back Prio", "Regrowth",
            (not isMoving and inCombat and isPriority and hp <= 0.85 and not hasRegrowth and jungle.ReadyCastSpell('Regrowth', friend)) 
        },

        -- [23] Regrowth Backup Aggro (< 85% + Missing Regrowth)
        [24] = { "Regrowth Back Aggro", "Regrowth",
            (not isMoving and inCombat and hp <= 0.85 and (targetedCount >= 1) and not hasRegrowth 
            and jungle.ReadyCastSpell('Regrowth', friend)) 
        },

        -- [24] Rejuv Mobile (< 60% + Moving + No Hots)
        [25] = { "Rejuv Mobile", "Rejuvenation",
            (inCombat and isMoving and hp < 0.60 
            and not hasRejuv and not hasRegrowth and not hasLifebloom
            and jungle.ReadyCastSpell('Rejuvenation', friend)) 
        },

        -- [25] Rejuv Aggro (< 85% + High Aggro)
        [26] = { "Rejuv Aggro", "Rejuvenation",
            (inCombat and hp <= 0.85 and (targetedCount >= 2) and not hasRejuv
            and jungle.ReadyCastSpell('Rejuvenation', friend)) 
        },

        -- [26] LB OOC (Not Combat + < 90% + No Hots)
        [27] = { "LB OOC", "Lifebloom",
            (not inCombat and hp <= 0.90 
            and not hasRejuv and not hasRegrowth and not hasLifebloom
            and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },

        -- [27] Stack 3x Panic (< 75% + Not Full Stacks)
        [28] = { "LB Panic Stack", "Lifebloom",
            (hp <= 0.75 and lbCount < 3 and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },

        -- [28] LB Filler (< 90% + No Stacks)
        [29] = { "LB Filler", "Lifebloom",
            (hp <= 0.90 and not hasLifebloom and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },

        -- [29] Regrowth Panic (< 45% + Standing)
        [30] = { "Regrowth Panic", "Regrowth",
            (not isMoving and inCombat and hp <= 0.45 and jungle.ReadyCastSpell('Regrowth', friend)) 
        },

        -- [30] Stack 3x Aggro (Targeted + Not Full Stacks)
        [31] = { "LB Aggro Stack", "Lifebloom",
            (inCombat and (targetedCount >= 2) and lbCount < 3 and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },
    }
end

jungle.raidHealSet = raidHealSet


-- ----------------------------------------------------------------------------
-- TANK ROTATION: Ported Logic (Maintenance & Pre-Hotting)
-- ----------------------------------------------------------------------------
local function tankRollSet(friend)
    local data = jungle.unitCache[friend]
    if not data or UnitIsDeadOrGhost(friend) then return {} end

    -- STRICT FILTER: Only Tanks
    -- Checks Main Tank assignment or Role Cache
    if not data.isTank then 
        return {} 
    end

    local hp = data.currLife
    local inCombat = data.isInCombat
    local isMoving = (GetUnitSpeed('player') > 0)
    local isTanking = jungle.isTanking(friend) -- Actually holding aggro
    
    -- Auras (Player Source)
    local hasRejuv     = jungle.unitCacheBuff(friend, 'Rejuvenation', '_PLAYER')
    local hasRegrowth  = jungle.unitCacheBuff(friend, 'Regrowth', '_PLAYER')
    local hasLifebloom = jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER')
    local hasNS        = jungle.unitCacheBuff("player", "Nature's Swiftness", '_PLAYER')

    -- Auras (Any Source - For Snipe Logic)
    local hasRegrowthAny = jungle.unitCacheBuff(friend, 'Regrowth')
    local hasRejuvAny    = jungle.unitCacheBuff(friend, 'Rejuvenation')

    -- Lifebloom State
    local lbExpireLimit = 1.5
    local lbCount = 0
    local lbExpiring = false
    
    if hasLifebloom then
        if jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', nil, 3) then lbCount = 3
        elseif jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', nil, 2) then lbCount = 2
        elseif jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', nil, 1) then lbCount = 1
        else lbCount = 3 end -- Fail-safe
        
        -- Expiring if SAFE check fails
        lbExpiring = not jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', lbExpireLimit)
    end

    return {
		[1] = { "NS Emergency", "Nature's Swiftness",
			(hp <= 0.3 and jungle.ReadyCastSpell('Healing Touch', friend) and not jungle.SpellOnCD("Nature's Swiftness") and not hasNS and data.isInCombat) },
		[2] = { "NS Cast", "Healing Touch",
			(jungle.ReadyCastSpell('Healing Touch', friend) and hasNS) },

        -- [2] Swiftmend Critical Tank (< 60% + HoT)
        [3] = { "Swiftmend Tank Crit", "Swiftmend",
            (inCombat and hp <= 0.60 and not jungle.SpellOnCD("Swiftmend") 
            and (hasRegrowth or hasRejuv)) -- Prefer own HoTs for critical tank save
        },

        -- [3] Update Active Tank (Aggro + Expiring)
        [4] = { "LB Refresh Active", "Lifebloom",
            (inCombat and isTanking and hasLifebloom and lbExpiring 
            and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },

        -- [4] Update Critical Tank (< 45% + Expiring)
        [5] = { "LB Refresh Crit", "Lifebloom",
            (inCombat and hp <= 0.45 and hasLifebloom and lbExpiring 
            and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },

        -- [5] Update Any Tank (Expiring)
        [6] = { "LB Refresh Any", "Lifebloom",
            (inCombat and hasLifebloom and lbExpiring 
            and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },

        -- [6] Regrowth Tank Panic (Standing + < 45%)
        [7] = { "Regrowth Panic", "Regrowth",
            (not isMoving and inCombat and hp <= 0.45 
            and jungle.ReadyCastSpell('Regrowth', friend)) 
        },

        -- [7] Tank Regrowth Active (Standing + Aggro + Missing)
        [8] = { "Regrowth Active", "Regrowth",
            (not isMoving and inCombat and isTanking and not hasRegrowth 
            and jungle.ReadyCastSpell('Regrowth', friend)) 
        },

        -- [8] Tank Rejuv Critical (< 45% + Missing)
        [9] = { "Rejuv Crit", "Rejuvenation",
            (inCombat and hp <= 0.45 and not hasRejuv 
            and jungle.ReadyCastSpell('Rejuvenation', friend)) 
        },

        -- [9] Tank Roll 3 Critical (< 45% + Stacks < 3)
        [10] = { "LB Stack 3 Crit", "Lifebloom",
            (inCombat and hp <= 0.45 and lbCount < 3 
            and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },

        -- [10] Tank Roll 3 Active (Aggro + Stacks < 3)
        [11] = { "LB Stack 3 Active", "Lifebloom",
            (inCombat and isTanking and lbCount < 3 
            and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },

        -- [11] Tank Rejuv Active (Aggro + Missing)
        [12] = { "Rejuv Active", "Rejuvenation",
            (inCombat and isTanking and not hasRejuv 
            and jungle.ReadyCastSpell('Rejuvenation', friend)) 
        },

        -- [12] Swiftmend Tank Snipe (< 80% + Non-My HoT)
        [13] = { "Swiftmend Snipe", "Swiftmend",
            (inCombat and not jungle.SpellOnCD("Swiftmend") and hp <= 0.80 
            and ((hasRegrowthAny and not hasRegrowth) or (hasRejuvAny and not hasRejuv))) 
        },

        -- [13] Swiftmend Tank Recycle (< 80% + My Expiring HoT)
        -- Logic: My HoT exists but is NOT safe for 5s (expires < 5s)
        [14] = { "Swiftmend Recycle", "Swiftmend",
            (inCombat and not jungle.SpellOnCD("Swiftmend") and hp <= 0.80 
            and ( (hasRegrowth and not jungle.unitCacheBuff(friend, 'Regrowth', '_PLAYER', 5)) 
               or (hasRejuv and not jungle.unitCacheBuff(friend, 'Rejuvenation', '_PLAYER', 5)) )) 
        },

        -- [14] Tank Update Bloom (OOC + Expiring)
        [15] = { "LB Refresh OOC", "Lifebloom",
            (not inCombat and hasLifebloom and lbExpiring 
            and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },

        -- [15] Tank One Bloom (OOC + Missing)
        -- Note: Checks if we have NO stacks.
        [16] = { "LB Start OOC", "Lifebloom",
            (not inCombat and not hasLifebloom 
            and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },

        -- [16] Tank Roll 3 (OOC + Stacks < 3)
        -- Builds the stack up to 3 between pulls.
        [17] = { "LB Build OOC", "Lifebloom",
            (not inCombat and lbCount < 3 
            and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },
    }
end

jungle.tankRollSet = tankRollSet

-- ----------------------------------------------------------------------------
-- TANK ROTATION 2: Converted Logic (External -> Jungle API)
-- ----------------------------------------------------------------------------
local function tankRollSet2(friend)
    local data = jungle.unitCache[friend]
    if not data or UnitIsDeadOrGhost(friend) then return {} end

    -- STRICT FILTER: Only Main Tanks or Assigned Tanks
    -- Matching external logic: GetPartyAssignment("MAINTANK", friend)
    -- We include data.isTank from cache which covers MainTank + Role 'TANK'
    if not data.isTank then 
        return {} 
    end

    local hp = data.currLife
    local inCombat = data.isInCombat
    local isTanking = jungle.isTanking(friend) -- Currently holding aggro
    
    -- Auras (Player)
    local hasRejuv     = jungle.unitCacheBuff(friend, 'Rejuvenation', '_PLAYER')
    local hasRegrowth  = jungle.unitCacheBuff(friend, 'Regrowth', '_PLAYER')
    local hasLifebloom = jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER')
    
    -- Auras (Any Source - For Snipe/Check)
    local hasRegrowthAny = jungle.unitCacheBuff(friend, 'Regrowth')
    local hasRejuvAny    = jungle.unitCacheBuff(friend, 'Rejuvenation')

    -- Lifebloom State
    local lbExpireLimit = 1.0 -- Matched to external 'expire = 1'
    local lbCount = 0
    local lbExpiring = false
    
    if hasLifebloom then
        -- Robust Count
        if jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', nil, 3) then lbCount = 3
        elseif jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', nil, 2) then lbCount = 2
        elseif jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', nil, 1) then lbCount = 1
        else lbCount = 3 end -- Fail-safe
        
        -- Logic: External Buff(..., expire) returns TRUE if expiring.
        -- Internal unitCacheBuff(..., expire) returns TRUE if safe.
        -- So: Expiring = NOT Safe.
        lbExpiring = not jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', lbExpireLimit)
    end

    return {
		[1] = { "NS Emergency", "Nature's Swiftness",
			(hp <= 0.3 and jungle.ReadyCastSpell('Healing Touch', friend) and not jungle.SpellOnCD("Nature's Swiftness") and not hasNS and data.isInCombat) },
		[2] = { "NS Cast", "Healing Touch",
			(jungle.ReadyCastSpell('Healing Touch', friend) and hasNS) },

        -- [2] Update Active Tank (Aggro + Expiring)
        [3] = { "LB Refresh Active", "Lifebloom",
            (inCombat and isTanking and hasLifebloom and lbExpiring
            and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },

        -- [3] Tank Non-My Hots 0.95 (Swiftmend)
        -- Logic: Has Regrowth/Rejuv ANY, but NOT Player's
        [4] = { "Swiftmend Non-My", "Swiftmend",
            (inCombat and isTanking and not jungle.SpellOnCD("Swiftmend") and hp <= 0.95
            and ((hasRegrowthAny and not hasRegrowth) or (hasRejuvAny and not hasRejuv))) 
        },

        -- [4] Tank My Hots 0.8 (Swiftmend)
        [5] = { "Swiftmend My", "Swiftmend",
            (inCombat and isTanking and not jungle.SpellOnCD("Swiftmend") and hp <= 0.80
            and (hasRegrowth or hasRejuv)) 
        },

        -- [5] Tank x3 (Stacking)
        [6] = { "LB Stack 3 Active", "Lifebloom",
            (inCombat and isTanking and lbCount < 3
            and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },

        -- [6] Tank No Tanking Update/One (Maintenance)
        -- Logic: Not tanking, HP < 100%, (Expiring OR Missing)
        [7] = { "LB Maintain Inactive", "Lifebloom",
            (inCombat and not isTanking and hp < 1.0 
            and ( (hasLifebloom and lbExpiring) or not hasLifebloom )
            and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },

        -- [7] Tank Active Regrowth (Missing)
        [8] = { "Regrowth Active", "Regrowth",
            (inCombat and isTanking and GetUnitSpeed('player') == 0 
            and not hasRegrowth
            and jungle.ReadyCastSpell('Regrowth', friend)) 
        },

        -- [8] Tank Rejuv Active (Missing)
        [9] = { "Rejuv Active", "Rejuvenation",
            (inCombat and isTanking and not hasRejuv
            and jungle.ReadyCastSpell('Rejuvenation', friend)) 
        },

        -- [9] Tank Regrowth 0.75 (Heal)
        -- Note: Checks HP <= 0.75, ignore buff status (Direct Heal usage)
        [10] = { "Regrowth Heal", "Regrowth",
            (inCombat and isTanking and GetUnitSpeed('player') == 0 and hp <= 0.75
            and jungle.ReadyCastSpell('Regrowth', friend)) 
        },

        -- [10] No Combat Update Tank
        [11] = { "LB Refresh OOC", "Lifebloom",
            (not inCombat and hasLifebloom and lbExpiring
            and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },

        -- [11] No Combat Tank (Stack to 3)
        [12] = { "LB Stack 3 OOC", "Lifebloom",
            (not inCombat and lbCount < 3
            and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },
    }
end
jungle.tankRollSet2 = tankRollSet2

-- ----------------------------------------------------------------------------
-- RAID ROTATION 2: Converted Logic
-- ----------------------------------------------------------------------------
local function raidHealSet2(friend)
    local data = jungle.unitCache[friend]
    if not data or UnitIsDeadOrGhost(friend) then return {} end

    -- STRICT FILTER: Non-Tanks
    if data.isTank then 
        return {} 
    end

    local hp = data.currLife
    local inCombat = data.isInCombat
    local isPrio = jungle.isPriority(friend)
    
    -- Auras
    local hasRejuv     = jungle.unitCacheBuff(friend, 'Rejuvenation', '_PLAYER')
    local hasRegrowth  = jungle.unitCacheBuff(friend, 'Regrowth', '_PLAYER')
    local hasLifebloom = jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER')
    
    -- Auras (Any)
    local hasRegrowthAny = jungle.unitCacheBuff(friend, 'Regrowth')
    local hasRejuvAny    = jungle.unitCacheBuff(friend, 'Rejuvenation')

    -- Lifebloom State
    local lbExpireLimit = 1.0
    local lbCount = 0
    local lbExpiring = false
    
    if hasLifebloom then
        if jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', nil, 3) then lbCount = 3
        elseif jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', nil, 2) then lbCount = 2
        elseif jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', nil, 1) then lbCount = 1
        else lbCount = 3 end
        lbExpiring = not jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', lbExpireLimit)
    end

    -- Regrowth/Rejuv "Empty" Checks (No Hots at all)
    local noHots = (not hasRejuv and not hasRegrowth and not hasLifebloom)

    return {
		[1] = { "NS Emergency", "Nature's Swiftness",
			(hp <= 0.3 and jungle.ReadyCastSpell('Healing Touch', friend) and not jungle.SpellOnCD("Nature's Swiftness") and not hasNS and data.isInCombat) },
		[2] = { "NS Cast", "Healing Touch",
			(jungle.ReadyCastSpell('Healing Touch', friend) and hasNS) },

        -- [2] Update Bloom (Priority or 80%)
        [3] = { "LB Refresh", "Lifebloom",
            (inCombat and hasLifebloom and lbExpiring 
            and (isPrio or hp <= 0.80)
            and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },

        -- [3] Swiftmend Non-My Hots 0.9 OR My Expiring Hots 0.9
        -- External Logic: Regrowth/Rejuv (Any and Not Player) OR (Player and Expiring < 5s)
        [4] = { "Swiftmend Snipe/Recycle", "Swiftmend",
            (inCombat and not jungle.SpellOnCD("Swiftmend") and hp <= 0.90
            and (
                (hasRegrowthAny and not hasRegrowth) or 
                (hasRejuvAny and not hasRejuv) or
                (hasRegrowth and not jungle.unitCacheBuff(friend, 'Regrowth', '_PLAYER', 5)) or
                (hasRejuv and not jungle.unitCacheBuff(friend, 'Rejuvenation', '_PLAYER', 5))
            )) 
        },

        -- [4] Swiftmend 60% (Or 40% w/ NS CD)
        [5] = { "Swiftmend Panic", "Swiftmend",
            (inCombat and not jungle.SpellOnCD("Swiftmend") 
            and ( (hp <= 0.60 and hp > 0.40) or (hp <= 0.40 and jungle.SpellOnCD("Nature's Swiftness")) )
            and (hasRegrowth or hasRejuv)) 
        },

        -- [5] 80% or Prio (Stack 2->3)
        [6] = { "LB Stack 3", "Lifebloom",
            (inCombat and (hp <= 0.80 or isPrio) and lbCount == 2
            and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },

        -- [6] 80% or Prio (Stack 1->2)
        [7] = { "LB Stack 2", "Lifebloom",
            (inCombat and (hp <= 0.80 or isPrio) and lbCount == 1
            and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },

        -- [7] Bloom 80% or Prio (Stack 0->1)
        [8] = { "LB Stack 1", "Lifebloom",
            (inCombat and (hp <= 0.80 or isPrio) and not hasLifebloom
            and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },

        -- [8] Regrowth (No Buffed 40% OR Priority 60%)
        [9] = { "Regrowth Panic", "Regrowth",
            (inCombat and GetUnitSpeed('player') == 0
            and ( (hp <= 0.40 and noHots) or (hp <= 0.60 and isPrio) )
            and jungle.ReadyCastSpell('Regrowth', friend)) 
        },

        -- [9] Rejuvenation (No Buffed 40% OR Priority 60%)
        [10] = { "Rejuv Panic", "Rejuvenation",
            (inCombat 
            and ( (hp <= 0.40 and noHots) or (hp <= 0.60 and isPrio) )
            and jungle.ReadyCastSpell('Rejuvenation', friend)) 
        },

        -- [10] Regrowth (40% OR Priority 60%) - General
        [11] = { "Regrowth General", "Regrowth",
            (inCombat and GetUnitSpeed('player') == 0
            and ( hp <= 0.40 or (hp <= 0.60 and isPrio) )
            and jungle.ReadyCastSpell('Regrowth', friend)) 
        },

        -- [11] Rejuvenation (40% OR Prio) - Missing Rejuv
        [12] = { "Rejuv General", "Rejuvenation",
            (inCombat and not hasRejuv
            and ( hp <= 0.40 or isPrio )
            and jungle.ReadyCastSpell('Rejuvenation', friend)) 
        },

        -- [12] No Combat Update (Expiring + Injured)
        [13] = { "LB Refresh OOC", "Lifebloom",
            (not inCombat and hasLifebloom and lbExpiring and hp < 1.0
            and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },

        -- [13] No Combat (Stack < 3 + Injured)
        [14] = { "LB Stack OOC", "Lifebloom",
            (not inCombat and lbCount < 3 and hp < 1.0
            and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },
    }
end
jungle.raidHealSet2 = raidHealSet2

local Jungle, jungle = ...

-- ----------------------------------------------------------------------------
-- UNIVERSAL V3: The "God Mode" Routine
-- Combines Tank Safety (Thread 1) + Raid Efficiency (Thread 4) + Snipe Logic
-- ----------------------------------------------------------------------------
local Jungle, jungle = ...

local function universalHealSetV3(friend)
    local data = jungle.unitCache[friend]
    if not data or UnitIsDeadOrGhost(friend) then return {} end

    -- 1. CONTEXT ANALYSIS
    local hp = data.currLife
    local inCombat = data.isInCombat
    local isTank = data.isTank 
    local isTanking = jungle.isTanking(friend) 
    local isPrio = jungle.isPriority(friend)
    local isMoving = (GetUnitSpeed('player') > 0)
    
    -- 2. AURA SCANNING
    local hasRejuv     = jungle.unitCacheBuff(friend, 'Rejuvenation', '_PLAYER')
    local hasRegrowth  = jungle.unitCacheBuff(friend, 'Regrowth', '_PLAYER')
    local hasLifebloom = jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER')
    local hasNS        = jungle.unitCacheBuff("player", "Nature's Swiftness", '_PLAYER')
    local _, noManaLB  = IsUsableSpell("Lifebloom")
    
    local hasRegrowthAny = jungle.unitCacheBuff(friend, 'Regrowth')
    local hasRejuvAny    = jungle.unitCacheBuff(friend, 'Rejuvenation')

    -- 3. ROBUST LIFEBLOOM COUNTING
    local lbExpireLimit = 1.5
    if jungle.isCasting('player', 2,'Regrowth') then
        lbExpireLimit = 1.8
    end
    local lbCount = 0
    local lbExpiring = false
    
    if hasLifebloom then
        if jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', nil, 3) then lbCount = 3
        elseif jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', nil, 2) then lbCount = 2
        elseif jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', nil, 1) then lbCount = 1
        else lbCount = 3 end
        
        lbExpiring = not jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', lbExpireLimit)
    end

    -- 4. PURE HEALING LOGIC
    return {
        -- ======================================
        -- PRIORITY 1: EMERGENCY
        -- ======================================
        [1] = { "NS Emergency", "Nature's Swiftness",
            (inCombat and not hasNS and not jungle.SpellOnCD("Nature's Swiftness") 
            and ( (isTank and hp <= 0.40) or (hp <= 0.35) and (jungle.SpellOnCD("Swiftmend") or  not (hasRegrowthAny or hasRejuvAny)))) 
        },
        [2] = { "NS Cast", "Healing Touch",
            (inCombat and jungle.ReadyCastSpell('Healing Touch', friend) and hasNS 
            and ( (isTank and hp <= 0.40) or (hp <= 0.35) )) 
        },
        [3] = { "Swiftmend Panic", "Swiftmend",
            (inCombat and not jungle.SpellOnCD("Swiftmend") 
            and ( (isTank and hp <= 0.50) or (hp <= 0.40) )
            and (hasRegrowthAny or hasRejuvAny)) 
        },
        [4] = { "LB Tank Safety", "Lifebloom",
            (isTank and hasLifebloom and lbExpiring and jungle.ReadyCastSpell('Lifebloom', friend)),
			"PROTECT_BLOOM" -- [MARKER] Protect stack building
        },

        -- ======================================
        -- PRIORITY 2: TANK MAINTENANCE
        -- ======================================
        [5] = { "LB Tank Stack", "Lifebloom",
            (isTank and isTanking and not hasLifebloom and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },
        [6] = { "Regrowth Tank", "Regrowth",
            (isTank and isTanking and not isMoving and not hasRegrowth and hp < 0.90
            and jungle.bloomWindow("Regrowth") -- [SIMULATOR CHECK]
            and jungle.ReadyCastSpell('Regrowth', friend) and not jungle.isCasting('player', 0.5,'Regrowth')) 
        },
        [7] = { "LB Tank Stack", "Lifebloom",
            (isTank and isTanking and lbCount < 3 and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },
        [8] = { "Rejuv Tank", "Rejuvenation",
            (isTank and isTanking and not hasRejuv and hp < 0.90
            and jungle.ReadyCastSpell('Rejuvenation', friend)) 
        },

        -- ======================================
        -- PRIORITY 3: RAID EFFICIENCY 
        -- ======================================
        [9] = { "Swiftmend Snipe", "Swiftmend",
            (inCombat and not jungle.SpellOnCD("Swiftmend") and not isTank and hp <= 0.80
            and ((hasRegrowthAny and not hasRegrowth) or (hasRejuvAny and not hasRejuv))) 
        },
        [10] = { "Regrowth Raid", "Regrowth",
            (inCombat and not isMoving and not hasRegrowth and not isTank and hp <= 0.60
            and jungle.bloomWindow("Regrowth") -- [SIMULATOR CHECK]
            and jungle.ReadyCastSpell('Regrowth', friend) and not jungle.isCasting('player', 0.5,'Regrowth')) 
        },
        [11] = { "LB Stack 3", "Lifebloom",
            (jungle.ReadyCastSpell('Lifebloom', friend) and lbCount == 2 and hp < 0.60
            and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },
        [12] = { "Rejuv Raid", "Rejuvenation",
            (inCombat and not hasRejuv and not isTank and hp <= 0.80
            and jungle.ReadyCastSpell('Rejuvenation', friend)) 
        },
        [13] = { "LB Stack 2", "Lifebloom",
            (jungle.ReadyCastSpell('Lifebloom', friend) and lbCount == 1 and hp <= 0.80
             and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },
        [14] = { "LB Refresh 3", "Lifebloom",
            (jungle.ReadyCastSpell('Lifebloom', friend) and lbExpiring and hp < 0.80
             and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },
        [15] = { "LB Start", "Lifebloom",
            (jungle.ReadyCastSpell('Lifebloom', friend) and lbCount == 0 and hp < 0.90
            and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },

        -- ======================================
        -- PRIORITY 4: OOC & FILLER
        -- ======================================
        [16] = { "LB OOC Tank", "Lifebloom",
            (not inCombat and isTank and (not hasLifebloom or lbExpiring)
            and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },
        [17] = { "LB OOC Raid", "Lifebloom",
            (not inCombat and not isTank and hp < 0.90 and not hasLifebloom
            and jungle.ReadyCastSpell('Lifebloom', friend)) 
        },
    }
end
jungle.universalHealSetV3 = universalHealSetV3