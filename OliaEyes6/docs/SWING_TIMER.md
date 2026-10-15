# Internal swing timer verification

Checked 2026-09-24 against installed `WowClassic.exe` version **2.5.6.69795**.
The addon TOC declares `20504`; no interface migration is included here.
There is no runtime dependency on SuperSwingTimer.

## Event rules

| Evidence | Tracker behavior |
| --- | --- |
| Main-hand white hit or miss | Confirm one main-hand swing and start its next cycle. |
| Off-hand white hit or miss | Update only the off-hand cycle. |
| Heroic Strike/Cleave damage or miss | Confirm the executed main-hand replacement swing. Queuing/cast-success alone does not establish execution. |
| Multiple Cleave targets | Count one swing, including mixed hit/miss or all-missed results. |
| Slam unit success, combat-log success, damage or miss | Complete one Slam reset; never create a new after-swing opportunity. |
| Failed/interrupted Slam cast | No completed-Slam reset. Preserve the unexpired old cycle, otherwise wait for a real swing. |

A completed cast and a landed hit are separate facts. A dodge, parry, miss,
full block, absorb or immunity outcome does not mean the cast was interrupted.
Crits and partial blocks arrive through the damage path.

Slam completion now has one callback for Warrior's consumed-window bookkeeping
and `SLAM_SUCCESS` diagnostics. The diagnostic `evidence` field identifies which
event established completion. Outcome-only and unit-success-only recovery both
consume the existing window in threads 2 and 3.

## Build-matched source

Reference: `Gethe/wow-ui-source`, `classic_anniversary`, revision
`1463c686270b6c64e2c5c228f447c4597c0f8ba6` (2.5.6 build 69795).

- [Blizzard_CombatLog/Classic/Blizzard_CombatLog.lua, lines 1714-1771](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_CombatLog/Classic/Blizzard_CombatLog.lua#L1714-L1771): Blizzard's parser places white miss type/off-hand at overall CLEU positions 12/13, spell ID/name at 12/13, spell miss type at 15, and white damage off-hand at 21. These are implementation evidence for the event layouts.
- [Blizzard_APIDocumentationGenerated/UnitDocumentation.lua, lines 3284-3294](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua#L3284-L3294): documented unit cast-success payload begins with unit, cast GUID and spell ID.
- [Blizzard_UIPanels_Game/Shared/CastingBarFrame.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_UIPanels_Game/Shared/CastingBarFrame.lua#L350): Blizzard reads cast start/end timestamps from `UnitCastingInfo`.
- [Blizzard_CharacterFrame/TBC/PaperDollFrame.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_CharacterFrame/TBC/PaperDollFrame.lua#L729): Blizzard reads weapon speed through `UnitAttackSpeed`.

These files establish event/API usage, **not the server's Slam swing-reset rule**.
The implemented TBC model is completion time plus a full weapon interval, based
on the previously inspected TBC simulator and version-aware swing addon. It is
still awaiting live Anniversary validation; do not describe it as API-confirmed.

Deduplication also includes project heuristics: a 0.5-second cross-channel grace
for Slam records lacking shared identity, and a 0.05-second distinct-target
grace for Cleave. Matching Slam cast GUIDs/CLEU timestamps and matching Cleave
CLEU timestamps catch duplicates outside those grace periods. Extremely delayed
records without shared identity remain ambiguous. Extra-attack attribution uses
the existing bounded combat-log counter; it likewise needs live proc coverage.

## Automated checks

`tests/SwingTimer.test.lua` exercises all listed TBC Slam, Heroic Strike and
Cleave ranks, damage/avoidance outcomes, success/result ordering, missing success,
duplicate completion, multi-target Cleave, subsequent genuine casts/swings,
source filtering, haste changes, interruption, extra attacks and real Warrior
thread 2/3 consumers. These are mocked event tests, not server observations.

All eleven standalone runnable suites passed under Lua 5.1. The historical
`HealingSnapshot.test.lua` comparison requires its original pre-optimization
checkpoint and was not run. No in-game reload or combat test has been performed.

## Bounded live check still required

After `/reload`, enable `/combatlog` for one 20-30 second controlled sample and
turn it off with `/combatlog` immediately afterward. Enable `/armslog on` for
the sample and `/armslog off` afterward if testing the routine's decisions.
Preserve the combat log and Arms diagnostics before another trial.

1. Use a constant-speed two-handed weapon, stay in melee range, and avoid haste
   changes, extra-attack procs and incoming parry haste for the first sample.
2. Record a baseline white-swing interval. Cast Slam deliberately late after
   one swing, then allow the next white swing. A late cast distinguishes reset
   from delay: the implemented model predicts one full weapon interval from
   completion; pause/resume predicts the old remaining interval after completion.
3. Repeat with landed and avoided Slam where available, then with a deliberately
   interrupted cast. Record exceptions rather than assuming all share a result.
4. In separate short samples, execute Heroic Strike and multi-target Cleave;
   compare each executed attack's timestamp with the following main-hand swing.
5. Finally repeat with haste gain/loss and extra-attack procs. Confirm there is
   no second consumed-window transition for duplicate Slam notifications or
   multiple Cleave targets, and no false after-swing window from Slam itself.

Report build, weapon speed, previous swing, cast start/completion, outcome,
following swing and any haste/proc/parry event. A missing or out-of-range attack
cannot establish the reset rule. Live results take precedence over this model.

## Arms thread 2/3 scheduling

The PvE scheduler now evaluates each after-swing opportunity before granting
Slam priority. The 1.15-second eligibility window remains fixed. Earliest start
includes the remaining GCD plus a minimum 0.1-second/world-latency margin. The
next core opportunity is after both the cast and the 1.5-second melee GCD finish;
the projected next swing uses the current weapon speed and the reset model above.

Slam is rejected when it adds projected MS/WW delay, delays applicable Sweeping
Strikes, or leaves insufficient rage for queued attacks and protected core spells
due before that next swing. AoE MS protection follows the existing 60-rage filler
threshold. This is a conservative zero-added-delay policy, not a claim of maximum
DPS. PvE budgets use 30 rage for Mortal Strike and 25 for Whirlwind, without
assuming a Mortal Strike set-bonus discount. Incoming damage, future crits, rage refunds,
future haste procs and extra attacks are not guaranteed funding.

Thread 3 explicitly distinguishes pooling from an active burst:

- Pooling retains its 80-rage/pre-swing activation rule. Overflow Slam must leave
  that funding intact and must not move activation later through either its GCD
  or swing reset. Under normal reset timing this rejects pooling Slam, even at
  100 rage. Losing nearby enemies does not release the existing Engine ownership.
- An already queued spender is cancelled if it would consume activation funding.
  Pooling maintenance must also fit before activation and retain its rage.
- During the burst, a ready or soon-ready WW blocks conflicting Slam, MS filler
  and maintenance. Cleave may precede WW as an off-GCD queue only while preserving
  WW funding; an underfunded existing queue is cancelled.
- After Sweeping Strikes is spent and remains on cooldown, the existing Engine
  handoff resumes. PvP, Fury and neighboring thread policies retain their prior
  behavior; the new scheduler also covers thread 3's PvE Arms fallback.

Build-matched [MainMenuBar.xml, lines 147-148](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_ActionBar/Classic/MainMenuBar.xml#L147-L148)
confirms the home/world latency return positions. Cooldown access uses this
addon's existing legacy getter. Matching cooldown/GCD start and duration is a
project heuristic; it is not a public server scheduling contract.

`tests/WarriorSlamTiming.test.lua` covers overlapping core cooldowns, GCD/latency
windows, cast duration, projected funding, haste gain/loss, pooling/burst/exit,
queued spenders, stale rows, and differential neighboring-policy controls against
the exact pre-change checkpoint. The event-identity fixture keeps core cooldowns
away from Slam so its swing assertions remain independent of priority policy.

For a bounded live check, run `/oliatrace start 30` separately in thread 2 and
thread 3. Sampled `slamPlan_*` counters identify planner rejection reasons; the
`slamProjected*DelaySeconds` details contain predicted delays, not observed cast
delays. Thread 2 Arms window diagnostics also retain the timing snapshot. Compare
those predictions with the combat-log capture, including a haste proc and a
low-rage pooling transition. In-game reload, raid outcomes and performance remain
unverified by the mocked tests.
