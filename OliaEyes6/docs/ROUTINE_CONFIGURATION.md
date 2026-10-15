# Routine configuration

## Kebab (2026-10-13)

`Kebab` (`warrior.kebab`) is an independent PvE single-target/AoE dual-wield Arms
definition. Add it explicitly through **+ Add routine** on any class thread 1-6.
Existing defaults and placements are not replaced. Steps exposes single-target and
AoE Normal/Execute, area-blocked and no-enemy branches, all 23 optional action
identities plus required Stopcasting cleanup, and 11 per-placement preferences.
PvP/ineligible contexts clean witnessed queues, then release to the next explicitly
placed routine. Safe AoE uses SS/Cleave/WW; no shared evaluator is wrapped.

Normal single-target HS queue/cancel is standard behavior under the HS action switch.
Ready MS/WW precedes new queues/self buffs; temporary admission needs confirmed MH
headroom and actual client usability. Paid HS retains the exact costs of all cores
due by their independent cooldowns before the next possible normal MH: 42/37/67 with 12-rage HS and MS/WW
costing 30/25. No extra rage buffer/floor. Unknown timing conservatively funds both
cores; no speculative rage income. The old `mainhand_queue` preference is retained
only in raw historical saves, not compiled or displayed. The aggressive Hamstring
exception is also retired. Both ready/closely due cores stay reserved despite
a shared GCD. Optional GCD buffs need a full 1.5s core gap; paid optional actions
retain an already funded HS payment as well as upcoming/next cores. Off-GCD
Bloodrage/trinkets remain available while pooling. See [Kebab policy, API
provenance and live checks](WARRIOR_KEBAB.md). Its fixed named behavior uses the
registry's `original` compatibility mode token; its own evaluator
and `kebab` algorithm select the new policy. It does not inherit Original damage.

Open `/olia options` after `/reload`. Expand a thread with **+ / -**, choose **+ Add routine**, and use the checkbox beside each routine. **More** contains Move up, Move down and Remove from this thread. **Run** selects that thread; **Stop** selects thread 0. The existing thread hotkeys still work. The Engine starts idle after each reload.

Threads 1-6 offer the same catalog for the current class. A routine can be used on several threads with independent switches and options. A thread runs its routines from top to bottom and stops when one selects an action or deliberately holds the tick. Tank + raid and Dispel + V6 are also available as joint friendly-selection routines: their authored row priorities compete across both component routines. Separate placements have sequential priority instead.

Thread 7 offers only Fishing and Follower. Their original eligibility remains inside those modules, including Follower's Druid Tree of Life logic. With the default support list, an equipped fishing pole selects Fishing exclusively. If Fishing is disabled or removed, Follower remains available with a pole. Support routines cannot be placed on threads 1-6; class routines cannot be placed on thread 7.

Hover a routine and keep the pointer over its row or step popup to inspect and toggle its actions. **Steps** pins the popup while you edit; pressing Steps again closes it. Scroll long lists with the mouse wheel; a slim scroll indicator shows when more items are available. All popups have a Close button and dismiss on outside left/right click or Escape. Opening another menu replaces the previous popup. Leaving a hover-only step popup dismisses it after a short delay. All authored rows that emit the same action form one semantic step. Its tooltip includes their conditions; row order and targeting rules remain authored. Required Stopcasting/StopFollow cleanup stays available. Turning off the whole routine or all its optional actions releases its tick ownership.

**Steps views:** Druid DPS, legacy universal healing and Warrior Arms/Fury/universal routines expose manual **PvE / PvP** tabs. A tab previews that authored branch; it does not force the evaluator into that context. Switching a tab or expanding a section pins the popup. Action switches apply across every context and section of the same placement; other placements keep their independent settings. Tabs themselves do not change saved action settings. Hover an action for that view's conditions and a section heading for its explanation.

Each actual dispatcher has separate sections with its activation condition visible under the heading. Original displays Arms and Fury separately under both PvE/PvP tabs, with single-target/AoE sections and spec equipment prepasses. Fury also separates Bloodthirst/Mortal Strike builds and fast/slow off-hand equipment modes. Arms shows the core-first Sweeping-active/inactive AoE priorities when that behavior applies. WoWSims separates single-target/AoE and explains unavailable PvP. Adaptive separates single/boss/AoE, blocked-area observations, no-enemy shouts and equipment; these are planner possibilities rather than a fixed rotation.

Druid DPS separates moving/stationary Moonkin/caster, Cat stealth and Mangle/Claw, Bear single-target/AoE with Mangle/Lacerate, and powershift/equipment. V6 displays raid scheduler stages and its legacy unit-selection groups. Rogue displays stealth/weapon/position branches; Follower displays rest, Tree of Life, ground/flying travel and driverless maintenance; Fishing displays casting/lure states. Routines using one shared table retain one view. See [the complete routine dispatch audit](ROUTINE_DISPATCH_VIEWS.md). Sections expand/collapse with **+ / -**, and their state and the chosen tab survive refresh while that placement is selected. Repeated actions share one switch across sections.

Warrior behavior belongs to the selected routine; there is no **Priority preset** menu. Original, **Arms — WoWSims** and **Arms — Adaptive** are independent choices. **Original combat / maintenance** preserves thread 1's explicit combat stage. Thread 3 defaults to Sweeping alone; **Original combat / Sweeping fallback** has been retired. Each choice behaves the same on any thread 1-6. Choose **Default shout** in More; right-clicking a routine also opens More. Own PvE/PvP/form/AoE dispatch branches and action alternatives remain authored. An ineligible routine returns no action and never substitutes another algorithm. Only a later explicitly configured placement can run after release.

## Profiles and saving

The profile menu provides New, Copy, Rename, switch and Delete. Delete applies to another profile; the selected profile cannot be deleted. Copy includes every class configuration already stored in that profile. A profile stores separate class settings, so characters of different classes can share its name without replacing each other's lists.

The initial profile is named `Character - Realm`. Each character remembers its selected profile. Changes are written to the existing `OliaEyes6_Settings` SavedVariables table immediately; the WoW client flushes that table on logout/reload. There is no separate Save button. Existing Warrior mode/options migrate into the initial placements, including explicit false values. Old settings are retained for compatibility. Each thread's Reset restores the original Engine class defaults for that thread; support Reset restores Fishing + Follower.

During combat, edits and profile selections update the saved configuration and display **Saved / applies after combat**. The active compiled plan stays intact until `PLAYER_REGEN_ENABLED`, when the new plan replaces it. This includes additions, removals, ordering, step masks and options. Changing the active thread still selects its currently compiled plan.

Defaults preserve Druid and Rogue ordering; Warrior thread 3 now contains Sweeping alone. Thread 7 intentionally becomes support-only. Other class files currently contain no implemented rotations and show no class choices. Diagnostic test routines and the deliberately empty Druid interrupt placeholder are excluded.

## Fixed Warrior behavior and compatibility

Saved Warrior policy/mode combinations are upgraded across every profile to stable routine IDs. Existing order, enabled state, step switches, options and shout preferences remain. Migration is idempotent and does not reset profiles. Unknown records retain their data; duplicate or unimportable records remain visible with an error and can be removed.

The Add menu contains independent authored choices and Original combat / maintenance. Fallback-only universal policy-3 compatibility entries are archived under `removedRoutineFallbacks` with their thread/index and raw preferences, and removed from every saved profile's thread list. `routineSchemaVersion=3` and class `routineIsolationVersion=1` record this idempotent migration; higher versions remain intact. An unusual old combination remains as a labeled saved compatibility routine, using its selected algorithm only. Specialized Arms/Fury/maintenance/Sweeping imports keep their own evaluator even if an old mode field names another algorithm. These compatibility choices are hidden from Add but their existing placements can still be edited, reordered, removed and copied with a profile. This prevents silently replacing a user's old configuration with another priority. Druid behavior, support eligibility and the action/key/pixel protocol remain unchanged.

## Modules and import contract

- `Core/RoutineBehavior.lua`: named Warrior behavior contracts and compatibility adapters, constructed at load.
- `Core/RoutineConfig.lua`: registry validation, migration, profile operations, plan compilation, decision reset lifecycle and dispatch.
- `Core/RoutineSchemas.lua`: static authored row descriptions. No source parsing or evaluator execution occurs to construct the UI.
- `Core/RoutineDispatchViews.lua`: static projections of authored mode branches, loaded after schemas and before the catalog.
- `Core/RoutineCatalog.lua`: evaluator/selector declarations, supported actions, dependency links and class defaults.
- `Core/RoutineUI.lua`: event-driven overlay and profile controls. No additional OnUpdate handler.

Routine definitions may author static `displayViews` in the catalog. Each view has a unique `id`, `label`, optional `description`, ordered `sections` and optional option-key list. A section declares its `label`, optional explanation, visible `when` activation condition/default `collapsed` state, reachable `rowSets`, and `steps` for dynamic alternatives or summaries. Display steps use existing action IDs and may specify `summary`, `description`, `label`, or a `before`/`after` action anchor within that section. Schema descriptions merge within the section, keeping context tooltips separate. Option keys omitted from a view default to all definition options; an explicit list selects only those applicable to that view.

Registration validates schema/action references, dynamic anchors, view identity, and complete action/option coverage across the views. Empty dynamic schema placeholders remain excluded from controls, matching the existing action registry. Definitions without presentation metadata receive a generic single view. `metadataFrom` still shares execution step metadata; each definition validates its own presentation, using only the algorithm's own declared actions. Unknown historical action preferences remain in raw saved data without unrelated menu controls. Views are built at registration and never execute evaluators, parse source, enter compiled action masks, or persist tab/collapse state.

A definition needs a stable `id`, `label`, source path, class/support category, selector (`rotate` or `dpsRotate`), evaluator function array and declared row sets. Row metadata must contain string labels/action IDs and boolean initial conditions. Dynamic action alternatives must be included in `extraSteps`. Class action identities are checked against the fixed class/global hotkey registries; support logic is not class-filtered. Missing evaluators, row schemas and invalid dependencies cannot register; invalid action identities cannot compile or be added through the UI.

Evaluators keep the existing `{label, actionID, eligible, stopcastMetadata}` row format and authored order. They return a shared empty table for an ineligible context, or reusable rows where practical. An evaluator returning a non-table or selecting an undeclared action is isolated from subsequent dispatch and reports its error once. Unavailable saved placements remain visible and removable.

Read `jungle.RoutineContext` only during evaluation. Compiled masks/options are per placement and must not be mutated by evaluators. `allEnabled` allows row gates to skip mask lookups for default configurations:

```lua
local actions = jungle.RoutineContext
    and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
rows[index][3] = (not actions or actions[rows[index][2]] ~= false)
    and authoredCondition
```

A final row gate is necessary but insufficient. Gate the decision that requests preparation, reserves resources, ranks candidates, blocks a fallback, owns a tick or updates an action-specific macro. The shared spell readiness helpers enforce masks; direct cooldown/talent/queue decisions must enforce the same contract. Factual state, such as an already queued attack, aura or in-progress cast, remains real until the client clears it. Runtime caches of decisions must include placement identity. Configuration changes reset prospective reservations without deleting factual swing observations.

Examples covered here include Slam holds and timing projections; enabled-only Warrior core funding, gap-closer/interrupt/Thunder Clap preparation and Sweeping ownership; Lifebloom scheduler admission and per-placement V6 caches; Healing Touch with Nature's Swiftness preparation; disabled Backstab's Sinister Strike fallback; Follower Tree/Mount/rest preparation; and Fishing's Lure retry timestamps. Links disable Nature's Swiftness preparation together with Healing Touch; the popup shows the unmet prerequisite and blocks that preparation checkbox until its owner is enabled. Other enabled actions retain authored aura-dependent behavior; disabling future applications does not pretend an existing aura disappeared.

Adding a routine requires its schema/catalog entry, dependency audit, enabled/disabled/fallback tests and an explicit default placement if it should run initially. Preserve stable action IDs, binding order, pixel colors, focus handshake and row [4] stopcast metadata.

## Authoring behavior and lifecycle

Warrior definitions reference a validated named `behavior` and a fixed `mode`. Read semantic properties through `GetWarriorRoutineBehavior()`; `GetRoutineThread()` remains the existing Druid/legacy adapter. New semantics can register a named behavior with `RoutineBehaviors:RegisterWarrior` without a numeric legacy policy. These tables are immutable by convention. New behavior variants use new stable routine IDs and share validated metadata through `metadataFrom` only when evaluator/schema/options/links references match.

Each compiled placement owns `entry.state` for prospective decisions. `Config:ResetDecisionState()` clears it and calls registered `reset` callbacks, deduplicated by function identity, after compilation and when the Engine changes thread. Adaptive preparation, sampling and retry windows bind to that placement. Shared factual swing observations, spell costs and observed enemies remain available. Original maintenance can hand off Thunder Clap preparation to compatible combat only for the same named handoff, target GUID, physical thread and configuration revision.

Keep evaluator, schema and catalog declarations synchronized as described in the [project authoring skill](../skills/oliaeyes6-routines-overlay/SKILL.md). This change establishes the behavior/lifecycle contract; it retains the authored algorithms and static metadata rather than rewriting every rotation as a new language.

## Verification and remaining live checks

The Lua 5.1 suites compare all-enabled behavior against the exact pre-edit checkpoint, exercise profile migration/reload/combat deferral, actual UI callbacks with mocked frames, class/support routing, dependent step behavior and malformed evaluator results. The dispatch allocation test runs 10,000 warm dispatches with garbage collection stopped and disallows discovery, profile identity reads, compilation and UI refresh. Healing readiness comparisons retain identical cooldown/usability API counts.

A mocked CPU benchmark of actual routine code after optimization measured approximately 0.036 ms per Warrior evaluation versus 0.034 ms before, and 0.275 ms per 25-unit Druid evaluation versus 0.262 ms before (5 batches of 5,000 evaluations; local Lua 5.1 runtime). These are routine-only measurements, not installed-client frame timings. Configuration adds small CPU overhead; unchanged frame rate has not been established. An intentionally longer user-created routine list can also evaluate more work than the old presets.

Live checks remain necessary:

1. `/reload`, open the overlay, check dropdown/hover scrolling, small-screen clipping, checkboxes, More/Steps controls and profile name entry; inspect Lua errors.
2. Save a per-thread action change, copy/switch profiles, reload and log into another character/class. Verify persistence and the Engine's idle startup.
3. In combat, edit/remove/reorder a placement and switch profiles. Verify pending status, unchanged active plan and the new plan after combat ends.
4. Verify real actions and deliberate waits with valid/missing targets, movement, forms/stances, queued attacks and casts. Exercise Slam off/on, disabled preparation actions and healing/support fallbacks separately.
5. Compare `/oliaperf 15` reports before/after in matching solo, dungeon and 25-unit raid conditions with the overlay both visible and hidden. Compare Engine/rotation tails, Lua memory and responsiveness; do not infer performance from the mocked timing alone.
6. Check the unchanged focus/action protocol with existing hotkeys and `/olia dump`. No action registry, binding order or pixel geometry was edited.

Exact preimages, postimages, unified edit hunks and test/benchmark results are retained outside the addon load path at `C:/Users/freeker0k/.codex/task-checkpoints/olia-thread-profiles-20261004`. Reverse only recorded hunks whose postimages still match; do not replace files over later edits.

## Anniversary API reference

Reference: Gethe/wow-ui-source `classic_anniversary`, revision **1463c686270b6c64e2c5c228f447c4597c0f8ba6**, **2.5.6 (69795)**. The installed `WowClassic.exe` file version is **2.5.6.69795**. `OliaEyes6.toc` retains **20504**; this change does not migrate that compatibility declaration. The verified source snapshot is retained outside the addon.

- SavedVariables initialization uses the first `ADDON_LOADED` payload argument: [AddOnsDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnsDocumentation.lua#L368), with a matching consumer in `Blizzard_FrameXML/GhostFrame.lua`.
- Character identity and combat-end event: [UnitDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua#L705); `GetRealmName` fallback is used by `Blizzard_UIPanels_Game/Classic/FriendsFrame.lua`. Lockdown is documented in [RestrictedActionsDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_APIDocumentationGenerated/RestrictedActionsDocumentation.lua). `Blizzard_RestrictedAddOnEnvironment/SecureStateDriver.lua` consumes `PLAYER_REGEN_ENABLED`.
- Previous Classic dropdown signatures and lifecycle (the current overlay uses its own simple frame menus): [UIDropDownMenu.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_SharedXML/Classic/UIDropDownMenu.lua#L76), with the matching template in `UIDropDownMenuTemplates.xml` in that directory.
- Hover, script hooks and wheel handling: [SimpleScriptRegionAPIDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionAPIDocumentation.lua#L428). Frame positioning/clamping uses `SimpleFrameAPIDocumentation.lua` and `SimpleScriptRegionResizingAPIDocumentation.lua`.
- Scroll child/offsets: [SimpleScrollFrameAPIDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScrollFrameAPIDocumentation.lua). Profile text entry uses `SimpleEditBoxAPIDocumentation.lua`; buttons use `SimpleButtonAPIDocumentation.lua`.
- Delayed hover dismissal uses `C_Timer.After`, with a matching use in [Blizzard_DebugTools.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_DebugTools/Blizzard_DebugTools.lua#L301).

These references establish API signatures and Blizzard implementation behavior. Popup rendering, actual SavedVariables disk persistence, combat interaction and performance remain bounded live verification tasks, not conclusions from documentation.


### October 4 interface follow-up

The routine overlay uses dark panels, a teal active indicator, consistent spacing and ASCII control labels. Reorder/removal and shout selection share the named More menu. No special arrow/ellipsis font glyphs are needed. The UI creates/reuses simple frame widgets when configuration or selection changes; it adds no OnUpdate loop.

Outside-click dismissal registers `GLOBAL_MOUSE_DOWN` only while a menu, step popup or profile prompt is visible, and releases the listener when all are closed. It observes left/right clicks without an input-blocking overlay. The event payload is documented in [SystemDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_APIDocumentationGenerated/SystemDocumentation.lua#L63). A matching outside-menu cursor check is in [Blizzard_Menu/Menu.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_Menu/Menu.lua#L1905); its framework is not imported by this overlay.

Escape integrates named unprotected popup frames into `UISpecialFrames`, guarded for availability, following [UIParentPanelManager.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua#L1041). Profile prompt dismissal calls the documented `EditBox:ClearFocus`; checkmark texture/color and single-line font behavior were checked in `SimpleEditBoxAPIDocumentation.lua`, `SimpleCheckboxAPIDocumentation.lua`, `SimpleRegionAPIDocumentation.lua` and `SimpleFontStringAPIDocumentation.lua` from that same reference revision. Installed client version remains 2.5.6.69795; TOC 20504 is unchanged.

The steps popup prefers the available right or left side, resizes its rows to fit, and uses bounded space below/above the routine when neither side fits. Rectangle APIs may return no coordinates before layout, so that case falls back to screen clamping. API contracts are in [SimpleScriptRegionAPIDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionAPIDocumentation.lua#L101); the matching Classic dropdown checks screen edges using those coordinates in [UIDropDownMenu.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_SharedXML/Classic/UIDropDownMenu.lua#L1159). The addon frames inherit UIParent's scale, so their dimensions and coordinates share UI units. A pinned steps panel remains selected when another routine is only hovered.

`tests/RoutineUI.test.lua` exercises the actual UI handlers with mocked mouse events and the reference Escape name lookup. It covers menu replacement/dismissal, disabled duplicate choices, reordering/removal, fixed routine identity/shout selection, pinned/hover step behavior, pending combat edits, profile validation/cancellation/focus, scroll bounds, text anchors and popup cleanup on hiding the overlay. `tests/RoutineConfig.test.lua` retains the broader profile/dispatch checks. Actual client rendering, click propagation and Escape/input behavior still require `/reload` and a bounded in-game check, including combat and both screen edges.

The interface follow-up checkpoint and exact edit ledger are separate from the Engine refactor: `C:/Users/freeker0k/.codex/task-checkpoints/olia-routine-ui-20261004`.

UI follow-up validation: all 19 standalone suites passed; all 65 Lua files parsed with Lua 5.1. The UI suite passed 375 mocked layout, dismissal, focus and interaction checks, including narrower viewports, both screen edges and pinned-step selection. The unchanged dispatch allocation check measured 0 KiB across 10,000 warm dispatches. These checks do not establish live rendering or installed-client frame timing. Results are retained in the interface checkpoint.

### Fixed behavior implementation verification

The exact pre-implementation checkpoint is `C:/Users/freeker0k/.codex/task-checkpoints/olia-fixed-routine-behavior-20261004/before`; the parent directory retains the edit ledger, postimages and verification results. Behavior differential checks use this checkpoint, while older refactor comparisons retain their original exact baseline.

Migration checks cover all 168 legacy Warrior definition/mode/policy combinations across selected and unselected profiles, reload idempotence, false preferences, defaults, duplicates, unavailable records, class isolation and combat deferral. Actual evaluator comparisons cover 3,906 compiled evaluations, ordered rows and action/wait outcomes across target transitions, movement, AoE, disabled steps and physical threads. State tests exercise independent Adaptive Thunder Clap preparation, Slam planning and trinket retry dwell, attributed cast completion, event invalidation and the scoped Original maintenance handoff. These use mocked client APIs and a shadow selector; they do not prove live range, spell success or rendering.

Adaptive retains its existing event API signatures. The matching reference documents `NAME_PLATE_UNIT_ADDED/REMOVED` in [NamePlateManagerDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_APIDocumentationGenerated/NamePlateManagerDocumentation.lua#L113), consumed by `Blizzard_NamePlates/Blizzard_NamePlates.lua` (lines 53-58). `UNIT_SPELLCAST_SUCCEEDED` payload order is documented in [UnitDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua#L3283) and consumed by `Blizzard_UnitFrame/Classic/UnitFrame.lua` (lines 232-234). `PLAYER_REGEN_ENABLED` is documented in that same generated file (line 2352). All references use the verified Anniversary revision/build above; TOC 20504 is unchanged. Cast attribution uses the addon's recorded selection and revision/thread guards, not a new Blizzard ownership guarantee. Live verification still needs the bounded combat/event checks listed above.

Final fixed-behavior validation: all 22 standalone suites passed; all 69 Lua sources parsed with Lua 5.1 (the pre-existing UTF-8 BOM in unchanged `Pixels.lua` was stripped only in the parser input). `RoutineBehavior` passed 1,053 migration/identity/lifecycle checks, `RoutineBehaviorParity` passed 8,985 checks, `RoutineDecisionState` passed 22 checks, and `RoutineUI` passed 380 checks. Dispatch allocated 0 KiB over 10,000 warm iterations. Both project skills passed the skill metadata validator.

A separate bounded benchmark compared actual routines under compiled contexts with the immediate pre-implementation checkpoint: 5 batches of 2,000 evaluations per case, with mocks, warm caches and advancing fixture time. Mean milliseconds before/after were Original 0.0395/0.0320, WoWSims 0.0142/0.0141, Adaptive 0.0382/0.0390 and Druid 25-unit V6 0.2706/0.2746. These small fixture measurements include noise and do not establish unchanged in-game FPS; Adaptive's measured increase was about 2%. Compatibility definitions share step metadata and are constructed outside dispatch. Longer configured lists still perform more evaluator work.

### October 5 PvE/PvP steps views

This presentation change retains evaluator code, dispatcher order, action IDs, the key/color protocol, per-placement saved switches and combat compilation deferral. The new view metadata is authored in `Core/RoutineCatalog.lua`, validated by `Core/RoutineConfig.lua` and rendered generically by `Core/RoutineUI.lua`. Short summaries supplement detailed context-specific tooltips. The October 6 isolation change below supersedes this version's cross-routine fallback controls.

UI APIs were rechecked against the retained `classic_anniversary` snapshot **1463c686270b6c64e2c5c228f447c4597c0f8ba6**, matching installed **2.5.6.69795** and TOC **20504**. Tab hover uses [SimpleScriptRegionAPIDocumentation.lua:HookScript](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionAPIDocumentation.lua#L299). Layout uses the existing [SetHeight/SetPoint contracts](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionResizingAPIDocumentation.lua#L114) and the screen-edge comparison in `Blizzard_SharedXML/Classic/UIDropDownMenu.lua:1159`. Escape still follows `Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua:1041`. No new client API or event is introduced.

Validation: `RoutineConfig`, `RoutineUI`, `RoutineSteps`, `RoutineBehavior`, `RoutineViews` and `RoutinePerformance` pass with mocked client APIs; all addon Lua files parse with Lua 5.1. The new suite checks actual evaluator/binding registration, context ordering/descriptions, dynamic alternatives, complete display coverage, malformed metadata, shared switches, independent placements, refresh/collapse state and combat deferral. The allocation check remains 0 KiB over 10,000 warm dispatches. These checks do not establish live rendering.

Bounded live check: `/reload`, `/olia options`, open Druid DPS or Warrior Universal Steps; compare both tabs and expand each owned section, toggle an action and confirm its shared setting in the other view. Check hover/pinning, scrolling and placement at screen edges; repeat an edit during combat and verify the pending message and application after combat. Reload once to confirm the action preference persists. Exact preimages, postimages and edit hunks are retained outside the addon at `C:/Users/freeker0k/.codex/task-checkpoints/olia-step-views-20261005`.

### October 6 routine isolation

WoWSims and Adaptive now have independent guarded evaluators. They return no action when ineligible instead of entering Original/Fury. Original keeps its authored Arms/Fury dispatcher; each routine retains its own PvE/PvP and single-target/AoE branches. Adaptive uses an explicitly utility-only projection of Arms decisions in its own PvP branch. Loading Adaptive does not wrap any other evaluator or ownership callback. Maintenance retains its own preferences when explicitly placed before another routine. An empty or waiting algorithm does not secretly start another one; the existing explicit placement order and deliberate holds still apply.

Schema/catalog views now include complete WoWSims AoE order, Adaptive PvE action metadata, dynamic Arms Overpower/Thunder Clap, Fury Mortal Strike and Druid Cat powershift return. No unrelated Original/Fury fallback section or fallback-only Add/default entry remains. Both authoring skills prohibit reintroducing these substitutions and require complete display of valid internal dispatchers.

No client API, event or binding protocol changes. Eligibility was checked against the retained `classic_anniversary` revision **1463c686270b6c64e2c5c228f447c4597c0f8ba6**, installed **2.5.6.69795**, TOC **20504**: [UnitIsPlayer / UnitPlayerControlled documentation](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua#L1340), with `UnitPlayerControlled` also consumed in `Blizzard_UnitFrame/Classic/UnitFrame.lua:433`. Branch availability and ownership are addon policy, not a Blizzard guarantee.

After `/reload`, inspect `/olia options`: Thread 3 should show Sweeping only unless you explicitly added another routine. Check Original/Arms/Fury PvE/PvP, WoWSims single target/AoE and ineligible PvP, Adaptive PvE/PvP/AoE, and Druid form/powershift sections. Verify action switches, combat deferral, profile reload and waiting/target-loss behavior. Static/mock results do not prove live rendering or spell execution. Exact preimages, postimages and hunks are retained outside the addon at `C:/Users/freeker0k/.codex/task-checkpoints/olia-routine-isolation-20261006`.

Offline validation: all **25** standalone suites passed; all **72** Lua files parsed under Lua 5.1. The final metadata/defensive-migration edits were rechecked with RoutineIsolation (**534** checks), RoutineViews (**38,494** checks), RoutineBehavior (**1,229** checks), RoutineConfig, RoutineUI and RoutinePerformance. RoutineBehaviorParity checked **4,221** compiled evaluations for unchanged owned behavior, intentional retirement and routing independence. Warm dispatch still allocated **0 KiB over 10,000 iterations**. Both updated project skills passed the skill validator. These results use mocked APIs and do not establish live performance or rendering.


### October 6 dispatch structure audit

All registered canonical routines and imported Warrior behavior identities were checked against their own evaluator. Static branch projections now expose the actual context, spec, target-count, form, movement and phase switches; combined action unions are no longer used to conceal those dispatchers. Missing existing actions were declared: Fury fast/slow off-hand returns, Sweeping Mortal Strike, Tank Sunder Armor, and Follower Tree of Life. This fixes compiled selection rejecting these eligible undeclared actions. Arms no longer declares Fury-only off-hand actions. Existing evaluator logic, fixed hotkey registries and pixel protocol were not edited.

Activation text wraps and its measured height contributes to the existing bounded scroll layout. APIs: `FontString:SetWordWrap` and `GetStringHeight`, [SimpleFontStringAPIDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua#L316); matching width/height layout in [ScrollTemplates.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_SharedXML/Shared/Scroll/ScrollTemplates.lua#L318). Reference remains verified classic_anniversary revision 1463c686270b6c64e2c5c228f447c4597c0f8ba6, installed 2.5.6.69795, TOC 20504.

`RoutineDispatchViews.test.lua` compares eligible actual evaluator outputs with their applicable mode sections and checks dynamic equipment/support actions through their own declarations. `RoutineViews` checks validation, wrapped activation text and shared switches via actual UI callbacks. Existing profile migration, combat deferral, screen-edge scrolling, isolation and allocation suites remain applicable. Exact preimages/postimages, hunk ledger and verification results are retained at `C:/Users/freeker0k/.codex/task-checkpoints/olia-dispatch-views-20261006`. After `/reload`, open `/olia options`, compare these sections, test the shared action switches and scroll/wrapping at both screen edges. Mocked checks do not establish in-game rendering or spell execution.


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
