local Jungle, jungle = ...
jungle.RoutineAllows = jungle.RoutineAllows or function() return true end
jungle.GetRoutineThread = jungle.GetRoutineThread or function() return jungle.Engine and jungle.Engine.activeThread end
local unitCache = jungle.unitCache
local IsTotemUnit = jungle.IsTotemUnit
local IsEnemyNameplateEligibleForAoE = jungle.IsEnemyNameplateEligibleForAoE
-- Preferences only gate existing branches. Unconfigured threads retain their
-- original behavior; Sunder initial/stack share one switch in threads 2 and 3.
local warriorOptionActions = {demo="Demoralizing Shout", thunderClap="Thunder Clap", sunderInitial="Sunder Armor", sunderStack="Sunder Armor", sweeping="Sweeping Strikes"}

function jungle.WarriorRoutineOptionEnabled(kind)
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    local behavior = jungle.GetWarriorRoutineBehavior()
    local entry = jungle.RoutineContext
    if entry then
        local action = warriorOptionActions[kind]
        if action and not (not routineActions or routineActions[action] ~= false) then return false end
        local value = entry.options[kind]
        if value ~= nil then return value end
    end
    local key = behavior.optionKeys[kind]
    if not key or not jungle.Options then return true end
    return jungle.Options:AllowsForThread(key, behavior.legacyPolicy, "WARRIOR")
end

-- Shared DPS shout choice; ownership comes from the player's categorized aura cache.
-- Preserve our active shout; otherwise complement another warrior or use the saved default.
-- Build/API evidence and live checks: docs/WARRIOR_SHOUTS.md.
function jungle.GetWarriorDpsShout(refreshWindow)
    if jungle.unitCacheBuff('player', 'Commanding Shout', 'player') then
        return 'Commanding Shout', not jungle.unitCacheBuff('player', 'Commanding Shout', 'player', refreshWindow)
    elseif jungle.unitCacheBuff('player', 'Battle Shout', 'player') then
        return 'Battle Shout', not jungle.unitCacheBuff('player', 'Battle Shout', 'player', refreshWindow)
    elseif jungle.unitCacheBuff('player', 'Battle Shout') then
        -- With both supplied externally, wait instead of refreshing someone else's buff.
        return 'Commanding Shout', not jungle.unitCacheBuff('player', 'Commanding Shout')
    elseif jungle.unitCacheBuff('player', 'Commanding Shout') then
        return 'Battle Shout', true
    end
    local defaultShout = jungle.Options and jungle.Options:GetWarriorDefaultShout() or 'Battle Shout'
    return defaultShout, true
end

local GetNameplateUnitToken = jungle.GetNameplateUnitToken or function(nameplate, index)
    local unit = nameplate and (nameplate.namePlateUnitToken or nameplate.unitToken or nameplate.unit or nameplate.displayedUnit)
    local unitFrame = nameplate and nameplate.UnitFrame
    if not unit and unitFrame then
        unit = unitFrame.unit or unitFrame.unitToken or unitFrame.displayedUnit
    end
    if not unit and index then
        unit = "nameplate" .. index
    end
    return unit and UnitExists(unit) and unit or nil
end

-- ============================================================================
-- EQUIPMENT SCANNER UTILITIES
-- Shared helpers + three scanner functions:
--   jungle.GetBest2HWeapon()  - highest DPS two-hand weapon (bags + slot 16)
--   jungle.GetBest1HWeapon()  - highest DPS one-hand weapon (bags + slots 16/17)
--   jungle.GetBestShield()    - highest armor shield (bags + slot 17)
-- All return item name string or nil.
-- ============================================================================
do
    local scanTooltip

    local function EnsureScanTooltip()
        if not scanTooltip then
            scanTooltip = CreateFrame("GameTooltip", "OliaEquipScanTip", nil, "GameTooltipTemplate")
        end
        scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
        return scanTooltip
    end

    -- Safe container wrappers (Anniversary uses C_Container)
    local function SafeGetNumSlots(bag)
        if C_Container and C_Container.GetContainerNumSlots then
            return C_Container.GetContainerNumSlots(bag)
        elseif GetContainerNumSlots then
            return GetContainerNumSlots(bag)
        end
        return 0
    end

    local function SafeGetItemLink(bag, slot)
        if C_Container and C_Container.GetContainerItemLink then
            return C_Container.GetContainerItemLink(bag, slot)
        elseif GetContainerItemLink then
            return GetContainerItemLink(bag, slot)
        end
        return nil
    end

    -- Parse DPS from tooltip lines. Returns number or nil.
    local function ParseDPS(tip, numLines)
        for i = 1, numLines do
            local region = _G[tip:GetName() .. "TextLeft" .. i]
            if region then
                local text = region:GetText()
                if text then
                    local dps = text:match("%((%d+%.?%d*)%s+damage per second%)")
                    if not dps then
                        dps = text:match("(%d+%.?%d*)%s+[Dd][Pp][Ss]")
                    end
                    if dps then return tonumber(dps) end
                end
            end
        end
        return nil
    end

    -- Parse average flat damage from tooltip lines. Returns number or nil.
    local function ParseDamage(tip, numLines)
        for i = 1, numLines do
            local region = _G[tip:GetName() .. "TextLeft" .. i]
            if region then
                local text = region:GetText()
                if text then
                    local minDmg, maxDmg = text:match("(%d+)%s*-%s*(%d+)%s+.-[Dd]amage")
                    if not minDmg then
                        minDmg, maxDmg = text:match("(%d+)%s*-%s*(%d+)")
                        if minDmg and not (text:find("[Dd]amage") or text:find("[Pp]hysical") or text:find("[Ss]hadow") or text:find("[Ff]ire") or text:find("[Nn]ature") or text:find("[Ff]rost") or text:find("[Aa]rcane") or text:find("[Dd]am") or text:find("[Uu]ron")) then
                            minDmg, maxDmg = nil, nil
                        end
                    end
                    if minDmg and maxDmg then
                        return (tonumber(minDmg) + tonumber(maxDmg)) / 2
                    end
                end
            end
        end
        return nil
    end

    -- Parse weapon speed from tooltip lines. Returns number or nil.
    local function ParseSpeed(tip, numLines)
        for i = 1, numLines do
            for _, side in ipairs({"TextLeft", "TextRight"}) do
                local region = _G[tip:GetName() .. side .. i]
                if region then
                    local text = region:GetText()
                    if text then
                        -- Check English "Speed 2.60" or Russian "Скорость 2.60"
                        local speed = text:match("[Ss]peed%s+(%d+%.?%d*)")
                        if not speed then
                            speed = text:match("Скорость%s+(%d+%.?%d*)")
                        end
                        if speed then return tonumber(speed) end
                    end
                end
            end
        end
        return nil
    end

    -- Parse Armor value from tooltip lines. Returns number or nil.
    -- Matches: "1234 Armor" (left-aligned text)
    local function ParseArmor(tip, numLines)
        for i = 1, numLines do
            local region = _G[tip:GetName() .. "TextLeft" .. i]
            if region then
                local text = region:GetText()
                if text then
                    local armor = text:match("^(%d+) Armor$")
                    if armor then return tonumber(armor) end
                end
            end
        end
        return nil
    end

    -- Scan bags for items matching equipLoc, score them with scoreFn.
    -- Returns bestName, bestScore
    local function ScanBags(tip, equipLocs, scoreFn)
        local bestName, bestScore = nil, 0
        for bag = 0, 4 do
            local numSlots = SafeGetNumSlots(bag)
            for slot = 1, numSlots do
                local itemLink = SafeGetItemLink(bag, slot)
                if itemLink then
                    local itemName, _, _, _, _, _, _, _, itemEquipLoc = GetItemInfo(itemLink)
                    if itemName and equipLocs[itemEquipLoc] then
                        tip:ClearLines()
                        tip:SetOwner(WorldFrame, "ANCHOR_NONE")
                        tip:SetBagItem(bag, slot)
                        local score = scoreFn(tip, tip:NumLines())
                        if score and score > bestScore then
                            bestScore = score
                            bestName = itemName
                        end
                    end
                end
            end
        end
        return bestName, bestScore
    end

    -- Scan an equipped inventory slot. Returns bestName, bestScore
    local function ScanEquipSlot(tip, invSlot, equipLocs, scoreFn, currentBest, currentScore)
        local eqLink = GetInventoryItemLink("player", invSlot)
        if eqLink then
            local itemName, _, _, _, _, _, _, _, itemEquipLoc = GetItemInfo(eqLink)
            if itemName and equipLocs[itemEquipLoc] then
                tip:ClearLines()
                tip:SetOwner(WorldFrame, "ANCHOR_NONE")
                tip:SetInventoryItem("player", invSlot)
                local score = scoreFn(tip, tip:NumLines())
                if score and score > currentScore then
                    return itemName, score
                end
            end
        end
        return currentBest, currentScore
    end

    -- ---- PUBLIC FUNCTIONS ----

    local EQUIPLOC_2H = { ["INVTYPE_2HWEAPON"] = true }
    local EQUIPLOC_1H = { ["INVTYPE_WEAPON"] = true, ["INVTYPE_WEAPONMAINHAND"] = true }
    local EQUIPLOC_SHIELD = { ["INVTYPE_SHIELD"] = true }
    local EQUIPLOC_1H_OH = { ["INVTYPE_WEAPON"] = true, ["INVTYPE_WEAPONOFFHAND"] = true }

    function jungle.GetBest2HWeapon()
        local tip = EnsureScanTooltip()
        local bestName, bestScore = ScanBags(tip, EQUIPLOC_2H, ParseDPS)
        bestName, bestScore = ScanEquipSlot(tip, 16, EQUIPLOC_2H, ParseDPS, bestName, bestScore)
        return bestName
    end

    function jungle.GetBest1HWeapon()
        local tip = EnsureScanTooltip()
        local bestName, bestScore = ScanBags(tip, EQUIPLOC_1H, ParseDPS)
        bestName, bestScore = ScanEquipSlot(tip, 16, EQUIPLOC_1H, ParseDPS, bestName, bestScore)
        bestName, bestScore = ScanEquipSlot(tip, 17, EQUIPLOC_1H, ParseDPS, bestName, bestScore)
        return bestName
    end

    function jungle.GetBestShield()
        local tip = EnsureScanTooltip()
        local bestName, bestScore = ScanBags(tip, EQUIPLOC_SHIELD, ParseArmor)
        bestName, bestScore = ScanEquipSlot(tip, 17, EQUIPLOC_SHIELD, ParseArmor, bestName, bestScore)
        return bestName
    end

    local lastScan = 0
    local cachedMH, cachedOH, cachedThird

    local function IsWeaponAvailable(itemName)
        if not itemName then return false end

        for bag = 0, 4 do
            local numSlots = SafeGetNumSlots(bag)
            for slot = 1, numSlots do
                local itemLink = SafeGetItemLink(bag, slot)
                if itemLink and GetItemInfo(itemLink) == itemName then
                    return true
                end
            end
        end

        for _, invSlot in ipairs({16, 17}) do
            local itemLink = GetInventoryItemLink("player", invSlot)
            if itemLink and GetItemInfo(itemLink) == itemName then
                return true
            end
        end

        return false
    end
    jungle.IsWeaponAvailable = IsWeaponAvailable

    function jungle.GetBestDWWeapons()
        local now = GetTime()
        local cachedWeaponsAvailable = (
            cachedMH
            and IsWeaponAvailable(cachedMH)
            and (not cachedOH or IsWeaponAvailable(cachedOH))
            and (not cachedThird or IsWeaponAvailable(cachedThird))
        )
        if now - lastScan < 2 and cachedWeaponsAvailable then
            return cachedMH, cachedOH, cachedThird
        end
        lastScan = now

        local tip = EnsureScanTooltip()
        local candidates = {}

        local function addCandidate(name, equipLoc, dpsVal, dmgVal, id)
            if name and dpsVal and dpsVal > 0 then
                table.insert(candidates, {
                    name = name,
                    equipLoc = equipLoc,
                    dps = dpsVal,
                    damage = dmgVal or 0,
                    id = id
                })
            end
        end

        -- Scan bags
        for bag = 0, 4 do
            local numSlots = SafeGetNumSlots(bag)
            for slot = 1, numSlots do
                local itemLink = SafeGetItemLink(bag, slot)
                if itemLink then
                    local itemName, _, _, _, _, _, _, _, itemEquipLoc = GetItemInfo(itemLink)
                    if itemName and (itemEquipLoc == "INVTYPE_WEAPON" or itemEquipLoc == "INVTYPE_WEAPONMAINHAND" or itemEquipLoc == "INVTYPE_WEAPONOFFHAND") then
                        tip:ClearLines()
                        tip:SetOwner(WorldFrame, "ANCHOR_NONE")
                        tip:SetBagItem(bag, slot)
                        local dpsVal = ParseDPS(tip, tip:NumLines())
                        local dmgVal = ParseDamage(tip, tip:NumLines())
                        if dpsVal then
                            addCandidate(itemName, itemEquipLoc, dpsVal, dmgVal, "bag_" .. bag .. "_" .. slot)
                        end
                    end
                end
            end
        end

        -- Scan equipped slots 16 and 17
        for _, invSlot in ipairs({16, 17}) do
            local eqLink = GetInventoryItemLink("player", invSlot)
            if eqLink then
                local itemName, _, _, _, _, _, _, _, itemEquipLoc = GetItemInfo(eqLink)
                if itemName and (itemEquipLoc == "INVTYPE_WEAPON" or itemEquipLoc == "INVTYPE_WEAPONMAINHAND" or itemEquipLoc == "INVTYPE_WEAPONOFFHAND") then
                    tip:ClearLines()
                    tip:SetOwner(WorldFrame, "ANCHOR_NONE")
                    tip:SetInventoryItem("player", invSlot)
                    local dpsVal = ParseDPS(tip, tip:NumLines())
                    local dmgVal = ParseDamage(tip, tip:NumLines())
                    if dpsVal then
                        addCandidate(itemName, itemEquipLoc, dpsVal, dmgVal, "equip_" .. invSlot)
                    end
                end
            end
        end

        -- 1. Find best MH: highest flat damage main hand or one hand weapon
        local bestMH = nil
        local maxDamage = -1
        for i = 1, #candidates do
            local A = candidates[i]
            if A.equipLoc == "INVTYPE_WEAPON" or A.equipLoc == "INVTYPE_WEAPONMAINHAND" then
                if A.damage > maxDamage then
                    maxDamage = A.damage
                    bestMH = A
                elseif A.damage == maxDamage then
                    -- Tie-breaker: if damage is identical (or both are 0), choose higher DPS
                    if not bestMH or A.dps > bestMH.dps then
                        bestMH = A
                    end
                end
            end
        end

        -- 2. Find best OH: highest DPS one hand or offhand weapon, excluding bestMH
        local bestOH = nil
        local maxOHDps = 0
        for i = 1, #candidates do
            local B = candidates[i]
            if not bestMH or B.id ~= bestMH.id then
                if B.equipLoc == "INVTYPE_WEAPON" or B.equipLoc == "INVTYPE_WEAPONOFFHAND" then
                    if B.dps > maxOHDps then
                        maxOHDps = B.dps
                        bestOH = B
                    end
                end
            end
        end

        -- 3. Optional: find 3rd one-hand weapon by dps, excluding bestMH and bestOH
        local bestThird = nil
        local maxThirdDps = 0
        for i = 1, #candidates do
            local C = candidates[i]
            local notMH = (not bestMH or C.id ~= bestMH.id)
            local notOH = (not bestOH or C.id ~= bestOH.id)
            if notMH and notOH then
                if C.equipLoc == "INVTYPE_WEAPON" or C.equipLoc == "INVTYPE_WEAPONMAINHAND" or C.equipLoc == "INVTYPE_WEAPONOFFHAND" then
                    if C.dps > maxThirdDps then
                        maxThirdDps = C.dps
                        bestThird = C
                    end
                end
            end
        end

        local mhName = bestMH and bestMH.name or nil
        local ohName = bestOH and bestOH.name or nil
        local thirdName = bestThird and bestThird.name or nil

        cachedMH, cachedOH, cachedThird = mhName, ohName, thirdName
        return mhName, ohName, thirdName
    end

    local itemSpeedCache = {}

    function jungle.GetItemSpeed(itemName)
        if not itemName then return nil end
        if itemSpeedCache[itemName] then
            return itemSpeedCache[itemName]
        end

        local tip = EnsureScanTooltip()
        
        -- Check bags
        for bag = 0, 4 do
            local numSlots = SafeGetNumSlots(bag)
            for slot = 1, numSlots do
                local itemLink = SafeGetItemLink(bag, slot)
                if itemLink then
                    local name = GetItemInfo(itemLink)
                    if name == itemName then
                        tip:ClearLines()
                        tip:SetOwner(WorldFrame, "ANCHOR_NONE")
                        tip:SetBagItem(bag, slot)
                        local speed = ParseSpeed(tip, tip:NumLines())
                        if speed then
                            itemSpeedCache[itemName] = speed
                            return speed
                        end
                    end
                end
            end
        end

        -- Check equipped slots
        for _, invSlot in ipairs({16, 17}) do
            local eqLink = GetInventoryItemLink("player", invSlot)
            if eqLink then
                local name = GetItemInfo(eqLink)
                if name == itemName then
                    tip:ClearLines()
                    tip:SetOwner(WorldFrame, "ANCHOR_NONE")
                    tip:SetInventoryItem("player", invSlot)
                    local speed = ParseSpeed(tip, tip:NumLines())
                    if speed then
                        itemSpeedCache[itemName] = speed
                        return speed
                    end
                end
            end
        end

        return nil
    end

end

-- ============================================================================
-- TALENT-BASED BUILD DETECTION & EQUIP CACHES
-- ============================================================================
local warriorCapabilities = {
    improvedSlamRank = 0,
    hasImprovedSlam2 = false,
    hasSweepingStrikes = false,
    hasBloodthirst = false,
    hasMortalStrike = false,
    hasSlam = false,
    hasDualWieldSpecialization = false,
}

local BLOODTHIRST_SPELL_IDS = {23881, 23892, 23893, 23894, 25251, 30335}

local function IsAnyPlayerSpellKnown(spellIDs)
    for i = 1, #spellIDs do
        local spellID = spellIDs[i]
        if IsPlayerSpell(spellID) or IsSpellKnown(spellID) then
            return true
        end
    end
    return false
end

local function RefreshWarriorCapabilities()
    local improvedSlamRank = 0
    local hasSweepingStrikesTalent = false
    local hasDualWieldSpecialization = false

    if C_SpecializationInfo and C_SpecializationInfo.GetTalentInfo then
        for specializationIndex = 1, 3 do
            for talentIndex = 1, 40 do
                local talentInfo = C_SpecializationInfo.GetTalentInfo({
                    specializationIndex = specializationIndex,
                    talentIndex = talentIndex,
                    isInspect = false,
                    isPet = false,
                })
                if talentInfo then
                    if talentInfo.name == "Improved Slam" then
                        improvedSlamRank = talentInfo.rank or 0
                    elseif talentInfo.name == "Sweeping Strikes" then
                        hasSweepingStrikesTalent = (talentInfo.rank or 0) > 0 or talentInfo.known
                    elseif talentInfo.name == "Dual Wield Specialization" then
                        hasDualWieldSpecialization = (talentInfo.rank or 0) > 0
                    end
                end
            end
        end
    end

    warriorCapabilities.improvedSlamRank = improvedSlamRank
    warriorCapabilities.hasImprovedSlam2 = improvedSlamRank >= 2
    warriorCapabilities.hasSweepingStrikes = hasSweepingStrikesTalent
        or IsPlayerSpell(12328)
        or IsSpellKnown(12328)
        or GetSpellBookItemInfo("Sweeping Strikes") ~= nil
    warriorCapabilities.hasBloodthirst = IsAnyPlayerSpellKnown(BLOODTHIRST_SPELL_IDS)
    warriorCapabilities.hasMortalStrike = IsPlayerSpell(12294)
        or IsSpellKnown(12294)
        or GetSpellBookItemInfo("Mortal Strike") ~= nil
    warriorCapabilities.hasSlam = IsPlayerSpell(1464)
        or IsSpellKnown(1464)
        or GetSpellBookItemInfo("Slam") ~= nil
    warriorCapabilities.hasDualWieldSpecialization = hasDualWieldSpecialization
end

local warriorTalentFrame = CreateFrame("Frame")
warriorTalentFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
warriorTalentFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
warriorTalentFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
warriorTalentFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")
warriorTalentFrame:SetScript("OnEvent", RefreshWarriorCapabilities)
RefreshWarriorCapabilities()

local function IsDualWieldSpec()
    return warriorCapabilities.hasDualWieldSpecialization
end

local function HasTwoHandEquipped()
    local mhLink = GetInventoryItemLink("player", 16)
    if not mhLink then return false end
    local _, _, _, _, _, _, _, _, itemEquipLoc = GetItemInfo(mhLink)
    return (itemEquipLoc == "INVTYPE_2HWEAPON")
end

local equipCache2H = {
    [1] = {'Equip2H', 'Equip2H', false, 1, 0},
}
local equipCacheDW = {
    [1] = {'EquipDW', 'EquipDW', false, 1, 0},
}
local equipCacheShield = {
    [1] = {'EquipShield', 'EquipShield', false, 1, 0},
}
local equipCacheFastOffHand = {
    [1] = {'EquipFastOffHand', 'EquipFastOffHand', false, 1, 0},
}
local equipCacheSlowOffHand = {
    [1] = {'EquipSlowOffHand', 'EquipSlowOffHand', false, 1, 0},
}

local function HasOtherAttackPowerDebuff(unit)
    if not unit then return false end
    return jungle.Debuff('Demoralizing Roar', unit)
        or jungle.Debuff('Curse of Weakness', unit)
        or jungle.Debuff('Screech', unit)
end

local function HasAttackPowerDebuff(unit)
    if not unit then return false end
    return jungle.Debuff('Demoralizing Shout', unit) or HasOtherAttackPowerDebuff(unit)
end

local function CanUseImprovedSlam()
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    return (not routineActions or routineActions["Slam"] ~= false) and warriorCapabilities.hasImprovedSlam2
        and warriorCapabilities.hasSlam
        and HasTwoHandEquipped()
end

local function UsesWarriorFuryRotation()
    local isDW = IsDualWieldSpec()
    
    if not isDW then
        local mhLink = GetInventoryItemLink("player", 16)
        local ohLink = GetInventoryItemLink("player", 17)
        if mhLink and ohLink then
            local _, _, _, _, _, _, _, _, mhEquipLoc = GetItemInfo(mhLink)
            local _, _, _, _, _, _, _, _, ohEquipLoc = GetItemInfo(ohLink)
            if (mhEquipLoc == "INVTYPE_WEAPONMAINHAND" or mhEquipLoc == "INVTYPE_WEAPON") and 
               (ohEquipLoc == "INVTYPE_WEAPONOFFHAND" or ohEquipLoc == "INVTYPE_WEAPON") then
                isDW = true
            end
        end
    end
    
    return isDW
end

local function CanApplyWarriorTargetDebuff(unit)
    return unit and UnitExists(unit) and not IsTotemUnit(unit)
end

local function ReadyCastSpellNoGCD(spell, target, allowResourcePending)
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    if not (not routineActions or routineActions[spell] ~= false) then return false end
    local name = GetSpellInfo(spell)
    if not name or not GetSpellBookItemInfo(spell) then
        return false
    end

    local usable, nomana = IsUsableSpell(spell)
    if (not usable) and not (allowResourcePending and nomana) then return false end
    if nomana and not allowResourcePending then return false end

    if jungle.actionHasRange[spell] and target and target ~= 'player' then
        local inRange = IsSpellInRange(spell, target)
        if inRange ~= 1 then return false end
    end

    local start, duration = GetSpellCooldown(spell)
    if not start then return false end

    if duration and duration > 0.05 then
        local _, gcdDuration = jungle.GetGCDValues()
        if not (gcdDuration and gcdDuration > 0 and duration <= (gcdDuration + 0.05)) then
            return false
        end
    end

    if UnitIsDeadOrGhost('player') then return false end
    return true
end

-- Resource-independent readiness used when deciding whether filler may spend rage.
local function IsSpellOffRealCooldown(spell)
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    if not (not routineActions or routineActions[spell] ~= false) then return false end
    local start, duration = GetSpellCooldown(spell)
    if not start then return false end
    if not duration or duration <= 0.05 then return true end

    local _, gcdDuration = jungle.GetGCDValues()
    return gcdDuration and gcdDuration > 0 and duration <= (gcdDuration + 0.05)
end

local function GetWarriorGapCloserDecision(target, readySpell, result)
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    readySpell = readySpell or ReadyCastSpellNoGCD

    local inCombat = UnitAffectingCombat("player")
    local rage = UnitPower("player", 1)
    local stance = GetShapeshiftForm()
    local hasEnemy = target ~= nil and UnitExists(target)
        and UnitCanAttack("player", target) and not UnitIsDeadOrGhost(target)
    local inMeleeRange = hasEnemy and jungle.inMeleeRange(target)
    local chargeInRange = hasEnemy and C_Spell.IsSpellInRange("Charge", target) == true
    local interceptInRange = hasEnemy and C_Spell.IsSpellInRange("Intercept", target) == true
    local inGapCloserRange = (chargeInRange or interceptInRange) and not inMeleeRange
    local chargeOnCD = jungle.SpellOnCD("Charge")
    local interceptOnCD = jungle.SpellOnCD("Intercept")

    local wantCharge = (not routineActions or routineActions["Charge"] ~= false) and not inCombat and chargeInRange and not inMeleeRange and not chargeOnCD
    if stance == 3 and rage >= 10 and not interceptOnCD then
        wantCharge = false
    end

    local chargeStart = GetSpellCooldown("Charge")
    local recentlyCharged = chargeStart and chargeStart > 0 and (GetTime() - chargeStart) <= 2
    local interceptStart = GetSpellCooldown("Intercept")
    local recentlyIntercepted = interceptStart and interceptStart > 0 and (GetTime() - interceptStart) <= 2
    local wantIntercept = (not routineActions or routineActions["Intercept"] ~= false) and (
        (inCombat or chargeOnCD or (stance == 3 and rage >= 10))
        and not recentlyCharged
        and interceptInRange
        and not inMeleeRange
        and not interceptOnCD
    )

    -- Adaptive supplies reusable scratch storage; existing callers retain their own result.
    local decision = result or {}
    decision.inCombat = inCombat
    decision.rage = rage
    decision.stance = stance
    decision.inMeleeRange = inMeleeRange
    decision.inGapCloserRange = inGapCloserRange
    decision.chargeOnCD = chargeOnCD
    decision.interceptOnCD = interceptOnCD
    decision.chargeStart = chargeStart
    decision.recentlyCharged = recentlyCharged
    decision.recentlyIntercepted = recentlyIntercepted
    decision.wantCharge = wantCharge
    decision.wantIntercept = wantIntercept
    decision.useCharge = wantCharge and stance == 1 and readySpell('Charge', target)
    decision.useBattleStanceForCharge = wantCharge and stance ~= 1 and readySpell('Battle Stance')
    decision.useIntercept = wantIntercept and stance == 3 and readySpell('Intercept', target)
    decision.useBerserkerStanceForIntercept = wantIntercept and stance ~= 3 and readySpell('Berserker Stance')
    return decision
end

-- ============================================================================
-- WARRIOR TANK ROUTINE (TBC Classic)
-- ============================================================================

local warriorTankCache = {
    [1]  = {'Charge', 'Charge', false, 1, 0},
    [2]  = {'Battle Stance', 'Battle Stance', false, 1, 0},
    [3]  = {'Intercept', 'Intercept', false, 1, 0},
    [4]  = {'Pre-Zerk TC', 'Thunder Clap', false, 1, 0},
    [5]  = {'Berserker Stance', 'Berserker Stance', false, 1, 0},
    
    [6]  = {'Pre-Def BR', 'Berserker Rage', false, 1, 0},
    [7]  = {'Pre-Def WW', 'Whirlwind', false, 1, 0},
    [8]  = {'Defensive Stance', 'Defensive Stance', false, 1, 0},
    
    [9]  = {'Bloodrage', 'Bloodrage', false, 1, 0},
    [10] = {'Commanding Shout', 'Commanding Shout', false, 1, 0},
    [11] = {'Battle Shout', 'Battle Shout', false, 1, 0},
    [12] = {'Shield Block', 'Shield Block', false, 1, 0},
    [13] = {'Taunt', 'Taunt', false, 1, 0},

    -- --- DYNAMIC PRIORITIES ---
    [14] = {'AoE Priority', 'Demoralizing Shout', false, 1, 0},
    [15] = {'Cleave Priority', 'Cleave', false, 1, 0},
    [16] = {'Shield Bash', 'Shield Bash', false, 1, 0},
    [17] = {'Shield Slam', 'Shield Slam', false, 1, 0},
    [18] = {'Sunder Priority', 'Devastate', false, 1, 0},
    [19] = {'Revenge', 'Revenge', false, 1, 0},
    [20] = {'Demo Shout', 'Demoralizing Shout', false, 1, 0},
    [21] = {'Thunder Clap', 'Thunder Clap', false, 1, 0},
    [22] = {'Sunder Stack', 'Devastate', false, 1, 0},
    [23] = {'Unused', '', false, 1, 0},
    [24] = {'Trinkets', 'Trinkets', false, 1, 0},
    
    [25] = {'Cleave', 'Cleave', false, 1, 0},
    [26] = {'Heroic Strike', 'Heroic Strike', false, 1, 0},
    [27] = {'Attack', 'Attack', false, 1, 0},
}
local emptyCache = {}

local overpowerExpireTime = 0
local overpowerDodgeGUID = nil
local armsLastMainhandSwingTime = 0
local armsLastSlammedSwingTime = 0
local armsSlamCastingSwingTime = 0
local armsLastGapCloserTime = 0
local armsGapCloserPendingSwing = false
local armsLastMainhandWasGapCloserSwing = false
local armsLastPiercingHowlTime = 0
local armsReplacementHSExpireTime = 0
local armsPveHoldBattleForThunderClap = false
local armsPveHoldBattleForThunderClapGUID = nil
local armsPveHoldBattleForThunderClapThread = {}
local armsPveSunderApplicationTimes = {}
local armsSweepingStrikesCastGraceUntil = 0
local THREAD3_PRE_SWING_WINDOW = 0.8
local SLAM_AFTERSWING_WINDOW = 1.15
local SLAM_GAP_CLOSER_AFTERSWING_WINDOW = 1.15
local SLAM_GAP_CLOSER_EVENT_SKEW = 0.75
local SLAM_STATIONARY_SPEED_MAX = 0.1
local SLAM_PRE_SWING_BUFFER = 0.1
local SLAM_EXPECTED_SWING_RAGE = 15
local SLAM_GAP_CLOSER_WAIT_TIMEOUT = 5
local HEROIC_STRIKE_RAGE_COST = 15
local CLEAVE_RAGE_COST = 20
local ARMS_PVP_MORTAL_STRIKE_RAGE_COST = 30
local ARMS_PVE_MORTAL_STRIKE_RAGE_COST = 30
local ARMS_PVE_WHIRLWIND_RAGE_COST = 25
local ARMS_PVE_SLAM_RAGE_COST = 15
local ARMS_PVE_SWEEPING_STRIKES_RAGE_COST = 30
local ARMS_PVE_SWEEPING_MS_RAGE_THRESHOLD = 60
local ARMS_PVE_RAGE_DUMP_OVERFLOW = 90
local ARMS_PVE_THUNDER_CLAP_URGENT_REMAINING = 5
local ARMS_PVE_DEMORALIZING_SHOUT_REFRESH_REMAINING = 5
local ARMS_PVE_SUNDER_AURA_SETTLE_TIME = 1.5
local PIERCING_HOWL_AOE_INTERVAL = 5
local OVERPOWER_DODGE_WINDOW = 6

local function GetImprovedSlamRageThreshold(isAoE)
    if not isAoE then return ARMS_PVE_SLAM_RAGE_COST end
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    if jungle.WarriorRoutineOptionEnabled("sweeping") and warriorCapabilities.hasSweepingStrikes and IsSpellOffRealCooldown("Sweeping Strikes") then
        return ARMS_PVE_RAGE_DUMP_OVERFLOW
    end
    local threshold = ARMS_PVE_SWEEPING_MS_RAGE_THRESHOLD
    if routineActions then
        if routineActions['Whirlwind'] == false then threshold = threshold - ARMS_PVE_WHIRLWIND_RAGE_COST end
        if routineActions['Mortal Strike'] == false then threshold = threshold - ARMS_PVE_MORTAL_STRIKE_RAGE_COST end
    end
    return math.max(ARMS_PVE_SLAM_RAGE_COST, threshold)
end

-- ============================================================================
-- ARMS PVE DIAGNOSTICS
-- Records one entry per meaningful event instead of one entry per rotation tick.
-- The saved log is intentionally structured so it can be inspected directly in
-- WTF/Account/<account>/SavedVariables/OliaEyes6.lua after logout or /reload.
-- ============================================================================

local ARMS_LOG_VERSION = 1
local ARMS_LOG_MAX_ENTRIES = 1200
local ARMS_CORE_DELAY_WARNING = 0.25
local ARMS_PVE_ACTIVE_GRACE = 1.0
local ARMS_DECISION_SAMPLE_INTERVAL = 0.05
local ARMS_CORE_SPELLS = {
    ["Mortal Strike"] = true,
    ["Whirlwind"] = true,
    ["Sweeping Strikes"] = true,
}

local armsPveDiagnosticsActiveUntil = 0
local armsPveFight = nil
local armsSlamWindow = nil
local armsSlamCastStartedAt = 0
local armsCoreWindows = {}
local armsLastCoreCast = {}
local armsFightSequence = 0
local armsLastDecisionSampleAt = 0

local function EnsureArmsLog()
    if type(OliaArmsLog) ~= "table" then
        OliaArmsLog = {}
    end

    OliaArmsLog.version = ARMS_LOG_VERSION
    if OliaArmsLog.enabled == nil then
        OliaArmsLog.enabled = false
    end
    if type(OliaArmsLog.entries) ~= "table" then
        OliaArmsLog.entries = {}
    end
    if type(OliaArmsLog.stats) ~= "table" then
        OliaArmsLog.stats = {}
    end

    local stats = OliaArmsLog.stats
    stats.fights = stats.fights or 0
    stats.swings = stats.swings or 0
    stats.slamUsed = stats.slamUsed or 0
    stats.slamMissed = stats.slamMissed or 0
    stats.slamSkipped = stats.slamSkipped or 0
    stats.slamFailed = stats.slamFailed or 0
    stats.core = stats.core or {}

    for spellName in pairs(ARMS_CORE_SPELLS) do
        local spellStats = stats.core[spellName]
        if type(spellStats) ~= "table" then
            spellStats = {}
            stats.core[spellName] = spellStats
        end
        spellStats.casts = spellStats.casts or 0
        spellStats.delaySamples = spellStats.delaySamples or 0
        spellStats.actionableDelayTotal = spellStats.actionableDelayTotal or 0
        spellStats.actionableDelayMax = spellStats.actionableDelayMax or 0
        spellStats.delayedCasts = spellStats.delayedCasts or 0
    end

    return OliaArmsLog
end

local function ArmsDiagnosticsEnabled()
    return type(OliaArmsLog) == "table" and OliaArmsLog.enabled == true
end

local function NoopArmsDecision()
end

local function FormatArmsNumber(value, digits)
    if type(value) ~= "number" then return tostring(value or "-") end
    return string.format("%." .. (digits or 2) .. "f", value)
end

local function ArmsReasonSummary(reasons)
    if type(reasons) ~= "table" then return "none" end

    local names = {}
    for reason, seen in pairs(reasons) do
        if seen then
            names[#names + 1] = reason
        end
    end
    table.sort(names)
    return #names > 0 and table.concat(names, ",") or "none"
end

local function AppendArmsLog(eventName, text, data)
    local log = EnsureArmsLog()
    if not log.enabled then return end

    local now = GetTime()
    local entry = {
        time = date("%Y-%m-%d %H:%M:%S"),
        sessionTime = now,
        fight = armsPveFight and armsPveFight.id or 0,
        event = eventName,
        text = text,
        data = data,
    }

    table.insert(log.entries, entry)
    while #log.entries > ARMS_LOG_MAX_ENTRIES do
        table.remove(log.entries, 1)
    end
end

local function IncrementFightCounter(field)
    if armsPveFight then
        armsPveFight[field] = (armsPveFight[field] or 0) + 1
    end
end

local function EnsureFightCoreStats(spellName)
    if not armsPveFight then return nil end
    armsPveFight.core = armsPveFight.core or {}
    local stats = armsPveFight.core[spellName]
    if not stats then
        stats = {casts = 0, delayTotal = 0, delayMax = 0, delayed = 0}
        armsPveFight.core[spellName] = stats
    end
    return stats
end

local function StartArmsPveFight(now)
    if armsPveFight or not EnsureArmsLog().enabled then return end

    armsSlamWindow = nil
    armsSlamCastStartedAt = 0
    armsCoreWindows = {}
    armsLastCoreCast = {}
    armsLastDecisionSampleAt = 0

    armsFightSequence = armsFightSequence + 1
    local targetName = UnitExists("target") and UnitName("target") or "unknown"
    armsPveFight = {
        id = date("%H%M%S") .. "-" .. armsFightSequence,
        startedAt = now,
        targetName = targetName,
        targetGUID = UnitExists("target") and UnitGUID("target") or nil,
        swings = 0,
        slamUsed = 0,
        slamMissed = 0,
        slamSkipped = 0,
        slamFailed = 0,
        core = {},
    }

    local log = EnsureArmsLog()
    log.stats.fights = log.stats.fights + 1
    AppendArmsLog(
        "FIGHT_START",
        "Arms PvE diagnostics started against " .. tostring(targetName),
        {
            target = targetName,
            targetGUID = armsPveFight.targetGUID,
            rage = UnitPower("player", 1),
            stance = GetShapeshiftForm(),
        }
    )
end

local function FinishArmsCoreWindow(spellName, result, now)
    local state = armsCoreWindows[spellName]
    if not state then return nil end

    armsCoreWindows[spellName] = nil
    local cooldownDelay = math.max(0, now - state.startedAt)
    local actionableDelay = state.actionableAt and math.max(0, now - state.actionableAt) or nil
    local reasonText = ArmsReasonSummary(state.reasons)

    if result ~= "cast" then
        local eventName = actionableDelay and "CORE_DROPPED" or "CORE_WINDOW_END"
        AppendArmsLog(
            eventName,
            string.format(
                "%s opportunity ended without a cast after %.2fs (actionable=%s; reasons=%s)",
                spellName,
                cooldownDelay,
                actionableDelay and FormatArmsNumber(actionableDelay) .. "s" or "never",
                reasonText
            ),
            {
                spell = spellName,
                result = result,
                cooldownDelay = cooldownDelay,
                actionableDelay = actionableDelay,
                reasons = reasonText,
                lastSelected = state.lastSelected,
                maxRage = state.maxRage,
            }
        )
    end

    return state, cooldownDelay, actionableDelay, reasonText
end

local function RecordArmsCoreCast(spellName, now)
    if not ARMS_CORE_SPELLS[spellName] or not armsPveFight then return end

    local state, cooldownDelay, actionableDelay, reasonText = FinishArmsCoreWindow(spellName, "cast", now)
    local sinceLastCast = armsLastCoreCast[spellName] and (now - armsLastCoreCast[spellName]) or nil
    armsLastCoreCast[spellName] = now

    local log = EnsureArmsLog()
    local lifetimeStats = log.stats.core[spellName]
    lifetimeStats.casts = lifetimeStats.casts + 1

    local fightStats = EnsureFightCoreStats(spellName)
    fightStats.casts = fightStats.casts + 1

    if actionableDelay then
        lifetimeStats.delaySamples = lifetimeStats.delaySamples + 1
        lifetimeStats.actionableDelayTotal = lifetimeStats.actionableDelayTotal + actionableDelay
        lifetimeStats.actionableDelayMax = math.max(lifetimeStats.actionableDelayMax, actionableDelay)
        fightStats.delaySamples = (fightStats.delaySamples or 0) + 1
        fightStats.delayTotal = fightStats.delayTotal + actionableDelay
        fightStats.delayMax = math.max(fightStats.delayMax, actionableDelay)
        if actionableDelay >= ARMS_CORE_DELAY_WARNING then
            lifetimeStats.delayedCasts = lifetimeStats.delayedCasts + 1
            fightStats.delayed = fightStats.delayed + 1
        end
    end

    local eventName = actionableDelay and actionableDelay >= ARMS_CORE_DELAY_WARNING and "CORE_DELAYED" or "CORE_CAST"
    AppendArmsLog(
        eventName,
        string.format(
            "%s cast; ready delay=%s, cooldown-open=%s, since last=%s, reasons=%s",
            spellName,
            actionableDelay and FormatArmsNumber(actionableDelay) .. "s" or "unobserved",
            cooldownDelay and FormatArmsNumber(cooldownDelay) .. "s" or "unobserved",
            sinceLastCast and FormatArmsNumber(sinceLastCast) .. "s" or "first",
            reasonText or "none"
        ),
        {
            spell = spellName,
            actionableDelay = actionableDelay,
            cooldownDelay = cooldownDelay,
            sinceLastCast = sinceLastCast,
            reasons = reasonText,
            lastSelected = state and state.lastSelected or nil,
            rage = UnitPower("player", 1),
            stance = GetShapeshiftForm(),
        }
    )
end

local function FinishArmsSlamWindow(now, forcedReason)
    local window = armsSlamWindow
    if not window then return end
    armsSlamWindow = nil

    local delay = math.max(0, now - window.swingAt)
    local reasonText = ArmsReasonSummary(window.reasons)
    local log = EnsureArmsLog()
    local eventName
    local result

    if forcedReason == "used" then
        eventName = "SLAM_USED"
        result = "used"
        log.stats.slamUsed = log.stats.slamUsed + 1
        IncrementFightCounter("slamUsed")
    elseif window.recommended then
        eventName = "SLAM_MISSED"
        result = "missed"
        log.stats.slamMissed = log.stats.slamMissed + 1
        IncrementFightCounter("slamMissed")
    else
        eventName = "SLAM_SKIPPED"
        result = "skipped"
        log.stats.slamSkipped = log.stats.slamSkipped + 1
        IncrementFightCounter("slamSkipped")
    end

    local detail
    if result == "used" then
        detail = string.format(
            "Slam started %.3fs after %s (window %.2fs; rage %d -> %d; selected=%s)",
            delay,
            window.attack,
            window.windowLength,
            window.rageAtSwing,
            UnitPower("player", 1),
            tostring(window.lastSelected or "Slam")
        )
    elseif result == "missed" then
        detail = string.format(
            "Slam was recommended after %s but no cast started inside %.2fs (reasons=%s; selected=%s)",
            window.attack,
            window.windowLength,
            reasonText,
            tostring(window.lastSelected or "unknown")
        )
    else
        detail = string.format(
            "Slam skipped after %s (reason=%s; blockers=%s; max rage=%d/%d; selected=%s)",
            window.attack,
            tostring(forcedReason or window.lastBlocker or "not_eligible"),
            reasonText,
            window.maxRage,
            window.rageThreshold or 15,
            tostring(window.lastSelected or "none")
        )
    end

    AppendArmsLog(eventName, detail, {
        result = result,
        forcedReason = forcedReason,
        swingAt = window.swingAt,
        delay = delay,
        deadline = window.deadline,
        windowLength = window.windowLength,
        attack = window.attack,
        attackResult = window.attackResult,
        gapCloserSwing = window.gapCloserSwing,
        rageAtSwing = window.rageAtSwing,
        rageAtFinish = UnitPower("player", 1),
        maxRage = window.maxRage,
        rageThreshold = window.rageThreshold,
        evaluations = window.evaluations,
        eligible = window.eligible,
        recommended = window.recommended,
        recommendationAt = window.recommendationAt,
        reasons = reasonText,
        lastBlocker = window.lastBlocker,
        slamTiming = window.slamTiming,
        lastSelected = window.lastSelected,
        mode = window.mode,
        target = window.target,
    })
end

local function EndArmsPveFight(now, reason)
    if not armsPveFight then return end

    if armsSlamWindow then
        FinishArmsSlamWindow(now, "combat_end")
    end
    for spellName in pairs(armsCoreWindows) do
        FinishArmsCoreWindow(spellName, "combat_end", now)
    end

    local fight = armsPveFight
    local coreParts = {}
    for _, spellName in ipairs({"Mortal Strike", "Whirlwind", "Sweeping Strikes"}) do
        local stats = fight.core[spellName]
        if stats and stats.casts > 0 then
            local delaySamples = stats.delaySamples or 0
            coreParts[#coreParts + 1] = string.format(
                "%s %d casts avg %s max %.2fs",
                spellName,
                stats.casts,
                delaySamples > 0 and FormatArmsNumber(stats.delayTotal / delaySamples) .. "s" or "unobserved",
                stats.delayMax
            )
        end
    end
    local coreText = #coreParts > 0 and table.concat(coreParts, "; ") or "no observed core casts"
    local duration = math.max(0, now - fight.startedAt)

    AppendArmsLog(
        "FIGHT_END",
        string.format(
            "Fight ended (%s): %.1fs, %d swings, Slam %d used/%d missed/%d skipped/%d failed; %s",
            tostring(reason or "combat_end"),
            duration,
            fight.swings,
            fight.slamUsed,
            fight.slamMissed,
            fight.slamSkipped,
            fight.slamFailed,
            coreText
        ),
        {
            reason = reason,
            duration = duration,
            target = fight.targetName,
            targetGUID = fight.targetGUID,
            swings = fight.swings,
            slamUsed = fight.slamUsed,
            slamMissed = fight.slamMissed,
            slamSkipped = fight.slamSkipped,
            slamFailed = fight.slamFailed,
            core = fight.core,
        }
    )

    armsPveFight = nil
    armsSlamWindow = nil
    armsCoreWindows = {}
end

local function MarkArmsPveDiagnosticsActive(target, inCombat)
    if not ArmsDiagnosticsEnabled() then return end

    local now = GetTime()
    armsPveDiagnosticsActiveUntil = now + ARMS_PVE_ACTIVE_GRACE

    if inCombat then
        StartArmsPveFight(now)
        if armsPveFight and UnitExists(target) then
            armsPveFight.targetName = UnitName(target) or armsPveFight.targetName
            armsPveFight.targetGUID = UnitGUID(target) or armsPveFight.targetGUID
        end
    elseif armsPveFight then
        EndArmsPveFight(now, "routine_out_of_combat")
    end
end

local function AddArmsWindowReason(window, reason)
    if not window or not reason then return end
    window.reasons[reason] = true
    window.lastBlocker = reason
end

local function SampleArmsCoreWindow(spellName, details, context)
    local now = context.now
    local state = armsCoreWindows[spellName]

    if not details.due then
        if state then
            FinishArmsCoreWindow(spellName, "no_longer_due", now)
        end
        return
    end

    if not state then
        state = {
            startedAt = now,
            actionableAt = nil,
            reasons = {},
            maxRage = context.rage,
            lastSelected = context.selected,
        }
        armsCoreWindows[spellName] = state
    end

    state.maxRage = math.max(state.maxRage or 0, context.rage)
    if context.selected then
        state.lastSelected = context.selected
    end
    if details.ready and context.inMelee and not state.actionableAt then
        state.actionableAt = now
    end

    if not context.inMelee then
        state.reasons.out_of_melee = true
    end
    if context.blockCoreForSlam then
        state.reasons.slam_reservation = true
    end
    if context.gcdRemaining > 0.1 then
        state.reasons.gcd = true
    end
    if not details.ready then
        local usable, noRage = IsUsableSpell(spellName)
        if noRage then
            state.reasons.low_rage = true
        elseif not usable then
            state.reasons.stance_or_unusable = true
        else
            state.reasons.not_castable = true
        end
    end
    if context.selected and context.selected ~= spellName then
        state.reasons["selected_" .. string.gsub(string.lower(context.selected), "%s+", "_")] = true
    end
end

local function UpdateArmsPveDiagnostics(context)
    if not armsPveFight or not EnsureArmsLog().enabled then return end

    local window = armsSlamWindow
    if window then
        if context.now <= window.deadline then
            window.evaluations = window.evaluations + 1
            window.maxRage = math.max(window.maxRage, context.rage)
            window.rageThreshold = context.slamRageThreshold
            window.mode = context.mode
            if context.selected then
                window.lastSelected = context.selected
            end
            if context.useSlamWindow then
                window.eligible = true
            end
            if context.slamRecommended then
                window.recommended = true
                window.recommendationAt = window.recommendationAt or context.now
            end
            AddArmsWindowReason(window, context.slamBlocker)
            if context.slamTiming then
                -- Only bounded diagnostic samples retain a copy of the reused planner record.
                window.slamTiming = window.slamTiming or {}
                for key in pairs(window.slamTiming) do window.slamTiming[key] = nil end
                for key, value in pairs(context.slamTiming) do window.slamTiming[key] = value end
            end
        else
            FinishArmsSlamWindow(context.now, nil)
        end
    end

    if context.core then
        for spellName in pairs(ARMS_CORE_SPELLS) do
            local details = context.core[spellName] or {due = false, ready = false}
            SampleArmsCoreWindow(spellName, details, context)
        end
    end
end

local function RecordArmsMainhandSwing(now, attackName, attackResult)
    local wasGapCloserSwing = armsGapCloserPendingSwing

    if armsPveFight and now <= armsPveDiagnosticsActiveUntil then
        if armsSlamWindow then
            FinishArmsSlamWindow(now, nil)
        end

        local windowLength = wasGapCloserSwing and SLAM_GAP_CLOSER_AFTERSWING_WINDOW or SLAM_AFTERSWING_WINDOW
        armsSlamWindow = {
            swingAt = now,
            deadline = now + windowLength,
            windowLength = windowLength,
            attack = attackName or "Auto Attack",
            attackResult = attackResult or "unknown",
            gapCloserSwing = wasGapCloserSwing,
            rageAtSwing = UnitPower("player", 1),
            maxRage = UnitPower("player", 1),
            rageThreshold = 15,
            evaluations = 0,
            eligible = false,
            recommended = false,
            recommendationAt = nil,
            reasons = {},
            lastBlocker = nil,
            lastSelected = nil,
            mode = nil,
            target = UnitExists("target") and UnitName("target") or nil,
        }

        local log = EnsureArmsLog()
        log.stats.swings = log.stats.swings + 1
        IncrementFightCounter("swings")
        AppendArmsLog(
            "SWING",
            string.format(
                "%s %s opened a %.2fs Slam window (rage=%d; gap closer=%s)",
                armsSlamWindow.attack,
                armsSlamWindow.attackResult,
                windowLength,
                armsSlamWindow.rageAtSwing,
                tostring(wasGapCloserSwing)
            ),
            {
                attack = armsSlamWindow.attack,
                result = armsSlamWindow.attackResult,
                windowLength = windowLength,
                deadline = armsSlamWindow.deadline,
                rage = armsSlamWindow.rageAtSwing,
                stance = GetShapeshiftForm(),
                gapCloserSwing = wasGapCloserSwing,
                target = armsSlamWindow.target,
            }
        )
    end

    armsLastMainhandSwingTime = now
    armsLastMainhandWasGapCloserSwing = wasGapCloserSwing
    armsGapCloserPendingSwing = false
    armsReplacementHSExpireTime = 0
end

jungle.SwingTimer:RegisterMainhandSwingCallback(RecordArmsMainhandSwing)
jungle.SwingTimer:RegisterResetCallback(function(reason)
    armsLastMainhandSwingTime = 0
    armsLastSlammedSwingTime = 0
    armsLastMainhandWasGapCloserSwing = false
    armsSlamCastingSwingTime = 0
    armsSlamCastStartedAt = 0
    if reason ~= "attack_request" then
        armsGapCloserPendingSwing = false
        armsLastGapCloserTime = 0
    end
end)

local function RecordArmsSlamStart()
    local now = GetTime()
    if armsLastMainhandSwingTime > armsLastSlammedSwingTime then
        armsSlamCastingSwingTime = armsLastMainhandSwingTime
        armsLastSlammedSwingTime = armsSlamCastingSwingTime
        armsSlamCastStartedAt = now
        if armsPveFight and armsSlamWindow and armsSlamWindow.swingAt == armsSlamCastingSwingTime then
            FinishArmsSlamWindow(armsSlamCastStartedAt, "used")
        end
    elseif armsPveFight and armsSlamCastingSwingTime == 0 then
        armsSlamCastStartedAt = now
        AppendArmsLog(
            "SLAM_UNMATCHED",
            string.format(
                "Slam started without an open swing window (last swing %.3fs ago)",
                armsLastMainhandSwingTime > 0 and math.max(0, now - armsLastMainhandSwingTime) or 999
            ),
            {
                timeSinceSwing = armsLastMainhandSwingTime > 0 and math.max(0, now - armsLastMainhandSwingTime) or nil,
                rage = UnitPower("player", 1),
                stance = GetShapeshiftForm(),
            }
        )
    end
end

-- All completion evidence consumes the same window, including avoided Slam.
jungle.SwingTimer:RegisterSlamCompletionCallback(function(now, evidence)
    if armsSlamCastingSwingTime == 0 then
        RecordArmsSlamStart()
    end
    if armsPveFight then
        AppendArmsLog(
            "SLAM_SUCCESS",
            string.format(
                "Slam completed after %.3fs (rage=%d)",
                armsSlamCastStartedAt > 0 and math.max(0, now - armsSlamCastStartedAt) or 0,
                UnitPower("player", 1)
            ),
            {
                evidence = evidence,
                castDuration = armsSlamCastStartedAt > 0 and math.max(0, now - armsSlamCastStartedAt) or nil,
                rage = UnitPower("player", 1),
            }
        )
    end
    armsSlamCastingSwingTime = 0
    armsSlamCastStartedAt = 0
end)

local function RecordArmsGapCloser(now, fromRotation)
    if not fromRotation and armsLastGapCloserTime > 0 and armsLastMainhandSwingTime > armsLastGapCloserTime then
        return
    end

    if not fromRotation and armsLastMainhandSwingTime > 0 and now > armsLastMainhandSwingTime and (now - armsLastMainhandSwingTime) <= SLAM_GAP_CLOSER_EVENT_SKEW then
        return
    end

    armsLastGapCloserTime = now
    armsLastMainhandSwingTime = 0
    armsGapCloserPendingSwing = true
    armsLastMainhandWasGapCloserSwing = false
end

local overpowerTracker = CreateFrame("Frame")
overpowerTracker:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
overpowerTracker:RegisterEvent("PLAYER_REGEN_DISABLED")
overpowerTracker:RegisterEvent("PLAYER_REGEN_ENABLED")
overpowerTracker:RegisterEvent("UNIT_SPELLCAST_FAILED")
overpowerTracker:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
overpowerTracker:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
overpowerTracker:SetScript("OnEvent", function(_, event, unit, castGUID, spellID)
    local now = GetTime()

    if event == "PLAYER_REGEN_DISABLED" then
        if now <= armsPveDiagnosticsActiveUntil then
            StartArmsPveFight(now)
        end
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        EndArmsPveFight(now, "combat_end")
        armsPveHoldBattleForThunderClap = false
        armsPveHoldBattleForThunderClapGUID = nil
        armsPveHoldBattleForThunderClapThread.behavior = nil
        armsPveSunderApplicationTimes = {}
        armsSweepingStrikesCastGraceUntil = 0
        return
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit == "player" and spellID then
            local spellName = GetSpellInfo(spellID)
            if spellName == "Sunder Armor" then
                local targetGUID = jungle.CurrentCast and jungle.CurrentCast.targetGUID
                if targetGUID then
                    armsPveSunderApplicationTimes[targetGUID] = now
                end
            elseif spellName == "Thunder Clap" then
                armsPveHoldBattleForThunderClap = false
                armsPveHoldBattleForThunderClapGUID = nil
                armsPveHoldBattleForThunderClapThread.behavior = nil
            elseif spellName == "Sweeping Strikes" then
                -- UNIT_AURA may arrive a frame after the successful cast. Keep
                -- Thread 3 ownership through that handoff so normal Arms/Fury
                -- cannot spend the burst before the buff cache catches up.
                armsSweepingStrikesCastGraceUntil = now + 1
            end
        end
        return
    elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        if unit == "player" and spellID and GetSpellInfo(spellID) == "Slam" then
            if armsPveFight then
                local log = EnsureArmsLog()
                log.stats.slamFailed = log.stats.slamFailed + 1
                IncrementFightCounter("slamFailed")
                AppendArmsLog(
                    "SLAM_FAILED",
                    string.format(
                        "Slam cast %s %.3fs after it started",
                        event == "UNIT_SPELLCAST_INTERRUPTED" and "was interrupted" or "failed",
                        armsSlamCastStartedAt > 0 and math.max(0, now - armsSlamCastStartedAt) or 0
                    ),
                    {
                        result = event,
                        castDuration = armsSlamCastStartedAt > 0 and math.max(0, now - armsSlamCastStartedAt) or nil,
                        rage = UnitPower("player", 1),
                    }
                )
            end
            armsSlamCastingSwingTime = 0
            armsSlamCastStartedAt = 0
        end
        return
    end

    local _, subEvent, _, sourceGUID, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
    if sourceGUID == UnitGUID("player") then
        if subEvent == "SPELL_DAMAGE" or subEvent == "SPELL_MISSED" then
            local spellName = select(13, CombatLogGetCurrentEventInfo())
            if spellName == "Charge" or spellName == "Intercept" then
                RecordArmsGapCloser(now)
            end
        elseif subEvent == "SPELL_CAST_SUCCESS" then
            local spellName = select(13, CombatLogGetCurrentEventInfo())
            if spellName == "Charge" or spellName == "Intercept" then
                RecordArmsGapCloser(now)
            elseif spellName == "Piercing Howl" then
                armsLastPiercingHowlTime = now
            elseif ARMS_CORE_SPELLS[spellName] then
                RecordArmsCoreCast(spellName, now)
            end
        elseif subEvent == "SPELL_CAST_START" then
            local spellName = select(13, CombatLogGetCurrentEventInfo())
            if spellName == "Slam" then
                RecordArmsSlamStart()
            end
        end

        if subEvent == "SWING_MISSED" or subEvent == "SPELL_MISSED" then
            local missType
            if subEvent == "SWING_MISSED" then
                missType = select(12, CombatLogGetCurrentEventInfo())
            else
                missType = select(15, CombatLogGetCurrentEventInfo())
            end
            if missType == "DODGE" then
                overpowerExpireTime = now + OVERPOWER_DODGE_WINDOW
                overpowerDodgeGUID = destGUID
            end
        end
    end
end)

-- Silent controls only. WoW writes OliaArmsLog to the addon's SavedVariables
-- file on logout or /reload; no diagnostic data is sent to the chat frame.
SLASH_OLIAARMSLOG1 = "/armslog"
SlashCmdList["OLIAARMSLOG"] = function(message)
    local command = string.match(string.lower(message or ""), "^%s*(%S*)") or ""
    local log = EnsureArmsLog()

    if command == "on" then
        log.enabled = true
    elseif command == "off" then
        if armsPveFight then
            EndArmsPveFight(GetTime(), "logging_disabled")
        end
        log.enabled = false
    elseif command == "clear" then
        if armsPveFight then
            EndArmsPveFight(GetTime(), "log_cleared")
        end
        local wasEnabled = log.enabled
        OliaArmsLog = {version = ARMS_LOG_VERSION, enabled = wasEnabled, entries = {}, stats = {}}
        EnsureArmsLog()
    end
end

local function GetDebuffRemaining(unit, spellName)
    if not unit then return 0, 0, 0 end
    local traceStart = jungle.RaidTrace.sample and debugprofilestop()
    if jungle.RaidTrace.sample then jungle.RaidTrace:Count("warriorDebuffScans") end
    if not UnitExists(unit) then
        if traceStart then return jungle.RaidTrace:Finish("warriorDebuffScan", traceStart, 0, 0, 0) end
        return 0, 0, 0
    end
    for i = 1, 40 do
        if jungle.RaidTrace.sample then jungle.RaidTrace:Count("warriorDebuffSlots") end
        local name, _, count, _, duration, expirationTime = UnitAura(unit, i, "HARMFUL")
        if not name then break end
        if name == spellName then
            if expirationTime and expirationTime > 0 then 
                if traceStart then return jungle.RaidTrace:Finish("warriorDebuffScan", traceStart, expirationTime - GetTime(), count or 1, duration or 0) end
                return expirationTime - GetTime(), count or 1, duration or 0
            end
            if traceStart then return jungle.RaidTrace:Finish("warriorDebuffScan", traceStart, 999, count or 1, 999) end
            return 999, count or 1, 999
        end
    end
    if traceStart then return jungle.RaidTrace:Finish("warriorDebuffScan", traceStart, 0, 0, 0) end
    return 0, 0, 0
end

local function GetArmsCoreCooldown(spell, now, gcdStart, gcdDuration)
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    if not (not routineActions or routineActions[spell] ~= false) then return math.huge end
    local start, duration, enabled = GetSpellCooldown(spell)
    if not start or enabled == 0 then return math.huge end
    -- Only a matching active GCD is ignored. A short real cooldown must
    -- not disappear merely because its duration is below 1.5 seconds.
    if gcdStart and gcdStart > 0 and gcdDuration and gcdDuration > 0
        and math.abs(start - gcdStart) <= 0.05
        and math.abs((duration or 0) - gcdDuration) <= 0.05 then return 0 end
    return math.max(0, start + (duration or 0) - now)
end

local armsSlamTiming, thread3SlamTiming = {}, {}

-- Project the cost of inserting Slam rather than granting every after-swing
-- opportunity ownership of the GCD. Values are relative to this decision tick.
local function GetArmsSlamTiming(rage, isAoE, phase)
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    local now = GetTime()
    local gcdStart, gcdDuration = jungle.GetGCDValues()
    local gcdRemaining = gcdStart and gcdStart > 0 and gcdDuration
        and math.max(0, gcdStart + gcdDuration - now) or 0
    if not (not routineActions or routineActions["Slam"] ~= false) then
        -- Keep actual GCD/queue/swing facts used by other actions, without
        -- projecting a disabled Slam cast or reserving its future window.
        local timing = phase and thread3SlamTiming or armsSlamTiming
        for key in pairs(timing) do timing[key] = nil end
        timing.start, timing.release = gcdRemaining, gcdRemaining + 1.5
        timing.oldSwing = jungle.SwingTimer:GetSlamTimeRemaining()
        timing.nextSwing = timing.oldSwing
        timing.queuedCost = C_Spell.IsCurrentSpell('Cleave') and CLEAVE_RAGE_COST
            or (C_Spell.IsCurrentSpell('Heroic Strike') and HEROIC_STRIKE_RAGE_COST or 0)
        timing.ms = warriorCapabilities.hasMortalStrike and GetArmsCoreCooldown('Mortal Strike', now, gcdStart, gcdDuration) or math.huge
        timing.ww = GetArmsCoreCooldown('Whirlwind', now, gcdStart, gcdDuration)
        timing.allowed, timing.reason = false, 'disabled'
        return timing
    end
    local _, _, homeLatency, worldLatency = GetNetStats()
    local safety = math.max(SLAM_PRE_SWING_BUFFER, (worldLatency or homeLatency or 0) / 1000)
    local _, _, _, castMS = GetSpellInfo('Slam')
    local castTime = castMS and castMS > 0 and castMS / 1000 or 0.5
    local timing = phase and thread3SlamTiming or armsSlamTiming
    for key in pairs(timing) do timing[key] = nil end
    timing.start, timing.queuedCost = gcdRemaining + safety, 0
    -- TBC melee GCD/Slam cast are not shortened by attack-speed haste.
    timing.release = timing.start + math.max(1.5, castTime)
    timing.nextSwing = timing.start + castTime + (UnitAttackSpeed('player') or 3.0)
    timing.oldSwing = jungle.SwingTimer:GetSlamTimeRemaining()
    timing.swingDelay = math.max(0, timing.nextSwing - timing.oldSwing)
    if C_Spell.IsCurrentSpell('Cleave') then
        timing.queuedCost = CLEAVE_RAGE_COST
    elseif C_Spell.IsCurrentSpell('Heroic Strike') then
        timing.queuedCost = HEROIC_STRIKE_RAGE_COST
    end
    timing.ms = warriorCapabilities.hasMortalStrike and GetArmsCoreCooldown('Mortal Strike', now, gcdStart, gcdDuration) or math.huge
    timing.ww = GetSpellBookItemInfo('Whirlwind') and GetArmsCoreCooldown('Whirlwind', now, gcdStart, gcdDuration) or math.huge
    timing.msDelay = math.max(0, timing.release - math.max(timing.start, timing.ms))
    timing.wwDelay = math.max(0, timing.release - math.max(timing.start, timing.ww))
    timing.ss = isAoE and phase ~= 'burst' and warriorCapabilities.hasSweepingStrikes
        and jungle.WarriorRoutineOptionEnabled('sweeping')
        and not jungle.unitCacheBuff('player', 'Sweeping Strikes')
        and GetArmsCoreCooldown('Sweeping Strikes', now, gcdStart, gcdDuration) or math.huge
    if not jungle.SwingTimer:IsMainhandTimingReliable() then
        timing.reason = 'swing_unknown'
    elseif armsLastMainhandSwingTime <= 0
        or now - armsLastMainhandSwingTime + timing.start > SLAM_AFTERSWING_WINDOW then
        timing.reason = 'gcd_outside_slam_window'
    elseif phase == 'pooling' then
        -- Keep the existing 80-rage activation threshold and pre-swing SS
        -- timing. Do not assume the postponed white hit will fund the burst.
        timing.burstBefore = math.max(gcdRemaining, timing.oldSwing - THREAD3_PRE_SWING_WINDOW)
        timing.burstAfter = math.max(timing.release, timing.nextSwing - THREAD3_PRE_SWING_WINDOW)
        if rage - ARMS_PVE_SLAM_RAGE_COST - timing.queuedCost < 80 then
            timing.reason = 'burst_rage'
        elseif timing.burstAfter > timing.burstBefore + 0.001 then
            timing.reason = 'burst_delay'
        end
    else
        local protectMS = not isAoE or rage >= ARMS_PVE_SWEEPING_MS_RAGE_THRESHOLD
        local reserve = timing.queuedCost
        if protectMS and timing.ms <= timing.nextSwing + safety then
            reserve = reserve + ARMS_PVE_MORTAL_STRIKE_RAGE_COST
        end
        if timing.ww <= timing.nextSwing + safety then
            reserve = reserve + ARMS_PVE_WHIRLWIND_RAGE_COST
        end
        if timing.ss <= timing.nextSwing + safety then
            reserve = reserve + ARMS_PVE_SWEEPING_STRIKES_RAGE_COST
        end
        if timing.ss < timing.release then
            timing.reason = 'sweeping_strikes_delay'
        elseif timing.wwDelay > 0.001 then
            timing.reason = 'whirlwind_delay'
        elseif protectMS and timing.msDelay > 0.001 then
            timing.reason = 'mortal_strike_delay'
        elseif rage - ARMS_PVE_SLAM_RAGE_COST < reserve then
            timing.reason = 'core_rage'
        end
    end
    timing.allowed = timing.reason == nil
    if jungle.RaidTrace.sample then
        jungle.RaidTrace:Count('slamPlan_' .. (phase or 'normal') .. '_' .. (timing.reason or 'allowed'))
        jungle.RaidTrace:Detail('slamProjectedMSDelaySeconds', timing.msDelay)
        jungle.RaidTrace:Detail('slamProjectedWWDelaySeconds', timing.wwDelay)
        jungle.RaidTrace:Detail('slamProjectedSwingDelaySeconds', timing.swingDelay)
    end
    return timing
end

-- Read-only timing shared by the damage rotation and Thread 1 maintenance.
local noSlamState = {
    hasPendingSlam=false, activeSlamWindow=0, stationaryForSlam=false, slamRageThreshold=0,
    hasSlamRageNow=false, canSlamAfterSwing=false, useSlamWindow=false, reserveSlamWindow=false,
    useCoreFirstForHaste=false, reserveInitialSwingForSlam=false, reserveSlamPreSwing=false,
    coreGCDWouldClipSlam=false, holdGCDForSlam=false, blockCoreForSlam=false,
}
local function GetArmsPveSlamState(hasEnemy, inMeleeRange, rage, isAoE, useCoreFirstAoE)
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    if not (not routineActions or routineActions["Slam"] ~= false) then
        local now = GetTime()
        noSlamState.mainhandSpeed = UnitAttackSpeed("player") or 3.0
        noSlamState.timeSinceSwing = armsLastMainhandSwingTime > 0 and now - armsLastMainhandSwingTime or 999
        noSlamState.isAutoAttacking = C_Spell.IsCurrentSpell(6603)
            or (armsLastMainhandSwingTime > 0 and noSlamState.timeSinceSwing <= noSlamState.mainhandSpeed + .25)
        -- A real in-progress cast remains protected; no prospective Slam window is evaluated.
        noSlamState.isCastingSlam = UnitCastingInfo("player") == "Slam"
        noSlamState.holdGCDForSlam, noSlamState.blockCoreForSlam = noSlamState.isCastingSlam, noSlamState.isCastingSlam
        local start, duration = jungle.GetGCDValues()
        noSlamState.expectedGCD = duration and duration > 0 and duration or 1.5
        noSlamState.gcdRemaining = start and start > 0 and math.max(0,start + (duration or 0) - now) or 0
        return noSlamState
    end
    local canUseImprovedSlam = CanUseImprovedSlam()
    local reliableSwingTiming = jungle.SwingTimer:IsMainhandTimingReliable()
    local mainhandSpeed = UnitAttackSpeed("player") or 3.0
    -- Slam should be tied to a confirmed mainhand/HS/Cleave swing, not Slam's own damage event.
    local timeSinceSwing = armsLastMainhandSwingTime > 0 and (GetTime() - armsLastMainhandSwingTime) or 999
    local timeSinceGapCloser = armsLastGapCloserTime > 0 and (GetTime() - armsLastGapCloserTime) or 999
    local waitingForGapCloserSwing = (hasEnemy and armsGapCloserPendingSwing and timeSinceGapCloser <= SLAM_GAP_CLOSER_WAIT_TIMEOUT)
    local apiAutoAttacking = C_Spell.IsCurrentSpell(6603) or false
    local recentlyConfirmedSwing = (armsLastMainhandSwingTime > 0 and timeSinceSwing <= (mainhandSpeed + 0.25))
    local isAutoAttacking = (apiAutoAttacking or recentlyConfirmedSwing)
    local hasPendingSlam = (armsLastMainhandSwingTime > armsLastSlammedSwingTime)
    local activeSlamWindow = armsLastMainhandWasGapCloserSwing and SLAM_GAP_CLOSER_AFTERSWING_WINDOW or SLAM_AFTERSWING_WINDOW
    local upcomingSlamWindow = waitingForGapCloserSwing and SLAM_GAP_CLOSER_AFTERSWING_WINDOW or SLAM_AFTERSWING_WINDOW
    local isAfterswingWindow = (hasPendingSlam and not waitingForGapCloserSwing and timeSinceSwing >= 0 and timeSinceSwing <= activeSlamWindow)
    local armsTimeRemaining = (reliableSwingTiming and armsLastMainhandSwingTime > 0 and not waitingForGapCloserSwing) and jungle.SwingTimer:GetSlamTimeRemaining() or 999
    local isCastingSlam = (UnitCastingInfo("player") == "Slam")
    local playerSpeed = GetUnitSpeed("player") or 0
    local stationaryForSlam = playerSpeed <= SLAM_STATIONARY_SPEED_MAX
    local slamRageThreshold = GetImprovedSlamRageThreshold(isAoE)
    local hasSlamRageNow = rage >= slamRageThreshold
    local gcdStart, gcdDuration = jungle.GetGCDValues()
    local expectedGCD = ((gcdDuration and gcdDuration > 0) and gcdDuration or 1.5)
    local gcdRemaining = (gcdStart and gcdStart > 0 and gcdDuration and gcdDuration > 0) and math.max(0, (gcdStart + gcdDuration) - GetTime()) or 0
    local _, _, latencyHome = GetNetStats()
    local slamTimingSafety = math.max(SLAM_PRE_SWING_BUFFER, (latencyHome or 0) / 1000)
    local maxCoreGCDOverrunAfterSwing = math.max(0, upcomingSlamWindow - slamTimingSafety)
    local canSlamAfterSwing = (hasEnemy and canUseImprovedSlam and isAutoAttacking and isAfterswingWindow and stationaryForSlam and not isCastingSlam and ReadyCastSpellNoGCD('Slam'))
    local useSlamWindow = (canSlamAfterSwing and inMeleeRange and hasSlamRageNow)
    local reserveGapCloserMovingWindow = (canUseImprovedSlam and armsLastMainhandWasGapCloserSwing and isAutoAttacking and isAfterswingWindow and not stationaryForSlam and not isCastingSlam and inMeleeRange and hasSlamRageNow and ReadyCastSpellNoGCD('Slam', nil, true))
    local reserveSlamWindow = useSlamWindow or reserveGapCloserMovingWindow
    local slamReserveLead = math.max(slamTimingSafety, expectedGCD - maxCoreGCDOverrunAfterSwing)
    local _, _, _, slamCastTimeMs = GetSpellInfo('Slam')
    local slamBaseCastTime = (slamCastTimeMs and slamCastTimeMs > 0) and (slamCastTimeMs / 1000) or 0.5
    local slamCastTime = slamBaseCastTime -- TBC Slam is not spell-haste-scaled.
    local postSlamGCDRemaining = math.max(0, expectedGCD - slamCastTime)
    local slamCoreStartWindow = mainhandSpeed - postSlamGCDRemaining - slamReserveLead
    -- If there is not even one latency-safe opportunity to start a core action
    -- between Slam's GCD and the next reservation, switch to core-first mode.
    local useCoreFirstForHaste = (slamCoreStartWindow < slamTimingSafety)
    local canReserveUpcomingSlam = (canUseImprovedSlam and (isAutoAttacking or waitingForGapCloserSwing) and (stationaryForSlam or waitingForGapCloserSwing) and not isCastingSlam and inMeleeRange and (rage + SLAM_EXPECTED_SWING_RAGE) >= slamRageThreshold and ReadyCastSpellNoGCD('Slam', nil, true))
    local reserveInitialSwingForSlam = (reliableSwingTiming and canUseImprovedSlam and not waitingForGapCloserSwing and not recentlyConfirmedSwing and stationaryForSlam and not isCastingSlam and inMeleeRange and (rage + SLAM_EXPECTED_SWING_RAGE) >= slamRageThreshold and ReadyCastSpellNoGCD('Slam', nil, true))
    local reserveSlamPreSwing = (canReserveUpcomingSlam and not isAfterswingWindow and (waitingForGapCloserSwing or armsTimeRemaining <= slamReserveLead))
    local coreGCDWouldClipSlam = false
    if waitingForGapCloserSwing then
        coreGCDWouldClipSlam = true
    elseif armsTimeRemaining < 999 then
        local projectedCoreGCDAfterSwing = (gcdRemaining + expectedGCD) - armsTimeRemaining
        coreGCDWouldClipSlam = projectedCoreGCDAfterSwing > maxCoreGCDOverrunAfterSwing
    end

    local reserveSlamPreSwingCore = (canReserveUpcomingSlam and not isAfterswingWindow and coreGCDWouldClipSlam)
    -- Preserve legacy reservation behavior for other callers. Baseline/Sweeping
    -- apply projected core-delay and funding checks below.
    local holdGCDForSlam = isCastingSlam or useSlamWindow or (
        not useCoreFirstAoE
        and not useCoreFirstForHaste
        and (reserveInitialSwingForSlam or reserveSlamWindow or reserveSlamPreSwing)
    )
    local blockCoreForSlam = isCastingSlam or useSlamWindow or (
        not useCoreFirstAoE
        and not useCoreFirstForHaste
        and (reserveInitialSwingForSlam or reserveSlamWindow or reserveSlamPreSwingCore)
    )
    local timing
    if jungle.Engine and jungle.GetWarriorRoutineBehavior().projectedSlam then
        timing = GetArmsSlamTiming(rage, isAoE)
        canSlamAfterSwing = canSlamAfterSwing and timing.allowed
        useSlamWindow = canSlamAfterSwing and inMeleeRange and hasSlamRageNow
        reserveSlamWindow = useSlamWindow
        -- Do not hold ready core abilities for a speculative future Slam.
        reserveInitialSwingForSlam, reserveSlamPreSwing, coreGCDWouldClipSlam = false, false, false
        holdGCDForSlam = isCastingSlam or useSlamWindow
        blockCoreForSlam = holdGCDForSlam
    end
    return {
        timing = timing,
        mainhandSpeed = mainhandSpeed,
        timeSinceSwing = timeSinceSwing,
        isAutoAttacking = isAutoAttacking,
        hasPendingSlam = hasPendingSlam,
        activeSlamWindow = activeSlamWindow,
        isCastingSlam = isCastingSlam,
        stationaryForSlam = stationaryForSlam,
        slamRageThreshold = slamRageThreshold,
        hasSlamRageNow = hasSlamRageNow,
        expectedGCD = expectedGCD,
        gcdRemaining = gcdRemaining,
        canSlamAfterSwing = canSlamAfterSwing,
        useSlamWindow = useSlamWindow,
        reserveSlamWindow = reserveSlamWindow,
        useCoreFirstForHaste = useCoreFirstForHaste,
        reserveInitialSwingForSlam = reserveInitialSwingForSlam,
        reserveSlamPreSwing = reserveSlamPreSwing,
        coreGCDWouldClipSlam = coreGCDWouldClipSlam,
        holdGCDForSlam = holdGCDForSlam,
        blockCoreForSlam = blockCoreForSlam,
    }
end

local function UsesWarriorDemoFallback()
    return jungle.Engine and jungle.GetWarriorRoutineBehavior().demoFallback
end

local function CanUseWarriorFuryPveCore(target, isAoE, hasBloodthirst, rage)
    if not jungle.inMeleeRange(target) then return false end
    local strike = hasBloodthirst and 'Bloodthirst' or 'Mortal Strike'
    local strikeOnCD = not IsSpellOffRealCooldown(strike)
    local wwOnCD = not IsSpellOffRealCooldown('Whirlwind')
    local allowWW = not hasBloodthirst or strikeOnCD
    local allowStrike = hasBloodthirst or wwOnCD
    if isAoE then
        allowWW = not jungle.WarriorRoutineOptionEnabled("sweeping")
            or not IsSpellOffRealCooldown('Sweeping Strikes')
        allowStrike = wwOnCD and rage >= 50
    end
    return (allowWW and rage >= (isAoE and 37 or 25) and ReadyCastSpellNoGCD('Whirlwind'))
        or (allowStrike and rage >= (isAoE and 42 or 30) and ReadyCastSpellNoGCD(strike, target))
end

local function ShouldDeferWarriorPveMaintenanceDemo(target)
    if not UsesWarriorDemoFallback() then return false end
    if UnitCastingInfo("player") == "Slam" then return true end
    local enemiesNearby, sweepingEnemiesNearby = 0, 0
    local nameplates = C_NamePlate.GetNamePlates()
    if jungle.RaidTrace.sample then jungle.RaidTrace:Count("warriorNameplateVisits", #nameplates) end
    for i = 1, #nameplates do
        local unit = GetNameplateUnitToken(nameplates[i], i)
        if IsEnemyNameplateEligibleForAoE(unit) and CheckInteractDistance(unit, 3) then
            enemiesNearby = enemiesNearby + 1
            local maxHP = UnitHealthMax(unit)
            if maxHP > 0 and UnitHealth(unit) / maxHP > 0.2 then
                sweepingEnemiesNearby = sweepingEnemiesNearby + 1
            end
        end
    end
    local isAoE = enemiesNearby >= 2
    local rage = UnitPower("player", 1)
    if UsesWarriorFuryRotation() then
        return CanUseWarriorFuryPveCore(target, isAoE, warriorCapabilities.hasBloodthirst, rage)
    end
    local inMeleeRange = jungle.inMeleeRange(target)
    local slam = GetArmsPveSlamState(true, inMeleeRange, rage, isAoE, false)
    if slam.holdGCDForSlam or slam.blockCoreForSlam then return true end
    local msReady = warriorCapabilities.hasMortalStrike and ReadyCastSpellNoGCD('Mortal Strike', target)
    local wwReady = ReadyCastSpellNoGCD('Whirlwind')
    if not isAoE then return inMeleeRange and (msReady or wwReady) end
    local ssAvailable = sweepingEnemiesNearby >= 2
        and jungle.WarriorRoutineOptionEnabled("sweeping")
        and not jungle.unitCacheBuff('player', 'Sweeping Strikes')
        and ReadyCastSpellNoGCD('Sweeping Strikes')
    return inMeleeRange and wwReady and (not ssAvailable or rage >= 50)
end

-- Shared by maintenance and the corresponding combat fallback
-- routines so Demoralizing Shout keeps the same PvE refresh rule everywhere.
local function ShouldRefreshWarriorPveDemoralizingShout(target, inMeleeRange, allowPvp)
    return jungle.WarriorRoutineOptionEnabled("demo")
        and target ~= nil and UnitExists(target)
        and UnitCanAttack("player", target)
        and not UnitIsDeadOrGhost(target)
        and (allowPvp or (not UnitIsPlayer(target) and not UnitPlayerControlled(target)))
        and CanApplyWarriorTargetDebuff(target)
        and inMeleeRange
        and GetDebuffRemaining(target, 'Demoralizing Shout') <= 5
        and ReadyCastSpellNoGCD('Demoralizing Shout')
end

-- Arms PvE needs both armor debuffs together. Keep the legacy name/count/
-- expiration semantics while avoiding two independent 40-slot aura scans.
local function GetArmorDebuffState(unit)
    local traceStart = jungle.RaidTrace.sample and debugprofilestop()
    if jungle.RaidTrace.sample then jungle.RaidTrace:Count("warriorArmorScans") end
    if not UnitExists(unit) then
        if traceStart then return jungle.RaidTrace:Finish("warriorArmorScan", traceStart, 0, 0, 0) end
        return 0, 0, 0
    end

    local sunderFound = false
    local sunderExpirationTime = nil
    local sunderCount = 0
    local exposeFound = false
    local exposeExpirationTime = nil

    for i = 1, 40 do
        if jungle.RaidTrace.sample then jungle.RaidTrace:Count("warriorDebuffSlots") end
        local name, _, count, _, _, expirationTime = UnitAura(unit, i, "HARMFUL")
        if not name then break end

        if name == 'Sunder Armor' and not sunderFound then
            sunderFound = true
            sunderExpirationTime = expirationTime
            sunderCount = count or 1
        elseif name == 'Expose Armor' and not exposeFound then
            exposeFound = true
            exposeExpirationTime = expirationTime
        end

        if sunderFound and exposeFound then break end
    end

    local sunderRemaining = 0
    if sunderFound then
        sunderRemaining = (sunderExpirationTime and sunderExpirationTime > 0)
            and (sunderExpirationTime - GetTime())
            or 999
    end

    local exposeRemaining = 0
    if exposeFound then
        exposeRemaining = (exposeExpirationTime and exposeExpirationTime > 0)
            and (exposeExpirationTime - GetTime())
            or 999
    end

    if traceStart then return jungle.RaidTrace:Finish("warriorArmorScan", traceStart, sunderRemaining, sunderCount, exposeRemaining) end
    return sunderRemaining, sunderCount, exposeRemaining
end

local function InterruptListContains(list, spellName)
    if not list then return false end
    for i = 1, #list do
        if list[i] == spellName then
            return true
        end
    end
    return false
end

local function IsPriorityInterruptSpell(spellName)
    if not spellName then return false end

    local bigHeals = jungle.spellsBigHealsInterrupt
    local important = jungle.spellsImportantInterrupt
    local crowdControl = jungle.spellsCcInterrupt
    local hasConfiguredList = bigHeals or important or crowdControl

    if InterruptListContains(bigHeals, spellName) then return true end
    if InterruptListContains(important, spellName) then return true end
    if InterruptListContains(crowdControl, spellName) then return true end

    -- Preserve interrupt behavior if the shared priority data is unavailable.
    return not hasConfiguredList
end

function jungle.warriorTank(_target)
    -- WEAPON CHECK: Tank requires 1H + Shield
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    if not IsEquippedItemType("Shields") then
        if not (not routineActions or routineActions["EquipShield"] ~= false) then return emptyCache end
        equipCacheShield[1][3] = (not routineActions or routineActions[equipCacheShield[1][2]] ~= false) and (jungle.CanSwapWeapons())
        return equipCacheShield
    end

    local hasEnemy = _target ~= nil and UnitExists(_target)
        and UnitCanAttack("player", _target) and not UnitIsDeadOrGhost(_target)
    if not hasEnemy then _target = nil end

    local inCombat = UnitAffectingCombat("player")
    local rage = UnitPower("player", 1)
    local stance = GetShapeshiftForm()
    local canApplyTargetDebuff = CanApplyWarriorTargetDebuff(_target)
    
    -- 1. TALENT DETECTION
    local hasDevastate = IsPlayerSpell(20243) or IsSpellKnown(20243) or IsPlayerSpell(29888) or IsSpellKnown(29888) or IsPlayerSpell(30016) or IsSpellKnown(30016) or IsPlayerSpell(30022) or IsSpellKnown(30022) or GetSpellBookItemInfo("Devastate")
    local sunderAction = hasDevastate and (not routineActions or routineActions['Devastate'] ~= false) and 'Devastate' or 'Sunder Armor'

    local hasShieldSlam = IsPlayerSpell(23922) or IsSpellKnown(23922) or IsPlayerSpell(23923) or IsSpellKnown(23923) or IsPlayerSpell(23924) or IsSpellKnown(23924) or IsPlayerSpell(23925) or IsSpellKnown(23925) or GetSpellBookItemInfo("Shield Slam")
    local hasBloodthirst = IsPlayerSpell(23881) or IsPlayerSpell(23892) or IsPlayerSpell(23893) or IsPlayerSpell(23894) or IsPlayerSpell(25251) or IsPlayerSpell(30335)
    local hasMortalStrike = IsPlayerSpell(12294) or IsSpellKnown(12294) or GetSpellBookItemInfo("Mortal Strike")
    
    local heavyHitter = nil
    if hasShieldSlam and (not routineActions or routineActions["Shield Slam"] ~= false) then
        heavyHitter = 'Shield Slam'
    elseif hasBloodthirst and (not routineActions or routineActions["Bloodthirst"] ~= false) then
        heavyHitter = 'Bloodthirst'
    elseif hasMortalStrike and (not routineActions or routineActions["Mortal Strike"] ~= false) then
        heavyHitter = 'Mortal Strike'
    end

    warriorTankCache[18][2] = sunderAction
    warriorTankCache[22][2] = sunderAction
    if heavyHitter then
        warriorTankCache[17][1] = heavyHitter
        warriorTankCache[17][2] = heavyHitter
    else
        warriorTankCache[17][1] = 'None'
        warriorTankCache[17][2] = ''
    end
    
    -- 2. ENEMY COUNTING IN AOE RANGE
    local enemiesNearby = 0
    local enemiesTargetingMe = 0
    local enemiesWithSunder = 0
    local enemiesWithTC = 0
    local enemiesWithDemo = 0
    
    local nameplates = C_NamePlate.GetNamePlates()
    if jungle.RaidTrace.sample then jungle.RaidTrace:Count("warriorNameplateVisits", #nameplates) end
    for i = 1, #nameplates do
        local unit = GetNameplateUnitToken(nameplates[i], i)
        if IsEnemyNameplateEligibleForAoE(unit) and CheckInteractDistance(unit, 3) then
            local unitHPMax = UnitHealthMax(unit)
            local hpPercent = unitHPMax > 0 and (UnitHealth(unit) / unitHPMax * 100) or 100
            if hpPercent >= 20 then
                enemiesNearby = enemiesNearby + 1
                if UnitIsUnit(unit.."target", "player") then
                    enemiesTargetingMe = enemiesTargetingMe + 1
                end
                
                if GetDebuffRemaining(unit, 'Sunder Armor') > 0 or GetDebuffRemaining(unit, 'Expose Armor') > 0 then
                    enemiesWithSunder = enemiesWithSunder + 1
                end
                if jungle.Debuff('Thunder Clap', unit) then
                    enemiesWithTC = enemiesWithTC + 1
                end
                if HasAttackPowerDebuff(unit) then
                    enemiesWithDemo = enemiesWithDemo + 1
                end
            end
        end
    end

    if enemiesNearby < 1 and (hasEnemy and IsEnemyNameplateEligibleForAoE(_target)) and (hasEnemy and CheckInteractDistance(_target, 3)) then
        enemiesNearby = 1
        if (hasEnemy and UnitIsUnit(_target.."target", "player")) then
            enemiesTargetingMe = enemiesTargetingMe + 1
        end
    end
    
    if hasEnemy and enemiesNearby == 1 then
        enemiesWithSunder = (GetDebuffRemaining(_target, 'Sunder Armor') > 0 or GetDebuffRemaining(_target, 'Expose Armor') > 0) and 1 or 0
        enemiesWithTC = (hasEnemy and jungle.Debuff('Thunder Clap', _target)) and 1 or 0
        enemiesWithDemo = HasAttackPowerDebuff(_target) and 1 or 0
    end

    local canApplyAreaDebuff = canApplyTargetDebuff or (not hasEnemy and enemiesNearby > 0)
    local inAreaRange = (hasEnemy and CheckInteractDistance(_target, 3))
        or (not hasEnemy and enemiesNearby > 0)

    -- 3. GLOBAL DEFENSIVE & UTILITY
    local inChargeRange = ((hasEnemy and CheckInteractDistance(_target, 1)) and not (hasEnemy and jungle.inMeleeRange(_target)))
    
    local chargeOnCD = jungle.SpellOnCD("Charge")
    local interceptOnCD = jungle.SpellOnCD("Intercept")

    local wantCharge = ((not routineActions or routineActions["Charge"] ~= false) and not inCombat and inChargeRange and not chargeOnCD)
    
    local chargeStart, chargeDur = GetSpellCooldown("Charge")
    local recentlyCharged = (chargeStart and chargeStart > 0 and (GetTime() - chargeStart) <= 2)

    local wantIntercept = ((not routineActions or routineActions["Intercept"] ~= false) and (inCombat or chargeOnCD) and not recentlyCharged and inChargeRange and not interceptOnCD)
    local useCharge = (wantCharge and stance == 1 and (hasEnemy and jungle.ReadyCastSpell('Charge', _target)))
    local useBattleStanceForCharge = (wantCharge and stance ~= 1 and jungle.ReadyCastSpell('Battle Stance'))

    local useIntercept = (wantIntercept and stance == 3 and (hasEnemy and jungle.ReadyCastSpell('Intercept', _target)))
    local useZerkStanceForIntercept = (wantIntercept and stance ~= 3 and jungle.ReadyCastSpell('Berserker Stance'))

    local preZerkTC = false
    if canApplyTargetDebuff and useZerkStanceForIntercept and stance == 1 and enemiesNearby > 0 and inAreaRange then
        if jungle.ReadyCastSpell('Thunder Clap') then
            preZerkTC = true
            useZerkStanceForIntercept = false
        end
    end

    local needsStance = (stance ~= 2 and not wantCharge and not wantIntercept)
    local useDefStance = (needsStance and stance ~= 2 and jungle.ReadyCastSpell('Defensive Stance'))
    local preDefBR = false
    local preDefWW = false
    
    if useDefStance and stance == 3 then
        if jungle.ReadyCastSpell('Berserker Rage') then
            preDefBR = true
            useDefStance = false
        elseif jungle.ReadyCastSpell('Whirlwind') and enemiesNearby > 0 then
            preDefWW = true
            useDefStance = false
        end
    end

    local isTankingCurrentTarget = (hasEnemy and UnitIsUnit("player", _target.."target"))
    local haveRageForDump = (rage > 40)
    local canShieldBlock = (haveRageForDump or isTankingCurrentTarget)
    
    local useShieldBlock = (rage >= 10 and inCombat and enemiesTargetingMe > 0 and canShieldBlock and jungle.ReadyCastSpell('Shield Block'))

    local targetOfTarget = hasEnemy and (_target .. "target")
    local needsTaunt = false
    if canApplyTargetDebuff and inCombat and UnitExists(targetOfTarget) and not UnitIsUnit("player", targetOfTarget) then
        local isAnotherTank = (UnitGroupRolesAssigned(targetOfTarget) == 'TANK') or (GetPartyAssignment("MAINTANK", targetOfTarget) == true)
        if not isAnotherTank then
            needsTaunt = true
        end
    end

    local useBloodrage = (enemiesNearby > 0 and rage < 80 and jungle.ReadyCastSpell('Bloodrage'))

    local hasMyBattle = jungle.unitCacheBuff('player', 'Battle Shout', 'player')
    local hasMyBattleSafe = jungle.unitCacheBuff('player', 'Battle Shout', 'player', 5)
    local hasAnyCommandingSafe = jungle.unitCacheBuff('player', 'Commanding Shout', nil, 5)

    local useCommandingShout = false
    local useBattleShout = false

    if hasMyBattle then
        useBattleShout = (not hasMyBattleSafe and jungle.ReadyCastSpell('Battle Shout'))
    else
        useCommandingShout = (not hasAnyCommandingSafe and jungle.ReadyCastSpell('Commanding Shout'))
    end

    local isHSQueued = C_Spell.IsCurrentSpell("Heroic Strike") or false
    local isCleaveQueued = C_Spell.IsCurrentSpell("Cleave") or false

    local isSingle = (enemiesNearby == 1)
    local isAoE = (enemiesNearby > 1)
    
    local sunderRemaining, sunderCountAura = GetDebuffRemaining(_target, 'Sunder Armor')
    local exposeRemaining = GetDebuffRemaining(_target, 'Expose Armor')
    if exposeRemaining > 0 then
        sunderCountAura = 5
        sunderRemaining = 999
    end
    
    local tcStart, tcDuration = GetSpellCooldown("Thunder Clap")
    local tcOnCD = (tcStart and tcDuration > 2) or false
    
    local demoStart, demoDuration = GetSpellCooldown("Demoralizing Shout")
    local demoOnCD = (demoStart and demoDuration > 2) or false

    local needsSunderPriority = false
    local needsSunderStack = false
    
    local aoeDemoPriority = false
    local aoeTCPriority = false
    local isCleavePriority = false

    local fillDemo = false
    local fillTC = false

    if hasEnemy and isSingle then
        needsSunderPriority = (sunderCountAura == 0 or (sunderCountAura > 0 and sunderRemaining > 0 and sunderRemaining < 5))
        needsSunderStack = (sunderCountAura > 0 and (hasDevastate or sunderCountAura < 5))
        local hasOneSunder = (sunderCountAura >= 1)
        
        fillTC = hasOneSunder and not (hasEnemy and jungle.Debuff('Thunder Clap', _target))
        fillDemo = hasOneSunder and not ((hasEnemy and jungle.Debuff('Demoralizing Shout', _target)) or (hasEnemy and jungle.Debuff('Demoralizing Roar', _target)))
    else
        if enemiesNearby > 4 then
            if enemiesWithDemo >= math.ceil(enemiesNearby / 2) then
                isCleavePriority = true
            else
                aoeDemoPriority = true
            end
        else
            if enemiesWithTC >= math.ceil(enemiesNearby / 2) then
                isCleavePriority = true
            else
                aoeTCPriority = true
            end
        end

        needsSunderStack = (hasDevastate or sunderCountAura < 5)
        fillDemo = not ((hasEnemy and jungle.Debuff('Demoralizing Shout', _target)) or (hasEnemy and jungle.Debuff('Demoralizing Roar', _target)))
        fillTC = not (hasEnemy and jungle.Debuff('Thunder Clap', _target))
    end

    if not hasEnemy then
        fillDemo = enemiesNearby > 0 and enemiesWithDemo < enemiesNearby
        fillTC = enemiesNearby > 0 and enemiesWithTC < enemiesNearby
    end

    local currentBlock = false

    local allowAoEDemoPriority = false
    if (not routineActions or routineActions["Demoralizing Shout"] ~= false) and enemiesNearby > 0 and aoeDemoPriority and not currentBlock then
        allowAoEDemoPriority = true
        if not demoOnCD then currentBlock = true end
    end

    local allowAoETCPriority = false
    if (not routineActions or routineActions["Thunder Clap"] ~= false) and aoeTCPriority and not currentBlock and inAreaRange then
        allowAoETCPriority = true
        if not tcOnCD then currentBlock = true end
    end

    local wantCleavePriority = false
    if (not routineActions or routineActions["Cleave"] ~= false) and isCleavePriority and rage >= 20 then
        wantCleavePriority = true
    end

    local allowCleavePriority = false
    if wantCleavePriority and not isCleaveQueued then
        allowCleavePriority = true
    end

    local allowSB = true

    local allowHeavyHitter = heavyHitter and (not routineActions or routineActions[heavyHitter] ~= false) and hasEnemy and not currentBlock and (heavyHitter ~= nil)
    local hhOnCD = true
    if heavyHitter then
        hhOnCD = not jungle.IsSpellReadyIgnoreGCD(heavyHitter)
    end

    local hhCost = 20
    if heavyHitter == 'Bloodthirst' or heavyHitter == 'Mortal Strike' then hhCost = 30 end

    local waitRageForHH = (allowHeavyHitter and not hhOnCD and sunderCountAura >= 1 and rage < hhCost)
    if waitRageForHH then
        currentBlock = true
    end

    local allowSunderPriority = false
    if (not routineActions or routineActions[sunderAction] ~= false) and isSingle and needsSunderPriority and not currentBlock then
        allowSunderPriority = true
        currentBlock = true
    end

    local allowRevenge = hasEnemy and not currentBlock

    local allowFillDemo = false
    if (not routineActions or routineActions["Demoralizing Shout"] ~= false) and fillDemo and not currentBlock then
        allowFillDemo = true
        if not demoOnCD then currentBlock = true end
    end

    local allowFillTC = false
    if (not routineActions or routineActions["Thunder Clap"] ~= false) and fillTC and not currentBlock and inAreaRange then
        allowFillTC = true
        if not tcOnCD then currentBlock = true end
    end

    local allowSunderStack = false
    if (not routineActions or routineActions[sunderAction] ~= false) and hasEnemy and needsSunderStack and not currentBlock and hhOnCD then
        allowSunderStack = true
        currentBlock = true
    end

    local allowDump = not currentBlock

    -- 4. APPLY CACHE PRIORITIES
    for i = 1, #warriorTankCache do warriorTankCache[i][3] = false end

    -- Globals
    warriorTankCache[1][3] = (not routineActions or routineActions[warriorTankCache[1][2]] ~= false) and (useCharge)
    warriorTankCache[2][3] = (not routineActions or routineActions[warriorTankCache[2][2]] ~= false) and (useBattleStanceForCharge)
    warriorTankCache[3][3] = (not routineActions or routineActions[warriorTankCache[3][2]] ~= false) and (useIntercept)
    warriorTankCache[4][3] = (not routineActions or routineActions[warriorTankCache[4][2]] ~= false) and (canApplyTargetDebuff and preZerkTC)
    warriorTankCache[5][3] = (not routineActions or routineActions[warriorTankCache[5][2]] ~= false) and (useZerkStanceForIntercept)
    
    warriorTankCache[6][3] = (not routineActions or routineActions[warriorTankCache[6][2]] ~= false) and (preDefBR)
    warriorTankCache[7][3] = (not routineActions or routineActions[warriorTankCache[7][2]] ~= false) and (preDefWW)
    warriorTankCache[8][3] = (not routineActions or routineActions[warriorTankCache[8][2]] ~= false) and (useDefStance)
    
    warriorTankCache[9][3] = (not routineActions or routineActions[warriorTankCache[9][2]] ~= false) and (useBloodrage)
    warriorTankCache[10][3] = (not routineActions or routineActions[warriorTankCache[10][2]] ~= false) and (useCommandingShout)
    warriorTankCache[11][3] = (not routineActions or routineActions[warriorTankCache[11][2]] ~= false) and (useBattleShout)
    warriorTankCache[12][3] = (not routineActions or routineActions[warriorTankCache[12][2]] ~= false) and (useShieldBlock)
    warriorTankCache[13][3] = ((not routineActions or routineActions[warriorTankCache[13][2]] ~= false) and (canApplyTargetDebuff and needsTaunt and (hasEnemy and jungle.ReadyCastSpell('Taunt', _target))))

    if allowAoEDemoPriority then
        warriorTankCache[14][2] = 'Demoralizing Shout'
        warriorTankCache[14][3] = (not routineActions or routineActions[warriorTankCache[14][2]] ~= false) and (canApplyAreaDebuff and jungle.ReadyCastSpell('Demoralizing Shout'))
    elseif allowAoETCPriority then
        warriorTankCache[14][2] = 'Thunder Clap'
        warriorTankCache[14][3] = (not routineActions or routineActions[warriorTankCache[14][2]] ~= false) and (canApplyAreaDebuff and inAreaRange and jungle.ReadyCastSpell('Thunder Clap'))
    end

    warriorTankCache[15][3] = ((not routineActions or routineActions[warriorTankCache[15][2]] ~= false) and (allowCleavePriority and (hasEnemy and jungle.ReadyCastSpell('Cleave', _target))))
    warriorTankCache[16][3] = ((not routineActions or routineActions[warriorTankCache[16][2]] ~= false) and (allowSB and (hasEnemy and jungle.ReadyCastSpell('Shield Bash', _target)) and (hasEnemy and jungle.isCasting(_target))))
    warriorTankCache[17][3] = ((not routineActions or routineActions[warriorTankCache[17][2]] ~= false) and (allowHeavyHitter and heavyHitter and (hasEnemy and jungle.ReadyCastSpell(heavyHitter, _target)) or false))
    warriorTankCache[18][3] = ((not routineActions or routineActions[warriorTankCache[18][2]] ~= false) and (canApplyTargetDebuff and allowSunderPriority and (hasEnemy and jungle.ReadyCastSpell(sunderAction, _target))))
    warriorTankCache[19][3] = ((not routineActions or routineActions[warriorTankCache[19][2]] ~= false) and (allowRevenge and (hasEnemy and jungle.ReadyCastSpell('Revenge', _target))))
    warriorTankCache[20][3] = ((not routineActions or routineActions[warriorTankCache[20][2]] ~= false) and (canApplyAreaDebuff and allowFillDemo and jungle.ReadyCastSpell('Demoralizing Shout')))
    warriorTankCache[21][3] = ((not routineActions or routineActions[warriorTankCache[21][2]] ~= false) and (canApplyAreaDebuff and allowFillTC and inAreaRange and jungle.ReadyCastSpell('Thunder Clap')))
    warriorTankCache[22][3] = ((not routineActions or routineActions[warriorTankCache[22][2]] ~= false) and (canApplyTargetDebuff and allowSunderStack and (hasEnemy and jungle.ReadyCastSpell(sunderAction, _target))))

    local mainhandTimeRemaining = jungle.SwingTimer:GetTimeRemaining()
    local isAttacking = C_Spell.IsCurrentSpell(6603) or false
    
    local wantCleaveDump = false
    local wantHSDump = false
    
    if isAoE and rage > 40 then
        wantCleaveDump = true
    elseif isSingle then
        if rage >= 50 or (hhOnCD and rage >= 30) then
            wantHSDump = true
        end
    end

    local playerHPMax = UnitHealthMax("player")
    local targetHPPercent = playerHPMax > 0 and (UnitHealth("player") / playerHPMax) or 1
    local inMeleeRange = (hasEnemy and jungle.inMeleeRange(_target))
    local useTrinkets = jungle.AreTrinketsReady() and inCombat and inMeleeRange and (enemiesTargetingMe >= 3 or targetHPPercent < 0.7)

    local doStopCasting = false
    if isHSQueued or isCleaveQueued then
        if not isAttacking or not inMeleeRange then
            doStopCasting = true
        elseif mainhandTimeRemaining < 0.5 then
            if isHSQueued and not wantHSDump then
                doStopCasting = true
            elseif isCleaveQueued and not wantCleaveDump then
                doStopCasting = true
            end
        end
    end

    warriorTankCache[23][1] = 'Stopcasting'
    warriorTankCache[23][2] = 'Stopcasting'
    warriorTankCache[23][3] = (not routineActions or routineActions[warriorTankCache[23][2]] ~= false) and (doStopCasting)
    warriorTankCache[24][3] = (not routineActions or routineActions[warriorTankCache[24][2]] ~= false) and (useTrinkets)

    if isAttacking and inMeleeRange then
        if wantCleaveDump and not isCleaveQueued then
            warriorTankCache[25][3] = ((not routineActions or routineActions[warriorTankCache[25][2]] ~= false) and (hasEnemy and jungle.ReadyCastSpell('Cleave', _target)))
        elseif wantHSDump and not isHSQueued and mainhandTimeRemaining <= 0.4 then
            warriorTankCache[26][3] = ((not routineActions or routineActions[warriorTankCache[26][2]] ~= false) and (hasEnemy and jungle.ReadyCastSpell('Heroic Strike', _target)))
        end
    end
    
    warriorTankCache[27][3] = ((not routineActions or routineActions[warriorTankCache[27][2]] ~= false) and (not isAttacking and inMeleeRange)) -- Attack

    return warriorTankCache
end

local warriorFuryPvPCache = {
    [1]  = {'Stopcasting', 'Stopcasting', false, 1, 0},
    [2]  = {'Stopattack', 'Stopattack', false, 1, 0},
    [3]  = {'Attack', 'Attack', false, 1, 0},
    [4]  = {'Queue Heroic Strike', 'Heroic Strike', false, 1, 0},
    [5]  = {'Charge', 'Charge', false, 1, 0},
    [6]  = {'Battle Stance', 'Battle Stance', false, 1, 0},
    [7]  = {'Intercept', 'Intercept', false, 1, 0},
    [8]  = {'Pre-Zerk: Execute', 'Execute', false, 1, 0},
    [9]  = {'Pre-Zerk: Bloodthirst', 'Bloodthirst', false, 1, 0},
    [10] = {'Pre-Zerk: TC', 'Thunder Clap', false, 1, 0},
    [11] = {'Berserker Stance', 'Berserker Stance', false, 1, 0},
    [12] = {'Bloodrage', 'Bloodrage', false, 1, 0},
    [13] = {'Berserker Rage', 'Berserker Rage', false, 1, 0},
    [14] = {'Battle Shout', 'Battle Shout', false, 1, 0},
    [15] = {'Rampage', 'Rampage', false, 1, 0},
    [16] = {'Sweeping Strikes', 'Sweeping Strikes', false, 1, 0},
    [17] = {'Victory Rush', 'Victory Rush', false, 1, 0},
    [18] = {'Execute', 'Execute', false, 1, 0},
    [19] = {'Sunder Armor', 'Sunder Armor', false, 1, 0},
    [20] = {'Whirlwind (AoE)', 'Whirlwind', false, 1, 0},
    [21] = {'Bloodthirst (AoE)', 'Bloodthirst', false, 1, 0},
    [22] = {'Bloodthirst (Single)', 'Bloodthirst', false, 1, 0},
    [23] = {'Whirlwind (Single)', 'Whirlwind', false, 1, 0},
    [24] = {'Hamstring', 'Hamstring', false, 1, 0},
    [25] = {'Piercing Howl', 'Piercing Howl', false, 1, 0},
    [26] = {'Cleave', 'Cleave', false, 1, 0},
    [27] = {'Heroic Strike', 'Heroic Strike', false, 1, 0},
    [28] = {'Trinkets', 'Trinkets', false, 1, 0},
}

local warriorFuryCache = {
    -- --- SINGLE TARGET PRIORITIES (Super High) ---
    [1]  = {'Oneshot Execute', 'Execute', false, 1, 0},
    [2]  = {'Bloodthirst (Single)', 'Bloodthirst', false, 1, 0},
    [3]  = {'Whirlwind (Single)', 'Whirlwind', false, 1, 0},
    [4]  = {'Execute (Mortal Strike)', 'Execute', false, 1, 0},
    [5]  = {'Execute', 'Execute', false, 1, 0},
    
    -- --- AOE TARGET PRIORITIES (Super High) ---
    [6]  = {'Sweeping Strikes', 'Sweeping Strikes', false, 1, 0},
    [7]  = {'Whirlwind (AoE)', 'Whirlwind', false, 1, 0},
    [8]  = {'Cleave', 'Cleave', false, 1, 0},
    [9]  = {'Execute (AoE)', 'Execute', false, 1, 0},
    [10]  = {'Bloodthirst (AoE)', 'Bloodthirst', false, 1, 0},

    -- --- UTILITIES / STANCES / RAGE ---
    [11]  = {'Stopcasting', 'Stopcasting', false, 1, 0},
    [12]  = {'Queue Heroic Strike', 'Heroic Strike', false, 1, 0},
    [13]  = {'Interrupt Stance', 'Berserker Stance', false, 1, 0},
    [14]  = {'Interrupt', 'Pummel', false, 1, 0},
    [15]  = {'Stopattack', 'Stopattack', false, 1, 0},
    [16]  = {'Attack', 'Attack', false, 1, 0},
    [17]  = {'Charge', 'Charge', false, 1, 0},
    [18]  = {'Battle Stance', 'Battle Stance', false, 1, 0},
    [19]  = {'Intercept', 'Intercept', false, 1, 0},
    [20]  = {'Pre-Zerk: Execute', 'Execute', false, 1, 0},
    [21]  = {'Pre-Zerk: Bloodthirst', 'Bloodthirst', false, 1, 0},
    [22]  = {'Pre-Zerk: TC', 'Thunder Clap', false, 1, 0},
    [23]  = {'Berserker Stance', 'Berserker Stance', false, 1, 0},
    [24]  = {'Bloodrage', 'Bloodrage', false, 1, 0},
    [25]  = {'Berserker Rage', 'Berserker Rage', false, 1, 0},
    [26]  = {'Battle Shout', 'Battle Shout', false, 1, 0},
    
    -- --- LOWER PRIORITIES ---
    [27]  = {'Rampage', 'Rampage', false, 1, 0},
    [28]  = {'Victory Rush', 'Victory Rush', false, 1, 0},
    [29]  = {'Sunder Armor', 'Sunder Armor', false, 1, 0},
    [30]  = {'Demoralizing Shout', 'Demoralizing Shout', false, 1, 0},
    [31]  = {'Demoralizing Shout (ST)', 'Demoralizing Shout', false, 1, 0},
    [32]  = {'Heroic Strike', 'Heroic Strike', false, 1, 0},
    [33]  = {'Trinkets', 'Trinkets', false, 1, 0},
    [34]  = {'Overpower', 'Overpower', false, 1, 0},
}

local warriorFuryActiveCache = {}
for i = 1, 5 do
    warriorFuryActiveCache[i] = warriorFuryCache[i]
end
warriorFuryActiveCache[6] = warriorFuryCache[34]
for i = 6, 33 do
    warriorFuryActiveCache[i + 1] = warriorFuryCache[i]
end


-- =========================================================================
-- HEROIC STRIKE / CLEAVE ABUSE PRECISION CONFIG
-- =========================================================================
local HS_ABUSE_SAFETY_BUFFER = 0.40 -- Base safety buffer. Increase if you get accidental HS hits; decrease if offhand misses.
local HS_ABUSE_QUEUE_WINDOW  = 0.8  -- Window (in seconds) before offhand lands to start queueing.
-- =========================================================================

-- =========================================================================
-- DESYNC STATE MACHINE
-- =========================================================================
-- When MH and OH swing timers are synced (timeDiff < 0.5s), the HS abuse
-- window cannot open. We briefly StopAttack then StartAttack to reset the
-- swing timers and let the natural weapon speed difference (e.g. 2.7 vs 2.6)
-- create drift over subsequent cycles.
--
-- States: IDLE → STOPPED → COOLDOWN → IDLE
--   IDLE:     Normal operation, monitoring for synced swings
--   STOPPED:  StopAttack issued, waiting DESYNC_STOP_DURATION before restart
--   COOLDOWN: Restarted, waiting for timers to drift apart or timeout
-- =========================================================================
local DESYNC_IDLE     = 0
local DESYNC_STOPPED  = 1
local DESYNC_COOLDOWN = 2

local desyncState = DESYNC_IDLE
local desyncStateTime = 0
local DESYNC_STOP_DURATION     = 0.15  -- Brief pause to trigger timer reset (seconds)
local DESYNC_COOLDOWN_DURATION = 8.0   -- Don't retry desync for ~3 swing cycles

-- =========================================================================
-- "ON NEXT SWING" ABILITY CHECK (Heroic Strike / Cleave)
-- =========================================================================
-- These abilities are off-GCD, so ReadyCastSpell's GCD gating blocks them
-- incorrectly. This lightweight check only verifies:
--   1. Usable (correct stance, enough rage)
--   2. Not already queued (IsCurrentSpell)
--   3. In melee range (Hamstring range as proxy)
-- =========================================================================
local function IsNextSwingReady(spell, target)
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    if not (not routineActions or routineActions[spell] ~= false) then return false end
    local usable, noMana = IsUsableSpell(spell)
    local isCurrent = C_Spell.IsCurrentSpell(spell)
    local inRange = nil
    if target and target ~= 'player' then
        inRange = C_Spell.IsSpellInRange("Hamstring", target)
    end
    local rangeOK = (inRange == true or inRange == 1)
    if not rangeOK and inRange == nil then
        rangeOK = jungle.inMeleeRange(target)
    end

    if noMana then return false end
    if usable ~= true then return false end
    if isCurrent then return false end
    return rangeOK
end

function jungle.warriorFury(_target)
    -- WEAPON CHECK: Fury requires dual-wield weapons
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    local _, offSpeed = UnitAttackSpeed("player")
    if offSpeed == nil then
        if not (not routineActions or routineActions["EquipDW"] ~= false) then return emptyCache end
        equipCacheDW[1][3] = (not routineActions or routineActions[equipCacheDW[1][2]] ~= false) and (jungle.CanSwapWeapons())
        return equipCacheDW
    end

    local hasBloodthirst = IsPlayerSpell(23881) or IsPlayerSpell(23892) or IsPlayerSpell(23893) or IsPlayerSpell(23894) or IsPlayerSpell(25251) or IsPlayerSpell(30335)
    local hasMortalStrike = IsPlayerSpell(12294) or IsSpellKnown(12294) or GetSpellBookItemInfo("Mortal Strike")
    if not hasBloodthirst and not hasMortalStrike then return emptyCache end

    local furyStrike = hasBloodthirst and 'Bloodthirst' or 'Mortal Strike'

    local hasEnemy = _target ~= nil and UnitExists(_target)
        and UnitCanAttack("player", _target) and not UnitIsDeadOrGhost(_target)
    if not hasEnemy then _target = nil end

    if hasEnemy and (UnitIsPlayer(_target) or UnitPlayerControlled(_target)) then
        warriorFuryPvPCache[9][1] = 'Pre-Zerk: ' .. furyStrike
        warriorFuryPvPCache[9][2] = furyStrike
        warriorFuryPvPCache[21][1] = furyStrike .. ' (AoE)'
        warriorFuryPvPCache[21][2] = furyStrike
        warriorFuryPvPCache[22][1] = furyStrike .. ' (Single)'
        warriorFuryPvPCache[22][2] = furyStrike

        for i = 1, #warriorFuryPvPCache do warriorFuryPvPCache[i][3] = false end

        local inCombat = UnitAffectingCombat("player")
        local rage = UnitPower("player", 1)
        local stance = GetShapeshiftForm()
        local canApplyTargetDebuff = CanApplyWarriorTargetDebuff(_target)
        
        -- ENEMY COUNTING IN AOE RANGE (PVP: Players/Pets, No Totems)
        local enemiesNearby = 0
        local enemyPlayersNearby = 0
        local enemiesTargetingMe = 0
        local nameplates = C_NamePlate.GetNamePlates()
        if jungle.RaidTrace.sample then jungle.RaidTrace:Count("warriorNameplateVisits", #nameplates) end
        for i = 1, #nameplates do
            local unit = GetNameplateUnitToken(nameplates[i], i)
            if IsEnemyNameplateEligibleForAoE(unit) and CheckInteractDistance(unit, 3) then
                local isPlayer = UnitIsPlayer(unit)
                if isPlayer or UnitPlayerControlled(unit) then
                    enemiesNearby = enemiesNearby + 1
                    if isPlayer then
                        enemyPlayersNearby = enemyPlayersNearby + 1
                    end
                    if UnitIsUnit(unit.."target", "player") then
                        enemiesTargetingMe = enemiesTargetingMe + 1
                    end
                end
            end
        end

        if enemiesNearby < 1 and IsEnemyNameplateEligibleForAoE(_target) and CheckInteractDistance(_target, 3) then
            if UnitIsPlayer(_target) or UnitPlayerControlled(_target) then
                enemiesNearby = 1
                if UnitIsPlayer(_target) then
                    enemyPlayersNearby = 1
                end
                if UnitIsUnit(_target.."target", "player") then
                    enemiesTargetingMe = enemiesTargetingMe + 1
                end
            end
        end

        local isAoE = (enemiesNearby >= 2)
        local isSingle = (enemiesNearby == 1)

        local inChargeRange = (CheckInteractDistance(_target, 1) and not jungle.inMeleeRange(_target))
        
        local chargeOnCD = jungle.SpellOnCD("Charge")
        local interceptOnCD = jungle.SpellOnCD("Intercept")

        local wantCharge = ((not routineActions or routineActions["Charge"] ~= false) and not inCombat and inChargeRange and not chargeOnCD)
        if stance == 3 and rage >= 10 and not interceptOnCD then
            wantCharge = false
        end
        
        local chargeStart, chargeDur = GetSpellCooldown("Charge")
        local recentlyCharged = (chargeStart and chargeStart > 0 and (GetTime() - chargeStart) <= 2)

        local wantIntercept = ((not routineActions or routineActions["Intercept"] ~= false) and (inCombat or chargeOnCD or (stance == 3 and rage >= 10)) and not recentlyCharged and inChargeRange and not interceptOnCD)

        local useCharge = (wantCharge and stance == 1 and jungle.ReadyCastSpell('Charge', _target))
        local useBattleStanceForCharge = (wantCharge and stance ~= 1 and jungle.ReadyCastSpell('Battle Stance'))

        local useIntercept = (wantIntercept and stance == 3 and jungle.ReadyCastSpell('Intercept', _target))
        
        local useZerkStanceForIntercept = (wantIntercept and stance ~= 3 and jungle.ReadyCastSpell('Berserker Stance'))
        
        local inMeleeLocal = jungle.inMeleeRange(_target)
        local targetHPMaxForStance = UnitHealthMax(_target)
        local targetHPPercentLocal = targetHPMaxForStance > 0 and (UnitHealth(_target) / targetHPMaxForStance * 100) or 100
        
        local btReady = (jungle.IsSpellReadyIgnoreGCD(furyStrike))
        local executeReady = ((not routineActions or routineActions["Execute"] ~= false) and targetHPPercentLocal < 20)
        local tcReady = jungle.WarriorRoutineOptionEnabled("thunderClap") and canApplyTargetDebuff and jungle.IsSpellReadyIgnoreGCD("Thunder Clap")
        
        local delayZerkForBT = (stance == 1 and rage > 10 and btReady and inMeleeLocal)
        local delayZerkForExecute = ((not routineActions or routineActions["Execute"] ~= false) and stance == 1 and rage > 10 and executeReady and inMeleeLocal)
        local delayZerkForTC = (stance == 1 and rage > 10 and tcReady and CheckInteractDistance(_target, 3))
        
        local needsStance = (stance ~= 3 and not wantCharge and not wantIntercept)
        local useZerkStance = useZerkStanceForIntercept or (needsStance and jungle.ReadyCastSpell('Berserker Stance'))
        
        local preZerkExecute = false
        local preZerkBT = false
        local preZerkTC = false
        if useZerkStance and stance == 1 and not useZerkStanceForIntercept then
            if delayZerkForExecute and jungle.ReadyCastSpell('Execute', _target) then
                preZerkExecute = true
                useZerkStance = false
            elseif delayZerkForBT and jungle.ReadyCastSpell(furyStrike, _target) then
                preZerkBT = true
                useZerkStance = false
            elseif delayZerkForTC and jungle.ReadyCastSpell('Thunder Clap') then
                preZerkTC = true
                useZerkStance = false
            elseif (delayZerkForExecute or delayZerkForBT or delayZerkForTC) then
                useZerkStance = false
            end
        end

        local useBloodrage = false
        local useBerserkerRage = false -- Disabled for PvP Fury

        local inMeleeRange = jungle.inMeleeRange(_target)
        local inHamstringRange = false
        local hamstringRangeVal = C_Spell.IsSpellInRange("Hamstring", _target)
        if hamstringRangeVal ~= nil then
            inHamstringRange = (hamstringRangeVal == true or hamstringRangeVal == 1)
        else
            inHamstringRange = inMeleeRange
        end
        
        local targetHP = UnitHealth(_target)
        local targetHPMax = UnitHealthMax(_target)
        local targetHPPercent = targetHPMax > 0 and (targetHP / targetHPMax * 100) or 100

        local canExecute = ((not routineActions or routineActions["Execute"] ~= false) and targetHPPercent < 20 and inMeleeRange)
        
        local isTargetPlayer = UnitIsPlayer(_target) or UnitPlayerControlled(_target)
        local oneshotThreshold = isTargetPlayer and 2000 or 10000
        if canExecute and targetHP < oneshotThreshold and jungle.ReadyCastSpell('Execute', _target) then
            for i = 1, #warriorFuryPvPCache do warriorFuryPvPCache[i][3] = false end
            warriorFuryPvPCache[18][3] = (not routineActions or routineActions[warriorFuryPvPCache[18][2]] ~= false) and (true)
            return warriorFuryPvPCache
        end

        -- SLOW LOGIC
        -- Only apply slows when target has no slow or slow is about to expire (< 3s)
        -- This prevents spamming Hamstring/Piercing Howl over core damage abilities
        local needsSlow = false
        if UnitIsPlayer(_target) then
            local hasImmunity = jungle.isSlowProtected(_target)
            if not hasImmunity then
                local hasSlow = jungle.isSlowed(_target)
                if not hasSlow then
                    needsSlow = true
                else
                    -- Check remaining time on our slows specifically
                    local hamRemaining = GetDebuffRemaining(_target, 'Hamstring')
                    local phRemaining = GetDebuffRemaining(_target, 'Piercing Howl')
                    local bestSlowRemaining = math.max(hamRemaining, phRemaining)
                    -- Only refresh if our slow is about to expire and no other slow is active
                    if bestSlowRemaining > 0 and bestSlowRemaining < 3 then
                        needsSlow = true
                    end
                end
            end
        end

        local hasEvasion = jungle.unitCacheBuff(_target, "Evasion")
        local useHamstring = (needsSlow and inMeleeRange and not hasEvasion and enemyPlayersNearby < 2 and jungle.ReadyCastSpell('Hamstring', _target))
        local usePiercingHowl = (needsSlow and not useHamstring and jungle.ReadyCastSpell('Piercing Howl'))

        local shout, needsShout = jungle.GetWarriorDpsShout(5)

        -- CACHE ASSIGNMENT
        warriorFuryPvPCache[5][3] = (not routineActions or routineActions[warriorFuryPvPCache[5][2]] ~= false) and (useCharge)
        warriorFuryPvPCache[6][3] = (not routineActions or routineActions[warriorFuryPvPCache[6][2]] ~= false) and (useBattleStanceForCharge)
        warriorFuryPvPCache[7][3] = (not routineActions or routineActions[warriorFuryPvPCache[7][2]] ~= false) and (useIntercept)
        warriorFuryPvPCache[8][3] = (not routineActions or routineActions[warriorFuryPvPCache[8][2]] ~= false) and (preZerkExecute)
        warriorFuryPvPCache[9][3] = (not routineActions or routineActions[warriorFuryPvPCache[9][2]] ~= false) and (preZerkBT)
        warriorFuryPvPCache[10][3] = (not routineActions or routineActions[warriorFuryPvPCache[10][2]] ~= false) and (canApplyTargetDebuff and preZerkTC)
        warriorFuryPvPCache[11][3] = (not routineActions or routineActions[warriorFuryPvPCache[11][2]] ~= false) and (useZerkStance or useZerkStanceForIntercept)
        warriorFuryPvPCache[12][3] = (not routineActions or routineActions[warriorFuryPvPCache[12][2]] ~= false) and (useBloodrage)
        warriorFuryPvPCache[13][3] = (not routineActions or routineActions[warriorFuryPvPCache[13][2]] ~= false) and (useBerserkerRage)
        warriorFuryPvPCache[14][1] = shout
        warriorFuryPvPCache[14][2] = shout
        warriorFuryPvPCache[14][3] = (not routineActions or routineActions[warriorFuryPvPCache[14][2]] ~= false) and (needsShout and jungle.ReadyCastSpell(shout))
        warriorFuryPvPCache[15][3] = ((not routineActions or routineActions[warriorFuryPvPCache[15][2]] ~= false) and (inCombat and jungle.ReadyCastSpell('Rampage') and not jungle.unitCacheBuff('player', 'Rampage', nil, 5)))
        
        local sunderRemaining, sunderCountAura = GetDebuffRemaining(_target, 'Sunder Armor')
        local exposeRemaining = GetDebuffRemaining(_target, 'Expose Armor')
        if exposeRemaining > 0 then
            sunderCountAura = 5
            sunderRemaining = 999
        end
        local needsSunderPriority = (sunderCountAura > 0 and sunderRemaining > 0 and sunderRemaining < 5)

        warriorFuryPvPCache[16][3] = ((not routineActions or routineActions[warriorFuryPvPCache[16][2]] ~= false) and (jungle.WarriorRoutineOptionEnabled("sweeping") and isAoE and jungle.ReadyCastSpell('Sweeping Strikes')))
        warriorFuryPvPCache[17][3] = ((not routineActions or routineActions[warriorFuryPvPCache[17][2]] ~= false) and (inMeleeRange and jungle.ReadyCastSpell('Victory Rush', _target)))
        warriorFuryPvPCache[18][3] = ((not routineActions or routineActions[warriorFuryPvPCache[18][2]] ~= false) and (canExecute and jungle.ReadyCastSpell('Execute', _target)))
        warriorFuryPvPCache[19][3] = ((not routineActions or routineActions[warriorFuryPvPCache[19][2]] ~= false) and (jungle.WarriorRoutineOptionEnabled("sunderStack") and canApplyTargetDebuff and needsSunderPriority and inMeleeRange and jungle.ReadyCastSpell('Sunder Armor', _target)))
        
        local btOnCD = jungle.SpellOnCD(furyStrike)
        local wwOnCD = jungle.SpellOnCD("Whirlwind")
        local hasSSBuff = jungle.unitCacheBuff('player', 'Sweeping Strikes')
        local isCleaveQueuedLocal = C_Spell.IsCurrentSpell("Cleave") or false

        local allowBTAoE = wwOnCD
        if hasSSBuff then
            allowBTAoE = wwOnCD and (rage > 50 or isCleaveQueuedLocal)
        end

        warriorFuryPvPCache[20][3] = ((not routineActions or routineActions[warriorFuryPvPCache[20][2]] ~= false) and (isAoE and jungle.ReadyCastSpell('Whirlwind')))
        warriorFuryPvPCache[21][3] = ((not routineActions or routineActions[warriorFuryPvPCache[21][2]] ~= false) and (isAoE and allowBTAoE and inMeleeRange and jungle.ReadyCastSpell(furyStrike, _target)))
        
        warriorFuryPvPCache[22][3] = ((not routineActions or routineActions[warriorFuryPvPCache[22][2]] ~= false) and (isSingle and inMeleeRange and jungle.ReadyCastSpell(furyStrike, _target)))
        warriorFuryPvPCache[23][3] = ((not routineActions or routineActions[warriorFuryPvPCache[23][2]] ~= false) and (isSingle and btOnCD and jungle.ReadyCastSpell('Whirlwind')))
        
        warriorFuryPvPCache[24][3] = (not routineActions or routineActions[warriorFuryPvPCache[24][2]] ~= false) and (useHamstring)
        warriorFuryPvPCache[25][3] = (not routineActions or routineActions[warriorFuryPvPCache[25][2]] ~= false) and (usePiercingHowl)

        local offhandTimeRemaining = jungle.SwingTimer:GetOffhandTimeRemaining()
        local mainhandTimeRemaining = jungle.SwingTimer:GetTimeRemaining()

        local queueHS = false
        local doStopCasting = false
        local isAttacking = C_Spell.IsCurrentSpell(6603)
        local isHSQueued = C_Spell.IsCurrentSpell("Heroic Strike")
        
        local wantCleave = false
        if isAoE and not canExecute then
            if hasSSBuff then
                wantCleave = (rage >= 20)
            else
                wantCleave = (btOnCD and wwOnCD)
            end
        end
        local wantHS = isSingle and not canExecute and (rage > 60 or (rage >= 42 and btOnCD and wwOnCD))

        local _, _, _, latencyHome = GetNetStats()
        local latency = (latencyHome or 50) / 1000
        local safetyBuffer = HS_ABUSE_SAFETY_BUFFER + latency

        -- =============================================
        -- STEP 1: CANCEL LOGIC (evaluated first)
        -- =============================================
        if isHSQueued or isCleaveQueuedLocal then
            if not isAttacking or not inMeleeRange then
                doStopCasting = true
            elseif mainhandTimeRemaining < 0.5 then
                local meetCleaveCondition = (isAoE and wantCleave)
                local meetHSCondition = (isSingle and wantHS)
                local isAbuseOnly = (isHSQueued and not wantHS) or (isCleaveQueuedLocal and not wantCleave)
                
                -- HARD SAFEGUARD: At < 0.4s, cancel everything we don't want as a rage dump
                if mainhandTimeRemaining < 0.4 then
                    if isHSQueued and not meetHSCondition then
                        doStopCasting = true
                    elseif isCleaveQueuedLocal and not meetCleaveCondition then
                        doStopCasting = true
                    end
                end
                
                -- SOFT ZONE (0.4-0.5s): Only cancel rage-dump mismatches, NOT abuse queues
                if not doStopCasting and not isAbuseOnly then
                    local inOffhandWindow = (offhandTimeRemaining < HS_ABUSE_QUEUE_WINDOW and (mainhandTimeRemaining > offhandTimeRemaining + safetyBuffer))
                    local isSynced = (math.abs(mainhandTimeRemaining - offhandTimeRemaining) < 0.5)
                    local offhandJustLanded = (jungle.SwingTimer:GetOffhandTimeSinceLastSwing() < 0.2)
                    
                    if offhandJustLanded then
                        if isHSQueued and not meetHSCondition then
                            doStopCasting = true
                        elseif isCleaveQueuedLocal and not meetCleaveCondition then
                            doStopCasting = true
                        end
                    elseif not inOffhandWindow and not isSynced then
                        if isHSQueued and not meetHSCondition then
                            doStopCasting = true
                        elseif isCleaveQueuedLocal and not meetCleaveCondition then
                            doStopCasting = true
                        end
                    end
                end
            end
        end

        -- Post-cancel effective state
        local effectiveHSQueued = isHSQueued and not doStopCasting
        local effectiveCleaveQueued = isCleaveQueuedLocal and not doStopCasting

        -- =============================================
        -- STEP 2: QUEUE LOGIC (uses post-cancel state)
        -- =============================================
        if offhandTimeRemaining < HS_ABUSE_QUEUE_WINDOW and (mainhandTimeRemaining > offhandTimeRemaining + safetyBuffer) and isAttacking and inMeleeRange and rage >= 12 then
            if isAoE then
                if not effectiveCleaveQueued and not effectiveHSQueued and rage < 20 then
                    queueHS = true
                end
            else
                if not effectiveHSQueued then
                    queueHS = true
                end
            end
        end

        -- =============================================
        -- STEP 3: CACHE ASSIGNMENTS
        -- =============================================
        warriorFuryPvPCache[1][3] = (not routineActions or routineActions[warriorFuryPvPCache[1][2]] ~= false) and (doStopCasting)
        warriorFuryPvPCache[4][1] = 'Queue Heroic Strike'
        warriorFuryPvPCache[4][2] = 'Heroic Strike'
        warriorFuryPvPCache[4][3] = ((not routineActions or routineActions[warriorFuryPvPCache[4][2]] ~= false) and (queueHS and IsNextSwingReady('Heroic Strike', _target)))

        -- Rage dump queue — uses effective post-cancel state
        if isAttacking and inMeleeRange then
            if wantCleave and not effectiveCleaveQueued then
                warriorFuryPvPCache[26][3] = (not routineActions or routineActions[warriorFuryPvPCache[26][2]] ~= false) and (IsNextSwingReady('Cleave', _target))
            elseif wantHS and not effectiveHSQueued and mainhandTimeRemaining <= 0.4 then
                warriorFuryPvPCache[27][3] = (not routineActions or routineActions[warriorFuryPvPCache[27][2]] ~= false) and (IsNextSwingReady('Heroic Strike', _target))
            end
        end
        
        local hasTrinketBuff = jungle.unitCacheBuff('player', 'Death Wish') or jungle.unitCacheBuff('player', 'Lightning Speed')
        warriorFuryPvPCache[28][3] = ((not routineActions or routineActions[warriorFuryPvPCache[28][2]] ~= false) and (jungle.AreTrinketsReady() and inCombat and inMeleeRange and not (canExecute and targetHP < 50000) and (hasTrinketBuff and true or false)))

        -- =============================================
        -- DESYNC STATE MACHINE + ATTACK CONTROL
        -- =============================================
        local wantStopattack = false
        local now = GetTime()
        local allowAttack = false

        if isAttacking then
            if not inHamstringRange then
                wantStopattack = true
            elseif inCombat and inHamstringRange and desyncState == DESYNC_IDLE then
                local timeDiff = math.abs(mainhandTimeRemaining - offhandTimeRemaining)
                if mainhandTimeRemaining > 0 and offhandTimeRemaining > 0 and timeDiff < 0.5 and not jungle.SwingTimer:IsTimerStale() then
                    wantStopattack = true
                    desyncState = DESYNC_STOPPED
                    desyncStateTime = now
                    jungle.SwingTimer:OnAttackStopped()
                    jungle.isSyncedDesyncTrigger = true
                end
            elseif desyncState == DESYNC_STOPPED then
                wantStopattack = true
            end
        else
            if desyncState == DESYNC_STOPPED then
                if (now - desyncStateTime) >= DESYNC_STOP_DURATION then
                    desyncState = DESYNC_COOLDOWN
                    desyncStateTime = now
                    allowAttack = inHamstringRange
                    if allowAttack then
                        jungle.SwingTimer:OnAttackStarted()
                    end
                end
            else
                allowAttack = inHamstringRange
                if desyncState == DESYNC_COOLDOWN then
                    local timeDiff = math.abs(mainhandTimeRemaining - offhandTimeRemaining)
                    if timeDiff >= 0.5 and not jungle.SwingTimer:IsTimerStale() then
                        desyncState = DESYNC_IDLE
                    elseif (now - desyncStateTime) >= DESYNC_COOLDOWN_DURATION then
                        desyncState = DESYNC_IDLE
                    end
                end
            end
        end

        if desyncState ~= DESYNC_IDLE and (not inCombat or not UnitExists(_target)) then
            desyncState = DESYNC_IDLE
            desyncStateTime = 0
        end

        warriorFuryPvPCache[2][3] = (not routineActions or routineActions[warriorFuryPvPCache[2][2]] ~= false) and (wantStopattack)
        warriorFuryPvPCache[3][3] = (not routineActions or routineActions[warriorFuryPvPCache[3][2]] ~= false) and (allowAttack)
        
        return warriorFuryPvPCache
    end

    -- PVE ROUTINE (Current)
    warriorFuryCache[21][1] = 'Pre-Zerk: ' .. furyStrike
    warriorFuryCache[21][2] = furyStrike
    if hasBloodthirst then
        warriorFuryCache[2][1] = 'Bloodthirst (Single)'
        warriorFuryCache[2][2] = 'Bloodthirst'
        warriorFuryCache[3][1] = 'Whirlwind (Single)'
        warriorFuryCache[3][2] = 'Whirlwind'
        warriorFuryCache[4][1] = 'Placeholder'
        warriorFuryCache[4][2] = ''
    else
        warriorFuryCache[2][1] = 'Whirlwind (Single)'
        warriorFuryCache[2][2] = 'Whirlwind'
        warriorFuryCache[3][1] = 'Execute (Mortal Strike)'
        warriorFuryCache[3][2] = 'Execute'
        warriorFuryCache[4][1] = 'Mortal Strike (Single)'
        warriorFuryCache[4][2] = 'Mortal Strike'
    end
    warriorFuryCache[10][1] = furyStrike .. ' (AoE)'
    warriorFuryCache[10][2] = furyStrike

    local inCombat = UnitAffectingCombat("player")
    local rage = UnitPower("player", 1)
    local stance = GetShapeshiftForm()
    local canApplyTargetDebuff = CanApplyWarriorTargetDebuff(_target)
    
    -- ENEMY COUNTING IN AOE RANGE
    local enemiesNearby = 0
    local enemiesNearbyAbove20 = 0
    local enemiesTargetingMe = 0
    local enemiesWithDemo = 0
    local nameplates = C_NamePlate.GetNamePlates()
    if jungle.RaidTrace.sample then jungle.RaidTrace:Count("warriorNameplateVisits", #nameplates) end
    for i = 1, #nameplates do
        local unit = GetNameplateUnitToken(nameplates[i], i)
        if IsEnemyNameplateEligibleForAoE(unit) and CheckInteractDistance(unit, 3) then
            enemiesNearby = enemiesNearby + 1
            local unitHPMax = UnitHealthMax(unit)
            local hpPercent = unitHPMax > 0 and (UnitHealth(unit) / unitHPMax * 100) or 100
            if hpPercent >= 20 then
                enemiesNearbyAbove20 = enemiesNearbyAbove20 + 1
            end
            if UnitIsUnit(unit.."target", "player") then
                enemiesTargetingMe = enemiesTargetingMe + 1
            end
            if HasAttackPowerDebuff(unit) then
                enemiesWithDemo = enemiesWithDemo + 1
            end
        end
    end

    if enemiesNearby < 1 and (hasEnemy and IsEnemyNameplateEligibleForAoE(_target)) and (hasEnemy and CheckInteractDistance(_target, 3)) then
        enemiesNearby = 1
        local targetHP = (hasEnemy and UnitHealth(_target) or 0)
        local targetHPMax = (hasEnemy and UnitHealthMax(_target) or 0)
        local targetHPPercent = targetHPMax > 0 and (targetHP / targetHPMax * 100) or 100
        if targetHPPercent >= 20 then
            enemiesNearbyAbove20 = 1
        end
        if (hasEnemy and UnitIsUnit(_target.."target", "player")) then
            enemiesTargetingMe = enemiesTargetingMe + 1
        end
    else
        if enemiesNearbyAbove20 < 1 and (hasEnemy and IsEnemyNameplateEligibleForAoE(_target)) and (hasEnemy and CheckInteractDistance(_target, 3)) then
            local targetHP = (hasEnemy and UnitHealth(_target) or 0)
            local targetHPMax = (hasEnemy and UnitHealthMax(_target) or 0)
            local targetHPPercent = targetHPMax > 0 and (targetHP / targetHPMax * 100) or 100
            if targetHPPercent >= 20 then
                enemiesNearbyAbove20 = 1
            end
        end
    end
    
    if hasEnemy and enemiesNearby == 1 then
        enemiesWithDemo = HasAttackPowerDebuff(_target) and 1 or 0
    end

    -- WEAPON SWAP LOGIC (Fury PvE)
    equipCacheFastOffHand[1][3] = false
    equipCacheSlowOffHand[1][3] = false

    if jungle.GetBestDWWeapons then
        local bestMH, bestOH, bestThird = jungle.GetBestDWWeapons()
        local fastOH = nil
        local slowOH = nil

        if bestOH and bestThird then
            local speedOH = jungle.GetItemSpeed(bestOH) or 2.0
            local speedThird = jungle.GetItemSpeed(bestThird) or 2.0
            if speedOH <= speedThird then
                fastOH = bestOH
                slowOH = bestThird
            else
                fastOH = bestThird
                slowOH = bestOH
            end
        elseif bestOH then
            fastOH = bestOH
            slowOH = bestOH
        end

        local isAoEMode = (enemiesNearby >= 2)
        local targetOH = isAoEMode and slowOH or fastOH

        if targetOH then
            local ohLink = GetInventoryItemLink("player", 17)
            local currentOH = ohLink and ohLink:match("%[(.-)%]") or nil
            if currentOH ~= targetOH then
                local offhandJustLanded = (jungle.SwingTimer:GetOffhandTimeSinceLastSwing() < 0.2)
                local mainhandJustLanded = (jungle.SwingTimer:GetTimeSinceLastSwing() < 0.2)
                local canSwap = (not inCombat) or offhandJustLanded or mainhandJustLanded
                local equipAction = targetOH == fastOH and "EquipFastOffHand" or "EquipSlowOffHand"
                local macroTargets = jungle.Hotkeys and jungle.Hotkeys.EquipMacroTargets
                local macroTarget = macroTargets and macroTargets[equipAction]
                local canExecuteSwap = (
                    canSwap
                    and jungle.CanSwapWeapons()
                    and jungle.IsWeaponAvailable(targetOH)
                    and macroTarget == targetOH
                )
                if canExecuteSwap then
                    if equipAction == "EquipFastOffHand" then
                        equipCacheFastOffHand[1][3] = (not routineActions or routineActions[equipCacheFastOffHand[1][2]] ~= false) and (true)
                        return equipCacheFastOffHand
                    else
                        equipCacheSlowOffHand[1][3] = (not routineActions or routineActions[equipCacheSlowOffHand[1][2]] ~= false) and (true)
                        return equipCacheSlowOffHand
                    end
                end
            end
        end
    end

    local inChargeRange = ((hasEnemy and CheckInteractDistance(_target, 1)) and not (hasEnemy and jungle.inMeleeRange(_target)))
    
    local chargeOnCD = jungle.SpellOnCD("Charge")
    local interceptOnCD = jungle.SpellOnCD("Intercept")

    local wantCharge = ((not routineActions or routineActions["Charge"] ~= false) and not inCombat and inChargeRange and not chargeOnCD)
    if stance == 3 and rage >= 10 and not interceptOnCD then
        wantCharge = false
    end
    
    local chargeStart, chargeDur = GetSpellCooldown("Charge")
    local recentlyCharged = (chargeStart and chargeStart > 0 and (GetTime() - chargeStart) <= 2)

    local wantIntercept = ((not routineActions or routineActions["Intercept"] ~= false) and (inCombat or chargeOnCD or (stance == 3 and rage >= 10)) and not recentlyCharged and inChargeRange and not interceptOnCD)

    local useCharge = (wantCharge and stance == 1 and (hasEnemy and jungle.ReadyCastSpell('Charge', _target)))
    local useBattleStanceForCharge = (wantCharge and stance ~= 1 and jungle.ReadyCastSpell('Battle Stance'))

    local useIntercept = (wantIntercept and stance == 3 and (hasEnemy and jungle.ReadyCastSpell('Intercept', _target)))
    
    local useZerkStanceForIntercept = (wantIntercept and stance ~= 3 and jungle.ReadyCastSpell('Berserker Stance'))
    
    local useBloodrage = (rage < 12 and (hasEnemy and jungle.inMeleeRange(_target)) and jungle.ReadyCastSpell('Bloodrage'))
    local useBerserkerRage = (stance == 3 and enemiesTargetingMe >= 1 and jungle.ReadyCastSpell('Berserker Rage'))
    
    local isSingle = (enemiesNearby == 1)
    local isAoE = (enemiesNearby >= 2)

    local isHSQueued = C_Spell.IsCurrentSpell("Heroic Strike") or false
    local isCleaveQueued = C_Spell.IsCurrentSpell("Cleave") or false

    local inMeleeRange = (hasEnemy and jungle.inMeleeRange(_target))
    local useEarlyDemoFallback = jungle.Engine and jungle.GetWarriorRoutineBehavior().earlyDemo
    local demoCoreBlocked = UsesWarriorDemoFallback() and (
        UnitCastingInfo("player") == "Slam"
        or (hasEnemy and CanUseWarriorFuryPveCore(_target, isAoE, hasBloodthirst, rage))
    )
    local demoFallbackReady = UsesWarriorDemoFallback() and not demoCoreBlocked
        and ShouldRefreshWarriorPveDemoralizingShout(_target, inMeleeRange)
    local useEarlyFallbackDemoralizingShout = useEarlyDemoFallback and demoFallbackReady
    local inHamstringRange = false
    local hamstringRangeVal = (hasEnemy and C_Spell.IsSpellInRange("Hamstring", _target))
    if hamstringRangeVal ~= nil then
        inHamstringRange = (hamstringRangeVal == true or hamstringRangeVal == 1)
    else
        inHamstringRange = inMeleeRange
    end
    
    local targetHP = (hasEnemy and UnitHealth(_target) or 0)
    local targetHPMax = (hasEnemy and UnitHealthMax(_target) or 0)
    local targetHPPercent = targetHPMax > 0 and (targetHP / targetHPMax * 100) or 100

    local canExecute = ((not routineActions or routineActions["Execute"] ~= false) and targetHPPercent < 20 and inMeleeRange)
    

    local btOnCD = jungle.SpellOnCD(furyStrike)
    local wwOnCD = jungle.SpellOnCD("Whirlwind")
    local ssOnCD = not jungle.WarriorRoutineOptionEnabled("sweeping") or jungle.SpellOnCD("Sweeping Strikes")

    -- --- OVERPOWER LOGIC ---
    local overpowerActive = (GetTime() <= overpowerExpireTime)
    local opOnCD = jungle.SpellOnCD("Overpower")
    local wantOverpower = isSingle and not canExecute and overpowerActive and not opOnCD and inMeleeRange and (btOnCD and wwOnCD or stance == 1)
    
    local useOverpower = (wantOverpower and stance == 1 and (hasEnemy and jungle.ReadyCastSpell('Overpower', _target)))
    local useBattleStanceForOP = (wantOverpower and stance ~= 1 and jungle.ReadyCastSpell('Battle Stance'))

    local inMeleeLocal = (hasEnemy and jungle.inMeleeRange(_target))
    local targetHPPercentLocal = targetHPPercent
    
    local btReady = (not jungle.SpellOnCD(furyStrike))
    local executeReady = ((not routineActions or routineActions["Execute"] ~= false) and targetHPPercentLocal < 20)
    local tcReady = jungle.WarriorRoutineOptionEnabled("thunderClap") and canApplyTargetDebuff and not jungle.SpellOnCD("Thunder Clap")
    
    local delayZerkForBT = (stance == 1 and rage > 10 and btReady and inMeleeLocal)
    local delayZerkForExecute = (enemiesNearby < 2 and stance == 1 and rage > 10 and executeReady and inMeleeLocal)
    local delayZerkForTC = (stance == 1 and rage > 10 and tcReady and (hasEnemy and CheckInteractDistance(_target, 3)))
    
    local needsStance = (stance ~= 3 and not wantCharge and not wantIntercept and not wantOverpower)
    local useZerkStance = useZerkStanceForIntercept or (needsStance and jungle.ReadyCastSpell('Berserker Stance'))
    
    local preZerkExecute = false
    local preZerkBT = false
    local preZerkTC = false
    if useZerkStance and stance == 1 and not useZerkStanceForIntercept then
        if delayZerkForExecute and (hasEnemy and jungle.ReadyCastSpell('Execute', _target)) then
            preZerkExecute = true
            useZerkStance = false
        elseif delayZerkForTC and jungle.ReadyCastSpell('Thunder Clap') then
            preZerkTC = true
            useZerkStance = false
        elseif delayZerkForBT and (hasEnemy and jungle.ReadyCastSpell(furyStrike, _target)) then
            preZerkBT = true
            useZerkStance = false
        elseif (delayZerkForExecute or delayZerkForBT or delayZerkForTC) then
            useZerkStance = false
        end
    end

    local allowSS = false
    local allowWW = false
    local allowBT = false

    local hasSSBuff = jungle.unitCacheBuff('player', 'Sweeping Strikes')

    if enemiesNearby == 1 then
        if hasBloodthirst then
            allowBT = true
            allowWW = btOnCD
        else
            allowWW = true
            allowBT = wwOnCD
        end
    elseif enemiesNearby >= 2 then
        if enemiesNearbyAbove20 >= 2 then
            allowSS = (jungle.WarriorRoutineOptionEnabled("sweeping") and rage >= 30 and isCleaveQueued)
        end
        allowWW = ssOnCD
        allowBT = wwOnCD and (rage >= 50)
    end

    local shout, needsShout = jungle.GetWarriorDpsShout(5)

    local chargedVeryRecently = (chargeStart and chargeStart > 0 and (GetTime() - chargeStart) <= 0.2)
    if chargedVeryRecently and shout == 'Battle Shout' then
        needsShout = false
    end

    -- INTERRUPT LOGIC
    local usePummel = false
    local useZerkStanceForPummel = false
    if (not routineActions or routineActions["Pummel"] ~= false) and inMeleeRange and jungle.checkPveInterrupt(_target) then
        if stance == 3 then
            usePummel = (hasEnemy and jungle.ReadyCastSpell('Pummel', _target))
        else
            useZerkStanceForPummel = jungle.ReadyCastSpell('Berserker Stance')
        end
    end

    -- APPLY CACHE PRIORITIES
    for i = 1, #warriorFuryCache do warriorFuryCache[i][3] = false end

    warriorFuryCache[13][3] = (not routineActions or routineActions[warriorFuryCache[13][2]] ~= false) and (useZerkStanceForPummel)
    warriorFuryCache[14][3] = (not routineActions or routineActions[warriorFuryCache[14][2]] ~= false) and (usePummel)
    warriorFuryCache[17][3] = (not routineActions or routineActions[warriorFuryCache[17][2]] ~= false) and (useCharge)
    warriorFuryCache[18][3] = (not routineActions or routineActions[warriorFuryCache[18][2]] ~= false) and (useBattleStanceForCharge or useBattleStanceForOP)
    warriorFuryCache[19][3] = (not routineActions or routineActions[warriorFuryCache[19][2]] ~= false) and (useIntercept)
    warriorFuryCache[20][3] = (not routineActions or routineActions[warriorFuryCache[20][2]] ~= false) and (preZerkExecute)
    warriorFuryCache[21][3] = (not routineActions or routineActions[warriorFuryCache[21][2]] ~= false) and (preZerkBT)
    warriorFuryCache[22][3] = (not routineActions or routineActions[warriorFuryCache[22][2]] ~= false) and (canApplyTargetDebuff and preZerkTC)
    warriorFuryCache[23][3] = (not routineActions or routineActions[warriorFuryCache[23][2]] ~= false) and (useZerkStance or useZerkStanceForIntercept)
    warriorFuryCache[34][3] = (not routineActions or routineActions[warriorFuryCache[34][2]] ~= false) and (useOverpower)
    warriorFuryCache[24][3] = (not routineActions or routineActions[warriorFuryCache[24][2]] ~= false) and (useBloodrage)
    warriorFuryCache[25][3] = (not routineActions or routineActions[warriorFuryCache[25][2]] ~= false) and (useBerserkerRage)
    warriorFuryCache[26][1] = shout
    warriorFuryCache[26][2] = shout
    warriorFuryCache[26][3] = (not routineActions or routineActions[warriorFuryCache[26][2]] ~= false) and (needsShout and jungle.ReadyCastSpell(shout))
    local isTargetPlayer = (hasEnemy and UnitIsPlayer(_target)) or (hasEnemy and UnitPlayerControlled(_target))
    local oneshotThreshold = isTargetPlayer and 2000 or math.max(5000, math.min(50000, targetHPMax * 0.015))
    local useOneshotExecute = (not isAoE and canExecute and targetHP < oneshotThreshold and (hasEnemy and jungle.ReadyCastSpell('Execute', _target)))

    local needsDemoAoE = (isAoE and enemiesWithDemo < math.ceil(enemiesNearby / 2))
    local needsDemoST = (isSingle and (hasEnemy and not HasAttackPowerDebuff(_target) or not hasEnemy and enemiesWithDemo < 1))
    if UsesWarriorDemoFallback() then
        needsDemoAoE = isAoE and demoFallbackReady
        needsDemoST = isSingle and demoFallbackReady
    end

    local sunderRemaining, sunderCountAura = GetDebuffRemaining(_target, 'Sunder Armor')
    local exposeRemaining = GetDebuffRemaining(_target, 'Expose Armor')
    if exposeRemaining > 0 then
        sunderCountAura = 5
        sunderRemaining = 999
    end
    -- Fury PvE filler: build Sunder to five stacks in both single-target and
    -- AoE modes whenever the higher-priority rotation has nothing available.
    -- Preserve the existing urgent refresh at five stacks, while Expose Armor
    -- suppresses Sunder entirely through the normalized state above.
    local needsSunderPriority = (
        sunderCountAura < 5
        or (sunderCountAura > 0 and sunderRemaining > 0 and sunderRemaining < 5)
    )

    local offhandTimeRemaining = jungle.SwingTimer:GetOffhandTimeRemaining()
    local mainhandTimeRemaining = jungle.SwingTimer:GetTimeRemaining()

    local queueHS = false
    local doStopCasting = false
    local isAttacking = C_Spell.IsCurrentSpell(6603)
    
    local wantCleave = false
    local wantHS = false
    local wantExecute = false

    if isAoE then
        if hasSSBuff then
            wantCleave = (rage >= 20)
        else
            if wwOnCD then
                wantCleave = (rage >= 20) -- WW is on CD, Cleave every time
            else
                wantCleave = (rage > ((not routineActions or routineActions["Whirlwind"] ~= false) and 50 or CLEAVE_RAGE_COST)) -- Fund enabled Whirlwind only
            end
        end
    else
        if canExecute then
            wantExecute = (btOnCD and wwOnCD)
        else
            wantHS = (rage > 60 or (rage >= 42 and btOnCD and wwOnCD))
        end
    end

    -- --- SINGLE TARGET PRIORITIES (Super High) ---
    warriorFuryCache[1][3] = (not routineActions or routineActions[warriorFuryCache[1][2]] ~= false) and (useOneshotExecute)
    if hasBloodthirst then
        warriorFuryCache[2][3] = ((not routineActions or routineActions[warriorFuryCache[2][2]] ~= false) and (allowBT and isSingle and inMeleeRange and rage >= 30 and (hasEnemy and jungle.ReadyCastSpell('Bloodthirst', _target))))
        warriorFuryCache[3][3] = ((not routineActions or routineActions[warriorFuryCache[3][2]] ~= false) and (allowWW and isSingle and rage >= 25 and jungle.ReadyCastSpell('Whirlwind')))
        warriorFuryCache[4][3] = false
        warriorFuryCache[5][3] = ((not routineActions or routineActions[warriorFuryCache[5][2]] ~= false) and (wantExecute and (hasEnemy and jungle.ReadyCastSpell('Execute', _target))))
    else
        warriorFuryCache[2][3] = ((not routineActions or routineActions[warriorFuryCache[2][2]] ~= false) and (allowWW and isSingle and rage >= 25 and jungle.ReadyCastSpell('Whirlwind')))
        warriorFuryCache[3][3] = ((not routineActions or routineActions[warriorFuryCache[3][2]] ~= false) and (canExecute and (hasEnemy and jungle.ReadyCastSpell('Execute', _target))))
        warriorFuryCache[4][3] = ((not routineActions or routineActions[warriorFuryCache[4][2]] ~= false) and (allowBT and isSingle and inMeleeRange and rage >= 30 and (hasEnemy and jungle.ReadyCastSpell('Mortal Strike', _target))))
        warriorFuryCache[5][3] = ((not routineActions or routineActions[warriorFuryCache[5][2]] ~= false) and (wantExecute and (hasEnemy and jungle.ReadyCastSpell('Execute', _target))))
    end

    -- --- AOE TARGET PRIORITIES (Super High) ---
    warriorFuryCache[6][3] = ((not routineActions or routineActions[warriorFuryCache[6][2]] ~= false) and (allowSS and isAoE and jungle.ReadyCastSpell('Sweeping Strikes')))
    warriorFuryCache[7][3] = ((not routineActions or routineActions[warriorFuryCache[7][2]] ~= false) and (allowWW and isAoE and rage >= 37 and jungle.ReadyCastSpell('Whirlwind')))
    -- [8] Cleave is set further down in STEP 3
    warriorFuryCache[9][3] = ((not routineActions or routineActions[warriorFuryCache[9][2]] ~= false) and (isAoE and hasSSBuff and not hasBloodthirst and canExecute and (hasEnemy and jungle.ReadyCastSpell('Execute', _target))))
    warriorFuryCache[10][3] = ((not routineActions or routineActions[warriorFuryCache[10][2]] ~= false) and (allowBT and isAoE and inMeleeRange and rage >= 42 and (hasEnemy and jungle.ReadyCastSpell(furyStrike, _target))))

    -- The Thread 2 slot is eligible only when no core attack can be used.
    if useEarlyFallbackDemoralizingShout then
        warriorFuryCache[5][1] = 'Fallback Demoralizing Shout'
        warriorFuryCache[5][2] = 'Demoralizing Shout'
        warriorFuryCache[5][3] = (not routineActions or routineActions[warriorFuryCache[5][2]] ~= false) and (true)
    else
        warriorFuryCache[5][1] = 'Execute'
        warriorFuryCache[5][2] = 'Execute'
    end

    -- --- UTILITY / SHOUTS / LOWER PRIORITIES ---
    warriorFuryCache[27][3] = ((not routineActions or routineActions[warriorFuryCache[27][2]] ~= false) and (inCombat and rage >= 32 and jungle.ReadyCastSpell('Rampage') and not jungle.unitCacheBuff('player', 'Rampage', nil, 5)))
    warriorFuryCache[28][3] = ((not routineActions or routineActions[warriorFuryCache[28][2]] ~= false) and (inMeleeRange and (hasEnemy and jungle.ReadyCastSpell('Victory Rush', _target))))
    warriorFuryCache[29][3] = ((not routineActions or routineActions[warriorFuryCache[29][2]] ~= false) and (jungle.WarriorRoutineOptionEnabled(sunderCountAura == 0 and "sunderInitial" or "sunderStack") and canApplyTargetDebuff and needsSunderPriority and inMeleeRange and (hasEnemy and jungle.ReadyCastSpell('Sunder Armor', _target))))
    warriorFuryCache[30][3] = ((not routineActions or routineActions[warriorFuryCache[30][2]] ~= false) and (jungle.WarriorRoutineOptionEnabled("demo") and not useEarlyDemoFallback and (canApplyTargetDebuff or (not hasEnemy and enemiesNearby > 0)) and needsDemoAoE and jungle.ReadyCastSpell('Demoralizing Shout')))
    warriorFuryCache[31][3] = ((not routineActions or routineActions[warriorFuryCache[31][2]] ~= false) and (jungle.WarriorRoutineOptionEnabled("demo") and not useEarlyDemoFallback and (canApplyTargetDebuff or (not hasEnemy and enemiesNearby > 0)) and needsDemoST and jungle.ReadyCastSpell('Demoralizing Shout')))

    local _, _, _, latencyHome = GetNetStats()
    local latency = (latencyHome or 50) / 1000
    local safetyBuffer = HS_ABUSE_SAFETY_BUFFER + latency

    -- =============================================
    -- STEP 1: CANCEL LOGIC (evaluated first so queue can use post-cancel state)
    -- =============================================
    -- Abuse-only queues (HS queued for OH hit-table benefit, not rage dump) are
    -- only cancelled at the hard safeguard (< 0.4s), not in the soft zone.
    if isCleaveQueued or isHSQueued then
        if not isAttacking or not inMeleeRange then
            doStopCasting = true
        elseif mainhandTimeRemaining < 0.5 then
            local meetCleaveCondition = (isAoE and wantCleave)
            local meetHSCondition = (isSingle and wantHS)
            local isAbuseOnly = (isHSQueued and not wantHS) or (isCleaveQueued and not wantCleave)
            
            -- HARD SAFEGUARD: At < 0.4s, cancel everything we don't want as a rage dump
            if mainhandTimeRemaining < 0.4 then
                if isHSQueued and not meetHSCondition then
                    doStopCasting = true
                elseif isCleaveQueued and not meetCleaveCondition then
                    doStopCasting = true
                end
            end
            
            -- SOFT ZONE (0.4-0.5s): Only cancel rage-dump mismatches, NOT abuse queues
            -- Abuse queues persist through the soft zone and are handled by the hard safeguard
            if not doStopCasting and not isAbuseOnly then
                local inOffhandWindow = (offhandTimeRemaining < HS_ABUSE_QUEUE_WINDOW and (mainhandTimeRemaining > offhandTimeRemaining + safetyBuffer))
                local isSynced = (math.abs(mainhandTimeRemaining - offhandTimeRemaining) < 0.5)
                local offhandJustLanded = (jungle.SwingTimer:GetOffhandTimeSinceLastSwing() < 0.2)
                
                if offhandJustLanded then
                    if isHSQueued and not meetHSCondition then
                        doStopCasting = true
                    elseif isCleaveQueued and not meetCleaveCondition then
                        doStopCasting = true
                    end
                elseif not inOffhandWindow and not isSynced then
                    if isHSQueued and not meetHSCondition then
                        doStopCasting = true
                    elseif isCleaveQueued and not meetCleaveCondition then
                        doStopCasting = true
                    end
                end
            end
        end
    end

    -- Post-cancel effective state: if we're cancelling, treat HS/Cleave as unqueued
    -- so the queue logic below can immediately re-queue for the next offhand window
    local effectiveHSQueued = isHSQueued and not doStopCasting
    local effectiveCleaveQueued = isCleaveQueued and not doStopCasting

    -- =============================================
    -- STEP 2: QUEUE LOGIC (uses post-cancel effective state)
    -- =============================================
    local queueCleave = false
    if offhandTimeRemaining < HS_ABUSE_QUEUE_WINDOW and (mainhandTimeRemaining > offhandTimeRemaining + safetyBuffer) and isAttacking and inMeleeRange then
        if isAoE then
            if wantCleave and rage >= 20 then
                queueCleave = true
            elseif not effectiveCleaveQueued and not effectiveHSQueued and rage >= 12 and rage < 20 then
                queueHS = true
            end
        else
            if rage >= 12 and not effectiveHSQueued then
                queueHS = true
            end
        end
    end

    -- =============================================
    -- STEP 3: CACHE ASSIGNMENTS
    -- =============================================
    warriorFuryCache[11][3] = (not routineActions or routineActions[warriorFuryCache[11][2]] ~= false) and (doStopCasting)
    warriorFuryCache[12][1] = 'Queue Heroic Strike'
    warriorFuryCache[12][2] = 'Heroic Strike'
    warriorFuryCache[12][3] = ((not routineActions or routineActions[warriorFuryCache[12][2]] ~= false) and (queueHS and IsNextSwingReady('Heroic Strike', _target)))

    -- Rage dump queue — uses effective post-cancel state
    -- AoE Cleave: queue as fast as possible, no MH swing gate
    local queueCleaveAction = false
    if isAttacking and inMeleeRange then
        if queueCleave and not effectiveCleaveQueued then
            queueCleaveAction = true
        elseif wantCleave and not effectiveCleaveQueued then
            queueCleaveAction = true
        end
    end
    warriorFuryCache[8][3] = ((not routineActions or routineActions[warriorFuryCache[8][2]] ~= false) and (queueCleaveAction and IsNextSwingReady('Cleave', _target)))

    if isAttacking and inMeleeRange and mainhandTimeRemaining <= 0.4 then
        if wantHS and not effectiveHSQueued then
            warriorFuryCache[32][3] = (not routineActions or routineActions[warriorFuryCache[32][2]] ~= false) and (IsNextSwingReady('Heroic Strike', _target))
        end
    end
    
    local hasTrinketBuff = jungle.unitCacheBuff('player', 'Death Wish') or jungle.unitCacheBuff('player', 'Lightning Speed')
    local useTrinkets = isAoE or hasTrinketBuff
    warriorFuryCache[33][3] = ((not routineActions or routineActions[warriorFuryCache[33][2]] ~= false) and (jungle.AreTrinketsReady() and inCombat and inMeleeRange and not (canExecute and targetHP < 50000) and (useTrinkets and true or false)))

    -- =============================================
    -- DESYNC STATE MACHINE + ATTACK CONTROL
    -- =============================================
    local wantStopattack = false
    local now = GetTime()
    local allowAttack = false

    if isAttacking then
        if not inHamstringRange then
            -- Out of range: always stop (safety, not desync)
            wantStopattack = true
        elseif inCombat and inHamstringRange and desyncState == DESYNC_IDLE then
            -- Check if swings are synced and we need to desync
            local ohLink = GetInventoryItemLink("player", 17)
            local ohName = ohLink and GetItemInfo(ohLink)
            local ohSpeed = ohName and jungle.GetItemSpeed(ohName)
            local skipDesync = ohSpeed and (ohSpeed < 1.8) or false

            if not skipDesync then
                local timeDiff = math.abs(mainhandTimeRemaining - offhandTimeRemaining)
                if mainhandTimeRemaining > 0 and offhandTimeRemaining > 0 and timeDiff < 0.5 and not jungle.SwingTimer:IsTimerStale() then
                    wantStopattack = true
                    desyncState = DESYNC_STOPPED
                    desyncStateTime = now
                    jungle.SwingTimer:OnAttackStopped()
                    jungle.isSyncedDesyncTrigger = true
                end
            end
        elseif desyncState == DESYNC_STOPPED then
            -- Keep requesting stop until the external driver processes it
            wantStopattack = true
        end
    else
        -- Not currently attacking
        if desyncState == DESYNC_STOPPED then
            if (now - desyncStateTime) >= DESYNC_STOP_DURATION then
                -- Waited long enough, allow restart
                desyncState = DESYNC_COOLDOWN
                desyncStateTime = now
                allowAttack = inHamstringRange
                if allowAttack then
                    jungle.SwingTimer:OnAttackStarted()
                end
            end
            -- else: still waiting in stopped state, suppress Attack
        else
            -- Normal: allow attack if in range
            allowAttack = inHamstringRange
            if desyncState == DESYNC_COOLDOWN then
                -- Check if desync succeeded or if we should allow retry
                local timeDiff = math.abs(mainhandTimeRemaining - offhandTimeRemaining)
                if timeDiff >= 0.5 and not jungle.SwingTimer:IsTimerStale() then
                    desyncState = DESYNC_IDLE -- Successfully desynced
                elseif (now - desyncStateTime) >= DESYNC_COOLDOWN_DURATION then
                    desyncState = DESYNC_IDLE -- Timeout, allow retry
                end
            end
        end
    end

    -- Safety: exit desync state if combat drops or target is lost
    if desyncState ~= DESYNC_IDLE and (not inCombat or not UnitExists(_target)) then
        desyncState = DESYNC_IDLE
        desyncStateTime = 0
    end

    warriorFuryCache[15][3] = (not routineActions or routineActions[warriorFuryCache[15][2]] ~= false) and (wantStopattack)
    warriorFuryCache[16][3] = (not routineActions or routineActions[warriorFuryCache[16][2]] ~= false) and (allowAttack)
    
    return warriorFuryActiveCache
end

local warriorArmsPvPCache = {
    [1]  = {'Stopcasting', 'Stopcasting', false, 1, 0},
    [2]  = {'Interrupt Stance', 'Berserker Stance', false, 1, 0},
    [3]  = {'Interrupt', 'Pummel', false, 1, 0},
    [4]  = {'Charge', 'Charge', false, 1, 0},
    [5]  = {'Battle Stance', 'Battle Stance', false, 1, 0},
    [6]  = {'Intercept', 'Intercept', false, 1, 0},
    [7]  = {'Berserker Stance', 'Berserker Stance', false, 1, 0},
    [8]  = {'Hamstring', 'Hamstring', false, 1, 0},
    [9]  = {'Piercing Howl', 'Piercing Howl', false, 1, 0},
    [10] = {'Bloodrage', 'Bloodrage', false, 1, 0},
    [11] = {'Lethal Execute', 'Execute', false, 1, 0},
    [12] = {'Mortal Strike', 'Mortal Strike', false, 1, 0},
    [13] = {'Execute', 'Execute', false, 1, 0},
    [14] = {'Overpower Stance', 'Battle Stance', false, 1, 0},
    [15] = {'Overpower', 'Overpower', false, 1, 0},
    [16] = {'Thunder Clap', 'Thunder Clap', false, 1, 0},
    [17] = {'Queue Heroic Strike', 'Heroic Strike', false, 1, 0},
    [18] = {'Sweeping Strikes', 'Sweeping Strikes', false, 1, 0},
    [19] = {'Victory Rush', 'Victory Rush', false, 1, 0},
    [20] = {'Whirlwind', 'Whirlwind', false, 1, 0},
    [21] = {'Update Sunder Armor', 'Sunder Armor', false, 1, 0},
    [22] = {'Sunder Armor', 'Sunder Armor', false, 1, 0},
    [23] = {'Berserker Rage', 'Berserker Rage', false, 1, 0},
    [24] = {'Battle Shout', 'Battle Shout', false, 1, 0},
    [25] = {'Default Berserker Stance', 'Berserker Stance', false, 1, 0},
    [26] = {'Attack', 'Attack', false, 1, 0},
}



-- Assigned after the WoWSims selector loads; shared only with the T1 prepass.

local warriorArmsPveMaintenanceCache = {
    [1] = {'Initial Sunder Armor', 'Sunder Armor', false, 1, 0},
    [2] = {'Thunder Clap Stance', 'Battle Stance', false, 1, 0},
    [3] = {'Refresh Thunder Clap', 'Thunder Clap', false, 1, 0},
    [4] = {'Refresh Demoralizing Shout', 'Demoralizing Shout', false, 1, 0},
    [5] = {'Build Sunder Armor', 'Sunder Armor', false, 1, 0},
}

function jungle.warriorArmsPveMaintenance(_target)
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    for i = 1, #warriorArmsPveMaintenanceCache do
        warriorArmsPveMaintenanceCache[i][3] = false
    end

    -- This placement owns only its PvE debuff maintenance. The configured
    -- thread list determines which explicit placement is evaluated next.
    if not _target or not UnitExists(_target)
    or not UnitCanAttack("player", _target)
    or UnitIsDeadOrGhost(_target)
    or UnitIsPlayer(_target)
    or UnitPlayerControlled(_target)
    or not CanApplyWarriorTargetDebuff(_target) then
        return warriorArmsPveMaintenanceCache
    end

    local inMeleeRange = jungle.inMeleeRange(_target)
    local sunderRemaining, sunderCount, exposeRemaining = GetArmorDebuffState(_target)
    local thunderClapRemaining = GetDebuffRemaining(_target, 'Thunder Clap')
    local stance = GetShapeshiftForm()

    local targetGUID = UnitGUID(_target)
    if armsPveHoldBattleForThunderClap
    and armsPveHoldBattleForThunderClapGUID ~= targetGUID then
        armsPveHoldBattleForThunderClap = false
        armsPveHoldBattleForThunderClapGUID = nil
        armsPveHoldBattleForThunderClapThread.behavior = nil
    end
    local sunderAppliedAt = targetGUID and armsPveSunderApplicationTimes[targetGUID]
    if sunderRemaining <= 0
    and sunderAppliedAt
    and (GetTime() - sunderAppliedAt) >= ARMS_PVE_SUNDER_AURA_SETTLE_TIME then
        armsPveSunderApplicationTimes[targetGUID] = nil
        sunderAppliedAt = nil
    end
    local recentlyAppliedSunder = sunderAppliedAt
        and (GetTime() - sunderAppliedAt) < ARMS_PVE_SUNDER_AURA_SETTLE_TIME
    local canCastSunder = (
        inMeleeRange
        and exposeRemaining <= 0
        and not recentlyAppliedSunder
        and ReadyCastSpellNoGCD('Sunder Armor', _target)
    )
    local useInitialSunder = jungle.WarriorRoutineOptionEnabled("sunderInitial") and canCastSunder and sunderCount == 0
    local useStackSunder = jungle.WarriorRoutineOptionEnabled("sunderStack") and canCastSunder
        and sunderCount > 0
        and (sunderCount < 5 or (sunderRemaining > 0 and sunderRemaining <= 5))

    -- Keep Thunder Clap up.  It has a dedicated stance action so the next
    -- maintenance tick casts it immediately after entering Battle Stance.
    local thunderClapNeeded = (
        jungle.WarriorRoutineOptionEnabled("thunderClap")
        and thunderClapRemaining <= 5
        and CheckInteractDistance(_target, 3)
    )
    if thunderClapNeeded then
        armsPveHoldBattleForThunderClap = true
        armsPveHoldBattleForThunderClapGUID = targetGUID
        armsPveHoldBattleForThunderClapThread.behavior = jungle.GetWarriorRoutineBehavior().handoff
        armsPveHoldBattleForThunderClapThread.thread = jungle.Engine and jungle.Engine.activeThread
        armsPveHoldBattleForThunderClapThread.revision = jungle.RoutineConfig and jungle.RoutineConfig.revision
    elseif armsPveHoldBattleForThunderClap
    and armsPveHoldBattleForThunderClapGUID == targetGUID then
        armsPveHoldBattleForThunderClap = false
        armsPveHoldBattleForThunderClapGUID = nil
        armsPveHoldBattleForThunderClapThread.behavior = nil
    end
    local useThunderClap = (
        thunderClapNeeded
        and stance == 1
        and ReadyCastSpellNoGCD('Thunder Clap')
    )
    local useBattleStanceForThunderClap = (
        thunderClapNeeded
        and stance ~= 1
        and ReadyCastSpellNoGCD('Battle Stance')
    )

    local useDemoralizingShout = ShouldRefreshWarriorPveDemoralizingShout(_target, inMeleeRange)
        and not ShouldDeferWarriorPveMaintenanceDemo(_target)

    warriorArmsPveMaintenanceCache[1][3] = (not routineActions or routineActions[warriorArmsPveMaintenanceCache[1][2]] ~= false) and (useInitialSunder)
    warriorArmsPveMaintenanceCache[2][3] = (not routineActions or routineActions[warriorArmsPveMaintenanceCache[2][2]] ~= false) and (useBattleStanceForThunderClap)
    warriorArmsPveMaintenanceCache[3][3] = (not routineActions or routineActions[warriorArmsPveMaintenanceCache[3][2]] ~= false) and (useThunderClap)
    warriorArmsPveMaintenanceCache[4][3] = (not routineActions or routineActions[warriorArmsPveMaintenanceCache[4][2]] ~= false) and (useDemoralizingShout)
    warriorArmsPveMaintenanceCache[5][3] = (not routineActions or routineActions[warriorArmsPveMaintenanceCache[5][2]] ~= false) and (useStackSunder)
    return warriorArmsPveMaintenanceCache
end

local warriorArmsCache = {
    [1]  = {'Interrupt Stance', 'Berserker Stance', false, 1, 0},
    [2]  = {'Interrupt', 'Pummel', false, 1, 0},
    [3]  = {'Sweeping Strikes', 'Sweeping Strikes', false, 1, 0},
    [4]  = {'Slam', 'Slam', false, 1, 0},
    [5]  = {'Lethal Execute', 'Execute', false, 1, 0},
    [6]  = {'Heroic Strike', 'Heroic Strike', false, 1, 0},
    [7]  = {'Update Sunder Armor', 'Sunder Armor', false, 1, 0},
    [8]  = {'Mortal Strike', 'Mortal Strike', false, 1, 0},
    [9]  = {'Whirlwind', 'Whirlwind', false, 1, 0},
    [10] = {'Execute Filler', 'Execute', false, 1, 0},
    [11] = {'Victory Rush', 'Victory Rush', false, 1, 0},
    [12] = {'Attack', 'Attack', false, 1, 0},
    [13] = {'Cleave', 'Cleave', false, 1, 0},
    [14] = {'Bloodrage', 'Bloodrage', false, 1, 0},
    [15] = {'Berserker Rage', 'Berserker Rage', false, 1, 0},
    [16] = {'Battle Shout', 'Battle Shout', false, 1, 0},
    [17] = {'Demoralizing Shout', 'Demoralizing Shout', false, 1, 0},
    [18] = {'Charge', 'Charge', false, 1, 0},
    [19] = {'Battle Stance', 'Battle Stance', false, 1, 0},
    [20] = {'Intercept', 'Intercept', false, 1, 0},
    [21] = {'Berserker Stance', 'Berserker Stance', false, 1, 0},
    [22] = {'Trinkets', 'Trinkets', false, 1, 0},
}

function jungle.warriorArms(_target, pvpUtilitiesOnly)
    -- Check if target is casting/channeling to suspend 2H check during interrupt window (PvP only)
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    local isCastingTarget = false
    if _target and UnitExists(_target) and UnitIsPlayer(_target) then
        local cName, _, _, _, _, _, _, notInt = UnitCastingInfo(_target)
        local chName, _, _, _, _, _, notIntCh = UnitChannelInfo(_target)
        if (cName and not notInt) or (chName and not notIntCh) then
            isCastingTarget = true
        end
    end

    -- WEAPON CHECK: Arms requires two-hand weapon
    if not pvpUtilitiesOnly and not isCastingTarget and not HasTwoHandEquipped() then
        equipCache2H[1][3] = (not routineActions or routineActions[equipCache2H[1][2]] ~= false) and (jungle.CanSwapWeapons())
        return equipCache2H
    end

    local hasMortalStrike = warriorCapabilities.hasMortalStrike
    -- Adaptive core planning must not hide the Original slow utility row.
    local canUseImprovedSlam = not pvpUtilitiesOnly and CanUseImprovedSlam()

    local hasEnemy = _target ~= nil and UnitExists(_target)
        and UnitCanAttack("player", _target) and not UnitIsDeadOrGhost(_target)
    if not hasEnemy then _target = nil end

    if hasEnemy and (pvpUtilitiesOnly or UnitIsPlayer(_target) or UnitPlayerControlled(_target)) then
        if not pvpUtilitiesOnly then
            if armsPveFight then EndArmsPveFight(GetTime(), "player_controlled_target") end
            armsPveDiagnosticsActiveUntil = 0
        end

        for i = 1, #warriorArmsPvPCache do warriorArmsPvPCache[i][3] = false end

        local inCombat = UnitAffectingCombat("player")
        local rage = UnitPower("player", 1)
        local stance = GetShapeshiftForm()
        local canApplyTargetDebuff = CanApplyWarriorTargetDebuff(_target)
        
        -- PVP MODE COUNTING: only hostile players and player-controlled pets.
        -- Totems, dead units, and ordinary NPCs must never switch the routine
        -- between its single-target and AoE priorities.
        local pvpCombatantsNearby = 0
        local nameplates = C_NamePlate.GetNamePlates()
        if jungle.RaidTrace.sample then jungle.RaidTrace:Count("warriorNameplateVisits", #nameplates) end
        for i = 1, #nameplates do
            local unit = GetNameplateUnitToken(nameplates[i], i)
            if IsEnemyNameplateEligibleForAoE(unit) and CheckInteractDistance(unit, 3) then
                local isPlayer = UnitIsPlayer(unit)
                if isPlayer or UnitPlayerControlled(unit) then
                    pvpCombatantsNearby = pvpCombatantsNearby + 1
                end
            end
        end

        if pvpCombatantsNearby < 1 and IsEnemyNameplateEligibleForAoE(_target) and CheckInteractDistance(_target, 3) then
            if UnitIsPlayer(_target) or UnitPlayerControlled(_target) then
                if not UnitIsDeadOrGhost(_target) then
                    pvpCombatantsNearby = 1
                end
            end
        end

        local isAoE = (pvpCombatantsNearby >= 2)
        local isSingle = not isAoE

        local gapCloser = GetWarriorGapCloserDecision(_target, jungle.ReadyCastSpell)
        local inChargeRange = gapCloser.inGapCloserRange
        local chargeOnCD = gapCloser.chargeOnCD
        local interceptOnCD = gapCloser.interceptOnCD
        local wantCharge = gapCloser.wantCharge
        local recentlyCharged = gapCloser.recentlyCharged
        local recentlyIntercepted = gapCloser.recentlyIntercepted
        local justEngaged = (recentlyCharged or recentlyIntercepted)
        local wantIntercept = gapCloser.wantIntercept
        local useCharge = gapCloser.useCharge
        local useBattleStanceForCharge = gapCloser.useBattleStanceForCharge
        local useIntercept = gapCloser.useIntercept
        if useCharge or useIntercept then
            RecordArmsGapCloser(GetTime(), true)
        end
        
        local inMeleeRange = jungle.inMeleeRange(_target)
        local targetHP = UnitHealth(_target)
        local targetHPMax = UnitHealthMax(_target)
        local targetHPPercent = targetHPMax > 0 and (targetHP / targetHPMax * 100) or 100

        local isExecutePhase = ((not routineActions or routineActions["Execute"] ~= false) and targetHPPercent < 20)
        local canExecute = ((not routineActions or routineActions["Execute"] ~= false) and isExecutePhase and inMeleeRange)
        local msOffRealCooldown = hasMortalStrike and IsSpellOffRealCooldown('Mortal Strike')
        local msOnRealCooldown = not msOffRealCooldown
        local wwOffRealCooldown = IsSpellOffRealCooldown('Whirlwind')
        local wwOnRealCooldown = not wwOffRealCooldown

        local isTargetPlayer = UnitIsPlayer(_target) or UnitPlayerControlled(_target)
        local oneshotThreshold = isTargetPlayer and 2000 or 10000

        local mainhandSpeed = UnitAttackSpeed("player") or 3.0
        local timeSinceSwing = armsLastMainhandSwingTime > 0 and (GetTime() - armsLastMainhandSwingTime) or 999
        local timeSinceGapCloser = armsLastGapCloserTime > 0 and (GetTime() - armsLastGapCloserTime) or 999
        local waitingForGapCloserSwing = (armsGapCloserPendingSwing and timeSinceGapCloser <= SLAM_GAP_CLOSER_WAIT_TIMEOUT)
        local apiAutoAttacking = C_Spell.IsCurrentSpell(6603) or false
        local recentlyConfirmedSwing = (armsLastMainhandSwingTime > 0 and timeSinceSwing <= (mainhandSpeed + 0.25))
        local isAutoAttacking = (apiAutoAttacking or recentlyConfirmedSwing)
        local hasPendingSlam = (armsLastMainhandSwingTime > armsLastSlammedSwingTime)
        local activeSlamWindow = armsLastMainhandWasGapCloserSwing and SLAM_GAP_CLOSER_AFTERSWING_WINDOW or SLAM_AFTERSWING_WINDOW
        local isAfterswingWindow = (hasPendingSlam and not waitingForGapCloserSwing and timeSinceSwing >= 0 and timeSinceSwing <= activeSlamWindow)
        local isCastingSlam = (UnitCastingInfo("player") == "Slam")
        if isCastingSlam and armsSlamCastingSwingTime == 0 then
            RecordArmsSlamStart()
        end
        local playerSpeed = GetUnitSpeed("player") or 0
        local stationaryForSlam = playerSpeed <= SLAM_STATIONARY_SPEED_MAX
        local slamRageThreshold = GetImprovedSlamRageThreshold(isAoE)
        local hasSlamRageNow = rage >= slamRageThreshold
        local canSlamAfterSwing = (canUseImprovedSlam and isAutoAttacking and isAfterswingWindow and stationaryForSlam and not isCastingSlam and ReadyCastSpellNoGCD('Slam'))
        -- PvP Slam mirrors the PvE after-swing priority: if the swing window is
        -- open, use it before ordinary core damage.
        local useSlamWindow = (canSlamAfterSwing and inMeleeRange and hasSlamRageNow)
        local holdGCDForSlam = isCastingSlam or useSlamWindow
        local blockCoreForSlam = isCastingSlam

        -- INTERRUPT LOGIC
        local usePummel = false
        local useShieldBash = false
        local useZerkStanceForPummel = false
        local canReachInterrupt = false
        local doStopCasting = false
        local castName, _, _, startTime, endTime, _, _, notInterruptible = UnitCastingInfo(_target)
        local channelName, _, _, _, _, _, notInterruptibleChannel = UnitChannelInfo(_target)
        local activeCastName = castName or channelName

        if IsPriorityInterruptSpell(activeCastName)
        and ((castName and not notInterruptible) or (channelName and not notInterruptibleChannel)) then
            local shouldInterrupt = false

            if channelName then
                shouldInterrupt = true
            elseif castName and startTime and endTime and (endTime - startTime) > 0 then
                local finish = (endTime / 1000) - GetTime()
                local duration = (endTime - startTime) / 1000
                local castProgress = 1 - (finish / duration)
                if castProgress > 0.7 then
                    shouldInterrupt = true
                end
            end

            if shouldInterrupt and inMeleeRange and rage >= 10 then
                if stance == 3 then
                    usePummel = not jungle.SpellOnCD('Pummel')
                    canReachInterrupt = usePummel
                elseif stance == 1 or stance == 2 then
                    if IsEquippedItemType("Shields") and not jungle.SpellOnCD('Shield Bash') then
                        useShieldBash = true
                        canReachInterrupt = true
                    elseif not jungle.SpellOnCD('Pummel') then
                        -- Prefer an existing stance swap over a late in-combat
                        -- weapon swap, which is too slow for a 70% interrupt.
                        canReachInterrupt = true
                        useZerkStanceForPummel = jungle.ReadyCastSpell('Berserker Stance')
                    end
                end

                doStopCasting = isCastingSlam and canReachInterrupt
            end
        end

        local useZerkStanceForIntercept = gapCloser.useBerserkerStanceForIntercept
        
        -- OVERPOWER LOGIC
        local targetGUID = UnitGUID(_target)
        local overpowerActive = (
            GetTime() <= overpowerExpireTime
            and (not overpowerDodgeGUID or overpowerDodgeGUID == targetGUID)
        )
        local opOnCD = jungle.SpellOnCD("Overpower")
        local useOverpower = false
        local useBattleStanceForOP = false
        local useBerserkerRageForOP = false

        local _, targetClass = UnitClass(_target)
        local isRogueTarget = (targetClass == "ROGUE")
        local hasBerserkerRageBuff = jungle.unitCacheBuff('player', 'Berserker Rage')
        local wantOverpower = (
            overpowerActive
            and inMeleeRange
            and not opOnCD
            and (
                msOnRealCooldown
                or rage < 25
                or (msOnRealCooldown and wwOnRealCooldown)
            )
        )

        if wantOverpower then
            if stance == 1 then
                useOverpower = jungle.ReadyCastSpell('Overpower', _target)
            else
                if not pvpUtilitiesOnly and isRogueTarget and stance == 3 and not hasBerserkerRageBuff and jungle.ReadyCastSpell('Berserker Rage') then
                    useBerserkerRageForOP = true
                else
                    useBattleStanceForOP = jungle.ReadyCastSpell('Battle Stance')
                end
            end
        end

        -- SLOW LOGIC
        -- Only apply slows when target has no slow or slow is about to expire (< 3s)
        -- This prevents spamming Hamstring/Piercing Howl over core damage abilities
        local needsSlow = false
        if UnitIsPlayer(_target) then
            local hasImmunity = jungle.isSlowProtected(_target)
            if not hasImmunity then
                local hasSlow = jungle.isSlowed(_target)
                if not hasSlow then
                    needsSlow = true
                else
                    -- Check remaining time on our slows specifically
                    local hamRemaining = GetDebuffRemaining(_target, 'Hamstring')
                    local phRemaining = GetDebuffRemaining(_target, 'Piercing Howl')
                    local bestSlowRemaining = math.max(hamRemaining, phRemaining)
                    -- Only refresh if our slow is about to expire and no other slow is active
                    if bestSlowRemaining > 0 and bestSlowRemaining < 3 then
                        needsSlow = true
                    end
                end
            end
        end

        local hasEvasion = jungle.unitCacheBuff(_target, "Evasion")
        local mainTargetOutsideMelee = (isTargetPlayer and CheckInteractDistance(_target, 3) and not inMeleeRange)
        local piercingHowlIntervalReady = (armsLastPiercingHowlTime == 0 or (GetTime() - armsLastPiercingHowlTime) >= PIERCING_HOWL_AOE_INTERVAL)
        local canUseAoEPiercingHowl = (mainTargetOutsideMelee or hasEvasion or (isAoE and piercingHowlIntervalReady))
        -- Hamstring on contact; Piercing Howl covers Evasion, short range gaps,
        -- and multiple PvP combatants without becoming a generic rage filler.
        local useHamstring = (needsSlow and inMeleeRange and not hasEvasion and isSingle and jungle.ReadyCastSpell('Hamstring', _target))
        local usePiercingHowl = (needsSlow and not useHamstring and canUseAoEPiercingHowl and jungle.ReadyCastSpell('Piercing Howl'))
        local thunderClapRemaining = GetDebuffRemaining(_target, 'Thunder Clap')
        local useThunderClap = (
            jungle.WarriorRoutineOptionEnabled("thunderClap")
            and canApplyTargetDebuff
            and stance == 1
            and (targetClass == "ROGUE" or targetClass == "WARRIOR" or targetClass == "HUNTER")
            and CheckInteractDistance(_target, 3)
            and thunderClapRemaining <= 0
            and ReadyCastSpellNoGCD('Thunder Clap')
        )
        
        local canLethalExecute = (not blockCoreForSlam and canExecute and targetHP < oneshotThreshold and jungle.ReadyCastSpell('Execute', _target))
        local canExecuteCast = (not blockCoreForSlam and canExecute and msOnRealCooldown and jungle.ReadyCastSpell('Execute', _target))
        local canMSCast = (not blockCoreForSlam and jungle.ReadyCastSpell('Mortal Strike', _target))
        local executeOffRealCooldown = canExecute and IsSpellOffRealCooldown('Execute')
        local _, msNeedsRage = IsUsableSpell('Mortal Strike')
        local _, executeNeedsRage = IsUsableSpell('Execute')
        local waitRageForMain = (inMeleeRange and (
            (msOffRealCooldown and not canExecute and msNeedsRage)
            or (executeOffRealCooldown and executeNeedsRage)
        ))

        -- STANCE LOGIC (Normal)
        local msCD = msOnRealCooldown
        local wwCD = wwOnRealCooldown
        local delayZerkForMS = (stance == 1 and msOffRealCooldown and inMeleeRange)
        local delayZerkForExecute = ((not routineActions or routineActions["Execute"] ~= false) and stance == 1 and targetHPPercent < 20 and inMeleeRange)
        local needsStance = (stance ~= 3 and not wantCharge and not wantIntercept and not delayZerkForMS and not delayZerkForExecute and not useBattleStanceForOP)
        local useZerkStanceNormal = (needsStance and stance ~= 3 and inCombat and jungle.ReadyCastSpell('Berserker Stance'))

        local useBloodrage = (isExecutePhase and inCombat and inMeleeRange and jungle.ReadyCastSpell('Bloodrage'))
        local useBerserkerRage = false

        -- ROTATION PRIORITY DIRECT CONSTRUCTION
        local canSlam = useSlamWindow
        local reserveRageForSlam = useSlamWindow
        local canQueueHSForSlam = (not reserveRageForSlam or (rage - HEROIC_STRIKE_RAGE_COST) >= slamRageThreshold)
        
        local shout, needsShout = jungle.GetWarriorDpsShout(5)

        local sunderRemaining, sunderCountAura = GetDebuffRemaining(_target, 'Sunder Armor')
        local exposeRemaining = GetDebuffRemaining(_target, 'Expose Armor')
        if exposeRemaining > 0 then
            sunderCountAura = 5
            sunderRemaining = 999
        end
        local canUseSunderWindow = (msOnRealCooldown and wwOnRealCooldown and not isExecutePhase and not waitRageForMain)
        local useUpdateSunder = (jungle.WarriorRoutineOptionEnabled("sunderStack") and canApplyTargetDebuff and canUseSunderWindow and sunderCountAura > 0 and sunderRemaining > 0 and sunderRemaining < 5 and inMeleeRange and not holdGCDForSlam and jungle.ReadyCastSpell('Sunder Armor', _target))
        local useSunderFiller = (jungle.WarriorRoutineOptionEnabled(sunderCountAura == 0 and "sunderInitial" or "sunderStack") and canApplyTargetDebuff and canUseSunderWindow and sunderCountAura < 5 and inMeleeRange and not holdGCDForSlam and jungle.ReadyCastSpell('Sunder Armor', _target))

        warriorArmsPvPCache[1][3] = (not routineActions or routineActions[warriorArmsPvPCache[1][2]] ~= false) and (doStopCasting)
        warriorArmsPvPCache[2][3] = ((not routineActions or routineActions[warriorArmsPvPCache[2][2]] ~= false) and (useZerkStanceForPummel and not isCastingSlam))
        
        if stance == 3 then
            warriorArmsPvPCache[3][1] = 'Interrupt'
            warriorArmsPvPCache[3][2] = 'Pummel'
            warriorArmsPvPCache[3][3] = ((not routineActions or routineActions[warriorArmsPvPCache[3][2]] ~= false) and (usePummel and not isCastingSlam))
        else
            warriorArmsPvPCache[3][1] = 'Interrupt'
            warriorArmsPvPCache[3][2] = 'Shield Bash'
            warriorArmsPvPCache[3][3] = ((not routineActions or routineActions[warriorArmsPvPCache[3][2]] ~= false) and (useShieldBash and not isCastingSlam))
        end

        warriorArmsPvPCache[4][3]  = ((not routineActions or routineActions[warriorArmsPvPCache[4][2]] ~= false) and (useCharge and not isCastingSlam))
        warriorArmsPvPCache[5][3]  = ((not routineActions or routineActions[warriorArmsPvPCache[5][2]] ~= false) and (useBattleStanceForCharge and not isCastingSlam))
        warriorArmsPvPCache[6][3]  = ((not routineActions or routineActions[warriorArmsPvPCache[6][2]] ~= false) and (useIntercept and not isCastingSlam))
        warriorArmsPvPCache[7][3]  = ((not routineActions or routineActions[warriorArmsPvPCache[7][2]] ~= false) and (useZerkStanceForIntercept and not isCastingSlam))
        if canSlam then
            warriorArmsPvPCache[8][1] = 'Slam'
            warriorArmsPvPCache[8][2] = 'Slam'
            warriorArmsPvPCache[8][3] = (not routineActions or routineActions[warriorArmsPvPCache[8][2]] ~= false) and (true)
            warriorArmsPvPCache[9][3] = false
        else
            warriorArmsPvPCache[8][1] = 'Hamstring'
            warriorArmsPvPCache[8][2] = 'Hamstring'
            warriorArmsPvPCache[8][3] = ((not routineActions or routineActions[warriorArmsPvPCache[8][2]] ~= false) and (useHamstring and not isCastingSlam and not canLethalExecute))
            warriorArmsPvPCache[9][3] = ((not routineActions or routineActions[warriorArmsPvPCache[9][2]] ~= false) and (usePiercingHowl and not isCastingSlam and not canLethalExecute))
        end
        warriorArmsPvPCache[10][3] = ((not routineActions or routineActions[warriorArmsPvPCache[10][2]] ~= false) and (useBloodrage and not canLethalExecute))
        warriorArmsPvPCache[11][3] = (not routineActions or routineActions[warriorArmsPvPCache[11][2]] ~= false) and (canLethalExecute)
        warriorArmsPvPCache[12][3] = (not routineActions or routineActions[warriorArmsPvPCache[12][2]] ~= false) and (canMSCast)
        warriorArmsPvPCache[13][3] = (not routineActions or routineActions[warriorArmsPvPCache[13][2]] ~= false) and (canExecuteCast)
        if useBerserkerRageForOP then
            warriorArmsPvPCache[14][1] = 'Overpower Berserker Rage'
            warriorArmsPvPCache[14][2] = 'Berserker Rage'
            warriorArmsPvPCache[14][3] = (not routineActions or routineActions[warriorArmsPvPCache[14][2]] ~= false) and (not isCastingSlam)
        else
            warriorArmsPvPCache[14][1] = 'Overpower Stance'
            warriorArmsPvPCache[14][2] = 'Battle Stance'
            warriorArmsPvPCache[14][3] = ((not routineActions or routineActions[warriorArmsPvPCache[14][2]] ~= false) and (useBattleStanceForOP and not isCastingSlam))
        end
        warriorArmsPvPCache[15][3] = ((not routineActions or routineActions[warriorArmsPvPCache[15][2]] ~= false) and (useOverpower and not blockCoreForSlam))
        warriorArmsPvPCache[16][3] = ((not routineActions or routineActions[warriorArmsPvPCache[16][2]] ~= false) and (useThunderClap and not blockCoreForSlam))
        warriorArmsPvPCache[17][3] = ((not routineActions or routineActions[warriorArmsPvPCache[17][2]] ~= false) and (rage >= 70 and canQueueHSForSlam and inMeleeRange and IsNextSwingReady('Heroic Strike', _target)))

        local useSS = (jungle.WarriorRoutineOptionEnabled("sweeping") and isAoE and jungle.ReadyCastSpell('Sweeping Strikes') and (rage > 60 or (msCD and wwCD)))
        warriorArmsPvPCache[18][3] = ((not routineActions or routineActions[warriorArmsPvPCache[18][2]] ~= false) and (useSS and not blockCoreForSlam))
        warriorArmsPvPCache[19][3] = ((not routineActions or routineActions[warriorArmsPvPCache[19][2]] ~= false) and (not blockCoreForSlam and inMeleeRange and jungle.ReadyCastSpell('Victory Rush', _target)))
        warriorArmsPvPCache[20][3] = ((not routineActions or routineActions[warriorArmsPvPCache[20][2]] ~= false) and (not blockCoreForSlam and inMeleeRange and msCD and jungle.ReadyCastSpell('Whirlwind')))
        warriorArmsPvPCache[21][3] = (not routineActions or routineActions[warriorArmsPvPCache[21][2]] ~= false) and (useUpdateSunder)
        warriorArmsPvPCache[22][3] = (not routineActions or routineActions[warriorArmsPvPCache[22][2]] ~= false) and (useSunderFiller)
        warriorArmsPvPCache[23][3] = ((not routineActions or routineActions[warriorArmsPvPCache[23][2]] ~= false) and (useBerserkerRage and not blockCoreForSlam))
        warriorArmsPvPCache[24][1] = shout
        warriorArmsPvPCache[24][2] = shout
        warriorArmsPvPCache[24][3] = ((not routineActions or routineActions[warriorArmsPvPCache[24][2]] ~= false) and ((needsShout and jungle.ReadyCastSpell(shout)) and not holdGCDForSlam))
        warriorArmsPvPCache[25][3] = ((not routineActions or routineActions[warriorArmsPvPCache[25][2]] ~= false) and (useZerkStanceNormal and not holdGCDForSlam and not isCastingSlam))
        warriorArmsPvPCache[26][3] = ((not routineActions or routineActions[warriorArmsPvPCache[26][2]] ~= false) and (not C_Spell.IsCurrentSpell(6603)))

        if pvpUtilitiesOnly then
            -- Narrow utility view; never mutate the compiled placement masks.
            for i = 1, #warriorArmsPvPCache do
                local action = warriorArmsPvPCache[i][2]
                if action == 'Slam' or action == 'Mortal Strike' or action == 'Execute'
                    or action == 'Whirlwind' or action == 'Heroic Strike' or action == 'Cleave'
                    or action == 'Sweeping Strikes' or action == 'Victory Rush'
                    or action == 'Bloodrage' or action == 'Berserker Rage' then
                    warriorArmsPvPCache[i][3] = false
                end
            end
        end
        return warriorArmsPvPCache, canLethalExecute
    end

    local inCombat = UnitAffectingCombat("player")
    if hasEnemy then MarkArmsPveDiagnosticsActive(_target, inCombat) end
    local rage = UnitPower("player", 1)
    local stance = GetShapeshiftForm()
    local canApplyTargetDebuff = CanApplyWarriorTargetDebuff(_target)
    local targetHP = (hasEnemy and UnitHealth(_target) or 0)
    local targetHPMax = (hasEnemy and UnitHealthMax(_target) or 0)
    local targetHPPercent = targetHPMax > 0 and (targetHP / targetHPMax * 100) or 100
    
    -- ENEMY COUNTING IN AOE RANGE
    local enemiesNearby = 0
    local sweepingEnemiesNearby = 0
    local enemiesTargetingMe = 0
    local enemiesWithDemo = 0
    local firstDemoUnit = nil
    local nameplates = C_NamePlate.GetNamePlates()
    if jungle.RaidTrace.sample then jungle.RaidTrace:Count("warriorNameplateVisits", #nameplates) end
    for i = 1, #nameplates do
        local unit = GetNameplateUnitToken(nameplates[i], i)
        if IsEnemyNameplateEligibleForAoE(unit) and CheckInteractDistance(unit, 3) then
            local unitHPMax = UnitHealthMax(unit)
            local hpPercent = unitHPMax > 0 and (UnitHealth(unit) / unitHPMax * 100) or 100
            enemiesNearby = enemiesNearby + 1
            if hpPercent > 20 then
                sweepingEnemiesNearby = sweepingEnemiesNearby + 1
            end
            if UnitIsUnit(unit.."target", "player") then
                enemiesTargetingMe = enemiesTargetingMe + 1
            end
            if enemiesNearby == 1 then
                firstDemoUnit = unit
            else
                if enemiesNearby == 2 and HasAttackPowerDebuff(firstDemoUnit) then
                    enemiesWithDemo = enemiesWithDemo + 1
                end
                if HasAttackPowerDebuff(unit) then
                    enemiesWithDemo = enemiesWithDemo + 1
                end
            end
        end
    end

    if enemiesNearby < 1 and (hasEnemy and IsEnemyNameplateEligibleForAoE(_target)) and (hasEnemy and CheckInteractDistance(_target, 3)) then
        enemiesNearby = 1
        if targetHPPercent > 20 then
            sweepingEnemiesNearby = 1
        end
        if (hasEnemy and UnitIsUnit(_target.."target", "player")) then
            enemiesTargetingMe = enemiesTargetingMe + 1
        end
    end

    local isAoE = (enemiesNearby >= 2)
    local isSweepingAoE = (sweepingEnemiesNearby >= 2)

    local gapCloser = GetWarriorGapCloserDecision(_target, ReadyCastSpellNoGCD)
    local inMeleeRange = gapCloser.inMeleeRange
    local inAoERange = inMeleeRange or (not hasEnemy and enemiesNearby > 0)
    local inChargeRange = gapCloser.inGapCloserRange
    local chargeOnCD = gapCloser.chargeOnCD
    local interceptOnCD = gapCloser.interceptOnCD
    local chargeStart = gapCloser.chargeStart
    local wantCharge = gapCloser.wantCharge
    local recentlyCharged = gapCloser.recentlyCharged
    local wantIntercept = gapCloser.wantIntercept
    local useCharge = gapCloser.useCharge
    local useBattleStanceForCharge = gapCloser.useBattleStanceForCharge
    local useIntercept = gapCloser.useIntercept
    local useZerkStanceForIntercept = gapCloser.useBerserkerStanceForIntercept

    if useCharge or useIntercept then
        RecordArmsGapCloser(GetTime(), true)
    end

    local msReadyNoGCD = hasMortalStrike and (hasEnemy and ReadyCastSpellNoGCD("Mortal Strike", _target))
    local ssReadyNoGCD = jungle.WarriorRoutineOptionEnabled("sweeping") and ReadyCastSpellNoGCD("Sweeping Strikes")
    local isCleaveQueued = C_Spell.IsCurrentSpell("Cleave") or false
    local hasBerserkerRage = jungle.unitCacheBuff('player', 'Berserker Rage', nil, 5)
    local hasSSBuff = jungle.unitCacheBuff('player', 'Sweeping Strikes')
    local useCoreFirstAoE = (
        isAoE
        and jungle.Engine
        and jungle.GetWarriorRoutineBehavior().coreFirstAoE
    )
    local useSweepingCorePriority = (useCoreFirstAoE and hasSSBuff)
    local useNonSweepingCorePriority = (useCoreFirstAoE and not hasSSBuff)
    local wwReadyNoGCD = ReadyCastSpellNoGCD("Whirlwind")
    local earlySSForCore = hasBerserkerRage and (wwReadyNoGCD or isCleaveQueued)
    -- This is the exact Sweeping Strikes condition used by the AoE priority
    -- below.  Keep it shared with stance and Thunder Clap decisions.
    local sweepingStrikesReadyForRotation = (
        isSweepingAoE
        and ssReadyNoGCD
        and not hasSSBuff
        and (rage >= 50 or earlySSForCore)
    )
    local overpowerOpportunity = (
        not isAoE
        and GetTime() <= overpowerExpireTime
        and inMeleeRange
        and IsSpellOffRealCooldown("Overpower")
    )
    local holdBattleForOverpower = (overpowerOpportunity and stance == 1)
    local usePriorityOverpower = (
        holdBattleForOverpower
        and (hasEnemy and ReadyCastSpellNoGCD('Overpower', _target))
    )
    local useBattleStanceForOverpower = (
        overpowerOpportunity
        and stance == 3
        and rage <= 14
        and ReadyCastSpellNoGCD('Battle Stance')
    )
    local delayZerkForMS = (not isAoE and stance == 1 and msReadyNoGCD and inMeleeRange)
    local delayZerkForSS = (stance == 1 and sweepingStrikesReadyForRotation and inMeleeRange)
    local delayZerkForExecute = (not isAoE and stance == 1 and targetHPPercent < 20 and inMeleeRange)

    local holdBattleForThunderClap = (
        jungle.WarriorRoutineOptionEnabled("thunderClap")
        and armsPveHoldBattleForThunderClap
        and armsPveHoldBattleForThunderClapGUID == (hasEnemy and UnitGUID(_target))
        and jungle.Engine
        and armsPveHoldBattleForThunderClapThread.behavior == jungle.GetWarriorRoutineBehavior().handoff
        and armsPveHoldBattleForThunderClapThread.thread == jungle.Engine.activeThread
        and armsPveHoldBattleForThunderClapThread.revision == (jungle.RoutineConfig and jungle.RoutineConfig.revision)
    )
    local needsStance = (
        stance ~= 3
        and not wantCharge
        and not wantIntercept
        and not delayZerkForMS
        and not delayZerkForSS
        and not delayZerkForExecute
        and not holdBattleForOverpower
    )
    local useZerkStanceNormal = (
        needsStance
        and stance ~= 3
        and inCombat
        and not holdBattleForThunderClap
        and ReadyCastSpellNoGCD('Berserker Stance')
    )

    local useBloodrage = (inCombat and rage < 80 and ReadyCastSpellNoGCD('Bloodrage'))
    local useBerserkerRage = (stance == 3 and enemiesTargetingMe >= 1 and ReadyCastSpellNoGCD('Berserker Rage'))

    local slamState = GetArmsPveSlamState(hasEnemy, inMeleeRange, rage, isAoE, useCoreFirstAoE)
    local mainhandSpeed = slamState.mainhandSpeed
    local timeSinceSwing = slamState.timeSinceSwing
    local isAutoAttacking = slamState.isAutoAttacking
    local hasPendingSlam = slamState.hasPendingSlam
    local activeSlamWindow = slamState.activeSlamWindow
    local isCastingSlam = slamState.isCastingSlam
    local stationaryForSlam = slamState.stationaryForSlam
    local slamRageThreshold = slamState.slamRageThreshold
    local hasSlamRageNow = slamState.hasSlamRageNow
    local expectedGCD = slamState.expectedGCD
    local gcdRemaining = slamState.gcdRemaining
    local canSlamAfterSwing = slamState.canSlamAfterSwing
    local useSlamWindow = slamState.useSlamWindow
    local reserveSlamWindow = slamState.reserveSlamWindow
    local useCoreFirstForHaste = slamState.useCoreFirstForHaste
    local reserveInitialSwingForSlam = slamState.reserveInitialSwingForSlam
    local reserveSlamPreSwing = slamState.reserveSlamPreSwing
    local coreGCDWouldClipSlam = slamState.coreGCDWouldClipSlam
    local holdGCDForSlam = slamState.holdGCDForSlam
    local blockCoreForSlam = slamState.blockCoreForSlam
    if isCastingSlam and armsSlamCastingSwingTime == 0 then
        RecordArmsSlamStart()
    end

    local canExecute = ((not routineActions or routineActions["Execute"] ~= false) and targetHPPercent < 20 and inMeleeRange)

    local isHSQueued = C_Spell.IsCurrentSpell("Heroic Strike") or false
    local vrReadyNoGCD = not isAoE and (hasEnemy and ReadyCastSpellNoGCD("Victory Rush", _target))
    local executeReadyNoGCD = canExecute and (hasEnemy and ReadyCastSpellNoGCD("Execute", _target))
    local msOffRealCooldown = hasMortalStrike and IsSpellOffRealCooldown("Mortal Strike")
    local wwOffRealCooldown = IsSpellOffRealCooldown("Whirlwind")
    local msOnRealCooldown = not msOffRealCooldown
    local wwOnRealCooldown = not wwOffRealCooldown
    local wwStart, wwDuration = GetSpellCooldown("Whirlwind")
    local wwRealCooldownRemaining = (not routineActions or routineActions["Whirlwind"] ~= false) and 0 or math.huge
    if (not routineActions or routineActions["Whirlwind"] ~= false) and wwOnRealCooldown and wwStart and wwStart > 0 and wwDuration and wwDuration > 0 then
        wwRealCooldownRemaining = math.max(0, (wwStart + wwDuration) - GetTime())
    end
    local ssOffRealCooldown = (jungle.WarriorRoutineOptionEnabled("sweeping") and isSweepingAoE and not hasSSBuff and IsSpellOffRealCooldown("Sweeping Strikes"))
    local ssSpellAvailable = (isSweepingAoE and ssReadyNoGCD and not hasSSBuff)
    local thread2AoESlamReady = (
        useCoreFirstAoE
        and canSlamAfterSwing
        and inMeleeRange
        and hasSlamRageNow
    )
    local thread2AoEMSReady = (
        useCoreFirstAoE
        and hasMortalStrike
        and rage >= ((not routineActions or routineActions["Whirlwind"] ~= false) and ARMS_PVE_SWEEPING_MS_RAGE_THRESHOLD or ARMS_PVE_MORTAL_STRIKE_RAGE_COST)
        and msReadyNoGCD
        and wwOnRealCooldown
        and wwRealCooldownRemaining > expectedGCD
        and not thread2AoESlamReady
        and not reserveInitialSwingForSlam
        and not coreGCDWouldClipSlam
    )
    -- Do not repeatedly cast Thunder Clap merely because we are in Battle
    -- Stance. In the normal routine it is only an AoE fallback when the
    -- existing debuff is missing/about to expire and no higher core action or
    -- Slam reservation is pending.
    local thunderClapRemaining = GetDebuffRemaining(_target, 'Thunder Clap')
    local usePriorityThunderClap = (
        jungle.WarriorRoutineOptionEnabled("thunderClap")
        and canApplyTargetDebuff
        and isAoE
        and stance == 1
        and inMeleeRange
        and thunderClapRemaining <= ARMS_PVE_THUNDER_CLAP_URGENT_REMAINING
        and not holdGCDForSlam
        and not useSlamWindow
        and not wwReadyNoGCD
        and not sweepingStrikesReadyForRotation
        and ReadyCastSpellNoGCD('Thunder Clap')
    )

    local armsDiagnosticsEnabled = ArmsDiagnosticsEnabled()
    local RecordArmsDecision = NoopArmsDecision
    if armsDiagnosticsEnabled then
        RecordArmsDecision = function(selectedAction, slamRecommended, explicitSlamBlocker)
        if not armsPveFight then return end

        local decisionNow = GetTime()
        local urgentSlamSample = slamRecommended or selectedAction == "Slam"
        if not urgentSlamSample and (decisionNow - armsLastDecisionSampleAt) < ARMS_DECISION_SAMPLE_INTERVAL then
            return
        end
        armsLastDecisionSampleAt = decisionNow

        local slamBlocker = explicitSlamBlocker
        if not slamBlocker and hasPendingSlam and timeSinceSwing <= activeSlamWindow then
            if not isAutoAttacking then
                slamBlocker = "auto_attack_not_active"
            elseif not inMeleeRange then
                slamBlocker = "out_of_melee"
            elseif not stationaryForSlam then
                slamBlocker = "moving"
            elseif not hasSlamRageNow then
                slamBlocker = "low_rage"
            elseif not ReadyCastSpellNoGCD("Slam", nil, true) then
                slamBlocker = "slam_unavailable"
            elseif slamState.timing and slamState.timing.reason and not slamRecommended then
                slamBlocker = slamState.timing.reason
            elseif useCoreFirstForHaste and not slamRecommended then
                slamBlocker = "core_first_haste_mode"
            elseif selectedAction and selectedAction ~= "Slam" and not slamRecommended then
                slamBlocker = "selected_" .. string.gsub(string.lower(selectedAction), "%s+", "_")
            end
        end

        UpdateArmsPveDiagnostics({
            now = decisionNow,
            rage = rage,
            stance = stance,
            mode = isAoE and (isSweepingAoE and "sweeping_aoe" or "aoe") or "single_target",
            inMelee = inMeleeRange,
            gcdRemaining = gcdRemaining,
            selected = selectedAction,
            blockCoreForSlam = blockCoreForSlam,
            useSlamWindow = useSlamWindow,
            slamRecommended = slamRecommended and true or false,
            slamRageThreshold = slamRageThreshold,
            slamBlocker = slamBlocker,
            slamTiming = slamState.timing,
            core = {
                ["Mortal Strike"] = {
                    due = inCombat and ((not isAoE and msOffRealCooldown) or thread2AoEMSReady),
                    ready = msReadyNoGCD,
                },
                ["Whirlwind"] = {
                    due = inCombat and wwOffRealCooldown and (isAoE or msOnRealCooldown),
                    ready = wwReadyNoGCD,
                },
                ["Sweeping Strikes"] = {
                    due = jungle.WarriorRoutineOptionEnabled("sweeping") and inCombat and isSweepingAoE and not hasSSBuff and IsSpellOffRealCooldown("Sweeping Strikes"),
                    ready = ssReadyNoGCD,
                },
            },
        })
        end
    end

    local isTargetPlayer = (hasEnemy and UnitIsPlayer(_target)) or (hasEnemy and UnitPlayerControlled(_target))
    local oneshotThreshold = isTargetPlayer and 2000 or math.max(5000, math.min(50000, targetHPMax * 0.015))
    local lethalExecuteReady = (not isAoE and executeReadyNoGCD and targetHP < oneshotThreshold)
    local cancelQueuedAttackForLethal = (lethalExecuteReady and (isHSQueued or isCleaveQueued) and not isCastingSlam)
    if (not routineActions or routineActions["Pummel"] ~= false) and inMeleeRange and not isCastingSlam and jungle.checkPveInterrupt(_target) then
        for i = 1, #warriorArmsCache do warriorArmsCache[i][3] = false end
        if stance == 3 and (hasEnemy and ReadyCastSpellNoGCD('Pummel', _target)) then
            warriorArmsCache[2][3] = (not routineActions or routineActions[warriorArmsCache[2][2]] ~= false) and (true)
            RecordArmsDecision("Pummel", false, "interrupt")
            return warriorArmsCache
        elseif ReadyCastSpellNoGCD('Berserker Stance') then
            warriorArmsCache[1][3] = (not routineActions or routineActions[warriorArmsCache[1][2]] ~= false) and (true)
            RecordArmsDecision("Berserker Stance", false, "interrupt_stance")
            return warriorArmsCache
        end
    end

    -- A confirmed after-swing Slam remains immediately ahead of the kill Execute.
    if not cancelQueuedAttackForLethal and not useSlamWindow and not blockCoreForSlam and lethalExecuteReady then
        for i = 1, #warriorArmsCache do warriorArmsCache[i][3] = false end
        warriorArmsCache[5][3] = (not routineActions or routineActions[warriorArmsCache[5][2]] ~= false) and (true)
        RecordArmsDecision("Execute", false, "lethal_execute")
        return warriorArmsCache
    end

    local msCD = not msReadyNoGCD
    local wwCD = not wwReadyNoGCD
    local ssCD = not ssReadyNoGCD
    
    local msStart, msDur = GetSpellCooldown("Mortal Strike")
    local msRemaining = (msStart and msStart > 0 and msDur - (GetTime() - msStart)) or 0
    if not hasMortalStrike or not (not routineActions or routineActions["Mortal Strike"] ~= false) then
        msRemaining = 999 
        msCD = true
    end

    local isExecutePhase = canExecute

    -- ARMS PRIORITIES
    local useSlam = false
    local useLethalExecute = lethalExecuteReady
    local useExecuteFiller = false
    local useVR = false
    local useMS = false
    local useWW = false
    local useSS = false
    local useCleave = false
    local useHS = false
    local useDemo = false
    local wantCleaveQueued = false
    local wantHSQueued = false
    local replaceCleaveWithHS = false

    local checkHSQueued = isHSQueued or isCleaveQueued
    local reserveRageForSlam = (slamState.timing and useSlamWindow) or (
        not useCoreFirstAoE
        and not useCoreFirstForHaste
        and (reserveInitialSwingForSlam or reserveSlamWindow or reserveSlamPreSwing)
    )
    local slamRageReserve = reserveRageForSlam and ARMS_PVE_SLAM_RAGE_COST or 0

    -- HS/Cleave replace a white swing, so a sustainable dump includes both
    -- the button cost and the rage that the white swing was expected to make.
    -- At 90+ rage, allow the hard (spell-cost-only) budget to prevent capping.
    local singleCoreRageReserve =
        ((msOffRealCooldown or (slamState.timing and slamState.timing.ms <= slamState.timing.nextSwing))
            and ARMS_PVE_MORTAL_STRIKE_RAGE_COST or 0)
        + ((wwOffRealCooldown or (slamState.timing and slamState.timing.ww <= slamState.timing.nextSwing))
            and ARMS_PVE_WHIRLWIND_RAGE_COST or 0)
    local hsHardRageThreshold = HEROIC_STRIKE_RAGE_COST + singleCoreRageReserve + slamRageReserve
    local hsSoftRageThreshold = hsHardRageThreshold + SLAM_EXPECTED_SWING_RAGE
    local canQueueHSByBudget = (
        rage >= hsSoftRageThreshold
        or (rage >= ARMS_PVE_RAGE_DUMP_OVERFLOW and rage >= hsHardRageThreshold)
    )
    local canKeepHSByBudget = (rage >= hsHardRageThreshold)

    local aoeCoreRageReserve =
        ((ssOffRealCooldown or (slamState.timing and slamState.timing.ss <= slamState.timing.nextSwing))
            and ARMS_PVE_SWEEPING_STRIKES_RAGE_COST or 0)
        + ((wwOffRealCooldown or (slamState.timing and slamState.timing.ww <= slamState.timing.nextSwing))
            and ARMS_PVE_WHIRLWIND_RAGE_COST or 0)
    local cleaveHardRageThreshold = CLEAVE_RAGE_COST + aoeCoreRageReserve + slamRageReserve
    local cleaveSoftRageThreshold = cleaveHardRageThreshold + SLAM_EXPECTED_SWING_RAGE
    local canQueueCleaveByBudget = (
        rage >= cleaveSoftRageThreshold
        or (rage >= ARMS_PVE_RAGE_DUMP_OVERFLOW and rage >= cleaveHardRageThreshold)
    )
    local canKeepCleaveByBudget = (rage >= cleaveHardRageThreshold)

    if useCoreFirstAoE then
        -- Slam must pass the projected delay check. Queued Cleave retains
        -- funding for core cooldowns and any selected Slam.
        useWW = wwReadyNoGCD
        useSS = (useNonSweepingCorePriority and sweepingStrikesReadyForRotation)
        useSlam = thread2AoESlamReady
        useMS = thread2AoEMSReady
        wantCleaveQueued = ((not routineActions or routineActions["Cleave"] ~= false) and
            inMeleeRange
            and ((isCleaveQueued and canKeepCleaveByBudget)
                or (not isCleaveQueued and canQueueCleaveByBudget))
        )
        useCleave = (
            wantCleaveQueued
            and not isCleaveQueued
            and not isHSQueued
        )
    elseif isAoE then
        local ssReady = ssSpellAvailable

        if useSlamWindow then
            useSlam = true
        end
        
        -- WW is the highest AoE rage-spending GCD after an active Slam window;
        -- a fully funded off-GCD Cleave toggle may still be shown first.
        if not wwCD then
            if not ssReady or rage >= 50 then
                useWW = true
            end
        end
        
        -- Sweeping Strikes:
        -- 1. Normal condition: rage >= 50
        -- 2. Early sequence: we have Berserker Rage buff and (WW is off CD or Cleave is already queued)
        if sweepingStrikesReadyForRotation and not blockCoreForSlam and not ssCD then
            useSS = true
        end

        if enemiesWithDemo < math.ceil(enemiesNearby / 2) then
            useDemo = true
        end

        -- Queue using the sustainable budget. Once queued, retain it while the
        -- hard budget still protects every real-cooldown core spell and Slam.
        wantCleaveQueued = ((not routineActions or routineActions["Cleave"] ~= false) and
            inMeleeRange
            and ((isCleaveQueued and canKeepCleaveByBudget) or (not isCleaveQueued and canQueueCleaveByBudget))
        )
        useCleave = (wantCleaveQueued and not checkHSQueued)
    else
        -- single target
        if useSlamWindow then
            useSlam = true
        end
        
        if vrReadyNoGCD then
            useVR = true
        end
        
        if not msCD then
            useMS = true
        end

        if (hasEnemy or enemiesNearby > 0) and msCD and not wwCD then
            useWW = true
        end

        -- Ordinary Execute is only a filler after both MS and WW are on real cooldown.
        if isExecutePhase and not useLethalExecute and msOnRealCooldown and wwOnRealCooldown and executeReadyNoGCD then
            useExecuteFiller = true
        end

        -- Heroic Strike is an off-GCD next-swing toggle. A queued Cleave is
        -- replaced directly when the rotation becomes single-target.
        replaceCleaveWithHS = ((not routineActions or routineActions["Heroic Strike"] ~= false) and
            isCleaveQueued
            and inMeleeRange
            and not useLethalExecute
            and rage >= HEROIC_STRIKE_RAGE_COST
        )
        if replaceCleaveWithHS then
            armsReplacementHSExpireTime = GetTime() + mainhandSpeed + 0.5
        end
        local maintainReplacementHS = (
            isHSQueued
            and GetTime() <= armsReplacementHSExpireTime
            and rage >= HEROIC_STRIKE_RAGE_COST
        )
        local hsBudgetSatisfied = (
            (isHSQueued and canKeepHSByBudget)
            or (not isHSQueued and canQueueHSByBudget)
        )
        wantHSQueued = ((not routineActions or routineActions["Heroic Strike"] ~= false) and
            inMeleeRange
            and not useLethalExecute
            and (replaceCleaveWithHS or maintainReplacementHS or hsBudgetSatisfied)
        )
        useHS = (wantHSQueued and not isHSQueued)
    end

    local demoCoreBlocked = UsesWarriorDemoFallback() and (
        holdGCDForSlam or blockCoreForSlam
        or (useSlam and inMeleeRange)
        or (useMS and inMeleeRange and msReadyNoGCD)
        or (useWW and inAoERange and wwReadyNoGCD)
    )
    local demoFallbackReady = UsesWarriorDemoFallback() and not demoCoreBlocked
        and ShouldRefreshWarriorPveDemoralizingShout(_target, inMeleeRange)
    local useEarlyFallbackDemoralizingShout = (
        jungle.Engine
        and jungle.GetWarriorRoutineBehavior().earlyDemo
        and demoFallbackReady
    )
    if UsesWarriorDemoFallback() then
        useDemo = isAoE and demoFallbackReady
    end

    local sunderRemaining, sunderCountAura = GetDebuffRemaining(_target, 'Sunder Armor')
    local useUpdateSunder = (jungle.WarriorRoutineOptionEnabled("sunderStack") and canApplyTargetDebuff and sunderCountAura > 0 and sunderRemaining > 0 and sunderRemaining < 5)

    local cancelQueuedAttack = (
        not isCastingSlam
        and (
            (isHSQueued and not wantHSQueued)
            or (isCleaveQueued and not wantCleaveQueued and not replaceCleaveWithHS)
        )
    )

    local highHasteCoreReady = (
        useExecuteFiller
        or (useMS and msReadyNoGCD)
        or (useWW and wwReadyNoGCD)
        or (useVR and vrReadyNoGCD)
        or (useSS and ssReadyNoGCD)
        or useHS
        or useCleave
    )
    local prioritizeCoreOverSlam = useCoreFirstForHaste
        and not useSlamWindow
        and not useLethalExecute
        and highHasteCoreReady

    local shout, needsShout = jungle.GetWarriorDpsShout(5)

    local chargedVeryRecently = (chargeStart and chargeStart > 0 and (GetTime() - chargeStart) <= 0.2)
    if chargedVeryRecently and shout == 'Battle Shout' then
        needsShout = false
    end

    -- INTERRUPT LOGIC
    local usePummel = false
    local useZerkStanceForPummel = false
    if (not routineActions or routineActions["Pummel"] ~= false) and inMeleeRange and jungle.checkPveInterrupt(_target) then
        if stance == 3 then
            usePummel = (hasEnemy and ReadyCastSpellNoGCD('Pummel', _target))
        else
            useZerkStanceForPummel = ReadyCastSpellNoGCD('Berserker Stance')
        end
    end

    -- Every normal-path condition slot is assigned below. Early-return paths
    -- retain their own clears because they intentionally set only one action.
    warriorArmsCache[1][3] = ((not routineActions or routineActions[warriorArmsCache[1][2]] ~= false) and (useZerkStanceForPummel and not isCastingSlam))
    warriorArmsCache[2][3] = ((not routineActions or routineActions[warriorArmsCache[2][2]] ~= false) and (usePummel and not isCastingSlam))
    local usePriorityCleave = (
        not useCoreFirstAoE
        and useCleave
        and not useSlam
    )
    local priorityCleaveReady = (
        usePriorityCleave
        and inMeleeRange
        and (hasEnemy and ReadyCastSpellNoGCD('Cleave', _target))
    )
    -- A dodge proc may wait; never let Overpower or its stance dance consume
    -- the action reserved for an active or upcoming Slam window.
    local overpowerBlockedBySlam = (
        isCastingSlam
        or useSlamWindow
        or holdGCDForSlam
    )
    if useEarlyFallbackDemoralizingShout then
        warriorArmsCache[3][1] = 'Fallback Demoralizing Shout'
        warriorArmsCache[3][2] = 'Demoralizing Shout'
        warriorArmsCache[3][3] = (not routineActions or routineActions[warriorArmsCache[3][2]] ~= false) and (true)

        -- Thread 2's AoE layouts normally own these slots. Clear them while
        -- fallback maintenance uses the otherwise idle slot.
        if useCoreFirstAoE then
            for i = 4, 7 do
                warriorArmsCache[i][3] = false
            end
        end
    elseif useSweepingCorePriority then
        warriorArmsCache[3][1] = 'Sweeping Slam'
        warriorArmsCache[3][2] = 'Slam'
        warriorArmsCache[3][3] = ((not routineActions or routineActions[warriorArmsCache[3][2]] ~= false) and (useSlam and inMeleeRange))

        warriorArmsCache[4][1] = 'Sweeping Whirlwind'
        warriorArmsCache[4][2] = 'Whirlwind'
        warriorArmsCache[4][3] = ((not routineActions or routineActions[warriorArmsCache[4][2]] ~= false) and (useWW and not isCastingSlam and inAoERange and wwReadyNoGCD))

        if (isHSQueued or (isCleaveQueued and not wantCleaveQueued)) and not isCastingSlam then
            warriorArmsCache[5][1] = 'Cancel Unfunded/Replacement Queue'
            warriorArmsCache[5][2] = 'Stopcasting'
            warriorArmsCache[5][3] = (not routineActions or routineActions[warriorArmsCache[5][2]] ~= false) and (true)
        else
            warriorArmsCache[5][1] = 'Sweeping Cleave'
            warriorArmsCache[5][2] = 'Cleave'
            warriorArmsCache[5][3] = ((not routineActions or routineActions[warriorArmsCache[5][2]] ~= false) and (useCleave and not isCastingSlam and inMeleeRange and (hasEnemy and ReadyCastSpellNoGCD('Cleave', _target))))
        end

        warriorArmsCache[6][1] = 'Sweeping Mortal Strike'
        warriorArmsCache[6][2] = 'Mortal Strike'
        warriorArmsCache[6][3] = ((not routineActions or routineActions[warriorArmsCache[6][2]] ~= false) and (useMS and not isCastingSlam and inMeleeRange and msReadyNoGCD))
        warriorArmsCache[7][3] = false
    elseif useNonSweepingCorePriority then
        warriorArmsCache[3][1] = 'AoE Slam'
        warriorArmsCache[3][2] = 'Slam'
        warriorArmsCache[3][3] = ((not routineActions or routineActions[warriorArmsCache[3][2]] ~= false) and (useSlam and inMeleeRange))

        warriorArmsCache[4][1] = 'AoE Sweeping Strikes'
        warriorArmsCache[4][2] = 'Sweeping Strikes'
        warriorArmsCache[4][3] = ((not routineActions or routineActions[warriorArmsCache[4][2]] ~= false) and (useSS and not isCastingSlam and inAoERange and ssReadyNoGCD))

        warriorArmsCache[5][1] = 'AoE Whirlwind'
        warriorArmsCache[5][2] = 'Whirlwind'
        warriorArmsCache[5][3] = ((not routineActions or routineActions[warriorArmsCache[5][2]] ~= false) and (useWW and not isCastingSlam and inAoERange and wwReadyNoGCD))

        if (isHSQueued or (isCleaveQueued and not wantCleaveQueued)) and not isCastingSlam then
            warriorArmsCache[6][1] = 'Cancel Unfunded/Replacement Queue'
            warriorArmsCache[6][2] = 'Stopcasting'
            warriorArmsCache[6][3] = (not routineActions or routineActions[warriorArmsCache[6][2]] ~= false) and (true)
        else
            warriorArmsCache[6][1] = 'AoE Cleave'
            warriorArmsCache[6][2] = 'Cleave'
            warriorArmsCache[6][3] = ((not routineActions or routineActions[warriorArmsCache[6][2]] ~= false) and (useCleave and not isCastingSlam and inMeleeRange and (hasEnemy and ReadyCastSpellNoGCD('Cleave', _target))))
        end

        warriorArmsCache[7][1] = 'AoE Mortal Strike'
        warriorArmsCache[7][2] = 'Mortal Strike'
        warriorArmsCache[7][3] = ((not routineActions or routineActions[warriorArmsCache[7][2]] ~= false) and (useMS and not isCastingSlam and inMeleeRange and msReadyNoGCD))
    elseif usePriorityThunderClap then
        warriorArmsCache[3][1] = 'AoE Thunder Clap'
        warriorArmsCache[3][2] = 'Thunder Clap'
        warriorArmsCache[3][3] = (not routineActions or routineActions[warriorArmsCache[3][2]] ~= false) and (true)
    elseif useBattleStanceForOverpower and not overpowerBlockedBySlam then
        warriorArmsCache[3][1] = 'Overpower Stance'
        warriorArmsCache[3][2] = 'Battle Stance'
        warriorArmsCache[3][3] = (not routineActions or routineActions[warriorArmsCache[3][2]] ~= false) and (true)
    elseif usePriorityOverpower and not overpowerBlockedBySlam then
        warriorArmsCache[3][1] = 'Overpower'
        warriorArmsCache[3][2] = 'Overpower'
        warriorArmsCache[3][3] = (not routineActions or routineActions[warriorArmsCache[3][2]] ~= false) and (true)
    elseif cancelQueuedAttack then
        warriorArmsCache[3][1] = 'Cancel Queued Attack'
        warriorArmsCache[3][2] = 'Stopcasting'
        warriorArmsCache[3][3] = (not routineActions or routineActions[warriorArmsCache[3][2]] ~= false) and (true)
    elseif priorityCleaveReady then
        warriorArmsCache[3][1] = 'Cleave'
        warriorArmsCache[3][2] = 'Cleave'
        warriorArmsCache[3][3] = (not routineActions or routineActions[warriorArmsCache[3][2]] ~= false) and (true)
    else
        warriorArmsCache[3][1] = 'Sweeping Strikes'
        warriorArmsCache[3][2] = 'Sweeping Strikes'
        warriorArmsCache[3][3] = ((not routineActions or routineActions[warriorArmsCache[3][2]] ~= false) and (useSS and not blockCoreForSlam and inAoERange and ssReadyNoGCD))
    end

    if not useCoreFirstAoE then
        -- Eligible after-swing Slam has already passed the projected core-delay check.
        warriorArmsCache[4][1] = 'Slam'
        warriorArmsCache[4][2] = 'Slam'
        warriorArmsCache[4][3] = ((not routineActions or routineActions[warriorArmsCache[4][2]] ~= false) and (useSlam and not prioritizeCoreOverSlam and inMeleeRange))

        warriorArmsCache[5][1] = 'Lethal Execute'
        warriorArmsCache[5][2] = 'Execute'
        warriorArmsCache[5][3] = ((not routineActions or routineActions[warriorArmsCache[5][2]] ~= false) and (useLethalExecute and not blockCoreForSlam and executeReadyNoGCD))

        -- Heroic Strike is off-GCD and intentionally precedes MS/WW/VR.
        warriorArmsCache[6][1] = 'Heroic Strike'
        warriorArmsCache[6][2] = 'Heroic Strike'
        warriorArmsCache[6][3] = ((not routineActions or routineActions[warriorArmsCache[6][2]] ~= false) and (useHS and inMeleeRange and (hasEnemy and ReadyCastSpellNoGCD('Heroic Strike', _target))))

        warriorArmsCache[7][1] = 'Update Sunder Armor'
        warriorArmsCache[7][2] = 'Sunder Armor'
    end

    if not useCoreFirstAoE then
        warriorArmsCache[7][3] = ((not routineActions or routineActions[warriorArmsCache[7][2]] ~= false) and (useUpdateSunder and not blockCoreForSlam and inMeleeRange and (hasEnemy and ReadyCastSpellNoGCD('Sunder Armor', _target))))
    end
    warriorArmsCache[8][3] = ((not routineActions or routineActions[warriorArmsCache[8][2]] ~= false) and (not useCoreFirstAoE and useMS and not blockCoreForSlam and inMeleeRange and msReadyNoGCD))
    warriorArmsCache[9][3] = ((not routineActions or routineActions[warriorArmsCache[9][2]] ~= false) and (not useCoreFirstAoE and useWW and not blockCoreForSlam and inAoERange and wwReadyNoGCD))
    warriorArmsCache[10][3] = ((not routineActions or routineActions[warriorArmsCache[10][2]] ~= false) and (useExecuteFiller and not blockCoreForSlam and executeReadyNoGCD))
    warriorArmsCache[11][3] = ((not routineActions or routineActions[warriorArmsCache[11][2]] ~= false) and (useVR and not blockCoreForSlam and inMeleeRange and vrReadyNoGCD))
    local useZerkStanceForInterceptNow = (
        useZerkStanceForIntercept
        and not holdBattleForThunderClap
    )
    local gapCloserPending = useCharge or useBattleStanceForCharge or useIntercept or useZerkStanceForInterceptNow
    warriorArmsCache[12][3] = ((not routineActions or routineActions[warriorArmsCache[12][2]] ~= false) and (hasEnemy and not isAutoAttacking and not gapCloserPending)) -- Attack
    warriorArmsCache[13][3] = ((not routineActions or routineActions[warriorArmsCache[13][2]] ~= false) and (not useCoreFirstAoE and useCleave and not usePriorityCleave and inMeleeRange and (hasEnemy and ReadyCastSpellNoGCD('Cleave', _target))))
    warriorArmsCache[14][3] = (not routineActions or routineActions[warriorArmsCache[14][2]] ~= false) and (useBloodrage)
    warriorArmsCache[15][3] = ((not routineActions or routineActions[warriorArmsCache[15][2]] ~= false) and (useBerserkerRage and not blockCoreForSlam))
    warriorArmsCache[16][1] = shout
    warriorArmsCache[16][2] = shout
    warriorArmsCache[16][3] = ((not routineActions or routineActions[warriorArmsCache[16][2]] ~= false) and (not useCoreFirstAoE and (needsShout and ReadyCastSpellNoGCD(shout)) and not holdGCDForSlam))
    warriorArmsCache[17][3] = ((not routineActions or routineActions[warriorArmsCache[17][2]] ~= false) and (jungle.WarriorRoutineOptionEnabled("demo") and canApplyTargetDebuff and not useCoreFirstAoE and useDemo and not holdGCDForSlam and ReadyCastSpellNoGCD('Demoralizing Shout')))

    warriorArmsCache[18][3] = ((not routineActions or routineActions[warriorArmsCache[18][2]] ~= false) and (useCharge and not isCastingSlam))
    warriorArmsCache[19][3] = ((not routineActions or routineActions[warriorArmsCache[19][2]] ~= false) and (useBattleStanceForCharge and not isCastingSlam))
    warriorArmsCache[20][3] = ((not routineActions or routineActions[warriorArmsCache[20][2]] ~= false) and (useIntercept and not isCastingSlam))
    warriorArmsCache[21][3] = ((not routineActions or routineActions[warriorArmsCache[21][2]] ~= false) and ((useZerkStanceForInterceptNow or (useZerkStanceNormal and not holdGCDForSlam)) and not isCastingSlam))
    local hasTrinketBuff = jungle.unitCacheBuff('player', 'Death Wish') or jungle.unitCacheBuff('player', 'Lightning Speed')
    local useTrinkets = isAoE or hasTrinketBuff
    warriorArmsCache[22][3] = ((not routineActions or routineActions[warriorArmsCache[22][2]] ~= false) and (jungle.AreTrinketsReady() and inCombat and inMeleeRange and not (canExecute and targetHP < 50000) and (useTrinkets and true or false)))

    if armsDiagnosticsEnabled then
        local selectedAction = nil
        for i = 1, #warriorArmsCache do
            if warriorArmsCache[i][3] then
                selectedAction = warriorArmsCache[i][2]
                break
            end
        end
        RecordArmsDecision(selectedAction, warriorArmsCache[4][3])
    end
    
    return warriorArmsCache
end

-- ============================================================================
-- WARRIOR THREAD 3: SWEEPING STRIKES AOE MANAGEMENT
-- ============================================================================

local thread3BattleCleaveSwingBaseline = nil

local warriorThread3Cache = {
    [1]  = {'Charge', 'Charge', false, 1, 0},
    [2]  = {'Charge Stance', 'Battle Stance', false, 1, 0},
    [3]  = {'Intercept', 'Intercept', false, 1, 0},
    [4]  = {'Intercept Stance', 'Berserker Stance', false, 1, 0},
    [5]  = {'Attack', 'Attack', false, 1, 0},
    [6]  = {'Battle Thunder Clap', 'Thunder Clap', false, 1, 0},
    [7]  = {'Battle Cleave', 'Cleave', false, 1, 0},
    [8]  = {'Berserker Stance', 'Berserker Stance', false, 1, 0},
    [9]  = {'Sweeping Strikes', 'Sweeping Strikes', false, 1, 0},
    [10] = {'Sweeping Cleave', 'Cleave', false, 1, 0},
    [11] = {'Improved Slam', 'Slam', false, 1, 0},
    [12] = {'Trinkets', 'Trinkets', false, 1, 0},
    [13] = {'Whirlwind', 'Whirlwind', false, 1, 0},
    [14] = {'Core Filler', 'Bloodthirst', false, 1, 0},
    [15] = {'Bloodrage', 'Bloodrage', false, 1, 0},
    [16] = {'Berserker Rage', 'Berserker Rage', false, 1, 0},
    [17] = {'AoE Demoralizing Shout', 'Demoralizing Shout', false, 1, 0},
}

local function CountEligibleWarriorAoEEnemies(target)
    local count = 0
    local seenGUIDs = {}
    local nameplates = C_NamePlate.GetNamePlates()
    if jungle.RaidTrace.sample then jungle.RaidTrace:Count("warriorNameplateVisits", #nameplates) end
    for i = 1, #nameplates do
        local unit = GetNameplateUnitToken(nameplates[i], i)
        if IsEnemyNameplateEligibleForAoE(unit) and CheckInteractDistance(unit, 3) then
            local guid = UnitGUID(unit)
            if not guid or not seenGUIDs[guid] then
                count = count + 1
                if guid then seenGUIDs[guid] = true end
            end
        end
    end

    if IsEnemyNameplateEligibleForAoE(target) and CheckInteractDistance(target, 3) then
        local targetGUID = UnitGUID(target)
        if not targetGUID or not seenGUIDs[targetGUID] then
            count = count + 1
        end
    end
    return count
end

local function GetWarriorThread3State(target)
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    if not (not routineActions or routineActions["Sweeping Strikes"] ~= false) or not target or not UnitExists(target)
    or not UnitCanAttack("player", target)
    or UnitIsDeadOrGhost(target)
    or not warriorCapabilities.hasSweepingStrikes then
        return nil
    end

    local enemyCount = CountEligibleWarriorAoEEnemies(target)
    local sweepingActive = (jungle.unitCacheBuff('player', 'Sweeping Strikes') and true or false)
        or GetTime() <= armsSweepingStrikesCastGraceUntil
    local sweepingReady = IsSpellOffRealCooldown('Sweeping Strikes')
    if not sweepingActive and not sweepingReady then return nil end

    return {
        schedule = not UsesWarriorFuryRotation() and not UnitIsPlayer(target) and not UnitPlayerControlled(target),
        phase = sweepingActive and 'burst' or 'pooling',
        enemyCount = enemyCount,
        isAoE = enemyCount >= 2,
        sweepingActive = sweepingActive,
        sweepingReady = sweepingReady,
    }
end

function jungle.WarriorThread3OwnsTarget(target)
    return GetWarriorThread3State(target) ~= nil
end

local function CanThread3Slam(target, rageThreshold, timing)
    if not timing.allowed or not CanUseImprovedSlam() or UnitPower("player", 1) < rageThreshold then
        return false
    end
    if not jungle.inMeleeRange(target) or (GetUnitSpeed("player") or 0) > SLAM_STATIONARY_SPEED_MAX then
        return false
    end
    local hasPendingSwing = armsLastMainhandSwingTime > armsLastSlammedSwingTime
    local timeSinceSwing = armsLastMainhandSwingTime > 0 and (GetTime() - armsLastMainhandSwingTime) or 999
    return hasPendingSwing
        and timeSinceSwing >= 0
        and timeSinceSwing <= SLAM_AFTERSWING_WINDOW
        and UnitCastingInfo("player") ~= "Slam"
        and ReadyCastSpellNoGCD('Slam')
end

function jungle.warriorThread3AoE(_target)
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    for i = 1, #warriorThread3Cache do
        warriorThread3Cache[i][3] = false
    end

    warriorThread3Cache[10][1], warriorThread3Cache[10][2] = 'Cleave', 'Cleave'
    local threadState = GetWarriorThread3State(_target)
    if not threadState then
        thread3BattleCleaveSwingBaseline = nil
        return warriorThread3Cache
    end

    local gapCloser = GetWarriorGapCloserDecision(_target, ReadyCastSpellNoGCD)
    local rage = gapCloser.rage
    local stance = gapCloser.stance
    local inMeleeRange = gapCloser.inMeleeRange
    local isAutoAttacking = C_Spell.IsCurrentSpell(6603) or false
    local mainhandTimeRemaining = jungle.SwingTimer:GetSlamTimeRemaining(armsLastMainhandSwingTime)
    local hasConfirmedSwing = armsLastMainhandSwingTime > 0
    local aboutToSwing = isAutoAttacking
        and hasConfirmedSwing
        and jungle.SwingTimer:IsMainhandTimingReliable()
        and mainhandTimeRemaining <= THREAD3_PRE_SWING_WINDOW
    local isCleaveQueued = C_Spell.IsCurrentSpell("Cleave") or false
    local canApplyTargetDebuff = CanApplyWarriorTargetDebuff(_target)
    local slamRageThreshold = threadState.sweepingActive
        and ARMS_PVE_SWEEPING_MS_RAGE_THRESHOLD or ARMS_PVE_RAGE_DUMP_OVERFLOW
    if threadState.sweepingActive and routineActions then
        if routineActions['Whirlwind'] == false then slamRageThreshold = slamRageThreshold - ARMS_PVE_WHIRLWIND_RAGE_COST end
        if routineActions['Mortal Strike'] == false then slamRageThreshold = slamRageThreshold - ARMS_PVE_MORTAL_STRIKE_RAGE_COST end
        slamRageThreshold = math.max(ARMS_PVE_SLAM_RAGE_COST, slamRageThreshold)
    end
    local slamTiming = GetArmsSlamTiming(rage, threadState.isAoE, threadState.phase)
    if not threadState.schedule then slamTiming.allowed = true end
    local slamReady = CanThread3Slam(_target, slamRageThreshold, slamTiming)
    local wwReady = threadState.sweepingActive and inMeleeRange and ReadyCastSpellNoGCD('Whirlwind')
    local wwReserve = (not routineActions or routineActions['Whirlwind'] ~= false) and ARMS_PVE_WHIRLWIND_RAGE_COST or 0
    local fillerThreshold = (not routineActions or routineActions['Whirlwind'] ~= false) and ARMS_PVE_SWEEPING_MS_RAGE_THRESHOLD or ARMS_PVE_MORTAL_STRIKE_RAGE_COST
    local filler = warriorCapabilities.hasBloodthirst and (not routineActions or routineActions['Bloodthirst'] ~= false) and 'Bloodthirst'
        or (warriorCapabilities.hasMortalStrike and (not routineActions or routineActions['Mortal Strike'] ~= false) and 'Mortal Strike')
    local fillerReady = threadState.sweepingActive and filler ~= nil
        and rage >= fillerThreshold
        and inMeleeRange
        and not IsSpellOffRealCooldown('Whirlwind')
        and (not threadState.schedule or (slamTiming.ww >= slamTiming.start + 1.5
            and rage >= ARMS_PVE_MORTAL_STRIKE_RAGE_COST + wwReserve + slamTiming.queuedCost))
        and ReadyCastSpellNoGCD(filler, _target)
    local reserveSlam = aboutToSwing and CanUseImprovedSlam() and inMeleeRange
        and (GetUnitSpeed("player") or 0) <= SLAM_STATIONARY_SPEED_MAX
        and rage + SLAM_EXPECTED_SWING_RAGE >= slamRageThreshold
        and ReadyCastSpellNoGCD('Slam', nil, true)
    local useDemoralizingShout = threadState.isAoE
        and (not threadState.schedule
            or (threadState.phase == 'burst' and slamTiming.start + 1.5 <= slamTiming.ww)
            or (threadState.phase == 'pooling' and rage >= 90 + slamTiming.queuedCost
                and slamTiming.start + 1.5 <= math.max(0, slamTiming.oldSwing - THREAD3_PRE_SWING_WINDOW)))
        and not (slamReady or wwReady or fillerReady or reserveSlam or UnitCastingInfo("player") == "Slam")
        and ShouldRefreshWarriorPveDemoralizingShout(_target, inMeleeRange)

    warriorThread3Cache[1][3] = (not routineActions or routineActions[warriorThread3Cache[1][2]] ~= false) and (gapCloser.useCharge)
    warriorThread3Cache[2][3] = (not routineActions or routineActions[warriorThread3Cache[2][2]] ~= false) and (gapCloser.useBattleStanceForCharge)
    warriorThread3Cache[3][3] = (not routineActions or routineActions[warriorThread3Cache[3][2]] ~= false) and (gapCloser.useIntercept)
    warriorThread3Cache[4][3] = (not routineActions or routineActions[warriorThread3Cache[4][2]] ~= false) and (gapCloser.useBerserkerStanceForIntercept)
    if gapCloser.useCharge or gapCloser.useIntercept then
        RecordArmsGapCloser(GetTime(), true)
    end

    local gapCloserPending = gapCloser.useCharge
        or gapCloser.useBattleStanceForCharge
        or gapCloser.useIntercept
        or gapCloser.useBerserkerStanceForIntercept
    warriorThread3Cache[5][3] = (not routineActions or routineActions[warriorThread3Cache[5][2]] ~= false) and (not gapCloserPending and not isAutoAttacking)

    if gapCloserPending or not isAutoAttacking then
        return warriorThread3Cache
    end

    if threadState.schedule and threadState.phase == 'pooling' and slamTiming.queuedCost > 0
        and rage < 80 + slamTiming.queuedCost and UnitCastingInfo('player') ~= 'Slam' then
        warriorThread3Cache[10][1], warriorThread3Cache[10][2] = 'Protect Burst Rage', 'Stopcasting'
        warriorThread3Cache[10][3] = (not routineActions or routineActions[warriorThread3Cache[10][2]] ~= false) and (true)
        return warriorThread3Cache
    end

    -- Before Sweeping Strikes is spent, Thread 3 owns the rotation even when
    -- fewer than two verified enemies are nearby. Overflow may not deplete
    -- burst funding or postpone activation when another enemy arrives.
    if not threadState.sweepingActive and not threadState.isAoE then
        thread3BattleCleaveSwingBaseline = nil
        warriorThread3Cache[11][3] = (not routineActions or routineActions[warriorThread3Cache[11][2]] ~= false) and (CanThread3Slam(_target, ARMS_PVE_RAGE_DUMP_OVERFLOW, slamTiming))
        warriorThread3Cache[14][1] = 'Overflow Mortal Strike'
        warriorThread3Cache[14][2] = 'Mortal Strike'
        warriorThread3Cache[14][3] = (not routineActions or routineActions[warriorThread3Cache[14][2]] ~= false) and (warriorCapabilities.hasMortalStrike
            and rage >= ARMS_PVE_RAGE_DUMP_OVERFLOW
            and (not threadState.schedule or (rage >= 80 + ARMS_PVE_MORTAL_STRIKE_RAGE_COST + slamTiming.queuedCost
                and slamTiming.release <= math.max(0, slamTiming.oldSwing - THREAD3_PRE_SWING_WINDOW)))
            and inMeleeRange
            and ReadyCastSpellNoGCD('Mortal Strike', _target))
        warriorThread3Cache[15][3] = (not routineActions or routineActions[warriorThread3Cache[15][2]] ~= false) and (rage < ARMS_PVE_RAGE_DUMP_OVERFLOW
            and ReadyCastSpellNoGCD('Bloodrage'))
        warriorThread3Cache[16][3] = (not routineActions or routineActions[warriorThread3Cache[16][2]] ~= false) and (ReadyCastSpellNoGCD('Berserker Rage'))
        return warriorThread3Cache
    end

    -- When Thread 3 finds us in Battle Stance, spend the one available Thunder
    -- Clap first. If a Cleave can consume the imminent swing, wait for that
    -- confirmed swing before moving to Berserker Stance.
    if stance == 1 then
        local useThunderClap = canApplyTargetDebuff
            and inMeleeRange
            and ReadyCastSpellNoGCD('Thunder Clap')
        warriorThread3Cache[6][3] = (not routineActions or routineActions[warriorThread3Cache[6][2]] ~= false) and (useThunderClap)
        if useThunderClap then return warriorThread3Cache end

        if useDemoralizingShout then
            warriorThread3Cache[17][3] = (not routineActions or routineActions[warriorThread3Cache[17][2]] ~= false) and (true)
            return warriorThread3Cache
        end

        if thread3BattleCleaveSwingBaseline ~= nil then
            if armsLastMainhandSwingTime <= thread3BattleCleaveSwingBaseline then
                return warriorThread3Cache
            end
            thread3BattleCleaveSwingBaseline = nil
        elseif isCleaveQueued then
            if thread3BattleCleaveSwingBaseline == nil then
                thread3BattleCleaveSwingBaseline = armsLastMainhandSwingTime
            end
            return warriorThread3Cache
        elseif aboutToSwing and inMeleeRange and rage >= CLEAVE_RAGE_COST and IsNextSwingReady('Cleave', _target) then
            warriorThread3Cache[7][3] = (not routineActions or routineActions[warriorThread3Cache[7][2]] ~= false) and (true)
            return warriorThread3Cache
        else
            thread3BattleCleaveSwingBaseline = nil
        end

        warriorThread3Cache[8][3] = (not routineActions or routineActions[warriorThread3Cache[8][2]] ~= false) and (ReadyCastSpellNoGCD('Berserker Stance'))
        return warriorThread3Cache
    elseif stance ~= 3 then
        thread3BattleCleaveSwingBaseline = nil
        if useDemoralizingShout then
            warriorThread3Cache[17][3] = (not routineActions or routineActions[warriorThread3Cache[17][2]] ~= false) and (true)
            return warriorThread3Cache
        end
        warriorThread3Cache[8][3] = (not routineActions or routineActions[warriorThread3Cache[8][2]] ~= false) and (ReadyCastSpellNoGCD('Berserker Stance'))
        return warriorThread3Cache
    end
    thread3BattleCleaveSwingBaseline = nil

    if useDemoralizingShout then
        warriorThread3Cache[17][3] = (not routineActions or routineActions[warriorThread3Cache[17][2]] ~= false) and (true)
        return warriorThread3Cache
    end

    if threadState.sweepingActive then
        -- An off-GCD queue may precede WW only while leaving WW funded.
        -- Cancel an already queued spender that would consume that reserve.
        if threadState.schedule and slamTiming.queuedCost > 0 and rage < slamTiming.queuedCost + wwReserve
            and UnitCastingInfo('player') ~= 'Slam' then
            warriorThread3Cache[10][1], warriorThread3Cache[10][2] = 'Protect Whirlwind Rage', 'Stopcasting'
            warriorThread3Cache[10][3] = (not routineActions or routineActions[warriorThread3Cache[10][2]] ~= false) and (true)
            return warriorThread3Cache
        end
        warriorThread3Cache[10][3] = (not routineActions or routineActions[warriorThread3Cache[10][2]] ~= false) and (aboutToSwing
            and inMeleeRange
            and rage >= CLEAVE_RAGE_COST + (threadState.schedule and wwReserve or 0)
            and not isCleaveQueued
            and IsNextSwingReady('Cleave', _target))
        warriorThread3Cache[11][3] = (not routineActions or routineActions[warriorThread3Cache[11][2]] ~= false) and (slamReady and (not threadState.schedule or not wwReady))
        warriorThread3Cache[12][3] = (not routineActions or routineActions[warriorThread3Cache[12][2]] ~= false) and (jungle.AreTrinketsReady()
            and UnitAffectingCombat("player")
            and inMeleeRange)
        warriorThread3Cache[13][3] = (not routineActions or routineActions[warriorThread3Cache[13][2]] ~= false) and (wwReady)

        warriorThread3Cache[14][1] = filler and (filler .. ' Filler') or 'No Core Filler'
        warriorThread3Cache[14][2] = filler or ''
        warriorThread3Cache[14][3] = (not routineActions or routineActions[warriorThread3Cache[14][2]] ~= false) and (fillerReady)
        warriorThread3Cache[15][3] = (not routineActions or routineActions[warriorThread3Cache[15][2]] ~= false) and (rage < 80 and ReadyCastSpellNoGCD('Bloodrage'))
        warriorThread3Cache[16][3] = (not routineActions or routineActions[warriorThread3Cache[16][2]] ~= false) and (ReadyCastSpellNoGCD('Berserker Rage'))
        return warriorThread3Cache
    end

    -- Pooling phase: no normal rage spender may leak through to the baseline
    -- rotation. Overflow Slam also has to preserve burst funding and timing.
    warriorThread3Cache[11][3] = (not routineActions or routineActions[warriorThread3Cache[11][2]] ~= false) and (CanThread3Slam(_target, ARMS_PVE_RAGE_DUMP_OVERFLOW, slamTiming))
    warriorThread3Cache[9][3] = (not routineActions or routineActions[warriorThread3Cache[9][2]] ~= false) and (rage >= 80
        and aboutToSwing
        and inMeleeRange
        and ReadyCastSpellNoGCD('Sweeping Strikes'))
    warriorThread3Cache[15][3] = (not routineActions or routineActions[warriorThread3Cache[15][2]] ~= false) and (rage < 80 and ReadyCastSpellNoGCD('Bloodrage'))
    warriorThread3Cache[16][3] = (not routineActions or routineActions[warriorThread3Cache[16][2]] ~= false) and (ReadyCastSpellNoGCD('Berserker Rage'))
    return warriorThread3Cache
end

-- Adapted from wowsims/tbc-new arms.apl.json at d708f839d8bd6bedc97f668a64bb270ed608f123.
-- MIT attribution, source/API references and deliberate live adaptations:
-- docs/WARRIOR_WOWSIMS.md and docs/licenses/wowsims-tbc-new.txt.
-- Separate rows/timing keep the original routines and their 1.15s Slam policy intact.
do
    local rows = {
        {'WoWSims Attack', 'Attack', false},
        {'WoWSims Interrupt Stance', 'Berserker Stance', false},
        {'WoWSims Interrupt', 'Pummel', false},
        {'WoWSims Cancel Queue', 'Stopcasting', false},
        {'WoWSims Initial Sunder', 'Sunder Armor', false},
        {'WoWSims Stack Sunder', 'Sunder Armor', false},
        {'WoWSims Refresh Sunder', 'Sunder Armor', false},
        {'WoWSims Slam', 'Slam', false},
        {'WoWSims Mortal Strike', 'Mortal Strike', false},
        {'WoWSims Whirlwind', 'Whirlwind', false},
        {'WoWSims Execute', 'Execute', false},
        {'WoWSims Overpower Stance', 'Battle Stance', false},
        {'WoWSims Overpower', 'Overpower', false},
        {'WoWSims Berserker Stance', 'Berserker Stance', false},
        {'WoWSims Heroic Strike', 'Heroic Strike', false},
        {'WoWSims Hamstring', 'Hamstring', false},
        {'WoWSims Bloodrage', 'Bloodrage', false},
        {'WoWSims Battle Shout', 'Battle Shout', false},
        {'WoWSims Demoralizing Shout', 'Demoralizing Shout', false},
    }
    local sweepingRow = {'WoWSims Sweeping Strikes', 'Sweeping Strikes', false}
    local whirlwindRow = {'WoWSims AoE Whirlwind', 'Whirlwind', false}
    local cleaveRow = {'WoWSims Cleave', 'Cleave', false}
    -- Source multi-target order: SS/WW before Slam, Cleave after Execute.
    -- Reuse the existing rows so single-target ordering stays byte-for-byte stable.
    local aoeRows = {
        rows[1], rows[2], rows[3], rows[4], sweepingRow, whirlwindRow,
        rows[8], rows[9], rows[10], rows[11], cleaveRow,
        rows[12], rows[13], rows[14], rows[15], rows[16], rows[17], rows[18], rows[19],
    }
    local state = {}

    local function Ready(spell, target, offGCD)
        local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    if not (not routineActions or routineActions[spell] ~= false) then return false end
        -- Do not prequeue a GCD action beyond a narrow after-swing window.
        -- Queued Heroic Strike and off-GCD actions can still use the tick.
        if not offGCD and state.gcdRemaining > 0.01 then return false end
        if not GetSpellBookItemInfo(spell) then return false end
        local usable, insufficient = IsUsableSpell(spell)
        if usable ~= true or insufficient then return false end
        if GetArmsCoreCooldown(spell, state.now, state.gcdStart, state.gcdDuration) > 0 then return false end
        if target and jungle.actionHasRange[spell]
            and C_Spell.IsSpellInRange(spell, target) ~= true then return false end
        return true
    end

    local function UseWowsims(target)
        local behavior = jungle.GetWarriorRoutineBehavior()
        -- Registered placements supply their fixed mode. Standalone callers use
        -- the legacy option only as an eligibility gate, never a substitute.
        if not behavior.allowsWowsims
            or not jungle.Options
            or jungle.Options:GetArmsPveMode() ~= 'wowsims'
            or not warriorCapabilities.hasMortalStrike
            or warriorCapabilities.hasBloodthirst
            or not target or not UnitExists(target)
            or not UnitCanAttack('player', target) or UnitIsDeadOrGhost(target)
            or UnitIsDeadOrGhost('player') or UnitIsPlayer(target)
            or UnitPlayerControlled(target) or IsTotemUnit(target)
            or not UnitAffectingCombat('player') or not jungle.inMeleeRange(target) then
            return false
        end
        local _, offhand = UnitAttackSpeed('player')
        if not (warriorCapabilities.hasImprovedSlam2 and warriorCapabilities.hasSlam and HasTwoHandEquipped())
            and not (not HasTwoHandEquipped() and offhand) then return false end
        -- Enemy count selects priority inside the routine, not a legacy fallback.
        return true
    end


    local function Option(key)
        return jungle.Options:IsEnabled(key, 'WARRIOR')
    end

    local function EvaluateWowsims(target)
        local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    for i = 1, #rows do rows[i][3] = false end
        sweepingRow[3], whirlwindRow[3], cleaveRow[3] = false, false, false
        -- No action may cancel/restart a live Slam or another player cast.
        if UnitCastingInfo('player') or UnitChannelInfo('player') then return rows end

        state.now = GetTime()
        state.gcdStart, state.gcdDuration = jungle.GetGCDValues()
        state.gcdRemaining = math.max(0, (state.gcdStart or 0) + (state.gcdDuration or 0) - state.now)
        local rage = UnitPower('player', 1)
        local stance = GetShapeshiftForm()
        local twoHand = warriorCapabilities.hasImprovedSlam2 and warriorCapabilities.hasSlam and HasTwoHandEquipped()
        local aoeTargetEligible = IsEnemyNameplateEligibleForAoE(target)
        local isAoE = aoeTargetEligible and CountEligibleWarriorAoEEnemies(target) >= 2
        local hp, maxHP = UnitHealth(target), UnitHealthMax(target)
        local execute = (not routineActions or routineActions["Execute"] ~= false) and hp and maxHP and hp > 0 and maxHP > 0 and hp / maxHP <= 0.2
        local ms = GetArmsCoreCooldown('Mortal Strike', state.now, state.gcdStart, state.gcdDuration)
        local ww = GetArmsCoreCooldown('Whirlwind', state.now, state.gcdStart, state.gcdDuration)
        local delayCheck = ms >= 1.5 and ww >= 1.5
        local hsQueued = C_Spell.IsCurrentSpell('Heroic Strike')
        local cleaveQueued = C_Spell.IsCurrentSpell('Cleave')
        local bloodlust = jungle.unitCacheBuff('player', 'Bloodlust')
            or jungle.unitCacheBuff('player', 'Heroism')
        local hsThreshold = twoHand and 80 or 40
        local wantHS = not isAoE and not execute and rage >= hsThreshold

        rows[1][3] = (not routineActions or routineActions[rows[1][2]] ~= false) and (not C_Spell.IsCurrentSpell(6603))
        if (not routineActions or routineActions["Pummel"] ~= false) and jungle.checkPveInterrupt(target) then
            rows[2][3] = (not routineActions or routineActions[rows[2][2]] ~= false) and (stance ~= 3 and rage >= 10 and Ready('Berserker Stance', nil, true))
            rows[3][3] = (not routineActions or routineActions[rows[3][2]] ~= false) and (stance == 3 and Ready('Pummel', target, true))
        end
        -- /stopcasting is the platform's existing next-swing cancellation slot.
        -- Replace the previous mode's queue after a count/eligibility change.
        -- Thresholds control new queues, not cancellation after rage is spent.
        rows[4][3] = (not routineActions or routineActions[rows[4][2]] ~= false) and ((not isAoE and cleaveQueued) or (isAoE and hsQueued))

        -- Live adaptation: no future Bloodlust/encounter-duration oracle. Use
        -- affordable, learned SS on cooldown; retain T2's existing SS switch.
        sweepingRow[3] = (not routineActions or routineActions[sweepingRow[2]] ~= false) and (isAoE and warriorCapabilities.hasSweepingStrikes
            and jungle.WarriorRoutineOptionEnabled('sweeping')
            and not jungle.unitCacheBuff('player', 'Sweeping Strikes')
            and state.now > armsSweepingStrikesCastGraceUntil
            and rage >= 30 and Ready('Sweeping Strikes', nil, true))
        whirlwindRow[3] = (not routineActions or routineActions[whirlwindRow[2]] ~= false) and (isAoE and stance == 3 and Ready('Whirlwind'))
        cleaveRow[3] = (not routineActions or routineActions[cleaveRow[2]] ~= false) and (isAoE and rage >= 40 and not hsQueued and not cleaveQueued
            and Ready('Cleave', target, true))

        local remaining, stacks, expose = GetArmorDebuffState(target)
        local applied = armsPveSunderApplicationTimes[UnitGUID(target)]
        local settling = applied and state.now - applied < ARMS_PVE_SUNDER_AURA_SETTLE_TIME
        local canSunder = not isAoE and expose <= 0 and not settling and Ready('Sunder Armor', target)
        rows[5][3] = (not routineActions or routineActions[rows[5][2]] ~= false) and (canSunder and stacks == 0 and Option('wowsims_sunder_initial'))
        rows[6][3] = (not routineActions or routineActions[rows[6][2]] ~= false) and (canSunder and stacks > 0 and stacks < 5 and Option('wowsims_sunder_stack'))
        rows[7][3] = (not routineActions or routineActions[rows[7][2]] ~= false) and (canSunder and stacks > 0 and remaining > 0 and remaining <= 10
            and delayCheck and Option('wowsims_sunder_refresh'))

        local _, _, homeMS, worldMS = GetNetStats()
        local inputDelay = math.max(0, (worldMS or homeMS or 0) / 1000)
        local swing = jungle.SwingTimer
        local sinceSwing = swing:GetTimeSinceLastSwing()
        local pendingSwing = armsLastMainhandSwingTime > armsLastSlammedSwingTime
        local swingTargetMatches = swing:GetLastConfirmedMainhandSwingTargetGUID() == UnitGUID(target)
        local mainhandInterval = UnitAttackSpeed('player')
        -- Source: current haste-adjusted full MH interval >= 0.5s (not time remaining).
        -- Separate after-swing window: time since MH auto <= inputDelay + 300ms.
        -- Network latency is only a proxy for inputDelay; retain a 1.15s hard cap.
        rows[8][3] = (not routineActions or routineActions[rows[8][2]] ~= false) and (twoHand and pendingSwing and swingTargetMatches
            and swing:IsMainhandTimingReliable()
            and sinceSwing <= math.min(SLAM_AFTERSWING_WINDOW, inputDelay + 0.3)
            and (mainhandInterval or 0) >= 0.5
            and (GetUnitSpeed('player') or 0) <= SLAM_STATIONARY_SPEED_MAX
            and not (execute and bloodlust) and rage >= 15 and Ready('Slam', target))
        rows[9][3] = (not routineActions or routineActions[rows[9][2]] ~= false) and ((twoHand or not execute) and Ready('Mortal Strike', target))
        rows[10][3] = (not routineActions or routineActions[rows[10][2]] ~= false) and (aoeTargetEligible and stance == 3 and Ready('Whirlwind'))
        rows[11][3] = (not routineActions or routineActions[rows[11][2]] ~= false) and (execute and (twoHand or ww > 1.5) and Ready('Execute', target))

        local op = (not routineActions or routineActions["Overpower"] ~= false) and not isAoE and not twoHand and not execute and delayCheck and rage >= 5
            and state.now <= overpowerExpireTime and overpowerDodgeGUID == UnitGUID(target)
            and GetArmsCoreCooldown('Overpower', state.now, state.gcdStart, state.gcdDuration) == 0
        rows[12][3] = (not routineActions or routineActions[rows[12][2]] ~= false) and (op and stance ~= 1 and Ready('Battle Stance'))
        rows[13][3] = (not routineActions or routineActions[rows[13][2]] ~= false) and (op and stance == 1 and Ready('Overpower', target))
        rows[14][3] = (not routineActions or routineActions[rows[14][2]] ~= false) and (stance ~= 3 and not op and (ms <= inputDelay or ww <= inputDelay)
            and Ready('Berserker Stance', nil, true))
        rows[15][3] = (not routineActions or routineActions[rows[15][2]] ~= false) and (wantHS and not hsQueued and not cleaveQueued and Ready('Heroic Strike', target, true))
        rows[16][3] = (not routineActions or routineActions[rows[16][2]] ~= false) and (not twoHand and delayCheck and rage >= 40 and Ready('Hamstring', target))
        rows[17][3] = (not routineActions or routineActions[rows[17][2]] ~= false) and (rage < 90 and Ready('Bloodrage', nil, true))
        local shout, needsShout = jungle.GetWarriorDpsShout(10)
        rows[18][1] = shout == 'Commanding Shout' and 'WoWSims Commanding Shout' or 'WoWSims Battle Shout'
        rows[18][2] = shout
        rows[18][3] = (not routineActions or routineActions[rows[18][2]] ~= false) and (delayCheck and needsShout and Ready(shout))
        -- The source Arms APL has no Demo row. Keep this opt-in utility in
        -- its Delay Check filler gap, with the original AP-debuff coverage set.
        rows[19][3] = (not routineActions or routineActions[rows[19][2]] ~= false) and (aoeTargetEligible and Option('wowsims_demoralizing_shout') and delayCheck
            and GetDebuffRemaining(target, 'Demoralizing Shout') <= 5
            and not jungle.Debuff('Demoralizing Roar', target)
            and not jungle.Debuff('Curse of Weakness', target)
            and not jungle.Debuff('Screech', target)
            and Ready('Demoralizing Shout'))
        return isAoE and aoeRows or rows
    end

    jungle.WarriorWowsimsOwns = UseWowsims
    function jungle.warriorWowsims(target)
        if not UseWowsims(target) then return emptyCache end
        return EvaluateWowsims(target)
    end

    -- Original is an authored Arms/Fury dispatcher. It never substitutes a
    -- different algorithm because another routine is ineligible or waiting.
    function jungle.warriorUniversal(target)
        if UsesWarriorFuryRotation() then return jungle.warriorFury(target) end
        return jungle.warriorArms(target)
    end
end


-- Opt-in event timing; original scripts remain installed while tracing is off.
jungle.RaidTrace:WatchEventFrame(overpowerTracker, "warriorCombat")
jungle.RaidTrace:WatchEventFrame(warriorTalentFrame, "warriorCapabilities")

-- Narrow read-only bridge for the independent Adaptive Arms module.
-- No original priority, action registry, or shared readiness implementation changes.
jungle.WarriorAdaptiveContext = {
    capabilities = warriorCapabilities,
    gapCloser = GetWarriorGapCloserDecision,
    pvpUtilities = function(target)
        -- Reused utility decisions are part of Adaptive's authored PvP branch;
        -- this utility-only projection never selects Original core damage.
        return jungle.warriorArms(target, true)
    end,
    pvpDemo = function(target)
        -- Reuse the established missing/<=5s refresh rule for PvP fallback.
        return ShouldRefreshWarriorPveDemoralizingShout(target, jungle.inMeleeRange(target), true)
    end,
    hasTwoHand = HasTwoHandEquipped,
    canSlam = CanUseImprovedSlam,
    armorDebuff = GetArmorDebuffState,
    debuffRemaining = GetDebuffRemaining,
    hasAttackPowerDebuff = HasAttackPowerDebuff,
    hasOtherAttackPowerDebuff = HasOtherAttackPowerDebuff,
    canDebuff = CanApplyWarriorTargetDebuff,
    overpower = function(guid) return guid and guid == overpowerDodgeGUID and GetTime() <= overpowerExpireTime end,
    markDiagnostics = MarkArmsPveDiagnosticsActive,
    recordDiagnostics = UpdateArmsPveDiagnostics,
}

function jungle.ResetWarriorRoutineState()
    armsPveHoldBattleForThunderClap = false
    armsPveHoldBattleForThunderClapGUID, armsPveHoldBattleForThunderClapThread.behavior = nil, nil
    armsPveHoldBattleForThunderClapThread.thread, armsPveHoldBattleForThunderClapThread.revision = nil, nil
    thread3BattleCleaveSwingBaseline = nil
end

jungle.GetWarriorSlamDecisionState = GetArmsPveSlamState
