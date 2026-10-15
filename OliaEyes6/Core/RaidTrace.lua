local addonName, jungle = ...

-- Observational recorder. No protected actions, global API hooks, or disk I/O.
local Trace = { enabled = false, sample = false, watchers = {}, routineNames = {} }
jungle.RaidTrace = Trace
local clock = debugprofilestop
local floor, max = math.floor, math.max
local MAX_BUCKETS, MAX_EVENTS, MAX_SPIKES, MAX_SESSIONS = 720, 256, 32, 3
local stages = { "engine", "units", "rotation", "housekeeping", "arena", "frameGap", "recorder", "sampledEngine", "plainEngine" }
local bounds = { 0.25, 0.5, 1, 2, 3, 5, 8, 12, 20, 33, 50 }
local eventFrame = CreateFrame("Frame")

local function NewStat()
    return { n = 0, total = 0, max = 0, over5 = 0, histogram = {0,0,0,0,0,0,0,0,0,0,0,0} }
end

local function Add(stat, elapsed)
    -- Another addon may reset the shared profiling clock; don't retain negatives.
    if elapsed < 0 then return end
    stat.n = stat.n + 1
    stat.total = stat.total + elapsed
    if elapsed > stat.max then stat.max = elapsed end
    if elapsed >= 5 then stat.over5 = stat.over5 + 1 end
    local bin = #bounds + 1
    for i = 1, #bounds do
        if elapsed <= bounds[i] then bin = i; break end
    end
    stat.histogram[bin] = stat.histogram[bin] + 1
end

local function Increment(t, key, value)
    t[key] = (t[key] or 0) + (value or 1)
end

local function BoundedIncrement(t, key, limit)
    key = key or "unknown"
    if t[key] == nil then
        if t.keys >= limit then key = "overflow" else t.keys = t.keys + 1 end
    end
    Increment(t, key)
end

local function Context()
    local _, class = UnitClass("player")
    local instanceName, instanceType, difficulty, _, _, _, _, instanceID = GetInstanceInfo()
    local _, _, home, world = GetNetStats()
    local cacheCount, tanks = 0, 0
    local unique = {}
    for _, data in pairs(jungle.unitCache or {}) do
        cacheCount = cacheCount + 1
        if data.guid and not unique[data.guid] then
            unique[data.guid] = true
            if data.isTank then tanks = tanks + 1 end
        end
    end
    local uniqueCount = 0
    for _ in pairs(unique) do uniqueCount = uniqueCount + 1 end
    local gcdStart, gcdDuration = 0, 0
    if jungle.GetGCDValues then gcdStart, gcdDuration = jungle.GetGCDValues() end
    return {
        class = class, thread = jungle.Engine and jungle.Engine.activeThread or 0,
        combat = UnitAffectingCombat("player") and true or false,
        instance = instanceName, instanceType = instanceType, instanceID = instanceID,
        encounterID = Trace.encounterID, encounterName = Trace.encounterName,
        difficulty = difficulty, groupSize = GetNumGroupMembers(),
        cachedTokens = cacheCount, cachedGUIDs = uniqueCount, cachedTanks = tanks,
        fps = GetFramerate(), homeLatencyMs = home, worldLatencyMs = world,
        haste = UnitSpellHaste and UnitSpellHaste("player") or nil,
        form = GetShapeshiftForm(), power = UnitPower("player"),
        playerCast = UnitCastingInfo("player"), targetGUID = UnitGUID("target"),
        gcdRemaining = max(0, (gcdStart or 0) + (gcdDuration or 0) - GetTime()),
        bloodlust = jungle.unitCacheBuff and jungle.unitCacheBuff("player", "Bloodlust") or false,
        heroism = jungle.unitCacheBuff and jungle.unitCacheBuff("player", "Heroism") or false,
        luaMemoryKB = collectgarbage("count"), -- Read only; never force collection.
        armsLog = OliaArmsLog and OliaArmsLog.enabled or false,
        debugUI = jungle.Debug and jungle.Debug.enabled or false,
        legacyPerf = jungle.Perf and jungle.Perf.enabled or false,
    }
end

local function ContextLabel(context)
    local situation = context.encounterName and ("encounter: " .. context.encounterName)
        or (context.combat and "combat" or "out of combat")
    return string.format("%s | thread %s | %s | %d players | %s",
        context.class or "UNKNOWN", tostring(context.thread),
        context.instance or context.instanceType or "unknown location",
        context.groupSize or 0, situation)
end

function Trace:NewBucket(now)
    if #self.session.buckets >= MAX_BUCKETS then self:Stop("bucket_limit"); return false end
    local bucket = {
        start = now - self.session.startedAt, duration = 0, context = Context(),
        timings = {}, details = {}, counters = {}, events = {}, eventTimings = {},
        intents = { keys = 0 }, outcomes = { keys = 0 }, sampledFrames = 0,
    }
    bucket.label = ContextLabel(bucket.context)
    -- A session may span several situations; its name describes its start.
    -- Each bucket retains its own label rather than rewriting earlier context.
    if not self.session.label then self.session.label = bucket.label end
    for i = 1, #stages do bucket.timings[stages[i]] = NewStat() end
    self.session.buckets[#self.session.buckets + 1] = bucket
    self.bucket, self.bucketStarted = bucket, now
    return true
end

function Trace:Count(name, amount)
    Increment(self.bucket.counters, name, amount)
end

function Trace:Detail(name, elapsed)
    local detail = self.bucket.details[name]
    if not detail then detail = NewStat(); self.bucket.details[name] = detail end
    Add(detail, elapsed)
end

-- Used only on sampled early-return paths; preserve all documented results.
function Trace:Finish(name, started, a, b, c)
    self:Detail(name, clock() - started)
    return a, b, c
end

function Trace:Mark(kind, a, b, c, d, e)
    local session = self.session
    if not self.enabled or not session then return end
    if #session.markers >= MAX_EVENTS then
        session.droppedMarkers = session.droppedMarkers + 1
        return
    end
    session.markers[#session.markers + 1] = { t = GetTime() - session.startedAt, kind = kind, a = a, b = b, c = c, d = d, e = e }
end

-- Only this addon's explicitly registered, ordinary event frames are wrapped.
-- Disabled mode retains the original callbacks with no wrapper dispatch cost.
function Trace:WatchEventFrame(frame, name)
    self.watchers[#self.watchers + 1] = { frame = frame, name = name }
end

function Trace:InstallEventTimers()
    for i = 1, #self.watchers do
        local watch = self.watchers[i]
        local original = watch.frame:GetScript("OnEvent")
        if original then
            local calls, keys = {}, {}
            watch.original = original
            watch.wrapper = function(frame, event, ...)
                if not self.enabled then return original(frame, event, ...) end
                local key = keys[event]
                if not key then key = watch.name .. ":" .. event; keys[event] = key end
                Increment(self.bucket.events, key)
                calls[event] = (calls[event] or 0) + 1
                if calls[event] % 16 ~= 1 then return original(frame, event, ...) end
                local start = clock()
                original(frame, event, ...)
                local elapsed = clock() - start
                if self.enabled then
                    local stat = self.bucket.eventTimings[key]
                    if not stat then stat = NewStat(); self.bucket.eventTimings[key] = stat end
                    Add(stat, elapsed)
                end
            end
            watch.frame:SetScript("OnEvent", watch.wrapper)
        end
    end
end

function Trace:BeginFrame(sinceLastUpdate)
    local begin = clock()
    local now = GetTime()
    if now >= self.deadline then self:Stop("duration"); return false end
    local thread = jungle.Engine and jungle.Engine.activeThread or 0
    local combat = UnitAffectingCombat("player") and true or false
    if now - self.bucketStarted >= 5 or thread ~= self.bucket.context.thread
        or combat ~= self.bucket.context.combat or self.contextDirty then
        self.bucket.duration = now - self.bucketStarted
        if not self:NewBucket(now) then return false end
        self.contextDirty = false
    end
    self.bucket.duration = now - self.bucketStarted
    self.intentSpell, self.intentTarget, self.intentStage = nil, nil, nil
    self.rotationState = "evaluating"
    self.sampleCountdown = self.sampleCountdown - 1
    self.sample = self.sampleCountdown <= 0
    if self.sample then
        -- Local PRNG avoids changing math.random state used by other addons.
        self.seed = (self.seed * 16807) % 2147483647
        self.sampleCountdown = 8 + (self.seed % 17) -- Mean interval ~16 frames.
        self.bucket.sampledFrames = self.bucket.sampledFrames + 1
    end
    self.frameGap = (sinceLastUpdate or 0) * 1000
    self.beginCost = clock() - begin
    return true
end

function Trace:EndFrame(engine, units, rotation, housekeeping, arena)
    local start = clock()
    local bucket = self.bucket
    Add(bucket.timings.engine, engine)
    Add(bucket.timings.units, units)
    Add(bucket.timings.rotation, rotation)
    if housekeeping then Add(bucket.timings.housekeeping, housekeeping) end
    if arena then Add(bucket.timings.arena, arena) end
    Add(bucket.timings.frameGap, self.frameGap)
    Add(bucket.timings[self.sample and "sampledEngine" or "plainEngine"], engine)
    Increment(bucket.counters, self.intentStage or "noIntent")
    Increment(bucket.counters, self.rotationState)
    if self.intentSpell then BoundedIncrement(bucket.intents, self.intentSpell, 64) end
    if engine >= 5 then
        local spikes = self.session.spikes
        local index = #spikes + 1
        if index > MAX_SPIKES then
            index = 1
            for i = 2, #spikes do if spikes[i].engine < spikes[index].engine then index = i end end
            if engine <= spikes[index].engine then index = nil end
        end
        if index then
            local record = spikes[index] or {}
            record.t, record.bucket = GetTime() - self.session.startedAt, #self.session.buckets
            record.engine, record.units, record.rotation = engine, units, rotation
            record.housekeeping, record.arena = housekeeping, arena
            record.frameGap, record.sampled = self.frameGap, self.sample
            record.spell, record.target, record.stage = self.intentSpell, self.intentTarget, self.intentStage
            record.rotationState = self.rotationState
            spikes[index] = record
        end
    end
    self.sample = false
    Add(bucket.timings.recorder, self.beginCost + clock() - start)
end

function Trace:Status()
    local session = self.session
    if not session then
        local saved = OliaEyes6_RaidTrace
        session = saved and saved.sessions and saved.sessions[#saved.sessions]
    end
    if not session then print("[OliaTrace] No recording. Use /oliatrace start 600"); return end
    print(string.format("[OliaTrace] %s; %.1fs; %d buckets; %d slow frames; label=%s",
        self.enabled and "recording" or (session.stopReason or "interrupted"),
        self.enabled and (GetTime() - session.startedAt) or (session.duration or 0),
        #session.buckets, #session.spikes, self.enabled and self.bucket.label or session.label))
end

function Trace:Stop(reason)
    if not self.enabled then return end
    self.enabled, self.sample = false, false
    self.session.duration = GetTime() - self.session.startedAt
    self.session.stopReason = reason or "manual"
    self.bucket.duration = GetTime() - self.bucketStarted
    self.session.endedAt = time()
    for i = 1, #self.watchers do
        local watch = self.watchers[i]
        if watch.wrapper and watch.frame:GetScript("OnEvent") == watch.wrapper then
            watch.frame:SetScript("OnEvent", watch.original)
        end
        watch.wrapper, watch.original = nil, nil
    end
    eventFrame:UnregisterAllEvents()
    if reason ~= "logout" then
        self:Status()
        print("[OliaTrace] In memory. /reload or log out to write WTF/.../SavedVariables/OliaEyes6.lua")
    end
end

function Trace:Start(seconds)
    if self.enabled then print("[OliaTrace] Already recording; stop before starting another."); return end
    if type(clock) ~= "function" then print("[OliaTrace] Profiling clock unavailable."); return end
    seconds = max(10, math.min(1800, tonumber(seconds) or 600))
    if type(OliaEyes6_RaidTrace) ~= "table" or OliaEyes6_RaidTrace.version ~= 1 then
        OliaEyes6_RaidTrace = { version = 1, sessions = {} }
    end
    local saved = OliaEyes6_RaidTrace
    while #saved.sessions >= MAX_SESSIONS do table.remove(saved.sessions, 1) end
    local version, build, buildDate, interface = GetBuildInfo()
    local now = GetTime()
    self.session = {
        schema = 1, recorderRevision = "raidtrace-2-autolabels", healingSnapshotRevision = 1, labelMode = "automatic",
        startedAt = now, wallStartedAt = time(), duration = 0, stopReason = "interrupted",
        client = { version = version, build = build, date = buildDate, interface = interface },
        scriptProfile = GetCVar("scriptProfile"), histogramBoundsMs = bounds,
        sampleInterval = "8..24 frames (local PRNG); event callbacks 1/16 per watcher/event",
        settings = {}, buckets = {}, markers = {}, spikes = {}, droppedMarkers = 0,
        watchedFrames = {},
    }
    -- Copy scalar routine settings, never retain a mutable settings table.
    local function CopyScalars(source, dest, depth)
        for key, value in pairs(source) do
            if type(value) == "number" or type(value) == "boolean" or type(value) == "string" then dest[key] = value
            elseif type(value) == "table" and depth < 3 then dest[key] = {}; CopyScalars(value, dest[key], depth + 1) end
        end
    end
    if type(OliaEyes6_Settings) == "table" then CopyScalars(OliaEyes6_Settings, self.session.settings, 0) end
    saved.sessions[#saved.sessions + 1] = self.session
    self.deadline, self.seed, self.sampleCountdown = now + seconds, max(1, floor(now * 1000) % 2147483647), 1
    self.enabled, self.sample, self.contextDirty = true, false, false
    self.encounterID, self.encounterName = nil, nil
    self:NewBucket(now)
    for name, value in pairs(jungle) do if type(value) == "function" then self.routineNames[value] = name end end
    for i = 1, #self.watchers do self.session.watchedFrames[i] = self.watchers[i].name end
    self:InstallEventTimers()
    for _, event in ipairs({"PLAYER_LOGOUT", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ENCOUNTER_START", "ENCOUNTER_END", "PLAYER_ENTERING_WORLD"}) do
        eventFrame:RegisterEvent(event)
    end
    for _, event in ipairs({"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED"}) do
        eventFrame:RegisterUnitEvent(event, "player")
    end
    print(string.format("[OliaTrace] Recording %.0fs; label=%s. /oliatrace stop to finish.", seconds, self.session.label))
end

eventFrame:SetScript("OnEvent", function(_, event, a, b, c, d, e)
    if not Trace.enabled then return end
    if event == "PLAYER_LOGOUT" then Trace:Stop("logout")
    elseif string.sub(event, 1, 15) == "UNIT_SPELLCAST_" then
        if a == "player" then BoundedIncrement(Trace.bucket.outcomes, event .. ":" .. tostring(c), 128) end
    else
        Trace:Mark(event, a, b, c, d, e)
        if event == "ENCOUNTER_START" then
            Trace.encounterID, Trace.encounterName = a, b
        elseif event == "ENCOUNTER_END" or event == "PLAYER_ENTERING_WORLD" then
            Trace.encounterID, Trace.encounterName = nil, nil
        end
        Trace.contextDirty = true
    end
end)

SLASH_OLIAEYES6_RAIDTRACE1 = "/oliatrace"
SlashCmdList.OLIAEYES6_RAIDTRACE = function(message)
    local command, rest = (message or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "start" then
        if rest ~= "" and not rest:match("^%d+$") then
            print("[OliaTrace] Labels are automatic. Use /oliatrace start [10..1800 seconds]")
            return
        end
        Trace:Start(tonumber(rest))
    elseif command == "stop" then Trace:Stop("manual")
    elseif command == "status" then Trace:Status()
    elseif command == "clear" then
        if Trace.enabled then print("[OliaTrace] Stop the recording before clearing."); return end
        OliaEyes6_RaidTrace = { version = 1, sessions = {} }; Trace.session = nil; Trace.bucket = nil
        print("[OliaTrace] Recordings cleared in memory; /reload to persist.")
    elseif command == "mark" then Trace:Mark("USER", string.sub(rest, 1, 80))
    else print("[OliaTrace] /oliatrace start [10..1800 seconds] | stop | status | mark text | clear") end
end
