local Jungle, jungle = ...

-- [FIX] Ensure the table exists before any function tries to index it
jungle.CurrentCast = jungle.CurrentCast or {}

local Rotation = {}

local function ShouldIgnoreUnlearnedSpell(spell)
    local ignoredSpells = jungle.ignoreUnlearnedSpells
    return ignoredSpells and ignoredSpells[spell] and GetSpellBookItemInfo(spell) == nil
end

local function evaluateRoutine(rotation, target)
    local trace = jungle.RaidTrace
    local started = trace.sample and debugprofilestop()
    local tbl = rotation(target)
    if type(tbl) ~= "table" then
        if jungle.RoutineContext then jungle.RoutineContext.invalid = "Evaluator must return a row table" end
        return false, nil, nil, nil, true
    end
    if started then
        trace:Detail(trace.routineNames[rotation] or "unknownRoutine", debugprofilestop() - started)
        trace:Count("routineEvaluations")
        trace:Count("routineRowsReturned", #tbl)
    end
    for j = 1, #tbl do
        local row = tbl[j]
        if trace.sample then trace:Count("routineRowsInspected") end
        if type(row) == "table" and type(row[2]) == "string" and row[3]
        and (not jungle.RoutineAllows or jungle.RoutineAllows(row[2])) and not ShouldIgnoreUnlearnedSpell(row[2])
        and (target ~= nil or not jungle.actionHasRange[row[2]]) then
            local entry = jungle.RoutineContext
            if entry and entry.definition and not entry.definition.stepByID[row[2]] then
                entry.invalid = "Evaluator selected an undeclared action: " .. row[2]
                return false, nil, nil, nil, true
            end
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

local function GetUnitHealthPercent(unit)
    local maximum = UnitHealthMax(unit) or 0
    if maximum <= 0 then return 0 end
    return (UnitHealth(unit) or 0) / maximum
end

local function RecordRoutineContext()
    local entry = jungle.RoutineContext
    local cast = jungle.CurrentCast
    cast.configEntry = entry
    cast.configRevision = jungle.RoutineConfig and jungle.RoutineConfig.revision
    cast.engineThread = jungle.Engine and jungle.Engine.activeThread
end

local function TryDpsUnit(self, rotations, pix, unit)
    local found, spell, target, priority, metadata = self:condition(rotations, pix, unit)
    if found then
        RecordRoutineContext()
        local castTarget = target or unit or "player"
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
        local found, spell, priority, metadata, invalid = evaluateRoutine(rotations[i], _target)
        if invalid then return false end
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
                local found, spell, priority, metadata, invalid = evaluateRoutine(rotation, unit)
                if invalid then return false end
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
        RecordRoutineContext()
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

    -- The routine owns eligibility even when no enemy can be selected.
    return TryDpsUnit(self, rotations, pix, nil)
end

-- Opt-in hostile-unit layer for softenemy, target, and raid1target-raid13target.
-- Duplicate tokens are collapsed by GUID. Larger scores win among equal spell
-- priorities; health percentage is the default score.
function Rotation:enemyTargetRotate(rotations, pix, scoreUnit)
    local enemyFocus = jungle.EnemyFocus
    if not rotations or not enemyFocus or not enemyFocus:IsEnabled() then
        return false
    end

    local bestSpell, bestUnit, bestGUID, bestPriority, bestMetadata, bestRoutine
    local bestScore, bestIndex

    for _, rotation in ipairs(rotations) do
        local seenGUIDs = {}
        for index, unit in ipairs(enemyFocus:GetUnits()) do
            local guid = UnitGUID(unit)
            if guid and not seenGUIDs[guid]
            and enemyFocus:IsSupportedUnit(unit, guid)
            and IsAttackableLiveUnit(unit) then
                seenGUIDs[guid] = true
                local found, spell, priority, metadata, invalid = evaluateRoutine(rotation, unit)
                if invalid then return false end
                if found then
                    local score = scoreUnit and scoreUnit(unit, guid, spell, priority)
                        or GetUnitHealthPercent(unit)
                    score = tonumber(score) or 0

                    local isBetter = not bestUnit
                        or priority < bestPriority
                        or (priority == bestPriority and score > bestScore)
                        or (priority == bestPriority and score == bestScore and index < bestIndex)

                    if isBetter then
                        bestSpell = spell
                        bestUnit = unit
                        bestGUID = guid
                        bestPriority = priority
                        bestMetadata = metadata
                        bestRoutine = rotation
                        bestScore = score
                        bestIndex = index
                    end
                end
            end
        end
    end

    if not bestUnit or not bestGUID
    or not enemyFocus:IsSupportedUnit(bestUnit, bestGUID) then
        return false
    end

    jungle.CurrentCast.targetGUID = bestGUID
    jungle.CurrentCast.targetUnit = bestUnit
    jungle.CurrentCast.spellName = bestSpell
    jungle.CurrentCast.priority = bestPriority
    jungle.CurrentCast.startTime = GetTime()
    jungle.CurrentCast.stopcastFunc = bestMetadata
    jungle.CurrentCast.routineFunc = bestRoutine

    return jungle.Cast:CastSpell(bestSpell, bestUnit, pix)
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
