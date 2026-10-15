-- Standalone Lua 5.1 regression tests with mocked game APIs.
-- Optional argument: pre-change Warrior.lua, for damage-rotation comparisons.
local baselinePath = ...
local file = assert(io.open("tests/WarriorOptions.test.lua"))
local source = file:read("*a")
file:close()
local boundary = assert(source:find("local function Snapshot(rows)", 1, true))
local Context = assert(loadstring(source:sub(1, boundary - 1) .. "\nreturn Context"))()
local checks = 0
local function Check(value, message)
    assert(value, message)
    checks = checks + 1
end
local function HasAction(rows, action)
    for _, row in ipairs(rows) do
        if row[2] == action and row[3] then return true end
    end
    return false
end
local function Fixture(s, path, disabled)
    s.rage = s.rage or 80
    local j, env, frames = Context(s, path, disabled)
    local now = 100
    env.GetTime = function() return now end
    local costs = { ["Mortal Strike"] = 30, Whirlwind = 25, Slam = 15,
        ["Demoralizing Shout"] = 10, Bloodthirst = 30 }
    env.IsUsableSpell = function(spell)
        if s.blocked and s.blocked[spell] then return false, false end
        if spell == "Whirlwind" and (s.stance or 3) ~= 3 then return false, false end
        if s.rage < (costs[spell] or 0) then return false, true end
        return true, false
    end
    env.GetSpellCooldown = function(spell)
        if s.cooldowns and s.cooldowns[spell] then return 99, 10 end
        if s.gcd then return 99.5, 1.5 end
        return 0, 0
    end
    j.GetGCDValues = function() return s.gcd and 99.5 or 0, 1.5 end
    j.ReadyCastSpell = function(spell)
        return not s.gcd and env.IsUsableSpell(spell)
            and not (s.cooldowns and s.cooldowns[spell])
    end
    j.SwingTimer.GetSlamTimeRemaining = function() return s.swingRemaining or 2 end
    j.SwingTimer.GetTimeRemaining = j.SwingTimer.GetSlamTimeRemaining
    -- Deliver a real main-hand event through the routine's registered handler.
    if s.swingAgo then
        now = 100 - s.swingAgo
        env.CombatLogGetCurrentEventInfo = function()
            return now, "SWING_DAMAGE", false, "player", nil, nil, nil, "enemy1"
        end
        for _, frame in ipairs(frames) do
            if frame.scripts.OnEvent then frame.scripts.OnEvent(frame, "COMBAT_LOG_EVENT_UNFILTERED") end
        end
        now = 100
    end
    return j
end

local function Rows(j, route)
    if route == "maintenance" then return j.warriorArmsPveMaintenance("target") end
    if route == "thread3" then return j.warriorThread3AoE("target") end
    if route == "fury" then return j.warriorFury("target") end
    return j.warriorArms("target")
end
local routes = {
    { thread = 1, route = "maintenance", enemies = 1 },
    { thread = 1, route = "maintenance", enemies = 3 },
    { thread = 1, route = "arms", enemies = 3 },
    { thread = 2, route = "arms", enemies = 1 },
    { thread = 2, route = "arms", enemies = 3 },
    { thread = 3, route = "arms", enemies = 3 },
    { thread = 3, route = "thread3", enemies = 3 },
}
for _, route in ipairs(routes) do
    local function Scenario(extra)
        local s = { thread = route.thread, enemies = route.enemies, sweepingActive = true,
            rage = 90, swingAgo = 2, cooldowns = { ["Mortal Strike"] = true, Whirlwind = true } }
        for k, v in pairs(extra or {}) do s[k] = v end
        return s
    end
    local label = "thread " .. route.thread .. " " .. route.route .. " enemies=" .. route.enemies
    Check(HasAction(Rows(Fixture(Scenario()), route.route), "Demoralizing Shout"), label .. ": idle fallback")
    for _, spell in ipairs({ "Mortal Strike", "Whirlwind" }) do
        -- Baseline Arms AoE deliberately does not schedule Mortal Strike.
        if spell ~= "Mortal Strike" or route.enemies == 1 or route.thread == 2 or route.route == "thread3" then
            local s = Scenario()
            s.cooldowns[spell] = nil
            local rows = Rows(Fixture(s), route.route)
            Check(not HasAction(rows, "Demoralizing Shout"), label .. ": yields to " .. spell)
            if route.route ~= "maintenance" then Check(HasAction(rows, spell), label .. ": keeps " .. spell .. " eligible") end
            s.gcd = true
            Check(not HasAction(Rows(Fixture(s), route.route), "Demoralizing Shout"), label .. ": shared GCD does not hide " .. spell)
        end
    end
    local slam = Scenario({ swingAgo = 0.2 })
    Check(not HasAction(Rows(Fixture(slam), route.route), "Demoralizing Shout"), label .. ": after-swing Slam")
    slam.moving = true
    Check(HasAction(Rows(Fixture(slam), route.route), "Demoralizing Shout"), label .. ": movement closes Slam opportunity")
    Check(not HasAction(Rows(Fixture(Scenario({ casting = true })), route.route), "Demoralizing Shout"), label .. ": casting Slam")
    for _, remaining in ipairs({ 5, 6 }) do
        local s = Scenario({ auras = { { "Demoralizing Shout", 0, remaining } } })
        Check(HasAction(Rows(Fixture(s), route.route), "Demoralizing Shout") == (remaining == 5), label .. ": refresh at " .. remaining)
    end
    for _, invalid in ipairs({ "pvp", "totem", "dead", "outOfRange" }) do
        Check(not HasAction(Rows(Fixture(Scenario({ [invalid] = true })), route.route), "Demoralizing Shout"), label .. ": rejects " .. invalid)
    end
    local disabled = { ["thread" .. route.thread .. "_demoralizing_shout"] = false }
    Check(not HasAction(Rows(Fixture(Scenario(), nil, disabled), route.route), "Demoralizing Shout"), label .. ": option disabled")
    local s = Scenario()
    local j = Fixture(s)
    Check(HasAction(Rows(j, route.route), "Demoralizing Shout"), label .. ": cached fallback")
    s.cooldowns.Whirlwind = nil
    Check(not HasAction(Rows(j, route.route), "Demoralizing Shout"), label .. ": cached core returns")
    s.cooldowns.Whirlwind = true
    Check(HasAction(Rows(j, route.route), "Demoralizing Shout"), label .. ": cached fallback returns")
end

for _, thread in ipairs({ 1, 2, 3 }) do
    local route = thread == 1 and "maintenance" or thread == 2 and "arms" or "thread3"
    local s = { thread = thread, enemies = thread == 3 and 3 or 1, stance = 1,
        sweepingActive = true, rage = 80, swingAgo = 2, moving = true,
        blocked = { ["Thunder Clap"] = true }, cooldowns = { ["Mortal Strike"] = true } }
    Check(HasAction(Rows(Fixture(s), route), "Demoralizing Shout") == (thread ~= 3), "thread " .. thread .. ": Battle Stance WW preparation policy")
end

-- Thread 1 retains speculative reservations; Thread 2 reserves only eligible Slam.
for _, thread in ipairs({ 1, 2 }) do
    local route = thread == 1 and "maintenance" or "arms"
    for _, initial in ipairs({ false, true }) do
        local s = { thread = thread, rage = 40, swingAgo = not initial and 2 or nil, swingRemaining = 0.3,
            cooldowns = { ["Mortal Strike"] = true, Whirlwind = true } }
        Check(HasAction(Rows(Fixture(s), route), "Demoralizing Shout") == (thread == 2), "thread " .. thread .. ": speculative reservation policy")
    end
end

-- Low rage, stance, and Thread 3's intentional pooling thresholds.
for _, thread in ipairs({ 1, 2, 3 }) do
    local route = thread == 1 and "maintenance" or thread == 2 and "arms" or "thread3"
    local s = { thread = thread, enemies = thread == 3 and 3 or 1, sweepingActive = true,
        rage = 10, swingAgo = 2, moving = true }
    Check(HasAction(Rows(Fixture(s), route), "Demoralizing Shout") == (thread ~= 3), "thread " .. thread .. ": low rage core funding policy")
    s.rage = 9
    Check(not HasAction(Rows(Fixture(s), route), "Demoralizing Shout"), "thread " .. thread .. ": insufficient Demo rage")
end
local s = { thread = 3, enemies = 3, sweepingActive = true, rage = 59, swingAgo = 2, cooldowns = { Whirlwind = true } }
Check(HasAction(Rows(Fixture(s), "thread3"), "Demoralizing Shout"), "thread 3: MS respects 60-rage threshold")
s.rage = 60
Check(not HasAction(Rows(Fixture(s), "thread3"), "Demoralizing Shout"), "thread 3: MS eligible at 60 rage")
s.swingRemaining = 0.5
s.cooldowns["Mortal Strike"] = true
Check(not HasAction(Rows(Fixture(s), "thread3"), "Demoralizing Shout"), "thread 3: imminent Slam is protected")
s.sweepingActive = false
s.rage = 90
s.swingAgo = 0.2
Check(not HasAction(Rows(Fixture(s), "thread3"), "Slam"), "thread 3: overflow Slam cannot postpone burst")
s.rage = 80
s.swingRemaining = 2
Check(not HasAction(Rows(Fixture(s), "thread3"), "Demoralizing Shout"), "thread 3: maintenance preserves activation rage")

-- Fury also uses the Thread 1 overlay and Thread 2 elevated Demo slot.
for _, thread in ipairs({ 1, 2, 3 }) do
    for _, enemies in ipairs({ 1, 3 }) do
        local s = { thread = thread, fury = true, rage = 80, enemies = enemies,
            cooldowns = { Bloodthirst = true, Whirlwind = true, ["Sweeping Strikes"] = true } }
        local route = thread == 1 and "maintenance" or "fury"
        Check(HasAction(Rows(Fixture(s), route), "Demoralizing Shout"), "Fury fallback thread " .. thread)
        s.cooldowns.Whirlwind = nil
        Check(not HasAction(Rows(Fixture(s), route), "Demoralizing Shout"), "Fury WW thread " .. thread)
        s.gcd = true
        Check(not HasAction(Rows(Fixture(s), route), "Demoralizing Shout"), "Fury WW during GCD thread " .. thread)
    end
end

-- The shared Slam extraction must preserve damage decisions with Demo disabled.
if baselinePath then
    local disabled = { thread1_demoralizing_shout = false, thread2_demoralizing_shout = false, thread3_demoralizing_shout = false }
    local function Actions(rows)
        local result = {}
        for _, row in ipairs(rows) do if row[3] then result[#result + 1] = row[2] end end
        return table.concat(result, ",")
    end
    for _, thread in ipairs({ 1, 2, 3 }) do
        for _, enemies in ipairs({ 1, 3 }) do
            for _, moving in ipairs({ false, true }) do
                for _, swingAgo in ipairs({ 0.2, 2 }) do
                    for _, rage in ipairs({ 10, 30, 60, 90 }) do
                        local s = { thread = thread, enemies = enemies, moving = moving, swingAgo = swingAgo, rage = rage }
                        local old, new = Fixture(s, baselinePath, disabled), Fixture(s, nil, disabled)
                        Check(Actions(old.warriorArms("target")) == Actions(new.warriorArms("target")), "unchanged Arms core decisions")
                        if thread == 3 then
                            Check(Actions(old.warriorThread3AoE("target")) == Actions(new.warriorThread3AoE("target")), "unchanged Thread 3 decisions")
                        end
                    end
                end
            end
        end
    end
    for _, thread in ipairs({ 1, 2, 3, 5, 7 }) do
        for _, fury in ipairs({ false, true }) do
            local s = { thread = thread, fury = fury, pvp = true, enemies = 3, swingAgo = 2 }
            local old, new = Fixture(s, baselinePath), Fixture(s)
            Check(Actions(old.warriorUniversal("target")) == Actions(new.warriorUniversal("target")), "unchanged PvP decisions")
            if thread == 5 or thread == 7 then
                s.pvp = false
                old, new = Fixture(s, baselinePath), Fixture(s)
                Check(Actions(old.warriorUniversal("target")) == Actions(new.warriorUniversal("target")), "unchanged other threads")
            end
        end
    end
end
print("Warrior Demoralizing Shout: " .. checks .. " checks passed (mocked APIs).")
