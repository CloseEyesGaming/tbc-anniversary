local Jungle, jungle = ...

-- [FIX] Ensure the table exists before any function tries to index it
jungle.CurrentCast = jungle.CurrentCast or {}

local Rotation = {}
function Rotation:new()
    local self = {}
    setmetatable(self, { __index = Rotation })
    return self
end

function Rotation:condition(rotations, pix, _target)
    for i = 1, #rotations do
        local tbl = rotations[i](_target)
        for j = 1, #tbl do
            if tbl[j] and tbl[j][3] then 
                -- Store the routine function for the stopcast engine's potential re-evaluation
                jungle.CurrentCast.routineFunc = rotations[i]
                
                -- [NEW] Return the 4th parameter (Metadata) if it exists in the rotation line
                return {tbl[j][2], _target, j, tbl[j][4]}
            end
        end
    end
    return false
end

function Rotation:rotate(rotations, pix)
    local bestResult, bestUnit = nil, nil
    
    for _, rotation in ipairs(rotations) do
        for unit, unitData in pairs(jungle.unitCache) do
            if jungle.isUnitAvailable(unit) and UnitIsFriend('player', unit) then
                
                local res = self:condition({rotation}, pix, unit)
                
                if res then
                    local isBetter = false
                    
                    if not bestResult then
                        isBetter = true
                    elseif res[3] < bestResult[3] then
                        isBetter = true -- STRICTLY Better Priority (Index rules all)
                    elseif res[3] == bestResult[3] then
                        
                        -- ===================================================
                        -- THE 2D TIE-BREAKER (BUCKETS -> HOT SCORE)
                        -- ===================================================
                        local currentBucket = unitData.hpBucket or 0
                        local bestBucket = jungle.unitCache[bestUnit].hpBucket or 0
                        
                        if currentBucket > bestBucket then
                            isBetter = true
                        elseif currentBucket == bestBucket then
                            local currentScore = unitData.hotScore or 0
                            local bestScore = jungle.unitCache[bestUnit].hotScore or 0
                            
                            if currentScore < bestScore then
                                isBetter = true
                            end
                        end
                        -- ===================================================
                    end

                    if isBetter then
                        bestResult, bestUnit = res, unit
                    end
                end
            end
        end
    end

    if bestResult and bestUnit then
        -- [NEW] Universal State Tracking
        jungle.CurrentCast.targetGUID = UnitGUID(bestUnit)
        jungle.CurrentCast.spellName = bestResult[1]
        jungle.CurrentCast.priority = bestResult[3]
        jungle.CurrentCast.startTime = GetTime()
        
        -- [NEW] Metadata Closure for Stopcast Engine
        jungle.CurrentCast.stopcastFunc = bestResult[4]
        
        -- [LEGACY/COMPATIBILITY] Marker Detector
        if bestResult[4] == "PROTECT_BLOOM" then
            jungle.protectedBlooms = jungle.protectedBlooms or {}
            jungle.protectedBlooms[jungle.CurrentCast.targetGUID] = true
        end

        return jungle.Cast:CastSpell(bestResult[1], bestUnit, pix)
    end
    return false
end

function Rotation:dpsRotate(rotations, pix)
    if UnitExists('target') and UnitCanAttack('player', 'target') then
        local res = self:condition(rotations, pix, 'target')
        if res then
            jungle.CurrentCast.targetGUID = UnitGUID('target')
            jungle.CurrentCast.spellName = res[1]
            -- [FIX] Map the metadata from the condition result
            jungle.CurrentCast.stopcastFunc = res[4]
            return jungle.Cast:CastSpell(res[1], 'target', pix)
        end
    end
    return false
end

function Rotation:arenaRotate(rotations, pix)
    for unit, _ in pairs(jungle.unitCache) do
        if jungle.isUnitAvailable(unit) and UnitCanAttack('player', unit) then
            local res = self:condition(rotations, pix, unit)
            if res then
                jungle.CurrentCast.targetGUID = UnitGUID(unit)
                jungle.CurrentCast.spellName = res[1]
                -- [FIX] Map the metadata from the condition result
                jungle.CurrentCast.stopcastFunc = res[4]
                return jungle.Cast:CastSpell(res[1], unit, pix)
            end
        end
    end
    return false
end

jungle.Rotation = Rotation