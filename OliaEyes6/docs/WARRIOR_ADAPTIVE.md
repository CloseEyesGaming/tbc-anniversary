# Adaptive Arms

After `/reload`, open `/olia options` and run **Arms — Adaptive** in the chosen
class thread. Its Steps and More controls belong to that placement; two placements
may use different switches. Original is the fresh-profile default. Existing routine
IDs, saved preferences, action bindings and the external key/color protocol are unchanged.

## Scope and integration

- Two-handed Arms planning requires Mortal Strike and no Bloodthirst, plus a registered
  behavior that permits Adaptive. Fury and excluded behavior variants return no Adaptive action; only the explicit thread list can select another placement.
- PvE and PvP share the damage planner, actual spell costs, Slam timing, Sweeping funding,
  queued HS/Cleave budget, Execute spending and observed enemy-count transitions.
- PvP activates against players/pets or in a battleground/arena. Selected NPCs can still
  be attacked there, but ordinary neighbouring NPCs do not inflate PvP coverage.
- Original remains independent; WoWSims is PvE-only and returns no action in PvP. Adaptive's shared Arms utility
  view suppresses their damage rows without changing the placement's compiled mask.
- Deliberate waits retain ownership; disabled actions release their planning reservations.
  Adaptive follows the registry's behavior contract regardless of the physical class thread.

The evaluator is `jungle.warriorAdaptive`, registered directly. It never wraps Original, Arms, maintenance or Sweeping. Steps shows all of Adaptive's own PvE/PvP and AoE actions, with no Original/Fury substitute sections. Explicitly configured maintenance has its own switches and remains independent.

## Adaptive PvP utilities

Interrupts and Slam cancellation, Charge/Intercept and their stance preparation keep
Original conditions and priority. Hamstring/Piercing Howl keep the Original slow,
immunity, refresh, Evasion and area interval checks. An immediate planned Slam remains
above slows; slows can precede other damage and short swing waits. Overpower, Thunder Clap,
Sunder, the chosen shout and default stance keep their Original eligibility and relative
positions around the selected core action. PvE support switches do not replace these rules.

Demoralizing Shout is an explicit PvP addition: a melee fallback after core attacks and
queues, before Sunder/shout, when Demo is missing or has at most five seconds remaining.
It reuses the established maintenance refresh rule, Original Demo preference and action
switch. It does not fill a reserved Slam swing wait or an active GCD. The existing Arms
PvP table had no automatic Demo row; this addition follows the requested PvP behavior.

**Bloodrage, Berserker Rage, Death Wish and trinkets are always disabled in Adaptive PvP**,
including Overpower's Berserker Rage preparation. Checking their Steps or PvE options
cannot enable them in PvP. Recklessness also retains its PvE-only restriction.

## Automatic context

Enemy observations use nameplate add/remove events and GUID deduplication including
the selected target. On reload, verified `nameplate1` through `nameplate40` tokens
bootstrap the registry; frame-array position is never used as identity. Observations
refresh at 100 ms, immediately invalidated by plate events and target GUID changes.

One eligible enemy uses single-target planning; two or more use cleave/AoE. Boss status
is inferred from worldboss classification, a skull level, or matching an exposed boss
token. A boss with adds still uses AoE planning. The mode is visible in diagnostic state.
Skull level alone is a heuristic, not authoritative encounter identification.

Coverage is conservative: a successful Hamstring range check is required. This does
not measure Whirlwind's full 8-yard radius, nor prove which targets Sweeping will hit.
Unobserved enemies and CC outside this conservative range are not fully represented.
Observed nearby CC/immunity exclusions suppress area damage; totems do not inflate counts.
Targets below 20% health remain eligible. Direct attacks on the selected target retain
their existing distinction from area-count exclusions.

Target lifetime uses bounded, GUID-keyed health-loss samples. It remains unknown until
there is at least 1.5 seconds of damage evidence and resets after healing/window turnover.
Unknown life is not assumed to mean dying. Stale identities expire after 10 seconds.
It is an estimate: phase transitions, healing and changing group damage can invalidate it.

## PvE priority and shared core planning

1. Protect an existing cast; validate equipment, target and movement context.
2. Start attacks, close distance, and handle the existing PvE interrupt decision.
3. Cancel an inappropriate/unfunded HS or Cleave; prepare required stances.
4. Use Bloodrage, maintain the chosen shout, and perform enabled support assignments.
5. Activate funded Sweeping with 2+ eligible enemies, then enabled damage cooldowns.
6. Compare Slam, Mortal Strike, Whirlwind and Execute over two actions; manage funded
   HS/Cleave separately during their next-swing window.
7. Use an available free Victory Rush when it does not conflict with a Slam reservation.
8. Use enabled Berserker Rage in a spare combat global, with enough time before the
   next Slam swing and affordable MS/WW cooldowns. Never interrupt an active cast.

The planner uses **explicit normalized damage weights**, not a full simulator:
Slam 1.2, Mortal Strike 1.25, Whirlwind 1.0 per predicted direct target (capped at four),
Execute 1.15 plus a bounded rage-dependent increment. A Sweeping bonus is deliberately
approximate; it is not a claim about exact charge consumption or duplicate-hit behavior.
Future WW value discounts enemies predicted to die before the second action.

It scores immediate damage plus 80% of the best affordable next-action value, a small
remaining-rage value, and penalties for displaced white swings and waiting. End-of-life
spending removes the remaining-rage reward. These are tunable project heuristics, not
proven optimal weights or predicted real damage. No kill is declared from these scores.
There is no WoWSims import or live dependency in this policy.

Slam requires 2/2 Improved Slam, a confirmed mainhand swing on the current target,
reliable timing, a stationary player, and the unchanged **1.15-second** after-swing limit.
Network latency contributes a conservative margin; it is not measured end-to-end input
latency. Cast start/completion consumes the opportunity. Haste changes the lookahead
through current weapon speed; the model allows another Slam only after another swing.
Movement and unknown swing timing immediately remove Slam/wait candidates.

The only deliberate swing wait is at most 0.30 seconds for a reliable imminent swing.
There is no T3 80-rage owner or indefinite wait for a second enemy. With shrinking packs,
the next observation returns to single-target decisions and cancels obsolete Cleave.
Cheap short-pack Sweeping requires an imminent swing that can land before estimated
death; otherwise it reserves Whirlwind funding too.

Costs come from Anniversary `C_Spell.GetSpellPowerCost`, with conservative legacy
defaults if unavailable. Execute uses its minimum cost for eligibility and spends the
remaining rage in the forecast. Already queued attacks reserve their cost and contribute
no white-swing income. Future unqueued white-swing income is a conservative **10-rage
heuristic**, not a guaranteed hit/proc. Actual cast readiness always requires present
usability and resources. Cost snapshots last at most 200 ms.

Cooldown readiness distinguishes unknown/disabled from ready. Matching cooldown start
and duration to the active GCD is a guarded project heuristic, not a public contract.
The legacy shared cooldown functions are not modified.

Low-rage Overpower can use an existing GUID-matched dodge opportunity when WW is safely
away and Slam is not being sacrificed. Stance preparation is limited to 5-10 rage.

## Adaptive overlay controls

The support and cooldown rows below describe PvE. Sweeping also controls shared PvP
core planning; PvP utilities use the Original preferences and action switches described above.

| Adaptive option | Default | Behavior |
| --- | --- | --- |
| Sunder: first stack | Off | Initial Sunder on a boss or target estimated to survive 12 seconds |
| Sunder: stack/refresh | Off | Build existing stacks on durable targets; refresh at <=3 seconds |
| Demoralizing Shout | Off | Apply missing Demo or refresh at <=5 seconds on an eligible melee enemy; skip other AP debuffs and protect a usable stationary Slam |
| Thunder Clap | Off | Assigned refresh and bounded stance preparation; avoids high-rage stance loss |
| Sweeping Strikes | On | Automatic funded cleave activation |
| Damage cooldowns | On | Learned Death Wish in melee; on-use trinkets for single targets/bosses |
| Berserker Rage | On | Combat filler in Berserker Stance; reserves Slam and affordable MS/WW |
| AoE: both trinkets | On | Independent AoE use of the existing slots 13/14 macro |
| Recklessness | Off | Opt-in boss use during Bloodlust/Heroism or estimated final 15 seconds |

PvE Sunder skips Expose Armor. PvE support uses Adaptive switches; PvP Sunder/Demo
use the Original preferences. All actions also honor that placement's Steps switches.
Death Wish/trinkets favor available melee uptime. They do not predict future Bloodlust
or scripted encounter vulnerability windows; use Damage cooldowns to hold Death Wish
and single-target trinkets, and AoE: both trinkets to hold AoE trinkets. The existing
`Trinkets` action executes `/use 13` then `/use 14`; item restrictions and shared
cooldowns determine which uses succeed. This does not guarantee simultaneous activation.
An apparently ready but failing trinket intent is bounded to one second, retried after
five seconds, so it cannot permanently starve core damage. Intent never counts as success.

In PvE, Berserker Rage is treated as a **1.5-second global**, not an immediate baseline rage
grant. Its TBC effect increases rage from taking damage and provides control immunity
([TBC spell reference](https://www.wowhead.com/tbc/spell=18499/berserker-rage)).
When stationary with Improved Slam, unknown swing timing fails closed; otherwise
the remaining swing must exceed 1.5 seconds plus the input margin and no current
Slam opportunity may remain. Moving/no-Slam contexts do not reserve a Slam window.
Actual casting, GCD, stance, known spell, cooldown, usability and active aura still gate
the action. This is opportunistic utility, not encounter-aware fear prediction.

## API verification

Installed executable: **2.5.6.69795**. Addon TOC: **20504**.
Required source: Gethe/wow-ui-source, **classic_anniversary**, commit
`1463c686270b6c64e2c5c228f447c4597c0f8ba6` (commit description: `2.5.6 (69795)`).

- [UnitDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua): `UnitIsPlayer`/`UnitPlayerControlled` boolean classification and cast/channel interruptibility tuples.
- [InstanceDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_APIDocumentationGenerated/InstanceDocumentation.lua): `IsInInstance` returns the instance type used for PvP routing.
- [SpellDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua): cooldown/info/cost records, explicit usability, range boolean/nil, current/queued spells.
- [SpellSharedDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellSharedDocumentation.lua): cost/minCost, power type, aura-qualified costs.
- [NamePlateDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_APIDocumentationGenerated/NamePlateDocumentation.lua) and [Blizzard_NamePlates.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_NamePlates/Blizzard_NamePlates.lua): readable nameplate objects and authoritative unit add/remove lifecycle.
- [Classic/TargetFrame.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_UnitFrame/Classic/TargetFrame.lua): Blizzard's legacy UnitLevel/UnitClassification consumers.
- [Shared/ActionButton.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_ActionBar/Shared/ActionButton.lua): separate unusable/resource-shortage handling and structured cooldown consumption.

UI source does not settle exact rage generation, Sweeping/WW charge interactions,
post-Slam server timing, Berserker Rage spell mechanics, item shared cooldowns, range coverage or external-input latency. No live verification
is claimed. Nameplate readability does not grant secure targetability.

## Validation and bounded live checks

Standalone Lua 5.1 mocked tests cover the shared core decision matrix, actual Original
PvP utilities, Demo refresh, always-disabled abilities, queues, target loss, NPC/pet/CC
coverage, per-step masks and independent compiled placements. Differential tests compare
unaffected Original/WoWSims and PvE behavior with the exact pre-edit checkpoint. Registry,
profile, decision-state and options suites cover adjacent contracts. These checks do not
prove in-game execution, server timing or DPS gains.

1. `/reload`; check Lua errors and select **Arms — Adaptive** in `/olia options`.
   Check placement Steps, profile persistence and switching back to Original.
2. In a bounded PvP encounter, verify confirmed-swing stationary Slam, movement into
   MS/WW, single-to-multi enemy transitions, funded HS/Cleave and Sweeping.
3. Verify interrupts/cancel-Slam, gap closers, slows, TC, dodge Overpower and Demo's
   missing/<=5s refresh. Disable Demo and confirm it no longer reserves a fallback.
4. Enable all cooldown preferences and verify Adaptive PvP still never recommends
   Bloodrage, Berserker Rage, Death Wish or Trinkets. Repeat target loss and queued attacks.
5. Record 30-60 seconds using `/armslog on` and `/armslog off`; check successful casts,
   failed intents, MS/WW delays and rage starvation. Compare PvE single-target and cleave
   behavior separately. Run `/oliaperf 15` for comparable combat to measure evaluation cost.

Exact task preimages and edit hunks are retained outside the addon at
`C:\Users\freeker0k\.codex\task-checkpoints\olia-adaptive-pvp-20261005`.
No live game validation has been performed for this change.

Adaptive decisions feed the existing opt-in `/armslog` window recorder and RaidTrace
rotation reasons. In-memory `jungle.WarriorAdaptive.state` includes mode, enemy count,
resource/timing facts, selected action, reason and planner score for inspection.
No stable action mapping was changed; `/olia dump` should match the pre-change registry.
Only repeatable live outcomes can establish whether this policy outperforms another mode.


## Adaptive Charge/Intercept parity (2026-10-06)

PvE now uses the same utility-only gap-closer helper as Original Arms. PvP already
uses it through the retained Original utility projection. Outside melee range:

1. Charge out of combat when its own range and cooldown/readiness pass; prepare Battle Stance.
2. Prefer ready Intercept while already in Berserker Stance with at least 10 rage.
3. Intercept in combat or when Charge is on cooldown, including out of combat;
   prepare Berserker Stance as needed. Suppress Intercept for two seconds after Charge.

Action and stance switches remain placement-specific. Casting/channel and equipment
guards retain their authored priorities. No action IDs, bindings, profiles or catalog
identities change. The shared helper accepts reusable scratch storage for Adaptive PvE.

API reference: retained Gethe `classic_anniversary` revision
`1463c686270b6c64e2c5c228f447c4597c0f8ba6`, matching installed **2.5.6.69795**;
TOC remains **20504**. [SpellDocumentation.lua:601](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua#L601)
documents boolean/nil range results; only explicit true admits preparation.
[SpellDocumentation.lua:108](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua#L108)
and `Blizzard_ActionBar/Shared/ActionButton.lua:829` confirm the structured modern
cooldown API. The reused Original helper retains the project's legacy cooldown,
usability and range wrappers; those global signatures are not established by this
modern generated entry. GCD discrimination and the recent-Charge timer are project
heuristics. Actual range, stance macro execution and cooldown timing require a bounded
live check: `/reload`, then try PvE/PvP Charge from Battle Stance, Intercept from
Berserker Stance with 10+ rage, stance preparation, and combat immediately after Charge.
Disable each gap closer/stance and repeat; verify no stale preparation after target loss.
No live game outcome is claimed.


Mounted follow-up: the initial parity change left Adaptive's blanket `IsMounted()`
return intact. It now permits only Charge/Intercept and their stance preparation while
mounted, using the corresponding Original PvE/PvP readiness, before equipment handling.
Other mounted combat and support actions remain suppressed. The existing secure action
macros remain in use; no protected action is called from evaluation.

Out-of-combat Intercept is eligible when Charge is on cooldown, provided Intercept is
ready, the target is outside melee and explicitly in Intercept range, its action/stance
switches allow it, sufficient actual rage is available, and Charge was not used within
two seconds. Matching those conditions in mocks is not a live cast result.

The same Anniversary snapshot's generated `SpellDocumentation.lua:631` documents
usability/insufficient-power results. Its generated files do not establish the legacy
`IsMounted` signature; existing client usage remains the project's compatibility path.
`Blizzard_ChatFrameBase/Shared/SlashCommands.lua:1224` confirms dismount is a secure
command handler, but does not establish automatic dismount on Charge/Intercept.
Actual mounted spell usability and automatic dismount must be checked in-game with
the existing macro; no dismount or usability bypass is introduced by this change.


## PvE Demo eligibility correction (2026-10-06)

With both Demo switches compiled enabled, the old PvE support path still required a
boss, a >=12-second lifetime estimate, or AoE. It also suppressed Demo for any pending
Slam swing, including movement, unavailable Slam and insufficient Slam rage. Those
conditions reproduced a no-action outcome with Demo explicitly enabled.

Adaptive PvE now applies missing Demo or refreshes it at <=5 seconds on the eligible
selected melee enemy. It does not require a lifetime estimate. The stationary pending
Slam window is protected only when Slam is actually ready with sufficient rage. Demo
still honors its action and `adaptive_demo` switches, own rage/GCD/readiness, target and
totem validity, mounted/casting guards, existing Roar/Curse of Weakness/Screech, and
crowd-control-safe area coverage. Sunder/Thunder Clap remain earlier support choices;
the existing support stage's priority is preserved. Defaults, saved false switches,
routine IDs, macros and action bindings are unchanged. Original and Adaptive PvP keep
their previous Demo behavior.

The change uses existing project aura/readiness helpers, with no new client API or
event. Reference remains Gethe `classic_anniversary` revision
`1463c686270b6c64e2c5c228f447c4597c0f8ba6`, installed **2.5.6.69795**, TOC **20504**.
`Blizzard_APIDocumentationGenerated/SpellDocumentation.lua:631` documents boolean
usability and insufficient-power results. Legacy `UnitAura` access and expiry handling
are inherited from the existing Warrior helper; no new aura-signature claim is made.

Regression coverage loads actual evaluators, aura helpers, registry, compiled placements
and configuration methods. It covers enabled Demo on a moving single NPC, unknown and
short lifetime, actual/disabled/unfunded/unavailable Slam, refresh/permanent auras,
alternative AP debuffs, area exclusions, target loss, rage/GCD/casts/mounts, switches
and independent placements. These are mocked client checks, not successful game casts.
Bounded live check: `/reload`, then an ordinary PvE enemy in melee with missing Demo
and enough rage while moving; repeat stationary, refresh at <=5 seconds, and disabled
Demo. Check Lua errors and actual successful casts, and `/oliaperf 15` if measuring cost.

Exact preimages and ledger are retained outside the addon in
`C:\Users\freeker0k\.codex\task-checkpoints\olia-adaptive-demo-20261006`.


## Imported Adaptive Demo preference (2026-10-06)

The reported profile had `options.adaptive_demo=true` at Warrior class/profile level,
an enabled Demo action, and an empty Adaptive placement `options` table. Compilation
filled the missing placement option with its authored off default. Changes to spell
eligibility could not make that disabled placement recommend Demo.

`adaptiveDemoPreferenceVersion=1` imports a stored boolean profile preference into
missing Adaptive placement `adaptive_demo` options once, across selected and unselected
profiles. Explicit placement false, action false, unknown records, unrelated preferences
and higher version numbers are preserved. New placements and Reset still use the authored
off default after the import. No runtime fallback changes a saved override.

The option is now labeled **PvE: maintain Demo**, distinct from the **Demoralizing Shout**
action checkbox. Its key stays `adaptive_demo`. `/olia demo` prints the loaded diagnostic
revision, active thread/placement, active action/option flags, saved option, combat-pending
state, and last evaluated action/reason/PvP/melee/rage/GCD plus snapshot age. It is a one-shot
read-only report, without evaluating a routine or emitting an action.

This reuses the existing configuration initialization/combat deferral lifecycle and
GetTime API. Required reference remains Gethe `classic_anniversary` revision
`1463c686270b6c64e2c5c228f447c4597c0f8ba6`, installed **2.5.6.69795**, TOC **20504**.
Generated `AddOnsDocumentation.lua:368` and the matching `Blizzard_FrameXML/GhostFrame.lua`
consumer establish ADDON_LOADED usage; `UnitDocumentation.lua:2352` and
`Blizzard_RestrictedAddOnEnvironment/SecureStateDriver.lua` establish the existing
PLAYER_REGEN_ENABLED lifecycle. `Blizzard_ChatFrameBase/Shared/SlashCommandsRegistry.lua:49`
and `ChatFrameEditBox.lua:259` confirm callback registration/dispatch; the Classic
`ChatFrameOverrides.lua:519` uses the existing GetTime clock. No new client event or
protected API is introduced.

Verification reproduces the exact saved-profile shape before the fix, then checks
compiled flags and actual moving Adaptive selection, all-profile import, explicit false,
action masks, reload idempotence, higher versions, class isolation and diagnostics.
Live check: `/reload`, inspect **PvE: maintain Demo**, then `/olia demo` immediately after
the failing encounter if Demo still does not cast. These diagnostics distinguish actual
compiled state from the overlay and old SavedVariables snapshots.
