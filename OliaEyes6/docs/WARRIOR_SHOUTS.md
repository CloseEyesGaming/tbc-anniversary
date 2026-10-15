# Adaptive DPS shouts

All existing DPS shout slots use `jungle.GetWarriorDpsShout`: Arms and Fury
PvE/PvP, WoWSims Arms (single target/AoE), and Adaptive Arms. Tanking is unchanged.
The selector reads only the existing player aura cache; it does not traverse the
group, add a cast path, or change action IDs, keys, colors, macros, or routing.

| Player's current buffs | Choice |
| --- | --- |
| Own Commanding Shout | Keep it; refresh within the routine's window |
| Own Battle Shout | Keep it; refresh within the routine's window |
| Another warrior's Battle Shout, no Commanding | Supply Commanding Shout |
| Another warrior's Commanding Shout, no Battle | Supply Battle Shout |
| Both supplied externally | Wait; do not refresh either while both remain |
| Neither | Cast the default selected in the overlay (initially Battle Shout) |

The overlay has two shared, mutually exclusive rows: **Default: Battle** and
**Default: Commanding**. Choose one for all DPS modes. The setting is stored with
the existing Warrior class preferences, survives `/reload`, and resets to Battle
with a class reset. Changing it does not replace an active own shout.

Ownership takes priority over complementing another warrior. An active own shout
is retained even if the other shout disappears. Once it expires, selection uses
the current buffs again. There is no persistent assignment after death/expiry.
Refresh windows remain 5 seconds for legacy Arms/Fury, 10 for WoWSims, and 3 for
Adaptive Arms; the existing cache treats exactly the threshold as still safe.
Each caller retains its readiness, resource, GCD, Slam, cooldown-gap and priority
gates, including legacy Battle Shout's brief post-Charge suppression. Unknown or
unusable selected spells do not produce an eligible action.

## Client/source verification

Verified 2026-09-29: installed `WowClassic.exe` and `.build.info` both report
Anniversary **2.5.6.69795**. `OliaEyes6.toc` retains **20504**.
GitHub's `classic_anniversary` branch resolved to
`1463c686270b6c64e2c5c228f447c4597c0f8ba6`, commit **2.5.6 (69795)**.

- [Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua#L156-L169)
  documents unit/filter-based aura reads returning nullable `AuraData`.
- [Blizzard_FrameXMLUtil/AuraUtil.lua](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_FrameXMLUtil/AuraUtil.lua#L32-L53)
  unpacks expiration time and source unit in positions 6 and 7, matching
  `UnitsData.lua`'s `ParseBuffAura` callback.
- [AuraUtil.ForEachAura](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_FrameXMLUtil/AuraUtil.lua#L84-L118)
  invokes the unpacked callback used by this cache. Its
  [Blizzard caller](https://github.com/Gethe/wow-ui-source/blob/1463c686270b6c64e2c5c228f447c4597c0f8ba6/Interface/AddOns/Blizzard_FrameXMLUtil/AuraUtil.lua#L415-L418)
  compares the caster with `player`, as the existing cache does.

The default selector reuses the overlay's existing row/checkbox handlers and
SavedVariables initialization; it adds no new UI API or protected action.
Mocked overlay tests cover both click paths, exclusive selection, persistence,
class reset and malformed settings; live rendering remains unverified.

This change introduces no new client API. Existing English aura names and
player/nonplayer cache classification are retained. Source confirms the tuple
layout, not shout stacking/rank replacement or every live source-token alias.
The routine reacts to observed auras rather than predicting successful casts.

## Verification

Standalone `tests/WarriorShouts.test.lua` exercises all six paths with the real
`unitCacheBuff` reader, including own/other sources, refresh boundaries, expired
and inactive cache entries, repeated transitions, both buffs, unavailable casts,
targetless use, and the WoWSims AoE/cooldown-gap path. Existing Warrior options,
WoWSims, Adaptive Arms, optional-enemy, Slam and Demoralizing Shout checks also
pass under Lua 5.1. These checks use mocked game APIs.

Live `/reload` and actual casts are not verified here. A bounded read-only probe
can be run once in each ownership state after `/reload`:

```text
/run AuraUtil.ForEachAura("player","HELPFUL",nil,function(n,_,_,_,_,e,s) if n=="Battle Shout" or n=="Commanding Shout" then print(n,s,e-GetTime()) end end)
```

With a second warrior, check neither buff, their Battle, their Commanding, both,
and your own shout approaching expiry. Use `/olia debug` to inspect the selected
action and verify the resulting buff/caster separately. Repeat for each enabled
DPS mode, with tanking as an unchanged control; check that your own shout remains
stable across successive ticks and that insufficient rage does not emit a shout.
