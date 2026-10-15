# OliaEyes6 project rules

For work on this addon, read and follow [the project development rules](skills/oliaeyes6-development/SKILL.md).

For routine design, additions, step switches, routing, profiles or their overlay controls, also read and follow [the routine and overlay authoring skill](skills/oliaeyes6-routines-overlay/SKILL.md). Keep evaluators, schemas, catalog definitions, saved/compiled state and UI descriptions synchronized as one change.

## Required client API reference

Use [Gethe/wow-ui-source, classic_anniversary branch, Interface/AddOns](https://github.com/Gethe/wow-ui-source/tree/classic_anniversary/Interface/AddOns) as the project's API reference database. All client API, event, enum, and Blizzard UI behavior checks must consult this branch's generated API documentation and relevant Blizzard addon source. A verified local checkout of the same source is acceptable.

Match findings to the installed Anniversary client build and `OliaEyes6.toc`; cite the relevant source path and revision or permalink for API-dependent changes. When source does not settle behavior, document the gap and verify with a bounded live probe. See the development rules for the full verification workflow.
