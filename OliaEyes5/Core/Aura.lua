local Jungle, jungle = ...

--------------------------------------------------------------------------------
-- AURA CACHING ENGINE (One-Pass)
--------------------------------------------------------------------------------
-- Cache Structure: jungle.auraCache[unitGUID] = { tick = 105, helpful = {Name={...}}, harmful = {...} }
jungle.auraCache = {}

local function ScanAuras(unit, filter)
    -- Safety Checks
    if not UnitExists(unit) then return nil end
    local unitGUID = UnitGUID(unit)
    if not unitGUID then return nil end

    -- Initialize or Retrieve Cache Entry
    if not jungle.auraCache[unitGUID] then
        jungle.auraCache[unitGUID] = { tick = -1, helpful = {}, harmful = {} }
    end

    local cache = jungle.auraCache[unitGUID]

    -- HIT: If scanned this tick, return cached data immediately
    if cache.tick == jungle.currentTick then
        return cache
    end

    -- MISS: Reset and Rescan (The only expensive part, runs once per unit per frame)
    cache.tick = jungle.currentTick
    wipe(cache.helpful)
    wipe(cache.harmful)

    -- Scan HELPFUL (Buffs)
    for i = 1, 40 do
        local name, icon, count, debuffType, duration, expirationTime, source, _, _, spellId = UnitAura(unit, i, "HELPFUL")
        if not name then break end
        cache.helpful[name] = { 
            count = count, 
            expiration = expirationTime, 
            source = source, 
            type = debuffType,
            id = spellId 
        }
    end

    -- Scan HARMFUL (Debuffs)
    for i = 1, 40 do
        local name, icon, count, debuffType, duration, expirationTime, source, _, _, spellId = UnitAura(unit, i, "HARMFUL")
        if not name then break end
        cache.harmful[name] = { 
            count = count, 
            expiration = expirationTime, 
            source = source, 
            type = debuffType, 
            id = spellId
        }
    end

    return cache
end

--------------------------------------------------------------------------------
-- API: BUFFS & DEBUFFS
--------------------------------------------------------------------------------

local function GetAuraData(unit, auraName, filter)
    local cache = ScanAuras(unit, filter)
    if not cache then return nil end
    local db = (filter == "HELPFUL") and cache.helpful or cache.harmful
    return db[auraName]
end

-- Checks for a HARMFUL aura (Debuff)
local function Debuff(_aura, _target, _sourceFilter, _remTime, _minStacks)
    local data = GetAuraData(_target, _aura, "HARMFUL")
    if not data then return false end

    if _sourceFilter and _sourceFilter ~= '' and data.source ~= "player" then return false end
    if _remTime and (data.expiration - GetTime()) <= _remTime then return false end
    if _minStacks and data.count < _minStacks then return false end

    return true
end
jungle.Debuff = Debuff

-- Checks for a HELPFUL aura (Buff) - Optimized for Lifebloom/Rejuv
local function Buff(_aura, _target, _sourceFilter, _remTime, _minStacks)
    local data = GetAuraData(_target, _aura, "HELPFUL")
    if not data then return false end

    if _sourceFilter and _sourceFilter ~= '' and data.source ~= "player" then return false end
    if _remTime and (data.expiration - GetTime()) <= _remTime then return false end
    if _minStacks and data.count < _minStacks then return false end

    return true
end
jungle.Buff = Buff

--------------------------------------------------------------------------------
-- API: DISPEL LOGIC (Resto Druid Optimized)
--------------------------------------------------------------------------------

local function CheckDispellableDebuffs(unit, debuffList, ...)
    local cache = ScanAuras(unit, "HARMFUL") 
    if not cache then return false end

    -- Create lookup for dispel types (e.g., {Magic=true, Curse=true, Poison=true})
    local dispelTypes = {}
    for _, dt in ipairs({...}) do dispelTypes[dt] = true end

    -- Iterate CACHED table (Fast)
    for name, data in pairs(cache.harmful) do
        -- 1. Match Dispel Type
        if data.type and dispelTypes[data.type] then
            -- 2. Match Priority List
            for _, priorityName in ipairs(debuffList) do
                if name == priorityName then
                    return true
                end
            end
        end
    end
    return false
end
jungle.CheckDispellableDebuffs = CheckDispellableDebuffs

--------------------------------------------------------------------------------
-- UTILITIES (Preserved & Cache-Enabled)
--------------------------------------------------------------------------------

local function isSlowed(_target)
    local d = jungle.slowDebuffs
    for _, aura in ipairs(d) do
        if Debuff(aura, _target) then return true end
    end
    return false
end
jungle.isSlowed = isSlowed

local function isSlowProtected(_target)
    local b = jungle.slowImmunityBuffs
    for _, aura in ipairs(b) do
        if Buff(aura, _target) then return true end
    end
    return false
end
jungle.isSlowProtected = isSlowProtected

local function hasAuraTypeCount(_target, _filter, _type)
    local cache = ScanAuras(_target, _filter)
    if not cache then return 0 end
    
    local db = (_filter == "HELPFUL") and cache.helpful or cache.harmful
    local count = 0
    for _, data in pairs(db) do
        if data.type == _type then count = count + 1 end
    end
    return count
end
jungle.hasAuraTypeCount = hasAuraTypeCount

-- Preserved logic for Cyclone, now uses cache
local function ReCastCyclone(target, bufferTime)
    local cycloneCastTime = 1.5 
    local totalBuffer = cycloneCastTime + (bufferTime or 0.2)
    
    local data = GetAuraData(target, "Cyclone", "HARMFUL")
    if data and data.source == "player" then
        local rem = data.expiration - GetTime()
        return (rem <= totalBuffer) -- True = Recast now
    end
    return true -- No cyclone found, cast it
end
jungle.ReCastCyclone = ReCastCyclone

-- Helpers
jungle.isHasOneOfDebuffs = function(t, list) for k in pairs(list) do if Debuff(k, t) then return true end end return false end
jungle.isHasOneOfBuffs   = function(t, list) for k in pairs(list) do if Buff(k, t)   then return true end end return false end

-- Legacy Shims (For backward compatibility if needed)
jungle.hasAuraType = function(_target, _filter, _type) return (hasAuraTypeCount(_target, _filter, _type) > 0) end