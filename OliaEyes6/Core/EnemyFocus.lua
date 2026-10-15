local Jungle, jungle = ...

local EnemyFocus = {}
jungle.EnemyFocus = EnemyFocus

local units = {"softenemy", "target"}
local supported = {
    softenemy = true,
    target = true,
}

for index = 1, 13 do
    local unit = "raid" .. index .. "target"
    units[#units + 1] = unit
    supported[unit] = true
end

function EnemyFocus:IsEnabled()
    return not IsInRaid() or GetNumGroupMembers() <= 25
end

function EnemyFocus:GetUnits()
    return units
end

function EnemyFocus:GetActionId(unit)
    if unit == "softenemy" or unit == "target" then
        return unit
    end

    local index = type(unit) == "string" and tonumber(unit:match("^raid(%d+)target$"))
    if not index or index < 1 or index > 13 then return nil end
    return "RaidTargetFocus" .. index
end

function EnemyFocus:IsSupportedUnit(unit, expectedGUID)
    if not self:IsEnabled() or not supported[unit] or not UnitExists(unit) then
        return false
    end

    local guid = UnitGUID(unit)
    if not guid then return false end
    return not expectedGUID or guid == expectedGUID
end

function EnemyFocus:PrintDiagnostics()
    local active, unique = 0, 0
    local seenGUIDs = {}

    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            active = active + 1
            local guid = UnitGUID(unit)
            if guid and not seenGUIDs[guid] then
                seenGUIDs[guid] = true
                unique = unique + 1
            end
        end
    end

    print(string.format(
        "|cff00ccff[Olia Enemy Focus]|r enabled=%s activeTokens=%d uniqueEnemies=%d",
        tostring(self:IsEnabled()),
        active,
        unique
    ))
end
