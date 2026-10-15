-- Lua 5.1 event-sequence tests of the real internal tracker and Arms consumers.
-- Mocked APIs validate state transitions, not live server timing.
local checks = 0
local function Check(value, why) assert(value, why); checks = checks + 1 end
local function Near(actual, expected, why)
    Check(math.abs(actual - expected) < 0.00001, why .. ': ' .. tostring(actual) .. ' ~= ' .. tostring(expected))
end

local function Fixture()
    local s = {now = 100, mh = 3.6, oh = 2.6, swings = 0, resets = 0, slams = 0, class = 'WARRIOR', form = 3}
    local e = setmetatable({}, {__index = _G})
    e._G = e
    local frame
    e.CreateFrame = function()
        frame = {events = {}}
        function frame:RegisterEvent(name) self.events[name] = true end
        function frame:SetScript(_, fn) self.handler = fn end
        return frame
    end
    e.GetTime = function() return s.now end
    e.UnitGUID = function() return 'player' end
    e.UnitAttackSpeed = function() return s.mh, s.oh end
    e.UnitClass = function() return s.class, s.class end
    e.GetShapeshiftForm = function() return s.form end
    e.GetSpellInfo = function(id) return id == 25242 and 'Localized Slam' or id, nil, nil, 500 end
    e.UnitCastingInfo = function()
        if s.casting then return 'Localized Slam', nil, nil, (s.castStart or s.now) * 1000, s.castEnd * 1000 end
    end
    -- Accessing either external integration surface would fail the tests.
    e.C_AddOns = setmetatable({}, {__index = function() error('external addon dependency') end})
    e.SuperSwingTimerMHBar = setmetatable({}, {__index = function() error('external bar read') end})
    e.CombatLogGetCurrentEventInfo = function() return unpack(s.payload, 1, 24) end
    local j = {RaidTrace = {WatchEventFrame = function() end}}
    setfenv(assert(loadfile('Core/SwingTimer.lua')), e)('OliaEyes6', j)
    local t = j.SwingTimer
    t:RegisterMainhandSwingCallback(function(now, name, result, guid)
        s.swings = s.swings + 1
        s.lastName, s.lastResult, s.lastGUID = name, result, guid
    end)
    t:RegisterResetCallback(function() s.resets = s.resets + 1 end)
    t:RegisterSlamCompletionCallback(function() s.slams = s.slams + 1 end)
    function s:event(name, ...)
        Check(frame.events[name], 'event is registered: ' .. name)
        frame.handler(frame, name, ...)
    end
    function s:log(kind, values)
        self.payload = {[1] = 999000 + self.now, [2] = kind, [4] = 'player', [8] = 'enemy'}
        for k, v in pairs(values or {}) do self.payload[k] = v end
        self:event('COMBAT_LOG_EVENT_UNFILTERED')
    end
    return s, t
end

local s, t = Fixture()
Check(t:IsTimerStale() and not t:HasConfirmedMainhandSwing(), 'login is unknown, not an imminent swing')
Near(t:GetTimeRemaining(), 0, 'unknown preserves numeric API')
s:log('SWING_DAMAGE')
Near(t:GetTimeRemaining(), 3.6, 'MH hit starts full cycle in local clock')
Check(t:GetMainhandTimerSource() == 'internal', 'always internal')
s.now = 100.2
s:log('SWING_MISSED', {[12] = 'DODGE', [13] = true})
Near(t:GetTimeRemaining(), 3.4, 'OH miss does not reset MH')
Near(t:GetOffhandTimeRemaining(), 2.6, 'OH miss resets OH')
Check(s.swings == 1, 'OH never opens Arms window')
s.now = 100.3
s:log('SWING_MISSED', {[12] = 'PARRY', [13] = false})
Check(s.swings == 2 and s.lastResult == 'parry', 'outgoing miss confirms MH swing')
Near(t:GetTimeRemaining(), 3.6, 'outgoing parried attack resets, not parry haste')

-- Successive speed changes: 50% remaining -> haste -> partial progress -> expiry.
s, t = Fixture()
s:log('SWING_DAMAGE')
s:log('SWING_DAMAGE', {[21] = true})
s.now, s.mh, s.oh = 101.8, 1.8, 1.3
s:event('UNIT_ATTACK_SPEED', 'player')
Near(t:GetTimeRemaining(), 0.9, 'haste preserves MH progress')
Near(t:GetOffhandTimeRemaining(), 0.4, 'haste preserves independent OH progress')
Near(t:GetTimeSinceLastSwing(), 1.8, 'haste does not rewrite observed hit timestamp')
s.now, s.mh = 102.1, 3.6
s:event('UNIT_ATTACK_SPEED', 'player')
Near(t:GetTimeRemaining(), 1.2, 'haste loss preserves progress')
s.now, s.mh = 102.4, 1.8
Near(t:GetTimeRemaining(), 0.45, 'read fallback catches missed speed event')
s.now, s.mh = 105, 3.6
Near(t:GetTimeRemaining(), 0, 'speed loss cannot resurrect expired swing')
Check(not t:IsMainhandTimingReliable(), 'overdue timer is stale')
Check(s.swings == 1, 'predictions do not invent confirmed swings')

-- Late Slam: swing at 100, start at 101, finish at 101.5 => next at 105.1.
s, t = Fixture()
s:log('SWING_DAMAGE')
s.now, s.casting, s.castStart, s.castEnd = 101, true, 101, 101.5
s:event('UNIT_SPELLCAST_START', 'player', 'cast1', 25242)
s:log('SPELL_CAST_START', {[12] = 25242, [13] = 'Localized Slam'})
Near(t:GetSlamTimeRemaining(), 4.1, 'predict completion plus full weapon interval')
Check(not t:IsMainhandTimingReliable(), 'cast prediction is not a swing confirmation')
s.now, s.castEnd = 101.2, 101.8
s:event('UNIT_SPELLCAST_DELAYED', 'player', 'cast1', 25242)
Near(t:GetSlamTimeRemaining(), 4.2, 'pushback uses live cast end')
s.now, s.casting = 101.8, false
s:event('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast1', 25242)
Near(t:GetSlamTimeRemaining(), 3.6, 'successful Slam resets full interval')
s.now = 101.9
s:log('SPELL_CAST_SUCCESS', {[12] = 25242})
s:log('SPELL_MISSED', {[12] = 25242, [15] = 'MISS'})
Near(t:GetSlamTimeRemaining(), 3.5, 'duplicate success and miss do not reset twice')
Check(s.swings == 1 and t:GetLastConfirmedMainhandSwingTime() == 100, 'Slam never opens new afterswing window')

-- Haste during Slam affects the new weapon cycle, not the cast duration.
s, t = Fixture()
s:log('SWING_DAMAGE')
s.now, s.casting, s.castEnd = 100.1, true, 100.6
s:event('UNIT_SPELLCAST_START', 'player', 'cast2', 25242)
s.now, s.mh = 100.3, 1.8
s:event('UNIT_ATTACK_SPEED', 'player')
Near(t:GetSlamTimeRemaining(), 2.1, 'haste during cast')
s.now, s.casting = 100.6, false
s:event('UNIT_SPELLCAST_STOP', 'player', 'cast2', 25242)
s:event('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast2', 25242)
Near(t:GetTimeRemaining(), 1.8, 'STOP before SUCCESS still resets correctly')
s.now = 100.7
s:log('SPELL_CAST_SUCCESS', {[12] = 25242})
Near(t:GetTimeRemaining(), 1.7, 'duplicate after STOP/SUCCESS is ignored')

for _, ending in ipairs({'UNIT_SPELLCAST_FAILED', 'UNIT_SPELLCAST_INTERRUPTED', 'UNIT_SPELLCAST_STOP'}) do
    s, t = Fixture()
    s:log('SWING_DAMAGE')
    s.now, s.casting, s.castEnd = 100.1, true, 100.6
    s:event('UNIT_SPELLCAST_START', 'player', 'cast3', 25242)
    s:event(ending, 'player', 'different-cast', 25242)
    Near(t:GetTimeRemaining(), 4.1, 'other cast failure must not cancel active Slam')
    s.now, s.casting = 100.2, false
    s:event(ending, 'player', 'cast3', 25242)
    Check(t:IsMainhandTimingReliable(), 'early interruption preserves known unexpired cycle')
    Near(t:GetTimeRemaining(), 3.4, 'failed Slam never resets or adds the cast duration')
    s.now = 101
    s:log('SWING_DAMAGE')
    Near(t:GetTimeRemaining(), 3.6, 'resync after interrupted cast')
end
s, t = Fixture()
s:log('SWING_DAMAGE')
s.now, s.casting, s.castEnd = 103.5, true, 104
s:event('UNIT_SPELLCAST_START', 'player', 'late', 25242)
s.now, s.casting = 103.8, false
s:event('UNIT_SPELLCAST_INTERRUPTED', 'player', 'late', 25242)
Check(not t:IsMainhandTimingReliable(), 'interruption across swing deadline waits for confirmation')
Near(t:GetTimeRemaining(), 0, 'no invented deadline after swing blocked by cast')
s, t = Fixture()
s.casting, s.castEnd = true, 100.5
s:event('UNIT_SPELLCAST_START', 'player', 'lost', 25242)
s.now, s.casting = 102, false
Near(t:GetTimeRemaining(), 0, 'lost completion event cannot leave permanent casting state')
Check(t:IsTimerStale(), 'lost completion is unknown')
s:log('SPELL_CAST_SUCCESS', {[12] = 25242})
Near(t:GetTimeRemaining(), 3.6, 'CLEU-only success recovery without damage record')

-- Queuing is not execution; several Cleave targets represent a single swing.
s, t = Fixture()
s:log('SWING_DAMAGE')
s.now = 101
s:event('UNIT_SPELLCAST_SUCCEEDED', 'player', 'queued', 25231)
Near(t:GetTimeRemaining(), 2.6, 'queueing Cleave does not reset')
s:log('SPELL_DAMAGE', {[12] = 25231, [8] = 'enemy1'})
s.now = 101.02
s:log('SPELL_MISSED', {[12] = 25231, [8] = 'enemy2', [15] = 'DODGE'})
Near(t:GetTimeRemaining(), 3.58, 'secondary Cleave target does not reset')
Check(s.swings == 2 and s.lastGUID == 'enemy1', 'one callback per Cleave')
s.now = 101.2
s:log('SPELL_DAMAGE', {[1] = 999101, [12] = 25231, [8] = 'enemy3'})
Check(s.swings == 2, 'same CLEU timestamp deduplicates delayed Cleave target record')
s.now = 105
s:log('SPELL_MISSED', {[12] = 30324, [15] = 'MISS'})
Check(s.swings == 3 and s.lastName == 'Heroic Strike', 'HS miss confirms real replacement swing')

-- Damage outcome and cast failure are different: every completed melee attack
-- spends its cycle even when no damage lands. Exercise both arrival orders and
-- a missing cast-success notification, using every Slam/HS/Cleave rank ID.
local outcomes = {'HIT', 'CRIT', 'PARTIAL_BLOCK', 'MISS', 'DODGE', 'PARRY', 'BLOCK', 'ABSORB', 'IMMUNE', 'EVADE'}
for _, attack in ipairs({
    {name = 'Slam', ids = {1464, 8820, 11604, 11605, 25241, 25242}},
    {name = 'Heroic Strike', ids = {78, 284, 285, 1608, 11564, 11565, 11566, 25286, 29707, 30324}},
    {name = 'Cleave', ids = {845, 7369, 11608, 11609, 20569, 25231}},
}) do
    for _, id in ipairs(attack.ids) do
        for _, outcome in ipairs(outcomes) do
            for _, order in ipairs({'success_first', 'result_first', 'result_only'}) do
                s, t = Fixture()
                s:log('SWING_DAMAGE')
                s:log('SWING_DAMAGE', {[21] = true})
                s.now = 100.5
                local isSlam = attack.name == 'Slam'
                local label = attack.name .. ' ' .. id .. ' ' .. outcome .. ' ' .. order
                if order == 'success_first' then
                    s:event('UNIT_SPELLCAST_SUCCEEDED', 'player', 'outcome-cast', id)
                    s:log('SPELL_CAST_SUCCESS', {[12] = id})
                end
                local damage = outcome == 'HIT' or outcome == 'CRIT' or outcome == 'PARTIAL_BLOCK'
                local kind = damage and 'SPELL_DAMAGE' or 'SPELL_MISSED'
                s:log(kind, {[12] = id, [15] = damage and 100 or outcome,
                    [19] = outcome == 'PARTIAL_BLOCK' and 50 or 0, [21] = outcome == 'CRIT'})
                Near(t:GetTimeRemaining(), 3.6, label .. ' resets MH')
                Near(t:GetOffhandTimeRemaining(), isSlam and 2.6 or 2.1, label .. ' correct hand')
                Check(s.swings == (isSlam and 1 or 2), label .. ' swing identity')
                Check(s.slams == (isSlam and 1 or 0), label .. ' completion count')
                if order == 'result_first' then
                    s.now = 100.6
                    s:event('UNIT_SPELLCAST_SUCCEEDED', 'player', 'outcome-cast', id)
                    s:log('SPELL_CAST_SUCCESS', {[12] = id})
                    Near(t:GetTimeRemaining(), 3.5, label .. ' no second reset')
                end
                if attack.name == 'Cleave' then
                    s.now = 100.7
                    s:log('SPELL_MISSED', {[1] = 999100.5, [12] = id, [8] = 'enemy2', [15] = 'PARRY'})
                    Check(s.swings == 2, label .. ' secondary target is same swing')
                    Near(t:GetTimeRemaining(), 3.4, label .. ' no secondary reset')
                    s.now = 104.1
                    s:log(kind, {[12] = id, [15] = damage and 100 or outcome})
                    Check(s.swings == 3, label .. ' next Cleave is a new swing')
                end
            end
        end
    end
end

-- Late duplicate identity must not move the deadline; the next genuine cast must.
s, t = Fixture()
s:event('UNIT_SPELLCAST_SUCCEEDED', 'player', 'identity1', 25242)
s:log('SPELL_MISSED', {[12] = 25242, [15] = 'PARRY'})
s.now = 101
s:event('UNIT_SPELLCAST_SUCCEEDED', 'player', 'identity1', 25242)
s:log('SPELL_MISSED', {[1] = 999100, [12] = 25242, [15] = 'PARRY'})
Near(t:GetTimeRemaining(), 2.6, 'late duplicate GUID and timestamp do not reset twice')
Check(s.slams == 1, 'late duplicates have one completion callback')
s.now, s.casting, s.castEnd = 101.5, true, 102
s:event('UNIT_SPELLCAST_START', 'player', 'identity2', 25242)
s.now, s.casting = 102, false
s:log('SPELL_DAMAGE', {[12] = 25242})
s:event('UNIT_SPELLCAST_SUCCEEDED', 'player', 'identity2', 25242)
Near(t:GetTimeRemaining(), 3.6, 'new cast resets after previous completed Slam')
Check(s.slams == 2, 'new cast completion is not suppressed')
s.now = 102.8
s:log('SPELL_MISSED', {[4] = 'other-player', [12] = 25242, [15] = 'MISS'})
Near(t:GetTimeRemaining(), 2.8, 'another player Slam cannot reset our weapon')

-- Extra attacks must neither reset MH nor consume offhand confirmations.
s, t = Fixture()
s:log('SWING_DAMAGE')
s.now = 101
s:log('SPELL_EXTRA_ATTACKS', {[12] = 123, [15] = 2})
s:log('SWING_DAMAGE', {[21] = true})
s:log('SWING_DAMAGE')
s:log('SWING_MISSED', {[12] = 'MISS', [13] = false})
Near(t:GetTimeRemaining(), 2.6, 'two extras leave MH cycle intact')
Near(t:GetOffhandTimeRemaining(), 2.6, 'OH still confirms during extra attack batch')
Check(s.swings == 1, 'extras do not open Slam windows')
s.now = 103.6
s:log('SWING_DAMAGE')
Check(s.swings == 2, 'next real autoattack is confirmed')
s:log('SPELL_EXTRA_ATTACKS', {[15] = 1})
s.now = 107.2
s:log('SWING_DAMAGE')
Check(s.swings == 3, 'missing extra event cannot swallow next normal cycle')

s, t = Fixture()
s:log('SWING_DAMAGE')
s.now = 101
s:log('SWING_MISSED', {[4] = 'enemy', [8] = 'player', [12] = 'PARRY'})
Near(t:GetTimeRemaining(), 1.16, 'incoming parry speeds up next MH')
s:log('SPELL_MISSED', {[4] = 'enemy', [8] = 'player', [15] = 'PARRY'})
Near(t:GetTimeRemaining(), 0.72, 'parry haste floor is 20 percent')
s.now = 101.1
s:log('SWING_MISSED', {[4] = 'enemy', [8] = 'player', [12] = 'PARRY'})
Near(t:GetTimeRemaining(), 0.62, 'parry never delays an already imminent swing')
Check(s.swings == 1, 'parry haste does not invent an outgoing swing')

for _, event in ipairs({'PLAYER_ENTERING_WORLD', 'PLAYER_DEAD', 'PLAYER_LEAVE_COMBAT', 'PLAYER_EQUIPMENT_CHANGED'}) do
    s, t = Fixture()
    s:log('SWING_DAMAGE')
    s:event(event, 16)
    Check(t:IsTimerStale() and not t:HasConfirmedMainhandSwing(), event .. ' invalidates history')
    s:log('SWING_DAMAGE', {[21] = true})
    Check(not t:IsMainhandTimingReliable(), 'OH cannot revive unknown MH')
    s:log('SWING_DAMAGE')
    Check(t:IsMainhandTimingReliable(), 'MH resynchronizes')
end
s, t = Fixture()
s:log('SWING_DAMAGE')
s.now = 100.5
s:event('PLAYER_EQUIPMENT_CHANGED', 1)
s:event('UPDATE_SHAPESHIFT_FORM')
Near(t:GetTimeRemaining(), 3.1, 'armor and Warrior stance changes do not reset swings')
s:event('UNIT_ATTACK_SPEED', 'target')
Near(t:GetTimeRemaining(), 3.1, 'target speed changes do not alter player')
t:OnAttackStopped()
t:OnAttackStarted()
Check(not t:HasConfirmedMainhandSwing() and t:IsTimerStale(), 'attack requests do not invent hits')
s.mh = 0
s:event('UNIT_ATTACK_SPEED', 'player')
Near(t:GetTimeRemaining(), 0, 'zero speed is safe')
s.mh = 1.8
s:log('SWING_DAMAGE')
Near(t:GetTimeRemaining(), 1.8, 'recovers after unavailable speed')
s.class, s.form = 'DRUID', 1
s:event('UPDATE_SHAPESHIFT_FORM')
Check(t:IsTimerStale(), 'Druid form transition invalidates previous weapon')
s:log('SWING_DAMAGE')
s:event('UPDATE_SHAPESHIFT_FORM')
Check(t:IsMainhandTimingReliable(), 'repeated form notification preserves cycle')

-- Exercise the real Warrior consumer: extra attacks cannot reopen consumed Slam.
local f = assert(io.open('tests/WarriorOptions.test.lua'))
local source = f:read('*a'); f:close()
local prefix = assert(source:find('local function Snapshot(rows)', 1, true))
local Context = assert(loadstring(source:sub(1, prefix - 1) .. '\nreturn Context'))()
for _, thread in ipairs({2, 3}) do
    local state = {thread = thread, rage = 90, enemies = thread == 3 and 3 or 1, realSwingTimer = true}
    state.sweepingActive = thread == 3
    local j, e, frames = Context(state)
    local now, payload = 100, {}
    e.GetTime = function() return now end
    e.GetSpellCooldown = function(spell)
        if spell == 'Mortal Strike' or spell == 'Whirlwind' or spell == 'Sweeping Strikes' then
            return now - 1, 10
        end
        return 0, 0
    end
    e.CombatLogGetCurrentEventInfo = function() return unpack(payload, 1, 24) end
    local function event(name, ...)
        for _, frame in ipairs(frames) do
            if frame.scripts.OnEvent then frame.scripts.OnEvent(frame, name, ...) end
        end
    end
    local function log(kind, spell, amount)
        payload = {[1] = now, [2] = kind, [4] = 'player', [8] = 'enemy1', [12] = spell, [13] = spell, [15] = amount}
        event('COMBAT_LOG_EVENT_UNFILTERED')
    end
    local function hasSlam()
        local rows = (thread == 3 and j.warriorThread3AoE or j.warriorArms)('target')
        for _, row in ipairs(rows) do if row[2] == 'Slam' and row[3] then return true end end
        return false
    end
    log('SWING_DAMAGE')
    Check(hasSlam(), 'thread ' .. thread .. ' sees authoritative mainhand callback')
    log('SPELL_CAST_START', 'Slam')
    now = 100.5
    log('SPELL_CAST_SUCCESS', 'Slam')
    log('SPELL_EXTRA_ATTACKS', 'Windfury', 1)
    log('SWING_DAMAGE')
    Check(not hasSlam(), 'thread ' .. thread .. ' extra attack cannot reopen Slam')
    now = 104
    log('SWING_DAMAGE')
    Check(hasSlam(), 'thread ' .. thread .. ' next actual swing reopens Slam')
    now = 104.5
    log('SPELL_MISSED', 'Slam', 'DODGE')
    Check(not hasSlam(), 'thread ' .. thread .. ' result-only Slam consumes pending window')
    now = 108
    log('SPELL_MISSED', 'Heroic Strike', 'PARRY')
    Check(hasSlam(), 'thread ' .. thread .. ' avoided HS opens afterswing window')
    now = 108.5
    event('UNIT_SPELLCAST_SUCCEEDED', 'player', 'unit-only', 25242)
    Check(not hasSlam(), 'thread ' .. thread .. ' unit-only completion consumes window')
    now = 112
    log('SPELL_MISSED', 'Cleave', 'MISS')
    Check(hasSlam(), 'thread ' .. thread .. ' missed Cleave opens afterswing window')
    event('PLAYER_EQUIPMENT_CHANGED', 16)
    Check(not hasSlam(), 'thread ' .. thread .. ' weapon change clears old Slam window')
end

print('SwingTimer: ' .. checks .. ' checks passed (mocked game events).')
