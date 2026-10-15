-- Real Warrior/core consumer tests; simulated events are not live combat proof.
local baselinePath = ...
local f = assert(io.open('tests/WarriorOptions.test.lua'))
local source = f:read('*a'); f:close()
local boundary = assert(source:find('local function Snapshot(rows)', 1, true))
local Context = assert(loadstring(source:sub(1, boundary - 1) .. '\nreturn Context'))()
local checks = 0
local function Check(value, why) assert(value, why); checks = checks + 1 end
local function Has(rows, spell)
    for _, row in ipairs(rows) do if row[2] == spell and row[3] then return true end end
    return false
end
local function Fixture(s, path)
    s.realSwingTimer = true
    s.rage = s.rage or 90
    s.thread = s.thread or 2
    local j, e, frames = Context(s, path)
    s.now = 100
    e.GetTime = function() return s.now end
    e.UnitAttackSpeed = function() return s.speed or 3.5 end
    e.GetSpellInfo = function(spell) return spell, nil, nil, s.castMS or 500 end
    e.GetNetStats = function() return 0, 0, 30, s.latency or 50 end
    j.GetGCDValues = function()
        return (s.gcd or 0) > 0 and s.now + s.gcd - 1.5 or 0, 1.5
    end
    e.GetSpellCooldown = function(spell)
        local remaining = s.cd and s.cd[spell] or 0
        if remaining > 0 then return s.now + remaining - 10, 10, 1 end
        if (s.gcd or 0) > 0 then return s.now + s.gcd - 1.5, 1.5, 1 end
        return 0, 0, 1
    end
    local costs = {Slam = 15, ['Mortal Strike'] = 30, Whirlwind = 25, Cleave = 20, ['Sweeping Strikes'] = 30}
    e.IsUsableSpell = function(spell)
        if s.blocked and s.blocked[spell] then return false, false end
        if spell == 'Whirlwind' and (s.stance or 3) ~= 3 then return false, false end
        local short = s.rage < (costs[spell] or 0)
        return not short, short
    end
    j.ReadyCastSpell = function(spell)
        return (s.gcd or 0) == 0 and (not s.cd or (s.cd[spell] or 0) == 0) and e.IsUsableSpell(spell)
    end
    local function Event(name, ...)
        for _, frame in ipairs(frames) do
            if frame.scripts.OnEvent then frame.scripts.OnEvent(frame, name, ...) end
        end
    end
    function s:swing(ago)
        self.now = 100 - (ago or 0.2)
        e.CombatLogGetCurrentEventInfo = function()
            return self.now, 'SWING_DAMAGE', false, 'player', nil, nil, nil, 'enemy1'
        end
        Event('COMBAT_LOG_EVENT_UNFILTERED')
        self.now = 100
    end
    function s:rows()
        return (self.thread == 3 and j.warriorThread3AoE or j.warriorArms)('target')
    end
    function s:haste(speed)
        self.speed = speed
        Event('UNIT_ATTACK_SPEED', 'player')
    end
    if not s.noSwing then s:swing(s.ago) end
    return s, j
end

-- An open Slam window must yield to ready/soon-ready core spells at every speed.
for _, speed in ipairs({3.5, 2.0, 1.2}) do
    for _, spell in ipairs({'Mortal Strike', 'Whirlwind'}) do
        for _, remaining in ipairs({0, 0.3, 1.5}) do
            local s = Fixture({speed = speed, cd = {['Mortal Strike'] = 7, Whirlwind = 7}})
            s.cd[spell] = remaining
            Check(not Has(s:rows(), 'Slam'), spell .. ' protected at ' .. remaining .. ' speed ' .. speed)
            if remaining == 0 then Check(Has(s:rows(), spell), spell .. ' remains eligible') end
        end
    end
    local s = Fixture({speed = speed, cd = {['Mortal Strike'] = 7, Whirlwind = 7}})
    Check(Has(s:rows(), 'Slam'), 'safe Slam retained at speed ' .. speed)
end

-- GCD, latency, cast duration and projected funding affect the actual decision.
local s = Fixture({cd = {['Mortal Strike'] = 2, Whirlwind = 7}, gcd = 0.6})
Check(not Has(s:rows(), 'Slam'), 'GCD wait would postpone MS')
s.cd['Mortal Strike'] = 7
Check(Has(s:rows(), 'Slam'), 'short GCD wait fits confirmed window')
s.gcd = 1
Check(not Has(s:rows(), 'Slam'), 'earliest start outside 1.15s window')
s.gcd, s.latency = 0, 1000
Check(not Has(s:rows(), 'Slam'), 'world latency pushes start outside window')
s.latency, s.castMS, s.cd['Mortal Strike'] = 50, 2000, 1.9
Check(not Has(s:rows(), 'Slam'), 'long cast completion can postpone MS past GCD')
s = Fixture({rage = 44, cd = {['Mortal Strike'] = 2, Whirlwind = 7}})
Check(not Has(s:rows(), 'Slam'), 'protect rage for MS before next reset swing')
s.rage = 45
Check(Has(s:rows(), 'Slam'), 'Slam plus MS exactly funded')
s.queued = true
Check(not Has(s:rows(), 'Slam'), 'queued Cleave cost included in funding')
s = Fixture({noSwing = true, cd = {['Mortal Strike'] = 7, Whirlwind = 7}})
Check(not Has(s:rows(), 'Slam'), 'unknown timer cannot schedule Slam')

-- Same live context: haste gain/loss must recompute predictions and retain priority.
s = Fixture({cd = {['Mortal Strike'] = 7, Whirlwind = 7}})
Check(Has(s:rows(), 'Slam'), 'initial safe window')
s:haste(1.2)
Check(Has(s:rows(), 'Slam'), 'haste itself does not disable safe Slam')
s.cd.Whirlwind = 0
Check(not Has(s:rows(), 'Slam') and Has(s:rows(), 'Whirlwind'), 'WW wins under haste')
s:haste(3.5)
Check(not Has(s:rows(), 'Slam'), 'haste expiry does not change ready-core precedence')

-- Thread 2 AoE: both buff states obey core timing, including SS activation.
for _, active in ipairs({false, true}) do
    s = Fixture({thread = 2, enemies = 3, sweepingActive = active,
        cd = {['Mortal Strike'] = 7, Whirlwind = 0, ['Sweeping Strikes'] = 7}})
    Check(not Has(s:rows(), 'Slam') and Has(s:rows(), 'Whirlwind'), 'T2 AoE WW precedence')
    s.cd.Whirlwind = 7
    Check(Has(s:rows(), 'Slam'), 'T2 AoE safe Slam remains usable')
    if not active then
        s.cd['Sweeping Strikes'] = 0
        Check(not Has(s:rows(), 'Slam'), 'Slam cannot delay T2 SS activation')
    end
end

-- Pooling: neither losing the 80-rage threshold nor moving the next swing is safe.
for _, enemies in ipairs({1, 3}) do
    for _, rage in ipairs({80, 90, 95, 100}) do
        s = Fixture({thread = 3, enemies = enemies, rage = rage,
            cd = {['Mortal Strike'] = 7, Whirlwind = 7}})
        Check(not Has(s:rows(), 'Slam'), 'pooling cannot delay activation at rage ' .. rage)
        Check(not Has(s:rows(), 'Mortal Strike'), 'pooling MS cannot deplete burst funding')
    end
end
s = Fixture({thread = 3, enemies = 3, rage = 80, ago = 2.9})
Check(Has(s:rows(), 'Sweeping Strikes'), 'funded pre-swing burst still activates')
s.rage = 79
Check(not Has(s:rows(), 'Sweeping Strikes'), 'activation funding threshold retained')
s.rage, s.queued = 90, true
Check(Has(s:rows(), 'Stopcasting'), 'pooling cancels a queue that would drop activation funding')
s.rage = 100
Check(not Has(s:rows(), 'Stopcasting') and Has(s:rows(), 'Sweeping Strikes'), 'fully funded queued burst proceeds')
s.queued, s.sweepingActive = false, true
s.cd = {['Mortal Strike'] = 7, Whirlwind = 7, ['Sweeping Strikes'] = 7}
Check(not Has(s:rows(), 'Sweeping Strikes'), 'active burst does not repeat activation')
s.sweepingActive = false
local empty = s:rows()
for _, row in ipairs(empty) do Check(not row[3], 'spent burst clears cached actions') end

-- Burst: WW wins; queue and filler spending must leave its rage available.
s = Fixture({thread = 3, enemies = 3, sweepingActive = true})
Check(not Has(s:rows(), 'Slam') and Has(s:rows(), 'Whirlwind'), 'T3 burst WW wins open Slam')
s.cd = {['Mortal Strike'] = 7, Whirlwind = 7}
Check(Has(s:rows(), 'Slam'), 'T3 burst allows non-conflicting Slam')
s.cd.Whirlwind = 0.5
Check(not Has(s:rows(), 'Slam'), 'T3 burst imminent WW protected')
Check(not Has(s:rows(), 'Demoralizing Shout'), 'maintenance cannot clip imminent WW')
s.cd['Mortal Strike'] = 0
Check(not Has(s:rows(), 'Mortal Strike'), 'MS filler cannot clip imminent WW')
s.cd.Whirlwind = 3
Check(Has(s:rows(), 'Mortal Strike'), 'MS filler allowed when it fits')
s:swing(2.9)
s.rage, s.cd.Whirlwind = 44, 0
Check(not Has(s:rows(), 'Cleave') and Has(s:rows(), 'Whirlwind'), 'queue cannot spend WW funding')
s.rage = 45
Check(Has(s:rows(), 'Cleave'), 'queue allowed with WW fully funded')
s.rage, s.queued = 30, true
Check(Has(s:rows(), 'Stopcasting'), 'underfunded existing queue is cancelled')
s.queued = false
Check(not Has(s:rows(), 'Stopcasting') and Has(s:rows(), 'Whirlwind'), 'cancel row clears next tick')

-- Invalid/moving contexts still reject Slam without stale cached eligibility.
for _, flag in ipairs({'moving', 'outOfRange', 'dead'}) do
    s = Fixture({thread = 2, cd = {['Mortal Strike'] = 7, Whirlwind = 7}})
    Check(Has(s:rows(), 'Slam'), 'valid initial context')
    s[flag] = true
    Check(not Has(s:rows(), 'Slam'), 'Slam rejected when ' .. flag)
end

-- Differential controls against the exact checkpoint for neighboring policies.
if baselinePath then
    local function Snapshot(rows)
        local result = {}
        for i, row in ipairs(rows) do
            if row[3] then result[#result + 1] = i .. ':' .. row[2] end
        end
        return table.concat(result, '|')
    end
    for _, thread in ipairs({1, 2, 3, 7}) do
        for _, pvp in ipairs({false, true}) do
            for _, active in ipairs({false, true}) do
                if pvp or thread == 1 or thread == 7 then
                    local args = {thread = thread, pvp = pvp, enemies = 3, sweepingActive = active}
                    local old = Fixture(args, baselinePath)
                    local new = Fixture({thread = thread, pvp = pvp, enemies = 3, sweepingActive = active})
                    Check(Snapshot(old:rows()) == Snapshot(new:rows()), 'neighbor unchanged: ' .. thread .. ' pvp=' .. tostring(pvp))
                end
            end
        end
    end
end
print('Warrior Slam timing: ' .. checks .. ' checks passed (mocked combat).')
