local Jungle, jungle = ...
local unitCache = jungle.unitCache

jungle.TTD_Cache = jungle.TTD_Cache or {}

-- Talented/expansion spells that should be skipped when they are not learned.
jungle.ignoreUnlearnedSpells = jungle.ignoreUnlearnedSpells or {}
for _, spell in ipairs({
    "Mangle (Bear)",
    "Lifebloom",
    "Tree of Life",
    "Moonkin Form",
    "Insect Swarm",
}) do
    jungle.ignoreUnlearnedSpells[spell] = true
end

local function IsSpellLearned(spell)
    return GetSpellBookItemInfo(spell) ~= nil
end

local function IsSpellIDKnown(spellID)
    return ((IsPlayerSpell and IsPlayerSpell(spellID)) or (IsSpellKnown and IsSpellKnown(spellID))) and true or false
end

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
    if not jungle.IsSpellReadyIgnoreGCD(formName) then return false end

    local shouldShift = false

    -- 2. Escape Logic (Roots/Slows) - Valid for ALL forms
    -- Triggers if we are slowed or rooted to break the effect immediately
    if jungle.isSlowed('player') then
        shouldShift = true
    end

    -- Check for Furor talent to enable resource-based shifting
    local hasFuror = IsPlayerSpell(17056) or IsPlayerSpell(17058) or IsPlayerSpell(17059) or IsPlayerSpell(17060) or IsPlayerSpell(17061)

    -- 3. Resource Logic (Form Specific)
    if formID == 3 then -- CAT FORM
        local energy = UnitPower("player", 3)
        local timeToTick = jungle.TimeUntilTick()
        -- Shift if Energy is low AND we won't clip a tick AND we have Furor
        if energy <= 11 and timeToTick <= 1 and hasFuror then
            shouldShift = true
        end

    elseif formID == 1 then -- BEAR FORM
        local rage = UnitPower("player", 1)
        -- Shift if Rage is empty (to trigger Furor talent for 10 Rage)
        -- Only if NOT tanking something actively hitting us (safety) and we have Furor
        if rage < 10 and not jungle.isTanking('player') and hasFuror then
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
local dispellCache = {
    [1] = {'Dispel Poison', "Abolish Poison", false, 1, 0},
    [2] = {'Decurse', "Remove Curse", false, 1, 0},
}
local emptyDispellCache = {}

local function hasActiveDebuff(debuffTable)
    for _, debuff in pairs(debuffTable) do
        if debuff.isActive then
            return true
        end
    end
    return false
end

function jungle.dispellSet(friend)
    -- FACT: Check if the unit exists in cache before indexing
    local data = unitCache[friend]
    if not data then return emptyDispellCache end

    -- Refactor: Check if the 'poison' or 'curse' sub-tables have ANY entries
    local hasPoison = hasActiveDebuff(data.auras.debuffs.poison)
    local hasCurse = hasActiveDebuff(data.auras.debuffs.curse)

    dispellCache[1][3] = (jungle.ReadyCastSpell('Abolish Poison', friend) and hasPoison and not jungle.unitCacheBuff(friend, 'Abolish Poison', '_PLAYER'))
    dispellCache[2][3] = (jungle.ReadyCastSpell('Remove Curse', friend) and hasCurse)

    return dispellCache
end

local dpsCatStealthCache = {
    [1]= {'Ravage', 'Ravage', false, 1, 0},
    [2]= {'Tiger Fury', "Tiger's Fury", false, 1, 0},
}
local dpsCatCache = {
    [1]= {'Rip', 'Rip', false, 1, 0},
    [2]= {'Ferocious Bite', 'Ferocious Bite', false, 1, 0},
    [3]= {'FF Feral', 'Faerie Fire (Feral)', false, 1, 0},
    [4]= {'Tiger Fury', "Tiger's Fury", false, 1, 0},
    [5]= {'Rake', 'Rake', false, 1, 0},
    [6]= {'Mangle Cat', 'Mangle (Cat)', false, 1, 0},
    [7]= {'Shred', 'Shred', false, 1, 0},
    [8]= {'Attack', 'Attack', false, 1, 0},
    [9]= {'Powershift Cat', 'Cat Form', false, 1, 0},
}
local dpsBearCache = {
    [1]= {'Demo Shout', 'Demoralizing Shout', false, 1, 0},
    [2]= {'Mangle Bear', 'Mangle (Bear)', false, 1, 0},
    [3]= {'Powershift Bear', 'Dire Bear Form', false, 1, 0},
    [4]= {'Maul', 'Maul', false, 1, 0},
    [5]= {'Lacerate', 'Lacerate', false, 1, 0}, 
    [6]= {'FF Feral', 'Faerie Fire (Feral)', false, 1, 0},
    [7]= {'Attack', 'Attack', false, 1, 0},
}
local dpsCasterCache = {
    [1]= {'Faerie Fire', 'Faerie Fire', false, 1, 0},
    [2]= {'Moonfire', 'Moonfire', false, 1, 0},
    [3]= {'Insect Swarm', 'Insect Swarm', false, 1, 0},
    [4]= {'Starfire', 'Starfire', false, 1, 0},
    [5]= {'Wrath', 'Wrath', false, 1, 0},
    [6]= {'Attack', 'Attack', false, 1, 0},
}
local dpsPvPCasterCache = {
    [1]= {'Moonfire', 'Moonfire', false, 1, 0},
    [2]= {'Insect Swarm', 'Insect Swarm', false, 1, 0},
    [3]= {'Faerie Fire', 'Faerie Fire', false, 1, 0},
    [4]= {'Starfire', 'Starfire', false, 1, 0},
    [5]= {'Wrath', 'Wrath', false, 1, 0},
    [6]= {'Attack', 'Attack', false, 1, 0},
}
local dpsPowershiftCache = {
    [1]= {'Powershift Return', '', false, 1, 0},
}
local emptyDpsCache = {}

-- THREAD 5: STANCE-AWARE DPS
function jungle.dpsSet(_target)
    if not UnitExists(_target) or not UnitCanAttack("player", _target) then return emptyDpsCache end
    
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
        if jungle.unitCacheBuff('player', "Tiger's Fury") then
            tigerFuryLastActive = GetTime()
        end

        if isStealthed then
            dpsCatStealthCache[1][3] = (jungle.ReadyCastSpell('Ravage', _target))
            dpsCatStealthCache[2][3] = (not jungle.unitCacheBuff('player', "Tiger's Fury") and jungle.ReadyCastSpell("Tiger's Fury") and cp <= 1 and timeToTick <= 1)
            return dpsCatStealthCache
        else
            -- [[ POWERSHIFT CONDITIONAL ]]
            local limitPowershift = (UnitPower("player", 0) / UnitPowerMax("player", 0) < 0.5) 
                                    and UnitIsUnit("player", _target .. "target") 
                                    and not UnitIsPlayer(_target)
            local catBuilderSpell = IsSpellLearned('Mangle (Cat)') and 'Mangle (Cat)' or 'Claw'

            dpsCatCache[1][3] = (jungle.ReadyCastSpell('Rip', _target) and useRip)
            dpsCatCache[2][3] = (jungle.ReadyCastSpell('Ferocious Bite', _target) and useFB)
            dpsCatCache[3][3] = (jungle.ReadyCastSpell('Faerie Fire (Feral)', _target) and not jungle.Debuff('Faerie Fire (Feral)', _target) and  not jungle.Debuff('Faerie Fire', _target) and UnitCreatureType(_target)~="Elemental" and UnitCreatureType(_target)~="Totem")
            dpsCatCache[4][3] = (not jungle.unitCacheBuff('player', "Tiger's Fury") and jungle.ReadyCastSpell("Tiger's Fury") and cp == 0 and (GetTime() - tigerFuryLastActive > 3) and (timeToTick <= 0.5 and energy >= 60))
            dpsCatCache[5][3] = (jungle.ReadyCastSpell('Rake', _target) and shouldRake and jungle.ImNotBehindUnit(_target))
            dpsCatCache[6][1] = (catBuilderSpell == 'Mangle (Cat)') and 'Mangle Cat' or 'Claw'
            dpsCatCache[6][2] = catBuilderSpell
            dpsCatCache[6][3] = (jungle.ReadyCastSpell(catBuilderSpell, _target) and cp < 5 and (jungle.ImNotBehindUnit(_target) or ( not UnitIsPlayer(_target) and UnitIsUnit('player', _target..'target'))))
            dpsCatCache[7][3] = (jungle.ReadyCastSpell('Shred', _target) and cp < 5 and  not jungle.ImNotBehindUnit(_target))
            dpsCatCache[8][3] = (shouldAttack)
            dpsCatCache[9][3] = (not limitPowershift and CheckPowershift('Cat Form', 3) and IsSpellInRange("Rake", "target") == 1 and not jungle.unitCacheBuff('player', "Clearcasting"))

            return dpsCatCache
        end

    elseif form == 1 then -- BEAR FORM
        local rage = UnitPower("player", 1)
        
        local needsDemo = not jungle.Debuff('Demoralizing Shout', _target)
        local demoContext = (jungle.targetedByCount('player', 'phys') >= 2 or isElite)
        local inDemoRange = jungle.inMeleeRange(_target) 
        local useDemo = (jungle.ReadyCastSpell('Demoralizing Shout') and needsDemo and demoContext and inDemoRange)

        local maulIDs = {6807, 6808, 6809, 8972, 9745, 9880, 9881, 26996}
        local isMaulQueued = false
        for _, id in ipairs(maulIDs) do
            if IsCurrentSpell(id) then isMaulQueued = true break end
        end

        local canMaul = (not isMaulQueued and rage >= 45 and inDemoRange)

        dpsBearCache[1][3] = (useDemo)
        dpsBearCache[2][3] = (jungle.ReadyCastSpell('Mangle (Bear)', _target))
        dpsBearCache[3][3] = (CheckPowershift('Dire Bear Form', 1))
        dpsBearCache[4][3] = (jungle.ReadyCastSpell('Maul', _target) and canMaul)
        dpsBearCache[5][3] = (jungle.ReadyCastSpell('Lacerate', _target) and not jungle.Debuff('Lacerate', _target, nil, 5)) 
        dpsBearCache[6][3] = (jungle.ReadyCastSpell('Faerie Fire (Feral)', _target) and not jungle.Debuff('Faerie Fire (Feral)', _target) and  not jungle.Debuff('Faerie Fire', _target) and UnitCreatureType(_target)~="Elemental" and UnitCreatureType(_target)~="Totem")
        dpsBearCache[7][3] = (shouldAttack)

        return dpsBearCache
    else -- CASTER / HUMAN (Default)
        
        -- [[ POWERSHIFT RECOVERY LOGIC ]]
        -- If we are in the powershift window (timer active), we IGNORE caster spells 
        -- and FORCE the return to the target form immediately.
        if GetTime() < powershiftEndTime and powershiftTarget > 0 then
            local returnSpell = (powershiftTarget == 1 and "Dire Bear Form") or (powershiftTarget == 3 and "Cat Form")
            if returnSpell then
                dpsPowershiftCache[1][2] = returnSpell
                dpsPowershiftCache[1][3] = (jungle.ReadyCastSpell(returnSpell))
                return dpsPowershiftCache
            end
        end
		
		-- Standard Caster Rotation (Only if window expired or manual shift)
        local isMoving = GetUnitSpeed('player') > 0
        local inCombat = UnitAffectingCombat('player')
        local isPvPTarget = UnitIsPVP(_target)
        local starfireReady = not isMoving and jungle.ReadyCastSpell('Starfire', _target)
        local wrathReady = not isMoving and jungle.ReadyCastSpell('Wrath', _target)

        local isMoonkin = (GetShapeshiftForm() == 5 or jungle.unitCacheBuff('player', "Moonkin Form"))
        local targetLevel = UnitLevel(_target)
        local isHighLevel = (targetLevel == -1 or targetLevel >= 70)
        local hasMoonfire = jungle.Debuff('Moonfire', _target, '|PLAYER')
        local hasInsectSwarm = jungle.Debuff('Insect Swarm', _target, '|PLAYER')
        local hasFaerieFire = jungle.Debuff('Faerie Fire', _target) or jungle.Debuff('Faerie Fire (Feral)', _target)

        if isPvPTarget then
            local hasBothDots = hasMoonfire and hasInsectSwarm

            dpsPvPCasterCache[1][3] = (isMoving and jungle.ReadyCastSpell('Moonfire', _target) and (not hasMoonfire or (hasBothDots and hasFaerieFire)))
            dpsPvPCasterCache[2][3] = (isMoving and jungle.ReadyCastSpell('Insect Swarm', _target) and not hasInsectSwarm)
            dpsPvPCasterCache[3][3] = (isMoving and hasBothDots and not hasFaerieFire and jungle.ReadyCastSpell('Faerie Fire', _target))
            dpsPvPCasterCache[4][3] = (starfireReady and not wrathReady)
            dpsPvPCasterCache[5][3] = wrathReady
            dpsPvPCasterCache[6][3] = shouldAttack

            return dpsPvPCasterCache
        end

        local hasAllPvEDebuffs = hasMoonfire
            and (hasInsectSwarm or not IsSpellLearned('Insect Swarm'))
            and (not isMoonkin or not isHighLevel or hasFaerieFire)
        local usePvEMoonfire = isMoving
            and jungle.ReadyCastSpell('Moonfire', _target)
            and (not hasMoonfire or hasAllPvEDebuffs)

        if isMoonkin then
            local preferWrath = CheckInteractDistance(_target, 3)
            local useWrath = wrathReady and (preferWrath or not starfireReady)
            local useStarfire = starfireReady and not useWrath

            dpsCasterCache[1][3] = (jungle.ReadyCastSpell('Faerie Fire', _target) and isHighLevel and not jungle.Debuff('Faerie Fire', _target) and not jungle.Debuff('Faerie Fire (Feral)', _target))
            dpsCasterCache[2][3] = usePvEMoonfire
            dpsCasterCache[3][3] = (isMoving and jungle.ReadyCastSpell('Insect Swarm', _target) and not hasInsectSwarm)
            dpsCasterCache[4][3] = useStarfire
            dpsCasterCache[5][3] = useWrath
        else
            dpsCasterCache[1][3] = false
            dpsCasterCache[2][3] = usePvEMoonfire
            dpsCasterCache[3][3] = (isMoving and jungle.ReadyCastSpell('Insect Swarm', _target) and not hasInsectSwarm)
            dpsCasterCache[4][3] = (starfireReady and not inCombat)
            dpsCasterCache[5][3] = (wrathReady and inCombat)
        end
        dpsCasterCache[6][3] = (shouldAttack)

        return dpsCasterCache
    end
end

-- THREAD 6: BUFF LOGIC
--------------------------------------------------------------------------------
local buffCache = {
    [1]= {'Omen', "Omen of Clarity", false, 1, 0},
    [2]= {'MotW Self', "Mark of the Wild", false, 1, 0},
    [3]= {'MotW Group', "Mark of the Wild", false, 1, 0},
    [4]= {'Thorns', "Thorns", false, 1, 0},
}

function jungle.buffSet(friend)
    local data = unitCache[friend]
    -- Check group status (0 = solo)
    local inGroup = GetNumGroupMembers() > 0
    local isPlayer = data.isMe
    -- Check for assigned tank role (Main Tank or assigned Tank role in cache)
    local isAssignedTank = data.isTank or UnitIsUnit("target", friend)

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

    buffCache[1][3] = (isPlayer and jungle.ReadyCastSpell('Omen of Clarity', friend) and not jungle.unitCacheBuff(friend, "Omen of Clarity", nil, 300))
    buffCache[2][3] = (isPlayer and jungle.ReadyCastSpell('Mark of the Wild', friend) and not jungle.unitCacheBuff(friend, "Mark of the Wild", nil, 600) and not jungle.unitCacheBuff(friend, "Gift of the Wild"))
    buffCache[3][3] = (not isPlayer and jungle.ReadyCastSpell('Mark of the Wild', friend) and not jungle.unitCacheBuff(friend, "Mark of the Wild", nil, 600) and not jungle.unitCacheBuff(friend, "Gift of the Wild"))
    buffCache[4][3] = (shouldBuffThorns and jungle.ReadyCastSpell('Thorns', friend) and not jungle.unitCacheBuff(friend, "Thorns", nil, 300))

    return buffCache
end

-- ----------------------------------------------------------------------------
-- PvE ROTATION: Efficiency & Tank Maintenance
-- ----------------------------------------------------------------------------
local pveHealCache = {
    [1] = { "NS Emergency", "Nature's Swiftness", false },
    [2] = { "NS Cast", "Healing Touch", false },
    [3] = { "Swiftmend Save", "Swiftmend", false },
    [4] = { "LB Tank Refresh", "Lifebloom", false },
    [5] = { "LB Tank Stack", "Lifebloom", false },
    [6] = { "Regrowth Tank HoT", "Regrowth", false },
    [7] = { "LB Crisis Stack", "Lifebloom", false },
    [8] = { "Regrowth Crisis", "Regrowth", false },
    [9] = { "Rejuv Fill", "Rejuvenation", false },
    [10] = { "LB Refresh", "Lifebloom", false },
    [11] = { "LB Base", "Lifebloom", false },
    [12] = { "LB Tank OOC Refresh", "Lifebloom", false },
    [13] = { "LB Tank OOC Fresh", "Lifebloom", false }
}
local emptyPveCache = {}

local function pveHealSet(friend)
    local data = jungle.unitCache[friend]
    if not data or UnitIsDeadOrGhost(friend) then return emptyPveCache end

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
    local lbExpireLimit = 1.7
	if jungle.isCasting('player', 2,'Regrowth') then
		lbExpireLimit = 2.0
	end
    local lbCount = 0
    local lbExpiring = nil
    
   if hasLifebloom then
        -- ROBUST STACK COUNTING
        if jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', nil, 3) then lbCount = 3
        elseif jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', nil, 2) then lbCount = 2
        elseif jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', nil, 1) then lbCount = 1
        else
            lbCount = 3
        end
        
        lbExpiring = not jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', lbExpireLimit)
    end

    pveHealCache[1][3] = (hp <= 0.3 and jungle.ReadyCastSpell('Healing Touch', friend) and jungle.IsSpellReadyIgnoreGCD("Nature's Swiftness") and not hasNS and data.isInCombat)
    pveHealCache[2][3] = (jungle.ReadyCastSpell('Healing Touch', friend) and hasNS)
    pveHealCache[3][3] = (jungle.IsSpellReadyIgnoreGCD("Swiftmend") and hp <= 0.60 and (hasRejuv or hasRegrowth) and data.isInCombat)
    pveHealCache[4][3] = (not noManaLB and isTank and isTanking and lbExpiring)
    pveHealCache[5][3] = (not noManaLB and isTanking and lbCount < 3)
    pveHealCache[6][3] = (jungle.ReadyCastSpell('Regrowth', friend) and hp <= 0.80 and isTanking and not hasRegrowth and GetUnitSpeed('player') == 0)
    pveHealCache[7][3] = (not noManaLB and hp < 0.70 and lbCount < 3)
    pveHealCache[8][3] = (jungle.ReadyCastSpell('Regrowth', friend) and hp < 0.60 and not hasRegrowth and GetUnitSpeed('player') == 0)
    pveHealCache[9][3] = (jungle.ReadyCastSpell('Rejuvenation', friend) and (hp < 0.85 or (isTank and hp <0.9)) and not hasRejuv)
    pveHealCache[10][3] = (jungle.ReadyCastSpell('Lifebloom', friend) and hp < 0.70 and lbExpiring)
    pveHealCache[11][3] = (jungle.ReadyCastSpell('Lifebloom', friend) and hp < 0.90 and not hasLifebloom)
    
    -- [UPDATE] Split OOC Lifebloom into strict priority to prevent OOC tanks from stealing GCD when a refresh is critically expiring
    pveHealCache[12][3] = (jungle.ReadyCastSpell('Lifebloom', friend) and isTank and not data.isInCombat and hasLifebloom and lbExpiring)
    pveHealCache[13][3] = (jungle.ReadyCastSpell('Lifebloom', friend) and isTank and not data.isInCombat and not hasLifebloom)

    return pveHealCache
end

-- ----------------------------------------------------------------------------
-- PvP ROTATION: Triage & Burst Protection
-- ----------------------------------------------------------------------------
local pvpHealCache = {
    [1] = { "NS PvP", "Nature's Swiftness", false },
    [2] = { "HT PvP", "Healing Touch", false },
    [3] = { "Swiftmend PvP", "Swiftmend", false },
    [4] = { "LB PvP Stack", "Lifebloom", false },
    [5] = { "LB PvP Refresh", "Lifebloom", false },
    [6] = { "Rejuv PvP", "Rejuvenation", false },
    [7] = { "LB Maintain", "Lifebloom", false }
}
local emptyPvpCache = {}

local function pvpHealSet(friend)
    local data = jungle.unitCache[friend]
    if not data or data.currLife >= 0.99 or UnitIsDeadOrGhost(friend) then return emptyPvpCache end

    -- PvP Logic: Focus on whoever is being attacked NOW
    local attackers = jungle.targetedByCount(friend)
    local isFocused = (attackers >= 1)
    
    local hasLifebloom = jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER')
    local lbFull       = jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', 0, 3)

    pvpHealCache[1][3] = (data.currLife <= 0.40 and jungle.IsSpellReadyIgnoreGCD("Nature's Swiftness") and data.isInCombat)
    pvpHealCache[2][3] = (data.currLife <= 0.40 and jungle.unitCacheBuff("player", "Nature's Swiftness", "_PLAYER"))
    pvpHealCache[3][3] = (jungle.IsSpellReadyIgnoreGCD("Swiftmend") and data.currLife <= 0.60 and (jungle.unitCacheBuff(friend, "Rejuvenation") or jungle.unitCacheBuff(friend, "Regrowth")))
    pvpHealCache[4][3] = (jungle.ReadyCastSpell('Lifebloom', friend) and isFocused and not lbFull)
    pvpHealCache[5][3] = (jungle.ReadyCastSpell('Lifebloom', friend) and hasLifebloom and not jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', 1.5))
    pvpHealCache[6][3] = (jungle.ReadyCastSpell('Rejuvenation', friend) and not jungle.unitCacheBuff(friend, "Rejuvenation", "_PLAYER"))
    pvpHealCache[7][3] = (jungle.ReadyCastSpell('Lifebloom', friend) and not hasLifebloom and data.currLife < 0.95)

    return pvpHealCache
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
    local lbExpireLimit = 1.7 -- Matched to external logic
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
			(hp <= 0.3 and jungle.ReadyCastSpell('Healing Touch', friend) and jungle.IsSpellReadyIgnoreGCD("Nature's Swiftness") and not hasNS and data.isInCombat) },
		[2] = { "NS Cast", "Healing Touch",
			(jungle.ReadyCastSpell('Healing Touch', friend) and hasNS) },

        -- [2] Swiftmend Save (Critical < 60% + Hot)
        [3] = { "Swiftmend Save", "Swiftmend",
            (inCombat and hp <= 0.60 and jungle.IsSpellReadyIgnoreGCD("Swiftmend") 
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
            (inCombat and jungle.IsSpellReadyIgnoreGCD("Swiftmend") and hp <= 0.85 
            and ((hasRegrowthAny and not hasRegrowth) or (hasRejuvAny and not hasRejuv))) 
        },

        -- [8] Swiftmend Recycle (My Hot Expiring + < 85%)
        -- Logic: My hot exists, but is NOT safe for 5 seconds (expires < 5s)
        [9] = { "Swiftmend Recycle", "Swiftmend",
            (inCombat and jungle.IsSpellReadyIgnoreGCD("Swiftmend") and hp <= 0.85
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
    local lbExpireLimit = 1.7
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
			(hp <= 0.3 and jungle.ReadyCastSpell('Healing Touch', friend) and jungle.IsSpellReadyIgnoreGCD("Nature's Swiftness") and not hasNS and data.isInCombat) },
		[2] = { "NS Cast", "Healing Touch",
			(jungle.ReadyCastSpell('Healing Touch', friend) and hasNS) },

        -- [2] Swiftmend Critical Tank (< 60% + HoT)
        [3] = { "Swiftmend Tank Crit", "Swiftmend",
            (inCombat and hp <= 0.60 and jungle.IsSpellReadyIgnoreGCD("Swiftmend") 
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
            (inCombat and jungle.IsSpellReadyIgnoreGCD("Swiftmend") and hp <= 0.80 
            and ((hasRegrowthAny and not hasRegrowth) or (hasRejuvAny and not hasRejuv))) 
        },

        -- [13] Swiftmend Tank Recycle (< 80% + My Expiring HoT)
        -- Logic: My HoT exists but is NOT safe for 5s (expires < 5s)
        [14] = { "Swiftmend Recycle", "Swiftmend",
            (inCombat and jungle.IsSpellReadyIgnoreGCD("Swiftmend") and hp <= 0.80 
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
local tankRollCache2 = {
    [1] = { "NS Emergency", "Nature's Swiftness", false },
    [2] = { "NS Cast", "Healing Touch", false },
    [3] = { "LB Refresh Active", "Lifebloom", false },
    [4] = { "Swiftmend Non-My", "Swiftmend", false },
    [5] = { "Swiftmend My", "Swiftmend", false },
    [6] = { "LB Stack 3 Active", "Lifebloom", false },
    [7] = { "LB Maintain Inactive", "Lifebloom", false },
    [8] = { "Regrowth Active", "Regrowth", false },
    [9] = { "Rejuv Active", "Rejuvenation", false },
    [10] = { "Regrowth Heal", "Regrowth", false },
    [11] = { "LB Refresh OOC", "Lifebloom", false },
    [12] = { "LB Stack 3 OOC", "Lifebloom", false }
}
local emptyTankRollCache2 = {}

local function tankRollSet2(friend)
    local data = jungle.unitCache[friend]
    if not data or UnitIsDeadOrGhost(friend) then return emptyTankRollCache2 end

    -- STRICT FILTER: Only Main Tanks or Assigned Tanks
    if not data.isTank then 
        return emptyTankRollCache2 
    end

    local hp = data.currLife
    local inCombat = data.isInCombat
    local isTanking = (data.threatStatus == 3 or data.threatStatus == 2)
    
    -- Auras (Player)
    local hasRejuv     = jungle.unitCacheBuff(friend, 'Rejuvenation', '_PLAYER')
    local hasRegrowth  = jungle.unitCacheBuff(friend, 'Regrowth', '_PLAYER')
    local hasLifebloom = jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER')
    local hasNS        = jungle.unitCacheBuff("player", "Nature's Swiftness", '_PLAYER')
    
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
        
        lbExpiring = not jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', lbExpireLimit)
    end

    local healingTouchReady = jungle.ReadyCastSpell('Healing Touch', friend)
    tankRollCache2[1][3] = (hp <= 0.3 and healingTouchReady and jungle.IsSpellReadyIgnoreGCD("Nature's Swiftness") and not hasNS and data.isInCombat)
    tankRollCache2[2][3] = (healingTouchReady and hasNS)
    tankRollCache2[3][3] = (inCombat and isTanking and hasLifebloom and lbExpiring and jungle.ReadyCastSpell('Lifebloom', friend))
    local swiftmendReady = inCombat and isTanking and jungle.IsSpellReadyIgnoreGCD("Swiftmend")
    tankRollCache2[4][3] = (swiftmendReady and hp <= 0.95 and ((hasRegrowthAny and not hasRegrowth) or (hasRejuvAny and not hasRejuv)))
    tankRollCache2[5][3] = (swiftmendReady and hp <= 0.80 and (hasRegrowth or hasRejuv))
    tankRollCache2[6][3] = (inCombat and isTanking and lbCount < 3 and jungle.ReadyCastSpell('Lifebloom', friend))
    tankRollCache2[7][3] = (inCombat and not isTanking and hp < 1.0 and ( (hasLifebloom and lbExpiring) or not hasLifebloom ) and jungle.ReadyCastSpell('Lifebloom', friend))
    local canHardcast = inCombat and isTanking and GetUnitSpeed('player') == 0
    tankRollCache2[8][3] = (canHardcast and not hasRegrowth and jungle.ReadyCastSpell('Regrowth', friend))
    tankRollCache2[9][3] = (inCombat and isTanking and not hasRejuv and jungle.ReadyCastSpell('Rejuvenation', friend))
    tankRollCache2[10][3] = (canHardcast and hp <= 0.75 and jungle.ReadyCastSpell('Regrowth', friend))
    tankRollCache2[11][3] = (not inCombat and hasLifebloom and lbExpiring and jungle.ReadyCastSpell('Lifebloom', friend))
    tankRollCache2[12][3] = (not inCombat and lbCount < 3 and jungle.ReadyCastSpell('Lifebloom', friend))

    return tankRollCache2
end
jungle.tankRollSet2 = tankRollSet2

-- ----------------------------------------------------------------------------
-- RAID ROTATION 2: Converted Logic
-- ----------------------------------------------------------------------------
local raidHealCache2 = {
    [1] = { "NS Emergency", "Nature's Swiftness", false },
    [2] = { "NS Cast", "Healing Touch", false },
    [3] = { "LB Refresh", "Lifebloom", false },
    [4] = { "Swiftmend Snipe/Recycle", "Swiftmend", false },
    [5] = { "Swiftmend Panic", "Swiftmend", false },
    [6] = { "LB Stack 3", "Lifebloom", false },
    [7] = { "LB Stack 2", "Lifebloom", false },
    [8] = { "LB Stack 1", "Lifebloom", false },
    [9] = { "Regrowth Panic", "Regrowth", false },
    [10] = { "Rejuv Panic", "Rejuvenation", false },
    [11] = { "Regrowth General", "Regrowth", false },
    [12] = { "Rejuv General", "Rejuvenation", false },
    [13] = { "LB Refresh OOC", "Lifebloom", false },
    [14] = { "LB Stack OOC", "Lifebloom", false }
}
local emptyRaidCache2 = {}

local function raidHealSet2(friend)
    local data = jungle.unitCache[friend]
    if not data or UnitIsDeadOrGhost(friend) then return emptyRaidCache2 end

    -- STRICT FILTER: Non-Tanks
    if data.isTank then 
        return emptyRaidCache2 
    end

    local hp = data.currLife
    local inCombat = data.isInCombat
    local isPrio = jungle.isPriority(friend)
    
    -- Auras
    local hasRejuv     = jungle.unitCacheBuff(friend, 'Rejuvenation', '_PLAYER')
    local hasRegrowth  = jungle.unitCacheBuff(friend, 'Regrowth', '_PLAYER')
    local hasLifebloom = jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER')
    local hasNS        = jungle.unitCacheBuff("player", "Nature's Swiftness", '_PLAYER')
    
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

    local healingTouchReady = jungle.ReadyCastSpell('Healing Touch', friend)
    raidHealCache2[1][3] = (hp <= 0.3 and healingTouchReady and jungle.IsSpellReadyIgnoreGCD("Nature's Swiftness") and not hasNS and data.isInCombat)
    raidHealCache2[2][3] = (healingTouchReady and hasNS)
    raidHealCache2[3][3] = (inCombat and hasLifebloom and lbExpiring and (isPrio or hp <= 0.80) and jungle.ReadyCastSpell('Lifebloom', friend))
    local swiftmendReady = inCombat and jungle.IsSpellReadyIgnoreGCD("Swiftmend")
    raidHealCache2[4][3] = (swiftmendReady and hp <= 0.90 and ((hasRegrowthAny and not hasRegrowth) or (hasRejuvAny and not hasRejuv) or (hasRegrowth and not jungle.unitCacheBuff(friend, 'Regrowth', '_PLAYER', 5)) or (hasRejuv and not jungle.unitCacheBuff(friend, 'Rejuvenation', '_PLAYER', 5))))
    raidHealCache2[5][3] = (swiftmendReady and ( (hp <= 0.60 and hp > 0.40) or (hp <= 0.40 and not jungle.IsSpellReadyIgnoreGCD("Nature's Swiftness")) ) and (hasRegrowth or hasRejuv))
    raidHealCache2[6][3] = (inCombat and (hp <= 0.80 or isPrio) and lbCount == 2 and jungle.ReadyCastSpell('Lifebloom', friend))
    raidHealCache2[7][3] = (inCombat and (hp <= 0.80 or isPrio) and lbCount == 1 and jungle.ReadyCastSpell('Lifebloom', friend))
    raidHealCache2[8][3] = (inCombat and (hp <= 0.80 or isPrio) and not hasLifebloom and jungle.ReadyCastSpell('Lifebloom', friend))
    local canHardcast = inCombat and GetUnitSpeed('player') == 0
    raidHealCache2[9][3] = (canHardcast and ( (hp <= 0.40 and noHots) or (hp <= 0.60 and isPrio) ) and jungle.ReadyCastSpell('Regrowth', friend))
    raidHealCache2[10][3] = (inCombat and ( (hp <= 0.40 and noHots) or (hp <= 0.60 and isPrio) ) and jungle.ReadyCastSpell('Rejuvenation', friend))
    raidHealCache2[11][3] = (canHardcast and ( hp <= 0.40 or (hp <= 0.60 and isPrio) ) and jungle.ReadyCastSpell('Regrowth', friend))
    raidHealCache2[12][3] = (inCombat and not hasRejuv and ( hp <= 0.40 or isPrio ) and jungle.ReadyCastSpell('Rejuvenation', friend))
    raidHealCache2[13][3] = (not inCombat and hasLifebloom and lbExpiring and hp < 1.0 and jungle.ReadyCastSpell('Lifebloom', friend))
    raidHealCache2[14][3] = (not inCombat and lbCount < 3 and hp < 1.0 and jungle.ReadyCastSpell('Lifebloom', friend))

    return raidHealCache2
end
jungle.raidHealSet2 = raidHealSet2

local Jungle, jungle = ...

-- ----------------------------------------------------------------------------
-- UNIVERSAL V3: The "God Mode" Routine
-- Combines Tank Safety (Thread 1) + Raid Efficiency (Thread 4) + Snipe Logic
-- ----------------------------------------------------------------------------
local Jungle, jungle = ...

local univHealCacheV5 = {
    [1] = { "NS Emergency", "Nature's Swiftness", false },
    [2] = { "NS Cast", "Healing Touch", false },
    [3] = { "Swiftmend Panic", "Swiftmend", false },
    [4] = { "LB Tank Safety", "Lifebloom", false, "PROTECT_BLOOM" },
    [5] = { "Urgent Rejuv", "Rejuvenation", false },
    [6] = { "Urgent LB Start", "Lifebloom", false },
    [7] = { "LB Tank Start", "Lifebloom", false, "PROTECT_BLOOM" },
    [8] = { "Regrowth Tank", "Regrowth", false },
    [9] = { "LB Tank Stack", "Lifebloom", false, "PROTECT_BLOOM" },
    [10] = { "Rejuv Tank", "Rejuvenation", false },
    [11] = { "Swiftmend Snipe", "Swiftmend", false },
    [12] = { "Regrowth Raid", "Regrowth", false },
    [13] = { "LB Stack 3", "Lifebloom", false },
    [14] = { "Rejuv Raid", "Rejuvenation", false },
    [15] = { "LB Stack 2", "Lifebloom", false },
    [16] = { "LB Refresh 3", "Lifebloom", false },
    [17] = { "LB Start Filler", "Lifebloom", false },
    [18] = { "LB OOC Tank", "Lifebloom", false },
    [19] = { "LB OOC Raid", "Lifebloom", false }
}
local emptyUnivV5Cache = {}

local function universalHealSetV5(friend)
    local data = jungle.unitCache[friend]
    if not data or UnitIsDeadOrGhost(friend) then return emptyUnivV5Cache end

    -- 1. CONTEXT ANALYSIS
    local hp = data.currLife
    local inCombat = data.isInCombat
    local isTank = data.isTank 
    local isMoving = (GetUnitSpeed('player') > 0)
    
    local rawIsTanking = jungle.isTanking(friend)
    local totIsTanking = UnitIsUnit(friend .. "targettarget", friend)
    local isActiveTank = isTank and inCombat and (rawIsTanking or totIsTanking)
    
    -- 2. AURA SCANNING
    local hasRejuv      = jungle.unitCacheBuff(friend, 'Rejuvenation', '_PLAYER')
    local hasRegrowth   = jungle.unitCacheBuff(friend, 'Regrowth', '_PLAYER')
    local hasLifebloom  = jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER')
    local hasNS         = jungle.unitCacheBuff("player", "Nature's Swiftness", '_PLAYER')
    
    local hasRegAny = jungle.unitCacheBuff(friend, 'Regrowth')
    local hasRejAny = jungle.unitCacheBuff(friend, 'Rejuvenation')

    -- 3. ROBUST LIFEBLOOM COUNTING
    local lbExpireLimit = 1.5
    if jungle.isCasting('player', 2,'Regrowth') then lbExpireLimit = 1.8 end
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
    univHealCacheV5[1][3] = (inCombat and not hasNS and jungle.IsSpellReadyIgnoreGCD("NS") and ((isActiveTank and hp <= 0.40) or (hp <= 0.35)) and (not jungle.IsSpellReadyIgnoreGCD("Swiftmend") or not (hasRegrowthAny or hasRejuvAny)))
    univHealCacheV5[2][3] = (inCombat and jungle.ReadyCastSpell('Healing Touch', friend) and hasNS and ((isActiveTank and hp <= 0.40) or (hp <= 0.35)))
    univHealCacheV5[3][3] = (inCombat and jungle.IsSpellReadyIgnoreGCD("Swiftmend") and ((isActiveTank and hp <= 0.50) or (hp <= 0.40)) and (hasRegrowthAny or hasRejuvAny))
    univHealCacheV5[4][3] = (isActiveTank and hasLifebloom and lbExpiring and jungle.ReadyCastSpell('Lifebloom', friend))
    univHealCacheV5[5][3] = (inCombat and not isActiveTank and hp < 0.65 and not hasRejuv and jungle.ReadyCastSpell('Rejuvenation', friend))
    univHealCacheV5[6][3] = (inCombat and not isActiveTank and hp < 0.65 and lbCount == 0 and jungle.ReadyCastSpell('Lifebloom', friend))
    univHealCacheV5[7][3] = (isActiveTank and not hasLifebloom and jungle.ReadyCastSpell('Lifebloom', friend))
    univHealCacheV5[8][3] = (isActiveTank and not isMoving and jungle.bloomWindow("Regrowth") and ((not hasRegrowth and hp < 0.90) or hp < 0.60) and jungle.ReadyCastSpell('Regrowth', friend) and not jungle.isCasting('player', 0.5,'Regrowth'))
    univHealCacheV5[9][3] = (isActiveTank and lbCount < 3 and jungle.ReadyCastSpell('Lifebloom', friend))
    univHealCacheV5[10][3] = (isActiveTank and not hasRejuv and hp < 0.90 and jungle.ReadyCastSpell('Rejuvenation', friend))
    univHealCacheV5[11][3] = (inCombat and jungle.IsSpellReadyIgnoreGCD("Swiftmend") and not isActiveTank and hp <= 0.80 and ((hasRegrowthAny and not hasRegrowth) or (hasRejuvAny and not hasRejuv)))
    univHealCacheV5[12][3] = (inCombat and not isMoving and not hasRegrowth and not isActiveTank and hp <= 0.80 and jungle.bloomWindow("Regrowth") and jungle.ReadyCastSpell('Regrowth', friend) and not jungle.isCasting('player', 0.5,'Regrowth'))
    univHealCacheV5[13][3] = (jungle.ReadyCastSpell('Lifebloom', friend) and lbCount == 2 and hp < 0.60)
    univHealCacheV5[14][3] = (inCombat and not hasRejuv and not isActiveTank and hp <= 0.80 and jungle.ReadyCastSpell('Rejuvenation', friend))
    univHealCacheV5[15][3] = (jungle.ReadyCastSpell('Lifebloom', friend) and lbCount == 1 and hp <= 0.80)
    univHealCacheV5[16][3] = (jungle.ReadyCastSpell('Lifebloom', friend) and lbExpiring and hp < 0.80)
    univHealCacheV5[17][3] = (jungle.ReadyCastSpell('Lifebloom', friend) and lbCount == 0 and hp < 0.90)
    univHealCacheV5[18][3] = (not inCombat and isTank and (not hasLifebloom or lbExpiring) and jungle.ReadyCastSpell('Lifebloom', friend))
    univHealCacheV5[19][3] = (not inCombat and not isTank and hp < 0.90 and not hasLifebloom and jungle.ReadyCastSpell('Lifebloom', friend))

    return univHealCacheV5
end
jungle.universalHealSetV5 = universalHealSetV5

local emptyUnivV6Cache = {}

local function stopIfFull(t)
    return jungle.LifePercent(t) >= 0.95
end

local univHealCacheV6 = {
    [1] = { "NS Emergency", "Nature's Swiftness", false },
    [2] = { "NS Cast", "Healing Touch", false },
    [3] = { "Swiftmend Panic", "Swiftmend", false },
    [4] = { "LB Tank Safety", "Lifebloom", false, "PROTECT_BLOOM" },

    [5] = { "LB Boss Tank Start", "Lifebloom", false, "PROTECT_BLOOM" },
    [6] = { "Regrowth Boss Tank", "Regrowth", false, nil },
    [7] = { "LB Boss Tank Stack", "Lifebloom", false, "PROTECT_BLOOM" },
    [8] = { "Rejuv Boss Tank", "Rejuvenation", false },

    [9] = { "Urgent Rejuv", "Rejuvenation", false },
    [10] = { "Urgent LB Start", "Lifebloom", false },

    [11] = { "LB Trash Tank Start", "Lifebloom", false, "PROTECT_BLOOM" },
    [12] = { "Regrowth Trash Tank", "Regrowth", false, nil },
    [13] = { "LB Trash Tank Stack", "Lifebloom", false, "PROTECT_BLOOM" },
    [14] = { "Rejuv Trash Tank", "Rejuvenation", false },

    [15] = { "Swiftmend Snipe", "Swiftmend", false },
    [16] = { "Regrowth Tank Backup", "Regrowth", false, nil },
    [17] = { "Regrowth Raid", "Regrowth", false, stopIfFull },
    [18] = { "LB Stack 3", "Lifebloom", false },
    [19] = { "Rejuv Raid", "Rejuvenation", false },
    [20] = { "LB Stack 2", "Lifebloom", false },
    [21] = { "LB Refresh 3", "Lifebloom", false },
    [22] = { "LB Start Filler", "Lifebloom", false },

    [23] = { "LB OOC Tank (Refresh)", "Lifebloom", false },
    [24] = { "LB OOC Tank (Stack 3)", "Lifebloom", false },
    [25] = { "LB OOC Tank (Stack 2)", "Lifebloom", false },
    [26] = { "LB OOC Tank (Stack 1)", "Lifebloom", false },
    [27] = { "LB OOC Raid", "Lifebloom", false },
}

local function universalHealSetV6(friend)
    local data = jungle.unitCache[friend]
    if not data or UnitIsDeadOrGhost(friend) then return emptyUnivV6Cache end

    -- 1. CONTEXT ANALYSIS
    local hp = data.currLife
    local inCombat = data.isInCombat
    local isTank = data.isTank
    local isMoving = (GetUnitSpeed('player') > 0)
    
    local hasTankThreat = (data.threatStatus == 3 or data.threatStatus == 2)
    local isActiveTank = false
    if isTank and inCombat then
        isActiveTank = hasTankThreat or UnitIsUnit(friend .. "targettarget", friend)
    end

    local isBoss = false
    if isActiveTank then
        local tLevel = UnitLevel(friend .. "target") or 1
        local tClass = UnitClassification(friend .. "target") or "normal"
        isBoss = (tLevel == -1 or tClass == "worldboss" or tClass == "boss")
    end
    
    local isTankingBoss  = isActiveTank and isBoss
    local isTankingTrash = isActiveTank and not isBoss
    
    -- 2. AURA SCANNING
    local hasRejuv      = jungle.unitCacheBuff(friend, 'Rejuvenation', '_PLAYER')
    local hasRegrowth   = jungle.unitCacheBuff(friend, 'Regrowth', '_PLAYER')
    local hasLifebloom  = jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER')
    local hasNS         = jungle.unitCacheBuff("player", "Nature's Swiftness", '_PLAYER')
    local knowsLifebloom = IsSpellLearned('Lifebloom')

    local safetyRow = univHealCacheV6[4]
    if knowsLifebloom then
        safetyRow[1] = "LB Tank Safety"
        safetyRow[2] = "Lifebloom"
        safetyRow[4] = "PROTECT_BLOOM"
    else
        safetyRow[1] = "Regrowth (No Lifebloom)"
        safetyRow[2] = "Regrowth"
        safetyRow[4] = stopIfFull
    end
    
    local hasRegAny = jungle.unitCacheBuff(friend, 'Regrowth')
    local hasRejAny = jungle.unitCacheBuff(friend, 'Rejuvenation')

    -- 3. ROBUST LIFEBLOOM COUNTING
    local lbExpireLimit = 1.5
    if jungle.isCasting('player', 2,'Regrowth') then lbExpireLimit = 1.8 end
    local lbCount = 0
    local lbExpiring = false
    
    if hasLifebloom then
        if jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', nil, 3) then lbCount = 3
        elseif jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', nil, 2) then lbCount = 2
        elseif jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', nil, 1) then lbCount = 1
        else lbCount = 3 end
        lbExpiring = not jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', lbExpireLimit)
    end

    -- [REGROWTH TANK LOGIC]
    local safeBloom = jungle.bloomWindow("Regrowth")
    local wantRegTank = false
    if isActiveTank and not isMoving and not jungle.isCasting('player', 0.5, 'Regrowth') and jungle.ReadyCastSpell('Regrowth', friend) then
        if not hasRegrowth and hp >= 0.90 and safeBloom then
            wantRegTank = true 
        elseif not hasRegrowth and hp < 0.90 then
            wantRegTank = true 
        elseif hp < 0.80 and safeBloom then
            wantRegTank = true 
        end
    end

    -- 5. PURE HEALING LOGIC
    -- Before Lifebloom is learned, Regrowth supplies the missing direct healing.
    -- Recast it through the existing HoT when health pressure is high enough.
    local useRegrowthWithoutLifebloom = not knowsLifebloom
        and not isMoving
        and not jungle.isCasting('player', 0.5, 'Regrowth')
        and jungle.ReadyCastSpell('Regrowth', friend)
        and (
            (inCombat and ((isTank and hp <= 0.85) or (not isTank and hp <= 0.65)))
            or (not inCombat and hp <= 0.80)
        )

    -- These readiness results cannot change during one synchronous evaluation
    -- for this friend. Reuse them across rows instead of repeating C API chains.
    local lifebloomReady = jungle.ReadyCastSpell('Lifebloom', friend)
    local swiftmendReady = inCombat and jungle.IsSpellReadyIgnoreGCD("Swiftmend")

    univHealCacheV6[1][3] = (inCombat and not hasNS and jungle.IsSpellReadyIgnoreGCD("Nature's Swiftness") and ((isActiveTank and hp <= 0.40) or (hp <= 0.35)) and (not swiftmendReady or not (hasRegAny or hasRejAny)))
    univHealCacheV6[2][3] = (inCombat and jungle.ReadyCastSpell('Healing Touch', friend) and hasNS and ((isActiveTank and hp <= 0.40) or (hp <= 0.35)))
    univHealCacheV6[3][3] = (inCombat and swiftmendReady and ((isActiveTank and hp <= 0.50) or (hp <= 0.40)) and (hasRegAny or hasRejAny))
    univHealCacheV6[4][3] = knowsLifebloom
        and (isActiveTank and hasLifebloom and lbExpiring and lifebloomReady)
        or useRegrowthWithoutLifebloom
    univHealCacheV6[5][3] = (isTankingBoss and not hasLifebloom and lifebloomReady)
    univHealCacheV6[6][3] = (isTankingBoss and wantRegTank)
    univHealCacheV6[7][3] = (isTankingBoss and lbCount < 3 and lifebloomReady)
    univHealCacheV6[8][3] = (isTankingBoss and not hasRejuv and hp < 0.90 and jungle.ReadyCastSpell('Rejuvenation', friend))
    univHealCacheV6[9][3] = (inCombat and not isActiveTank and hp < 0.65 and not hasRejuv and jungle.ReadyCastSpell('Rejuvenation', friend))
    univHealCacheV6[10][3] = (inCombat and not isActiveTank and hp < 0.65 and lbCount == 0 and lifebloomReady)
    univHealCacheV6[11][3] = (isTankingTrash and not hasLifebloom and lifebloomReady)
    univHealCacheV6[12][3] = (isTankingTrash and wantRegTank)
    univHealCacheV6[13][3] = (isTankingTrash and lbCount < 3 and lifebloomReady)
    univHealCacheV6[14][3] = (isTankingTrash and not hasRejuv and hp < 0.90 and jungle.ReadyCastSpell('Rejuvenation', friend))
    univHealCacheV6[15][3] = (inCombat and swiftmendReady and not isActiveTank and hp <= 0.80 and ((hasRegAny and not hasRegrowth) or (hasRejAny and not hasRejuv)))
    univHealCacheV6[16][3] = (inCombat and not isMoving and not hasRegrowth and isTank and hp <= 0.80 and jungle.bloomWindow("Regrowth") and jungle.ReadyCastSpell('Regrowth', friend) and not jungle.isCasting('player', 0.5,'Regrowth'))
    univHealCacheV6[17][3] = (inCombat and not isMoving and not hasRegrowth and not isTank and hp <= 0.80 and jungle.bloomWindow("Regrowth") and jungle.ReadyCastSpell('Regrowth', friend) and not jungle.isCasting('player', 0.5,'Regrowth'))
    univHealCacheV6[18][3] = (lifebloomReady and lbCount == 2 and hp < 0.60 and not isActiveTank)
    univHealCacheV6[19][3] = (inCombat and not hasRejuv and not isActiveTank and hp <= 0.80 and jungle.ReadyCastSpell('Rejuvenation', friend))
    univHealCacheV6[20][3] = (lifebloomReady and lbCount == 1 and hp <= 0.80 and not isActiveTank)
    univHealCacheV6[21][3] = (lifebloomReady and lbExpiring and hp < 0.80 and not isActiveTank)
    univHealCacheV6[22][3] = (lifebloomReady and lbCount == 0 and hp < 0.90 and not isActiveTank)
    univHealCacheV6[23][3] = (not inCombat and isTank and lbCount == 3 and lbExpiring and lifebloomReady)
    univHealCacheV6[24][3] = (not inCombat and isTank and lbCount == 2 and lifebloomReady)
    univHealCacheV6[25][3] = (not inCombat and isTank and lbCount == 1 and lifebloomReady)
    univHealCacheV6[26][3] = (not inCombat and isTank and lbCount == 0 and lifebloomReady)
    univHealCacheV6[27][3] = (not inCombat and not isTank and hp < 0.90 and not hasLifebloom and lifebloomReady)

    return univHealCacheV6
end

jungle.universalHealSetV6 = universalHealSetV6	

-- Initialize the throttle table
jungle.rejuvTimer = jungle.rejuvTimer or {}

local emptyUnivPvPCache = {}
local univPvPCache = {
    [1] = { "NS Panic",    "Nature's Swiftness", false },
    [2] = { "NS HT",       "Healing Touch",      false },
    [3] = { "Swiftmend",   "Swiftmend",          false },
    [4] = { "LB Critical Refresh", "Lifebloom", false },
    [5] = { "Regrowth (SPAM)", "Regrowth", false },
    [6] = { "LB Force Stack",      "Lifebloom", false },
    [7] = { "Rejuv Buffer", "Rejuvenation", false, nil },
    [8] = { "LB Refresh (Normal)", "Lifebloom",    false },
    [9] = { "Regrowth (HOT)",      "Regrowth",      false },
    [10] = { "Rejuv (General)",     "Rejuvenation",  false },
    [11] = { "LB Stack 1 & 2", "Lifebloom", false },
    [12] = { "LB Stack 3",     "Lifebloom", false },
    [13] = { "Swiftmend Mobile", "Swiftmend", false },
}
local pvpRejuvCallbacks = {}

local function GetPvPRejuvCallback(friend)
    local callback = pvpRejuvCallbacks[friend]
    if not callback then
        callback = function()
            jungle.rejuvTimer[friend] = GetTime()
        end
        pvpRejuvCallbacks[friend] = callback
    end
    return callback
end

local function universalPvPMatrix(friend)
    local data = jungle.unitCache[friend]
    if not data or UnitIsDeadOrGhost(friend) then return emptyUnivPvPCache end

    -- 1. CONTEXT & THREAT DETECTION
    local hp           = data.currLife
    local inCombat     = data.isInCombat
    local now          = GetTime()
    local isMoving     = (GetUnitSpeed('player') > 0)
    local pressure     = jungle.targetedByCount(friend)
    local isFocused    = (pressure > 0)
    local isRegrowthSafe = not isMoving and not jungle.isCasting('player', 0.5)
    
    -- PRIMARY TARGET DETECTION (Gladiator Logic)
    -- Is this person the most likely to die right now?
    local isPrimaryTarget = (hp < 0.50) or (pressure >= 2) or (isFocused and hp < 0.75)

    -- 2. AURA & API CACHING
    local hasRejuv      = jungle.unitCacheBuff(friend, 'Rejuvenation', '_PLAYER')
    local hasRegrowth   = jungle.unitCacheBuff(friend, 'Regrowth', '_PLAYER')
    local hasLifebloom  = jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER')
    local hasNS         = jungle.unitCacheBuff("player", "Nature's Swiftness", '_PLAYER')
    local smOnCD        = not jungle.IsSpellReadyIgnoreGCD("Swiftmend")
    
    local hasRegAny = jungle.unitCacheBuff(friend, 'Regrowth')
    local hasRejAny = jungle.unitCacheBuff(friend, 'Rejuvenation')

    -- 3. LIFEBLOOM DURATION & STACKS
    local lbExpiring = hasLifebloom and not jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', 1.5)
    local lbCount = 0
    if hasLifebloom then
        if jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', nil, 3) then lbCount = 3
        elseif jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', nil, 2) then lbCount = 2
        else lbCount = 1 end
    end

    -- 4. DYNAMIC TRIGGERS
    local isCriticalLB = lbExpiring and (hp < 0.65 or pressure >= 2)
    local lastRejuv = jungle.rejuvTimer[friend] or 0
    local needsBuffer = (isFocused or hp < 0.60) and (now - lastRejuv > 3.0)

    local needsDirectHPS = isRegrowthSafe and (pressure >= 2 or hp < 0.75)

    univPvPCache[7][4] = GetPvPRejuvCallback(friend)
    
    univPvPCache[1][3] = (inCombat and not hasNS and jungle.IsSpellReadyIgnoreGCD("Nature's Swiftness") and hp <= 0.30)
    univPvPCache[2][3] = (hasNS and hp <= 0.35)
    univPvPCache[3][3] = (hp <= 0.55 and (hasRegAny or hasRejAny) and not smOnCD)
    univPvPCache[4][3] = (isCriticalLB)
    univPvPCache[5][3] = (needsDirectHPS and jungle.ReadyCastSpell('Regrowth', friend))
    univPvPCache[6][3] = (isPrimaryTarget and lbCount < 3 and not lbExpiring)
    univPvPCache[7][3] = (not hasRejuv and needsBuffer)
    univPvPCache[8][3] = (lbExpiring and not isCriticalLB)
    univPvPCache[9][3] = (isRegrowthSafe and not hasRegrowth and (hp < 0.90 or isFocused))
    univPvPCache[10][3] = (not hasRejuv and (hp < 0.92 or pressure > 0))
    univPvPCache[11][3] = (not isPrimaryTarget and lbCount < 2 and (hp < 0.98 or inCombat))
    univPvPCache[12][3] = (not isPrimaryTarget and lbCount == 2 and (isFocused or hp < 0.80))
    univPvPCache[13][3] = (isMoving and hp < 0.70 and not smOnCD and (hasRegAny or hasRejAny))

    return univPvPCache
end

jungle.universalPvPMatrix = universalPvPMatrix

-- [UPDATED] The Custom Test Rotation with Metadata Stopcast
jungle.testStopcastSet = function(_target)
    return {
        -- Priority 1: Cast Regrowth for the HoT Buff. 
        -- Condition: Ready to cast AND target is missing the buff.
        -- Metadata: nil (We want the buff to land regardless of health).
        { 
            _target, 
            "Regrowth", 
            jungle.ReadyCastSpell("Regrowth", _target) and not jungle.unitCacheBuff(_target, 'Regrowth', true), 
            nil 
        },
        
        -- Priority 2: Cast Regrowth as a Direct Heal.
        -- Condition: Ready to cast AND target already has the buff.
        -- Metadata: Abort if target's predicted life exceeds 95%.
        { 
            _target, 
            "Regrowth", 
            jungle.ReadyCastSpell("Regrowth", _target) and jungle.unitCacheBuff(_target, 'Regrowth', true), 
			function(t) 
					-- Stopcasting logic: Return TRUE to ABORT.
					-- We abort if the buff is NOT found (you manually removed it).
					return not jungle.unitCacheBuff(t, 'Regrowth', true) 
				end
        }
    }
end

-- Helper function to specifically calculate the fastest Druid interrupt
local function druid_interrupt(target)
    if not target or not UnitExists(target) or not UnitCanAttack("player", target) then return {} end

    -- 1. CONTEXT & STATE DETECTION
    local isCasting = UnitCastingInfo(target) ~= nil
    local isChanneling = UnitChannelInfo(target) ~= nil
    local needsInterrupt = isCasting or isChanneling
    
    -- If they aren't casting, short-circuit immediately to save CPU
    if not needsInterrupt then return {} end

    -- 2. RESOURCES & COOLDOWNS
    local cp = GetComboPoints("player", target)
    local rage = UnitPower("player", 1)
    local inBear = jungle.Buff("Dire Bear Form", "player") or jungle.Buff("Bear Form", "player")
    local hasFeralCharge = IsSpellIDKnown(16979)
    local hasFullFuror = IsSpellIDKnown(17061)

    -- Smart CD & Range Checks for Shifting Logic
    local hasBash = IsSpellLearned("Bash")
    local bashReady = hasBash and not jungle.SpellOnCD("Bash")
    local bashRange = hasBash and IsSpellInRange("Bash", target)
    local inBashRange = (bashRange == 1) or (bashRange == nil and jungle.inMeleeRange(target))
    
    local chargeReady = hasFeralCharge and not jungle.SpellOnCD("Feral Charge")
    local chargeRange = hasFeralCharge and IsSpellInRange("Feral Charge", target)
    -- If IsSpellInRange returns nil, we fallback to a rough 28 yard check
    local inChargeRange = (chargeRange == 1) or (chargeRange == nil and CheckInteractDistance(target, 4))
    
    -- Only pre-shift for Bear interrupts when 5/5 Furor can provide the needed Rage.
    local canShiftBear = hasFullFuror and ((bashReady and inBashRange) or (chargeReady and inChargeRange)) and not inBear

    -- 3. THE INTERRUPT PRIORITY STACK
    -- Format expected by Engine: { "Log Name", "Spell String", BooleanCondition, "Metadata" }
    return {
        -- PRIORITY 1: INSTANT CASTS (Current Form)
        [1] = { "Bear Bash",     "Bash",         (hasBash and inBear and rage >= 10 and jungle.ReadyCastSpell("Bash", target)), "INTERRUPT" },
        [2] = { "Bear Charge",   "Feral Charge", (hasFeralCharge and jungle.ReadyCastSpell("Feral Charge", target)), "INTERRUPT" },
        [3] = { "Cat Maim",      "Maim",         (jungle.ReadyCastSpell("Maim", target) and cp > 0), "INTERRUPT" },

        -- PRIORITY 2: FORM SHIFTING (Calculated Preparation)
        -- If we need Bear prep, only shift when full Furor can fund the interrupt.
        [4] = { "Shift to Bear", "Dire Bear Form", (canShiftBear), "INTERRUPT_PREP" }
    }
end
jungle.druid_interrupt = druid_interrupt
