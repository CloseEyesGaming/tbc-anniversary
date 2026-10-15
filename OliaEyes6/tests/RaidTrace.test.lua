-- Standalone Lua 5.1 tests. Not loaded by the production TOC.
local now, profile, calls, combat = 100, 0, 0, false
local frames, messages = {}, {}
local checks = 0
local function Check(value, message) assert(value, message); checks = checks + 1 end
function GetTime() return now end
function time() return 1700000000 + now end
function debugprofilestop() profile = profile + 0.001; calls = calls + 1; return profile end
function UnitClass() return "Warrior", "WARRIOR" end
function GetInstanceInfo() return "Raid", "raid", 3, "25", 25, nil, nil, 565 end
function GetNetStats() return 0, 0, 30, 40 end
function UnitAffectingCombat() return combat end
function GetNumGroupMembers() return 25 end
function GetFramerate() return 100 end
function UnitSpellHaste() return 0 end
function GetShapeshiftForm() return 3 end
function UnitPower() return 50 end
function UnitCastingInfo() end
function UnitGUID(unit) return unit == "target" and "Creature-1" or "Player-1" end
function GetBuildInfo() return "2.5.4", "12345", "date", 20504 end
function GetCVar() return "0" end
function print(message) messages[#messages + 1] = message end
SlashCmdList = {}
function CreateFrame()
    local f = { scripts = {}, events = {} }
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:GetScript(name) return self.scripts[name] end
    function f:RegisterEvent(name) self.events[name] = true end
    function f:RegisterUnitEvent(name, unit) self.events[name] = unit end
    function f:UnregisterAllEvents() self.events = {} end
    frames[#frames + 1] = f
    return f
end
local j = { Engine = {activeThread = 1}, unitCache = {
    player = {guid = "Player-1"}, raid1 = {guid = "Player-1"},
    raid2 = {guid = "Player-2", isTank = true},
} }
assert(loadfile("Core/RaidTrace.lua"))("OliaEyes6", j)
local t, events = j.RaidTrace, frames[1]
Check(not t.enabled and calls == 0, "loading disabled recorder reads no profiling clock")
Check(next(events.events) == nil, "recorder has no event subscriptions while disabled")
local watcher = CreateFrame()
local eventCalls, gotFrame, gotEvent, gotA, gotB = 0
local function original(frame, event, a, b)
    eventCalls = eventCalls + 1
    gotFrame, gotEvent, gotA, gotB = frame, event, a, b
    profile = profile + 0.2
end
watcher:SetScript("OnEvent", original)
t:WatchEventFrame(watcher, "test")
Check(watcher:GetScript("OnEvent") == original, "watch registration does not wrap disabled callbacks")
OliaEyes6_Settings = {classes = {WARRIOR = {demo = true}}}
t:Start(30)
local session = t.session
Check(session.labelMode == "automatic" and session.label == "WARRIOR | thread 1 | Raid | 25 players | out of combat", "automatic starting label")
local startingLabel = session.label
Check(session.settings.classes.WARRIOR.demo, "settings captured")
OliaEyes6_Settings.classes.WARRIOR.demo = false
Check(session.settings.classes.WARRIOR.demo, "settings snapshot is independent")
Check(t.bucket.context.cachedTokens == 3 and t.bucket.context.cachedGUIDs == 2 and t.bucket.context.cachedTanks == 1, "context deduplicates GUIDs")
Check(events.events.UNIT_SPELLCAST_SUCCEEDED == "player", "outcome events filtered to player")
for i = 1, 33 do watcher:GetScript("OnEvent")(watcher, "UNIT_AURA", "raid2", nil) end
Check(eventCalls == 33 and gotFrame == watcher and gotEvent == "UNIT_AURA" and gotA == "raid2" and gotB == nil, "watch preserves callback payload and call count")
Check(t.bucket.events["test:UNIT_AURA"] == 33 and t.bucket.eventTimings["test:UNIT_AURA"].n == 3, "events count all callbacks but time 1/16")
local function Frame(cost)
    Check(t:BeginFrame(0.01), "frame begins")
    if t.sample then t:Count("testCalls", 2); t:Detail("testRoutine", 0.1) end
    t.intentSpell, t.intentTarget, t.intentStage = "Slam", "target", "spellIntent"
    t:EndFrame(cost or 3, 1, (cost or 3) - 1, nil, nil)
    now = now + 0.01
end
for i = 1, 100 do Frame() end
Check(t.bucket.timings.engine.n == 100 and t.bucket.timings.engine.total == 300, "all frame engine totals")
Check(t.bucket.sampledFrames > 1 and t.bucket.sampledFrames < 20, "bounded subsampling")
Check(t.bucket.counters.testCalls == t.bucket.sampledFrames * 2, "sample counters use sampled denominator")
Check(t.bucket.timings.sampledEngine.n + t.bucket.timings.plainEngine.n == 100, "timing populations disjoint")
Check(t.bucket.timings.frameGap.histogram[8] == 100, "10ms frame gaps fall in 8..12 bucket")
Check(t.bucket.timings.recorder.n == 100 and not t.sample, "recorder timing and sampling cleanup")
for i = 1, 80 do Frame(i + 5) end
Check(#session.spikes == 32, "slow frame storage bounded")
local minimum = 999
for _, spike in ipairs(session.spikes) do minimum = math.min(minimum, spike.engine) end
Check(minimum == 54, "retains worst 32 engine frames")
events:GetScript("OnEvent")(events, "UNIT_SPELLCAST_SUCCEEDED", "player", "castGUID", 1464)
events:GetScript("OnEvent")(events, "UNIT_SPELLCAST_SUCCEEDED", "raid2", "castGUID", 1464)
Check(t.bucket.outcomes["UNIT_SPELLCAST_SUCCEEDED:1464"] == 1, "actual outcomes separate from intent and non-player events")
events:GetScript("OnEvent")(events, "ENCOUNTER_START", 42, "Boss", 3, 25)
Check(session.markers[1].a == 42 and session.markers[1].d == 25, "encounter signature retained")
local previous = t.bucket
Frame()
Check(t.bucket ~= previous and #session.buckets == 2, "encounter marker splits context bucket")
Check(t.bucket.context.encounterID == 42 and t.bucket.label:find("encounter: Boss", 1, true), "encounter labels generated from observed events")
Check(session.label == startingLabel and previous.label == startingLabel, "new situation preserves earlier labels")
j.Engine.activeThread = 2; Frame()
Check(t.bucket.context.thread == 2, "thread changes split buckets")
Check(t.bucket.label:find("thread 2", 1, true), "thread label updates")
combat = true; Frame()
Check(t.bucket.context.combat, "combat changes split buckets")
now = now + 5; Frame()
Check(#session.buckets == 5, "five-second timeline rollover")
events:GetScript("OnEvent")(events, "ENCOUNTER_END", 42, "Boss", 3, 25, 1)
Frame()
Check(not t.bucket.context.encounterID and not t.bucket.label:find("encounter:", 1, true), "encounter end clears stale boss label")
Check(t.bucket.label:find("combat", 1, true), "combat fallback label")
for i = 1, 300 do t:Mark("USER", "mark") end
Check(#session.markers == 256 and session.droppedMarkers > 0, "marker cap reports drops")
for i = 1, 200 do events:GetScript("OnEvent")(events, "UNIT_SPELLCAST_SUCCEEDED", "player", nil, i) end
Check(t.bucket.outcomes.keys == 128 and t.bucket.outcomes.overflow > 0, "outcome cardinality bounded")
local a, b, c = t:Finish("returns", profile, false, nil, 9)
Check(a == false and b == nil and c == 9, "sampled early returns preserve false and nil")
t:Stop("manual")
Check(not t.enabled and watcher:GetScript("OnEvent") == original, "stop restores callback")
Check(next(events.events) == nil and session.stopReason == "manual", "stop unregisters recorder events and finalizes saved session")
for i = 1, 4 do t:Start(10); t:Stop("manual") end
Check(#OliaEyes6_RaidTrace.sessions == 3, "retains last three recordings")
t:Start(10); now = now + 11
Check(not t:BeginFrame(0.01) and not t.enabled and t.session.stopReason == "duration", "automatic duration stop")
t:Start(1800)
for i = 1, 721 do
    j.Engine.activeThread = i % 2
    if not t:BeginFrame(0.01) then break end
    t:EndFrame(1, 0.3, 0.7)
    now = now + 0.01
end
Check(not t.enabled and #t.session.buckets == 720 and t.session.stopReason == "bucket_limit", "rapid context changes bounded")
t:Start(10)
events:GetScript("OnEvent")(events, "PLAYER_LOGOUT")
Check(not t.enabled and t.session.stopReason == "logout", "logout finalizes without erasing data")
t:Start(10)
local other = function() end
watcher:SetScript("OnEvent", other)
t:Stop("manual")
Check(watcher:GetScript("OnEvent") == other, "stop does not overwrite another callback replacement")

-- Real Engine: compare call sequence in disabled, legacy-only, trace-only and both modes.
local engineClass = "WARRIOR"
j.GetPlayerClass = function() return engineClass end
assert(loadfile("Core/Performance.lua"))("OliaEyes6", j)
assert(loadfile("Core/Engine.lua"))("OliaEyes6", j)
local realProcessRotation = j.Engine.ProcessRotation
local sequence = {}
local function Push(name) sequence[#sequence + 1] = name; profile = profile + 0.1 end
j.updateUnitsData = function() Push("units") end
j.Los = {OnUpdate = function() Push("los") end}
j.subTableTimerRemove = function() Push("sweep") end
j.Arena = {OnUpdate = function() Push("arena") end}
j.Engine.ProcessRotation = function() Push("rotation") end
local function EngineTick()
    sequence = {}; j.Engine:OnUpdate(1)
    return table.concat(sequence, ",")
end
local expected = EngineTick()
local tick = j.currentTick
j.Perf.enabled = true
Check(EngineTick() == expected and j.currentTick == tick + 1, "legacy profiling preserves order and tick")
Check(j.Perf.stats.arena.count == 1, "legacy arena timing now reported")
j.Perf.enabled = false; t:Start(10)
Check(EngineTick() == expected and t.bucket.timings.engine.n == 1, "trace-only engine preserves order")
Check(j.Perf.stats.engine.count == 1, "trace-only does not pollute legacy statistics")
j.Perf.enabled = true
Check(EngineTick() == expected and j.Perf.stats.engine.count == 2, "both profilers coexist")
j.Perf.enabled = false; now = now + 11
Check(EngineTick() == expected and not t.enabled, "expiry frame executes normal engine exactly once")
local clockCalls = calls
EngineTick()
Check(calls == clockCalls, "disabled engine reads no profiling clock")

-- Actual friendly evaluator: no changed selection/metadata or routine call count.
assert(loadfile("Rotation.lua"))("OliaEyes6", j)
function UnitIsFriend() return true end
function GetSpellBookItemInfo() return 1 end
j.isUnitAvailable = function() return true end
j.ignoreUnlearnedSpells = {}
j.unitCache = {raid1 = {guid = "1", hpBucket = 1}, raid2 = {guid = "2", hpBucket = 3}}
local evaluated, selected = 0
local metadata = function() end
local routine = function(unit)
    evaluated = evaluated + 1
    return {{"heal", "Regrowth", true, metadata}}
end
j.Cast = {CastSpell = function(_, spell, unit) selected = unit; return spell end}
local rotation = j.Rotation:new()
Check(rotation:rotate({routine}, 1) == "Regrowth" and selected == "raid2" and evaluated == 2, "baseline tie-breaking")
t:Start(10); t:BeginFrame(0.01)
evaluated = 0
Check(rotation:rotate({routine}, 1) == "Regrowth" and selected == "raid2" and evaluated == 2, "sampled selector keeps every evaluation and winner")
Check(j.CurrentCast.stopcastFunc == metadata and t.bucket.counters.routineEvaluations == 2, "metadata and workload accounting preserved")
t:EndFrame(1, 0.2, 0.8); t:Stop("manual")
t:Start(10)
engineClass = "DRUID"
j.Engine.initialized = true
j.Engine.pixelReset = {clear = function() end}
j.CurrentCastStop = function() return false end
UnitCastingInfo = function() return "Regrowth" end
t:BeginFrame(0.01)
realProcessRotation(j.Engine)
Check(t.rotationState == "casting", "casting early return classified")
t:EndFrame(1, 0.2, 0.8)
j.CurrentCastStop = function() return true end
t:BeginFrame(0.01)
realProcessRotation(j.Engine)
Check(t.rotationState == "stopcasting", "stopcast early return classified")
t:EndFrame(1, 0.2, 0.8); t:Stop("manual")
SlashCmdList.OLIAEYES6_RAIDTRACE("clear")
Check(#OliaEyes6_RaidTrace.sessions == 0, "clear only recordings")
SlashCmdList.OLIAEYES6_RAIDTRACE("start 600 manual-label")
Check(not t.enabled, "manual labels rejected without starting a recording")
SlashCmdList.OLIAEYES6_RAIDTRACE("start 600")
Check(t.enabled and t.deadline == now + 600 and t.session.labelMode == "automatic", "duration-only command auto labels")
t:Stop("manual")
SlashCmdList.OLIAEYES6_RAIDTRACE("start")
Check(t.enabled and t.deadline == now + 600, "bare start defaults to 600 seconds")
Check(not t.bucket.context.encounterName, "new recordings have no stale encounter name")
t:Stop("manual")
io.write("RaidTrace: ", checks, " assertions passed\n")
