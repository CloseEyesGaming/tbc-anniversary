local Jungle, jungle = ...
local unitCache = jungle.unitCache

-- ============================================================================
-- FOLLOWER ROUTINE
-- ============================================================================

local TREE_OF_LIFE_SPELL_NAME = "Tree of Life"
local TREE_OF_LIFE_SPELL_ID = 33891

local followerCache = {
    [1] = {'Rest Stop', 'StopFollow', false, 1, 0},
    [2] = {'Drink', 'Drink', false, 1, 0},
    [3] = {'Food', 'Food', false, 1, 0},
    [4] = {TREE_OF_LIFE_SPELL_NAME, TREE_OF_LIFE_SPELL_NAME, false, 1, 0},
    [5] = {'Mount',  'Mount', false, 1, 0},
    [6] = {'Follow', 'Follow', false, 1, 0},
    [7] = {'StopFollow', 'StopFollow', false, 1, 0},
}
local emptyFollowerCache = {}

jungle.followerMountConfig = jungle.followerMountConfig or {
    flyingMount = "Starshard Netherdrake",
    groundMount = "Cerulean Phase-Hunter",
    driverMounts = {
        "Green Mechanostrider",
        "Starshard Netherdrake",
        "Cerulean Phase-Hunter",
        "Reins of the Striped Nightsaber",
    },
}

jungle.followerConsumableCache = jungle.followerConsumableCache or {
    scannedAt = 0,
    food = nil,
    drink = nil,
    activeMacros = {},
}

local outlandMapIDs = {
    [100] = true, -- Hellfire Peninsula
    [101] = true, -- Outland continent
    [102] = true, -- Zangarmarsh
    [104] = true, -- Shadowmoon Valley
    [105] = true, -- Blade's Edge Mountains
    [107] = true, -- Nagrand
    [108] = true, -- Terokkar Forest
    [109] = true, -- Netherstorm
    [111] = true, -- Shattrath City
}

local outlandZoneNames = {
    ["Hellfire Peninsula"] = true,
    ["Zangarmarsh"] = true,
    ["Shadowmoon Valley"] = true,
    ["Blade's Edge Mountains"] = true,
    ["Nagrand"] = true,
    ["Terokkar Forest"] = true,
    ["Netherstorm"] = true,
    ["Shattrath City"] = true,
    ["Outland"] = true,
}

-- Mount spell/aura names available in the TBC Anniversary client. This includes
-- inherited Classic mounts, TBC mounts, world-event mounts, and Anniversary
-- additions. The tooltip and speed checks below remain as future-proof fallbacks.
local knownTBCMounts = {
    -- TBC Anniversary additions
    ["Cerulean Phase-Hunter"] = true,
    ["Reawakened Phase-Hunter"] = true,
    ["Re-Awakened Phase-Hunter"] = true,
    ["Starshard Netherdrake"] = true,
    ["Reins of the Starshard Netherdrake"] = true,
    ["Voidfeather Dragonhawk"] = true,

    -- Blood Elf and Draenei racial mounts
    ["Black Hawkstrider"] = true,
    ["Purple Hawkstrider"] = true,
    ["Red Hawkstrider"] = true,
    ["Blue Hawkstrider"] = true,
    ["Swift Pink Hawkstrider"] = true,
    ["Swift Purple Hawkstrider"] = true,
    ["Swift Green Hawkstrider"] = true,
    ["Brown Elekk"] = true,
    ["Gray Elekk"] = true,
    ["Purple Elekk"] = true,
    ["Great Blue Elekk"] = true,
    ["Great Purple Elekk"] = true,
    ["Great Green Elekk"] = true,

    -- TBC vendor flying mounts
    ["Snowy Gryphon"] = true,
    ["Ebon Gryphon"] = true,
    ["Golden Gryphon"] = true,
    ["Swift Purple Gryphon"] = true,
    ["Swift Blue Gryphon"] = true,
    ["Swift Red Gryphon"] = true,
    ["Swift Green Gryphon"] = true,
    ["Blue Wind Rider"] = true,
    ["Green Wind Rider"] = true,
    ["Tawny Wind Rider"] = true,
    ["Swift Red Wind Rider"] = true,
    ["Swift Green Wind Rider"] = true,
    ["Swift Yellow Wind Rider"] = true,
    ["Swift Purple Wind Rider"] = true,

    -- TBC reputation, PvP, dungeon, raid, and profession mounts
    ["Dark Riding Talbuk"] = true,
    ["Dark War Talbuk"] = true,
    ["Cobalt Riding Talbuk"] = true,
    ["White Riding Talbuk"] = true,
    ["Tan Riding Talbuk"] = true,
    ["Silver Riding Talbuk"] = true,
    ["Cobalt War Talbuk"] = true,
    ["White War Talbuk"] = true,
    ["Tan War Talbuk"] = true,
    ["Silver War Talbuk"] = true,
    ["Blue Riding Nether Ray"] = true,
    ["Red Riding Nether Ray"] = true,
    ["Green Riding Nether Ray"] = true,
    ["Silver Riding Nether Ray"] = true,
    ["Purple Riding Nether Ray"] = true,
    ["Azure Netherwing Drake"] = true,
    ["Onyx Netherwing Drake"] = true,
    ["Violet Netherwing Drake"] = true,
    ["Purple Netherwing Drake"] = true,
    ["Veridian Netherwing Drake"] = true,
    ["Cobalt Netherwing Drake"] = true,
    ["Swift Nether Drake"] = true,
    ["Vengeful Nether Drake"] = true,
    ["Merciless Nether Drake"] = true,
    ["Brutal Nether Drake"] = true,
    ["Dragonmaw Nether Drake"] = true,
    ["Cenarion War Hippogryph"] = true,
    ["Raven Lord"] = true,
    ["Swift White Hawkstrider"] = true,
    ["Amani War Bear"] = true,
    ["Ashes of Al'ar"] = true,
    ["Fiery Warhorse"] = true,
    ["Flying Machine"] = true,
    ["Turbo-Charged Flying Machine"] = true,
    ["Swift Warstrider"] = true,

    -- TBC world-event and promotional mounts
    ["Headless Horseman's Mount"] = true,
    ["Great Brewfest Kodo"] = true,
    ["Brewfest Ram"] = true,
    ["Swift Brewfest Ram"] = true,
    ["Magic Broom"] = true,
    ["Old Magic Broom"] = true,
    ["Rickety Magic Broom"] = true,
    ["Swift Magic Broom"] = true,
    ["Flying Broom"] = true,
    ["Swift Flying Broom"] = true,
    ["Riding Turtle"] = true,
    ["Spectral Tiger"] = true,
    ["Swift Spectral Tiger"] = true,
    ["Swift Zhevra"] = true,
    ["Big Blizzard Bear"] = true,

    -- Inherited Horde racial and PvP mounts
    ["Brown Wolf"] = true,
    ["Dire Wolf"] = true,
    ["Timber Wolf"] = true,
    ["Swift Brown Wolf"] = true,
    ["Swift Gray Wolf"] = true,
    ["Swift Timber Wolf"] = true,
    ["Brown Kodo"] = true,
    ["Gray Kodo"] = true,
    ["Great Brown Kodo"] = true,
    ["Great Gray Kodo"] = true,
    ["Great White Kodo"] = true,
    ["Emerald Raptor"] = true,
    ["Turquoise Raptor"] = true,
    ["Violet Raptor"] = true,
    ["Swift Blue Raptor"] = true,
    ["Swift Olive Raptor"] = true,
    ["Swift Orange Raptor"] = true,
    ["Blue Skeletal Horse"] = true,
    ["Brown Skeletal Horse"] = true,
    ["Red Skeletal Horse"] = true,
    ["Green Skeletal Warhorse"] = true,
    ["Purple Skeletal Warhorse"] = true,
    ["Black War Wolf"] = true,
    ["Black War Kodo"] = true,
    ["Black War Raptor"] = true,
    ["Red Skeletal Warhorse"] = true,
    ["Frostwolf Howler"] = true,

    -- Inherited Alliance racial and PvP mounts
    ["Pinto"] = true,
    ["Brown Horse"] = true,
    ["Chestnut Mare"] = true,
    ["Black Stallion"] = true,
    ["Swift White Steed"] = true,
    ["Swift Brown Steed"] = true,
    ["Swift Palomino"] = true,
    ["Spotted Frostsaber"] = true,
    ["Striped Frostsaber"] = true,
    ["Striped Nightsaber"] = true,
    ["Swift Frostsaber"] = true,
    ["Swift Mistsaber"] = true,
    ["Swift Stormsaber"] = true,
    ["Brown Ram"] = true,
    ["Gray Ram"] = true,
    ["White Ram"] = true,
    ["Swift Brown Ram"] = true,
    ["Swift Gray Ram"] = true,
    ["Swift White Ram"] = true,
    ["Blue Mechanostrider"] = true,
    ["Green Mechanostrider"] = true,
    ["Red Mechanostrider"] = true,
    ["Unpainted Mechanostrider"] = true,
    ["Swift Green Mechanostrider"] = true,
    ["Swift White Mechanostrider"] = true,
    ["Swift Yellow Mechanostrider"] = true,
    ["Black War Steed"] = true,
    ["Black War Tiger"] = true,
    ["Black War Ram"] = true,
    ["Black Battlestrider"] = true,
    ["Stormpike Battle Charger"] = true,
    ["Winterspring Frostsaber"] = true,

    -- Inherited class, dungeon, raid, and Scarab Lord mounts
    ["Warhorse"] = true,
    ["Charger"] = true,
    ["Summon Warhorse"] = true,
    ["Summon Charger"] = true,
    ["Summon Felsteed"] = true,
    ["Summon Dreadsteed"] = true,
    ["Deathcharger"] = true,
    ["Swift Razzashi Raptor"] = true,
    ["Swift Zulian Tiger"] = true,
    ["Blue Qiraji Battle Tank"] = true,
    ["Green Qiraji Battle Tank"] = true,
    ["Yellow Qiraji Battle Tank"] = true,
    ["Red Qiraji Battle Tank"] = true,
    ["Black Qiraji Battle Tank"] = true,
    ["Summon Blue Qiraji Battle Tank"] = true,
    ["Summon Green Qiraji Battle Tank"] = true,
    ["Summon Yellow Qiraji Battle Tank"] = true,
    ["Summon Red Qiraji Battle Tank"] = true,
    ["Summon Black Qiraji Battle Tank"] = true,
}

local getScanTooltip

local function isKnownDriverMount(spellName, spellID)
    if spellID and C_MountJournal and C_MountJournal.GetMountFromSpell
        and C_MountJournal.GetMountFromSpell(spellID) then
        return true
    end

    if not spellName then return false end
    if knownTBCMounts[spellName] then return true end

    local config = jungle.followerMountConfig
    if spellName == config.flyingMount or spellName == config.groundMount then
        return true
    end
    for _, mountName in ipairs(config.driverMounts) do
        if spellName == mountName then
            return true
        end
    end
    return false
end

local function auraTooltipLooksLikeMount(driver, auraIndex, duration)
    -- Mount auras are permanent until dismounted. Avoid temporary speed buffs.
    if duration and duration > 0 then return false end
    if not getScanTooltip then return false end

    local tooltip = getScanTooltip()
    if not tooltip or not tooltip.SetUnitBuff then return false end

    tooltip:ClearLines()
    tooltip:SetUnitBuff(driver, auraIndex)

    local looksMounted = false
    for i = 1, tooltip:NumLines() do
        local line = _G["OliaFollowerConsumableTooltipTextLeft" .. i]
        local text = string.lower((line and line:GetText()) or "")
        if string.find(text, "rideable", 1, true)
            or string.find(text, "very fast mount", 1, true)
            or string.find(text, "flying mount", 1, true)
            or string.find(text, "increases speed by", 1, true)
            or string.find(text, "increases flight speed by", 1, true)
            or string.find(text, "increases ground speed by", 1, true)
            or (string.find(text, "summons and dismisses", 1, true)
                and string.find(text, "mount", 1, true)) then
            looksMounted = true
            break
        end
    end

    tooltip:ClearLines()
    return looksMounted
end

local driverMountStateCache = {
    guid = nil,
    checkedAt = 0,
    mounted = false,
}

local function driverLooksMounted(driver)
    if not UnitExists(driver) then return false end

    local driverGUID = UnitGUID(driver)
    local now = GetTime()
    if driverGUID and driverMountStateCache.guid == driverGUID
        and (now - driverMountStateCache.checkedAt) < 0.25 then
        return driverMountStateCache.mounted
    end

    local mounted = false

    -- Detect any mount exposed by the client, including stationary ground/flying
    -- mounts. The explicit names remain as a fallback on clients without a
    -- mount journal.
    for i = 1, 40 do
        local auraName, _, _, _, duration, _, _, _, _, spellID = UnitAura(driver, i, "HELPFUL")
        if not auraName then break end
        if isKnownDriverMount(auraName, spellID)
            or auraTooltipLooksLikeMount(driver, i, duration) then
            mounted = true
            break
        end
    end

    if not mounted then
        local driverCastName, _, _, _, _, _, _, _, driverCastSpellID = UnitCastingInfo(driver)
        mounted = isKnownDriverMount(driverCastName, driverCastSpellID)
    end

    if not mounted then
        local driverSpeed = GetUnitSpeed(driver) or 0
        mounted = driverSpeed > 9
    end

    driverMountStateCache.guid = driverGUID
    driverMountStateCache.checkedAt = now
    driverMountStateCache.mounted = mounted
    return mounted
end

local function isOutlandZone()
    local mapID
    if C_Map and C_Map.GetBestMapForUnit then
        mapID = C_Map.GetBestMapForUnit("player")
    end
    if mapID and outlandMapIDs[mapID] then
        return true
    end

    local zoneName = GetRealZoneText and GetRealZoneText() or nil
    return zoneName and outlandZoneNames[zoneName] or false
end

local function getFlyingLevelRequirement()
    local _, class = UnitClass("player")
    if class == "DRUID" then
        return 68
    end
    return 70
end

local function updateStaticMacro(actionID, macro)
    if InCombatLockdown and InCombatLockdown() then return false end
    local hotkeys = jungle.Hotkeys
    if not hotkeys or not hotkeys.StaticButtons then return false end

    local cache = jungle.followerConsumableCache.activeMacros
    if cache[actionID] == macro then return true end

    for _, btnData in ipairs(hotkeys.StaticButtons) do
        if btnData.id == actionID and btnData.frame then
            btnData.frame:SetAttribute("macrotext", macro)
            cache[actionID] = macro
            return true
        end
    end
    return false
end

local function getMountMacro(mountMode)
    local config = jungle.followerMountConfig
    local mountName = (mountMode == "flying") and config.flyingMount or config.groundMount
    return "/cancelform [outdoors,nocombat]\n/cast [outdoors,nocombat] " .. mountName
end

local function updateMountMacro(mountMode)
    local macro = getMountMacro(mountMode)
    local config = jungle.followerMountConfig
    if config.activeMountMacro == macro then return true end
    if updateStaticMacro("Mount", macro) then
        config.activeMountMacro = macro
        return true
    end
    return false
end

local function getBagSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag) or 0
    end
    return GetContainerNumSlots and GetContainerNumSlots(bag) or 0
end

local function getBagItemLink(bag, slot)
    if C_Container and C_Container.GetContainerItemLink then
        return C_Container.GetContainerItemLink(bag, slot)
    end
    return GetContainerItemLink and GetContainerItemLink(bag, slot) or nil
end

local function isBagItemLocked(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        return info and info.isLocked or false
    end
    if GetContainerItemInfo then
        local _, _, locked = GetContainerItemInfo(bag, slot)
        return locked
    end
    return false
end

local function getItemIDFromLink(link)
    return link and tonumber(string.match(link, "item:(%d+)")) or nil
end

local scanTooltip
getScanTooltip = function()
    if not scanTooltip then
        scanTooltip = CreateFrame("GameTooltip", "OliaFollowerConsumableTooltip", nil, "GameTooltipTemplate")
        if UIParent then
            scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        end
    end
    return scanTooltip
end

local function parseRestoreValue(text, resource)
    local cleaned = string.lower(text or "")
    cleaned = string.gsub(cleaned, ",", "")
    local best = 0
    for amount in string.gmatch(cleaned, "(%d+)%s+" .. resource) do
        local value = tonumber(amount) or 0
        if value > best then best = value end
    end
    return best
end

local function scanConsumableTooltip(bag, slot)
    local tooltip = getScanTooltip()
    tooltip:ClearLines()
    tooltip:SetBagItem(bag, slot)

    local healthRestore, manaRestore = 0, 0
    local isSeatedConsumable = false
    local mentionsEating = false
    local mentionsDrinking = false

    for i = 1, tooltip:NumLines() do
        local line = _G["OliaFollowerConsumableTooltipTextLeft" .. i]
        local text = line and line:GetText() or ""
        local lower = string.lower(text)

        if string.find(lower, "must remain seated") then isSeatedConsumable = true end
        if string.find(lower, "eating") then mentionsEating = true end
        if string.find(lower, "drinking") then mentionsDrinking = true end

        healthRestore = math.max(healthRestore, parseRestoreValue(text, "health"))
        manaRestore = math.max(manaRestore, parseRestoreValue(text, "mana"))
    end

    tooltip:ClearLines()

    if not isSeatedConsumable and not mentionsEating and not mentionsDrinking then
        return nil
    end

    return {
        health = healthRestore,
        mana = manaRestore,
        isFood = healthRestore > 0 and (mentionsEating or isSeatedConsumable),
        isDrink = manaRestore > 0 and (mentionsDrinking or mentionsEating or isSeatedConsumable),
    }
end

local function isUsableInventoryItem(link)
    local itemID = getItemIDFromLink(link)
    local itemName, _, _, _, itemMinLevel = GetItemInfo(link)
    if itemMinLevel and itemMinLevel > 0 and UnitLevel("player") < itemMinLevel then
        return false
    end

    local itemRef = itemID or itemName or link
    local usable = IsUsableItem and IsUsableItem(itemRef)
    if not usable then return false end

    if GetItemCooldown then
        local start, duration, enabled = GetItemCooldown(itemRef)
        if enabled == 0 then return false end
        if start and duration and duration > 0 and (start + duration) > GetTime() then
            return false
        end
    end

    return itemName or (link and string.match(link, "%[(.-)%]"))
end

local function scanBestConsumables(force)
    local cache = jungle.followerConsumableCache
    local now = GetTime()
    if not force and cache.scannedAt and (now - cache.scannedAt) < 1 then
        return cache.food, cache.drink
    end

    cache.scannedAt = now
    cache.food = nil
    cache.drink = nil

    local maxBag = NUM_BAG_SLOTS or 4
    for bag = 0, maxBag do
        for slot = 1, getBagSlots(bag) do
            local link = getBagItemLink(bag, slot)
            if link and not isBagItemLocked(bag, slot) then
                local itemName = isUsableInventoryItem(link)
                if itemName then
                    local info = scanConsumableTooltip(bag, slot)
                    if info then
                        if info.isFood and info.health > 0 and (not cache.food or info.health > cache.food.score) then
                            cache.food = { name = itemName, score = info.health }
                        end
                        if info.isDrink and info.mana > 0 and (not cache.drink or info.mana > cache.drink.score) then
                            cache.drink = { name = itemName, score = info.mana }
                        end
                    end
                end
            end
        end
    end

    return cache.food, cache.drink
end

local function updateConsumableMacro(actionID, item)
    if not item or not item.name then return false end
    return updateStaticMacro(actionID, "/use " .. item.name)
end

local function getFollowerTravelState()
    local inInstance, instanceType = IsInInstance()
    local isOutdoors = IsOutdoors()
    local isMountableInstance = (not inInstance) or instanceType == "none" or instanceType == "pvp"
    local isCasting = UnitCastingInfo("player") ~= nil or UnitChannelInfo("player") ~= nil
    local isMounted = IsMounted()
    local playerSpeed = GetUnitSpeed("player") or 0
    local isFlyable = IsFlyableArea and IsFlyableArea() or false
    local playerLevel = UnitLevel("player") or 0
    local canUseFlyingMount = isFlyable and isOutlandZone() and playerLevel >= getFlyingLevelRequirement()

    return {
        inCombat = UnitAffectingCombat("player"),
        isCasting = isCasting,
        isMounted = isMounted,
        isMoving = playerSpeed > 0,
        isOutdoors = isOutdoors,
        isMountableInstance = isMountableInstance,
        mountMode = canUseFlyingMount and "flying" or "ground",
        canMount = isOutdoors
            and isMountableInstance
            and not UnitAffectingCombat("player")
            and not isCasting
            and not isMounted
            and playerSpeed == 0,
    }
end

local function getFollowerRestState(travel)
    local manaMax = UnitPowerMax("player", 0) or 0
    local manaPct = manaMax > 0 and ((UnitPower("player", 0) or 0) / manaMax) or 1
    local healthMax = UnitHealthMax("player") or 0
    local healthPct = healthMax > 0 and ((UnitHealth("player") or 0) / healthMax) or 1
    local hasDrink = jungle.unitCacheBuff("player", "Drink") or jungle.unitCacheBuff("player", "Refreshment")
    local hasFood = jungle.unitCacheBuff("player", "Food") or jungle.unitCacheBuff("player", "Refreshment")
    local bestFood, bestDrink = scanBestConsumables()

    local lowMana = not travel.inCombat and manaPct < 0.50
    local lowHealth = healthPct < 0.70
    local canDrink = bestDrink and updateConsumableMacro("Drink", bestDrink)
    local canEat = bestFood and updateConsumableMacro("Food", bestFood)
    local shouldRest = lowMana and (hasDrink or hasFood or canDrink or (lowHealth and canEat))

    return {
        shouldRest = shouldRest,
        shouldStop = shouldRest and travel.isMoving,
        shouldDrink = shouldRest and canDrink and not hasDrink and not travel.isMoving and not travel.isCasting and not travel.isMounted,
        shouldEat = shouldRest and lowHealth and canEat and not hasFood and not travel.isMoving and not travel.isCasting and not travel.isMounted,
    }
end

local function getFollowerDriver()
    local driver = "target"
    if not UnitExists(driver) then
        driver = "party1"
    end
    return driver
end

local function isTreeOfLifeKnown()
    if IsPlayerSpell and IsPlayerSpell(TREE_OF_LIFE_SPELL_ID) then return true end
    if IsSpellKnown and IsSpellKnown(TREE_OF_LIFE_SPELL_ID) then return true end
    return GetSpellBookItemInfo and GetSpellBookItemInfo(TREE_OF_LIFE_SPELL_NAME) ~= nil
end

local function isTreeOfLifeActive()
    if jungle.unitCacheBuff("player", TREE_OF_LIFE_SPELL_NAME) then return true end
    if AuraUtil and AuraUtil.FindAuraByName then
        return AuraUtil.FindAuraByName(TREE_OF_LIFE_SPELL_NAME, "player", "HELPFUL") ~= nil
    end
    return false
end

local function followerNeedsHealing()
    if not UnitAffectingCombat("player") then return false end

    for unit, data in pairs(jungle.unitCache) do
        if data and data.currLife and data.currLife < 0.90
            and jungle.isUnitAvailable(unit)
            and UnitIsFriend("player", unit)
            and not UnitIsDeadOrGhost(unit) then
            return true
        end
    end

    return false
end

local function shouldUseTreeOfLife(travel, rest)
    local _, class = UnitClass("player")
    return class == "DRUID"
        and not rest.shouldRest
        and travel.inCombat
        and not travel.isCasting
        and not travel.isMounted
        and isTreeOfLifeKnown()
        and not isTreeOfLifeActive()
        and followerNeedsHealing()
        and jungle.ReadyCastSpell(TREE_OF_LIFE_SPELL_NAME)
end

function jungle.followerSet(friend)
    -- 1. Identify Driver
    local driver = getFollowerDriver()

    -- Fast exit: only evaluate once per rotation tick (when friend == driver)
    if not UnitIsUnit(friend, driver) then return emptyFollowerCache end
    if not UnitExists(driver) or UnitIsDeadOrGhost(driver) then return emptyFollowerCache end

    local travel = getFollowerTravelState()
    local rest = getFollowerRestState(travel)
    local shouldMirrorMount = driverLooksMounted(driver)

    -- 2. Follow distance
    local isVeryClose = jungle.inMeleeRange(driver) -- about 7 yards

    followerCache[1][3] = rest.shouldStop
    followerCache[2][3] = rest.shouldDrink
    followerCache[3][3] = rest.shouldEat

    local shouldTree = shouldUseTreeOfLife(travel, rest)
    followerCache[4][3] = shouldTree

    -- 3. Mount only when the driver appears to be mounting/mounted and we can mount now.
    local shouldMount = (not shouldTree and not rest.shouldRest and shouldMirrorMount and travel.canMount and not (isVeryClose and travel.isMoving))
    if shouldMount then
        updateMountMacro(travel.mountMode)
    end
    followerCache[5][3] = shouldMount

    -- 4. Follow Logic: still works in instances/indoors when mount is blocked.
    followerCache[6][3] = (not shouldTree and not rest.shouldRest and not isVeryClose and not travel.isCasting)

    -- 5. Stop Follow (if close and we are still auto-running toward driver)
    followerCache[7][3] = (not shouldTree and not rest.shouldRest and isVeryClose and travel.isMoving)

    return followerCache
end
