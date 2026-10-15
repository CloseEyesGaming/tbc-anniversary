# Optional WoWSims Arms PvE rotation

After `/reload`, open `/olia options` and add **Arms — WoWSims** to the chosen class thread. It is an independent routine with fixed mode, per-placement action switches and preferences. Original remains the fresh-profile default on thread 2. The former `arms_pve_mode` / `universal_arms_wowsims_st` settings are migration inputs, not a selector that redirects other routines.

The four maintenance preferences in this placement's PvE Steps are independent and **default off**:

| HUD switch | When enabled |
| --- | --- |
| Sunder: first stack | Single target: apply only when Sunder is absent |
| Sunder: stack to 5 | Single target: add to existing 1-4 stacks; never starts the first stack |
| Sunder: refresh | Single target: refresh any existing stacks at <=10 seconds, with MS and WW both >=1.5 seconds away |
| Demoralizing Shout | Apply/refresh at <=5 seconds in the same core-cooldown filler gap |

Every Sunder action skips active Expose Armor and respects the existing post-cast
aura-settle guard. Refresh can be enabled without stacking; an actual refresh
cast may naturally add a stack. Demo skips active Demoralizing Roar, Curse of
Weakness or Screech, matching the original AP-debuff coverage list.

**Death Wish and trinkets are not automatically used by this mode.** The legacy
thread switches control the original routines; these four control WoWSims only.
An explicitly listed PvE maintenance placement keeps its own switches and timing. WoWSims neither disables that placement nor redirects it.

## Scope

| Context | This placement's behavior |
| --- | --- |
| Any class thread 1-6, supported Arms behavior | Run WoWSims when eligible, regardless of physical thread |
| PvP, player-controlled targets, totems | No action; no Original substitute |
| Two or more observed eligible nearby enemies | Own WoWSims AoE priority |
| No enemy, friendly/dead enemy, out of combat, out of melee | No action; next explicit placement may run |
| Arms with Mortal Strike, 2H and 2/2 Improved Slam | Two-handed source priorities |
| Arms with Mortal Strike and dual weapons | Dual-wield source priorities |
| Bloodthirst builds or unsupported equipment/talents | No action; no Fury substitute |
| Deliberate wait in an eligible context | Hold this placement; preserve rage/window policy |

Steps lists the complete single-target and AoE orders. The PvP tab explains unavailability. Thread 3 defaults to Sweeping alone; add WoWSims explicitly if you want it to run after Sweeping releases. Support thread 7 cannot import this class routine.

## Extracted priorities

Source: [wowsims/tbc-new](https://github.com/wowsims/tbc-new), revision
`d708f839d8bd6bedc97f668a64bb270ed608f123`.

- [Arms APL](https://github.com/wowsims/tbc-new/blob/d708f839d8bd6bedc97f668a64bb270ed608f123/ui/specs/warrior/dps/apls/arms.apl.json)
- [Preset registration](https://github.com/wowsims/tbc-new/blob/d708f839d8bd6bedc97f668a64bb270ed608f123/ui/specs/warrior/dps/presets.ts)
- [Slam implementation](https://github.com/wowsims/tbc-new/blob/d708f839d8bd6bedc97f668a64bb270ed608f123/sim/warrior/slam.go)
- [Heroic Strike/Cleave queues](https://github.com/wowsims/tbc-new/blob/d708f839d8bd6bedc97f668a64bb270ed608f123/sim/warrior/heroic_strike_cleave.go)

After the platform's autoattack start, interrupt and carried-Cleave cleanup:

1. Optional first Sunder, stacking Sunder, then Sunder refresh, each with its own
   switch and an active Expose Armor exclusion. Refresh requires <=10 seconds
   remaining and both Mortal Strike and Whirlwind at least 1.5 seconds away.
2. Two-handed Slam immediately after a confirmed main-hand swing, with a current
   haste-adjusted full main-hand swing interval >=0.5 seconds. Skip during Execute phase while
   Bloodlust or Heroism is active.
3. Mortal Strike; dual-wield Arms skips it during Execute phase.
4. Whirlwind.
5. Execute at <=20% health. Dual-wield Arms requires Whirlwind more than 1.5 seconds away.
6. Dual-wield Overpower weaving, outside Execute, after a dodge by this target,
   with at least five rage and both core cooldowns at least 1.5 seconds away.
7. Return to Berserker Stance when a core cooldown is ready/within input delay.
8. Heroic Strike outside Execute: queue at >=80 rage for 2H, >=40 for DW.
9. DW Hamstring filler at >=40 rage when both core cooldowns are >=1.5 seconds away.
10. Bloodrage below 90 rage.
11. Battle Shout when less than ten seconds remain, in a core cooldown gap.
12. Optional Demoralizing Shout, as filler in a core cooldown gap and only when
    equivalent AP-reduction coverage is absent.

Action order is the first eligible row, not an instruction to cast an unavailable
spell. A live player cast/channel holds an empty result, without falling through
to the old rotation. Eligibility is rebuilt on every evaluation.

## Two or more eligible targets

Observed eligible enemy count selects this own branch automatically. After autoattack,
interrupts and clearing a carried Heroic Strike queue:

1. Sweeping Strikes if learned, ready, affordable (30 rage), not active or within
   the existing successful-cast aura-settle grace. Thread 2's existing Sweeping
   Strikes switch is respected. No 80-rage Sweeping-owner pooling is imported into this routine.
2. Whirlwind before Slam or Mortal Strike.
3. The same Slam, Mortal Strike, Whirlwind fallback and Execute conditions as ST.
4. Cleave queue at >=40 rage, including Execute phase, after higher-priority damage.
5. Stance return and the existing eligible Hamstring/Bloodrage/shout fillers.

Sunder, Heroic Strike queueing and DW Overpower weaving are ST-only in the APL.
When the count drops below two, ST priorities resume immediately and a carried
Cleave is cancelled while not casting. Entering AoE cancels a carried Heroic
Strike before queueing Cleave. Queue thresholds are not cancellation thresholds:
after spending rage, an existing same-mode queue is not cancelled at 40/80 rage.
All temporary AoE rows clear every evaluation, including cast/channel holds.

Sweeping's source `multipleCdUsages` uses simulated future Bloodlust timing. The
live port uses it on cooldown with the observed valid AoE context, not a fabricated
encounter schedule. Native usability/stance and real cooldown checks remain.
The spell is adapted by its existing **Sweeping Strikes** action name: source
`12723` is a simulator identifier also used for its proc, not a new live binding.
The [source implementation](https://github.com/wowsims/tbc-new/blob/d708f839d8bd6bedc97f668a64bb270ed608f123/sim/warrior/talents_fury.go#L155)
models its activation without a normal GCD; the live readiness gate still checks
usability and its actual cooldown. Anniversary cast timing remains a live check.

Sweeping's pooling/burst ownership and enemy-drop policy are unchanged. WoWSims runs after it only when explicitly added later in the thread list. Death Wish and trinkets remain manual in both owned WoWSims branches.

## Deliberate live adaptations

- The source's `inputDelay + 300ms` Slam window uses world network latency as a
  proxy for simulation input delay, capped at the platform's 1.15-second limit.
  The separate >=0.5-second gate reads the current full interval from
  `UnitAttackSpeed("player")`, without subtracting elapsed time or latency, matching
  [the APL autoSwingTime implementation](https://github.com/wowsims/tbc-new/blob/d708f839d8bd6bedc97f668a64bb270ed608f123/sim/core/apl_values_auto_attacks.go).
  Actual external input/focus delivery delay is unknown and needs combat verification. GCD actions wait for
  GCD expiry instead of emitting an early Slam that could execute too late.
- The new mode follows source **Slam before MS/WW**, including at 15 rage, rather
  than the old mode's core-cooldown/rage reservation policy. Those old helpers and
  the original 1.15-second after-swing policy remain in the independently selected Original routine.
- The shared swing tracker supplies confirmed timestamps, target GUID, haste
  updates and cast completion. A new window requires a matching target and a
  reliable main-hand cycle; a completed Slam cannot reopen its own window.
- The APL identifies its 2H variant by Slam cast time <=0.5s. This port requires
  actual 2H equipment plus 2/2 Improved Slam. The DW variant requires dual weapons
  and Mortal Strike without Bloodthirst. Unsupported builds return no WoWSims action.
- Simulation encounter duration, future Bloodlust timing, future Expose Armor,
  pre-pull scheduling, engineering, potions, drums and racial coordination are
  not available through this dispatcher. No such schedule or new action mapping
  is fabricated. Automatic trinket and Death Wish usage was removed by user request.
  Recklessness also stays manual.
- Sunder uses the three independent WoWSims switches and the existing short
  post-success aura-settle guard. Active Expose suppresses every phase;
  the simulator's two-stack stop while awaiting a planned Expose cannot be known.
- Battle Shout maintenance uses observed player coverage. The source Arms APL
  has **no Demoralizing Shout action**. Demo is a user-requested optional utility
  using the APL's Delay Check filler gap plus the original <=5-second refresh
  threshold and equivalent-debuff coverage checks. This is an adaptation, not
  an extracted Demo priority. Explicit maintenance retains its own Thunder Clap/Sunder/Demo preferences; it does not delegate to WoWSims.
- A queued attack from the previous ST/AoE mode is cleared through the existing
  Stopcasting action while not casting. Queue thresholds only control **queueing**:
  dropping below 80/40 after spending does not cancel an already queued strike.
- No protocol IDs, keys, colors, secure macros, TOC ordering or Engine routes change.
  The existing English-name capability/aura helpers and coarse range policy are
  retained; this does not add a localization or range-system rewrite.

## Client/API verification

Installed `.build.info`: `wow_anniversary` **2.5.6.69795**.
`OliaEyes6.toc`: interface **20504** (retained).
Verified checkout: `Gethe/wow-ui-source`, branch `classic_anniversary`, revision
`1463c686270b6c64e2c5c228f447c4597c0f8ba6`, commit **2.5.6 (69795)**.

The branch's generated docs and Blizzard implementations were inspected:

- [SpellDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua):
  `C_Spell.IsCurrentSpell` is boolean; `C_Spell.IsSpellInRange` is boolean/nil;
  `C_Spell.IsSpellUsable` distinguishes usability/resource shortage. The new range
  gate requires explicit true. Existing legacy usability must also be explicit true.
- [UnitDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua):
  valid tokens for UnitCanAttack; existence/player-control, health and power APIs.
  Missing/zero maximum health never enables Execute.
- [TBC/PaperDollFrame.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_CharacterFrame/TBC/PaperDollFrame.lua#L729):
  main-hand and optional off-hand speed from UnitAttackSpeed.
- [Shared/CastingBarFrame.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_UIPanels_Game/Shared/CastingBarFrame.lua#L350):
  cast/channel detection and timestamp layouts.
- [Classic/SpellBookFrame.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_UIPanels_Game/Classic/SpellBookFrame.lua#L324):
  legacy GetSpellCooldown tuple; spellbook use at lines 422/432.
- [Classic/MainMenuBar.xml](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_ActionBar/Classic/MainMenuBar.xml#L147):
  GetNetStats home/world latency fields.
- [UnitAuraDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua)
  and [Classic/TargetFrame.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_UnitFrame/Classic/TargetFrame.lua#L534):
  generated aura API and Blizzard's harmful-aura tuple consumption (name, count,
  duration, expiration and caster). This change reuses GetArmorDebuffState,
  GetDebuffRemaining and Debuff; it introduces no new client API dependency.
- Existing combat-event/swing references remain in [SWING_TIMER.md](SWING_TIMER.md).

**Verification gap:** generated C_Spell records do not prove every legacy global
string overload used by this addon. The inherited GetSpellBookItemInfo,
IsUsableSpell, UnitAura and cooldown/GCD matching policy are not newly established
public contracts. Nor does UI source prove actual Slam reset, delivery latency,
or `/stopcasting` next-swing cancellation behavior. No live client test was run.

A bounded, read-only API probe after `/reload` (run once with a hostile target):

```text
/run local s="Slam"; print("book",GetSpellBookItemInfo(s)); print("usable",IsUsableSpell(s)); print("cd",GetSpellCooldown(s)); print("range",C_Spell.IsSpellInRange(s,"target")); print("build",GetBuildInfo())
```

Then verify one short combat sample: 2H normal/haste/Execute with and without
Bloodlust; movement, target loss/reacquisition, one Slam per swing, HS queue and
Cleave cancellation; DW Overpower/WW pooling if that build is used. Check the
placement's saved enabled state and four default-off maintenance switches, independent explicit maintenance, Expose/equivalent-debuff suppression, thread 3 holding/release, 1-to-2/2-to-1 transitions, CC/totem exclusion, and
PvP/other-thread controls. `/olia debug` shows the selected action; compare actual
casts/swing events rather than treating a recommendation as a successful cast.

## Offline checks

Lua **5.1** parsing and standalone mocked tests cover the new mode, default-off
comparisons against the exact pre-edit file, menu persistence, the existing
Warrior options/Slam/Demoralizing Shout policies, optional enemies, shared swing
timer, weapon GCD and action-range integration. Tests are not loaded by the TOC.
Static/mocked results do not establish in-game timing or DPS improvement.

WoWSims attribution and MIT notice: [licenses/wowsims-tbc-new.txt](licenses/wowsims-tbc-new.txt).
