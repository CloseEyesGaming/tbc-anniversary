# Kebab

After `/reload`, open `/olia options`, choose a class thread (1-6), and use
**+ Add routine > Kebab**. Move it ahead of other combat routines if it should
own that thread. Existing profiles/defaults are unchanged. An earlier placement
may select an action or hold before Kebab is reached.

Kebab owns PvE single-target and AoE dual-wield Arms with learned Mortal Strike and no
Bloodthirst. Missing DW equipment, PvP, controlled enemies and totems release the
placement. Two or more safe observed eligible melee enemies select its AoE branch. It never substitutes another
algorithm, swaps weapons, uses Slam/Overpower, or stops attacks for desynchronization.
Without an enemy it can clean an observed HS or carried Cleave queue, then maintain the selected shout. Moving in melee does not block
instant attacks. Ordinary gap closers and the shared PvE interrupt observation retain
their guarded eligibility. No consumable/racial/profession actions or new bindings
are introduced; use those manually through the client's existing controls.

## Single-target rage and priority

Readiness requires a learned spell, explicit usable=true, no resource shortage,
real cooldown readiness and appropriate range/stance. GCD attacks require a ready
global. Paid next-swing HS remains available while the GCD runs.

1. Protect casts/channels; validate spec/equipment/enemy/context. Required factual
   queue cleanup, gap closers, interrupts and stance/autoattack preparation retain
   their guarded priority. Low rage alone never cancels HS/Cleave.
2. Assigned Demo: missing or <=5 seconds, ready and safe to apply. Runs before
   damage, burst, self shouts, SS pooling and new queues, including Execute and
   existing HS/Cleave queues. Uses its own current-rage cost without a core reserve
   or core-gap condition. Skip other AP-reduction coverage and excluded enemies.
3. Assigned Sunder: either **Init Sunder Armor** or **Stack Sunder Armor** applies a
   missing first stack or refreshes at <=3 seconds, including five stacks and
   Execute. Skip Expose Armor. Uses current rage without reserving a core attack.
   Init never builds healthy stacks; refreshing a live debuff may add a stack.
4. After maintenance, ready Normal MS/WW spends actual rage before self buffs,
   burst and new HS admission, whether or not HS is queued. MS wins simultaneous
   readiness; an affordable WW never waits for an unaffordable MS. Permitted Execute
   cores retain their early priority with HS queued. No cancellation releases rage.
5. Proactive off-GCD Bloodrage at <=90 rage; off-GCD trinkets remain available
   while pooling or during the GCD, below ready cores. Normal shouts, Death Wish
   and opt-in boss Recklessness require a ready GCD and a full >=1.5s core gap.
   Paid ordinary buffs retain exact upcoming/next core funding plus any already
   funded queued HS payment. Bloodlust/Heroism alignment and bounded retries remain.
6. Berserker Rage remains opt-in outside Execute in a >=1.5s core gap. Normal
   single-target HS admission precedes it; AoE retains its existing utility order.
   It is a GCD utility, not an assumed immediate rage grant.
7. Standard Normal HS admission uses its action switch, including during the GCD.
   Queue temporarily while pooling with confirmed matching MH timing; let it fire
   only when actual HS cost plus all upcoming core costs are funded. No extra rage
   buffer or 40-rage floor. Exact policy and fallback below. Execute is unchanged.
8. Normal damage: MS before simultaneously ready WW. Do not wait for an unavailable
   MS when WW can be used. Current rage funds abilities with either queue present.
9. Execute: MS opt-in, WW enabled by default; each funded core retains minimum
   Execute cost +5. Otherwise Execute spends rage. HS remains separately opt-in.
10. Free Victory Rush in a >=1.5s core gap, then **Stack Sunder Armor** can build
    healthy stacks 1-4 in the same safe gap. Normal single target retains the
    greater of the upcoming HS core reserve and next enabled core cost, plus an
    already funded queued HS payment, without a rage buffer. AoE/Execute retains its existing next-core cost +5. This filler
    never outranks a ready core or Execute.
    Both Sunder preferences can be checked; Init does not suppress Stack filling.
11. Normal single-target Hamstring follows safe Sunder stacking, with a >=1.5s
    core gap and actual Hamstring cost plus the same exact filler core reserve; no
    extra rage buffer or 40-rage floor. The aggressive cap exception is retired;
    the full >=1.5s gap applies even at 90-100 rage and to old saved opt-ins.

Normal HS payment reserves each enabled MS/WW whose own cooldown is due at or
before the next possible white MH after paying the upcoming HS: confirmed MH time
remaining plus the current MH weapon period. Each cooldown is checked independently;
a shared GCD never pushes the second ready/closely due core out of the budget.
Both ready cores therefore retain 55 rage even with a 1.5s GCD, and 12-rage HS
requires 67 for payment. Only actual costs are added; no predicted OH/crit/damage-
taken rage is credited. This does not promise rage from that later white swing.
Disabled, unknown or area-blocked cores reserve nothing. With unknown/unmatched
MH timing, paid admission conservatively reserves both enabled cores; temporary
admission is unavailable. Normal fillers also retain the next enabled core cost,
so a future core is protected even beyond this payment horizon.

AoE and Execute keep their pre-refactor budgets: the earlier enabled core within
MH time remaining + 1.5s (1.5s if unknown), with Execute minimum cost +5 where
applicable. These are project policies, not proof of optimal DPS or future rage.

Nearby observations use verified nameplate add/remove tokens, GUID deduplication,
totem/controlled exclusions and conservative Hamstring range. An excluded observed
enemy suppresses new SS/Cleave/Demo while selected-target direct attacks remain possible.
Whirlwind has a separate control-safety check: Ice Block, Divine Shield, Blessing
of Protection and Divine Intervention alone do not veto WW. Those enemies still
stay out of the AoE count, so Kebab uses single-target priorities when fewer than
two eligible enemies remain. Protected control debuffs and Mind Control still
block WW, including when an immunity buff is present at the same time.
This does not measure the full WW radius or guarantee complete CC coverage.

The 2026-10-16 immunity exception is project policy, not a claim that WW can damage
an immune unit. Installed build 2.5.6.70006 and TOC 20504 remain the target.
Existing aura access was rechecked against Anniversary revision
`2cfec7c00f0f24762d5ca35a4beb1e93c0cde328`:
[UnitAuraDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/2cfec7c00f0f24762d5ca35a4beb1e93c0cde328/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua#L156)
defines indexed unit/filter access and a nullable aura result;
[Blizzard_BuffFrame/BuffFrame.lua](https://github.com/Gethe/wow-ui-source/blob/2cfec7c00f0f24762d5ca35a4beb1e93c0cde328/Interface/AddOns/Blizzard_BuffFrame/BuffFrame.lua)
is the matching Blizzard consumer. The exception uses the existing localized-name
lists and aura cache; it adds no client API/event. Live checks: attack a vulnerable
PvE target beside each immune enemy and confirm WW; add protected control and
confirm WW suppression; remove auras and confirm normal AoE resumes. A
PLAYER_ENTERING_WORLD bootstrap verifies explicit nameplate1-40 tokens, independently
of frame-array positions. Observations are shared facts; decisions/trinket retries
live in each compiled placement's state. Recompile/thread changes clear those plans.

## PvE AoE policy and research

AoE activates at **2+ observed eligible melee enemies with no excluded observation**.
It retains Kebab's DW Arms/PvE eligibility, utility, assignments and burst controls.
These branches use the existing Cleave and Sweeping Strikes action slots; bindings,
macros, pixel identities, defaults and existing saved preferences are unchanged.

1. Clean carried HS, or Cleave that is disabled, unsafe or Execute-disallowed.
   Low rage or an unfunded future reserve alone never cancels Cleave.
2. Shared interrupt/stance and autoattack, then urgent Demo/Sunder maintenance
   before Bloodrage, self shout and burst, including Execute.
3. Learned/enabled Sweeping Strikes without an active aura: pool actual cost + the
   imminent enabled core cost + 5. Execute also retains minimum Execute + 5.
   A ready but unfunded SS deliberately holds damage; an unavailable, disabled or
   future-cooldown SS never creates this pool. SS uses the existing off-GCD policy.
4. Funded paid Cleave, including during the GCD: rage >=max(40, Cleave cost + the
   enabled SS/core/Execute reserve + 5). No temporary Cleave/HS queue cycling.
5. Whirlwind before Mortal Strike. Abilities use actual current rage with Cleave
   queued. MS protects imminent WW, without reserving an unqueued Cleave into
   an idle tick. Existing Execute MS/WW
   preferences still apply; WW retains minimum Execute + 5 before Execute spends.
6. Execute Cleave is separately opt-in and uses the protected budget. No AoE Hamstring.
   Urgent Demo/Sunder retains its high priority. Free Victory Rush precedes
   safe healthy Sunder stacking; spare Berserker Rage retains its Normal gap guard.

Fewer than two eligible enemies immediately restore single-target priority after
obsolete Cleave cleanup; there is no wait for SS to expire or become available.
Excluded nearby observations block new SS, WW, Cleave and Demo; direct attacks remain
possible. A previously active SS aura can still duplicate direct/auto attacks, so
this observation guard is not a guarantee against breaking CC. Nameplate/Hamstring
coverage also cannot prove the full area is safe. Lost target/range/spec/context
cleans observed Cleave before release, protecting active casts/channels. Queue facts
survive decision resets; intent alone does not establish execution.

Research compared the dedicated DW Arms AoE priority in the
[TBC Warrior rotation guide](https://www.wowhead.com/tbc/guide/classes/warrior/dps-rotation-cooldowns-abilities-pve)
with [Arms AoE guidance](https://www.warcrafttavern.com/tbc/guides/pve-arms-warrior-rotation-cooldowns-abilities/).
Both favor SS, WW and Cleave; the DW-specific guide makes MS spare-rage damage.
The latter places MS higher during active SS. This implementation selects the
conservative WW/Cleave funding approach across both aura states; no encounter/gear
simulation establishes that it is optimal. Existing single-target MS-before-WW
behavior is intentionally retained even though the DW guide favors WW there too.

Primary model evidence: the pinned
[TBC simulator WW implementation](https://github.com/wowsims/tbc-new/blob/7a957f8a20b4b3386852edc7176df8ee65c36def/sim/warrior/whirlwind.go)
models both DW weapons and a four-target cap, supporting WW's AoE value. It does not
prove Anniversary server behavior. [TBC SS spell data](https://www.wowhead.com/tbc/spell=12328/sweeping-strikes)
and the existing WoWSims evaluator use off-GCD SS. Exact GCD/cost/charge interactions,
pool thresholds and realized damage require the bounded live check below; generated
Blizzard UI docs define API shapes rather than server damage mechanics.

Bounded live check: two/three-enemy trash with comparable gear, 30 MH cycles, first
with SS/Cleave switches off, then on. Record rage, SS success, WW delays, Cleave hits
and Execute starvation; exercise a count drop, CC observation, target/range loss,
disabled SS/Cleave, and phase transitions. Confirm SS can execute during a running
GCD and its observed cost before tuning thresholds. Use `/combatlog` only for those
samples and `/oliaperf 15` for representative AoE evaluation cost. No live result
or DPS improvement is claimed from mock tests.

## Overlay controls

Steps has two PvE blocks: **PvE Single target** and **PvE AoE**. Each includes
its Execute actions, with phase/assignment/safety requirements beside the actions
and in the section tooltip. Targetless shout/cleanup is described under Single
target; excluded enemies also use its direct-action guards. PvP remains unavailable.
There are 23 optional action identities and required Queue cleanup (Stopcasting).
Repeated actions share the same per-placement switch. Disabling an action removes
its future preparation/reservations; all optional actions off releases ownership.
Demo and Berserker Rage require both their action step and matching preference.
Demo and missing/expiring Sunder appear before damage. Healthy Sunder stacking
uses that same action switch but runs later as a safe filler. After urgent
maintenance, a ready single-target core with HS queued keeps its early priority. Queues use no GCD and
have not spent rage, while a GCD ability still requires a ready global. These are
guarded decisions, not an unconditional cast sequence. No HUD-specific evaluator
or duplicated saved switches are added.
Default shout is selected through **More**. Preferences are independent per placement:

| Preference | Default |
| --- | --- |
| Execute: retain Mortal Strike | Off |
| Execute: retain Whirlwind | On |
| Execute: allow paid Heroic Strike | Off |
| AoE Execute: allow paid Cleave | Off |
| Init Sunder Armor | Off |
| Stack Sunder Armor | Off |
| Maintain Demoralizing Shout | Off |
| Automatic Death Wish / trinkets | On |
| Hold damage cooldowns for Bloodlust | Off |
| Allow boss Recklessness | Off |
| Spare-global Berserker Rage | Off |

The Bloodlust hold may wait indefinitely when no Bloodlust/Heroism arrives. It gates
only damage cooldowns, not the core rotation. Recklessness also requires its own
preference and a recognized boss. Action switches still gate every preference.
Per-placement settings save through the existing profile API; combat edits apply
only after combat. Kebab uses the accepted `original` compatibility mode token with
its own fixed named `kebab` behavior/evaluator, registered after legacy expansion.
It has no legacy variant migration or implicit default placement.

## Standard Normal single-target HS queue/cancel (2026-10-14)

The Heroic Strike action switch now owns this behavior automatically. The retired
`mainhand_queue` preference is no longer displayed or compiled; existing raw saved
values are preserved and ignored. The `aggressive_filler` preference is also
retired with its raw historical values preserved. There are 11 current preferences. No profile
replacement or new action/binding is required. AoE and Execute keep their own policy.

1. Ready affordable MS, otherwise ready affordable WW, runs before new HS admission,
   self buffs and burst, after required cleanup/interrupt/stance/attack and assigned
   Demo/Sunder maintenance. Use actual current rage with HS observed; its cost has
   not been paid and is never subtracted from available rage.
2. Otherwise queue HS whenever explicitly usable. A fully funded queue can enter
   at any swing phase. Temporary admission needs combat/melee/Berserker Stance,
   autoattack, a confirmed MH cycle for this target, >0.9s remaining, and no previous
   cancellation in that same cycle. It has no paid-core admission reserve.
3. Re-evaluate payment every tick: HS cost + every enabled core whose own cooldown
   is due before the next possible normal MH. A shared GCD does not exclude a
   second ready/closely due core. For 12-rage HS, MS=30 and WW=25: MS only **42**,
   WW only **37**, both **67**, neither **12**. There is no extra rage buffer/floor.
   Actual spell costs, current haste period and independent cooldowns drive payment.
   The GCD gates execution and optional buff admission, not a core cost exclusion.
4. Retain a funded queue through MH. Retain an unfunded queue while pooling outside
   the cancellation deadline. At <=0.6s before MH, cancel affordable unpaid HS unless
   a ready affordable core takes priority. Lost matching timing/autoattack/combat
   also closes the temporary window. The lead/headroom are timing safeguards,
   not extra rage. Below actual HS cost, keep observing; no rage-only cancellation.
5. Cancellation intent is not confirmation. Retry while the queue is observed; do
   not admit another temporary queue in the cancelled MH cycle, even if haste
   extends it. A new confirmed cycle reopens temporary admission. Full funding may
   admit paid HS within the old cycle. Target loss, invalid context, disable,
   incompatible AoE/Execute and casts/channels retain their factual cleanup guards.

Queuing cannot guarantee continuous payment and on-cooldown cores when rage income
is insufficient. A paid HS also replaces a white MH's rage generation; that lost
income is why the payment horizon extends to the following possible white MH.
Extra attacks, delayed input and frame stalls can still spend HS before cancellation.
No OH timer or stop/start desynchronization is added.

The [TBC simulator queue model](https://github.com/wowsims/tbc-new/blob/7a957f8a20b4b3386852edc7176df8ee65c36def/sim/warrior/heroic_strike_cleave.go#L81)
removes the extra DW miss penalty while queued. Cancellation removes that model
benefit; it does not establish a free non-missing white MH. Base miss, dodge and
parry remain separate. This is model evidence, not a verified Anniversary server
contract. Exact queue-indicator clearing below HS cost remains a live gap.

Bounded live check after `/reload`: use the same PvE enemy/gear, record 30 normal MH
cycles with `/combatlog` and `/kebabcheck`. Inspect `hsReserve`, `hsThreshold`,
`hsHorizon`, current rage, queue indicator and MS/WW delays. Exercise 41/42, 36/37,
66/67 payment boundaries with suitable cooldowns, queue while pooling at 12-24 rage,
then reach 30 for MS or 25 for WW and verify success without a prior cancellation.
Check the 0.6s cancellation boundary, failed/delayed cancellation, haste, target
loss, disabled HS/core steps, below-cost rage and AoE/Execute transitions. Compare
paid HS/rage starvation and all swings/misses, not only the existing miss-only log,
which cannot prove pre-hit queue state. Stop `/combatlog` after the bounded probe.
No live result is claimed here.

API reference rechecked against installed **2.5.6.70006**, TOC **20504**, required
`classic_anniversary` revision `2cfec7c00f0f24762d5ca35a4beb1e93c0cde328`.
Existing C_Spell cooldown, cost, usability and queue contracts remain unchanged.
The legacy MH/OH return order is consumed by Blizzard's
[Blizzard_CharacterFrame/TBC/PaperDollFrame.lua:621](https://github.com/Gethe/wow-ui-source/blob/2cfec7c00f0f24762d5ca35a4beb1e93c0cde328/Interface/AddOns/Blizzard_CharacterFrame/TBC/PaperDollFrame.lua#L621)
and speed display at line 733; generated Unit documentation lists the speed-change
event, not this legacy function signature. The evaluator reads the same existing
UnitAttackSpeed call's first result for current MH period. Matching tracker timing
and 1.5s scheduling remain project policy; source does not prove queue cancellation
latency or server hit-table behavior. Retained references/hashes are beside the ledger.

Earlier smart-HS refactor verification (before the close-core guards below):
all 80 addon/test Lua files parse under
Lua 5.1. WarriorKebab passes 1,646 checks; WarriorKebabUI passes 451 checks.
RoutineBehavior, RoutineDecisionState, RoutineIsolation, RoutineDispatchViews,
RoutineViews, RoutineSteps and RoutinePerformance pass. Exact pre-edit Warrior
behavior comparison passes 4,221 compiled evaluations; Kebab's own suite also
compares unchanged AoE/Execute decisions against this task's immediate preimage.
Isolated 10,000-call paid/temporary/queued-HS/AoE warm evaluator checks allocate
0.062/0.062/0.000/0.056 KiB respectively; generic dispatch allocates 0 KiB. These
are mocked checks, not live performance, successful casts or DPS measurements.

Checkpoint and exact hunk ledger:
`C:/Users/freeker0k/.codex/task-checkpoints/olia-kebab-smart-hs-20261014`.

## Close-core and optional-spend guards (2026-10-14)

This follow-up fixes all three reviewed failures in Normal single-target PvE:

- Both ready cores behind a 1.5s GCD, MH due in 0.2s: reserve MS+WW=55; 42 rage
  cannot pay a 12-rage HS. Temporary admission still works with >0.9s headroom.
- With MS/WW due in 0.1/0.2s, ordinary shouts/Death Wish/Recklessness wait instead
  of starting a fresh GCD. A full 1.5s gap is required; urgent assigned Demo/Sunder
  priorities are unchanged. Genuine off-GCD Bloodrage and trinkets remain available.
- A queued, funded HS at 67 rage with both cores due is protected from Hamstring
  and healthy Sunder spending. They need their own actual cost in addition: 77 for
  10-rage Hamstring, 82 for 15-rage Sunder, with the same 12/30/25 example costs.
  Ordinary paid buffs use the same reserve. No extra rage buffer is added.

Optional Normal spending retains the greater of the upcoming two-core reserve and
next enabled core cost, then adds actual HS cost only if HS is factually queued
and already funded. This prospective optional-spend budget never subtracts queued
cost from actual rage used by ready cores or urgent assignments. An unfunded
queue stays temporary and follows its existing MH deadline. All optional GCD
fillers require a full >=1.5s gap after any remaining current GCD; the final
readiness tolerance cannot overlap a core deadline. The aggressive Hamstring
exception is removed.
No cancellation margin, OH timer, binding, routing or AoE/Execute budget is changed.

The HUD still has two compact PvE blocks, 23 optional action identities and required
queue cleanup, now with 11 active preferences. It explains independent close-core
funding, exact HS payment examples, buff gap guards and protection of funded HS.
Neither retired preference is displayed/compiled; raw values survive profile copy
and reload. `/kebabcheck` additionally reports `optionalReserve` and `utilityGap`.

API evidence stays pinned to required `classic_anniversary` revision
`2cfec7c00f0f24762d5ca35a4beb1e93c0cde328`, installed **2.5.6.70006**, TOC **20504**.
No new API/event is added. See the SpellDocumentation/SpellSharedDocumentation,
ActionButton and TBC PaperDollFrame paths linked in the preceding provenance notes.
Cooldown/resource arithmetic and the 1.5s optional-action admission are project
policy. Trinkets remain off GCD per the user's confirmed behavior; they are not
subject to the ordinary buff gap. Queue resolution/cancel timing still needs live
verification; no static check establishes actual server ordering or DPS.

After `/reload`, inspect the HUD and use `/kebabcheck` in bounded combat: both cores
ready behind a GCD at 42/66/67 rage, cooldown gaps 0.1/0.2s and 1.49/1.5s, funded HS
at 67 with Hamstring/Sunder enabled, buff spending at 76/77, off-GCD trinkets during
a locked GCD, and target/phase/action-switch changes. Verify both core successes,
queue persistence and cancellation, not just emitted intents. Check `/oliaperf`
under comparable combat conditions before claiming any live performance change.

Verified final sources: all 80 addon/test Lua files parse under Lua 5.1;
WarriorKebab passes 1,863 checks and WarriorKebabUI passes 453. Regression probes
against the exact preimage reproduce the three old failures and confirm the new
55-rage clustered reserve and optional holds. The suite exercises core payments
across successive GCDs without invented rage, exact optional spending boundaries,
GCD remainders, disabled actions, retired saved keys, reload and off-GCD trinkets.
RoutineBehavior, RoutineDecisionState, RoutineIsolation, RoutineDispatchViews,
RoutineViews, RoutineSteps and RoutinePerformance pass; unrelated Warrior behavior
comparison passes 4,221 compiled evaluations. The Kebab suite also compares the
unchanged AoE/Execute branches against this turn's immediate preimage. Four isolated
10,000-call warm evaluator checks allocate 0.062/0.062/0.000/0.056 KiB for paid,
temporary, queued-HS and AoE respectively; dispatch allocates 0 KiB. These checks
use mocked client APIs and do not establish live spell execution or performance.

Exact preimages and hunk ledger:
`C:/Users/freeker0k/.codex/task-checkpoints/olia-kebab-core-guards-20261014`.

## Evidence and Anniversary API provenance

The initial policy was informed by [Kcaws Naj'entus](https://fresh.warcraftlogs.com/reports/kmxbDrtcnWPGBCdw?fight=57&type=casts&source=7),
[Teron](https://fresh.warcraftlogs.com/reports/kmxbDrtcnWPGBCdw?fight=83&type=casts&source=7), and
[Mother Shahraz](https://fresh.warcraftlogs.com/reports/kmxbDrtcnWPGBCdw?fight=104&type=casts&source=7).
The Naj'entus rage plot shows high-rage/cap pressure before Execute and repeated
depletion afterwards. Cast timing shows conservative gaps with occasional aggressive
Hamstrings; Execute damage events recover activations missing from the Casts table.
Plotted samples are not necessarily pre-payment/queue-time resources. One player's
three kills do not establish optimum thresholds or a general top-player policy.

Installed executable checked: **2.5.6.70006**, addon TOC **20504**. Required source:
Gethe/wow-ui-source `classic_anniversary`, revision
`2cfec7c00f0f24762d5ca35a4beb1e93c0cde328` (`2.5.6 (70006)`).
The AoE extension rechecked the executable and TOC and re-downloaded the pinned
Spell/SpellShared documentation, Blizzard_NamePlates and ActionButton consumers.
Exact pre/post images, hunk ledger, reference hashes and verification scripts are
retained at `C:/Users/freeker0k/.codex/task-checkpoints/olia-kebab-aoe-20261014`.
It introduces no new client API or event; spell mechanics still need the bounded
live probe described above.

- [SpellDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/2cfec7c00f0f24762d5ca35a4beb1e93c0cde328/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua): structured cooldowns, power costs, explicit usability, current/queued spell and boolean/nil range contracts.
- [Blizzard_ActionBar/Shared/ActionButton.lua](https://github.com/Gethe/wow-ui-source/blob/2cfec7c00f0f24762d5ca35a4beb1e93c0cde328/Interface/AddOns/Blizzard_ActionBar/Shared/ActionButton.lua#L674): current-action checked/attack display is a UI observation. It does not document server hit-table persistence or cancel latency. Existing secure HS/Stopcasting macros are unchanged.
- [SpellSharedDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/2cfec7c00f0f24762d5ca35a4beb1e93c0cde328/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellSharedDocumentation.lua): cost/minCost and aura-qualified records. `isOnGCD` is not trusted in polling; matching GCD start/duration is a guarded heuristic.
- [Blizzard_NamePlates.lua](https://github.com/Gethe/wow-ui-source/blob/2cfec7c00f0f24762d5ca35a4beb1e93c0cde328/Interface/AddOns/Blizzard_NamePlates/Blizzard_NamePlates.lua): authoritative nameplate add/remove event payloads and unit lifecycle.
- [UnitDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/2cfec7c00f0f24762d5ca35a4beb1e93c0cde328/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua): unit classification contracts; existing project utility/legacy wrappers remain.

UI/API source does not settle exact server rage generation, next-swing cancellation
timing, external input latency, proc interactions, trinket shared cooldowns or DPS.
Legacy globals absent from generated docs are retained as existing project usage,
not claimed newly verified public contracts. No protected API or secure attributes
are changed by this routine.

## Validation and live checks

Standalone `tests/WarriorKebab.test.lua` exercises the actual evaluator, catalog and
fixed action registries with mocked target/stance/rage/GCD/cost/cooldown/swing states,
step masks, placement state, queue cleanup, excluded enemies, burst, assignments,
target loss and disabled ownership. `WarriorKebabUI` exercises actual overlay controls
and profile persistence semantics. Existing configuration/UI/routing/branch suites
and differential parity protect neighboring routines. Tests are outside the TOC.

After `/reload`: inspect Lua errors and **Add routine > Kebab**; open all Steps
sections/preferences and verify per-placement switches, More/shout, combat deferral
and profile reload. On a controlled PvE target exercise low/high rage, GCD HS,
carried Cleave/HS cleanup, normal/Execute transitions, disabled core actions, target
loss/reacquisition, nearby excluded enemies, 2+ eligible enemy AoE and count-drop transitions. Observe
actual MS/WW delays, HS hits and resource starvation before comparing DPS. Verify
Bloodrage/cooldown execution and failed-item retry behavior. Use `/oliaperf 15` in
representative combat; static/mocked checks do not establish live performance.

Read-only decision snapshot: `jungle.RoutineContext.state` while evaluating contains
phase, action/reason, rage, queuedCost, msCD/wwCD, reserve, swing,
paidHS, temporaryHS, readyCoreCost, queueWindow, cancelLead, queueCycle/cancelCycle, aoe, enemies
and unsafeArea. RaidTrace rotation reasons use `kebab_*`. No unbounded combat log or
new SavedVariables are added.

Current maintenance priority (2026-10-14): enabled Demo and missing/<=3s Sunder
run before damage in both Normal and Execute. Berserker Rage retains its Normal
safe-gap policy. Defaults and saved preference keys are unchanged.
Rechecked installed 2.5.6.70006 / TOC 20504 and retained classic_anniversary
revision `2cfec7c00f0f24762d5ca35a4beb1e93c0cde328`: generated
`SpellDocumentation.lua` (explicit usability/cooldown) and
`Blizzard_ActionBar/Shared/ActionButton.lua` (current-action UI observation).
No API, event, macro or binding changes. Regression tests reproduce the old HS
starvation and exercise ST/AoE utility priority, masks, funding and excluded contexts.
Live outcome still requires reload and a controlled combat check with both preferences on.

Read-only `/kebabcheck` reports the current thread's compiled Kebab switches versus
saved preferences, the last actual decision and its age, core/GCD/rage/queue state,
shared Warrior debuff observations, spell usability/cooldown and actual key/macros.
Run on a melee PvE target while the abilities are missing. It never evaluates a
routine, changes options, emits intent or casts. `saved=nil` means the catalog
default applies (both preferences default false); pending combat edits are shown.
API reference remains classic_anniversary 2cfec7c00f0f24762d5ca35a4beb1e93c0cde328,
installed 2.5.6.70006 / TOC 20504: SpellDocumentation.lua and the existing
ActionButton current/usability observation contracts. Legacy spellbook/aura
wrappers remain existing client usage and require live confirmation.


Queue/HUD audit (2026-10-14): queued cost is diagnostic only; `UnitPower` is
the current resource snapshot for all abilities. Removed resource-only Cleave
cancellation and MS's reserve for a Cleave that is not queued. Context gates
whether Cleave may remain queued; explicit usability/cooldown gates new admission,
so a transient readiness change does not cancel a factual permitted queue. New HS/Cleave
admission still protects SS/core/Execute funding. Demo remains opt-in but now
maintains high priority without core funding/gap/phase restrictions. Berserker
Rage retains its opt-in Normal 1.5-second gap. Defaults were not changed.

Reference rechecked against the retained classic_anniversary revision
`2cfec7c00f0f24762d5ca35a4beb1e93c0cde328`, installed 2.5.6.70006, TOC 20504:
`Blizzard_APIDocumentationGenerated/SpellDocumentation.lua:436` distinguishes a
current/queued spell observation, `:631` documents explicit usability/shortage;
`Blizzard_ActionBar/Shared/ActionButton.lua:674-695` observes current state and
usability separately. Generated docs do not specify the server's next-swing rage
payment time; current-rage policy also follows the user's live observation.
Checkpoint and exact hunk ledger: `C:/Users/freeker0k/.codex/task-checkpoints/olia-kebab-queue-hud-20261014`.

Bounded live check after `/reload`: inspect `/olia options` for the two blocks;
enable both the Demo/Berserker Rage action and preference, then use `/kebabcheck`
on a melee PvE enemy with HS queued and on safe two-enemy trash with Cleave queued.
Observe successful utility casts, actual rage/GCD updates, WW with 25 rage and
Cleave queued, and no rage-only cancellation. Check Execute opt-ins, a count drop,
excluded nearby enemy and target loss; queue observations should persist until
the client clears them. Mocked checks do not establish actual cast or HUD rendering
success. Use `/oliaperf 15` for representative combat profiling if needed.


Assigned maintenance update (2026-10-14): Demo priority precedes Sunder priority.
Both Sunder modes independently initialize or refresh at <=3 seconds; Stack mode
also builds healthy stacks up to five as funded filler after cores/free Victory
Rush and before Hamstring. Required cleanup/interrupt/stance preparation stays
ahead of maintenance. Step/preference masks still gate every path, and unchanged
option keys `sunder_initial`/`sunder_stack` preserve saved profiles.
Exact checkpoint/hunk ledger: `C:/Users/freeker0k/.codex/task-checkpoints/olia-kebab-maintenance-20261014`.
No client API/event/protocol changes. Existing aura helper/API reference remains
classic_anniversary `2cfec7c00f0f24762d5ca35a4beb1e93c0cde328`, installed
2.5.6.70006 / TOC 20504. `Warrior.lua:GetArmorDebuffState` observes stack count and
expiry; permanent expiry is represented as 999. Mock checks include the real helper.
After `/reload`, verify missing/five-second Demo; each Sunder mode alone on a fresh
target; three-second refresh at one/five stacks; and healthy stacking behind MS/WW
with HS/Cleave queued in single-target/AoE/Execute. Check Expose Armor and disabled
steps. Use `/kebabcheck` for Demo decisions. Live cast/aura timing remains unverified.
