-- Standalone Lua 5.1 tests of real swap decisions with mocked game state.
-- Not loaded by the addon TOC; does not validate in-game equipment execution.
local checks = 0
local function Check(value, why) assert(value, why); checks = checks + 1 end
local function Factory(path, boundary, name)
    local f = assert(io.open(path)); local source = f:read('*a'); f:close()
    local stop = assert(source:find(boundary, 1, true))
    return assert(loadstring(source:sub(1, stop - 1) .. '\nreturn ' .. name))()
end
local Warrior = Factory('tests/WarriorOptions.test.lua', 'local function Snapshot(rows)', 'Context')
local Druid = Factory('tests/OptionalEnemy.test.lua', 'local druidSelf=', 'Druid')
local function Eligible(rows, action)
    for _, row in ipairs(rows) do if row[2] == action and row[3] then return true end end
    return false
end
local function InstallGCD(j, env, s)
    s.now, s.start, s.duration, s.reads = 100, 99, 1.5, 0
    env.GetTime = function() return s.now end
    env.UnitAffectingCombat = function(unit)
        Check(unit == 'player', 'swap gate uses player combat state')
        return s.combat
    end
    local original = env.GetSpellCooldown
    env.GetSpellCooldown = function(spell)
        if spell == 61304 then
            s.reads = s.reads + 1
            return s.start, s.duration
        end
        if original then return original(spell) end
        return 0, 0
    end
    local core = { offsets = { GCD_SPELL_ID = 61304 }, RaidTrace = { sample = false } }
    setfenv(assert(loadfile('Core/Spell.lua')), env)('OliaEyes6', core)
    j.CanSwapWeapons, j.GetGCDValues = core.CanSwapWeapons, core.GetGCDValues
end
local function SwapMatrix(j, s, rows, action, label)
    s.combat = false
    local before = s.reads
    Check(Eligible(rows(), action), label .. ' swaps out of combat during GCD')
    -- Only count direct helper reads: routines may independently inspect spell GCD.
    before = s.reads
    Check(j.CanSwapWeapons() and s.reads == before, label .. ' bypasses GCD read outside combat')
    s.combat = true
    Check(not Eligible(rows(), action), label .. ' blocks combat swap with 0.5 seconds left')
    s.now = 100.499
    Check(not Eligible(rows(), action), label .. ' blocks final millisecond of GCD')
    s.now = 100.5
    Check(Eligible(rows(), action), label .. ' allows exact GCD expiry')
    s.start = 0; s.duration = 0
    Check(Eligible(rows(), action), label .. ' allows no active GCD')
    s.start = s.now; s.duration = 1.5
    Check(not Eligible(rows(), action), label .. ' clears cached eligibility on next GCD')
    s.combat = false
    Check(Eligible(rows(), action), label .. ' immediately allows swap after leaving combat')
end

for _, case in ipairs({
    {'warriorTank', 'EquipShield'}, {'warriorFury', 'EquipDW'}, {'warriorArms', 'Equip2H'},
}) do
    local s = { fury = case[1] == 'warriorFury', rage = 80 }
    local j, env = Warrior(s)
    InstallGCD(j, env, s)
    env.IsEquippedItemType = function() return false end
    env.UnitAttackSpeed = function() return 3.5, nil end
    env.GetInventoryItemLink = function() return nil end
    SwapMatrix(j, s, function() return j[case[1]](nil) end, case[2], case[1])
end

for _, enemies in ipairs({1, 3}) do
    local s = { fury = true, enemies = enemies, rage = 80 }
    local j, env = Warrior(s)
    InstallGCD(j, env, s)
    local action = enemies == 1 and 'EquipFastOffHand' or 'EquipSlowOffHand'
    j.GetBestDWWeapons = function() return 'main', 'fast', 'slow' end
    j.GetItemSpeed = function(item) return item == 'fast' and 1.5 or 2.5 end
    j.IsWeaponAvailable = function() return true end
    j.Hotkeys = { EquipMacroTargets = { EquipFastOffHand = 'fast', EquipSlowOffHand = 'slow' } }
    j.SwingTimer.GetOffhandTimeSinceLastSwing = function() return s.swingElapsed or 0.1 end
    j.SwingTimer.GetTimeSinceLastSwing = function() return s.swingElapsed or 0.1 end
    SwapMatrix(j, s, function() return j.warriorFury('target') end, action, action)
    s.combat = true; s.start = 0; s.duration = 0; s.swingElapsed = 0.4
    Check(not Eligible(j.warriorFury('target'), action), 'combat swap still requires recent swing')
    s.combat = false
    Check(Eligible(j.warriorFury('target'), action), 'out-of-combat swap bypasses swing window')
    j.Hotkeys.EquipMacroTargets[action] = 'wrong weapon'
    Check(not Eligible(j.warriorFury('target'), action), 'macro target mismatch still blocks swap')
end

local function DruidEquipment(s)
    local j, env = Druid(s)
    InstallGCD(j, env, s)
    j.Hotkeys = { EquipMacroTargets = {
        Equip2H = { mainHand = 'battery' },
        EquipDW = { mainHand = 'velocity', offHand = 'focus' },
        EquipShield = { mainHand = 'healing', offHand = 'focus' },
    } }
    env.GetInventoryItemLink = function(_, slot)
        return s.equipment and s.equipment[slot] and ('[' .. s.equipment[slot] .. ']') or nil
    end
    env.GetItemInfo = function(link) return link:match('%[(.-)%]') end
    if s.battery then
        env.UnitPower = function(_, kind) return kind == 0 and 40 or 80 end
    end
    return j, env
end
for _, case in ipairs({
    {form = 0, action = 'EquipShield', routine = 'druidHealingWeaponSet'},
    {form = 1, action = 'Equip2H', routine = 'druidDpsIdleSet'},
    {form = 3, action = 'Equip2H', routine = 'druidDpsIdleSet'},
    {form = 5, action = 'EquipDW', routine = 'druidDpsIdleSet'},
    {form = 1, action = 'Equip2H', routine = 'dpsSet'},
    {form = 3, action = 'Equip2H', routine = 'dpsSet'},
    {form = 5, action = 'EquipDW', routine = 'dpsSet'},
    {form = 5, action = 'Equip2H', routine = 'dpsSet', battery = true, hasEnemy = true},
}) do
    local j = DruidEquipment(case)
    local unit = case.routine == 'dpsSet' and (case.hasEnemy and 'target' or nil) or 'player'
    SwapMatrix(j, case, function() return j[case.routine](unit) end, case.action, case.routine .. '/' .. case.form)
end

-- GCD waiting must not start/exhaust the Druid retry budget or revive a timeout.
local s = { combat = true }
local j = DruidEquipment(s)
local function Healing() return Eligible(j.druidHealingWeaponSet('player'), 'EquipShield') end
Check(not Healing(), 'initial GCD blocks healing equipment')
s.now = 101; s.start = 100; Check(not Healing(), 'still waiting; no attempt started')
s.now = 101.5; Check(Healing(), 'attempt begins when GCD expires')
s.now = 101.7; s.start = 101.7; Check(not Healing(), 'new GCD pauses existing attempt')
s.now = 103; Check(not Healing(), 'GCD pause exceeds remaining retry budget')
s.now = 103.2; Check(Healing(), 'attempt resumes after full GCD without timing out')
s.now = 104.4; Check(Healing(), 'remaining attempt budget is retained')
s.now = 104.6; Check(not Healing(), 'failed swap still times out')
s.start = 104.6; Check(not Healing(), 'timed-out swap stays blocked during GCD')
s.now = 106.1; Check(not Healing(), 'later GCD does not revive timed-out attempt')
j.ResetDruidEquipAttemptState(); Check(Healing(), 'explicit attempt reset still works')
s.equipment = {[16] = 'healing', [17] = 'focus'}
Check(not Healing(), 'matching equipment clears the request')
s.equipment = nil; Check(Healing(), 'equipment mismatch starts a fresh request')

print('WeaponSwapGCD: ' .. checks .. ' checks passed')
