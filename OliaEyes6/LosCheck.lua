local Jungle, jungle = ...

-- Singleton Initialization
jungle.Los = {}
local Los = jungle.Los

-- Data Storage
local losCache = {}    -- Blocked by LoS
local behindCache = {} -- Target is behind player (You must be behind target)
local frontCache = {}  -- Player is in front (You must be in front)

-- Configuration
local CACHE_DURATION = 1 

-- Event Frame
local frame = CreateFrame("Frame")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("UI_ERROR_MESSAGE")

-- Helper: BlockGUID
local function BlockGUID(cache, guid)
    if guid and #guid > 0 then
        cache[guid] = GetTime() + CACHE_DURATION
    end
end

-- Helper: Get Context GUID
-- local function GetContextGUID()
    -- if LOS_CONTEXT_TARGET and UnitExists(LOS_CONTEXT_TARGET) then
        -- return UnitGUID(LOS_CONTEXT_TARGET)
    -- end
    -- return UnitGUID('target')
-- end
-- Helper: Get Context GUID
local function GetContextGUID()
    -- 1. PRIORITY: The unit the Engine DECIDED to cast on.
    -- We check if the cast attempt was recent (within last 1.0 second) to ensure relevance.
    if jungle.CurrentCast and jungle.CurrentCast.targetGUID then
        local lastCastTime = jungle.CurrentCast.startTime or 0
        if (GetTime() - lastCastTime) < 1.0 then
            return jungle.CurrentCast.targetGUID
        end
    end

    -- 2. Fallback: Manual Context override
    if LOS_CONTEXT_TARGET and UnitExists(LOS_CONTEXT_TARGET) then
        return UnitGUID(LOS_CONTEXT_TARGET)
    end
    
    -- 3. Fallback: Standard Units
    if UnitExists('target') then return UnitGUID('target') end
    if UnitExists('focus') then return UnitGUID('focus') end
    if UnitExists('mouseover') then return UnitGUID('mouseover') end

    return nil
end

-- Helper: String Matcher
local function IsMatch(text, pattern)
    if not text or type(text) ~= "string" then return false end
    if not pattern then return false end
    return string.find(text, pattern, 1, true)
end

-- frame:SetScript("OnEvent", function(self, event, ...)
    
    -- -- [[ CASE 1: Server-Side Failures (LoS) ]]
    -- if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        -- local _, subevent, _, sourceGUID, _, _, _, destGUID, _, _, _, _, _, _, failedType = CombatLogGetCurrentEventInfo()

        -- if subevent == "SPELL_CAST_FAILED" and sourceGUID == UnitGUID("player") then
            -- if not destGUID or #destGUID == 0 then destGUID = GetContextGUID() end

            -- if failedType == SPELL_FAILED_LINE_OF_SIGHT then
                -- -- print('CLEU: LINE_OF_SIGHT', destGUID)
                -- BlockGUID(losCache, destGUID)
            -- elseif failedType == SPELL_FAILED_UNIT_NOT_INFRONT then
                -- BlockGUID(behindCache, destGUID)
            -- end
        -- end

    -- -- [[ CASE 2: UI Error Messages (Positioning) ]]
    -- elseif event == "UI_ERROR_MESSAGE" then
        -- local messageType, msg = ...
        
        -- -- Ensure msg is a string (sometimes it's in arg1, mostly arg2)
        -- if type(messageType) == "string" then msg = messageType end

        -- if msg and type(msg) == "string" then
            
            -- -- ERROR: "You must be behind your target." (For Shred/Backstab)
            -- -- We check the Literal string found in your logs + the Global constant just in case.
            -- if IsMatch(msg, "You must be behind your target") or IsMatch(msg, SPELL_FAILED_UNIT_NOT_BEHIND) then
                -- local destGUID = GetContextGUID()
                -- print('POSITION: UNIT_NOT_BEHIND', destGUID) 
                -- BlockGUID(frontCache, destGUID) -- Block 'front' because we need to be behind
            
            -- -- ERROR: "Target needs to be in front of you." (For Gouge/Normal hits)
            -- elseif IsMatch(msg, "Target needs to be in front of you") or IsMatch(msg, SPELL_FAILED_UNIT_NOT_INFRONT) then
                 -- local destGUID = GetContextGUID()
                 -- print('POSITION: UNIT_NOT_INFRONT', destGUID)
                 -- BlockGUID(behindCache, destGUID) -- Block 'behind' because we need to be in front
            -- end
        -- end
    -- end
-- end)
frame:SetScript("OnEvent", function(self, event, ...)
    
    -- [[ CASE 1: Server-Side Failures (CLEU) ]]
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subevent, _, sourceGUID, _, _, _, destGUID, _, _, _, _, _, _, failedType = CombatLogGetCurrentEventInfo()

        if subevent == "SPELL_CAST_FAILED" and sourceGUID == UnitGUID("player") then
            if not destGUID or #destGUID == 0 then destGUID = GetContextGUID() end

            -- Note: LoS check removed from here; now handled in UI_ERROR_MESSAGE.
            if failedType == SPELL_FAILED_UNIT_NOT_INFRONT then
                BlockGUID(behindCache, destGUID)
            end
        end

    -- [[ CASE 2: UI Error Messages (Positioning & LoS) ]]
    elseif event == "UI_ERROR_MESSAGE" then
        local messageType, msg = ...
        
        -- Ensure msg is a string (sometimes it's in arg1, mostly arg2)
        if type(messageType) == "string" then msg = messageType end

        if msg and type(msg) == "string" then
            
            -- [[ LoS Check (Refactored) ]]
            if IsMatch(msg, "Target not in line of sight") or IsMatch(msg, SPELL_FAILED_LINE_OF_SIGHT) then
                local destGUID = GetContextGUID()
                print('UI_ERROR: LINE_OF_SIGHT', destGUID)
               BlockGUID(losCache, destGUID)

            -- [[ Position: Not Behind ]]
            elseif IsMatch(msg, "You must be behind your target") or IsMatch(msg, SPELL_FAILED_UNIT_NOT_BEHIND) then
                local destGUID = GetContextGUID()
                print('POSITION: UNIT_NOT_BEHIND', destGUID) 
                BlockGUID(frontCache, destGUID)
            
            -- [[ Position: Not In Front ]]
            elseif IsMatch(msg, "Target needs to be in front of you") or IsMatch(msg, SPELL_FAILED_UNIT_NOT_INFRONT) then
                 local destGUID = GetContextGUID()
                 print('POSITION: UNIT_NOT_INFRONT', destGUID)
                 BlockGUID(behindCache, destGUID)
            end
        end
    end
end)

-- =========================================================
-- Public API
-- =========================================================

function Los:IsUnitBlocked(unit)
    if not UnitExists(unit) then return false end
    local guid = UnitGUID(unit)
    local t = losCache[guid]
    return (t and t > GetTime()) or false
end

-- Is the unit physically behind me? (I need to turn around)
function Los:IsUnitBehindMe(unit)
    if not UnitExists(unit) then return false end
    local guid = UnitGUID(unit)
    local t = behindCache[guid]
    return (t and t > GetTime()) or false
end

-- Am I failing to be behind the unit? (I need to move behind them)
function Los:ImNotBehindUnit(unit)
    if not UnitExists(unit) then return false end
    local guid = UnitGUID(unit)
    local t = frontCache[guid]
    return (t and t > GetTime()) or false
end

function Los:OnUpdate()
    local now = GetTime()
    local function Clean(cache)
        for guid, expiry in pairs(cache) do
            if now >= expiry then
                cache[guid] = nil
            end
        end
    end
    Clean(losCache)
    Clean(behindCache)
    Clean(frontCache)
end

-- =========================================================
-- Global Exports
-- =========================================================

jungle.isTargetInLos = function(unit) return Los:IsUnitBlocked(unit) end
jungle.UnitIsBehindMe = function(unit) return Los:IsUnitBehindMe(unit) end
jungle.ImNotBehindUnit = function(unit) return Los:ImNotBehindUnit(unit) end