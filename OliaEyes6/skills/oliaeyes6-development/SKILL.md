---
name: oliaeyes6-development
description: Investigate, plan, develop, debug, refactor, verify, and safely roll back work whose primary artifact is the OliaEyes6 World of Warcraft Classic Anniversary addon, including its pixel/key protocol, secure-focus flow, rotations, timing, follower behavior, and performance. This includes read-only verification against matching Blizzard source outside the addon directory. Do not apply it as generic World of Warcraft addon guidance.
---

# OliaEyes6 development

Work on OliaEyes6 as a real-time pixel-to-hotkey automation engine for the Classic Anniversary/TBC client. Preserve its external protocol and live combat behavior before improving structure or style.

For routine/configuration/overlay work, also read [the routine and overlay authoring skill](../oliaeyes6-routines-overlay/SKILL.md). It describes the registry-driven contract introduced on 2026-10-04. Current code and the user's latest instructions take precedence over historical thread baselines below.

## Establish truth before changing code

Kebab (`warrior.kebab`, `Routines/WarriorKebab.lua`) is an independent PvE single-target/AoE DW Arms definition. Its two PvE blocks (Single target and AoE) include Execute controls and inline phase/safety/no-enemy explanations, sharing per-placement action masks and preferences; it has no fallback algorithm, Slam, Overpower, desynchronization or equipment swapping. Register it after legacy variant expansion with its named `kebab` behavior and the accepted `original` compatibility mode token. Keep core/queue/filler reservations enabled-action aware, required factual queue cleanup, optional Execute core choices, and all 23 optional steps / 11 preferences synchronized. Safe AoE uses funded Sweeping Strikes, paid Cleave and WW before spare-rage MS; MS protects imminent WW without reserving an unqueued Cleave; count drops resume single target without a Sweeping wait, and excluded observations suppress SS/Cleave/Demo. Kebab WW separately preserves control safety: immunity-only Ice Block/Divine Shield/Blessing of Protection/Divine Intervention excludes enemies from AoE counting without vetoing WW; protected control still vetoes WW, including combined control/immunity. Execute Cleave is separately opt-in. Normal single-target HS queue/cancel is standard under the HS action switch. Retire the old mainhand_queue and aggressive_filler preferences from active controls/compilation while preserving raw historical saves. Ready affordable Normal MS/WW precedes new HS, self buffs and burst after assigned maintenance. Paid HS reserves the actual costs of every enabled core independently due by cooldown before the next possible normal MH (remaining MH + current period); a shared GCD never excludes the second ready/closely due core, with no rage buffer or 40-rage floor. Unknown/unmatched timing conservatively reserves both enabled cores; temporary admission still requires confirmed matching timing. Normal optional spending retains the greater of this upcoming-core reserve and the next enabled core cost, adding actual HS cost when it is factually queued and already funded, with no extra rage buffer/floor. Ordinary Normal GCD buffs require a ready GCD and full >=1.5s core gap; genuine off-GCD Bloodrage/trinkets remain available. Every optional GCD must fit a full >=1.5s after any remaining current GCD, even at rage cap; preserve retired aggressive_filler values only in raw saves, never active compilation or controls. AoE and Execute budgets remain unchanged. It uses no OH timer or stop/start desynchronization and makes no guaranteed free MH-hit claim. Temporary HS admission follows client usability only, without paid core reservation or +5 buffer; hold while pooling and let ready affordable single-target cores spend actual rage directly with HS queued. Never cancel HS merely for core funding or because rage is below HS cost; retain factual queue observations until the client clears them. MH-deadline cancellation applies only when HS is affordable, unpaid and no ready core takes priority. All abilities use actual current rage with HS/Cleave queued; queued cost is diagnostic only. Never cancel Cleave solely for low rage or core funding. New queue admission and filler/core budgets remain prospective, with no subtraction of a queued cost. Keep witnessed queue cleanup across decision resets, with prospective cycle guards per placement. Assigned Demo is high-priority missing/<=5s maintenance before damage, including Execute, with no core-gap or extra rage reserve. Init Sunder Armor and Stack Sunder Armor (stable keys sunder_initial/sunder_stack) both prioritize missing/<=3s refresh, skip Expose Armor and use current rage before damage. Init does not build healthy stacks; Stack adds healthy stacks up to five only after cores/free Victory Rush in a >=1.5s gap, retaining exact upcoming/next core costs plus any already funded queued HS payment in Normal single target or existing next-core cost +5 in AoE/Execute, before Hamstring. Both modes may be enabled together. Required queue cleanup/interrupt/stance preparation keeps priority. Existing routine/profile defaults remain unchanged; see `docs/WARRIOR_KEBAB.md`.

Separate desired behavior from factual truth. The user's latest explicit request controls scope, priorities, and the desired outcome; it does not establish API capability or invalidate reproduced client behavior. For factual questions, use this order:

1. Reproduced live behavior, Lua errors, exported mappings, combat logs, and focused diagnostics.
2. Blizzard API documentation and Blizzard UI source for the exact installed Anniversary client.
3. The current TOC load order and current reachable call chain.
4. Current comments, tests, README text, and saved historical diagnostics.
5. Older conversations, proposed plans, and generic Retail addon advice.

If the requested mechanism conflicts with a verified platform restriction, explain the constraint and propose the nearest supported design. Do not pretend an unsupported mechanism works.

Treat older conversations as design evidence, not as proof that a change still exists. Later, more specific decisions supersede earlier ones. Call out a contradiction instead of silently choosing a convenient source.

Classify important facts while reasoning: public API contract, Blizzard-private implementation, reproduced live observation, or project heuristic. Only a public contract is portable without revalidation; private fields and heuristics require guards, telemetry, and build-specific testing.

The active target is the interface version declared by `OliaEyes6.toc` (currently `20504`), not Retail/The War Within. `README.md` currently describes the wrong branch. Never perform a mechanical “modern WoW” migration, add Retail frameworks, or replace working legacy APIs only because generic guidance recommends it.

Check repository status with `git rev-parse --show-toplevel` when version history or rollback matters; the directory had no Git repository at the 2026-08-19 audit. If no repository exists, use only task/conversation edit records. A nearby ZIP may be used as a weak comparison baseline, but never as an approximate rollback source or authoritative history. File modification times are also weak evidence.

## Match the requested mode of work

- For “investigate,” “check,” “compare,” “explain,” “review,” or “plan,” inspect and report without editing.
- For “fix,” “implement,” “change,” or “build,” make the narrowest complete change and verify it proportionally.
- Ask questions before coding only when an unresolved choice materially changes behavior, scope, or the external protocol. Do not re-ask facts discoverable in the code.
- For a large behavior change, first state the proposed priority and scenario matrix in concrete terms so the user can correct the model.
- When asked to “think first” or be challenged, compare current and proposed behavior, expose conflicts and edge cases, and wait for implementation approval.
- Treat pasted plans or conclusions from another AI as proposals. Verify them independently against this addon and the target client.
- Respect exact scope such as class, form/stance, thread, PvE/PvP, single-target/AoE, talent, equipment, and target type. Do not leak a specialized rule into another routine or an unrelated authored branch.
- Preserve unrelated user changes. If asked to roll back “this conversation,” undo only changes made for that conversation, not older or adjacent work.
- When live testing disproves a theory, accept the observed result, revise the model, and remove the failed implementation completely when requested.
- Report what changed, what was actually checked, what still requires `/reload` or live testing, and any remaining risk. Never equate static inspection with in-game success.
- When describing rotation behavior, prefer a compact ordered list such as `1. Action — conditions`, split by mode/thread where needed. During staged work, give a short “done / next” update rather than repeating the full analysis.

Before the first mutation in a conversation, maintain an edit ledger containing every touched file and its exact pre-edit/post-edit hunks. For broad or high-risk work, retain task-scoped preimages outside the addon load path. To roll back the conversation, reverse only ledgered hunks whose current text still matches the recorded post-edit text. If a hunk overlaps later user or external edits, stop and report the conflict rather than restoring the whole file. If no trustworthy ledger or preimage exists, do not approximate a rollback from timestamps, comments, or a ZIP.

Before implementing combat behavior, define the relevant dimensions:

- class/spec/talents and Engine thread;
- PvE or PvP, group/raid/arena context, and enemy count;
- selected target, focus, soft target, unit type, GUID, LoS, and range;
- combat state, movement, form/stance, equipment, and mounted/resting state;
- resource, GCD, cooldown, cast/channel, swing phase, latency, and haste;
- aura spell ID, source, stacks, duration, and expiry;
- the expected action, deliberate wait/hold, fallback, and stopcast behavior.

## Understand the execution model

The core path is:

```text
OnUpdate
  -> updateUnitsData
  -> Arena update
  -> ProcessRotation(thread)
  -> clear/choose pixel
  -> choose routine row and unit
  -> set CurrentCast
  -> emit focus color or action color
  -> external input presses a secure button
  -> macro executes in the game
  -> combat log/API state confirms or rejects the outcome
```

`Cast:CastSpell()` returning true proves only that intent was emitted. It does not prove that the focus changed, a button was pressed, or the spell succeeded. Debug these as three separate layers:

1. Intent: chosen routine, unit, action, and pixel.
2. Execution: secure button/key and macro execution.
3. Outcome: cast success/failure, aura/resource change, or combat-log event.

Actual protected actions must remain in secure buttons/macros reached through hardware input. Do not call protected cast or target functions from `OnUpdate`.

Technical execution through a secure button does not by itself establish compliance with Blizzard's automation rules. Do not design protected-action bypasses, combat-lockdown circumvention, unattended input, anti-detection behavior, or input broadcasting. Describe synthesized/external input and its account-policy risk accurately; never call it a genuine user hardware event without evidence.

`Main.lua` currently runs the Engine on every rendered frame. A historical 30 Hz/10 Hz throttle was only a proposal and is not current behavior. Treat a requested whole-Engine cap as a cross-cutting timing experiment, not proof of a stutter fix. Trace pixel clear/set dwell and the external sampler first: holding one action color for roughly 33 ms can change the wire protocol as well as focus/cast retry latency and stopcast/swing timing. Prefer measuring and throttling expensive snapshot or maintenance work separately while leaving protocol clearing, focus handoff, stopcast, swing windows, and emergency paths responsive. If the user explicitly requests the experiment without representative live measurements, make it reversible/configurable, carry accumulator remainder, bound catch-up, disclose the unverified responsiveness risk, and do not claim success until before/after combat profiling confirms it.

## Respect TOC order and module boundaries

Treat `OliaEyes6.toc` as executable dependency order. The present layers are:

1. offsets, color, and pixel protocol;
2. spell, aura, unit, hotkey, swing, configuration registry and options helpers;
3. cast, rotation, performance, arena, and engine;
4. data, caches, LoS, DR, cooldown, energy, stopcast, and diagnostics;
5. class/support routines;
6. routine schemas, static dispatch views, catalog and overlay;
7. `Main.lua`, debug UI, and legacy `Tests.lua` (standalone regression suites stay outside the production TOC).

When adding a file, place it after every dependency it reads at load time. A module may reference a later-loaded function only through intentional late binding at call time or initialization. `RoutineCatalog.lua`, for example, captures evaluator references after routine modules and schemas load; Engine dispatch uses the compiled configuration plan.

Use the established module form:

```lua
local Jungle, jungle = ...
```

Put shared public functions/state on `jungle`; keep helpers and state `local`. Do not add accidental globals. Use `_G` only for required macro-callable entry points, Blizzard objects/APIs, saved variables, or an explicit compatibility surface.

Prefix unavoidable new global entry points, named frames, bindings, saved variables, and slash-command identifiers with `OliaEyes6_` where compatibility permits. Do not rename established external globals without tracing their consumers.

Prefer an independent helper, prepass, or Engine layer when a feature has distinct ownership or state. Give that layer an explicit activation condition, priority and ineligible-context release; any following routine must be an explicit thread placement. “Independent” must mean it cannot accidentally alter unrelated threads or contexts.

Snapshot facts below were last verified on 2026-08-19 against the current code and `OliaEyes6.toc`. Revalidate any snapshot that materially affects the requested change. Current executable code outranks an older snapshot, and the user may explicitly change a behavioral baseline after the consequences are explained.

## Preserve configured routine ownership

Read `Core/Engine.lua`, `Core/RoutineConfig.lua` and `Core/RoutineCatalog.lua` before changing routing. Threads 1-6 use the same current-class catalog with ordered, independently configured placements. Thread 7 accepts support routines only, currently Fishing and Follower, preserving their module eligibility. Class/support categories are explicit registry metadata.

`RoutineCatalog.lua` owns default placements: Druid retains the original thread 1-6 healing/dispel/DPS/buff presets, Warrior retains maintenance/universal/Sweeping/tank presets, and Rogue defaults to DPS on thread 5. These defaults are reset/initialization data, not fixed routing. Warrior behavior and evaluator mode are fixed in its registered definition; the explicit Original maintenance variant retains thread 1's combat behavior. Thread 3 contains Sweeping alone by default. Fallback-only universal policy-3 identities are retired and archived out of every profile's thread lists; do not reintroduce them. Saved Warrior policy/mode overrides migrate to stable variant IDs across all profiles. Druid retains its existing policy adapter. Use semantic Warrior behavior properties rather than adding numeric preset switches or recovering behavior from the physical thread. See the companion skill for authoring and migration contracts.

An Engine/dispatch result of true may mean ownership without an emitted action. Preserve deliberate pooling/wait states and ineligible-context release. Separate placements have sequential priority; joint friendly definitions preserve competition by authored row priority across their component evaluators. The companion skill defines masks, dependency handling and all-actions-disabled ownership release.

Kebab intentionally uses two compact PvE blocks per the user's 2026-10-14 request. Keep Execute, unsafe-area and no-enemy eligibility in action/section descriptions and test actual outputs against the relevant block; do not recreate separate phase/context blocks for Kebab.

A routine owns its declared algorithm and authored PvE/PvP, form and single-target/AoE branches. Ineligibility returns a reusable empty result, never an automatic substitute from another algorithm. Global evaluator wrappers must not make Adaptive/WoWSims selection change Original/Arms/maintenance/Sweeping behavior. Explicit thread order remains the only path to another placement. Keep valid internal dispatchers, named joint routines and shared utility-only decisions; display all their own actions without unrelated fallback sections. Each actual mode needs its own step section and visible activation rule; a combined action list does not expose the dispatcher. Follow `Core/RoutineDispatchViews.lua` and [the routine dispatch audit](../../docs/ROUTINE_DISPATCH_VIEWS.md), and verify actual outputs per branch, including dynamic actions and equipment prepasses. Shared tables without a dispatcher keep a shared view. Update evaluators, schemas, catalog, migration, overlay views and both project skills together when changing this boundary. See `RoutineIsolation.test.lua` for regression coverage.

## Preserve rotation semantics

The effective routine row schema is:

```lua
{ diagnosticLabel, actionID, conditionBoolean, stopcastMetadata }
```

- Array position is priority. The first true row wins inside a routine.
- Row `[4]` is stopcast metadata: either a function evaluated during a matching active player cast or the legacy string `"PROTECT_BLOOM"`.
- Row `[4]` is not an on-selection or on-success callback. Never put an instant-cast side effect there.
- Row `[5]` is ignored by the active evaluator; extra legacy numbers do not define priority.
- Most routines reuse tables and overwrite row `[3]` each evaluation. Reset or assign every condition before every possible return so a previous tick cannot leave stale truth.
- Return a shared empty routine for invalid contexts instead of allocating a new table every frame.
- Keep diagnostic labels accurate, but remember that the action ID—not the label—is the protocol identifier.

Do not assume all selectors rank candidates the same way:

- Friendly `rotate()` compares row indexes across routines and cached friendly units. A lower row wins; ties prefer a larger `hpBucket`, then a smaller `hotScore`.
- `condition()`/`dpsRotate()` let routine-list order dominate and normally prefer a valid selected `target` before `softenemy`.
- Exact friendly ties may inherit Lua `pairs()` iteration order. Do not rely on deterministic ordering unless the task explicitly adds it.

`CurrentCast` fields are part of stopcast and LoS attribution. When adding a new selection path, audit spell, target GUID/token, priority, metadata, and start time consistently.

## Optional enemy context in existing routines

Keep self-action blocks and row priorities inside their existing class/support routines. Do not extract a separate self-action pass, duplicate conditions, or create a new dispatcher merely to make targetless actions reachable.

- `dpsRotate()` selects a live attackable `target`, then `softenemy`, then evaluates the same routines with `nil`. A missing enemy is a valid evaluation context. The action boundary uses `player` for a selected targetless action's bookkeeping, never as a fabricated enemy passed into the routine.
- Establish `hasEnemy` before enemy API reads, string concatenation, GUID-indexed state, PvP/PvE target classification, and target-based reservations. Guard enemy-directed rows, including `Attack` and queued attacks even when their action IDs have no spell range. Reset every returned condition so target loss cannot reuse a previous tick's eligible row.
- Preserve player-only resource, cooldown, form/equipment, casting, and buff conditions in place. Gate only their actual enemy dependencies. Missing target health must never become an Execute opportunity; stale gap-closer or swing context must not reserve an enemy action without an enemy. A routine containing only enemy-dependent actions may still return an empty set for `nil`.
- Offensive area actions still require suitable nearby-enemy observations and any existing aura/coverage, combat, or resource conditions. Nameplates supply observations, not cast destinations. Charge/Intercept preparation, target-specific interrupts, and the specialized Thread 3 sequence retain their enemy requirements. Do not enable a currently disabled action or placeholder class route as part of this work.
- Friendly healing/buff routines continue using their friendly unit context. In shared follower logic, self maintenance may use player context without a friendly driver; follow and mirrored mounting still require a driver.
- `jungle.actionHasRange` is initialized from `C_Spell.SpellHasRange(actionID)` and shared by casting, default macros, and generic readiness checks. Refresh the cache and secure macros together outside combat. Per the user's tested client policy, false includes custom/unknown action names; do not add manual targeting overrides or an unknown-action fallback. This classification controls execution, not action desirability.
- Verify valid-target behavior against an exact checkpoint, then exercise nil/friendly/dead contexts, target loss/reacquisition, no nameplates, nearby observations, resources/cooldowns, and stale queued actions. Unit API mocks should reject absent enemy reads. Verify that ranged actions cannot be selected for the no-enemy context and that eligible lower-priority targetless rows are still considered.

## Treat action, key, and color mappings as a wire protocol

Action IDs, spell-list order, global-default order, key-pool order, unit-token order, RGB hashing, pixel position, and focus handshake are externally consumed protocol—not cosmetic implementation detail.

- Renaming an action or changing its case changes its color.
- Reordering a registry changes subsequent key assignments.
- Adding a global default shifts later targeting bindings.
- Filtering unlearned spells out of a class registry shifts mappings; keep fixed registries and gate capability/readiness in rotation logic.
- Prefer changing a macro override for an existing stable action slot over creating a new action ID.
- Reuse shared equipment actions (`Equip2H`, `EquipDW`, and related slots) only after auditing every class that updates them.
- Do not change pixel geometry, hashing/rounding, clear colors, or the two-step focus-then-cast handshake incidentally.

In a request such as “add action A before action B,” interpret “before” as routine evaluation priority unless the user explicitly says to change the action registry. Insert or reorder the routine row and update every branch that resets/assigns its condition. If A is a genuinely new action ID, append it to the class registry after capacity analysis so existing keys remain stable; never insert it beside B merely to mirror rotation order. For Druid thread 5, audit PvE Moonkin, PvE non-Moonkin, PvP caster, movement, idle/equipment prepasses, and fallback/Attack rows separately.

At the 2026-08-19 audit, executable tables contained 50 rotation keys and 77 targeting keys; Druid used 46, Warrior used 44, and static targeting creation consumed 75. Comments claiming 51 targeting slots or 11 gamepad entries were stale. Recount the live tables and inspect the saved-variable mapping before claiming capacity or a free key.

For every intentional protocol change:

1. record the before/after registry and assigned key;
2. verify pool capacity and duplicate keys;
3. run `/olia dump` and inspect color collisions;
4. compare the exported `{class,type,id,key,color}` mappings;
5. coordinate the external decoder/input mapping change;
6. live-test focus acquisition and the final action separately.

Recorded project baseline (2026-08-15; TOC interface `20504`): secure macros using `/focus nameplateN`, `/target nameplateN`, or `[@nameplateN]` did not acquire/cast on those units even when Lua could read their GUID, health, or aura data. Treat nameplate tokens as observation-only for this build. If the running client/interface changes or contrary live evidence appears, repeat a bounded out-of-combat secure-button hardware-key probe before revising the conclusion. Until such a probe succeeds, use supported selected-target, soft-target, mouseover, focus, party/raid/arena tokens, or explicitly scope a separate user-driven mouse-target bridge.

## Obey combat-lockdown and macro safety

- Never mutate secure attributes, override bindings, or protected macro state during combat.
- For dynamic equipment/item/follower macros, mark state dirty and retry after `PLAYER_REGEN_ENABLED`; keep the previous valid macro active until then.
- Item information can arrive late. Refresh event-driven and retry only bounded pending work.
- Validate all equipment item IDs/names and macro length before replacing a working macro.
- Keep destructive bag operations behind a hardware-event macro, combat/cursor guards, throttling, and a strict item-ID allowlist. Never broaden the fishing deletion list implicitly.

## Use stable identities and truthful caches

- Unit tokens are transient handles. Use GUIDs for persistent state, deduplication, cooldown/DR ownership, and cross-token identity.
- Resolve a GUID back to a currently valid token only at the action boundary.
- One actor may appear as target, focus, party, raid, arena, or soft target at once. Deduplicate counts and schedules by GUID.
- Creature GUIDs contain stable NPC IDs. Prefer NPC ID plus encounter/form context for immunity or creature rules; use localized names only as a documented fallback.
- Use numeric creature-type IDs for mechanics. Localized values such as `"Elemental"` and `"Totem"` are presentation strings, not stable decision keys.
- Do not use localized aura names as unique cache keys. Aura names can collide and multiple casters can apply same-name auras. Preserve all instances or key by spell ID, source GUID, and an available instance discriminator.
- Treat `expirationTime == 0` as a permanent aura, not an expired aura.
- Evict GUID-keyed caches with bounded TTL/event cleanup; correctness-time expiry and physical cleanup may run on different schedules.
- `UnitsData` derives private lookup sets from public arrays at load time. Mutating the public array later does not update the private set unless it is rebuilt or the UI reloads.
- Verify helper semantics before trusting its name. In particular, `jungle.isTargetInLos(unit)` currently returns true for a temporarily blocked/out-of-LoS target.

There are two aura/cache models in this project: the GUID-keyed generic `Buff`/`Debuff` cache and the token-keyed categorized `UnitsData` cache. Do not merge or bypass them without tracing invalidation, expiry, duplicate-GUID aliases, and every caller.

`unitCache.currLife` is not raw health. Healing selection also incorporates incoming heals, HoT padding/saturation, missing health, 500-HP buckets, threat/tank status, and `hotScore`. Use the exact field required by the decision.

## Verify Anniversary APIs exactly

The required API reference database for this project is [Gethe/wow-ui-source: classic_anniversary / Interface/AddOns](https://github.com/Gethe/wow-ui-source/tree/classic_anniversary/Interface/AddOns), a mirror of Blizzard UI source for the target client branch. All client API, event, enum, and Blizzard UI behavior checks must consult this source, including its `Blizzard_APIDocumentationGenerated` documentation and relevant Blizzard addon implementations. Use the `classic_anniversary` branch explicitly; generic web examples, Retail signatures, and other Classic branches are insufficient.

A local checkout of that source may be used when its branch and revision are known. Record the relevant source path and revision or permalink for API-dependent changes, and check compatibility with the installed client build and `OliaEyes6.toc`. If source is unavailable, missing a legacy API, or conflicts with observed behavior, state the verification gap and use a bounded live probe; do not treat absence from generated documentation as proof that an API is unsupported.

Use targeted web research when the user requests it or when local sources cannot answer TBC data questions such as NPC, item, or mount lists. Prefer primary or build-specific sources and record the client build; do not import Retail mechanics by recollection.

- Check event argument order, API namespace, return count/type, nil behavior, and unit-token requirements at the call site.
- Prefer enum members such as `Enum.StartTimerType.PvPBeginTimer` over embedded numbers. If compatibility needs a numeric fallback, guard the enum and use a locally verified value with a comment.
- Do not mechanically mix legacy globals and `C_` APIs. Normalize once at a wrapper boundary.
- `C_Spell.IsSpellInRange` returns boolean/nil; legacy `IsSpellInRange` call sites may use `1/0/nil`. Compare according to the API actually called.
- Structured `C_Spell.GetSpellCooldown` data is not interchangeable with legacy multiple returns.
- Validate `UnitExists` before APIs requiring valid unit tokens, including strict attackability checks.
- Treat `nil`, `false`, `0`, and “not known yet” as distinct states. For readiness, require explicit usability unless a documented resource-pooling path intentionally accepts another state.
- `UnitInRange` has both `inRange` and `checkedRange`. Model `in`, `out`, and `unknown`; document the deliberate fail-open or fail-closed policy for unknown instead of treating it as out of range accidentally.
- `CheckInteractDistance(unit, index)` is only a coarse indexed interaction check. Do not label index `3` as an exact yard distance without live proof.
- Generated documentation may omit a supported legacy global. If exact local docs do not settle it, write a tiny bounded live probe and record the result rather than guessing.
- Blizzard documentation proving a token is readable does not prove that token is accepted by secure macro targeting.

When a feature needs authoritative active nameplate tokens, maintain them from `NAME_PLATE_UNIT_ADDED` and `NAME_PLATE_UNIT_REMOVED`. Never infer `"nameplate" .. index` from the array position returned by `C_NamePlate.GetNamePlates()`: the API documents no ordering contract. Private frame fields differ across client branches; if an existing compatibility path inspects them, validate the result with `UnitExists`, guard forbidden/private access, and never treat it as a secure-action grant.

When migrating legacy spell APIs, create one feature-detected compatibility adapter and give callers project-owned normalized records. Account for these incompatible shapes:

- legacy `GetSpellInfo` tuple versus `C_Spell.GetSpellInfo` table;
- legacy `GetSpellCooldown` tuple versus `C_Spell.GetSpellCooldown` table/nil;
- legacy `IsSpellInRange` `1/0/nil` versus `C_Spell.IsSpellInRange` boolean/nil;
- legacy `IsUsableSpell` tuple versus `C_Spell.IsSpellUsable`.

Do not mass-rename callers. Test the adapter on the actual Anniversary client first. Centralize cooldown interpretation as project policy and cover ready, GCD-only, real cooldown, disabled/on-hold, and unknown. Duration equality is not a guaranteed way to identify the GCD, and `isOnGCD` is only documented as trustworthy in a limited event context.

## Protect hot-path performance without changing behavior

Optimize only after locating the real cost. Use `/oliaperf` or bounded instrumentation in actual raid/boss/AoE scenarios; do not infer stutter from file size alone.

- Reuse routine/result tables and avoid per-frame table/string creation.
- Cache expensive results once per `jungle.currentTick` when every caller in that frame needs the same snapshot.
- Localize truly hot functions/tables, but do not add locals blindly to huge Lua 5.1 functions.
- Filter combat-log events by event type/source/destination before expensive work.
- Keep reclamation and slow audits on staggered or once-per-second maintenance paths while checking logical expiry synchronously where correctness requires it.
- Keep disabled diagnostics almost free; bound saved arrays and avoid per-frame chat output.
- Prefer event-confirmed state plus bounded grace windows over optimistic polling.
- Hoist stable talent, equipment, and capability checks to initialization or the relevant change events instead of recomputing them every frame.
- Treat filler rows as fillers: they must not block a newly ready core action unless deliberate ownership explicitly says to wait.
- Preserve responsiveness for stopcast, focus handoff, swing windows, and emergency healing when proposing a throttle.

Instrumentation should capture only what distinguishes the hypothesis: timestamp, build/schema, thread/routine/row, action, GUID and token, target type, resource, GCD/CD, cast/swing state, readiness result, and a reason code. Instrument the smallest decision boundary and remove or disable it after the question is answered.

## Last-verified Druid behavioral baselines

Trace the current Druid routine before editing; it is large and contains several generations of logic. Preserve these settled decisions unless the user explicitly changes them:

- Active thread 2/7 healing uses the V6 Lifebloom scheduler. It chooses the earliest relevant deadline per current tick and admits work using expected GCD/cast time, haste, latency, and a reserve window. Do not replace it with independent fixed-threshold checks.
- Keep tanks and threat tanks in V6 scheduling and deduplicate candidates by GUID.
- Cat powershifting is allowed only with 5/5 Furor (spell ID `17061`). Generic Cat shifting and Bear powershifting were rejected; Bear support remains removed.
- Bash, Feral Charge, Maim, and the general Druid interrupt-preparation routine remain disabled. Do not revive old commented rows incidentally.
- Moonweaver behavior is PvE-only and tied to its intended Moonkin/talent/equipment context. It reuses existing Moonfire/Insect Swarm/Wrath/Starfire and shared equipment actions; do not allocate new keys casually.
- Velocity/equipment restoration must be able to run without a hostile target when its state machine requires cleanup.
- PvE school-immunity avoidance must not bleed into PvP. Prefer NPC IDs/encounter evidence over English creature names.
- Improved Faerie Fire PvE logic remains talent-gated and limited to the intended skull/boss targets.
- Validate optional SuperSwingTimer information and retain the internal fallback; addon-loaded status alone is not proof of usable timing.

Keep form, movement, equipment, target existence, talent rank, and PvE/PvP gates explicit. Existing routines may evaluate without a hostile target; enemy-directed actions must still require a valid enemy, while area actions retain their nearby-enemy conditions.

## Last-verified Warrior behavioral baselines

Preserve these settled decisions unless explicitly changed. Thread numbers in the following Warrior baselines describe default placements/policies; specialization follows the fixed routine definition when users assign it elsewhere.

- Thread 1 owns PvE maintenance before universal rotation. Thread 2 is universal baseline. Thread 3 currently owns its Sweeping Strikes/AoE sequence and may deliberately hold ticks, including after the verified enemy count falls below two before Sweeping Strikes is spent.
- For any pooling or enemy-count-drop change, trace and report the actual entry, hold, and release transitions: target validity, enemy count, Sweeping readiness/active/grace state, rage, stance, queued Cleave/swing state, timeout/cancellation, and handoff to universal. Do not preserve indefinite ownership merely because a historical statement says “until release.” If the new request does not establish whether a drop below two should keep pooling or hand off, ask that behavioral question before editing.
- Thread 3 must not gain unrelated interrupt logic or leak its pooling rules into universal threads.
- The two-handed Slam after-swing window is deliberately hard-coded at `1.15` seconds. Do not derive it from the GCD or restore the rejected `/startattack /cast Slam /stopattack` macro.
- Preserve the distinction between off-GCD and GCD actions. Do not globally rewrite `ReadyCastSpell` or readiness behavior to solve one Warrior action.
- Totems remain excluded from maintenance debuff work. CC/totem exclusions for AoE counting do not forbid direct attacks on the selected target.
- Swing timing uses combat-log events, target/swing identity, bounded handoff state, and a validated optional SuperSwingTimer view. Keep the internal tracker hot as fallback.
- Retain both the generic `GetMainhandTimeRemaining` API and the legacy `GetSlamTimeRemaining` alias unless all external callers are proven gone.
- Large Warrior functions have already hit Lua 5.1's “more than 60 upvalues” limit. Extract cohesive helpers/state or consolidate data instead of adding many localized references inside a giant closure.

When evaluating next-swing actions, distinguish explicit `IsUsableSpell == true`, resource shortage, wrong stance/equipment, cooldown, queued state, and deliberate pending-resource behavior. Do not treat `false` as ready merely because it is non-nil.

## Follower and support invariants

- Thread 7 is support-only (Fishing/Follower), with no class-rotation imports. Preserve support module eligibility and configured priority, including class-aware branches authored inside Follower; do not add class filtering or unrelated class healing to this thread.
- Treat follow, stop-follow, mount, food/drink, fishing, and equipment macros as stable protocol actions.
- Any dynamic secure macro refresh must be event-driven, combat-safe, and recover after lockdown.
- Separate “leader/target temporarily unavailable” from “state should be reset.” Persistent movement or equipment cleanup must not depend unnecessarily on a hostile target.
- Keep bag/cursor operations conservative and recover the cursor on failure.

## Do not teach current defects as intended behavior

The following are confirmed hazards or inconsistencies. If a task touches them, fix them when in scope or preserve them knowingly and report the risk:

- `Core/Arena/Arena.lua` checks `START_TIMER` type `1`, while the local Anniversary timer constants define PvP begin as `0` and challenge countdown as `1`.
- Warrior `IsNextSwingReady` currently rejects only `usable == nil`; an explicit `false` can incorrectly pass.
- `Core/Aura.lua` stores one aura per localized name, so duplicate/source-specific auras overwrite one another. Its remaining-time path also mishandles permanent expiry `0`, and its GUID cache lacks clear bounded eviction.
- Druid creature-type checks and `TargetImmunities.lua` use English names despite numeric creature-type/NPC IDs being available.
- Arena cooldown/DR state and parts of target-immunity state are keyed by names. Persistent actor state should use GUIDs; names belong in diagnostics.
- Arena spec detection attributes some applied auras to `destGUID`, although the signature may identify the caster. Use `sourceGUID`, except for a verified self-only effect with `sourceGUID == destGUID`.
- DR tracking can retain more than one tier record. Maintain one state per destination GUID and DR category, and test apply/refresh/remove/immune/miss sequences against live captures.
- Existing nameplate helpers inspect private frame fields and can infer a token from frame-array position. Replace authoritative identity tracking with nameplate add/remove events when that code is in scope.
- Some range logic ignores `UnitInRange`'s `checkedRange` result and conflates unknown with out of range.
- Cooldown/GCD interpretation is duplicated and partly duration-based. Treat it as a heuristic pending a centralized, client-tested policy.
- A PvP Rejuvenation row places a side-effect function in row `[4]`; row `[4]` is stopcast metadata, so it is not an on-cast throttle hook.
- Friendly selection fills more `CurrentCast` timing fields than DPS/arena selection, weakening LoS attribution on those paths.
- Engine records an `arena` profiler section that the current performance report does not define.
- Active V6 healing does not clearly share the legacy `"PROTECT_BLOOM"` cleanup path. Trace ownership before relying on that marker.
- Arena debug passes a character name to a DR helper that expects a unit token; cooldown maps can also mix `Name-Realm` and short names.
- `Cast:Reset()` hashes IDs that do not match active registered actions. It is unused and must not be copied as the reset contract.
- `Tests.lua:tst2()` calls stale/non-exported functions, lacks guaranteed mock restoration, and mocks `UnitCastingInfo` with the spell ID in the wrong return position. Tests are loaded by the production TOC, so it is not proof of a passing suite and must not leave globals patched after failure.
- Optional TSM automation walks private UI structure and performs programmatic clicks. Keep it isolated behind exact addon/version/capability checks and fail closed on ambiguous or forbidden frames; never click arbitrary `UIParent` descendants.
- Several comments, pool counts, historical `[NEW]/[FIX]/FACT` notes, dead globals, and commented blocks are stale. Executable behavior outranks them.

Do not expand an unrelated task into a cleanup campaign for this list. Use it to avoid copying a defect and to disclose adjacent risk.

## Apply changes safely

1. Read the TOC, Engine routing, relevant routine, helper implementation, and every caller/consumer affected by the proposed change.
2. Search action IDs, spell IDs/names, event registrations, saved-variable fields, macros, and external export use across the whole addon.
3. Confirm the desired scenario matrix and ownership: who acts, who deliberately waits, and when the next explicit placement can run.
4. Verify exact API/event behavior against the local Anniversary source or a bounded live probe.
5. Before a radical experiment, establish an explicit recoverable checkpoint for the exact files in scope. Patch narrowly. Preserve surrounding line endings and avoid whole-file formatting in these mixed-ending legacy files.
6. Re-read the full changed functions for stale row state, early-return leaks, nil/false mistakes, wrong token/name/GUID types, combat-lockdown violations, and per-frame allocation.
7. Check TOC order, namespace/global leakage, Lua 5.1 compatibility, action/key capacity, color collisions, and external protocol diffs where applicable.
8. Parse every changed Lua file; for broad refactors, parse every addon Lua file. Run relevant standalone regression suites in `tests/`, but state their mocked-client limits. They cover control flow and differential scenarios, not live rendering, SavedVariables disk flush or real spell outcomes.
9. Perform `/reload`, inspect Lua errors, and exercise the smallest targeted live scenarios. Use control cases for neighboring threads/forms/contexts.
10. For timing or performance work, profile before/after in representative combat and retain enough bounded telemetry to explain regressions.

Useful live commands currently include:

```text
/olia debug
/olia dump
/oliaperf 15
/oliaperf on|off|report|clear
/olia arena debug
/armslog on|off|clear
/misslog on|off|clear|N
/desynclog N
tstNameplates(N)
```

Do not claim a spell or macro is fixed from syntax alone. A complete handoff distinguishes static validation, successful `/reload`, protocol/export verification, targeted live outcome, and anything still awaiting the user's game test.

## Historical cautions requiring revalidation

- Readable nameplate tokens are not secure macro targets in this client.
- Generic Retail modernization guidance is not the project specification.
- The global 30 Hz/10 Hz Engine throttle and a centralized `Core/Events.lua` were discussed or claimed historically but are absent from the current code; do not assume them.
- Action/key order is an external compatibility contract, not an internal refactor detail.
- V6 Lifebloom deadline scheduling, Thread 3 Warrior ownership, 1.15-second Slam timing, Cat-only 5/5-Furor powershifting, disabled Druid interrupts, and validated swing-timer fallback are deliberate surviving decisions.
- The August pre-swing Slam experiment—including the 0.1-second trigger, reservation/debug logic, Execute removal, and related GCD changes—was fully rolled back. Do not reconstruct it from old discussion.
- Earlier Thread 1 changes leaked through shared helpers into Thread 2 and were rejected. Audit all shared callers for every thread-scoped change.
- Intermediate PvP Hamstring/Bloodrage and complex stance-scheduling discussions conflict with later corrections. Use current code plus the newest explicit request, not an intermediate transcript.
- A performance refactor that preserves average timings but changes cache invalidation, target state, or priority behavior is a regression; historical Hamstring spam demonstrated this.
- Old assistant summaries can describe changes that were later rolled back or never survived. Verify every claimed feature in the current call chain before building on it.
