local Jungle, jungle = ...

BEACONED_FRIEND = ''
TO_BEACON = nil

local unitCache = {} -- Table to store cached unit data
jungle.unitCache = unitCache

local UNIVERSAL_TOKENS = {"player", "target", "focus", "mouseover", "pet", "softenemy"}
local DEBUFF_CATEGORIES = {'magic', 'curse', 'poison', 'disease', 'slow', 'root', 'freedom', 'unitIgnore'}
local RAID_TOKENS = {}
local PARTY_TOKENS = {}
local ARENA_TOKENS = {}
local ALL_TRACKED_TOKENS = {}
local TRACKED_TOKEN_SET = {}

for i = 1, 25 do
    RAID_TOKENS[i] = "raid" .. i
    PARTY_TOKENS[i] = "party" .. i
end
for i = 1, 5 do
    ARENA_TOKENS[i] = "arena" .. i
end

local function AddTrackedToken(token)
    if not TRACKED_TOKEN_SET[token] then
        TRACKED_TOKEN_SET[token] = true
        ALL_TRACKED_TOKENS[#ALL_TRACKED_TOKENS + 1] = token
    end
end

for i = 1, #UNIVERSAL_TOKENS do
    AddTrackedToken(UNIVERSAL_TOKENS[i])
end
for i = 1, 25 do
    AddTrackedToken(RAID_TOKENS[i])
    AddTrackedToken(PARTY_TOKENS[i])
end
for i = 1, 5 do
    AddTrackedToken(ARENA_TOKENS[i])
end

local auraDirty = {}
local auditCursor = 0
local InvalidateAuraCache = jungle.InvalidateAuraCache

local function MarkAuraDirty(unit)
    if not unit then return end

    if InvalidateAuraCache then
        InvalidateAuraCache(unit)
    end

    if TRACKED_TOKEN_SET[unit] then
        auraDirty[unit] = true
    end

    local guid = UnitGUID(unit)
    if guid then
        for token, data in pairs(unitCache) do
            if data.guid == guid then
                auraDirty[token] = true
            end
        end
    end
end

local auraEventFrame = CreateFrame("Frame")
auraEventFrame:RegisterEvent("UNIT_AURA")
auraEventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
auraEventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
auraEventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
auraEventFrame:RegisterEvent("ARENA_OPPONENT_UPDATE")
auraEventFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_AURA" then
        MarkAuraDirty(unit)
    elseif event == "PLAYER_TARGET_CHANGED" then
        MarkAuraDirty("target")
    elseif event == "PLAYER_FOCUS_CHANGED" then
        MarkAuraDirty("focus")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        MarkAuraDirty("mouseover")
    elseif event == "ARENA_OPPONENT_UPDATE" then
        if unit and TRACKED_TOKEN_SET[unit] then
            MarkAuraDirty(unit)
        else
            for i = 1, #ARENA_TOKENS do
                MarkAuraDirty(ARENA_TOKENS[i])
            end
        end
    end
end)

local function GetNextAuraAuditToken()
    local tokenCount = #ALL_TRACKED_TOKENS
    for _ = 1, tokenCount do
        auditCursor = (auditCursor % tokenCount) + 1
        local token = ALL_TRACKED_TOKENS[auditCursor]
        local data = unitCache[token]
        if data and data.auraInitialized and not auraDirty[token] then
            return token
        end
    end
    return nil
end

local function BuildNameSet(list)
    local set = {}
    if list then
        for _, name in pairs(list) do
            set[name] = true
        end
    end
    return set
end

-- GameData.lua loads immediately before this file. Keep its public arrays intact
-- for compatibility while using private O(1) lookups in the aura hot path.
local UNIT_IGNORE_DEBUFF_SET = BuildNameSet(jungle.unitIgnoreDebuffs)
local SLOW_DEBUFF_SET = BuildNameSet(jungle.slowDebuffs)
local ROOT_DEBUFF_SET = BuildNameSet(jungle.rootDebuffs)
local FREEDOM_DEBUFF_SET = BuildNameSet(jungle.toFreedomDebuffs)
local SLOW_IMMUNITY_BUFF_SET = BuildNameSet(jungle.slowImmunityBuffs)
local CASTER_IGNORE_BUFF_SET = BuildNameSet(jungle.unitIgnoreBuffCaster)
local PHYSICAL_IGNORE_BUFF_SET = BuildNameSet(jungle.unitIgnoreBuffPhys)

local GetTalentSpec
local GetPlayerClass = jungle.GetPlayerClass
local availabilityReady = false
local cachedTalentSpec
local cachedAvailabilityMode
local talentContextDirty = true
local nextTalentContextRefresh = 0
local TALENT_CONTEXT_REFRESH_INTERVAL = 1.0

local function RefreshAvailabilityContext(now)
    now = now or GetTime()
    if availabilityReady and not talentContextDirty and now < nextTalentContextRefresh then
        return
    end

    local playerClass = GetPlayerClass()
    if not playerClass or playerClass == "UNKNOWN" then
        availabilityReady = false
        nextTalentContextRefresh = now
        return
    end

    local usesTalentSpec = playerClass == "DRUID" or playerClass == "PALADIN" or playerClass == "SHAMAN"
    cachedTalentSpec = usesTalentSpec and GetTalentSpec() or nil

    if playerClass == "MAGE" or playerClass == "PRIEST" or playerClass == "WARLOCK"
    or (playerClass == "DRUID" and (cachedTalentSpec == 1 or cachedTalentSpec == 3))
    or (playerClass == "PALADIN" and cachedTalentSpec == 1)
    or (playerClass == "SHAMAN" and (cachedTalentSpec == 1 or cachedTalentSpec == 3)) then
        cachedAvailabilityMode = "caster"
    elseif playerClass == "WARRIOR" or playerClass == "ROGUE" or playerClass == "HUNTER"
    or (playerClass == "DRUID" and cachedTalentSpec == 2)
    or (playerClass == "PALADIN" and (cachedTalentSpec == 2 or cachedTalentSpec == 3))
    or (playerClass == "SHAMAN" and cachedTalentSpec == 2) then
        cachedAvailabilityMode = "physical"
    else
        cachedAvailabilityMode = nil
    end

    availabilityReady = true
    talentContextDirty = false
    nextTalentContextRefresh = usesTalentSpec and (now + TALENT_CONTEXT_REFRESH_INTERVAL) or math.huge
end

local availabilityEventFrame = CreateFrame("Frame")
availabilityEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
availabilityEventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
availabilityEventFrame:SetScript("OnEvent", function()
    talentContextDirty = true
    availabilityReady = false
end)

-- Define a function to check if a value is in a list
local function IsInList(value, list)
  for _, item in pairs(list) do
    if value == item then
      return true
    end
  end
  return false
end
jungle.IsInList = IsInList

--------------------------------------------------------------------------------
-- OPTIMIZATION HELPERS (Table Recycling)
--------------------------------------------------------------------------------

local function InitUnitTable()
    -- Create the complex table structure ONCE per unit
    return {
        identificator = 0,
        isMe = false,
        isInCombat = false,
        currLife = 0,
        maxHP = 1,
        auraInitialized = false,
        nextAuraExpiry = nil,
        missingHP = 0,   -- [NEW] Absolute missing health
        hpBucket = 0,    -- [NEW] Missing HP divided into 500s
        hotScore = 0,    -- [NEW] Saturation score
        threatStatus = 0,
        isTank = false,
        auras = {
            debuffs = {
                all = {}, magic = {}, curse = {}, poison = {}, disease = {},
                slow = {}, root = {}, freedom = {}, unitIgnore = {},
            },
            buffs = {
                player = {}, nonplayer = {}, slowImmunity = {},
                unitIgnoreIfYouCaster = {}, unitIgnoreIfYouPhys = {},
            },
        },
    }
end

local function tableSetInactive(cat)
    for _, tbl in pairs(cat) do
        for _, aura in pairs(tbl) do
            aura.isActive = false
        end
    end
end

local function ResetUnitCache(t)
    tableSetInactive(t.auras.debuffs)
    tableSetInactive(t.auras.buffs)
end

--------------------------------------------------------------------------------
-- PARSING HELPERS
--------------------------------------------------------------------------------

local activeAuraUnitData

local function injectAura(cat, name, count, expirationTime, source)
    local aura = cat[name]
    if not aura then
        aura = {}
        cat[name] = aura
    end
    aura.count = count
    aura.expirationTime = expirationTime
    aura.source = source
    aura.isActive = true

    if activeAuraUnitData and expirationTime and expirationTime > 0
    and (not activeAuraUnitData.nextAuraExpiry or expirationTime < activeAuraUnitData.nextAuraExpiry) then
        activeAuraUnitData.nextAuraExpiry = expirationTime
    end
end

local activeDebuffData
local activeBuffData
local activeBuffUnit

local function ParseDebuffAura(debuff, _, count, dispelType, duration, expirationTime, source, isStealable, _, spellId, _, _, castByPlayer, ...)
    local data = activeDebuffData
    if UNIT_IGNORE_DEBUFF_SET[debuff] then
        injectAura(data.unitIgnore, debuff, count, expirationTime, source)
    end
    if dispelType == 'Magic' then
        injectAura(data.magic, debuff, count, expirationTime, source)
    elseif dispelType == 'Curse' then
        injectAura(data.curse, debuff, count, expirationTime, source)
    elseif dispelType == 'Poison' then
        injectAura(data.poison, debuff, count, expirationTime, source)
    elseif dispelType == 'Disease' then
        injectAura(data.disease, debuff, count, expirationTime, source)
    end
    if SLOW_DEBUFF_SET[debuff] then
        injectAura(data.slow, debuff, count, expirationTime, source)
    end
    if ROOT_DEBUFF_SET[debuff] then
        injectAura(data.root, debuff, count, expirationTime, source)
    end
    if FREEDOM_DEBUFF_SET[debuff] then
        injectAura(data.freedom, debuff, count, expirationTime, source)
    end
end

local function debuffParse(unit)
    activeDebuffData = unitCache[unit].auras.debuffs
	AuraUtil.ForEachAura(unit, "HARMFUL", nil, ParseDebuffAura)
    activeDebuffData = nil
end

local function ParseBuffAura(buff, _, count, dispelType, duration, expirationTime, source, isStealable, _, spellId, _, _, castByPlayer, ...)
    local data = activeBuffData
    if source == 'player' then
        injectAura(data.player, buff, count, expirationTime, source)
        if buff == 'Beacon of Light' then
            BEACONED_unit = activeBuffUnit
        end
    else
        injectAura(data.nonplayer, buff, count, expirationTime, source)
    end
    if SLOW_IMMUNITY_BUFF_SET[buff] then
        injectAura(data.slowImmunity, buff, count, expirationTime, source)
    end
    if CASTER_IGNORE_BUFF_SET[buff] then
        injectAura(data.unitIgnoreIfYouCaster, buff, count, expirationTime, source)
    end
    if PHYSICAL_IGNORE_BUFF_SET[buff] then
        injectAura(data.unitIgnoreIfYouPhys, buff, count, expirationTime, source)
    end
end

local function buffParse(unit)
    activeBuffData = unitCache[unit].auras.buffs
    activeBuffUnit = unit
	AuraUtil.ForEachAura(unit, "HELPFUL", nil, ParseBuffAura)
    activeBuffData = nil
    activeBuffUnit = nil
end

-- local function auraParser(unit)
	-- debuffParse(unit)
	-- buffParse(unit)
    
    -- -- =======================================================
    -- -- [NEW] HOT SCORE & TANK BIAS LOGIC
    -- -- =======================================================
    -- local u = unitCache[unit]
    -- local score = 0
    -- local pBuffs = u.auras.buffs.player
    -- local anyBuffs = u.auras.buffs.nonplayer

    -- -- Calculate base score
    -- if pBuffs['Lifebloom'] then score = score + pBuffs['Lifebloom'].count end
    -- if pBuffs['Rejuvenation'] or anyBuffs['Rejuvenation'] then score = score + 1 end
    -- if pBuffs['Regrowth'] or anyBuffs['Regrowth'] then score = score + 1 end
	
	-- u.currLife = u.currLife + (score * 0.04)

    -- -- Tank Bias: Force tanks to look like they have fewer HoTs so they get priority
    -- if u.isTank and jungle.isTanking(unit) then
        -- if u.currLife < 0.60 then
            -- score = score - 2 -- Critical Tank
        -- elseif u.currLife < 0.90 then
            -- score = score - 1 -- Injured Tank
        -- end
    -- end

    -- u.hotScore = score
-- end
local function RefreshUnitAuras(unit, u)
    if InvalidateAuraCache then
        InvalidateAuraCache(unit)
    end
    ResetUnitCache(u)
    u.nextAuraExpiry = nil
    activeAuraUnitData = u
	debuffParse(unit)
	buffParse(unit)
    activeAuraUnitData = nil
    u.auraInitialized = true
    auraDirty[unit] = nil
end

local function ApplyAuraDerivedState(unit, maxHP)
    -- =======================================================
    -- [NEW] HOT SCORE & TANK BIAS LOGIC
    -- =======================================================
    local u = unitCache[unit]
    local score = 0
    local pBuffs = u.auras.buffs.player
    local anyBuffs = u.auras.buffs.nonplayer
    local lifebloom = pBuffs['Lifebloom']
    local playerRejuvenation = pBuffs['Rejuvenation']
    local otherRejuvenation = anyBuffs['Rejuvenation']
    local playerRegrowth = pBuffs['Regrowth']
    local otherRegrowth = anyBuffs['Regrowth']

    -- Calculate base score
    if lifebloom and lifebloom.isActive then score = score + lifebloom.count end
    if (playerRejuvenation and playerRejuvenation.isActive) or (otherRejuvenation and otherRejuvenation.isActive) then score = score + 1 end
    if (playerRegrowth and playerRegrowth.isActive) or (otherRegrowth and otherRegrowth.isActive) then score = score + 1 end

    -- [NEW] VIRTUAL HEALTH CALIBRATION
    -- Active tanks get 1% per HoT, everyone else gets 4% per HoT
    local activelyTanking = u.isTank and (u.threatStatus == 3 or u.threatStatus == 2)
    local multiplier = activelyTanking and 0.01 or 0.04
    local paddingPct = score * multiplier
    
    u.currLife = u.currLife + paddingPct
    
    -- [NEW] SYNC BUCKETS: Adjust missingHP and hpBucket to match the new virtual life
    maxHP = maxHP or u.maxHP or 1
    local paddingHP = maxHP * paddingPct
    u.missingHP = math.max(0, u.missingHP - paddingHP)
    u.hpBucket = math.floor(u.missingHP / 500)

    -- Tank Bias: Force tanks to look like they have fewer HoTs so they get priority
    if activelyTanking then
        if u.currLife < 0.60 then
            score = score - 2 -- Critical Tank
        elseif u.currLife < 0.90 then
            score = score - 1 -- Injured Tank
        end
    end

    u.hotScore = score
end

local function UpdateUnitAuras(unit, maxHP, now, auditToken)
    local u = unitCache[unit]
    local expired = u.nextAuraExpiry and now >= u.nextAuraExpiry
    if not u.auraInitialized or auraDirty[unit] or unit == auditToken or expired then
        RefreshUnitAuras(unit, u)
    end
    ApplyAuraDerivedState(unit, maxHP)
end

local function cacheUnitData(unit, _identificator, playerName)
    local isNew = false
    if not unitCache[unit] then
        unitCache[unit] = InitUnitTable()
        isNew = true
    end

    local u = unitCache[unit]
    local guid = UnitGUID(unit)
    if isNew or u.guid ~= guid then
        u.auraInitialized = false
        auraDirty[unit] = true
    end
    
	u.identificator = _identificator
	u.guid = guid -- [NEW] Cache the GUID for the tracker
	u.isMe = (UnitName(unit) == (playerName or UnitName('player')))
	u.isInCombat = UnitAffectingCombat(unit)
	u.threatStatus = UnitThreatSituation(unit)
	u.isTank = (UnitGroupRolesAssigned(unit) == 'TANK') or (GetPartyAssignment("MAINTANK", unit) == true)
    
    -- =======================================================
    -- [NEW] MISSING HP BUCKET LOGIC (Incoming Heals Supported)
    -- =======================================================
    local maxHP = UnitHealthMax(unit)
    local currentHP = UnitHealth(unit) or 0
    local incHeals = UnitGetIncomingHeals(unit) or 0 
    
    u.currLife = maxHP and maxHP > 0 and (currentHP / maxHP) or 0
    maxHP = maxHP or 1
    local missingHP = maxHP - (currentHP + incHeals)
    if missingHP < 0 then missingHP = 0 end
    
    u.maxHP = maxHP
    u.missingHP = missingHP
    -- Groups players by 500 HP tiers (0-499=0, 500-999=1, etc.)
    u.hpBucket = math.floor(missingHP / 500)
    return maxHP
end
jungle.cacheUnitData = cacheUnitData

local function clearCacheData(identificator)
  -- Remove stale units that were NOT updated in the current cycle
  for unitName, unitData in pairs(unitCache) do
    if unitData.identificator ~= identificator then
      unitCache[unitName] = nil
      auraDirty[unitName] = nil
      -- Note: This might clear globals aggressively, but preserving original logic behavior here
	  BEACONED_FRIEND = ''
	  TO_BEACON = nil
    end
  end
end

local cacheCounter = 0
local function cacheEveryUnit(_identificator, currentTime)
    cacheCounter = cacheCounter + 1
    if cacheCounter > 1000000 then cacheCounter = 1 end
    local identificator = cacheCounter
    local groupTokens
    local playerScanned = false
    local needsPlayerFallback = false
    local playerName = UnitName('player')
    local _, instanceType = IsInInstance()
    local now = currentTime or GetTime()
    local auditToken = GetNextAuraAuditToken()
    
	-- 1. Universal Token Scan
		for _, token in ipairs(UNIVERSAL_TOKENS) do
			if UnitExists(token) and not UnitIsDeadOrGhost(token) then
				-- FACT: This is the critical "Blacklist" gate
				-- Only cache if it's the player OR if the unit is NOT blacklisted
				if token == "player" or not jungle.isTargetInLos(token) then
					local maxHP = cacheUnitData(token, identificator, playerName)
					UpdateUnitAuras(token, maxHP, now, auditToken)
                    if token == "player" then
                        playerScanned = true
                    end
				end
			end
		end

    -- 2. Group Scanning Logic (Unchanged)
    if UnitExists('raid1') then
        groupTokens = RAID_TOKENS
    elseif UnitExists('party1') then
        groupTokens = PARTY_TOKENS
        needsPlayerFallback = true
    else
        needsPlayerFallback = true
    end
	
	if needsPlayerFallback and not playerScanned and not UnitIsDeadOrGhost('player') then
		local maxHP = cacheUnitData('player', identificator, playerName)
		UpdateUnitAuras('player', maxHP, now, auditToken)
	end
	
    if groupTokens then
        local groupCount = math.min(GetNumGroupMembers(), 25)
        for i = 1, groupCount do
			local u = groupTokens[i]
			if UnitExists(u)
			and not jungle.isTargetInLos(u)
			and (UnitName(u) == playerName or UnitInRange(u))
			and not UnitIsDeadOrGhost(u) then
				local maxHP = cacheUnitData(u, identificator, playerName)
				UpdateUnitAuras(u, maxHP, now, auditToken)
			end
         end
    end
	if instanceType == 'arena' then
		for j = 1, 5 do
            local arenaUnit = ARENA_TOKENS[j]
			if UnitExists(arenaUnit) and not jungle.isTargetInLos(arenaUnit) and not UnitIsDeadOrGhost(arenaUnit) then
				local maxHP = cacheUnitData(arenaUnit, identificator, playerName)
				UpdateUnitAuras(arenaUnit, maxHP, now, auditToken)
			end
		end
	end
    
    -- Now prune anyone who wasn't seen (old ID)
    clearCacheData(identificator)
end

local function updateUnitsData()
  local now = GetTime()
  RefreshAvailabilityContext(now)
  cacheEveryUnit(nil, now)
end
jungle.updateUnitsData = updateUnitsData

-- Function to get the number of auras for a specific unit
function GetUnitAuraCount(unit)
  if not unitCache[unit] then return 0 end
  return jungle.countEntries(unitCache[unit].auras.buffs.player)
end
jungle.GetUnitAuraCount = GetUnitAuraCount

local function getCacheFriend(_buff, _PLAYER)
	for friend, unitData in pairs(jungle.unitCache) do
		if _PLAYER then
			if jungle.unitCacheBuff(friend, _buff, '_PLAYER', nil, nil) then return friend end
		else
			if jungle.unitCacheBuff(friend, _buff, nil, nil) then return friend end
		end
	end
end
jungle.getCacheFriend = getCacheFriend

--------------------------------------------------------------------------------
-- TBC SPEC DETECTION (Robust Fix)
--------------------------------------------------------------------------------
GetTalentSpec = function()
    -- TBC/Classic: Count points in each tab. 1=Left, 2=Middle, 3=Right.
    -- FIX: Use multiple assignment to capturing ONLY the 3rd return value.
    -- This ensures 'p1' is just the points, not followed by the texture string.
    
    local _, _, p1 = GetTalentTabInfo(1)
    local _, _, p2 = GetTalentTabInfo(2)
    local _, _, p3 = GetTalentTabInfo(3)

    -- Force number or 0
    p1 = tonumber(p1) or 0
    p2 = tonumber(p2) or 0
    p3 = tonumber(p3) or 0
    
    local max = math.max(p1, p2, p3)
    
    if max == 0 then return 1 end -- No talents? Default to 1
    if max == p1 then return 1 end
    if max == p2 then return 2 end
    return 3
end

local function hasActiveEntries(tbl)
	for _, value in pairs(tbl) do
		if type(value) == 'table' and value.isActive then
			return true
		end
	end
	return false
end

local function isUnitAvailable(_unit)
	if not availabilityReady then
		RefreshAvailabilityContext()
	end

	if UnitExists(_unit) 
	and unitCache[_unit]
	and not hasActiveEntries(unitCache[_unit].auras.debuffs.unitIgnore)
	then
		local canAttack = UnitCanAttack('player', _unit)
		if canAttack and not jungle.isTargetInLos(_unit) then
			if cachedAvailabilityMode == "caster"
			and not hasActiveEntries(unitCache[_unit].auras.buffs.unitIgnoreIfYouCaster) then
				return true
			elseif cachedAvailabilityMode == "physical"
			and not hasActiveEntries(unitCache[_unit].auras.buffs.unitIgnoreIfYouPhys) then
				return true
			end
		end
		
		-- Logic for Friendly Targets (Heals)
		if not canAttack and not jungle.isTargetInLos(_unit) then
			return true
		end
	end
	return false
end
jungle.isUnitAvailable = isUnitAvailable

local function lowLifeFriendsCount(_life)
	local count = 0
	local life = _life or 1
	for _, unitData in pairs(unitCache) do
		if unitData.currLife <= life then
			count = count + 1
		end
	end
	return count
end
jungle.lowLifeFriendsCount = lowLifeFriendsCount

local function bloomFriendsCount(_life)
	local count = 0
	local life = _life or 1
	for _, unitData in pairs(unitCache) do
		if unitData.currLife <= life
		and unitData.auras.buffs.player['Lifebloom'] and unitData.auras.buffs.player['Lifebloom'].isActive then
			count = count + 1
		end
	end
	return count
end
jungle.bloomFriendsCount = bloomFriendsCount

local function unitCacheBuff(_unit, _aura, _PLAYER, _expired, _counts)
    -- 1. SAFETY GUARD:
    -- Returns false if unit is dead, out of LoS (missing from cache), or doesn't exist.
    if not _unit or not unitCache[_unit] or not unitCache[_unit].auras then 
        return false 
    end

    local _expired = _expired or 0
    local _counts = _counts or 0
    local buffs = unitCache[_unit].auras.buffs
    local buffList = _PLAYER and buffs.player or buffs.nonplayer
    
    local auraData = buffList[_aura]
    if not _PLAYER and (not auraData or not auraData.isActive) then
        auraData = buffs.player[_aura]
    end

    if auraData and auraData.isActive then
        -- FACT: expirationTime is 0 for buffs that don't expire (until used or die)
        local isInfinite = (auraData.expirationTime == 0)
        local remaining = isInfinite and 99999 or (auraData.expirationTime - GetTime())

        if remaining >= _expired and auraData.count >= _counts then
            return true
        end
    end
    return false
end
jungle.unitCacheBuff = unitCacheBuff

local function unitCacheDebuff(_friend, _aura, _expired, _counts)
    -- 1. SAFETY GUARD: Check if unit exists in our cache
    -- Prevents "attempt to index field '?' (a nil value)"
    if not _friend or not unitCache[_friend] or not unitCache[_friend].auras then 
        return false 
    end

    local _expired = _expired or 0
    local _counts = _counts or 0
    
    -- FACT: Check all debuff categories safely
    for _, cat in ipairs(DEBUFF_CATEGORIES) do
        local catTable = unitCache[_friend].auras.debuffs[cat]
        
        if catTable and catTable[_aura] then
            local d = catTable[_aura]
            
            if d and d.isActive then
                -- 2. INFINITE CHECK: expirationTime is 0 for permanent debuffs
                local isInfinite = (d.expirationTime == 0)
                local remaining = isInfinite and 99999 or (d.expirationTime - GetTime())

                if remaining >= _expired and d.count >= _counts then
                    return true
                end
            end
        end
    end
    return false
end
jungle.unitCacheDebuff = unitCacheDebuff

local function countEntries(table)
  local count = 0
  for k, v in pairs(table) do
    if type(v) == 'table' and v.isActive then count = count + 1 end
  end
  return count
end
jungle.countEntries = countEntries

function GetTokenByGUID(targetGUID)
    if not targetGUID then return nil end
    for token, data in pairs(jungle.unitCache) do
        if data.guid == targetGUID then
            return token
        end
    end
    return nil
end
jungle.GetTokenByGUID = GetTokenByGUID
