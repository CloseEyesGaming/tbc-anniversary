local Jungle, jungle = ...
jungle.RoutineAllows = jungle.RoutineAllows or function() return true end
jungle.GetRoutineThread = jungle.GetRoutineThread or function() return jungle.Engine and jungle.Engine.activeThread end
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
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    if not (not routineActions or routineActions[spell] ~= false) then return false end
    return GetSpellBookItemInfo(spell) ~= nil
end

local function IsSpellIDKnown(spellID)
    return ((IsPlayerSpell and IsPlayerSpell(spellID)) or (IsSpellKnown and IsSpellKnown(spellID))) and true or false
end

--------------------------------------------------------------------------------
-- MOONWEAVER WEAPON DISCOVERY
-- Velocity: highest static spell damage from either a 2H weapon or a 1H weapon
--           plus a held-in-off-hand caster item.
-- Battery:  highest form-only attack power on a 2H mace or staff.
--------------------------------------------------------------------------------
do
    local scanTooltip

    local function EnsureMoonweaverScanTooltip()
        if not scanTooltip then
            scanTooltip = CreateFrame("GameTooltip", "OliaMoonweaverScanTip", nil, "GameTooltipTemplate")
        end
        scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
        return scanTooltip
    end

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

    local function ToNumber(value)
        if type(value) == "number" then return value end
        if type(value) ~= "string" then return nil end
        return tonumber((value:gsub(",", "")))
    end

    local function GetItemStat(itemLink, statKeys)
        if type(GetItemStats) ~= "function" then return 0 end
        local stats = GetItemStats(itemLink)
        if type(stats) ~= "table" then return 0 end

        local best = 0
        for i = 1, #statKeys do
            local value = ToNumber(stats[statKeys[i]]) or 0
            if value > best then best = value end
        end
        return best
    end

    local SPELL_POWER_STAT_KEYS = {
        "ITEM_MOD_SPELL_POWER_SHORT",
        "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT",
        "ITEM_MOD_SPELL_DAMAGE_DONE",
    }
    local FERAL_AP_STAT_KEYS = {
        "ITEM_MOD_FERAL_ATTACK_POWER_SHORT",
        "ITEM_MOD_FERAL_ATTACK_POWER",
    }
    local HEALING_POWER_STAT_KEYS = {
        "ITEM_MOD_SPELL_HEALING_DONE_SHORT",
        "ITEM_MOD_SPELL_HEALING_DONE",
        "ITEM_MOD_HEALING_DONE_SHORT",
        "ITEM_MOD_HEALING_DONE",
    }

    local function ParseSpellPower(tip)
        local total = 0
        for i = 1, tip:NumLines() do
            local region = _G[tip:GetName() .. "TextLeft" .. i]
            local text = region and region:GetText()
            if text then
                -- TBC English tooltip variants.  Deliberately exclude temporary
                -- Use:/proc effects and school-specific damage bonuses.
                local amount = text:match("Increases damage and healing done by magical spells and effects by up to ([%d,]+)")
                if not amount then
                    amount = text:match("Increases healing done by up to [%d,]+ and damage done by up to ([%d,]+) for all magical spells and effects")
                end
                if not amount then
                    amount = text:match("Increases damage done by magical spells and effects by up to ([%d,]+)")
                end
                if not amount then
                    amount = text:match("^%+([%d,]+) Spell Damage and Healing$")
                        or text:match("^%+([%d,]+) Spell Damage$")
                end
                total = total + (ToNumber(amount) or 0)
            end
        end
        return total
    end

    local function ParseFeralAttackPower(tip)
        local best = 0
        for i = 1, tip:NumLines() do
            local region = _G[tip:GetName() .. "TextLeft" .. i]
            local text = region and region:GetText()
            if text then
                local amount = text:match("Increases attack power by ([%d,]+) in Cat, Bear, Dire Bear, and Moonkin forms only")
                amount = ToNumber(amount)
                if amount and amount > best then best = amount end
            end
        end
        return best
    end

    local function ParseHealingPower(tip)
        local total = 0
        for i = 1, tip:NumLines() do
            local region = _G[tip:GetName() .. "TextLeft" .. i]
            local text = region and region:GetText()
            if text then
                local amount = text:match("Increases healing done by up to ([%d,]+) and damage done by up to [%d,]+ for all magical spells and effects")
                    or text:match("Increases healing done by spells and effects by up to ([%d,]+)")
                    or text:match("Increases healing done by up to ([%d,]+)")
                    or text:match("^%+([%d,]+) Healing Spells$")
                    or text:match("^%+([%d,]+) Healing$")
                total = total + (ToNumber(amount) or 0)
            end
        end
        return total
    end

    local function CanUseItem(itemLink, requiredLevel)
        if requiredLevel and requiredLevel > UnitLevel("player") then return false end
        if type(IsEquippableItem) == "function" and not IsEquippableItem(itemLink) then return false end
        return true
    end

    function jungle.GetBestMoonweaverWeapons()
        local tip = EnsureMoonweaverScanTooltip()
        local best2HName, best2HSpellPower = nil, 0
        local best1HName, best1HSpellPower = nil, 0
        local bestOffHandName, bestOffHandSpellPower = nil, 0
        local bestBatteryName, bestBatteryFeralAP = nil, 0
        local bestHealing2HName, bestHealing2HPower = nil, 0
        local bestHealing1HName, bestHealing1HPower = nil, 0
        local bestHealingOffHandName, bestHealingOffHandPower = nil, 0

        local function ConsiderItem(itemLink, setTooltip)
            if not itemLink then return end

            local itemName, _, _, _, requiredLevel, _, _, _, equipLoc, _, _, classID, subclassID = GetItemInfo(itemLink)
            local isWeapon = classID == 2
            local isCasterOffHand = equipLoc == "INVTYPE_HOLDABLE"
            if not itemName or (not isWeapon and not isCasterOffHand) or not CanUseItem(itemLink, requiredLevel) then return end

            tip:ClearLines()
            tip:SetOwner(WorldFrame, "ANCHOR_NONE")
            setTooltip(tip)

            local tooltipSpellPower = ParseSpellPower(tip)
            local spellPower = math.max(tooltipSpellPower, GetItemStat(itemLink, SPELL_POWER_STAT_KEYS))
            local tooltipHealingPower = ParseHealingPower(tip)
            local healingPower = math.max(tooltipHealingPower, GetItemStat(itemLink, HEALING_POWER_STAT_KEYS))

            if equipLoc == "INVTYPE_2HWEAPON" then
                if spellPower > best2HSpellPower then
                    best2HName, best2HSpellPower = itemName, spellPower
                end
                if healingPower > bestHealing2HPower then
                    bestHealing2HName, bestHealing2HPower = itemName, healingPower
                end

                -- ItemWeaponSubclass: 5 = two-handed mace, 10 = staff.
                if subclassID == 5 or subclassID == 10 then
                    local feralAP = math.max(ParseFeralAttackPower(tip), GetItemStat(itemLink, FERAL_AP_STAT_KEYS))
                    if feralAP > bestBatteryFeralAP then
                        bestBatteryName, bestBatteryFeralAP = itemName, feralAP
                    end
                end
            elseif equipLoc == "INVTYPE_WEAPON" or equipLoc == "INVTYPE_WEAPONMAINHAND" then
                if spellPower > best1HSpellPower then
                    best1HName, best1HSpellPower = itemName, spellPower
                end
                if healingPower > bestHealing1HPower then
                    bestHealing1HName, bestHealing1HPower = itemName, healingPower
                end
            elseif equipLoc == "INVTYPE_HOLDABLE" then
                if spellPower > bestOffHandSpellPower then
                    bestOffHandName, bestOffHandSpellPower = itemName, spellPower
                end
                if healingPower > bestHealingOffHandPower then
                    bestHealingOffHandName, bestHealingOffHandPower = itemName, healingPower
                end
            end
        end

        for bag = 0, 4 do
            local numSlots = SafeGetNumSlots(bag)
            for slot = 1, numSlots do
                local itemLink = SafeGetItemLink(bag, slot)
                if itemLink then
                    ConsiderItem(itemLink, function(tooltip) tooltip:SetBagItem(bag, slot) end)
                end
            end
        end

        for _, invSlot in ipairs({16, 17}) do
            local itemLink = GetInventoryItemLink("player", invSlot)
            if itemLink then
                ConsiderItem(itemLink, function(tooltip) tooltip:SetInventoryItem("player", invSlot) end)
            end
        end

        local velocityMainHand, velocityOffHand, velocitySpellPower
        local oneHandSetupSpellPower = best1HSpellPower + bestOffHandSpellPower
        if best1HName and oneHandSetupSpellPower > best2HSpellPower then
            velocityMainHand = best1HName
            velocityOffHand = bestOffHandName
            velocitySpellPower = oneHandSetupSpellPower
        elseif best2HName and best2HSpellPower > 0 then
            velocityMainHand = best2HName
            velocityOffHand = nil
            velocitySpellPower = best2HSpellPower
        elseif best1HName and best1HSpellPower > 0 then
            velocityMainHand = best1HName
            velocityOffHand = bestOffHandName
            velocitySpellPower = oneHandSetupSpellPower
        end

        local healingMainHand, healingOffHand, healingSetPower
        local oneHandSetupHealing = bestHealing1HPower + bestHealingOffHandPower
        if bestHealing1HName and oneHandSetupHealing > bestHealing2HPower then
            healingMainHand = bestHealing1HName
            healingOffHand = bestHealingOffHandName
            healingSetPower = oneHandSetupHealing
        elseif bestHealing2HName and bestHealing2HPower > 0 then
            healingMainHand = bestHealing2HName
            healingOffHand = nil
            healingSetPower = bestHealing2HPower
        elseif bestHealing1HName and bestHealing1HPower > 0 then
            healingMainHand = bestHealing1HName
            healingOffHand = bestHealingOffHandName
            healingSetPower = oneHandSetupHealing
        end

        return velocityMainHand, velocityOffHand, bestBatteryName,
            velocitySpellPower or 0, bestBatteryFeralAP,
            healingMainHand, healingOffHand, healingSetPower or 0
    end
end

-- [[ STATE TRACKING ]]
-- Remembers which form we want to return to and for how long the window is open.
local powershiftTarget = 0   -- 3=Cat
local powershiftEndTime = 0  -- GetTime() timestamp
local tigerFuryLastActive = 0 -- [[ NEW: Internal CD Tracker for Tiger's Fury ]]

local druidCapabilities = {
    hasImprovedFaerieFire = false,
    improvedFaerieFireRank = 0,
}

local function RefreshDruidCapabilities()
    local improvedFaerieFireRank = 0

    if C_SpecializationInfo and C_SpecializationInfo.GetTalentInfo then
        for specializationIndex = 1, 3 do
            for talentIndex = 1, 40 do
                local talentInfo = C_SpecializationInfo.GetTalentInfo({
                    specializationIndex = specializationIndex,
                    talentIndex = talentIndex,
                    isInspect = false,
                    isPet = false,
                })
                if talentInfo
                and talentInfo.name == "Improved Faerie Fire"
                and ((talentInfo.rank or 0) > 0 or talentInfo.known) then
                    local detectedRank = talentInfo.rank or 0
                    if detectedRank <= 0 and talentInfo.known then
                        detectedRank = 1
                    end
                    improvedFaerieFireRank = math.max(improvedFaerieFireRank, detectedRank)
                    break
                end
            end
            if improvedFaerieFireRank > 0 then break end
        end
    end

    druidCapabilities.hasImprovedFaerieFire = improvedFaerieFireRank > 0
    druidCapabilities.improvedFaerieFireRank = improvedFaerieFireRank
end

local druidTalentFrame = CreateFrame("Frame")
druidTalentFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
druidTalentFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
druidTalentFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
druidTalentFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")
druidTalentFrame:SetScript("OnEvent", RefreshDruidCapabilities)
RefreshDruidCapabilities()

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

-- Cat powershifting requires the full 5/5 Furor talent. Bear powershifting is
-- deliberately unsupported by thread 5.
local function CheckCatPowershift()
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    if not (not routineActions or routineActions["Cat Form"] ~= false) then return false end
    if not IsSpellIDKnown(17061) then return false end

    local currentMana = UnitPower("player", 0)
    if currentMana < 600 then return false end -- Safety buffer
    if not jungle.IsSpellReadyIgnoreGCD("Cat Form") then return false end

    local shouldShift = false

    -- Break a root/slow only when full Furor makes the Cat return reliable.
    if jungle.isSlowed('player') then
        shouldShift = true
    end

    local energy = UnitPower("player", 3)
    local timeToTick = jungle.TimeUntilTick()
    if energy <= 11 and timeToTick <= 1 then
        shouldShift = true
    end

    if shouldShift then
        powershiftTarget = 3
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
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    local data = unitCache[friend]
    if not data then return emptyDispellCache end

    -- Refactor: Check if the 'poison' or 'curse' sub-tables have ANY entries
    local hasPoison = hasActiveDebuff(data.auras.debuffs.poison)
    local hasCurse = hasActiveDebuff(data.auras.debuffs.curse)

    dispellCache[1][3] = ((not routineActions or routineActions[dispellCache[1][2]] ~= false) and (jungle.ReadyCastSpell('Abolish Poison', friend) and hasPoison and not jungle.unitCacheBuff(friend, 'Abolish Poison', '_PLAYER')))
    dispellCache[2][3] = ((not routineActions or routineActions[dispellCache[2][2]] ~= false) and (jungle.ReadyCastSpell('Remove Curse', friend) and hasCurse))

    return dispellCache
end

local MOONWEAVER_AFTER_SWING_WINDOW = 0.25
local MOONWEAVER_BATTERY_ENTER_MANA = 0.05
local MOONWEAVER_BATTERY_EXIT_MANA = 0.10
local DRUID_EQUIP_ATTEMPT_TIMEOUT = 1.5
local moonweaverWrathSwungTargets = {}
local moonweaverStarfireFallbackTargets = {}
local moonkinBatteryMode = nil
local druidEquipAttemptState = {}

local function IsMoonweaverMeleeRange(unit)
    if not unit or not UnitExists(unit) then return false end

    local meleeRangeSpell = "Claw"
    -- Use the Druid melee ability Claw as the strict melee-range probe.
    if IsSpellInRange then
        local inRange = IsSpellInRange(meleeRangeSpell, unit)
        if inRange ~= nil then return inRange == 1 end
    end
    if C_Spell and C_Spell.IsSpellInRange then
        local inRange = C_Spell.IsSpellInRange(meleeRangeSpell, unit)
        if inRange ~= nil then return inRange == true or inRange == 1 end
    end

    -- Same compatibility fallback used by the installed Moonweaver addon and
    -- by Olia's established melee-range helper.
    return CheckInteractDistance(unit, 3) and true or false
end

-- Count attackable enemies that are in the strict Claw/melee range used by
-- Bear Swipe.  The primary target is added explicitly because it may not have
-- a visible nameplate (for example, a boss or a unit hidden by the UI).
local function CountDruidMeleeEnemies(primaryTarget)
    local count = 0
    local seen = {}

    local function addIfMeleeEnemy(unit)
        if not unit
        or not jungle.IsEnemyNameplateEligibleForAoE(unit)
        or not IsMoonweaverMeleeRange(unit) then
            return
        end

        local key = UnitGUID(unit) or unit
        if not seen[key] then
            seen[key] = true
            count = count + 1
        end
    end

    if C_NamePlate and C_NamePlate.GetNamePlates then
        local nameplates = C_NamePlate.GetNamePlates() or {}
        local getUnitToken = jungle.GetNameplateUnitToken
        for i = 1, #nameplates do
            local unit = getUnitToken and getUnitToken(nameplates[i], i) or ("nameplate" .. i)
            addIfMeleeEnemy(unit)
        end
    end

    addIfMeleeEnemy(primaryTarget)
    return count
end

local function UnitTargetsPlayer(unit)
    if not unit then return false end
    local targetUnit = unit .. "target"
    if UnitExists(targetUnit) then
        if UnitIsUnit(targetUnit, "player") then return true end

        local playerGUID = UnitGUID("player")
        if playerGUID ~= nil and UnitGUID(targetUnit) == playerGUID then
            return true
        end
    end

    -- Some Anniversary nameplate target tokens are unavailable for a frame.
    -- Threat status 2/3 is the authoritative fallback that the player is the
    -- unit's active tank target.
    local threatStatus = UnitThreatSituation and UnitThreatSituation("player", unit)
    return threatStatus ~= nil and threatStatus >= 2
end

local function HasMeleeEnemyTargetingPlayer(primaryTarget)
    if primaryTarget
    and IsMoonweaverMeleeRange(primaryTarget)
    and UnitTargetsPlayer(primaryTarget) then
        return true
    end

    if not C_NamePlate or not C_NamePlate.GetNamePlates then return false end
    local getUnitToken = jungle.GetNameplateUnitToken
    local nameplates = C_NamePlate.GetNamePlates() or {}
    for i = 1, #nameplates do
        local unit = getUnitToken and getUnitToken(nameplates[i], i) or ("nameplate" .. i)
        if unit
        and UnitExists(unit)
        and UnitCanAttack("player", unit)
        and not UnitIsDeadOrGhost(unit)
        and IsMoonweaverMeleeRange(unit)
        and UnitTargetsPlayer(unit) then
            return true
        end
    end
    return false
end

local function GetEquippedItemName(slot)
    local itemLink = GetInventoryItemLink("player", slot)
    return itemLink and GetItemInfo(itemLink) or nil
end

local function GetDruidEquipState(setName)
    local targets = jungle.Hotkeys
        and jungle.Hotkeys.EquipMacroTargets
        and jungle.Hotkeys.EquipMacroTargets[setName]
    if not targets or not targets.mainHand then return false, false end

    local mainHandMatches = GetEquippedItemName(16) == targets.mainHand
    local offHandMatches = not targets.offHand or GetEquippedItemName(17) == targets.offHand
    return true, mainHandMatches and offHandMatches
end

local function ResetDruidEquipAttempt(setName)
    druidEquipAttemptState[setName] = nil
end

function jungle.ResetDruidEquipAttemptState()
    druidEquipAttemptState = {}
end

local function ShouldRequestDruidEquip(setName, shouldEquip)
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    if not (not routineActions or routineActions[setName] ~= false) then return false end
    if not shouldEquip then
        ResetDruidEquipAttempt(setName)
        return false
    end

    local available, equipped = GetDruidEquipState(setName)
    if not available or equipped then
        ResetDruidEquipAttempt(setName)
        return false
    end

    local targets = jungle.Hotkeys.EquipMacroTargets[setName]
    local signature = targets.mainHand .. "\031" .. (targets.offHand or "")
    local state = druidEquipAttemptState[setName]
    -- Do not start or consume the attempt window while waiting for combat GCD.
    if not jungle.CanSwapWeapons() then
        if state and not state.gcdBlockedAt then state.gcdBlockedAt = GetTime() end
        return false
    end
    if state and state.gcdBlockedAt then
        state.startedAt = state.startedAt + GetTime() - state.gcdBlockedAt
        state.gcdBlockedAt = nil
    end
    if not state or state.signature ~= signature then
        state = { signature = signature, startedAt = GetTime(), timedOut = false }
        druidEquipAttemptState[setName] = state
        return true
    end

    if state.timedOut then return false end
    if GetTime() - state.startedAt >= DRUID_EQUIP_ATTEMPT_TIMEOUT then
        state.timedOut = true
        return false
    end

    return true
end

local function IsDruidFatWeaponForm(form)
    return form == 3
        or (form == 1 and IsSpellLearned("Dire Bear Form"))
end

local function GetDruidThread5WeaponSwap(form, target)
    if IsDruidFatWeaponForm(form) then
        moonkinBatteryMode = nil
        local useFatSwap = ShouldRequestDruidEquip("Equip2H", true)
        ShouldRequestDruidEquip("EquipDW", false)
        return useFatSwap, false
    end

    -- Battery and Velocity are Moonkin-only equipment states. Humanoid caster
    -- and all other forms leave the currently equipped weapon untouched.
    if form ~= 5 then
        moonkinBatteryMode = nil
        ShouldRequestDruidEquip("Equip2H", false)
        ShouldRequestDruidEquip("EquipDW", false)
        return false, false
    end

    local inMeleeRange = IsMoonweaverMeleeRange(target)
    local manaMax = UnitPowerMax("player", 0)
    local manaPercent = manaMax > 0 and (UnitPower("player", 0) / manaMax) or 1

    if not inMeleeRange then
        moonkinBatteryMode = false
    elseif manaPercent <= MOONWEAVER_BATTERY_ENTER_MANA then
        moonkinBatteryMode = true
    elseif manaPercent >= MOONWEAVER_BATTERY_EXIT_MANA then
        moonkinBatteryMode = false
    elseif moonkinBatteryMode == nil then
        -- Inside the hysteresis band, preserve an already equipped Battery.
        local batteryAvailable, batteryEquipped = GetDruidEquipState("Equip2H")
        moonkinBatteryMode = batteryAvailable and batteryEquipped
    end

    local wantsBattery = moonkinBatteryMode == true
    local useBatterySwap = ShouldRequestDruidEquip("Equip2H", wantsBattery)
    local useVelocitySwap = ShouldRequestDruidEquip("EquipDW", not wantsBattery)
    return useBatterySwap, useVelocitySwap
end

local function HasLiveDruidDpsTarget()
    local function isAttackable(unit)
        return UnitExists(unit)
            and UnitCanAttack("player", unit)
            and not UnitIsDeadOrGhost(unit)
    end

    return isAttackable("target") or isAttackable("softenemy")
end

local function CanMoonweaveHardcast()
    local timer = jungle.SwingTimer
    if not timer or not timer.GetMainhandTimeRemaining
    or not timer.GetLastConfirmedMainhandSwingTime then
        return false
    end

    local lastConfirmedSwing = timer:GetLastConfirmedMainhandSwingTime()
    if not lastConfirmedSwing then return false end

    local sinceSwing = GetTime() - lastConfirmedSwing
    if sinceSwing < 0 or sinceSwing > MOONWEAVER_AFTER_SWING_WINDOW then
        return false
    end

    -- Only a confirmed internal swing can open this hardcast opportunity.
    local timeToSwing = timer:GetMainhandTimeRemaining(lastConfirmedSwing)
    return type(timeToSwing) == "number" and timeToSwing > MOONWEAVER_AFTER_SWING_WINDOW
end

local function HasMoonweaverWrathOpeningSwing(unit)
    local targetGUID = unit and UnitGUID(unit)
    if not targetGUID then return false end
    if moonweaverWrathSwungTargets[targetGUID] then return true end

    local timer = jungle.SwingTimer
    if timer
    and timer.GetLastConfirmedMainhandSwingTargetGUID
    and timer:GetLastConfirmedMainhandSwingTargetGUID() == targetGUID then
        -- Enemy GUIDs are unique for each spawn, so this remembers exactly one
        -- opening swing for this enemy while naturally resetting on a new one.
        moonweaverWrathSwungTargets[targetGUID] = true
        return true
    end

    return false
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
    [1]= {'Swipe (AoE)', 'Swipe', false, 1, 0},
    [2]= {'Demo Roar', 'Demoralizing Roar', false, 1, 0},
    [3]= {'Mangle Bear', 'Mangle (Bear)', false, 1, 0},
    [4]= {'Maul', 'Maul', false, 1, 0},
    [5]= {'Lacerate', 'Lacerate', false, 1, 0}, 
    [6]= {'FF Feral', 'Faerie Fire (Feral)', false, 1, 0},
    [7]= {'Attack', 'Attack', false, 1, 0},
}
local dpsCasterCache = {
    [1]= {'Equip Battery', 'Equip2H', false, 1, 0},
    [2]= {'Equip Velocity', 'EquipDW', false, 1, 0},
    [3]= {'Faerie Fire', 'Faerie Fire', false, 1, 0},
    [4]= {'Moonfire', 'Moonfire', false, 1, 0},
    [5]= {'Insect Swarm', 'Insect Swarm', false, 1, 0},
    [6]= {'Starfire', 'Starfire', false, 1, 0},
    [7]= {'Wrath', 'Wrath', false, 1, 0},
    [8]= {'Attack', 'Attack', false, 1, 0},
}
local dpsIdleWeaponCache = {
    [1]= {'Equip FAT', 'Equip2H', false, 1, 0},
    [2]= {'Equip Velocity', 'EquipDW', false, 1, 0},
}
local dpsWeaponSwapCache = {
    [1]= {'Equip Battery', 'Equip2H', false, 1, 0},
    [2]= {'Equip Velocity', 'EquipDW', false, 1, 0},
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
local healingWeaponCache = {
    [1]= {'Equip Healing', 'EquipShield', false, 1, 0},
}

local function GetAppliedImprovedFaerieFireRank(target)
    local bestRank = 0

    local function ConsiderAura(auraName)
        local _, meleeHitBonus, rangedHitBonus = jungle.DebuffEffectValues(auraName, target)
        bestRank = math.max(bestRank, tonumber(meleeHitBonus) or 0, tonumber(rangedHitBonus) or 0)

        -- Compatibility fallback if the client omits effect values: an aura
        -- applied by this talented player necessarily carries our talent rank.
        if bestRank == 0 and jungle.Debuff(auraName, target, '|PLAYER') then
            bestRank = druidCapabilities.improvedFaerieFireRank
        end
    end

    ConsiderAura('Faerie Fire')
    ConsiderAura('Faerie Fire (Feral)')
    return bestRank
end
local emptyDpsCache = {}

function jungle.druidHealingWeaponSet(unit)
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    local shouldEquipHealing = false
    if unit and UnitIsUnit(unit, "player") then
        shouldEquipHealing = ShouldRequestDruidEquip("EquipShield", true)
    end

    healingWeaponCache[1][3] = (not routineActions or routineActions[healingWeaponCache[1][2]] ~= false) and (shouldEquipHealing)
    return healingWeaponCache
end

-- THREAD 5: STANCE-AWARE DPS
function jungle.druidDpsIdleSet(unit)
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    local useFatSwap, useVelocitySwap = false, false
    local form = GetShapeshiftForm()

    if unit
    and UnitIsUnit(unit, "player")
    and (form == 5 or IsDruidFatWeaponForm(form))
    and not HasLiveDruidDpsTarget() then
        useFatSwap, useVelocitySwap = GetDruidThread5WeaponSwap(form)
    end

    dpsIdleWeaponCache[1][3] = (not routineActions or routineActions[dpsIdleWeaponCache[1][2]] ~= false) and (useFatSwap)
    dpsIdleWeaponCache[2][3] = (not routineActions or routineActions[dpsIdleWeaponCache[2][2]] ~= false) and (useVelocitySwap)
    return dpsIdleWeaponCache
end

-- A completed hardcast arms one stationary Moonfire for this enemy only.
-- The opener can succeed before the combat flag turns on. Reset on combat
-- exit (PLAYER_REGEN_ENABLED), not on every out-of-combat evaluation.
local pendingMoonfireGUID
local function GetMoonfireMaintenanceTarget()
    if UnitExists("target") and UnitCanAttack("player", "target")
    and not UnitIsDeadOrGhost("target") then
        return "target"
    end
    if UnitExists("softenemy") and UnitCanAttack("player", "softenemy")
    and not UnitIsDeadOrGhost("softenemy") then
        return "softenemy"
    end
end

local moonfireMaintenanceTracker = CreateFrame("Frame")
moonfireMaintenanceTracker:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
moonfireMaintenanceTracker:RegisterEvent("PLAYER_TARGET_CHANGED")
moonfireMaintenanceTracker:RegisterEvent("PLAYER_SOFT_ENEMY_CHANGED")
moonfireMaintenanceTracker:RegisterEvent("PLAYER_REGEN_ENABLED")
moonfireMaintenanceTracker:RegisterEvent("PLAYER_ENTERING_WORLD")
moonfireMaintenanceTracker:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_SOFT_ENEMY_CHANGED" then
        local target = GetMoonfireMaintenanceTarget()
        if not target or UnitGUID(target) ~= pendingMoonfireGUID then
            pendingMoonfireGUID = nil
        end
        return
    end
    if event ~= "COMBAT_LOG_EVENT_UNFILTERED" then
        pendingMoonfireGUID = nil
        return
    end

    local _, subEvent, _, sourceGUID, _, _, _, destGUID, _, _, _, _, spellName = CombatLogGetCurrentEventInfo()
    if subEvent ~= "SPELL_CAST_SUCCESS" or sourceGUID ~= UnitGUID("player") or not destGUID then return end

    if spellName == (GetSpellInfo("Moonfire") or "Moonfire") then
        if destGUID == pendingMoonfireGUID then pendingMoonfireGUID = nil end
        return
    end
    if spellName ~= (GetSpellInfo("Wrath") or "Wrath")
    and spellName ~= (GetSpellInfo("Starfire") or "Starfire") then return end
    if not jungle.Engine or jungle.GetRoutineThread() ~= 5
    or GetShapeshiftForm() ~= 5 then return end

    local target = GetMoonfireMaintenanceTarget()
    if target and UnitGUID(target) == destGUID and not UnitIsPVP(target) then
        pendingMoonfireGUID = destGUID
    end
end)

function jungle.dpsSet(_target)
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    local hasEnemy = _target ~= nil and UnitExists(_target)
        and UnitCanAttack("player", _target) and not UnitIsDeadOrGhost(_target)
    if not hasEnemy then _target = nil end

    local guid = hasEnemy and UnitGUID(_target)
    if pendingMoonfireGUID ~= guid then
        pendingMoonfireGUID = nil
    end
    local form = GetShapeshiftForm()
    local isPowershiftRecovery = form == 0
        and GetTime() < powershiftEndTime
        and powershiftTarget > 0
    local useBatterySwap, useVelocitySwap = false, false
    if not isPowershiftRecovery then
        useBatterySwap, useVelocitySwap = GetDruidThread5WeaponSwap(form, _target)
    end
    dpsWeaponSwapCache[1][3] = (not routineActions or routineActions[dpsWeaponSwapCache[1][2]] ~= false) and (useBatterySwap)
    dpsWeaponSwapCache[2][3] = (not routineActions or routineActions[dpsWeaponSwapCache[2][2]] ~= false) and (useVelocitySwap)
    dpsWeaponSwapCache[1][1] = IsDruidFatWeaponForm(form) and "Equip FAT" or "Equip Battery"
    if useBatterySwap or useVelocitySwap then
        return dpsWeaponSwapCache
    end

    local isStealthed = IsStealthed()
    local cp = hasEnemy and GetComboPoints('player', _target) or 0
    local targetHP = hasEnemy and UnitHealth(_target) or 0
    local targetHPPercent = hasEnemy and (targetHP / UnitHealthMax(_target)) * 100 or 100
    local isElite = hasEnemy and (UnitClassification(_target) == "elite" or UnitClassification(_target) == "worldboss")
    
    local shouldAttack = (hasEnemy and not isStealthed and not IsCurrentSpell(6603))

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
    local shouldRake = hasEnemy and (not jungle.Debuff('Rake', _target, '|PLAYER') and cp < 4 and livesLongEnough) and UnitCreatureType(_target)~="Elemental" and UnitCreatureType(_target)~="Totem"

    -- 5. FINISHER LOGIC (Rip vs FB)
    local useRip = ((not routineActions or routineActions["Rip"] ~= false) and isElite and ttd > 12 and not jungle.Debuff('Rip', _target, '|PLAYER') and cp >= 4)
    local useFB = (not routineActions or routineActions["Ferocious Bite"] ~= false) and (isKillShot or (cp == 5 and not useRip))

    -- BEGIN STANCE LOGIC
    if form == 3 then -- CAT FORM
		local energy = UnitPower("player", 3)
		local timeToTick = jungle.TimeUntilTick()
        
        -- [[ NEW: UPDATE TIGER'S FURY TRACKER ]]
        if jungle.unitCacheBuff('player', "Tiger's Fury") then
            tigerFuryLastActive = GetTime()
        end

        if isStealthed then
            dpsCatStealthCache[1][3] = (((not routineActions or routineActions[dpsCatStealthCache[1][2]] ~= false) and (hasEnemy and jungle.ReadyCastSpell('Ravage', _target))))
            dpsCatStealthCache[2][3] = ((not routineActions or routineActions[dpsCatStealthCache[2][2]] ~= false) and ((hasEnemy or CountDruidMeleeEnemies(nil) > 0) and not jungle.unitCacheBuff('player', "Tiger's Fury") and jungle.ReadyCastSpell("Tiger's Fury") and cp <= 1 and timeToTick <= 1))
            return dpsCatStealthCache
        else
            -- [[ POWERSHIFT CONDITIONAL ]]
            local limitPowershift = hasEnemy and (UnitPower("player", 0) / UnitPowerMax("player", 0) < 0.5) 
                                    and UnitIsUnit("player", _target .. "target") 
                                    and not UnitIsPlayer(_target)
            local catBuilderSpell = IsSpellLearned('Mangle (Cat)') and 'Mangle (Cat)' or 'Claw'

            dpsCatCache[1][3] = ((not routineActions or routineActions[dpsCatCache[1][2]] ~= false) and ((hasEnemy and jungle.ReadyCastSpell('Rip', _target)) and useRip))
            dpsCatCache[2][3] = ((not routineActions or routineActions[dpsCatCache[2][2]] ~= false) and ((hasEnemy and jungle.ReadyCastSpell('Ferocious Bite', _target)) and useFB))
            dpsCatCache[3][3] = ((not routineActions or routineActions[dpsCatCache[3][2]] ~= false) and ((hasEnemy and jungle.ReadyCastSpell('Faerie Fire (Feral)', _target)) and not jungle.Debuff('Faerie Fire (Feral)', _target) and  not jungle.Debuff('Faerie Fire', _target) and UnitCreatureType(_target)~="Elemental" and UnitCreatureType(_target)~="Totem"))
            dpsCatCache[4][3] = ((not routineActions or routineActions[dpsCatCache[4][2]] ~= false) and ((hasEnemy or CountDruidMeleeEnemies(nil) > 0) and not jungle.unitCacheBuff('player', "Tiger's Fury") and jungle.ReadyCastSpell("Tiger's Fury") and cp == 0 and (GetTime() - tigerFuryLastActive > 3) and (timeToTick <= 0.5 and energy >= 60)))
            dpsCatCache[5][3] = ((not routineActions or routineActions[dpsCatCache[5][2]] ~= false) and ((hasEnemy and jungle.ReadyCastSpell('Rake', _target)) and shouldRake and jungle.ImNotBehindUnit(_target)))
            dpsCatCache[6][1] = (catBuilderSpell == 'Mangle (Cat)') and 'Mangle Cat' or 'Claw'
            dpsCatCache[6][2] = catBuilderSpell
            dpsCatCache[6][3] = ((not routineActions or routineActions[dpsCatCache[6][2]] ~= false) and ((hasEnemy and jungle.ReadyCastSpell(catBuilderSpell, _target)) and cp < 5 and (jungle.ImNotBehindUnit(_target) or ( not UnitIsPlayer(_target) and UnitIsUnit('player', _target..'target')))))
            dpsCatCache[7][3] = ((not routineActions or routineActions[dpsCatCache[7][2]] ~= false) and ((hasEnemy and jungle.ReadyCastSpell('Shred', _target)) and cp < 5 and  not jungle.ImNotBehindUnit(_target)))
            dpsCatCache[8][3] = ((not routineActions or routineActions[dpsCatCache[8][2]] ~= false) and (shouldAttack))
            dpsCatCache[9][3] = ((not routineActions or routineActions[dpsCatCache[9][2]] ~= false) and ((hasEnemy or jungle.isSlowed('player')) and not limitPowershift and CheckCatPowershift() and (not hasEnemy or IsSpellInRange("Rake", "target") == 1) and not jungle.unitCacheBuff('player', "Clearcasting")))

            return dpsCatCache
        end

    elseif form == 1 then -- BEAR FORM
        local rage = UnitPower("player", 1)
        local hasMangleBear = IsSpellLearned('Mangle (Bear)')
        local hasFiveLacerateStacks = hasEnemy and jungle.Debuff('Lacerate', _target, nil, nil, 5)
        local meleeEnemies = CountDruidMeleeEnemies(_target)
        local isAoE = meleeEnemies >= 2
        local inClawMeleeRange = (hasEnemy and IsMoonweaverMeleeRange(_target)) or (not hasEnemy and meleeEnemies > 0)
        
        local needsDemo = hasEnemy and not jungle.Debuff('Demoralizing Roar', _target)
        if not hasEnemy and meleeEnemies > 0 then
            local plates = C_NamePlate and C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates() or {}
            for i = 1, #plates do
                local unit = jungle.GetNameplateUnitToken and jungle.GetNameplateUnitToken(plates[i], i)
                if unit and jungle.IsEnemyNameplateEligibleForAoE(unit)
                and IsMoonweaverMeleeRange(unit) and not jungle.Debuff('Demoralizing Roar', unit) then
                    needsDemo = true
                    break
                end
            end
        end
        local demoContext = (jungle.targetedByCount('player', 'phys') >= 2 or isElite)
        local inDemoRange = (hasEnemy and jungle.inMeleeRange(_target)) or (not hasEnemy and meleeEnemies > 0) 
        local useDemo = (jungle.ReadyCastSpell('Demoralizing Roar') and needsDemo and demoContext and inDemoRange)

        local maulIDs = {6807, 6808, 6809, 8972, 9745, 9880, 9881, 26996}
        local isMaulQueued = false
        for _, id in ipairs(maulIDs) do
            if IsCurrentSpell(id) then isMaulQueued = true break end
        end

        -- Mangle builds retain the existing 45-rage reserve. Without Mangle,
        -- reserve 30 rage while building Lacerate, then queue Maul at 15 rage.
        local maulRageThreshold = hasMangleBear and 45 or ((not (not routineActions or routineActions["Lacerate"] ~= false) or hasFiveLacerateStacks) and 15 or 30)
        local canMaul = (hasEnemy and not isMaulQueued and rage >= maulRageThreshold and inDemoRange)

        -- Swipe is an instant area ability; use Claw for the target-range gate
        -- because Swipe itself is not a reliable targeted range probe.
        dpsBearCache[1][3] = ((not routineActions or routineActions[dpsBearCache[1][2]] ~= false) and (isAoE and rage >= 20 and inClawMeleeRange and jungle.ReadyCastSpell('Swipe')))
        dpsBearCache[2][3] = ((not routineActions or routineActions[dpsBearCache[2][2]] ~= false) and (useDemo))
        dpsBearCache[3][1] = hasMangleBear and 'Mangle Bear' or 'Lacerate'
        dpsBearCache[3][2] = hasMangleBear and 'Mangle (Bear)' or 'Lacerate'
        dpsBearCache[3][3] = (not routineActions or routineActions[dpsBearCache[3][2]] ~= false) and (hasMangleBear
            and (hasEnemy and jungle.ReadyCastSpell('Mangle (Bear)', _target))
            or (not hasMangleBear and not hasFiveLacerateStacks and (hasEnemy and jungle.ReadyCastSpell('Lacerate', _target))))
        dpsBearCache[4][3] = ((not routineActions or routineActions[dpsBearCache[4][2]] ~= false) and ((hasEnemy and jungle.ReadyCastSpell('Maul', _target)) and canMaul))
        dpsBearCache[5][3] = ((not routineActions or routineActions[dpsBearCache[5][2]] ~= false) and (hasMangleBear and (hasEnemy and jungle.ReadyCastSpell('Lacerate', _target)) and not jungle.Debuff('Lacerate', _target, nil, 5))) 
        dpsBearCache[6][3] = ((not routineActions or routineActions[dpsBearCache[6][2]] ~= false) and ((hasEnemy and jungle.ReadyCastSpell('Faerie Fire (Feral)', _target)) and not jungle.Debuff('Faerie Fire (Feral)', _target) and  not jungle.Debuff('Faerie Fire', _target) and UnitCreatureType(_target)~="Elemental" and UnitCreatureType(_target)~="Totem"))
        dpsBearCache[7][3] = ((not routineActions or routineActions[dpsBearCache[7][2]] ~= false) and (shouldAttack))

        return dpsBearCache
    else -- CASTER / HUMAN (Default)
        
        -- [[ POWERSHIFT RECOVERY LOGIC ]]
        -- If we are in the powershift window (timer active), we IGNORE caster spells 
        -- and FORCE the return to the target form immediately.
        if GetTime() < powershiftEndTime and powershiftTarget > 0 then
            local returnSpell = powershiftTarget == 3 and "Cat Form"
            if returnSpell then
                dpsPowershiftCache[1][2] = returnSpell
                dpsPowershiftCache[1][3] = ((not routineActions or routineActions[dpsPowershiftCache[1][2]] ~= false) and (jungle.ReadyCastSpell(returnSpell)))
                return dpsPowershiftCache
            end
        end
		
        if not hasEnemy then return emptyDpsCache end

		-- Standard Caster Rotation (Only if window expired or manual shift)
        local isMoving = GetUnitSpeed('player') > 0
        local inCombat = UnitAffectingCombat('player')
        local isPvPTarget = UnitIsPVP(_target)
        local starfireReady = not isMoving and (hasEnemy and jungle.ReadyCastSpell('Starfire', _target))
        local wrathReady = not isMoving and (hasEnemy and jungle.ReadyCastSpell('Wrath', _target))

        -- GetShapeshiftForm is authoritative here; a cached aura must never
        -- keep weapon swaps or swing gating alive after leaving Moonkin Form.
        local isMoonkin = (form == 5)
        local targetLevel = UnitLevel(_target)
        local isSkullOrBoss = targetLevel == -1 or UnitClassification(_target) == "worldboss"
        local hasMoonfire = jungle.Debuff('Moonfire', _target, '|PLAYER')
        local hasInsectSwarm = jungle.Debuff('Insect Swarm', _target, '|PLAYER')
        local hasFaerieFire = not (not routineActions or routineActions['Faerie Fire'] ~= false) or jungle.Debuff('Faerie Fire', _target) or jungle.Debuff('Faerie Fire (Feral)', _target)

        if isPvPTarget then
            local hasBothDots = (not (not routineActions or routineActions["Moonfire"] ~= false) or hasMoonfire)
                and (not (not routineActions or routineActions["Insect Swarm"] ~= false) or hasInsectSwarm)

            dpsPvPCasterCache[1][3] = ((not routineActions or routineActions[dpsPvPCasterCache[1][2]] ~= false) and (isMoving and (hasEnemy and jungle.ReadyCastSpell('Moonfire', _target)) and (not hasMoonfire or (hasBothDots and hasFaerieFire))))
            dpsPvPCasterCache[2][3] = ((not routineActions or routineActions[dpsPvPCasterCache[2][2]] ~= false) and (isMoving and (hasEnemy and jungle.ReadyCastSpell('Insect Swarm', _target)) and not hasInsectSwarm))
            dpsPvPCasterCache[3][3] = ((not routineActions or routineActions[dpsPvPCasterCache[3][2]] ~= false) and (isMoving and hasBothDots and not hasFaerieFire and (hasEnemy and jungle.ReadyCastSpell('Faerie Fire', _target))))
            dpsPvPCasterCache[4][3] = ((not routineActions or routineActions[dpsPvPCasterCache[4][2]] ~= false) and (starfireReady and not wrathReady))
            dpsPvPCasterCache[5][3] = (not routineActions or routineActions[dpsPvPCasterCache[5][2]] ~= false) and (wrathReady)
            dpsPvPCasterCache[6][3] = (not routineActions or routineActions[dpsPvPCasterCache[6][2]] ~= false) and (shouldAttack)

            return dpsPvPCasterCache
        end

        -- PvE-only school-immunity state. An immune DoT is treated as already
        -- satisfied so the remaining usable DoT can complete the debuff cycle.
        local targetName = UnitName(_target)
        local natureDamageImmune = targetName
            and jungle.natureDamageImmuneTargetNames
            and jungle.natureDamageImmuneTargetNames[targetName] == true
            or false
        local arcaneDamageImmune = targetName
            and jungle.arcaneDamageImmuneTargetNames
            and jungle.arcaneDamageImmuneTargetNames[targetName] == true
            or false
        local hasRequiredPvEMoonfire = not (not routineActions or routineActions["Moonfire"] ~= false) or arcaneDamageImmune or hasMoonfire
        local hasRequiredPvEInsectSwarm = natureDamageImmune
            or hasInsectSwarm
            or not IsSpellLearned('Insect Swarm')
        local hasImprovedFaerieFire = druidCapabilities.hasImprovedFaerieFire
        local improvedFaerieFireRank = druidCapabilities.improvedFaerieFireRank
        local appliedImprovedFaerieFireRank = GetAppliedImprovedFaerieFireRank(_target)
        local hasSufficientImprovedFaerieFire = appliedImprovedFaerieFireRank >= improvedFaerieFireRank
        local hasAllPvEDebuffs = hasRequiredPvEMoonfire
            and hasRequiredPvEInsectSwarm
            and (not (not routineActions or routineActions["Faerie Fire"] ~= false) or not isMoonkin or not isSkullOrBoss or not hasImprovedFaerieFire or hasSufficientImprovedFaerieFire)
        local usePvEMoonfire = isMoving
            and (hasEnemy and jungle.ReadyCastSpell('Moonfire', _target))
            and (not hasMoonfire or hasAllPvEDebuffs)

        if isMoonkin then
            -- The engine waits for the current cast to finish. Only a confirmed
            -- hardcast on this enemy can queue stationary Moonfire maintenance.
            -- Keep the existing moving Moonfire condition independent of this.
            local maintainMoonfire = pendingMoonfireGUID ~= nil
                and pendingMoonfireGUID == guid
                and not isMoving
                and not jungle.Buff("Nature's Grace", "player")
                and jungle.DebuffRemainingTime('Moonfire', _target, '|PLAYER') < 1
                and jungle.ReadyCastSpell('Moonfire', _target)
            usePvEMoonfire = usePvEMoonfire or maintainMoonfire

            local inMoonweaverMelee = IsMoonweaverMeleeRange(_target)

            local weaveCastWindow = not inMoonweaverMelee or CanMoonweaveHardcast()
            local hasOnlyOneDamageSchool = natureDamageImmune ~= arcaneDamageImmune
            -- Prefer the shorter Wrath cast when any melee enemy is attacking
            -- the player, including an untargeted enemy found by nameplate scan.
            local preferWrath = HasMeleeEnemyTargetingPlayer(_target)
            local crossedHardcastFallback = (preferWrath and not wrathReady and starfireReady)
                or (not preferWrath and not starfireReady and wrathReady)
            if guid and crossedHardcastFallback then
                -- Once either hardcast has needed the other as a fallback on
                -- this enemy, settle on Starfire whenever it is usable. Wrath
                -- remains available whenever Starfire still cannot be cast.
                moonweaverStarfireFallbackTargets[guid] = true
            end
            local forceStarfireWhenReady = guid
                and moonweaverStarfireFallbackTargets[guid]
            local useMeleeWrathPreference = preferWrath and not forceStarfireWhenReady
            local wrathCastWindow = weaveCastWindow
                or HasMoonweaverWrathOpeningSwing(_target)
                or hasOnlyOneDamageSchool
            local starfireCastWindow = weaveCastWindow or hasOnlyOneDamageSchool
            local useWrath = wrathReady
                and wrathCastWindow
                and (useMeleeWrathPreference or not starfireReady)
            local useStarfire = starfireReady
                and starfireCastWindow
                and (not useMeleeWrathPreference or not wrathReady)

            dpsCasterCache[4][2] = "Moonfire"
            dpsCasterCache[5][2] = "Insect Swarm"
            dpsCasterCache[6][2] = "Starfire"
            dpsCasterCache[7][2] = "Wrath"

            dpsCasterCache[1][3] = false
            dpsCasterCache[2][3] = false
            dpsCasterCache[3][3] = ((not routineActions or routineActions[dpsCasterCache[3][2]] ~= false) and (hasImprovedFaerieFire and (hasEnemy and jungle.ReadyCastSpell('Faerie Fire', _target)) and isSkullOrBoss and not hasSufficientImprovedFaerieFire))
            dpsCasterCache[4][3] = (not routineActions or routineActions[dpsCasterCache[4][2]] ~= false) and (usePvEMoonfire)
            dpsCasterCache[5][3] = ((not routineActions or routineActions[dpsCasterCache[5][2]] ~= false) and (isMoving and (hasEnemy and jungle.ReadyCastSpell('Insect Swarm', _target)) and not hasInsectSwarm))
            dpsCasterCache[6][3] = (not routineActions or routineActions[dpsCasterCache[6][2]] ~= false) and (useStarfire)
            dpsCasterCache[7][3] = (not routineActions or routineActions[dpsCasterCache[7][2]] ~= false) and (useWrath)
        else
            dpsCasterCache[1][3] = false
            dpsCasterCache[2][3] = false
            dpsCasterCache[4][2] = "Moonfire"
            dpsCasterCache[5][2] = "Insect Swarm"
            dpsCasterCache[6][2] = "Starfire"
            dpsCasterCache[7][2] = "Wrath"
            dpsCasterCache[3][3] = false
            dpsCasterCache[4][3] = (not routineActions or routineActions[dpsCasterCache[4][2]] ~= false) and (usePvEMoonfire)
            dpsCasterCache[5][3] = ((not routineActions or routineActions[dpsCasterCache[5][2]] ~= false) and (isMoving and (hasEnemy and jungle.ReadyCastSpell('Insect Swarm', _target)) and not hasInsectSwarm))
            dpsCasterCache[6][3] = ((not routineActions or routineActions[dpsCasterCache[6][2]] ~= false) and (starfireReady and (not inCombat or not wrathReady)))
            dpsCasterCache[7][3] = ((not routineActions or routineActions[dpsCasterCache[7][2]] ~= false) and (wrathReady and (inCombat or not starfireReady)))
        end
        dpsCasterCache[8][3] = ((not routineActions or routineActions[dpsCasterCache[8][2]] ~= false) and (shouldAttack))

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
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
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

    buffCache[1][3] = ((not routineActions or routineActions[buffCache[1][2]] ~= false) and (isPlayer and jungle.ReadyCastSpell('Omen of Clarity', friend) and not jungle.unitCacheBuff(friend, "Omen of Clarity", nil, 300)))
    buffCache[2][3] = ((not routineActions or routineActions[buffCache[2][2]] ~= false) and (isPlayer and jungle.ReadyCastSpell('Mark of the Wild', friend) and not jungle.unitCacheBuff(friend, "Mark of the Wild", nil, 600) and not jungle.unitCacheBuff(friend, "Gift of the Wild")))
    buffCache[3][3] = ((not routineActions or routineActions[buffCache[3][2]] ~= false) and (not isPlayer and jungle.ReadyCastSpell('Mark of the Wild', friend) and not jungle.unitCacheBuff(friend, "Mark of the Wild", nil, 600) and not jungle.unitCacheBuff(friend, "Gift of the Wild")))
    buffCache[4][3] = ((not routineActions or routineActions[buffCache[4][2]] ~= false) and (shouldBuffThorns and jungle.ReadyCastSpell('Thorns', friend) and not jungle.unitCacheBuff(friend, "Thorns", nil, 300)))

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
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
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

    pveHealCache[1][3] = ((not routineActions or routineActions[pveHealCache[1][2]] ~= false) and (hp <= 0.3 and jungle.ReadyCastSpell('Healing Touch', friend) and jungle.IsSpellReadyIgnoreGCD("Nature's Swiftness") and not hasNS and data.isInCombat))
    pveHealCache[2][3] = ((not routineActions or routineActions[pveHealCache[2][2]] ~= false) and (jungle.ReadyCastSpell('Healing Touch', friend) and hasNS))
    pveHealCache[3][3] = ((not routineActions or routineActions[pveHealCache[3][2]] ~= false) and (jungle.IsSpellReadyIgnoreGCD("Swiftmend") and hp <= 0.60 and (hasRejuv or hasRegrowth) and data.isInCombat))
    pveHealCache[4][3] = ((not routineActions or routineActions[pveHealCache[4][2]] ~= false) and (not noManaLB and isTank and isTanking and lbExpiring))
    pveHealCache[5][3] = ((not routineActions or routineActions[pveHealCache[5][2]] ~= false) and (not noManaLB and isTanking and lbCount < 3))
    pveHealCache[6][3] = ((not routineActions or routineActions[pveHealCache[6][2]] ~= false) and (jungle.ReadyCastSpell('Regrowth', friend) and hp <= 0.80 and isTanking and not hasRegrowth and GetUnitSpeed('player') == 0))
    pveHealCache[7][3] = ((not routineActions or routineActions[pveHealCache[7][2]] ~= false) and (not noManaLB and hp < 0.70 and lbCount < 3))
    pveHealCache[8][3] = ((not routineActions or routineActions[pveHealCache[8][2]] ~= false) and (jungle.ReadyCastSpell('Regrowth', friend) and hp < 0.60 and not hasRegrowth and GetUnitSpeed('player') == 0))
    pveHealCache[9][3] = ((not routineActions or routineActions[pveHealCache[9][2]] ~= false) and (jungle.ReadyCastSpell('Rejuvenation', friend) and (hp < 0.85 or (isTank and hp <0.9)) and not hasRejuv))
    pveHealCache[10][3] = ((not routineActions or routineActions[pveHealCache[10][2]] ~= false) and (jungle.ReadyCastSpell('Lifebloom', friend) and hp < 0.70 and lbExpiring))
    pveHealCache[11][3] = ((not routineActions or routineActions[pveHealCache[11][2]] ~= false) and (jungle.ReadyCastSpell('Lifebloom', friend) and hp < 0.90 and not hasLifebloom))
    
    -- [UPDATE] Split OOC Lifebloom into strict priority to prevent OOC tanks from stealing GCD when a refresh is critically expiring
    pveHealCache[12][3] = ((not routineActions or routineActions[pveHealCache[12][2]] ~= false) and (jungle.ReadyCastSpell('Lifebloom', friend) and isTank and not data.isInCombat and hasLifebloom and lbExpiring))
    pveHealCache[13][3] = ((not routineActions or routineActions[pveHealCache[13][2]] ~= false) and (jungle.ReadyCastSpell('Lifebloom', friend) and isTank and not data.isInCombat and not hasLifebloom))

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
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    local data = jungle.unitCache[friend]
    if not data or data.currLife >= 0.99 or UnitIsDeadOrGhost(friend) then return emptyPvpCache end

    -- PvP Logic: Focus on whoever is being attacked NOW
    local attackers = jungle.targetedByCount(friend)
    local isFocused = (attackers >= 1)
    
    local hasLifebloom = jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER')
    local lbFull       = jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', 0, 3)

    pvpHealCache[1][3] = ((not routineActions or routineActions[pvpHealCache[1][2]] ~= false) and (data.currLife <= 0.40 and jungle.IsSpellReadyIgnoreGCD("Nature's Swiftness") and data.isInCombat))
    pvpHealCache[2][3] = ((not routineActions or routineActions[pvpHealCache[2][2]] ~= false) and (data.currLife <= 0.40 and jungle.unitCacheBuff("player", "Nature's Swiftness", "_PLAYER")))
    pvpHealCache[3][3] = ((not routineActions or routineActions[pvpHealCache[3][2]] ~= false) and (jungle.IsSpellReadyIgnoreGCD("Swiftmend") and data.currLife <= 0.60 and (jungle.unitCacheBuff(friend, "Rejuvenation") or jungle.unitCacheBuff(friend, "Regrowth"))))
    pvpHealCache[4][3] = ((not routineActions or routineActions[pvpHealCache[4][2]] ~= false) and (jungle.ReadyCastSpell('Lifebloom', friend) and isFocused and not lbFull))
    pvpHealCache[5][3] = ((not routineActions or routineActions[pvpHealCache[5][2]] ~= false) and (jungle.ReadyCastSpell('Lifebloom', friend) and hasLifebloom and not jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', 1.5)))
    pvpHealCache[6][3] = ((not routineActions or routineActions[pvpHealCache[6][2]] ~= false) and (jungle.ReadyCastSpell('Rejuvenation', friend) and not jungle.unitCacheBuff(friend, "Rejuvenation", "_PLAYER")))
    pvpHealCache[7][3] = ((not routineActions or routineActions[pvpHealCache[7][2]] ~= false) and (jungle.ReadyCastSpell('Lifebloom', friend) and not hasLifebloom and data.currLife < 0.95))

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
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
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
			((not routineActions or routineActions["Nature's Swiftness"] ~= false) and (hp <= 0.3 and jungle.ReadyCastSpell('Healing Touch', friend) and jungle.IsSpellReadyIgnoreGCD("Nature's Swiftness") and not hasNS and data.isInCombat)) },
		[2] = { "NS Cast", "Healing Touch",
			((not routineActions or routineActions["Healing Touch"] ~= false) and (jungle.ReadyCastSpell('Healing Touch', friend) and hasNS)) },

        -- [2] Swiftmend Save (Critical < 60% + Hot)
        [3] = { "Swiftmend Save", "Swiftmend",
            ((not routineActions or routineActions["Swiftmend"] ~= false) and (inCombat and hp <= 0.60 and jungle.IsSpellReadyIgnoreGCD("Swiftmend") 
            and (hasRegrowthAny or hasRejuvAny))) 
        },

        -- [3] Update Bloom Critical (< 45% + Expiring)
        [4] = { "LB Refresh Crit", "Lifebloom",
            ((not routineActions or routineActions["Lifebloom"] ~= false) and (inCombat and hp <= 0.45 and hasLifebloom and lbExpiring and jungle.ReadyCastSpell('Lifebloom', friend))) 
        },

        -- [4] Update Bloom Priority (Expiring)
        [5] = { "LB Refresh Prio", "Lifebloom",
            ((not routineActions or routineActions["Lifebloom"] ~= false) and (inCombat and isPriority and hasLifebloom and lbExpiring and jungle.ReadyCastSpell('Lifebloom', friend))) 
        },

        -- [5] Update Bloom Most Targeted (Aggro + Expiring)
        [6] = { "LB Refresh Aggro", "Lifebloom",
            ((not routineActions or routineActions["Lifebloom"] ~= false) and (inCombat and (targetedCount >= 1) and hasLifebloom and lbExpiring and jungle.ReadyCastSpell('Lifebloom', friend))) 
        },

        -- [6] Update Bloom General (< 90% + Expiring)
        [7] = { "LB Refresh Gen", "Lifebloom",
            ((not routineActions or routineActions["Lifebloom"] ~= false) and (hp < 0.90 and hasLifebloom and lbExpiring and jungle.ReadyCastSpell('Lifebloom', friend))) 
        },

        -- [7] Swiftmend Snipe (Non-Player Hots + < 85%)
        -- Logic: Cast if they have a hot, but NOT ours.
        [8] = { "Swiftmend Snipe", "Swiftmend",
            ((not routineActions or routineActions["Swiftmend"] ~= false) and (inCombat and jungle.IsSpellReadyIgnoreGCD("Swiftmend") and hp <= 0.85 
            and ((hasRegrowthAny and not hasRegrowth) or (hasRejuvAny and not hasRejuv)))) 
        },

        -- [8] Swiftmend Recycle (My Hot Expiring + < 85%)
        -- Logic: My hot exists, but is NOT safe for 5 seconds (expires < 5s)
        [9] = { "Swiftmend Recycle", "Swiftmend",
            ((not routineActions or routineActions["Swiftmend"] ~= false) and (inCombat and jungle.IsSpellReadyIgnoreGCD("Swiftmend") and hp <= 0.85
            and ( (hasRegrowth and not jungle.unitCacheBuff(friend, 'Regrowth', '_PLAYER', 5)) 
               or (hasRejuv and not jungle.unitCacheBuff(friend, 'Rejuvenation', '_PLAYER', 5)) ))) 
        },

        -- [9] Regrowth Standing Critical (< 45% + No Hots)
        [10] = { "Regrowth Crit", "Regrowth",
            ((not routineActions or routineActions["Regrowth"] ~= false) and (not isMoving and inCombat and hp <= 0.45 
            and not hasRejuv and not hasLifebloom and not hasRegrowth
            and jungle.ReadyCastSpell('Regrowth', friend))) 
        },

        -- [10] Regrowth Standing Priority (< 85% + No Hots)
        [11] = { "Regrowth Prio", "Regrowth",
            ((not routineActions or routineActions["Regrowth"] ~= false) and (not isMoving and inCombat and isPriority and hp <= 0.85
            and not hasRejuv and not hasLifebloom and not hasRegrowth
            and jungle.ReadyCastSpell('Regrowth', friend))) 
        },

        -- [11] Regrowth Standing Aggro (< 85% + No Hots)
        [12] = { "Regrowth Aggro", "Regrowth",
            ((not routineActions or routineActions["Regrowth"] ~= false) and (not isMoving and inCombat and hp <= 0.85 and (targetedCount >= 1)
            and not hasRejuv and not hasLifebloom and not hasRegrowth
            and jungle.ReadyCastSpell('Regrowth', friend))) 
        },

        -- [12] Stack 3 Critical (< 45% + Has 2 Stacks)
        [13] = { "LB Stack 3 Crit", "Lifebloom",
            ((not routineActions or routineActions["Lifebloom"] ~= false) and (inCombat and isPriority and hp <= 0.45 and lbCount == 2 and jungle.ReadyCastSpell('Lifebloom', friend))) 
        },

        -- [13] Stack 3 Priority (Has 2 Stacks)
        [14] = { "LB Stack 3 Prio", "Lifebloom",
            ((not routineActions or routineActions["Lifebloom"] ~= false) and (inCombat and isPriority and lbCount == 2 and jungle.ReadyCastSpell('Lifebloom', friend))) 
        },

        -- [14] Stack 3 Any (< 75% + Has 2 Stacks)
        [15] = { "LB Stack 3 Any", "Lifebloom",
            ((not routineActions or routineActions["Lifebloom"] ~= false) and (inCombat and isPriority and hp < 0.75 and lbCount == 2 and jungle.ReadyCastSpell('Lifebloom', friend))) 
        },

        -- [15] Stack 2 Critical (< 45% + Has 1 Stack)
        [16] = { "LB Stack 2 Crit", "Lifebloom",
            ((not routineActions or routineActions["Lifebloom"] ~= false) and (inCombat and isPriority and hp <= 0.45 and lbCount == 1 and jungle.ReadyCastSpell('Lifebloom', friend))) 
        },

        -- [16] Stack 2 Priority (Has 1 Stack)
        [17] = { "LB Stack 2 Prio", "Lifebloom",
            ((not routineActions or routineActions["Lifebloom"] ~= false) and (inCombat and isPriority and lbCount == 1 and jungle.ReadyCastSpell('Lifebloom', friend))) 
        },

        -- [17] Stack 2 Any (< 75% + Has 1 Stack)
        [18] = { "LB Stack 2 Any", "Lifebloom",
            ((not routineActions or routineActions["Lifebloom"] ~= false) and (inCombat and isPriority and hp < 0.75 and lbCount == 1 and jungle.ReadyCastSpell('Lifebloom', friend))) 
        },

        -- [18] Stack 1 Critical (< 45% + No Stacks)
        [19] = { "LB Stack 1 Crit", "Lifebloom",
            ((not routineActions or routineActions["Lifebloom"] ~= false) and (inCombat and isPriority and hp <= 0.45 and not hasLifebloom and jungle.ReadyCastSpell('Lifebloom', friend))) 
        },

        -- [19] Stack 1 Priority (No Hots)
        [20] = { "LB Stack 1 Prio", "Lifebloom",
            ((not routineActions or routineActions["Lifebloom"] ~= false) and (inCombat and isPriority and not hasRegrowth and not hasRejuv and not hasLifebloom 
            and jungle.ReadyCastSpell('Lifebloom', friend))) 
        },

        -- [20] Stack 1 Any (< 75% + No Stacks)
        [21] = { "LB Stack 1 Any", "Lifebloom",
            ((not routineActions or routineActions["Lifebloom"] ~= false) and (inCombat and isPriority and hp < 0.75 and not hasLifebloom and jungle.ReadyCastSpell('Lifebloom', friend))) 
        },

        -- [21] Regrowth Backup Critical (< 45% + Missing Regrowth)
        [22] = { "Regrowth Back Crit", "Regrowth",
            ((not routineActions or routineActions["Regrowth"] ~= false) and (not isMoving and inCombat and hp <= 0.45 and not hasRegrowth and jungle.ReadyCastSpell('Regrowth', friend))) 
        },

        -- [22] Regrowth Backup Priority (< 85% + Missing Regrowth)
        [23] = { "Regrowth Back Prio", "Regrowth",
            ((not routineActions or routineActions["Regrowth"] ~= false) and (not isMoving and inCombat and isPriority and hp <= 0.85 and not hasRegrowth and jungle.ReadyCastSpell('Regrowth', friend))) 
        },

        -- [23] Regrowth Backup Aggro (< 85% + Missing Regrowth)
        [24] = { "Regrowth Back Aggro", "Regrowth",
            ((not routineActions or routineActions["Regrowth"] ~= false) and (not isMoving and inCombat and hp <= 0.85 and (targetedCount >= 1) and not hasRegrowth 
            and jungle.ReadyCastSpell('Regrowth', friend))) 
        },

        -- [24] Rejuv Mobile (< 60% + Moving + No Hots)
        [25] = { "Rejuv Mobile", "Rejuvenation",
            ((not routineActions or routineActions["Rejuvenation"] ~= false) and (inCombat and isMoving and hp < 0.60 
            and not hasRejuv and not hasRegrowth and not hasLifebloom
            and jungle.ReadyCastSpell('Rejuvenation', friend))) 
        },

        -- [25] Rejuv Aggro (< 85% + High Aggro)
        [26] = { "Rejuv Aggro", "Rejuvenation",
            ((not routineActions or routineActions["Rejuvenation"] ~= false) and (inCombat and hp <= 0.85 and (targetedCount >= 2) and not hasRejuv
            and jungle.ReadyCastSpell('Rejuvenation', friend))) 
        },

        -- [26] LB OOC (Not Combat + < 90% + No Hots)
        [27] = { "LB OOC", "Lifebloom",
            ((not routineActions or routineActions["Lifebloom"] ~= false) and (not inCombat and hp <= 0.90 
            and not hasRejuv and not hasRegrowth and not hasLifebloom
            and jungle.ReadyCastSpell('Lifebloom', friend))) 
        },

        -- [27] Stack 3x Panic (< 75% + Not Full Stacks)
        [28] = { "LB Panic Stack", "Lifebloom",
            ((not routineActions or routineActions["Lifebloom"] ~= false) and (hp <= 0.75 and lbCount < 3 and jungle.ReadyCastSpell('Lifebloom', friend))) 
        },

        -- [28] LB Filler (< 90% + No Stacks)
        [29] = { "LB Filler", "Lifebloom",
            ((not routineActions or routineActions["Lifebloom"] ~= false) and (hp <= 0.90 and not hasLifebloom and jungle.ReadyCastSpell('Lifebloom', friend))) 
        },

        -- [29] Regrowth Panic (< 45% + Standing)
        [30] = { "Regrowth Panic", "Regrowth",
            ((not routineActions or routineActions["Regrowth"] ~= false) and (not isMoving and inCombat and hp <= 0.45 and jungle.ReadyCastSpell('Regrowth', friend))) 
        },

        -- [30] Stack 3x Aggro (Targeted + Not Full Stacks)
        [31] = { "LB Aggro Stack", "Lifebloom",
            ((not routineActions or routineActions["Lifebloom"] ~= false) and (inCombat and (targetedCount >= 2) and lbCount < 3 and jungle.ReadyCastSpell('Lifebloom', friend))) 
        },
    }
end

jungle.raidHealSet = raidHealSet


-- ----------------------------------------------------------------------------
-- TANK ROTATION: Ported Logic (Maintenance & Pre-Hotting)
-- ----------------------------------------------------------------------------
local function tankRollSet(friend)
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
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
			((not routineActions or routineActions["Nature's Swiftness"] ~= false) and (hp <= 0.3 and jungle.ReadyCastSpell('Healing Touch', friend) and jungle.IsSpellReadyIgnoreGCD("Nature's Swiftness") and not hasNS and data.isInCombat)) },
		[2] = { "NS Cast", "Healing Touch",
			((not routineActions or routineActions["Healing Touch"] ~= false) and (jungle.ReadyCastSpell('Healing Touch', friend) and hasNS)) },

        -- [2] Swiftmend Critical Tank (< 60% + HoT)
        [3] = { "Swiftmend Tank Crit", "Swiftmend",
            ((not routineActions or routineActions["Swiftmend"] ~= false) and (inCombat and hp <= 0.60 and jungle.IsSpellReadyIgnoreGCD("Swiftmend") 
            and (hasRegrowth or hasRejuv))) -- Prefer own HoTs for critical tank save
        },

        -- [3] Update Active Tank (Aggro + Expiring)
        [4] = { "LB Refresh Active", "Lifebloom",
            ((not routineActions or routineActions["Lifebloom"] ~= false) and (inCombat and isTanking and hasLifebloom and lbExpiring 
            and jungle.ReadyCastSpell('Lifebloom', friend))) 
        },

        -- [4] Update Critical Tank (< 45% + Expiring)
        [5] = { "LB Refresh Crit", "Lifebloom",
            ((not routineActions or routineActions["Lifebloom"] ~= false) and (inCombat and hp <= 0.45 and hasLifebloom and lbExpiring 
            and jungle.ReadyCastSpell('Lifebloom', friend))) 
        },

        -- [5] Update Any Tank (Expiring)
        [6] = { "LB Refresh Any", "Lifebloom",
            ((not routineActions or routineActions["Lifebloom"] ~= false) and (inCombat and hasLifebloom and lbExpiring 
            and jungle.ReadyCastSpell('Lifebloom', friend))) 
        },

        -- [6] Regrowth Tank Panic (Standing + < 45%)
        [7] = { "Regrowth Panic", "Regrowth",
            ((not routineActions or routineActions["Regrowth"] ~= false) and (not isMoving and inCombat and hp <= 0.45 
            and jungle.ReadyCastSpell('Regrowth', friend))) 
        },

        -- [7] Tank Regrowth Active (Standing + Aggro + Missing)
        [8] = { "Regrowth Active", "Regrowth",
            ((not routineActions or routineActions["Regrowth"] ~= false) and (not isMoving and inCombat and isTanking and not hasRegrowth 
            and jungle.ReadyCastSpell('Regrowth', friend))) 
        },

        -- [8] Tank Rejuv Critical (< 45% + Missing)
        [9] = { "Rejuv Crit", "Rejuvenation",
            ((not routineActions or routineActions["Rejuvenation"] ~= false) and (inCombat and hp <= 0.45 and not hasRejuv 
            and jungle.ReadyCastSpell('Rejuvenation', friend))) 
        },

        -- [9] Tank Roll 3 Critical (< 45% + Stacks < 3)
        [10] = { "LB Stack 3 Crit", "Lifebloom",
            ((not routineActions or routineActions["Lifebloom"] ~= false) and (inCombat and hp <= 0.45 and lbCount < 3 
            and jungle.ReadyCastSpell('Lifebloom', friend))) 
        },

        -- [10] Tank Roll 3 Active (Aggro + Stacks < 3)
        [11] = { "LB Stack 3 Active", "Lifebloom",
            ((not routineActions or routineActions["Lifebloom"] ~= false) and (inCombat and isTanking and lbCount < 3 
            and jungle.ReadyCastSpell('Lifebloom', friend))) 
        },

        -- [11] Tank Rejuv Active (Aggro + Missing)
        [12] = { "Rejuv Active", "Rejuvenation",
            ((not routineActions or routineActions["Rejuvenation"] ~= false) and (inCombat and isTanking and not hasRejuv 
            and jungle.ReadyCastSpell('Rejuvenation', friend))) 
        },

        -- [12] Swiftmend Tank Snipe (< 80% + Non-My HoT)
        [13] = { "Swiftmend Snipe", "Swiftmend",
            ((not routineActions or routineActions["Swiftmend"] ~= false) and (inCombat and jungle.IsSpellReadyIgnoreGCD("Swiftmend") and hp <= 0.80 
            and ((hasRegrowthAny and not hasRegrowth) or (hasRejuvAny and not hasRejuv)))) 
        },

        -- [13] Swiftmend Tank Recycle (< 80% + My Expiring HoT)
        -- Logic: My HoT exists but is NOT safe for 5s (expires < 5s)
        [14] = { "Swiftmend Recycle", "Swiftmend",
            ((not routineActions or routineActions["Swiftmend"] ~= false) and (inCombat and jungle.IsSpellReadyIgnoreGCD("Swiftmend") and hp <= 0.80 
            and ( (hasRegrowth and not jungle.unitCacheBuff(friend, 'Regrowth', '_PLAYER', 5)) 
               or (hasRejuv and not jungle.unitCacheBuff(friend, 'Rejuvenation', '_PLAYER', 5)) ))) 
        },

        -- [14] Tank Update Bloom (OOC + Expiring)
        [15] = { "LB Refresh OOC", "Lifebloom",
            ((not routineActions or routineActions["Lifebloom"] ~= false) and (not inCombat and hasLifebloom and lbExpiring 
            and jungle.ReadyCastSpell('Lifebloom', friend))) 
        },

        -- [15] Tank One Bloom (OOC + Missing)
        -- Note: Checks if we have NO stacks.
        [16] = { "LB Start OOC", "Lifebloom",
            ((not routineActions or routineActions["Lifebloom"] ~= false) and (not inCombat and not hasLifebloom 
            and jungle.ReadyCastSpell('Lifebloom', friend))) 
        },

        -- [16] Tank Roll 3 (OOC + Stacks < 3)
        -- Builds the stack up to 3 between pulls.
        [17] = { "LB Build OOC", "Lifebloom",
            ((not routineActions or routineActions["Lifebloom"] ~= false) and (not inCombat and lbCount < 3 
            and jungle.ReadyCastSpell('Lifebloom', friend))) 
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
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
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
    tankRollCache2[1][3] = ((not routineActions or routineActions[tankRollCache2[1][2]] ~= false) and (hp <= 0.3 and healingTouchReady and jungle.IsSpellReadyIgnoreGCD("Nature's Swiftness") and not hasNS and data.isInCombat))
    tankRollCache2[2][3] = ((not routineActions or routineActions[tankRollCache2[2][2]] ~= false) and (healingTouchReady and hasNS))
    tankRollCache2[3][3] = ((not routineActions or routineActions[tankRollCache2[3][2]] ~= false) and (inCombat and isTanking and hasLifebloom and lbExpiring and jungle.ReadyCastSpell('Lifebloom', friend)))
    local swiftmendReady = inCombat and isTanking and jungle.IsSpellReadyIgnoreGCD("Swiftmend")
    tankRollCache2[4][3] = ((not routineActions or routineActions[tankRollCache2[4][2]] ~= false) and (swiftmendReady and hp <= 0.95 and ((hasRegrowthAny and not hasRegrowth) or (hasRejuvAny and not hasRejuv))))
    tankRollCache2[5][3] = ((not routineActions or routineActions[tankRollCache2[5][2]] ~= false) and (swiftmendReady and hp <= 0.80 and (hasRegrowth or hasRejuv)))
    tankRollCache2[6][3] = ((not routineActions or routineActions[tankRollCache2[6][2]] ~= false) and (inCombat and isTanking and lbCount < 3 and jungle.ReadyCastSpell('Lifebloom', friend)))
    tankRollCache2[7][3] = ((not routineActions or routineActions[tankRollCache2[7][2]] ~= false) and (inCombat and not isTanking and hp < 1.0 and ( (hasLifebloom and lbExpiring) or not hasLifebloom ) and jungle.ReadyCastSpell('Lifebloom', friend)))
    local canHardcast = inCombat and isTanking and GetUnitSpeed('player') == 0
    tankRollCache2[8][3] = ((not routineActions or routineActions[tankRollCache2[8][2]] ~= false) and (canHardcast and not hasRegrowth and jungle.ReadyCastSpell('Regrowth', friend)))
    tankRollCache2[9][3] = ((not routineActions or routineActions[tankRollCache2[9][2]] ~= false) and (inCombat and isTanking and not hasRejuv and jungle.ReadyCastSpell('Rejuvenation', friend)))
    tankRollCache2[10][3] = ((not routineActions or routineActions[tankRollCache2[10][2]] ~= false) and (canHardcast and hp <= 0.75 and jungle.ReadyCastSpell('Regrowth', friend)))
    tankRollCache2[11][3] = ((not routineActions or routineActions[tankRollCache2[11][2]] ~= false) and (not inCombat and hasLifebloom and lbExpiring and jungle.ReadyCastSpell('Lifebloom', friend)))
    tankRollCache2[12][3] = ((not routineActions or routineActions[tankRollCache2[12][2]] ~= false) and (not inCombat and lbCount < 3 and jungle.ReadyCastSpell('Lifebloom', friend)))

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
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
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
    raidHealCache2[1][3] = ((not routineActions or routineActions[raidHealCache2[1][2]] ~= false) and (hp <= 0.3 and healingTouchReady and jungle.IsSpellReadyIgnoreGCD("Nature's Swiftness") and not hasNS and data.isInCombat))
    raidHealCache2[2][3] = ((not routineActions or routineActions[raidHealCache2[2][2]] ~= false) and (healingTouchReady and hasNS))
    raidHealCache2[3][3] = ((not routineActions or routineActions[raidHealCache2[3][2]] ~= false) and (inCombat and hasLifebloom and lbExpiring and (isPrio or hp <= 0.80) and jungle.ReadyCastSpell('Lifebloom', friend)))
    local swiftmendReady = inCombat and jungle.IsSpellReadyIgnoreGCD("Swiftmend")
    raidHealCache2[4][3] = ((not routineActions or routineActions[raidHealCache2[4][2]] ~= false) and (swiftmendReady and hp <= 0.90 and ((hasRegrowthAny and not hasRegrowth) or (hasRejuvAny and not hasRejuv) or (hasRegrowth and not jungle.unitCacheBuff(friend, 'Regrowth', '_PLAYER', 5)) or (hasRejuv and not jungle.unitCacheBuff(friend, 'Rejuvenation', '_PLAYER', 5)))))
    raidHealCache2[5][3] = ((not routineActions or routineActions[raidHealCache2[5][2]] ~= false) and (swiftmendReady and ( (hp <= 0.60 and hp > 0.40) or (hp <= 0.40 and not jungle.IsSpellReadyIgnoreGCD("Nature's Swiftness")) ) and (hasRegrowth or hasRejuv)))
    raidHealCache2[6][3] = ((not routineActions or routineActions[raidHealCache2[6][2]] ~= false) and (inCombat and (hp <= 0.80 or isPrio) and lbCount == 2 and jungle.ReadyCastSpell('Lifebloom', friend)))
    raidHealCache2[7][3] = ((not routineActions or routineActions[raidHealCache2[7][2]] ~= false) and (inCombat and (hp <= 0.80 or isPrio) and lbCount == 1 and jungle.ReadyCastSpell('Lifebloom', friend)))
    raidHealCache2[8][3] = ((not routineActions or routineActions[raidHealCache2[8][2]] ~= false) and (inCombat and (hp <= 0.80 or isPrio) and not hasLifebloom and jungle.ReadyCastSpell('Lifebloom', friend)))
    local canHardcast = inCombat and GetUnitSpeed('player') == 0
    raidHealCache2[9][3] = ((not routineActions or routineActions[raidHealCache2[9][2]] ~= false) and (canHardcast and ( (hp <= 0.40 and noHots) or (hp <= 0.60 and isPrio) ) and jungle.ReadyCastSpell('Regrowth', friend)))
    raidHealCache2[10][3] = ((not routineActions or routineActions[raidHealCache2[10][2]] ~= false) and (inCombat and ( (hp <= 0.40 and noHots) or (hp <= 0.60 and isPrio) ) and jungle.ReadyCastSpell('Rejuvenation', friend)))
    raidHealCache2[11][3] = ((not routineActions or routineActions[raidHealCache2[11][2]] ~= false) and (canHardcast and ( hp <= 0.40 or (hp <= 0.60 and isPrio) ) and jungle.ReadyCastSpell('Regrowth', friend)))
    raidHealCache2[12][3] = ((not routineActions or routineActions[raidHealCache2[12][2]] ~= false) and (inCombat and not hasRejuv and ( hp <= 0.40 or isPrio ) and jungle.ReadyCastSpell('Rejuvenation', friend)))
    raidHealCache2[13][3] = ((not routineActions or routineActions[raidHealCache2[13][2]] ~= false) and (not inCombat and hasLifebloom and lbExpiring and hp < 1.0 and jungle.ReadyCastSpell('Lifebloom', friend)))
    raidHealCache2[14][3] = ((not routineActions or routineActions[raidHealCache2[14][2]] ~= false) and (not inCombat and lbCount < 3 and hp < 1.0 and jungle.ReadyCastSpell('Lifebloom', friend)))

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
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
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
    univHealCacheV5[1][3] = ((not routineActions or routineActions[univHealCacheV5[1][2]] ~= false) and (inCombat and not hasNS and jungle.IsSpellReadyIgnoreGCD("NS") and ((isActiveTank and hp <= 0.40) or (hp <= 0.35)) and (not jungle.IsSpellReadyIgnoreGCD("Swiftmend") or not (hasRegrowthAny or hasRejuvAny))))
    univHealCacheV5[2][3] = ((not routineActions or routineActions[univHealCacheV5[2][2]] ~= false) and (inCombat and jungle.ReadyCastSpell('Healing Touch', friend) and hasNS and ((isActiveTank and hp <= 0.40) or (hp <= 0.35))))
    univHealCacheV5[3][3] = ((not routineActions or routineActions[univHealCacheV5[3][2]] ~= false) and (inCombat and jungle.IsSpellReadyIgnoreGCD("Swiftmend") and ((isActiveTank and hp <= 0.50) or (hp <= 0.40)) and (hasRegrowthAny or hasRejuvAny)))
    univHealCacheV5[4][3] = ((not routineActions or routineActions[univHealCacheV5[4][2]] ~= false) and (isActiveTank and hasLifebloom and lbExpiring and jungle.ReadyCastSpell('Lifebloom', friend)))
    univHealCacheV5[5][3] = ((not routineActions or routineActions[univHealCacheV5[5][2]] ~= false) and (inCombat and not isActiveTank and hp < 0.65 and not hasRejuv and jungle.ReadyCastSpell('Rejuvenation', friend)))
    univHealCacheV5[6][3] = ((not routineActions or routineActions[univHealCacheV5[6][2]] ~= false) and (inCombat and not isActiveTank and hp < 0.65 and lbCount == 0 and jungle.ReadyCastSpell('Lifebloom', friend)))
    univHealCacheV5[7][3] = ((not routineActions or routineActions[univHealCacheV5[7][2]] ~= false) and (isActiveTank and not hasLifebloom and jungle.ReadyCastSpell('Lifebloom', friend)))
    univHealCacheV5[8][3] = ((not routineActions or routineActions[univHealCacheV5[8][2]] ~= false) and (isActiveTank and not isMoving and jungle.bloomWindow("Regrowth") and ((not hasRegrowth and hp < 0.90) or hp < 0.60) and jungle.ReadyCastSpell('Regrowth', friend) and not jungle.isCasting('player', 0.5,'Regrowth')))
    univHealCacheV5[9][3] = ((not routineActions or routineActions[univHealCacheV5[9][2]] ~= false) and (isActiveTank and lbCount < 3 and jungle.ReadyCastSpell('Lifebloom', friend)))
    univHealCacheV5[10][3] = ((not routineActions or routineActions[univHealCacheV5[10][2]] ~= false) and (isActiveTank and not hasRejuv and hp < 0.90 and jungle.ReadyCastSpell('Rejuvenation', friend)))
    univHealCacheV5[11][3] = ((not routineActions or routineActions[univHealCacheV5[11][2]] ~= false) and (inCombat and jungle.IsSpellReadyIgnoreGCD("Swiftmend") and not isActiveTank and hp <= 0.80 and ((hasRegrowthAny and not hasRegrowth) or (hasRejuvAny and not hasRejuv))))
    univHealCacheV5[12][3] = ((not routineActions or routineActions[univHealCacheV5[12][2]] ~= false) and (inCombat and not isMoving and not hasRegrowth and not isActiveTank and hp <= 0.80 and jungle.bloomWindow("Regrowth") and jungle.ReadyCastSpell('Regrowth', friend) and not jungle.isCasting('player', 0.5,'Regrowth')))
    univHealCacheV5[13][3] = ((not routineActions or routineActions[univHealCacheV5[13][2]] ~= false) and (jungle.ReadyCastSpell('Lifebloom', friend) and lbCount == 2 and hp < 0.60))
    univHealCacheV5[14][3] = ((not routineActions or routineActions[univHealCacheV5[14][2]] ~= false) and (inCombat and not hasRejuv and not isActiveTank and hp <= 0.80 and jungle.ReadyCastSpell('Rejuvenation', friend)))
    univHealCacheV5[15][3] = ((not routineActions or routineActions[univHealCacheV5[15][2]] ~= false) and (jungle.ReadyCastSpell('Lifebloom', friend) and lbCount == 1 and hp <= 0.80))
    univHealCacheV5[16][3] = ((not routineActions or routineActions[univHealCacheV5[16][2]] ~= false) and (jungle.ReadyCastSpell('Lifebloom', friend) and lbExpiring and hp < 0.80))
    univHealCacheV5[17][3] = ((not routineActions or routineActions[univHealCacheV5[17][2]] ~= false) and (jungle.ReadyCastSpell('Lifebloom', friend) and lbCount == 0 and hp < 0.90))
    univHealCacheV5[18][3] = ((not routineActions or routineActions[univHealCacheV5[18][2]] ~= false) and (not inCombat and isTank and (not hasLifebloom or lbExpiring) and jungle.ReadyCastSpell('Lifebloom', friend)))
    univHealCacheV5[19][3] = ((not routineActions or routineActions[univHealCacheV5[19][2]] ~= false) and (not inCombat and not isTank and hp < 0.90 and not hasLifebloom and jungle.ReadyCastSpell('Lifebloom', friend)))

    return univHealCacheV5
end
jungle.universalHealSetV5 = universalHealSetV5

local emptyUnivV6Cache = {}

local V6_LIFEBLOOM_EXPIRE_LIMIT = 1.3
local v6BloomSchedule = { tick = nil }
local v6TankRejuvAfterRegrowth = {}

local v6FrameContext = { ready = {}, lockouts = {} }

-- Explicitly scoped to thread 2. No cross-frame readiness reuse; other V6
-- callers (including thread 7) continue through their existing uncached paths.
local function GetV6FrameContext()
    local tick = jungle.currentTick
    if not jungle.Engine or jungle.GetRoutineThread() ~= 2 or not tick or tick <= 0 then return nil end
    if v6FrameContext.tick ~= tick or v6FrameContext.configEntry ~= jungle.RoutineContext then
        v6FrameContext.tick = tick
        v6FrameContext.configEntry = jungle.RoutineContext
        v6FrameContext.gcdRead = false
        for spell in pairs(v6FrameContext.ready) do v6FrameContext.ready[spell] = nil end
        for spell in pairs(v6FrameContext.lockouts) do v6FrameContext.lockouts[spell] = nil end
        v6FrameContext.playerInCombat = UnitAffectingCombat('player')
        v6FrameContext.speed = GetUnitSpeed('player')
        v6FrameContext.haste = (UnitSpellHaste and UnitSpellHaste('player')) or 0
        v6FrameContext.hasNS = jungle.unitCacheBuff('player', "Nature's Swiftness", '_PLAYER')
        v6FrameContext.knowsLifebloom = IsSpellLearned('Lifebloom')
        if jungle.RaidTrace.sample then jungle.RaidTrace:Count("healingSnapshotBuilds") end
    end
    return v6FrameContext
end


local function IsV6UnitTanking(unit, data)
    if not data or not data.isInCombat then return false end

    local hasTankThreat = (data.threatStatus == 3 or data.threatStatus == 2)
    return hasTankThreat or UnitIsUnit(unit .. "targettarget", unit)
end

local function IsV6ActiveTank(unit, data)
    return data and data.isTank and IsV6UnitTanking(unit, data)
end

local function IsV6MaintainedTank(unit, data, context)
    if not data then return false end
    if IsV6UnitTanking(unit, data) then return true end
    if context then return data.isTank and not context.playerInCombat end
    return data.isTank and not UnitAffectingCombat('player')
end

local function IsV6BloomServiceable(unit)
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    if not (not routineActions or routineActions["Lifebloom"] ~= false) then return false end
    if not UnitExists(unit)
        or UnitIsDeadOrGhost(unit)
        or not UnitIsFriend('player', unit)
        or not jungle.isUnitAvailable(unit) then
        return false
    end

    return unit == 'player' or IsSpellInRange('Lifebloom', unit) == 1
end

local function IsV6ActiveTankGUID(guid)
    if not guid then return false end

    for unit, data in pairs(jungle.unitCache) do
        if data
            and (data.guid == guid or UnitGUID(unit) == guid)
            and IsV6ActiveTank(unit, data) then
            return true
        end
    end

    return false
end

local function V6UnitKey(unit, data)
    return (data and data.guid) or UnitGUID(unit) or unit
end

local function BuildV6BloomSchedule(context)
    local traceStart = jungle.RaidTrace.sample and debugprofilestop()
    local now = GetTime()
    local tick = jungle.currentTick
    local entries = {}
    local seen = {}

    for unit, data in pairs(jungle.unitCache) do
        if IsV6MaintainedTank(unit, data, context) and IsV6BloomServiceable(unit) then
            local key = V6UnitKey(unit, data)
            if not seen[key] then
                seen[key] = true
                local buffs = data.auras and data.auras.buffs
                local bloom = buffs and buffs.player and buffs.player['Lifebloom']
                if bloom and bloom.isActive and bloom.expirationTime and bloom.expirationTime > now then
                    entries[#entries + 1] = {
                        key = key,
                        expirationTime = bloom.expirationTime,
                        refreshAt = bloom.expirationTime - V6_LIFEBLOOM_EXPIRE_LIMIT,
                        deadline = bloom.expirationTime,
                    }
                end
            end
        end
    end

    table.sort(entries, function(a, b)
        return a.expirationTime < b.expirationTime
    end)

    local gcdStart, gcdDuration = jungle.GetGCDValues(context)
    local spellHaste = context and context.haste or ((UnitSpellHaste and UnitSpellHaste('player')) or 0)
    local expectedGCD = (gcdDuration and gcdDuration > 0)
        and gcdDuration
        or math.max(1.0, 1.5 / (1 + spellHaste / 100))
    local gcdRemaining = 0
    if gcdStart and gcdStart > 0 and gcdDuration and gcdDuration > 0 then
        gcdRemaining = math.max(0, (gcdStart + gcdDuration) - now)
    end

    local _, _, homeLatencyMs, worldLatencyMs = GetNetStats()
    local latency = math.max(homeLatencyMs or 0, worldLatencyMs or 0) / 1000

    v6BloomSchedule = {
        tick = tick,
        configEntry = jungle.RoutineContext,
        now = now,
        entries = entries,
        sharedWindows = context and {} or nil,
        expectedGCD = expectedGCD,
        gcdRemaining = gcdRemaining,
        latency = latency,
    }
    if traceStart then
        jungle.RaidTrace:Detail("druidBloomSchedule", debugprofilestop() - traceStart)
        jungle.RaidTrace:Count("bloomScheduleEntries", #entries)
    end
    return v6BloomSchedule
end

local function GetV6BloomSchedule(context)
    local tick = jungle.currentTick
    if tick and v6BloomSchedule.tick == tick and v6BloomSchedule.configEntry == jungle.RoutineContext then
        return v6BloomSchedule
    end
    return BuildV6BloomSchedule(context)
end

local function IsV6EarliestDueBloom(schedule, unit, data)
    local first = schedule.entries[1]
    return first
        and first.refreshAt <= schedule.now
        and first.key == V6UnitKey(unit, data)
end

-- Earliest-deadline-first admission control. The 1.3-second window determines
-- refresh priority; optional actions use actual expiration as the hard deadline.
-- Latency is included exactly once as the predicted delivery time of each
-- future instant Lifebloom, with no additional fixed safety buffer.
local function CanUseV6BloomWindow(schedule, actionLockout, excludedKey, context)
    local shared = context and not excludedKey and schedule.sharedWindows
    if shared and shared[actionLockout] ~= nil then return shared[actionLockout] end
    if jungle.RaidTrace.sample then jungle.RaidTrace:Count("bloomWindowChecks") end
    local refreshesBefore = 0
    local initialLockout = schedule.gcdRemaining + actionLockout

    for _, entry in ipairs(schedule.entries) do
        if entry.key ~= excludedKey then
            local required = initialLockout
                + refreshesBefore * schedule.expectedGCD
                + schedule.latency
            if required >= (entry.deadline - schedule.now) then
                if shared then shared[actionLockout] = false end
                return false
            end
            refreshesBefore = refreshesBefore + 1
        end
    end
    if shared then shared[actionLockout] = true end
    return true
end

local function CanApplyV6BloomBeforeExpiry(schedule, key)
    for _, entry in ipairs(schedule.entries) do
        if entry.key == key then
            local applicationDelay = schedule.gcdRemaining + schedule.latency
            return applicationDelay < (entry.expirationTime - schedule.now)
        end
    end

    -- A missing Lifebloom has no existing expiration to beat.
    return true
end

local function GetV6SpellLockout(spellName, expectedGCD, context)
    if context and context.lockouts[spellName] ~= nil then return context.lockouts[spellName] end
    if jungle.RaidTrace.sample then jungle.RaidTrace:Count("bloomSpellLockoutChecks") end
    local _, _, _, castTimeMs = GetSpellInfo(spellName)
    local baseCastTime = (castTimeMs and castTimeMs > 0) and (castTimeMs / 1000) or 0
    local spellHaste = context and context.haste or ((UnitSpellHaste and UnitSpellHaste('player')) or 0)
    local reactiveCastTime = baseCastTime / (1 + spellHaste / 100)
    local lockout = math.max(expectedGCD, reactiveCastTime)
    if context then context.lockouts[spellName] = lockout end
    return lockout
end

local function stopIfFull(t)
    return jungle.LifePercent(t) >= 0.95
end

local univHealCacheV6 = {
    [1] = { "NS Emergency", "Nature's Swiftness", false },
    [2] = { "NS Cast", "Healing Touch", false },
    [3] = { "LB Tank Safety", "Lifebloom", false, "PROTECT_BLOOM" },
    [4] = { "Swiftmend Panic", "Swiftmend", false },

    [5] = { "LB Boss Tank Start", "Lifebloom", false, "PROTECT_BLOOM" },
    [6] = { "LB Trash Tank Start", "Lifebloom", false, "PROTECT_BLOOM" },

    [7] = { "Urgent Rejuv", "Rejuvenation", false },
    [8] = { "Urgent LB Start", "Lifebloom", false },
    [9] = { "Swiftmend Snipe", "Swiftmend", false },
    [10] = { "Regrowth Tank Backup", "Regrowth", false, nil },
    [11] = { "Regrowth Raid", "Regrowth", false, stopIfFull },
    [12] = { "Rejuv Raid", "Rejuvenation", false },

    [13] = { "Regrowth Boss Tank", "Regrowth", false, nil },
    [14] = { "LB Boss Tank Stack", "Lifebloom", false, "PROTECT_BLOOM" },
    [15] = { "Rejuv Boss Tank", "Rejuvenation", false },

    [16] = { "Regrowth Trash Tank", "Regrowth", false, nil },
    [17] = { "LB Trash Tank Stack", "Lifebloom", false, "PROTECT_BLOOM" },
    [18] = { "Rejuv Trash Tank", "Rejuvenation", false },

    [19] = { "LB Stack 3", "Lifebloom", false },
    [20] = { "LB Stack 2", "Lifebloom", false },
    [21] = { "LB Refresh 3", "Lifebloom", false },
    [22] = { "LB Start Filler", "Lifebloom", false },

    [23] = { "LB OOC Tank (Refresh)", "Lifebloom", false, "PROTECT_BLOOM" },
    [24] = { "LB OOC Tank (Stack 3)", "Lifebloom", false, "PROTECT_BLOOM" },
    [25] = { "LB OOC Tank (Stack 2)", "Lifebloom", false, "PROTECT_BLOOM" },
    [26] = { "LB OOC Tank (Stack 1)", "Lifebloom", false, "PROTECT_BLOOM" },
    [27] = { "LB OOC Raid", "Lifebloom", false },
}

local function universalHealSetV6(friend, context)
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    local data = jungle.unitCache[friend]
    if not data or UnitIsDeadOrGhost(friend) then return emptyUnivV6Cache end

    -- 1. CONTEXT ANALYSIS
    local hp = data.currLife
    local inCombat = data.isInCombat
    local playerInCombat
    if context then playerInCombat = context.playerInCombat else playerInCombat = UnitAffectingCombat('player') end
    local isTank = data.isTank
    local isMoving = ((context and context.speed or GetUnitSpeed('player')) > 0)
    
    local isUnitTanking = IsV6UnitTanking(friend, data)
    local isActiveTank = IsV6ActiveTank(friend, data)
    local isMaintainedTank = IsV6MaintainedTank(friend, data, context)

    local isBoss = false
    if isUnitTanking then
        local tLevel = UnitLevel(friend .. "target") or 1
        local tClass = UnitClassification(friend .. "target") or "normal"
        isBoss = (tLevel == -1 or tClass == "worldboss" or tClass == "boss")
    end
    
    local isTankingBoss  = isActiveTank and isBoss
    local isTankingTrash = isActiveTank and not isBoss
    local isBloomTankingBoss  = isUnitTanking and isBoss
    local isBloomTankingTrash = isUnitTanking and not isBoss
    
    -- 2. AURA SCANNING
    local hasRejuv      = jungle.unitCacheBuff(friend, 'Rejuvenation', '_PLAYER')
    local hasRegrowth   = jungle.unitCacheBuff(friend, 'Regrowth', '_PLAYER')
    local hasLifebloom  = jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER')
    local hasNS, knowsLifebloom
    if context then
        hasNS, knowsLifebloom = context.hasNS, context.knowsLifebloom
    else
        hasNS = jungle.unitCacheBuff("player", "Nature's Swiftness", '_PLAYER')
        knowsLifebloom = IsSpellLearned('Lifebloom')
    end

    local safetyRow = univHealCacheV6[3]
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
    local lbCount = 0
    local lbExpiring = false
    
    if hasLifebloom then
        if jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', nil, 3) then lbCount = 3
        elseif jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', nil, 2) then lbCount = 2
        elseif jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', nil, 1) then lbCount = 1
        else lbCount = 3 end
        lbExpiring = not jungle.unitCacheBuff(friend, 'Lifebloom', '_PLAYER', V6_LIFEBLOOM_EXPIRE_LIMIT)
    end

    -- [LIFEBLOOM DEADLINE SCHEDULER]
    local bloomSchedule = GetV6BloomSchedule(context)
    local unitKey = V6UnitKey(friend, data)
    local isEarliestDueBloom = IsV6EarliestDueBloom(bloomSchedule, friend, data)
    local instantLockout = bloomSchedule.expectedGCD
    local regrowthLockout = GetV6SpellLockout('Regrowth', bloomSchedule.expectedGCD, context)
    local canUseInstant = CanUseV6BloomWindow(bloomSchedule, instantLockout, nil, context)
    local canUseRegrowth = CanUseV6BloomWindow(bloomSchedule, regrowthLockout, nil, context)
    local canUseTankBloom = CanApplyV6BloomBeforeExpiry(bloomSchedule, unitKey)
        and CanUseV6BloomWindow(bloomSchedule, instantLockout, unitKey, context)

    -- [REGROWTH TANK LOGIC]
    local wantRegTank = false
    if isActiveTank and canUseRegrowth and not isMoving and not jungle.isCasting('player', 0.5, 'Regrowth') and jungle.ReadyCastSpell('Regrowth', friend, context) then
        if not hasRegrowth and hp >= 0.90 then
            wantRegTank = true 
        elseif not hasRegrowth and hp < 0.90 then
            wantRegTank = true 
        elseif hp < 0.80 then
            wantRegTank = true 
        end
    end

    -- 5. PURE HEALING LOGIC
    -- Before Lifebloom is learned, Regrowth supplies the missing direct healing.
    -- Recast it through the existing HoT when health pressure is high enough.
    local useRegrowthWithoutLifebloom = not knowsLifebloom
        and not isMoving
        and not jungle.isCasting('player', 0.5, 'Regrowth')
        and jungle.ReadyCastSpell('Regrowth', friend, context)
        and (
            (inCombat and ((isTank and hp <= 0.85) or (not isTank and hp <= 0.65)))
            or (not inCombat and hp <= 0.80)
        )

    -- These readiness results cannot change during one synchronous evaluation
    -- for this friend. Reuse them across rows instead of repeating C API chains.
    local lifebloomReady = jungle.ReadyCastSpell('Lifebloom', friend, context)
    local swiftmendReady = inCombat and jungle.IsSpellReadyIgnoreGCD("Swiftmend", context)
    local insertRejuvBeforeRepeatRegrowth = jungle.Engine
        and jungle.GetRoutineThread() == 2
        and knowsLifebloom
        and wantRegTank
        and hasRegrowth
        and hp < 0.80
        and v6TankRejuvAfterRegrowth[unitKey]
        and not hasRejuv
        and canUseInstant
        and jungle.ReadyCastSpell('Rejuvenation', friend, context)

    -- Keep the existing tank-Regrowth priority. Only replace a repeated
    -- Regrowth with Rejuvenation when the preceding successful Regrowth armed it.
    univHealCacheV6[13][1] = insertRejuvBeforeRepeatRegrowth and "Rejuv Before Regrowth Boss" or "Regrowth Boss Tank"
    univHealCacheV6[13][2] = insertRejuvBeforeRepeatRegrowth and "Rejuvenation" or "Regrowth"
    univHealCacheV6[16][1] = insertRejuvBeforeRepeatRegrowth and "Rejuv Before Regrowth Trash" or "Regrowth Trash Tank"
    univHealCacheV6[16][2] = insertRejuvBeforeRepeatRegrowth and "Rejuvenation" or "Regrowth"

    univHealCacheV6[1][3] = ((not routineActions or routineActions[univHealCacheV6[1][2]] ~= false) and (inCombat and not hasNS and jungle.IsSpellReadyIgnoreGCD("Nature's Swiftness", context) and ((isActiveTank and hp <= 0.40) or (hp <= 0.35)) and (not swiftmendReady or not (hasRegAny or hasRejAny))))
    univHealCacheV6[2][3] = ((not routineActions or routineActions[univHealCacheV6[2][2]] ~= false) and (inCombat and jungle.ReadyCastSpell('Healing Touch', friend, context) and hasNS and ((isActiveTank and hp <= 0.40) or (hp <= 0.35))))
    univHealCacheV6[3][3] = (not routineActions or routineActions[univHealCacheV6[3][2]] ~= false) and (knowsLifebloom
        and (isMaintainedTank and hasLifebloom and lbExpiring and isEarliestDueBloom and lifebloomReady)
        or useRegrowthWithoutLifebloom)
    univHealCacheV6[4][3] = ((not routineActions or routineActions[univHealCacheV6[4][2]] ~= false) and (canUseInstant and inCombat and swiftmendReady and ((isActiveTank and hp <= 0.50) or (hp <= 0.40)) and (hasRegAny or hasRejAny)))
    univHealCacheV6[5][3] = ((not routineActions or routineActions[univHealCacheV6[5][2]] ~= false) and (isBloomTankingBoss and not hasLifebloom and canUseTankBloom and lifebloomReady))
    univHealCacheV6[6][3] = ((not routineActions or routineActions[univHealCacheV6[6][2]] ~= false) and (isBloomTankingTrash and not hasLifebloom and canUseTankBloom and lifebloomReady))
    univHealCacheV6[7][3] = ((not routineActions or routineActions[univHealCacheV6[7][2]] ~= false) and (canUseInstant and inCombat and not isUnitTanking and hp < 0.65 and not hasRejuv and jungle.ReadyCastSpell('Rejuvenation', friend, context)))
    univHealCacheV6[8][3] = ((not routineActions or routineActions[univHealCacheV6[8][2]] ~= false) and (canUseInstant and inCombat and not isUnitTanking and hp < 0.65 and lbCount == 0 and lifebloomReady))
    univHealCacheV6[9][3] = ((not routineActions or routineActions[univHealCacheV6[9][2]] ~= false) and (canUseInstant and inCombat and swiftmendReady and not isActiveTank and hp <= 0.80 and ((hasRegAny and not hasRegrowth) or (hasRejAny and not hasRejuv))))
    univHealCacheV6[10][3] = ((not routineActions or routineActions[univHealCacheV6[10][2]] ~= false) and (canUseRegrowth and inCombat and not isMoving and not hasRegrowth and isTank and hp <= 0.80 and jungle.ReadyCastSpell('Regrowth', friend, context) and not jungle.isCasting('player', 0.5,'Regrowth')))
    univHealCacheV6[11][3] = ((not routineActions or routineActions[univHealCacheV6[11][2]] ~= false) and (canUseRegrowth and inCombat and not isMoving and not hasRegrowth and not isTank and hp <= 0.80 and jungle.ReadyCastSpell('Regrowth', friend, context) and not jungle.isCasting('player', 0.5,'Regrowth')))
    univHealCacheV6[12][3] = ((not routineActions or routineActions[univHealCacheV6[12][2]] ~= false) and (canUseInstant and inCombat and not hasRejuv and not isActiveTank and hp <= 0.80 and jungle.ReadyCastSpell('Rejuvenation', friend, context)))
    univHealCacheV6[13][3] = ((not routineActions or routineActions[univHealCacheV6[13][2]] ~= false) and (isTankingBoss and wantRegTank))
    univHealCacheV6[14][3] = ((not routineActions or routineActions[univHealCacheV6[14][2]] ~= false) and (isBloomTankingBoss and lbCount < 3 and canUseTankBloom and lifebloomReady))
    univHealCacheV6[15][3] = ((not routineActions or routineActions[univHealCacheV6[15][2]] ~= false) and (canUseInstant and isTankingBoss and not hasRejuv and hp < 0.90 and jungle.ReadyCastSpell('Rejuvenation', friend, context)))
    univHealCacheV6[16][3] = ((not routineActions or routineActions[univHealCacheV6[16][2]] ~= false) and (isTankingTrash and wantRegTank))
    univHealCacheV6[17][3] = ((not routineActions or routineActions[univHealCacheV6[17][2]] ~= false) and (isBloomTankingTrash and lbCount < 3 and canUseTankBloom and lifebloomReady))
    univHealCacheV6[18][3] = ((not routineActions or routineActions[univHealCacheV6[18][2]] ~= false) and (canUseInstant and isTankingTrash and not hasRejuv and hp < 0.90 and jungle.ReadyCastSpell('Rejuvenation', friend, context)))
    univHealCacheV6[19][3] = ((not routineActions or routineActions[univHealCacheV6[19][2]] ~= false) and (canUseInstant and lifebloomReady and lbCount == 2 and hp < 0.60 and not isActiveTank))
    univHealCacheV6[20][3] = ((not routineActions or routineActions[univHealCacheV6[20][2]] ~= false) and (canUseInstant and lifebloomReady and lbCount == 1 and hp <= 0.80 and not isActiveTank))
    univHealCacheV6[21][3] = ((not routineActions or routineActions[univHealCacheV6[21][2]] ~= false) and (canUseInstant and lifebloomReady and lbExpiring and hp < 0.80 and not isActiveTank))
    univHealCacheV6[22][3] = ((not routineActions or routineActions[univHealCacheV6[22][2]] ~= false) and (canUseInstant and lifebloomReady and lbCount == 0 and hp < 0.90 and not isActiveTank))
    univHealCacheV6[23][3] = ((not routineActions or routineActions[univHealCacheV6[23][2]] ~= false) and (not playerInCombat and isTank and lbCount == 3 and lbExpiring and isEarliestDueBloom and lifebloomReady))
    univHealCacheV6[24][3] = ((not routineActions or routineActions[univHealCacheV6[24][2]] ~= false) and (not playerInCombat and isTank and lbCount == 2 and canUseTankBloom and lifebloomReady))
    univHealCacheV6[25][3] = ((not routineActions or routineActions[univHealCacheV6[25][2]] ~= false) and (not playerInCombat and isTank and lbCount == 1 and canUseTankBloom and lifebloomReady))
    univHealCacheV6[26][3] = ((not routineActions or routineActions[univHealCacheV6[26][2]] ~= false) and (not playerInCombat and isTank and lbCount == 0 and canUseTankBloom and lifebloomReady))
    univHealCacheV6[27][3] = ((not routineActions or routineActions[univHealCacheV6[27][2]] ~= false) and (canUseInstant and not playerInCombat and not isTank and hp < 0.90 and not hasLifebloom and lifebloomReady))

    return univHealCacheV6
end

-- Thread 2 keeps the V6 emergency/scheduler rules, but compares additional
-- healing by virtual health instead of comparing tank and raid spell indexes.
local v6MaintenanceRows = { 5, 6, 10, 13, 14, 15, 16, 17, 18 }
local v6AdditionalRows = { 7, 8, 9, 11, 12, 13, 16, 19, 20, 21 }
local v6FillerRows = { 22, 27 }
local v6DirectRow = { "Regrowth Additional", "Regrowth", true, stopIfFull }
local v6UrgentDirectRow = { "Regrowth Urgent", "Regrowth", true, stopIfFull }
local v6SelectedRows = { { "", "", true } }
local v6SelectionTick, v6SelectedUnit, v6SelectionEntry

local function V6FirstReadyRow(rows, order, friend, maintenance)
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    for _, index in ipairs(order) do
        local row = rows[index]
        if row[3] and (not routineActions or routineActions[row[2]] ~= false) and IsSpellLearned(row[2]) then
            -- The same original row supplies either a missing tank HoT or a
            -- repeat direct heal. Only the former owns maintenance priority.
            local isMaintenance = true
            if index == 13 or index == 16 then
                isMaintenance = row[2] == 'Rejuvenation'
                    or not jungle.unitCacheBuff(friend, 'Regrowth', '_PLAYER')
            end
            if maintenance == nil or isMaintenance == maintenance then
                return row, index
            end
        end
    end
end

local function V6Thread2Candidate(friend, data, context)
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    local rows = universalHealSetV6(friend, context)
    for index = 1, 4 do
        local row = rows[index]
        if row and row[3] and (not routineActions or routineActions[row[2]] ~= false) and IsSpellLearned(row[2]) then return row, 1, index end
    end
    if #rows == 0 then return end
    -- Use actual HP for urgent healing; HoT padding must not hide danger.
    -- Direct healing precedes establishing HoTs on otherwise healthy tanks, but
    -- must still fit the bloom schedule and yield to emergency rows 1-4.
    local urgentHP = data.isInCombat and jungle.LifePercent(friend)
    if urgentHP and urgentHP <= 0.35 then
        if (context and context.speed or GetUnitSpeed('player')) == 0
            and not jungle.isCasting('player', 0.5, 'Regrowth')
            and jungle.ReadyCastSpell('Regrowth', friend, context) then
            local schedule = GetV6BloomSchedule(context)
            if CanUseV6BloomWindow(schedule, GetV6SpellLockout('Regrowth', schedule.expectedGCD, context), nil, context) then
                v6UrgentDirectRow[4] = nil
                if not IsV6ActiveTank(friend, data) then v6UrgentDirectRow[4] = stopIfFull end
                return v6UrgentDirectRow, 1, 5 + urgentHP
            end
        end
        -- If direct healing is unavailable, use an eligible existing action
        -- on the endangered friend before unrelated tank maintenance.
        local urgent, index = V6FirstReadyRow(rows, v6AdditionalRows, friend)
        if urgent then return urgent, 1, 5 + urgentHP end
    end
    -- Establish our Regrowth before starting/building tank Lifebloom. The
    -- original row still enforces movement, readiness and the bloom window;
    -- emergency actions and due bloom refreshes above retain their priority.
    if IsV6ActiveTank(friend, data)
        and not jungle.unitCacheBuff(friend, 'Regrowth', '_PLAYER') then
        local regrowthIndex = rows[13][3] and 13 or 16
        local regrowth = rows[regrowthIndex]
        if regrowth[3] and regrowth[2] == 'Regrowth' then
            return regrowth, 2, 0
        end
    end
    local row, index = V6FirstReadyRow(rows, v6MaintenanceRows, friend, true)
    if row then return row, 2, index end

    -- Non-tank rows are ordinary healing; tank rows 13/16 must be direct heals.
    for _, additionalIndex in ipairs(v6AdditionalRows) do
        local candidate = rows[additionalIndex]
        if candidate[3] and (not routineActions or routineActions[candidate[2]] ~= false) and IsSpellLearned(candidate[2]) then
            if additionalIndex ~= 13 and additionalIndex ~= 16
                or (candidate[2] == 'Regrowth' and jungle.unitCacheBuff(friend, 'Regrowth', '_PLAYER')) then
                return candidate, 3, additionalIndex
            end
        end
    end
    -- A friend with existing HoTs still needs a direct-heal option. Use the
    -- existing tank repeat-Regrowth threshold and the same bloom admission gate.
    if data.isInCombat and data.currLife < 0.80
        and (context and context.speed or GetUnitSpeed('player')) == 0
        and not jungle.isCasting('player', 0.5, 'Regrowth')
        and jungle.ReadyCastSpell('Regrowth', friend, context) then
        local schedule = GetV6BloomSchedule(context)
        if CanUseV6BloomWindow(schedule, GetV6SpellLockout('Regrowth', schedule.expectedGCD, context), nil, context) then
            return v6DirectRow, 3, 28
        end
    end
    row, index = V6FirstReadyRow(rows, v6FillerRows, friend)
    if row then return row, 4, index end
end

local function SelectV6Thread2Heal(context)
    local bestStage, bestIndex, bestData
    v6SelectedUnit = nil
    for unit, data in pairs(jungle.unitCache) do
        if jungle.isUnitAvailable(unit) and UnitIsFriend('player', unit)
            and not UnitIsDeadOrGhost(unit) then
            local row, stage, index = V6Thread2Candidate(unit, data, context)
            if row then
                local better = not bestData or stage < bestStage
                if bestData and stage == bestStage then
                    -- Spell priority still owns emergency, maintenance and filler.
                    -- Additional healing compares people before their spell choice.
                    local rank = stage == 3 and data.currLife or index
                    local bestRank = stage == 3 and bestData.currLife or bestIndex
                    better = rank < bestRank
                    if rank == bestRank then
                        local bucket, bestBucket = data.hpBucket or 0, bestData.hpBucket or 0
                        better = bucket > bestBucket
                            or (bucket == bestBucket and (data.hotScore or 0) < (bestData.hotScore or 0))
                    end
                end
                if better then
                    bestStage, bestIndex, bestData = stage, index, data
                    v6SelectedUnit = unit
                    -- V6 reuses its rows for each unit: copy values immediately.
                    local selected = v6SelectedRows[1]
                    selected[1], selected[2], selected[4] = row[1], row[2], row[4]
                end
            end
        end
    end
end

local function druidThread2Heal(friend)
    local context = GetV6FrameContext()
    local useRaidSelector
    if context then
        useRaidSelector = context.knowsLifebloom and context.playerInCombat
    elseif jungle.Engine and jungle.GetRoutineThread() == 2 then
        useRaidSelector = IsSpellLearned('Lifebloom') and UnitAffectingCombat('player')
    end
    -- Keep thread 7, pre-Lifebloom healing and out-of-combat selection rules.
    if not useRaidSelector then
        v6SelectionTick = nil
        return universalHealSetV6(friend, context)
    end
    -- The engine advances currentTick before updating units and selecting a heal.
    -- Evaluate each friend once per tick, then expose only the selected action
    -- to the unchanged shared selector (including its cast/stopcast bookkeeping).
    if not jungle.currentTick or v6SelectionTick ~= jungle.currentTick or v6SelectionEntry ~= jungle.RoutineContext then
        SelectV6Thread2Heal(context)
        v6SelectionTick = jungle.currentTick
        v6SelectionEntry = jungle.RoutineContext
    end
    return friend == v6SelectedUnit and v6SelectedRows or emptyUnivV6Cache
end

jungle.universalHealSetV6 = druidThread2Heal	

-- An aura alone is not enough to identify the first/second-Regrowth sequence.
-- Arm the insertion only after this routine successfully casts Regrowth on an
-- active tank, and consume it when that tank receives our Rejuvenation.
local v6TankRejuvTracker = CreateFrame("Frame")
v6TankRejuvTracker:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
v6TankRejuvTracker:RegisterEvent("PLAYER_REGEN_ENABLED")
v6TankRejuvTracker:RegisterEvent("PLAYER_ENTERING_WORLD")
v6TankRejuvTracker:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" then
        v6TankRejuvAfterRegrowth = {}
        return
    end

    local _, subEvent, _, sourceGUID, _, _, _, destGUID, _, _, _, _, spellName = CombatLogGetCurrentEventInfo()
    if subEvent ~= "SPELL_CAST_SUCCESS" or sourceGUID ~= UnitGUID("player") or not destGUID then
        return
    end

    local regrowthName = GetSpellInfo("Regrowth") or "Regrowth"
    local rejuvenationName = GetSpellInfo("Rejuvenation") or "Rejuvenation"

    if spellName == rejuvenationName then
        v6TankRejuvAfterRegrowth[destGUID] = nil
        return
    end

    if spellName ~= regrowthName
        or not jungle.Engine
        or jungle.GetRoutineThread() ~= 2
        or not IsSpellLearned("Lifebloom")
        or not IsV6ActiveTankGUID(destGUID) then
        return
    end

    local currentCast = jungle.CurrentCast
    local wasRecentRoutineCast = currentCast
        and currentCast.spellName == regrowthName
        and currentCast.targetGUID == destGUID
        and currentCast.startTime
        and (GetTime() - currentCast.startTime) <= 5

    if wasRecentRoutineCast then
        v6TankRejuvAfterRegrowth[destGUID] = true
    end
end)

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
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
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

    univPvPCache[7][4] = (not routineActions or routineActions["Rejuvenation"] ~= false) and GetPvPRejuvCallback(friend) or nil
    
    univPvPCache[1][3] = ((not routineActions or routineActions[univPvPCache[1][2]] ~= false) and (inCombat and not hasNS and jungle.IsSpellReadyIgnoreGCD("Nature's Swiftness") and hp <= 0.30))
    univPvPCache[2][3] = ((not routineActions or routineActions[univPvPCache[2][2]] ~= false) and (hasNS and hp <= 0.35))
    univPvPCache[3][3] = ((not routineActions or routineActions[univPvPCache[3][2]] ~= false) and (hp <= 0.55 and (hasRegAny or hasRejAny) and not smOnCD))
    univPvPCache[4][3] = ((not routineActions or routineActions[univPvPCache[4][2]] ~= false) and (isCriticalLB))
    univPvPCache[5][3] = ((not routineActions or routineActions[univPvPCache[5][2]] ~= false) and (needsDirectHPS and jungle.ReadyCastSpell('Regrowth', friend)))
    univPvPCache[6][3] = ((not routineActions or routineActions[univPvPCache[6][2]] ~= false) and (isPrimaryTarget and lbCount < 3 and not lbExpiring))
    univPvPCache[7][3] = ((not routineActions or routineActions[univPvPCache[7][2]] ~= false) and (not hasRejuv and needsBuffer))
    univPvPCache[8][3] = ((not routineActions or routineActions[univPvPCache[8][2]] ~= false) and (lbExpiring and not isCriticalLB))
    univPvPCache[9][3] = ((not routineActions or routineActions[univPvPCache[9][2]] ~= false) and (isRegrowthSafe and not hasRegrowth and (hp < 0.90 or isFocused)))
    univPvPCache[10][3] = ((not routineActions or routineActions[univPvPCache[10][2]] ~= false) and (not hasRejuv and (hp < 0.92 or pressure > 0)))
    univPvPCache[11][3] = ((not routineActions or routineActions[univPvPCache[11][2]] ~= false) and (not isPrimaryTarget and lbCount < 2 and (hp < 0.98 or inCombat)))
    univPvPCache[12][3] = ((not routineActions or routineActions[univPvPCache[12][2]] ~= false) and (not isPrimaryTarget and lbCount == 2 and (isFocused or hp < 0.80)))
    univPvPCache[13][3] = ((not routineActions or routineActions[univPvPCache[13][2]] ~= false) and (isMoving and hp < 0.70 and not smOnCD and (hasRegAny or hasRejAny)))

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

-- Druid interruption is intentionally disabled in every context (PvE and PvP).
-- Returning an empty set prevents Bash, Feral Charge, Maim, and interrupt prep shifts.
local function druid_interrupt(target)
    return {}
end
jungle.druid_interrupt = druid_interrupt

-- Opt-in event timing; original scripts remain installed while tracing is off.
jungle.RaidTrace:WatchEventFrame(v6TankRejuvTracker, "druidTankTracker")
jungle.RaidTrace:WatchEventFrame(druidTalentFrame, "druidCapabilities")

function jungle.ResetDruidRoutineState()
    v6SelectionTick, v6SelectionEntry = nil, nil
    v6FrameContext.tick = nil
    v6BloomSchedule.tick = nil
    pendingMoonfireGUID = nil
    powershiftEndTime, powershiftTarget = 0, 0
end

jungle.pveHealSet = pveHealSet
