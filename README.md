# TBC Anniversary

World of Warcraft Classic Anniversary project containing the `OliaEyes6` addon and the `OliaFingers2` companion folder.

## OliaEyes6

`OliaEyes6` is the in-game Lua addon. It evaluates configured routines, displays action and focus instructions through colored pixels, and creates secure buttons and key bindings used to execute those instructions through input. The addon and external input consumer share an action/key/color protocol; their mappings must agree.

The current addon declares interface **20504** in [OliaEyes6.toc](OliaEyes6/OliaEyes6.toc) and targets the Classic Anniversary/TBC client.

### Implemented features

- **Druid:** healing, including the V6 Lifebloom scheduler, tank/raid healing, dispels, buffs, form-aware damage and equipment handling.
- **Warrior:** Original Arms/Fury, tank and maintenance routines, a Sweeping Strikes sequence, Arms WoWSims, Arms Adaptive, and the independent PvE dual-wield Arms Kebab routine.
- **Rogue:** a damage routine with stealth, weapon and position conditions.
- **Support:** Fishing and Follower routines on a dedicated support thread.
- **Configuration:** an in-game overlay with ordered routine lists, action switches, per-routine options and profiles.
- **Diagnostics:** binding exports, debug displays, swing tracking, performance reports and bounded raid recordings.

Other class files are present as placeholders; their class rotations are not implemented in the current catalog. Available actions remain subject to each routine's talents, equipment, form and encounter conditions.

### Installation

1. Copy this repository's `OliaEyes6` directory into your Anniversary client's `Interface/AddOns/` directory.
2. Confirm the resulting path is `Interface/AddOns/OliaEyes6/OliaEyes6.toc`, without an extra nested directory.
3. Enable **OliaEyes6** in the character selection AddOns menu, then log in or `/reload`.
4. Open `/olia options` to configure routines. The Engine starts idle after each reload; select a thread with **Run** when ready.

This installs the addon component. External input setup is covered by the pending `OliaFingers2` documentation below.

### Routines and profiles

Threads **1-6** accept routines from the current class's catalog. Each thread evaluates its configured routines from top to bottom until a routine selects an action or deliberately waits. The same routine can appear on several threads with independent settings.

Thread **7** accepts only Fishing and Follower. Their own eligibility checks determine when they run.

In `/olia options`:

- Expand a thread and choose **+ Add routine** to add a placement.
- Use its checkbox to enable or disable it, **Steps** to inspect and toggle actions, and **More** for options, ordering and removal.
- Use **Run** to select a thread and **Stop** to return to idle.
- Use the profile menu to create, copy, rename or switch profiles. Profiles retain separate class configurations.

Settings are stored in `OliaEyes6_Settings` and written to disk by the client on normal logout or reload. Routine and profile edits made during combat are saved for application after combat.

See the [routine configuration guide](OliaEyes6/docs/ROUTINE_CONFIGURATION.md) for detailed controls and behavior.

### Useful commands

| Command | Purpose |
| --- | --- |
| `/olia options` | Toggle the configuration overlay. |
| `/olia center` | Recenter the overlay. |
| `/olia debug` | Toggle the hotkey debug display. |
| `/olia dump` | Export the current binding mappings. |
| `/olia enemies` | Print enemy-focus diagnostics. |
| `/olia demo` | Print Warrior Adaptive Demoralizing Shout diagnostics. |
| `/oliaperf 15` | Collect a 15-second performance sample. |
| `/oliaperf report` | Print the performance report. |
| `/oliatrace start 600` | Start a bounded raid performance recording. |
| `/oliatrace stop` | Stop the current recording. |
| `/oliatrace status` | Show recording status. |

For recording contents, retention and export instructions, see [raid performance recording](OliaEyes6/docs/RAID_TRACE.md).

### Source layout and development

| Path | Contents |
| --- | --- |
| `OliaEyes6/OliaEyes6.toc` | Addon metadata, SavedVariables and file load order. |
| `OliaEyes6/Main.lua` | Bootstrap, update loop and primary slash commands. |
| `OliaEyes6/Core/` | Engine, unit/spell/aura helpers, hotkeys, swing tracking, configuration, overlay and diagnostics. |
| `OliaEyes6/Routines/` | Class and support routine evaluators. |
| `OliaEyes6/docs/` | Feature guides, behavior notes and verification records. |
| `OliaEyes6/tests/` | Standalone Lua regression suites using mocked client state. |
| `OliaEyes6/skills/` | Project development and routine authoring rules. |

Start with [AGENTS.md](OliaEyes6/AGENTS.md) and the [development skill](OliaEyes6/skills/oliaeyes6-development/SKILL.md). Routine and overlay changes also follow the [routine authoring skill](OliaEyes6/skills/oliaeyes6-routines-overlay/SKILL.md).

Standalone suites target Lua 5.1 and run from the addon directory, for example:

```sh
cd OliaEyes6
lua tests/RoutineConfig.test.lua
```

Mocked tests do not verify real spell outcomes, client rendering or SavedVariables disk writes. Client-dependent changes require matching Anniversary API references and targeted in-game verification as described in the development rules.

Additional guides: [routine dispatch views](OliaEyes6/docs/ROUTINE_DISPATCH_VIEWS.md), [swing timer](OliaEyes6/docs/SWING_TIMER.md), [Warrior Adaptive](OliaEyes6/docs/WARRIOR_ADAPTIVE.md), [Warrior Kebab](OliaEyes6/docs/WARRIOR_KEBAB.md), [Warrior shouts](OliaEyes6/docs/WARRIOR_SHOUTS.md), and [Warrior WoWSims](OliaEyes6/docs/WARRIOR_WOWSIMS.md).

## OliaFingers2

TODO: Document the companion component, its requirements, installation, configuration, input handling and integration with `OliaEyes6`.
