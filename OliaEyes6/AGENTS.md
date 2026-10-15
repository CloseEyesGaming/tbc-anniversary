# OliaEyes6 project rules

For work on this addon, read and follow [the project development rules](skills/oliaeyes6-development/SKILL.md).

For routine design, additions, step switches, routing, profiles or their overlay controls, also read and follow [the routine and overlay authoring skill](skills/oliaeyes6-routines-overlay/SKILL.md). Keep evaluators, schemas, catalog definitions, saved/compiled state and UI descriptions synchronized as one change.

## GitHub synchronization: explicit command only

- Synchronize with `https://github.com/CloseEyesGaming/tbc-anniversary.git` only when the user explicitly requests GitHub synchronization. Routine development, fixes, tests and documentation requests do not authorize publishing. Each synchronization command authorizes that synchronization only, not future pushes. Do not create remote branches, pull requests or other remote changes without explicit authorization.
- When synchronization is requested, commit and push to `main` using informative commit messages describing the actual changes and their purpose. Review the complete diff and run the checks appropriate to the changes before pushing. If required checks fail or cannot run, stop and report before pushing; do not imply mocked/static checks prove live client behavior.
- This workspace represents only the repository's `OliaEyes6/` folder. Use a separate repository checkout (currently `C:\Users\freeker0k\.codex\checkouts\tbc-anniversary`), fetch the latest remote state, and preserve all other repository data and history. Never replace the repository root with this workspace, stage unrelated changes, force-push, or delete other folders. Check concurrent changes before syncing; report conflicting edits rather than overwriting them.
- Update the repository's root README and relevant addon documentation when the synchronized changes make them inaccurate. Such documentation updates are part of the requested synchronization; unrelated repository folders remain outside scope. Leave the `OliaFingers2` documentation TODO until work on that component is requested.
- Exclude local caches such as `.pnpm-store`. Verify the staged file scope and source-to-checkout correspondence, and verify the remote commit after pushing. Report the commit link, verification performed and any remaining live-test limitations.

## Required client API reference

Use [Gethe/wow-ui-source, classic_anniversary branch, Interface/AddOns](https://github.com/Gethe/wow-ui-source/tree/classic_anniversary/Interface/AddOns) as the project's API reference database. All client API, event, enum, and Blizzard UI behavior checks must consult this branch's generated API documentation and relevant Blizzard addon source. A verified local checkout of the same source is acceptable.

Match findings to the installed Anniversary client build and `OliaEyes6.toc`; cite the relevant source path and revision or permalink for API-dependent changes. When source does not settle behavior, document the gap and verify with a bounded live probe. See the development rules for the full verification workflow.
