local Jungle, jungle = ...

--------------------------------------------------------------------------------
-- AURA CACHING ENGINE (One-Pass)
--------------------------------------------------------------------------------
-- Cache Structure:
-- jungle.auraCache[unitGUID] = {
--     helpful = { Name = {...} },
--     harmful = { Name = {...} },
--     helpfulState = { initialized, dirty, nextExpiry },
--     harmfulState = { initialized, dirty, nextExpiry },
-- }
jungle.auraCache = {}

local function NewFilterState()
    return {
        initialized = false,
        dirty = true,
        nextExpiry = nil,
    }
end

local function NewAuraCache()
    return {
        tick = -1, -- Retained for compatibility with existing cache inspection.
        helpful = {},
        harmful = {},
        helpfulState = NewFilterState(),
        harmfulState = NewFilterState(),
    }
end

local function InvalidateAuraCache(unit)
    if not unit then return end

    local unitGUID = UnitGUID(unit)
    local cache = unitGUID and jungle.auraCache[unitGUID]
    if cache then
        cache.helpfulState.dirty = true
        cache.harmfulState.dirty = true
    end
end
jungle.InvalidateAuraCache = InvalidateAuraCache

local function ScanAuras(unit, filter)
    -- Safety Checks
    if not UnitExists(unit) then return nil end
    local unitGUID = UnitGUID(unit)
    if not unitGUID then return nil end

    -- Initialize or Retrieve Cache Entry
    if not jungle.auraCache[unitGUID] then
        jungle.auraCache[unitGUID] = NewAuraCache()
    end

    local cache = jungle.auraCache[unitGUID]
    local normalizedFilter = (filter == "HELPFUL") and "HELPFUL" or "HARMFUL"
    local db = (normalizedFilter == "HELPFUL") and cache.helpful or cache.harmful
    local state = (normalizedFilter == "HELPFUL") and cache.helpfulState or cache.harmfulState
    local now = GetTime()
    local expired = state.nextExpiry and now >= state.nextExpiry

    -- Event-invalidated hit: unchanged finite and permanent auras remain reusable
    -- across frames. Expiry is still checked synchronously before each query.
    if state.initialized and not state.dirty and not expired then
        return cache
    end

    -- Refresh only the requested filter. UnitsData invalidates this cache from
    -- UNIT_AURA and from its staggered missed-event audit.
    cache.tick = jungle.currentTick
    wipe(db)
    local nextExpiry
    for i = 1, 40 do
        local name, icon, count, debuffType, duration, expirationTime, source, _, _, spellId = UnitAura(unit, i, normalizedFilter)
        if not name then break end
        db[name] = {
            count = count,
            expiration = expirationTime,
            source = source,
            type = debuffType,
            id = spellId
        }
        if expirationTime and expirationTime > 0
        and (not nextExpiry or expirationTime < nextExpiry) then
            nextExpiry = expirationTime
        end
    end

    state.initialized = true
    state.dirty = false
    state.nextExpiry = nextExpiry
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
jungle.IsTargetSlowed = isSlowed

local function isSlowProtected(_target)
    local b = jungle.slowImmunityBuffs
    for _, aura in ipairs(b) do
        if Buff(aura, _target) then return true end
    end
    return false
end
jungle.isSlowProtected = isSlowProtected
jungle.IsTargetSlowProtected = isSlowProtected

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

-- Normalized Dispel Helpers
function jungle.isExtremePoison(unit)
    -- Checks if unit has a Poison debuff that is also in the priority CC list
    return jungle.CheckDispellableDebuffs(unit, jungle.allCcList, 'Poison')
end

function jungle.isExtremeCursed(unit)
    -- Checks if unit has a Curse debuff that is also in the priority CC list
    return jungle.CheckDispellableDebuffs(unit, jungle.allCcList, 'Curse')
end
