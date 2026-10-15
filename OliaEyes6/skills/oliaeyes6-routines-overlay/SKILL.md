---
name: oliaeyes6-routines-overlay
description: Design, add, change, or review OliaEyes6 routines and their overlay controls together. Keep evaluators, row descriptions, catalog definitions, action dependencies, profiles, and compiled dispatch synchronized. Use for routine authoring, step toggles, routing, or routine/profile UI changes in this project.
---

# OliaEyes6 routines and overlay

Use this skill with the [project development rules](../oliaeyes6-development/SKILL.md). This skill owns the routine/configuration/overlay contract; the development rules own client API verification, combat/protocol invariants, edit records, and live verification. Honor the user's current scope. Read the current implementation before editing; the file map and examples here are a navigation aid, not a replacement for executable code.

## Read the relevant contract

Kebab (`warrior.kebab`, `Routines/WarriorKebab.lua`) is an independent PvE single-target/AoE DW Arms definition. Its two PvE blocks (Single target and AoE) include Execute controls and inline phase/safety/no-enemy explanations, sharing per-placement action masks and preferences; it has no fallback algorithm, Slam, Overpower, desynchronization or equipment swapping. Register it after legacy variant expansion with its named `kebab` behavior and the accepted `original` compatibility mode token. Keep core/queue/filler reservations enabled-action aware, required factual queue cleanup, optional Execute core choices, and all 23 optional steps / 11 preferences synchronized. Safe AoE uses funded Sweeping Strikes, paid Cleave and WW before spare-rage MS; MS protects imminent WW without reserving an unqueued Cleave; count drops resume single target without a Sweeping wait, and excluded observations suppress area actions. Execute Cleave is separately opt-in. Normal single-target HS queue/cancel is standard under the HS action switch. Retire the old mainhand_queue and aggressive_filler preferences from active controls/compilation while preserving raw historical saves. Ready affordable Normal MS/WW precedes new HS, self buffs and burst after assigned maintenance. Paid HS reserves the actual costs of every enabled core independently due by cooldown before the next possible normal MH (remaining MH + current period); a shared GCD never excludes the second ready/closely due core, with no rage buffer or 40-rage floor. Unknown/unmatched timing conservatively reserves both enabled cores; temporary admission still requires confirmed matching timing. Normal optional spending retains the greater of this upcoming-core reserve and the next enabled core cost, adding actual HS cost when it is factually queued and already funded, with no extra rage buffer/floor. Ordinary Normal GCD buffs require a ready GCD and full >=1.5s core gap; genuine off-GCD Bloodrage/trinkets remain available. Every optional GCD must fit a full >=1.5s after any remaining current GCD, even at rage cap; preserve retired aggressive_filler values only in raw saves, never active compilation or controls. AoE and Execute budgets remain unchanged. It uses no OH timer or stop/start desynchronization and makes no guaranteed free MH-hit claim. Temporary HS admission follows client usability only, without paid core reservation or +5 buffer; hold while pooling and let ready affordable single-target cores spend actual rage directly with HS queued. Never cancel HS merely for core funding or because rage is below HS cost; retain factual queue observations until the client clears them. MH-deadline cancellation applies only when HS is affordable, unpaid and no ready core takes priority. All abilities use actual current rage with HS/Cleave queued; queued cost is diagnostic only. Never cancel Cleave solely for low rage or core funding. New queue admission and filler/core budgets remain prospective, with no subtraction of a queued cost. Keep witnessed queue cleanup across decision resets, with prospective cycle guards per placement. Assigned Demo is high-priority missing/<=5s maintenance before damage, including Execute, with no core-gap or extra rage reserve. Init Sunder Armor and Stack Sunder Armor (stable keys sunder_initial/sunder_stack) both prioritize missing/<=3s refresh, skip Expose Armor and use current rage before damage. Init does not build healthy stacks; Stack adds healthy stacks up to five only after cores/free Victory Rush in a >=1.5s gap, retaining exact upcoming/next core costs plus any already funded queued HS payment in Normal single target or existing next-core cost +5 in AoE/Execute, before Hamstring. Both modes may be enabled together. Required queue cleanup/interrupt/stance preparation keeps priority. Existing routine/profile defaults remain unchanged; see `docs/WARRIOR_KEBAB.md`.

Paths in the table are relative to the addon root. Read the evaluator and its helpers, these affected consumers, and [routine configuration notes](../../docs/ROUTINE_CONFIGURATION.md). Consult the TOC whenever adding a module.

| File | Ownership |
| --- | --- |
| `Routines/*.lua` | Authored conditions, ordered rows, preparation, resource planning, factual observations and deliberate waits. |
| `Core/RoutineSchemas.lua` | Static row/action metadata and condition descriptions, via `Config:AddRows`. |
| `Core/RoutineBehavior.lua` | Named Warrior behavior contracts and the legacy adapter; construction only. |
| `Core/RoutineCatalog.lua` | Stable definitions: evaluators, row sets, category/class, selector, fixed behavior/mode, extra actions, links, options, ownership and defaults. |
| `Core/RoutineConfig.lua` | Registration, validation, profile migration, placement mutations, masks, compilation, lifecycle and dispatch. |
| `Rotation.lua` | Unit selection, row selection, final action mask, invalid evaluator handling and cast-context recording. |
| `Core/Engine.lua` | Thread selection, global interceptors and entry into compiled dispatch. |
| `Core/Options.lua`, `Core/RoutineUI.lua` | Main overlay shell and registry-driven routine, steps, More and profile controls. |
| `Core/Hotkeys.lua`, spell/cast helpers | Fixed executable action identities, readiness and protocol boundary. |
| `OliaEyes6.toc` | Registry before consumers; schemas/catalog/UI after evaluators, before bootstrap. |

A normal new routine needs its evaluator, schema and catalog entry; the generic UI discovers it from the registry. Add a TOC entry only for a new file, defaults only if it should run initially, and lifecycle wiring only for new persistent decision state. Avoid separate class lists, duplicated step lists in the UI, or a new Engine branch for each routine.

## Preserve the configuration model

- Threads 1-6 offer one universal catalog for the current class. A routine can occupy multiple threads, with independent enabled state, steps and options. The current contract allows one placement of a given routine ID per thread.
- Thread 7 offers implemented support routines from non-class modules, currently Fishing and Follower. Use explicit `kind="support"`, no class filter, and an accurate source path. Preserve module eligibility, including class-aware branches inside Follower; support is not a class-rotation import shortcut.
- Placements run from top to bottom. The first action or deliberate ownership/hold ends dispatch. Multiple functions inside a single `rotate` definition use joint friendly row priority; separate placements use linear priority. Keep both when they represent distinct authored semantics and name joint definitions clearly.
- A placement must run only its declared algorithm. Return a reusable empty result when that algorithm is ineligible; never call another algorithm as a rescue after failed eligibility, an empty result or a deliberate wait. Do not wrap global evaluators so selecting Adaptive/WoWSims also changes Original, Arms, maintenance or Sweeping. The explicit thread list alone selects the next placement; keep its linear priority and intentional holds.
- An authored dispatcher inside a routine is valid: Original Arms/Fury, each routine's PvE/PvP, form and single-target/AoE branches, and named joint routines remain supported. Show every reachable branch and dynamic action in that routine's static overlay views. Shared utility-only helpers and action alternatives are allowed when explicitly authored; they must never select another routine's core algorithm. Do not display unrelated algorithms or create fallback-only default/Add entries.
- Choose `rotate` for friendly selection and `dpsRotate` for hostile/optional-enemy selection. Inspect their actual ranking and nil-target behavior before choosing; their ordering semantics differ.
- Warrior behavior/mode belongs to its definition, independent of the physical thread. Use `GetWarriorRoutineBehavior()` semantic properties, `RoutineOption` and `RoutineAllows`; do not add a numeric preset switch or recover behavior from `Engine.activeThread`. `GetRoutineThread()` remains a legacy adapter for Druid/standalone callers. Event observers use `GetRoutineEntry()` with recorded cast/thread/revision checks; transient `RoutineContext` is not available outside evaluation/ownership callbacks.
- Profiles store per-class configurations and per-character profile selection. Stable routine IDs, action IDs and option keys are persisted. Display labels can change without renaming IDs. Rename/remove persisted keys only with explicit migration and reload coverage.
- Defaults initialize new class settings and thread Reset. Adding a default does not insert it into existing saved profiles. Do not overwrite user lists during registration or initialization; implement an intentional migration separately when needed.

## Add behavior variants without a preset menu

Reuse a named contract from `jungle.RoutineBehaviors.byName` when the evaluator semantics match. For new Warrior semantics, `RoutineBehaviors:RegisterWarrior(name, values)` validates all six boolean properties (`projectedSlam`, `coreFirstAoE`, `demoFallback`, `earlyDemo`, `allowsWowsims`, `allowsAdaptive`) and optional option mappings/handoff metadata. `legacyPolicy` is optional and exists for compatibility, not new behavior dispatch. Definitions and behavior tables are immutable by authoring convention; Lua does not enforce read-only tables.

The catalog's local `Register` helper still derives Warrior behavior from its numeric compatibility argument, and the compatibility loop expands Warrior definitions registered before that loop. For a new named contract, use `Config:Register` with the registered `behavior` table and fixed `mode` after the compatibility pass. Extend the legacy variant mapping only when importing an existing saved identity requires it. `RoutineBehavior.test.lua` contains a working registration example without `legacyPolicy`.

Choose a stable routine ID for a meaningfully different behavior or evaluator mode and declare it in the catalog. Do not add a user preset selector or saved Warrior `policy`/`mode` override. Original combat has an explicit maintenance variant alongside the baseline choice. Thread 3 defaults to Sweeping alone; its retired combat-fallback identities exist only for migration. The overlay reads each definition's metadata automatically.

`db.routineSchemaVersion` tracks version 3, Warrior `routineBehaviorVersion` version 2, and `routineIsolationVersion` version 1; preserve higher values during migration. Schema version 2 upgrades every saved profile's Warrior class settings, including unselected profiles. Existing policy/mode combinations map to deterministic compatibility IDs. Unusual variants are hidden from Add but remain visible, configurable and removable when saved; profile copy preserves them. Their step metadata is shared with the validated algorithm they actually execute, never with another algorithm retained only for historical switches. Fallback-only universal policy-3 identities are marked `retired` and archived under the class settings' `removedRoutineFallbacks`, then removed from runnable/displayed thread lists. Preserve their raw preferences in that archive and keep migration idempotent across all profiles. Keep those IDs stable across reloads, explicit false values and ordering intact, unknown records preserved, and duplicate/unimportable records visible with diagnostics. Do not remove compatibility definitions just because new users cannot add them. Druid's policy-dependent behavior remains unchanged.

## Author evaluators and metadata together

Return a reusable row table, or a shared empty table for an ineligible context. The row contract is:

```lua
{ diagnosticLabel, actionID, conditionBoolean, stopcastMetadata }
```

Row order is authored priority. Reset every reused row condition on every path that can return it. Row `[4]` is stopcast metadata, not an on-selection callback. New UI features must not silently change ordering, targeting, waits or this contract.

For every reachable row set, add matching `Config:AddRows(name, rows, descriptions)` metadata. Preserve row order, labels and action IDs; initial schema conditions are booleans, normally false. Give each row a useful description of its actual eligibility, context and preparation. Update descriptions when the condition or relevant helper semantics change. Describe meaningful helper behavior instead of showing only an opaque variable name. Metadata is static: the overlay must never execute a routine or parse source to obtain its step list.

The catalog definition declares:

| Field | Rule |
| --- | --- |
| `id`, `label`, `source` | Stable ID, readable name, real evaluator module path. Override the catalog helper's inferred path for specialized/non-class files. |
| `kind`, `class` | Class definition with exact class token, or support definition without class filtering. |
| `selector`, `functions` | Supported selector and nonempty callable evaluator array. |
| `rowSets` | Every reachable schema name, including own form/PvE/PvP/single-target/AoE/equipment branches. |
| `displayViews` | Optional static PvE/PvP/shared presentation: ordered sections referencing declared row sets and existing actions, summaries/tooltips, visible section `when` activation conditions, collapse defaults and applicable option keys. Covers every declared action/option across views; generic single view is the default. |
| `extraSteps` | Every dynamic action alternative or action not statically visible in those row sets, with a useful description. |
| `links` | Direct preparation-to-owner dependencies, e.g. `["Nature's Swiftness"]="Healing Touch"`. |
| `options` | Stable boolean option keys, human labels, defaults and descriptions; distinct from action enablement. |
| `behavior`, `mode` | Warrior: registered named behavior table and fixed `original`, `wowsims` or `adaptive` mode. Druid/support retain their existing `policy` adapter. |
| `reset` | Optional module reset function, deduplicated by function identity and called after compilation and on Engine thread changes. |
| `metadataFrom` | Optional registered source ID for variants with identical evaluator/schema/options/links references; reuse its validated step metadata. |
| `owns`, `hold` | Optional ownership and deliberate wait callbacks; inspect `Config:Run` ordering and context. |

For every actual dispatcher, author a separate step section for each mode: for example Original Arms/Fury, PvE/PvP, single-target/AoE, caster movement/forms, or scheduler phases. A combined action union with a general mode description is insufficient. Put the activation condition in the section's `when` string so it is visible under its heading. Project only that branch's eligible action possibilities and preserve its priority/dynamic alternatives; shared equipment or utility stages may be shown once with their own activation rule. Do not manufacture separate PvE/PvP or AoE branches when the evaluator uses the same table/priority. Row-level guards and action alternatives can remain described beside their owning steps. Maintain [the routine dispatch audit](../../docs/ROUTINE_DISPATCH_VIEWS.md) and `Core/RoutineDispatchViews.lua` when changing a dispatcher. Test actual eligible outputs against the relevant mode section, including dynamic action IDs; complete union coverage alone cannot establish mode accuracy.

Kebab intentionally uses two compact PvE blocks per the user's 2026-10-14 request. Keep Execute, unsafe-area and no-enemy eligibility in action/section descriptions and test actual outputs against the relevant block; do not recreate separate phase/context blocks for Kebab.

Display views are previews of authored branches, not runtime context selectors. Keep their descriptions, dynamic alternatives and option applicability synchronized with evaluators. Each definition validates its own views even with `metadataFrom`; reuse declared action identities and cover every declared action of the actual algorithm; retain unknown historical switches only in raw saved data. Display-step `before`/`after` anchors only arrange controls within a section. Tabs and collapse state stay transient; action switches remain shared across contexts in that placement. Never build presentation by calling an evaluator or parsing source. Do not represent a planner as a fixed numbered rotation.

The registry derives one semantic step per action ID, merging descriptions for repeated rows. Describe all its variants. A step checkbox changes all rows that emit that action in that placement; it does not reorder rows or edit arbitrary Lua expressions. Branch-level boolean preferences belong in options. Introducing another granularity requires coordinated schema, persistence, compilation, evaluator and UI design.

Class actions must match the existing class/global binding registries. Support definitions skip class identity filtering but still declare all emitted actions and use the existing execution boundary. If a new executable action is necessary, trace the binding/key/color/export implications under the development rules; never silently rename or reorder existing protocol identities.

Registration validates definitions, schema rows and dependency endpoints. An unknown class action can remain visible with `validationError` while being unavailable for addition/compilation. Runtime selection rejects non-table evaluator results and eligible undeclared actions, but does not deeply validate every inactive runtime row. Keep authoring tests responsible for complete row shape and dynamic alternatives; registration success alone is insufficient.

## Make disabling a step semantically complete

Before adding or changing a toggle, trace the action through conditions, readiness, preparation, resource reservations, timing windows, candidate ranking, scheduling, fallback suppression, ownership, equipment/macro decisions and retry state. Disabling the final returned row alone is insufficient.

Use `RoutineAllows(actionID)` for action-specific decisions. For repeated row gates, follow the existing fast path:

```lua
local actions = jungle.RoutineContext
    and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
rows[index][3] = (not actions or actions[rows[index][2]] ~= false)
    and authoredCondition
```

Here `authoredCondition` stands for the existing eligibility expression. The final selector mask is a backstop, not a replacement for evaluator gates. Shared readiness already checks masks, but direct cooldown/queue/planning decisions need their own audit.

- Disabled Slam must not cause prospective timing-window holds, movement waits or resource reservations for Slam elsewhere in that placement.
- Disabling a heal must also remove its prospective scheduler admission and preparation. For direct preparation dependencies use `links`; retain the user's preparation choice while its owner is disabled, show the blocked reason, and restore it only according to that saved choice.
- `links` currently compile in one `pairs` pass. Do not assume transitive graph resolution or cycle detection. Keep dependencies direct; a new dependency graph needs explicit deterministic resolution, cycle validation, UI explanations and tests before use.
- Disabling an action must release its future fallback suppression and ownership where appropriate. A disabled/all-optional-actions-off placement must not indefinitely hold the tick.
- Preserve factual state: an existing aura, queued attack, cast, equipment state or swing observation still exists after its future application is disabled. Required Stopcasting/StopFollow cleanup stays locked. Do not erase factual state to simulate action removal.
- Decision caches must distinguish placement identity/configuration revision so two copies with different switches cannot share a stale plan. Configuration/thread changes must reset prospective decisions while preserving factual observations.

Use compiled `entry.state` for placement-owned prospective plans. `Config:ResetDecisionState()` clears these tables and invokes registered `reset` functions once per function identity after compilation and on Engine thread changes. Reset module-local reservations/retry state through that callback while retaining factual observations. Adaptive binds its local decision fields to the current entry; shared spell costs, swing facts and nameplate observations remain factual. Intentional Original Thunder Clap preparation between maintenance and combat uses an explicit handoff key plus target GUID, physical thread and configuration revision. Test cooperation and rejection of stale/foreign handoffs; do not make unrelated placements share a decision cache.

## Keep saved, compiled and displayed state consistent

Use `Config:Add`, `Remove`, `Move`, `SetEnabled`, `SetStep`, `SetOption`, and profile methods from UI handlers. Direct shout edits must call `Config:Changed`; Warrior policy/mode edits are no longer user controls. Do not mutate compiled action masks/options from widgets or evaluators. Entry-owned runtime decision fields are allowed only as intentional transient state.

`Changed` saves preferences and refreshes the overlay. During combat, the saved/displayed state changes with a pending message while active compiled plans remain intact. After combat the new plans replace them atomically. Preserve this distinction for add/remove/reorder, switches and profile selection; never force a compile in combat to make displayed state appear active. Disk persistence is a client logout/reload outcome, not evidence from a table write.

Unavailable saved placements must remain visible with a useful reason and removable through More. Missing/malformed profiles, false switches and unknown IDs must not silently become enabled or erase unrelated saved data. New migrations should be idempotent and preserve explicit false values.

## Preserve the human overlay contract

Render controls from definition metadata and saved placement state. Use readable labels, consistent spacing, dark panels and the established accent; avoid unsupported arrow/ellipsis glyphs. Keep Run/Active, Reset, Steps, More, Add routine, profile selection and Stop meanings consistent. Disable duplicate/unavailable Add choices with a reason.

Hover shows steps; keeping the pointer over the row/popup retains them. Steps pins the panel, pressing it again closes it, and hovering another routine does not replace a pinned selection. Explicitly choosing another Steps panel changes the selection. More owns move/remove and Default shout. There is no selectable Priority preset menu. Long lists use bounded scrolling with a visible affordance.

Menus, steps and name prompts close on outside left/right click, Escape, Close, a second opener click, opening another menu or hiding/collapsing the main overlay. Profile cancellation releases focus without saving. Check delayed hover-close serials, stale placement indexes after refresh, hidden-widget callbacks, menu replacement and focus cleanup when changing these flows.

Retain event-driven outside-click detection, named unprotected Escape frames and screen-aware placement. Register the global mouse listener only while a transient panel is shown; avoid an input-blocking full-screen shield. Steps choose usable right/left space or bounded above/below space and resize their content consistently. Do not add per-frame layout/polling. Verify any changed UI API/event against the required Anniversary branch, installed build and TOC, with the source path/revision recorded as described in the development skill and [API reference notes](../../docs/ROUTINE_CONFIGURATION.md#anniversary-api-reference).

## Complete a synchronized change

Scale verification to the behavior changed; do not run unrelated suites merely for wording changes. For routine/configuration changes, check relevant scenarios below with actual evaluators and meaningful mocks:

- All enabled versus the exact pre-edit behavior; each supported action disabled and re-enabled, preparation off, authored action alternatives available, no hidden routine substitution, all optional actions off and deliberate ownership release.
- Valid/missing/dead/friendly enemy contexts, target loss/reacquisition, applicable form/stance, movement, resources/casts and existing factual queued/aura state.
- Same routine in two different threads with different switches; fixed definition behavior after moving to another physical thread; sequential versus joint priority where applicable.
- Definition/schema completeness, dynamic actions, missing evaluators, invalid selection and unavailable placements. The fixture's stub evaluators/hotkeys do not prove real registration or behavior: load production evaluators and binding registries in the relevant checks.
- Profile copy/switch/reload, class isolation, false preservation, migration, combat deferral and stale decision resets.
- For UI changes: actual callbacks with mocked events, outside/Escape/second-click dismissal, pinned/hover selection, focus cancellation, disabled choices, scroll limits, screen edges and refresh/removal cleanup.

For fixed Warrior behavior changes, use `RoutineBehavior` for migration/defaults/identity and reset registration, `RoutineBehaviorParity` for actual compiled evaluator comparisons across modes and physical threads, and `RoutineDecisionState` for independent preparation/retry plans, cast attribution and scoped handoffs. The parity suite takes the immediate pre-change checkpoint directory and compares unchanged owned branches while asserting intentional retirement/ineligible-context suppression; do not require parity with removed substitutions. Original/Arms/Fury/maintenance/Sweeping must remain independent of another algorithm's settings. `RoutineIsolation` checks these routing boundaries; `RoutineDispatchViews` checks mode-specific eligible action coverage and dynamic equipment/support selection; the older Engine-refactor suites use their own earlier baseline. See the configuration notes for retained checkpoint locations. Include idle/unbound legacy calls when changing the behavior adapter; they must retain neutral legacy behavior.

Use the existing suites as starting points: `RoutineConfig`, `RoutineSteps`, `OptionalEnemy`, `HealingSnapshot`, class-specific tests, `RoutineUI` and `RoutinePerformance`. Tests stay outside the production TOC. Some differential tests require an exact checkpoint path (and HealingSnapshot's comparison mode); inspect their arguments rather than using a ZIP or the current file as a baseline. Parse changed files with Lua 5.1; broad cross-module changes justify parsing all addon Lua files.

The large Warrior Arms evaluator approaches Lua 5.1's 60-upvalue limit per function. Inspect captured locals before extending it; a reused module-local state record can group related fields without adding captured variables or per-tick allocation. Parse the evaluator after such edits.

Keep discovery, validation, metadata construction and profile compilation off the dispatch path. Reuse rows and decision tables; preserve the all-enabled fast path. The allocation suite checks 10,000 warm dispatches, not live CPU/frame time. Measure changed evaluation work appropriately; no allocation does not prove zero performance impact.

Update schemas, catalog/options, tests and user notes in the same change whenever their contract changes. Finish with a brief report of changed behavior, actual checks and remaining bounded live steps: `/reload`, `/olia options`, relevant combat/target scenarios, persistence and `/oliaperf` when evaluation costs change. Do not claim live rendering, spell execution or performance from mocked tests. Ordinary routine additions should not require a custom UI patch; if they do, identify the missing generic contract explicitly.
