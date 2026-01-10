local Jungle, jungle = ...

-- Utility function to get the minimum value in a table (unused in this class currently)
local function getMinValue(tbl)
    local key = next(tbl)
    local min = tbl[key]
    for k, v in pairs(tbl) do
        if tbl[k] < min then
            key, min = k, v
        end
    end
    return min
end

-- Rotation class definition
local Rotation = {}
function Rotation:new()
    local self = {}
    setmetatable(self, { __index = Rotation })

    -- print("Rotation instance created")
    return self
end

-- General condition evaluation
function Rotation:condition(rotations, pix, _target)
    local tbl = nil
    for i = 1, #rotations do
        tbl = rotations[i](_target)
        for j = 1, #tbl do
            if tbl[j][3] then
                return {tbl[j][2], _target, i * 100 + j} -- {spell, target, priority value}
            end
        end
    end
    return false
end

-- Main rotation logic
function Rotation:rotate(rotations, pix)
    LOS_CONTEXT_TARGET = 'focus'
    local _spell, _target, _previousTarget, cast
    local value = math.huge -- Lowest priority value
    local life = math.huge
    local previousLife = math.huge
	local pixel_reset = jungle.Pixel:new({0,0,0}, pix)
	pixel_reset:clear()

    -- Loop through each rotation step
    for _, rotation in ipairs(rotations) do
        -- print("Checking rotation:", tostring(rotation))

        -- Check each unit in the cache
        for unit, unitData in pairs(jungle.unitCache) do
            -- print("Checking unit:", unit)
            if jungle.isUnitAvailable(unit) and UnitIsFriend('player', unit) then
                local conditionResult = self:condition({rotation}, pix, unit)

                -- Process the condition
                if conditionResult then
                    -- print(string.format("Condition met for unit %s: Spell=%s Priority=%d", unit, conditionResult[1], conditionResult[3]))
                    if value > conditionResult[3] then
                        value = conditionResult[3]
                        _target = unit
                        _spell = conditionResult[1]
                        life = jungle.LifePercent(_target)
                    elseif value >= conditionResult[3] and life > jungle.LifePercent(unit) then
                        value = conditionResult[3]
                        _target = unit
                        _previousTarget = unit
                        _spell = conditionResult[1]
                        life = jungle.LifePercent(_target)
                        previousLife = jungle.LifePercent(_previousTarget)
                    elseif life < previousLife then
                        _previousTarget = unit
                    end
                else
                    -- print("Condition not met for unit:", unit)
                end
            end
        end

        -- Set up beacon target
        if UnitExists(_previousTarget) then
            TO_BEACON = _previousTarget
        end

        -- Cast the spell if a valid target and spell exist
        if UnitExists(_target) then
            LOS_CONTEXT_TARGET_NAME = UnitName(_target)
            cast = jungle.Cast:new(_spell, _target, pix)
            if jungle.isDebug then
                local framerate = GetFramerate()
                jungle.debugAction(1, 1, 1, 1, "Casting: ".._spell..' -> '.._target.."\n fps: "..floor(framerate))
            end
            return cast:cast()
        end
    end
    -- No valid action found
    return false
end

-- DPS rotation logic
function Rotation:dpsRotate(rotations, pix)
    LOS_CONTEXT_TARGET = 'target'
    local _spell, _target, cast
    local value = math.huge

    -- Check the target for DPS conditions
    if UnitExists('target') and UnitCanAttack('player', 'target') then
        local conditionResult = self:condition(rotations, pix, 'target')
        if conditionResult and value > conditionResult[3] then
            value = conditionResult[3]
            _target = 'target'
            _spell = conditionResult[1]
        end
    end

    -- Cast the spell if a valid target and spell exist
    if UnitExists(_target) then
        LOS_CONTEXT_TARGET_NAME = UnitName(_target)
        cast = jungle.Cast:new(_spell, _target, pix)
        if jungle.isDebug then
            local framerate = GetFramerate()
            jungle.debugAction(1, 1, 1, 1, "Casting: ".._spell..' -> '.._target.."\n fps: "..floor(framerate))
        end
        return cast:cast()
    end
    return false
end

-- Arena rotation logic
function Rotation:arenaRotate(rotations, pix)
    LOS_CONTEXT_TARGET = 'focus'
    local _spell, _target, cast

    -- Check each unit in the cache
    for unit, unitData in pairs(jungle.unitCache) do
        if jungle.isUnitAvailable(unit) and UnitCanAttack('player', unit) then
            local conditionResult = self:condition(rotations, pix, unit)
            if conditionResult then
                _target = unit
                _spell = conditionResult[1]
                break
            end
        end
    end

    -- Cast the spell if a valid target and spell exist
    if UnitExists(_target) then
        LOS_CONTEXT_TARGET_NAME = UnitName(_target)
        cast = jungle.Cast:new(_spell, _target, pix)
        if jungle.isDebug then
            local framerate = GetFramerate()
            jungle.debugAction(1, 1, 1, 1, "Casting: ".._spell..' -> '.._target.."\n fps: "..floor(framerate))
        end
        return cast:cast()
    end
    return false
end

-- Assign Rotation to the jungle namespace
jungle.Rotation = Rotation
