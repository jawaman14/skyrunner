# Owner decisions

Every decision the owner makes, in one place, each tied to where its work is tracked. Started 18 October 2026, after the
uncle storyline (decided 12 October) was found missing from every work list: it was recorded in HANDOFF.md and the triage
document but never given a roadmap section or an issue, and the 12 October roadmap refresh (#370) was never merged.

**Rules** (also in [PIPELINE.md](PIPELINE.md), "Owner decisions: the ledger"):

1. The agent who hears a decision adds a row here **in the same session**, in the owner's words where they matter.
2. Every row says where its work is tracked: a `ROADMAP: <section heading>` that exists in [ROADMAP.md](ROADMAP.md), or a
   PR or issue number. `tests/test_docs.gd` fails a row with no tracker, a status it does not know, or a roadmap section
   that does not exist.
3. A roadmap rewrite starts by reading this table: every row that is not `done` or `superseded` must appear in it.
4. Status is one of: `planned`, `in-pr`, `done`, `open` (the owner has not decided yet), `superseded`.

| ID | Date | Decision | Status | Tracked in |
|---|---|---|---|---|
| D-01 | 2026-10-08 | Direction: build an empire from nothing, starting as a hired pilot; four product steps in order | planned | ROADMAP: Product direction (owner, 8 October 2026) |
| D-02 | 2026-10-11 | Merge readiness is the agents' job: merge when the other agent's exact-head review, CI and threads are done | done | PIPELINE.md, HANDOFF.md |
| D-03 | 2026-10-12 | QA and QC (suites, sims, balance, goldens) go to Codex | done | PIPELINE.md |
| D-04 | 2026-10-12 | One week of polish, no new features | superseded | D-20 |
| D-05 | 2026-10-12 | Police interception much lower in chapters 1-2, still possible | done | #350 |
| D-06 | 2026-10-12 | Chapter goals forgiving in chapter 1, very sparing from chapter 3 | done | #354 |
| D-07 | 2026-10-12 | One hosting flow (the waiting room); the LAN beacon belongs to the server node | done | #364 |
| D-08 | 2026-10-12 | One saves folder, one file per mode, with a migration of old saves | done | SavePaths (main) |
| D-09 | 2026-10-12 | The boss is the player's uncle, Rafael "Rafa" Quintero; chapter 2 reveals his business; Los Cuervos kill him in chapter 4 (heard, not seen); the player takes his seat with a crumbling empire | planned | ROADMAP: Story: the uncle and the boss's seat (owner, 12 October; not built) |
| D-10 | 2026-10-12 | Delegating a flight costs money (you hire people out) | planned | ROADMAP: Story: the uncle and the boss's seat (owner, 12 October; not built) |
| D-11 | 2026-10-12 | Reputation is trust with each crew; the trust table (Morettis up: Cuervos down; Cuervos up: Morettis and dealers down; Company up: Collective down a little; Collective up: Company down a little; dealers up: Cuervos down a little) | planned | ROADMAP: Story: the uncle and the boss's seat (owner, 12 October; not built) |
| D-12 | 2026-10-12 | The 3D pilot app gets a fixed 30 Hz step with the picture smoothed between steps, as its own task | planned | ROADMAP: Forgotten or half done (found 18 October) |
| D-13 | 2026-10-14 | Only ground cargo can be stolen, in a firefight; first missions are free and can be retried at the same airport | done | #377, #376 |
| D-14 | 2026-10-16 | Outages: either agent takes over the other's work without asking | done | memory, board |
| D-15 | 2026-10-16 | Remove read-aloud (text to speech) | done | #385 |
| D-16 | 2026-10-16 | The General's choice is optional; keep the two-goal rule | done | #378 (merged 18 Oct, 2ea0842e) |
| D-17 | 2026-10-16 | Persistent island-wide job boards | in-pr | #383 |
| D-18 | 2026-10-17 | Remove the rival aircraft and the hijack | in-pr | #388 |
| D-19 | 2026-10-17 | Rival depot raid: stolen cargo goes to a depot at the rival HQ; a tip-off; a raid costs casualties, heat, a grudge and upkeep; success returns everything | planned | ROADMAP: Then: the rival depot raid |
| D-20 | 2026-10-17 | The polish freeze is removed; #378 lands now | done | ROADMAP: Owner decisions of 17 October |
| D-21 | 2026-10-17 | Change the strips (not gate the generator); reshape the quarry | in-pr | #396 |
| D-22 | 2026-10-17 | #367's vehicles are replaced by #374 | done | #374 |
| D-23 | 2026-10-17 | Next direction: the presentation layers (music, fashion, graffiti, city pulse) | planned | ROADMAP: Next: presentation layers (owner's pick) |
| D-24 | 2026-10-17 | Playtest fixes: clearer chapter 1 goals, boat updates and map lines, the AI pilot says where it goes, a radar tip, dirt wears the airframe, a slow reverse, the unloading step | in-pr | #390, #391, #392, #393, #394, #395 |
| D-25 | 2026-10-18 | The phone is the hub (Work, People, Empire, Map, Messages, Guide, Help, Radio, Settings) | done | #401 |
| D-26 | 2026-10-18 | Pick which save to use (save slots) | in-pr | #399 |
| D-27 | 2026-10-18 | Heat and the law rework, in three steps in order: case files and kinds of heat; the police search and the ladder down; patterns, escalation, corruption, ground chases | in-pr | ROADMAP: Heat and the law (owner, 18 October) |
| D-28 | 2026-10-18 | Fix the workflow audit's findings | done | #398 |
| D-29 | 2026-10-18 | Codex's woken turns may write the board folder (sandbox writable root), no full access | done | wake watcher command (local) |
| D-30 | 2026-10-18 | Keep a decisions ledger and check it in the tests (this file) | done | PIPELINE.md |
| D-31 | open | The hub approach on natural terrain (HAR end 0); flight skill in the story's goals; the AI knowledge policy; the engine (Godot or Unity); what survives Rafa's death | superseded | D-35, D-36, D-37, D-38, D-39 |
| D-32 | 2026-10-18 | The 52 design epics: the agents rank them by value and effort and post the order on #326 for the owner to veto | done | #326 |
| D-48 | 2026-10-18 | The owner accepted the agreed epic order without a veto (Tier 1: #172 with #155, #138/#156, #142, #120/#151, #134/#148, #165 with #164, #147/#173; the nine foundations get a gap audit; #169 deferred) | planned | ROADMAP: The design epics, in order (owner, 18 October) |
| D-33 | 2026-10-18 | The wake tool keeps starting Codex turns unattended (the local watcher runs with `--max-per-hour 40`; the checked-in default is 6) | done | wake watcher (local) |
| D-35 | 2026-10-18 | When Rafa dies, half his empire survives: half the stashes (the least known), half the crew, the trucks that were parked, a quarter of his cash | planned | ROADMAP: Story: the uncle and the boss's seat (owner, 12 October; not built) |
| D-36 | 2026-10-18 | The AI police and rivals know only what a human in their seat would see (radar, sightings, tips, informants) | planned | ROADMAP: After that: the four product steps |
| D-37 | 2026-10-18 | HAR: flatten the hill on the approach to runway end 0 so both ends work | planned | ROADMAP: Forgotten or half done (found 18 October) |
| D-38 | 2026-10-18 | Flight skill (landings, short strips, approaches) gives optional bonus goals in the story; it never blocks a chapter | planned | ROADMAP: Story: the uncle and the boss's seat (owner, 12 October; not built) |
| D-39 | 2026-10-18 | Stay on Godot; the Unity proposal is dropped | done | #326 |
| D-40 | 2026-10-18 | Claude captures screenshots of #373 (scenery) and #374 (period vehicles) for the owner to approve before they merge | done | #373, #374 |
| D-41 | 2026-10-18 | The owner approved #374's period vehicles from the screenshots ("Approve") | in-pr | #374 |
| D-42 | 2026-10-18 | The owner approved #373's scenery redesign from the screenshots ("Approve") | in-pr | #373 |
| D-43 | 2026-10-18 | Plan a map redesign from the ground up, using what we have learnt (roads, strips, systems, where buildings and assets go) | planned | ROADMAP: Map redesign (owner, 18 October; planned) |
| D-44 | 2026-10-18 | The redesign keeps Costa Brava's geography and rebuilds it properly | planned | ROADMAP: Map redesign (owner, 18 October; planned) |
| D-45 | 2026-10-18 | Enterable sites: the club, the stashes you load at, the hangar and the customs house; every other building stays solid | planned | ROADMAP: Map redesign (owner, 18 October; planned) |
| D-46 | 2026-10-18 | Valle Verde becomes a small town with its own streets | planned | ROADMAP: Map redesign (owner, 18 October; planned) |
| D-47 | 2026-10-18 | Fix the city's building models that overlap each other | done | #407 |
| D-49 | 2026-10-18 | Give Codex more of the workload: the review queue first, then the gap audits, the playtest protocol (#172), QA, the Heat app and map lines, Rafa's dialogue, housekeeping (board note 511) | planned | #329 |
| D-50 | 2026-10-18 | Widen the wake tool's sandbox so a woken Codex can commit and push in the skyrunner .git and its own skyrunner-* worktrees | done | wake watcher (local) |
| D-52 | 2026-10-18 | Change the working structure: each agent does its own work end to end and may approve and merge it; Codex stops being only an approver; the two assign each other coding jobs on the board. Codex first wraps up what it has left in its current role, then the two discuss the split and the owner is told which jobs go to whom. At 08:50 the owner said to switch now and finish the open PRs together | in-pr | ROADMAP: Working structure (owner, 18 October) |
| D-53 | 2026-10-18 | Queue tests and simulations behind the machine-wide Godot lock so an agent can line them up and carry on (skyrunner-mcp #10, merged), and bump the server pin | in-pr | #410 |
| D-51 | 2026-10-18 | Clean up all the repository's documents, including the README: dated reports to docs/archive/, a docs index, links fixed | done | #408 |
| D-54 | 2026-10-18 | Read the GitHub godot topic's repositories and list any whose names or descriptions could help; assess the list for implementation afterwards | in-pr | #413 |
| D-51 | 2026-10-18 | Clean up all the repository's documents, including the README: dated reports to docs/archive/, a docs index, links fixed | in-pr | #408 |
| D-34 | 2026-10-13 | Presentation layers: stingers, the player's own colours and tag, claiming a won zone with graffiti (gameplay; the layer draws it), systems reacting to each other, per-year stations, wordless with a pause-menu legend | planned | ROADMAP: Next: presentation layers (owner's pick) |
