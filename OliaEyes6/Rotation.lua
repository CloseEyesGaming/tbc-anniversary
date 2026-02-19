local Jungle, jungle = ...

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
                -- We save the routine used to find this spell
                jungle.CurrentCast.routineFunc = rotations[i]
                -- Return {SpellName, Target, IndexPriority}
                return {tbl[j][2], _target, j}
            end
        end
    end
    return false
end

function Rotation:rotate(rotations, pix)
    local bestResult, bestUnit = nil, nil
    
    for _, rotation in ipairs(rotations) do
        for unit, unitData in pairs(jungle.unitCache) do
            -- Ensure unit is valid, friendly, and available
            if jungle.isUnitAvailable(unit) and UnitIsFriend('player', unit) then
                
                local res = self:condition({rotation}, pix, unit)
                
                if res then
                    local isBetter = false
                    
                    if not bestResult then
                        -- No previous candidate, take this one
                        isBetter = true
                    elseif res[3] < bestResult[3] then
                        -- STRICTLY Better Priority (Lower Index is better)
                        -- Example: Priority 1 (NS) beats Priority 8 (Rejuv)
                        isBetter = true
                    elseif res[3] == bestResult[3] then
                        -- TIE-BREAKER: SAME Priority
                        -- Compare Health: The more injured target wins
                        local currentHP = unitData.currLife or 1
                        local bestHP = jungle.unitCache[bestUnit].currLife or 1
                        
                        if currentHP < bestHP then
                            isBetter = true
                        end
                    end

                    if isBetter then
                        bestResult, bestUnit = res, unit
                        -- Tag the routine used for this decision
                        jungle.CurrentCast.routineFunc = rotation 
                    end
                end
            end
        end
    end

    if bestResult and bestUnit then
        -- LOCK THE SESSION for the Stopcasting monitor
        jungle.CurrentCast.targetGUID = UnitGUID(bestUnit)
        jungle.CurrentCast.spellName = bestResult[1]
        jungle.CurrentCast.priority = bestResult[3]
        jungle.CurrentCast.startTime = GetTime()

        return jungle.Cast:CastSpell(bestResult[1], bestUnit, pix)
    end
    return false
end

-- DpsRotate and ArenaRotate remain unchanged but included for completeness if needed
function Rotation:dpsRotate(rotations, pix)
    if UnitExists('target') and UnitCanAttack('player', 'target') then
        local res = self:condition(rotations, pix, 'target')
        if res then
            jungle.CurrentCast.targetGUID = UnitGUID('target')
            jungle.CurrentCast.spellName = res[1]
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
                return jungle.Cast:CastSpell(res[1], unit, pix)
            end
        end
    end
    return false
end

jungle.Rotation = Rotation