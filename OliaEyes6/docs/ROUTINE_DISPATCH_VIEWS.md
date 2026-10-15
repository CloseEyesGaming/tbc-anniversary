# Authored dispatch modes in the overlay

Kebab uses exactly two PvE blocks: **PvE Single target** and **PvE AoE**.
Execute is described beside its actions in both blocks; exclusions and no-enemy
shout/cleanup are documented inside Single target. Its unavailable PvP tab only
exposes factual queue cleanup. This requested compact presentation is the Kebab
exception to the otherwise separate phase/context sections below. All 24 action
identities (23 optional) retain per-placement switches. There are 11 active
preferences; obsolete `mainhand_queue` and aggressive Hamstring controls are retired, with
raw historical saves preserved. Normal single-target queue uptime is standard
under the HS action switch; ready cores precede new HS and self buffs, and paid HS
reserves exact independently due core costs with no rage buffer; a shared GCD
cannot exclude the second ready core. Optional Normal GCD buffs require a full
1.5s core gap, while Bloodrage/trinkets remain off GCD. Optional spending preserves
an already funded queued HS payment; fillers have no aggressive cap exception. Tests cover actual Normal/Execute, excluded and no-enemy outputs
against the relevant block, plus actual overlay callbacks and combat deferral.

Queue audit 2026-10-14: current rage funds all abilities even with HS/Cleave queued.
Queued cost is observation only; funding checks admit new queues and protect core
or filler budgets. Cleave never cancels solely for rage/core funding, and an
unqueued Cleave cannot reserve MS into an idle tick. Timed HS cleanup and factual
context/disable/Execute cleanup remain. Demo keeps its opt-in preference and now has urgent missing/<=5s priority,
including Execute. Both Sunder modes prioritize missing/<=3s refresh; Stack
Sunder Armor builds healthy stacks only as funded filler after cores/free
Victory Rush. Init Sunder Armor never builds healthy stacks. The single
Sunder action is displayed with its urgent placement and explains the late
stack-filler path. Berserker Rage retains its Normal safe-gap guard. No equipment swap or
fallback algorithm is authored.

Audited 2026-10-06 against the reachable catalog/evaluator call chains. `Core/RoutineDispatchViews.lua` projects static schema rows into mode sections; `RoutineConfig` validates each definition and all saved Warrior identities. Each heading displays its activation condition. Dynamic action alternatives remain beside their owning steps. Context tabs preview structure; action switches still apply to the whole placement.

| Routine | Authored dispatch / overlay structure | Evaluator source |
| --- | --- | --- |
| Warrior Original, including combat/maintenance behavior variants | Arms or Fury from spec/weapon choice; each has PvE/PvP and single-target/AoE. Arms core-first AoE splits Sweeping active/inactive; Fury splits Bloodthirst/Mortal Strike. Own spec/off-hand equipment prepasses. | `Routines/Warrior.lua`: `warriorUniversal`, `UsesWarriorFuryRotation`, `warriorArms`, `warriorFury` |
| Warrior Arms | PvE/PvP; single-target/AoE; core-first AoE Sweeping state when enabled by this fixed behavior; two-hand equipment. No Fury gear/core. | `warriorArms` |
| Warrior Fury | PvE/PvP; single-target/AoE; Bloodthirst versus Mortal Strike; dual-wield equipment, fast off-hand in PvE single-target and slow in PvE AoE. | `warriorFury` |
| Warrior WoWSims | PvE single-target/AoE; unavailable PvP releases without another algorithm. | `warriorWowsims`, `UseWowsims`, WoWSims selector in `Routines/Warrior.lua` |
| Warrior Adaptive | PvE single/boss/AoE; PvP single/AoE; excluded nearby enemy blocks area mode; no-enemy shouts and equipment. Lists planner possibilities rather than a fixed row sequence. | `Routines/WarriorAdaptive.lua`: `Adaptive:Evaluate`, `ObserveEnemies`, `Adaptive:Owns` |
| Warrior Tank | Shared PvE/PvP priority; single-target/AoE, no selected enemy, shield equipment. Heavy hitter chooses Shield Slam, Bloodthirst or Mortal Strike; armor chooses Devastate/Sunder; alternatives are described at their owning step. | `Routines/Warrior.lua`: `warriorTank` |
| Warrior Sweeping | PvE Arms schedule versus unscheduled Fury; PvP unscheduled. Each separates single overflow, AoE pooling and active burst (including target-count drops). No substitute routine. | `warriorThread3AoE`, `GetWarriorThread3State` |
| Warrior maintenance | One PvE maintenance table; initial/stack Sunder and stance/area-debuff conditions remain individual row guards/options. | `warriorArmsPveMaintenance` |
| Druid DPS | PvE/PvP. PvE moving/stationary Moonkin and other caster; PvP moving/stationary caster. Cat stealth, Mangle/Claw builder; Bear single-target/AoE and Mangle/Lacerate; Cat powershift return; form equipment. Cat/caster have no target-count-specific rotation, so no invented AoE copies. | `Routines/Druid.lua`: `dpsSet`, `GetDruidThread5WeaponSwap` |
| Druid DPS idle/equipment | Cat/Bear FAT versus Moonkin Battery/Velocity equipment, with no live DPS enemy. | `druidDpsIdleSet` |
| Druid V6 | Raid selector in combat with Lifebloom learned: emergency, maintenance, additional healing, filler. Unit selection outside combat/pre-Lifebloom: emergency, boss tank, trash tank, raid and out-of-combat groups. | `druidThread2Heal`, `V6Thread2Candidate`, `universalHealSetV6` |
| Druid V6 legacy | Unit-selection groups; its fixed legacy policy does not use the raid selector. | `druidThread2Heal`, `universalHealSetV6` |
| Druid Dispel + V6 | Dispel plus legacy V6 groups, preserving joint row priority; no raid selector under this fixed policy. | `dispellSet`, `druidThread2Heal` |
| Druid legacy universal healing | PvE outside battleground/arena versus PvP inside those instances; all steps from the selected table. | `universalHealSet`, `pveHealSet`, `pvpHealSet` |
| Druid Tank + raid joint priority | Separate tank/raid components; competition by row priority. | `tankRollSet2`, `raidHealSet2` |
| Druid PvP matrix | One friendly-healing table. First/second Regrowth, Rejuvenation and cooldown/HP/movement conditions are step guards; no different context/AoE priority tables. | `universalPvPMatrix` |
| Druid V5 | One friendly-healing table; tank/raid, movement, HP and bloom conditions guard rows in the same priority. | `universalHealSetV5` |
| Druid legacy PvE and legacy PvP healing | Each exposes its own single table; the universal instance dispatcher is a separate routine above. | `pveHealSet`, `pvpHealSet` |
| Druid tank and legacy tank healing | Each uses one table on eligible tank-marked friends; excluded/dead/non-tank friends release. | `tankRollSet2`, `tankRollSet` |
| Druid raid and legacy raid healing | Each uses one table on eligible non-tanks; excluded/dead/tank friends release. | `raidHealSet2`, `raidHealSet` |
| Druid Dispel | One poison/curse action table with row guards. | `dispellSet` |
| Druid Buffs | One table; solo/group/tank/self eligibility is described per buff, without changing its step priority. | `buffSet` |
| Druid healing equipment | One EquipShield action; item/macro selection and player context remain its conditions. | `druidHealingWeaponSet` |
| Rogue DPS | Shared PvE/PvP; stealth, visible dagger/behind, visible other weapon/position. Disabling Backstab allows authored Sinister Strike; no target-count dispatcher. | `Routines/Rogue.lua`: `rogueDpsSet` |
| Follower | Rest; Druid Tree of Life; flying/ground travel; driverless self maintenance. Follow/stop still work when mounting is blocked. | `Routines/Follower.lua`: `followerSet`, `getFollowerTravelState`, `shouldUseTreeOfLife` |
| Fishing | Casting wait; missing lure; present/suppressed lure. Existing retry, channel and pole eligibility remain. | `Routines/Fishing.lua`: `Fishing`; `Core/RoutineConfig.lua`: support routing |
| Hunter, Mage, Paladin, Priest, Shaman, Warlock | Placeholder modules without registered executable routines. No invented mode/step menus. | Corresponding `Routines/*.lua`, `Core/RoutineCatalog.lua` |

Imported Warrior IDs display their actual canonical algorithm and fixed behavior. Retired fallback identities stay archived out of runnable thread lists. Row-level eligibility checks do not require duplicating an otherwise identical rotation for every possible buff/cooldown/resource state.

The audit also found missing declarations for existing evaluator outputs: Fury `EquipFastOffHand`/`EquipSlowOffHand`, Sweeping `Mortal Strike`, Tank `Sunder Armor`, and Follower `Tree of Life`. Their IDs/bindings were already present; declaring them makes the compiled mask/selector accept and display those authored actions. No evaluator, hotkey registry or pixel code was edited.

Verification: `tests/RoutineDispatchViews.test.lua` uses actual evaluators/registries to compare eligible outputs with their mode sections across PvE/PvP, target counts, builds, stances, rage, execute and Sweeping states, plus Druid forms/movement/builders and Adaptive area safety. It exercises real off-hand return branches and Tree of Life through compiled support selection. `RoutineViews` checks metadata validation and actual UI callbacks for activation wrapping, shared switches, collapse/tab state and combat deferral. See [configuration notes](ROUTINE_CONFIGURATION.md) for API provenance, checkpoints and bounded live checks.
