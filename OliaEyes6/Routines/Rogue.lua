local Jungle, jungle = ...
local unitCache = jungle.unitCache

-- Eviscerate rank tracking
local evisIDs = {2098, 6760, 6761, 6762, 8639, 8640, 11299, 11300, 31016}
local evisData = {
    [1] = {b=3, m=5},
    [2] = {b=6, m=11},
    [3] = {b=11, m=18},
    [4] = {b=20, m=31},
    [5] = {b=30, m=49},
    [6] = {b=43, m=72},
    [7] = {b=63, m=106},
    [8] = {b=96, m=151},
    [9] = {b=108, m=170}
}

local function GetHighestLearnedRank(idTable)
    for i = #idTable, 1, -1 do
        if IsPlayerSpell(idTable[i]) then
            return i
        end
    end
    return 1 -- Default to Rank 1 if none found
end

local dpsRogueCache = {
    [1] = {'Eviscerate', 'Eviscerate', false, 1, 0},
    [2] = {'Backstab', 'Backstab', false, 1, 0},
    [3] = {'Sinister Strike', 'Sinister Strike', false, 1, 0},
    [4] = {'Attack', 'Attack', false, 1, 0},
}
local emptyDpsCache = {}

function jungle.rogueDpsSet(_target)
    if not UnitExists(_target) or not UnitCanAttack("player", _target) then return emptyDpsCache end
    
    local cp = GetComboPoints('player', _target)
    local targetHP = UnitHealth(_target)
    
    -- Eviscerate Calculation (Mirrored from Feral Druid FB logic)
    local evisRank = GetHighestLearnedRank(evisIDs)
    local currentEvis = evisData[evisRank] or evisData[1]
    local baseAP, posAP, negAP = UnitAttackPower("player")
    local totalAP = baseAP + posAP + negAP
    
    local predictedDamage = (currentEvis.b + (currentEvis.m * cp)) + (totalAP * 0.03 * cp)
    local isKillShot = (cp >= 1 and predictedDamage >= (targetHP * 1.2))
    
    local useEvis = isKillShot or (cp == 5)
    
    local isStealthed = IsStealthed()
    local shouldAttack = (not isStealthed and not IsCurrentSpell(6603))
    
    -- Backstab Position & Weapon check (locale-independent classID/subclassID)
    local isBehind = not jungle.ImNotBehindUnit(_target)
    local hasDagger = false
    local mhItemID = GetInventoryItemID("player", 16)
    if mhItemID then
        local _, _, _, _, _, classID, subclassID = GetItemInfoInstant(mhItemID)
        if classID == 2 and subclassID == 15 then
            hasDagger = true
        else
            local _, _, _, _, _, _, itemSubType = GetItemInfo(mhItemID)
            if itemSubType == "Daggers" or itemSubType == "Dagger" then
                hasDagger = true
            end
        end
    end
    
    dpsRogueCache[1][3] = (not isStealthed and jungle.ReadyCastSpell('Eviscerate', _target) and useEvis)
    dpsRogueCache[2][3] = (hasDagger and isBehind and jungle.ReadyCastSpell('Backstab', _target) and cp < 5)
    dpsRogueCache[3][3] = (not isStealthed and jungle.ReadyCastSpell('Sinister Strike', _target) and cp < 5 and (not isBehind or not hasDagger))
    dpsRogueCache[4][3] = (shouldAttack)
    
    return dpsRogueCache
end
