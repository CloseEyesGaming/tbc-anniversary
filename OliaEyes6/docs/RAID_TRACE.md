# Raid performance recording

The recorder is off after every login/reload. It observes the current engine;
it does not throttle updates, change priorities, alter action colors or keys,
force garbage collection, or enable Blizzard's global script profiler.

## Collect a recording

1. `/reload` once to load the new recorder.
2. Before a pull: `/oliatrace start 600` (up to ten minutes).
3. Play normally. Optional: `/oliatrace mark bloodlust` or another short note.
4. After the fight: `/oliatrace stop`.
5. When safe, `/reload` or log out normally to write the recording to disk.

The same command works for every class and thread; manual labels are no longer
accepted. The recorder automatically labels the session's starting situation and
each timeline bucket using class, active thread, instance/location, group size,
and combat state or an observed encounter name. `/oliatrace status` shows the
current bucket's label while recording. Changes do not overwrite older buckets.
Encounter names are available after a recorded `ENCOUNTER_START`; if recording
starts mid-fight, the label says combat until an encounter event supplies a name.
Labels do not guess spec or identify ordinary combat as trash.
Use `/oliatrace status` to see whether it is running. The recorder automatically
stops after the requested duration (10â€“1800 seconds, default 600), on logout,
or at its bucket limit. It does not automatically restart after reload.
Starting while already recording leaves the current recording intact.

The normal WoW SavedVariables file is:

```text
D:\[GAMES]\World of Warcraft\_anniversary_\WTF\Account\<account>\SavedVariables\OliaEyes6.lua
```

Send/copy this file **after** reload/logout. The recording is the
`OliaEyes6_RaidTrace` global inside it. Other addon settings and pre-existing
diagnostic globals share the file. A stop message means capture finished in
memory, not that WoW has written the file yet. A client crash can lose unsaved
data. This addon has no arbitrary live file-write API.

The latest three recordings are retained, oldest first. Starting a fourth drops
the oldest in-memory recording. Copy a file before further recordings if you
need to retain it. `/oliatrace clear` clears only these recordings, and requires
capture to be stopped first. Reload/logout persists the clear as well.

## What is captured

- Every engine frame: inclusive engine, unit update, rotation and arena timing;
  housekeeping timing only when it runs; frame gap supplied by `OnUpdate`.
- Histograms, counts, total milliseconds, maxima and counts at/above 5 ms.
- Five-second timeline buckets, also split on thread/combat changes and
  encounter/world markers. An event immediately before a frame-boundary split
  can appear in the preceding bucket; markers carry precise relative timestamps.
- Sparse context snapshots: client build, class, thread, instance/difficulty,
  group size, cached tokens versus unique GUIDs, cached tanks, frame rate,
  latency, haste, form, power, player casting state, target GUID, GCD remainder,
  cached Bloodlust/Heroism state, Lua memory and other diagnostic flags.
  These describe the bucket's beginning, not continuous gameplay state.
- Initial routine settings copied independently from the settings table.
- Sampled routine execution times and counts of evaluations/rows returned/rows
  inspected. Reused rows are counted as returned, not as new allocations.
- Sampled generic/categorized aura enumeration times, aura query/slot counts,
  categorized refresh reasons, and unit fact refresh timing/counts.
- Sampled Warrior direct debuff/armor scan timing and slot counts, plus nameplate
  visits/direct aura scan counts. Slot counts include the terminating empty slot
  when the scanner reaches it.
- Sampled Druid Lifebloom schedule timing, schedule entry counts, window checks,
  and spell-lockout calculations.
- Sampled shared readiness/GCD/cooldown helper call counts.
- All callback counts and sampled callback timings for the explicitly registered
  addon frames listed in `session.watchedFrames`: aura cache, availability,
  Warrior combat/talents, Druid tank tracker/talents, swing timer, arena/spec,
  DR, LoS, recent casts, energy, and hotkey maintenance. Deferred timer work
  scheduled by a callback is **not** included in its callback timing.
- Every frame's last focus/spell intent, aggregated by spell/action, and player
  cast-start/success/failure/interruption event counts by spell ID. Intent does
  not prove external input execution or successful spell delivery; a player cast
  event may also result from manual input. No claim of one-to-one attribution.
- Up to 32 worst engine frames at/above 5 ms, with section breakdown, frame gap,
  sampling flag, bucket index, and last intent's spell/target token/stage.
- Encounter start/end, combat/world transitions and user markers.

## Cost and storage limits

There is no zero-overhead profiler. This design bounds cost and makes part of
the measurement overhead visible:

- Disabled: no recorder event subscriptions, original watched callbacks restored,
  no profiling-clock reads from the recorder path; small conditional checks
  remain at instrumented sites.
- Enabled: outer timing/aggregation every frame; detailed instrumentation only
  on frames spaced 8â€“24 frames apart (mean approximately 16), using a private
  PRNG that does not disturb the game's `math.random` sequence. It samples
  work; it never skips or repeats rotation evaluation.
- Event callbacks are timed on the first and every 16th subsequent invocation
  of each watcher/event combination. Counts cover every invocation while active.
- No per-frame strings or unbounded frame/event payload history. Numeric
  aggregates are updated in place. Buckets, detail keys, initial event keys,
  bounded worst-frame records and markers do allocate tables/strings.
- At most 720 buckets, 256 markers, and 32 worst-frame records per session;
  three sessions. Excess markers increment `droppedMarkers`; a bucket overflow
  stops recording. Spell intent/outcome maps cap distinct keys at 64/128 per
  bucket and aggregate additional keys under `overflow` (`keys` is metadata).
- No combat-log dump, `UpdateAddOnMemoryUsage`, `UpdateAddOnCPUUsage`, forced GC,
  or continuous chat output. `collectgarbage("count")` only reads total Lua
  memory at context boundaries; it is not addon-specific memory attribution.

`timings.recorder` measures begin/end bookkeeping around each recorded engine
frame. It excludes its own final histogram update, event-wrapper overhead, and
instrumentation inside the engine. Nested instrumentation is included in engine
and parent timings. Compare `sampledEngine` with `plainEngine` as an overhead
indicator, but their workloads differ and this is not a controlled benchmark.
Actual overhead and disk serialization cost still require in-game measurement.

## Analysis rules / schema 1

Each session has `buckets`, `spikes`, `markers`, client/settings metadata, a
`duration`, and `stopReason`. `interrupted` means no clean stop was recorded.
Times `start`, marker/spike `t`, and bucket/session `duration` are in seconds;
timing-stat `total`/`max` and `frameGap` are milliseconds. `startedAt` is a
session-local GetTime clock; `wallStartedAt`/`endedAt` are epoch seconds.

A timing stat contains `n`, `total`, `max`, `over5`, and `histogram`. Histogram
upper bounds (inclusive) are stored in `histogramBoundsMs`; the final bin is
above the last bound. Negative durations from a reset profiling clock are
discarded. Histograms give percentile ranges, not exact percentiles.

Useful calculations:

```text
average engine ms = sum(engine.total) / sum(engine.n)
engine updates/sec = sum(engine.n) / session.duration
engine wall-time share = sum(engine.total) / (1000 * session.duration)
rotation share = sum(rotation.total) / sum(engine.total)
sampled scans/frame = sum(scan counter) / sum(bucket.sampledFrames)
sampled routine ms/call = sum(detail.total) / sum(detail.n)
estimated event work = (eventTimings.total / eventTimings.n) * events[count]
```

Aggregate raw counts/totals before dividing; don't average bucket averages.
Only estimate event work where there are timed samples, and assess their count
and representativeness. Nested timers overlap: do not sum routine, aura and
schedule times as independent work. Frame gaps are whole-client intervals;
an engine spike and a frame gap are different measurements.

`counters.focusIntent`, `spellIntent`, and `noIntent` cover all recorded frames.
The separate `evaluating`, `casting`, `stopcasting`, `drinking`, and
`warriorThread3Hold` counters classify the reached engine path on every frame.
Other workload counters and `details` cover **sampled engine frames only**.
`noIntent` includes deliberate waits, casting, unsupported threads and no valid
candidate; it is not proof of a missed action. The record is designed to guide
performance refactoring, not to reconstruct every decision or every combat event.

The engine timer is not total addon CPU. Watched event timings are separate
sampled measurements; timers, other UI frames, callbacks not listed in
`watchedFrames`, external input and other addons remain outside coverage.

For comparisons, record equivalent class/thread/options, encounter stage, group
size and diagnostic settings. Start with `/oliaperf off` and optional debug/Arms
logs off unless those are specifically under investigation. The trace records
their flags instead of silently changing them. Use a representative short capture
first; verify no Lua errors and normal gameplay before longer raid recordings.
