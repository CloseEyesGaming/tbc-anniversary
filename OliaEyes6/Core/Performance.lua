local Jungle, jungle = ...

local Perf = {
    enabled = false,
    generation = 0,
    startedAt = 0,
    endedAt = 0,
    spikeThreshold = 5,
}
jungle.Perf = Perf
jungle.PerfEnabled = false

local stats = {
    engine = {label = "Engine", count = 0, total = 0, max = 0, spikes = 0},
    units = {label = "Units", count = 0, total = 0, max = 0, spikes = 0},
    rotation = {label = "Rotation", count = 0, total = 0, max = 0, spikes = 0},
    arena = {label = "Arena", count = 0, total = 0, max = 0, spikes = 0},
    housekeeping = {label = "Housekeeping", count = 0, total = 0, max = 0, spikes = 0},
}
local statOrder = {"engine", "units", "rotation", "housekeeping", "arena"}
Perf.stats = stats

function Perf:Clear()
    for i = 1, #statOrder do
        local stat = stats[statOrder[i]]
        stat.count = 0
        stat.total = 0
        stat.max = 0
        stat.spikes = 0
    end
    self.startedAt = self.enabled and GetTime() or 0
    self.endedAt = 0
end

function Perf:Record(name, elapsed)
    local stat = stats[name]
    if not stat then return end

    stat.count = stat.count + 1
    stat.total = stat.total + elapsed
    if elapsed > stat.max then
        stat.max = elapsed
    end
    if elapsed >= self.spikeThreshold then
        stat.spikes = stat.spikes + 1
    end
end

function Perf:Report()
    local reportEnd = self.endedAt > 0 and self.endedAt or GetTime()
    local duration = self.startedAt > 0 and math.max(0, reportEnd - self.startedAt) or 0
    local thread = jungle.Engine and jungle.Engine.activeThread or 0
    print(string.format("|cFF00FFFF[OliaPerf]|r duration=%.1fs thread=%s enabled=%s",
        duration, tostring(thread), tostring(self.enabled)))

    for i = 1, #statOrder do
        local stat = stats[statOrder[i]]
        local average = stat.count > 0 and (stat.total / stat.count) or 0
        print(string.format("|cFF00FFFF[OliaPerf]|r %s: n=%d avg=%.3fms max=%.3fms total=%.1fms spikes>=%dms=%d",
            stat.label, stat.count, average, stat.max, stat.total, self.spikeThreshold, stat.spikes))
    end
end

function Perf:Start(duration)
    if type(debugprofilestop) ~= "function" then
        print("|cFFFF0000[OliaPerf]|r debugprofilestop is unavailable.")
        return
    end

    self.generation = self.generation + 1
    self.enabled = true
    jungle.PerfEnabled = true
    self:Clear()

    if duration and duration > 0 then
        local generation = self.generation
        C_Timer.After(duration, function()
            if self.enabled and self.generation == generation then
                self:Stop(true)
            end
        end)
        print(string.format("|cFF00FFFF[OliaPerf]|r Sampling for %.0f seconds.", duration))
    else
        print("|cFF00FFFF[OliaPerf]|r Sampling started.")
    end
end

function Perf:Stop(showReport)
    if self.enabled then
        self.endedAt = GetTime()
    end
    self.enabled = false
    jungle.PerfEnabled = false
    self.generation = self.generation + 1
    print("|cFF00FFFF[OliaPerf]|r Sampling stopped.")
    if showReport then
        self:Report()
    end
end

SLASH_OLIAPERF1 = "/oliaperf"
SlashCmdList["OLIAPERF"] = function(message)
    local command = (message or ""):match("^%s*(.-)%s*$"):lower()
    local duration = tonumber(command)

    if duration then
        duration = math.max(1, math.min(300, duration))
        Perf:Start(duration)
    elseif command == "on" then
        Perf:Start()
    elseif command == "off" then
        Perf:Stop(true)
    elseif command == "report" then
        Perf:Report()
    elseif command == "clear" then
        Perf:Clear()
        print("|cFF00FFFF[OliaPerf]|r Statistics cleared.")
    else
        print("|cFF00FFFF[OliaPerf]|r Commands: /oliaperf 15, on, off, report, clear")
    end
end
