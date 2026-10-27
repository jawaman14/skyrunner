# Backlog

The issue tracker is the register. On 11 October the individual issues were folded into five open ones, so this file now
points at them and keeps the short list of what is still open, instead of a row per issue (the 10 October version went
stale within two days). The detailed evidence for every item is in
[PROJECT_TRIAGE_2026-10-12.md](PROJECT_TRIAGE_2026-10-12.md). The product order is in
[DESIGN.md §0](DESIGN.md#0-where-the-game-is-heading-owner-approved-direction-8-october-2026) and [ROADMAP.md](ROADMAP.md).
Last pass: **16 October 2026, Claude**, against `main` @ `9f2e6a3`. Update it when you merge or close something; don't
start a dated copy.

## Where things live

| Issue | What it holds |
|---|---|
| [#326](https://github.com/jawaman14/skyrunner/issues/326) | Owner: release gates only a person can pass, decisions, and the design epics (#120-#174) |
| [#327](https://github.com/jawaman14/skyrunner/issues/327) | Index of all agent work |
| [#328](https://github.com/jawaman14/skyrunner/issues/328) | Claude queue: simulation, flight, balance, economy |
| [#329](https://github.com/jawaman14/skyrunner/issues/329) | Codex queue: review, audits, tooling, UX/UI |
| [#345](https://github.com/jawaman14/skyrunner/issues/345) | Owner playtest feedback of 12 October, as a checklist |

## Still open

**Needs the owner (#326)**
- Release gates: Windows and macOS exported-build walkthroughs, controller / four-resolution acceptance,
  a two-machine multiplayer session, the functional-site walk, performance captures, radio and asset licensing.
- Decisions: job generator vs strips (#88, evidence in `STRIPS.md` and PR #323), the hub approach on natural terrain,
  whether flight skill is a story goal, the order of the design epics, whether the wake tool may spend Codex quota.

**Claude (#328)**
- Pathfinding (#86), strategic balance pass (#98), crew auto-hiring and payroll NPCs (#81, #84), turf war from present
  agents (#85, PR #378), arena polish (#100).
- Feature chain: physical cargo (#103), then police intelligence, checkpoints and pursuit (#104-#106), vehicle damage
  (#107), informants (#108), dynamic jobs (#109), weather and day/night (#110), flight planning (#111), maintenance (#112),
  fog of war (#113), crew relationships (#114), campaign director (#115), hidden informant role (#116).
- A bot that plays Story and reports the chapter it reaches; a fixed-route frame-time and memory capture harness.

**Codex (#329)**
- Housekeeping (#90): archive the dated one-off docs, stop committing per-run sim-results.
- Repository weight (#91): the asset files stay and are checked for era fit; videos move out of git.
- Startup architecture (#97): questions 2 to 10 are with the owner.
- Standing: exact-head reviews, syncing stale branches, human-gate scripts, the chapter-reachability audit.

**Playtest (#345)**
- Separate tutorials (take-off, flight, landing, loading) and a second-flight fuel and weight explanation; a notice that
  the runway end turns the aircraft round.
- Mouse look in the air, a slow reverse, a key audit.
- Dirt take-off fairness: degrade tyres instead of crashing.
- Whether the autopilot is mentioned unprompted; a human take-off check.

## Done, so don't redo it
Autopilot intercept, take-off hold, turn-back and waypoints (#80, #82, #87 via #295, #297, #318, #346), phone and incoming
calls (#83), session layering, CI lanes, the employed opening, early police pace (#350), forgiving chapter goals (#354),
chapter skip (#348). Evidence is in the triage doc and `PROJECT_STATUS.md`.

## Open pull requests (16 October)

| PR | State |
|---|---|
| #364 | Host flow step 8 (#97): green, ready for review |
| #305, #319, #321, #323, #376, #378 | Drafts. `main` was merged into #305, #319, #323, #376 and #378 on 16 October; #321 is stacked on #319 |
| #367, #374 | Both rebuild `period_vehicles.gd`; keep #374, close #367 (owner decision pending) |
| #368, #373 | Costa Brava salvage vs redesign; #368 has failing CI. Keep #373 unless the owner prefers the salvage |
| #370, #377 | Roadmap refresh and the air-hijack fix: clean, green |
| #379-#381 | Airfield props, the ambient-life / PS2 proposal, guest-entry tests |
