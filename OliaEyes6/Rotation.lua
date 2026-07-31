local Jungle, jungle = ...

-- [FIX] Ensure the table exists before any function tries to index it
jungle.CurrentCast = jungle.CurrentCast or {}

local Rotation = {}

local function ShouldIgnoreUnlearnedSpell(spell)
    local ignoredSpells = jungle.ignoreUnlearnedSpells
    return ignoredSpells and ignoredSpells[spell] and GetSpellBookItemInfo(spell) == nil
end

local function evaluateRoutine(rotation, target)
    local tbl = rotation(target)
    for j = 1, #tbl do
        local row = tbl[j]
        if row and row[3] and not ShouldIgnoreUnlearnedSpell(row[2]) then
            -- Preserve the existing write timing: every qualifying evaluation
            -- updates routineFunc, even if that candidate does not become best.
            jungle.CurrentCast.routineFunc = rotation
            return true, row[2], j, row[4]
        end
    end
    return false
end

local function IsAttackableLiveUnit(unit)
    return unit
        and UnitExists(unit)
        and UnitCanAttack('player', unit)
        and not UnitIsDeadOrGhost(unit)
end

local function TryDpsUnit(self, rotations, pix, unit)
    local found, spell, target, priority, metadata = self:condition(rotations, pix, unit)
    if found then
        local castTarget = target or unit
        jungle.CurrentCast.targetGUID = UnitGUID(castTarget)
        jungle.CurrentCast.spellName = spell
        -- [FIX] Map the metadata from the condition result
        jungle.CurrentCast.stopcastFunc = metadata
        return jungle.Cast:CastSpell(spell, castTarget, pix)
    end
    return false
end

function Rotation:new()
    local self = {}
    setmetatable(self, { __index = Rotation })
    return self
end

function Rotation:condition(rotations, pix, _target)
    for i = 1, #rotations do
        local found, spell, priority, metadata = evaluateRoutine(rotations[i], _target)
        if found then
            return true, spell, _target, priority, metadata
        end
    end
    return false
end

function Rotation:rotate(rotations, pix)
    local hasBest = false
    local bestSpell, bestUnit, bestPriority, bestMetadata
    
    for _, rotation in ipairs(rotations) do
        for unit, unitData in pairs(jungle.unitCache) do
            if jungle.isUnitAvailable(unit) and UnitIsFriend('player', unit) then
                local found, spell, priority, metadata = evaluateRoutine(rotation, unit)
                if found then
                    local isBetter = false
                    
                    if not hasBest then
                        isBetter = true
                    elseif priority < bestPriority then
                        isBetter = true -- STRICTLY Better Priority (Index rules all)
                    elseif priority == bestPriority then
                        
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
                        hasBest = true
                        bestSpell = spell
                        bestUnit = unit
                        bestPriority = priority
                        bestMetadata = metadata
                    end
                end
            end
        end
    end

    if hasBest and bestUnit then
        -- [NEW] Universal State Tracking
        jungle.CurrentCast.targetGUID = UnitGUID(bestUnit)
        jungle.CurrentCast.spellName = bestSpell
        jungle.CurrentCast.priority = bestPriority
        jungle.CurrentCast.startTime = GetTime()
        
        -- [NEW] Metadata Closure for Stopcast Engine
        jungle.CurrentCast.stopcastFunc = bestMetadata
        
        -- [LEGACY/COMPATIBILITY] Marker Detector
        if bestMetadata == "PROTECT_BLOOM" then
            jungle.protectedBlooms = jungle.protectedBlooms or {}
            jungle.protectedBlooms[jungle.CurrentCast.targetGUID] = true
        end

        return jungle.Cast:CastSpell(bestSpell, bestUnit, pix)
    end
    return false
end

function Rotation:dpsRotate(rotations, pix)
    if IsAttackableLiveUnit('target') then
        return TryDpsUnit(self, rotations, pix, 'target')
    end

    if IsAttackableLiveUnit('softenemy') then
        return TryDpsUnit(self, rotations, pix, 'softenemy')
    end

    return false
end

function Rotation:arenaRotate(rotations, pix)
    for unit, _ in pairs(jungle.unitCache) do
        if jungle.isUnitAvailable(unit) and UnitCanAttack('player', unit) then
            local found, spell, target, priority, metadata = self:condition(rotations, pix, unit)
            if found then
                jungle.CurrentCast.targetGUID = UnitGUID(unit)
                jungle.CurrentCast.spellName = spell
                -- [FIX] Map the metadata from the condition result
                jungle.CurrentCast.stopcastFunc = metadata
                return jungle.Cast:CastSpell(spell, unit, pix)
            end
        end
    end
    return false
end

jungle.Rotation = Rotation
