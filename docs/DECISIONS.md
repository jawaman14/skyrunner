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
| D-19 | 2026-10-17 | Rival depot raid: stolen cargo goes to a depot at the rival HQ; a tip-off; a raid costs casualties, heat, a grudge and upkeep; success returns everything (paused by D-75 until the Living District gate) | planned | ROADMAP: Then: the rival depot raid |
| D-20 | 2026-10-17 | The polish freeze is removed; #378 lands now | done | ROADMAP: Owner decisions of 17 October |
| D-21 | 2026-10-17 | Change the strips (not gate the generator); reshape the quarry | in-pr | #396 |
| D-22 | 2026-10-17 | #367's vehicles are replaced by #374 | done | #374 |
| D-23 | 2026-10-17 | Next direction: the presentation layers (music, fashion, graffiti, city pulse) (paused by D-75 until the Living District gate) | planned | ROADMAP: Next: presentation layers (owner's pick) |
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
| D-43 | 2026-10-18 | Plan a map redesign from the ground up, using what we have learnt (roads, strips, systems, where buildings and assets go) (paused by D-75 until the Living District gate) | planned | ROADMAP: Map redesign (owner, 18 October; planned) |
| D-44 | 2026-10-18 | The redesign keeps Costa Brava's geography and rebuilds it properly | planned | ROADMAP: Map redesign (owner, 18 October; planned) |
| D-45 | 2026-10-18 | Enterable sites: the club, the stashes you load at, the hangar and the customs house; every other building stays solid | planned | ROADMAP: Map redesign (owner, 18 October; planned) |
| D-46 | 2026-10-18 | Valle Verde becomes a small town with its own streets | planned | ROADMAP: Map redesign (owner, 18 October; planned) |
| D-47 | 2026-10-18 | Fix the city's building models that overlap each other | done | #407 |
| D-49 | 2026-10-18 | Give Codex more of the workload: the review queue first, then the gap audits, the playtest protocol (#172), QA, the Heat app and map lines, Rafa's dialogue, housekeeping (board note 511) | in-pr | #329, #446 |
| D-50 | 2026-10-18 | Widen the wake tool's sandbox so a woken Codex can commit and push in the skyrunner .git and its own skyrunner-* worktrees | done | wake watcher (local) |
| D-52 | 2026-10-18 | Change the working structure: each agent does its own work end to end and may approve and merge it; Codex stops being only an approver; the two assign each other coding jobs on the board. Codex first wraps up what it has left in its current role, then the two discuss the split and the owner is told which jobs go to whom. At 08:50 the owner said to switch now and finish the open PRs together | in-pr | ROADMAP: Working structure (owner, 18 October) |
| D-53 | 2026-10-18 | Queue tests and simulations behind the machine-wide Godot lock so an agent can line them up and carry on (skyrunner-mcp #10, merged), and bump the server pin | in-pr | #410 |
| D-57 | 2026-10-18 | Look into what can be added to the product and money loop to make the gameplay more dynamic and fun | planned | ROADMAP: Product and money loop ideas (owner asked 18 October; for decision) |
| D-58 | 2026-10-18 | The boss layer: after the takeover (D-35) the player organises the empire and delivering is optional, by a crew pilot or by themselves; flying cargo becomes part of the logistics system, not the main focus; before it the player flies the cargo and learns each mechanic chapter by chapter, so the boss's seat is understood when it comes (direct play stays first-class: D-79) | planned | ROADMAP: Story: the uncle and the boss's seat (owner, 12 October; not built) |
| D-59 | 2026-10-18 | Deadlines follow demand: a night's work, or 10 to 20 minutes when the street is hungry | in-pr | #419, #446 |
| D-60 | 2026-10-18 | Begin the loop additions as seen fit: first the market board and buyers' orders | in-pr | #419 |
| D-61 | 2026-10-18 | Ammunition is a cargo that is moved and traded, priced by the usual factors; weapons move as crates of each type, which differ in specs; the more powerful weapons are in shorter supply and the weaker ones plentiful; all of it ties into the ground and turf war | planned | ROADMAP: Arms and ammunition (owner, 18 October; planned) |
| D-51 | 2026-10-18 | Clean up all the repository's documents, including the README: dated reports to docs/archive/, a docs index, links fixed | done | #408 |
| D-54 | 2026-10-18 | Read the GitHub godot topic's repositories and list any whose names or descriptions could help; assess the list for implementation afterwards | in-pr | #414, #415, #416 |
| D-55 | 2026-10-18 | Do the godot-topic assessments in the order I think right (road junctions read, controller icons prototype, own dither pass, own playtest tool) and look at Terrain3D too | in-pr | #414, #415, #416 |
| D-56 | 2026-10-18 | Merge the lower-risk open PRs on my own judgement while Codex is out of quota (it hit its usage limit until 12:40) | done | #412 |
| D-34 | 2026-10-13 | Presentation layers: stingers, the player's own colours and tag, claiming a won zone with graffiti (gameplay; the layer draws it), systems reacting to each other, per-year stations, wordless with a pause-menu legend | planned | ROADMAP: Next: presentation layers (owner's pick) |
| D-62 | 2026-10-18 | Playtest batch: (1) fix the dealership list snapping back up when scrolled; (2) the boss's desk is about control of the workers, marking areas and heat visualisation, and should look more like an RTS; (3) replace the job menu's "sell / keep guns" with a person you buy guns from and then have to pick them up from, after you place an order, like CIA or Mafia; (4) make the phone usable while flying; (5) the autopilot is inefficient getting to its destination, and turning it on and off is clumsy | in-pr | #426, #446, #447 |
| D-63 | 2026-10-18 | Flying hot cargo doesn't make sense (do you keep it for your warehouse or fly it for others?); when you have your own stock you buy upfront. Rework the whole of logistics and stock for the bigger game it has become, since the original design was only transporting | planned | #427 |
| D-64 | 2026-10-18 | Getting caught must not make the player wait 20 minutes of real time; only caught workers do. The lawyer takes the hit: the pilot is never held, an arrest costs money, cargo, aircraft and heat | planned | #428 |
| D-65 | 2026-10-19 | The player and every rival organisation share one economic model; no organisation gets money or goods except through the same rules or an explicit outside account | planned | ROADMAP: Empire pivot (owner, 19 October) |
| D-66 | 2026-10-19 | Direct and delegated operations make the same ledger and inventory changes | planned | ROADMAP: Empire pivot (owner, 19 October) |
| D-67 | 2026-10-19 | One authoritative simulation clock with scheduled ticks (daily books); the HQ nights become a nightly report and an optional planning pause | planned | ROADMAP: Empire pivot (owner, 19 October) |
| D-68 | 2026-10-19 | Simulation detail scales with proximity and relevance (needed once there are several fully explorable cities, D-81); the first milestone only reserves the interface | planned | ROADMAP: Empire pivot (owner, 19 October) |
| D-69 | 2026-10-19 | Employees follow orders and policies only, and every refused or blocked order shows its reason | planned | ROADMAP: Empire pivot (owner, 19 October) |
| D-70 | 2026-10-19 | The campaign runs 1979-1989, then an alternate-history sandbox continues indefinitely | planned | ROADMAP: Empire pivot (owner, 19 October) |
| D-71 | 2026-10-19 | Single-player first: the existing multiplayer keeps working (sockets lane green on every PR) and new systems use the command gate, but no new multiplayer features until the Living District passes | planned | ROADMAP: Empire pivot (owner, 19 October) |
| D-72 | 2026-10-19 | The first gameplay gate is a Living District: three organisations competing in one district on the same rules | planned | ROADMAP: Empire pivot (owner, 19 October) |
| D-73 | 2026-10-19 | Story and save restructures need explicit, tested migrations; a save is never silently dropped | planned | ROADMAP: Empire pivot (owner, 19 October) |
| D-74 | 2026-10-19 | The Python parity fixtures retire one subsystem at a time, replaced by Godot goldens and invariant tests; the flight golden stays | planned | ROADMAP: Empire pivot (owner, 19 October) |
| D-75 | 2026-10-19 | Land the open PRs and finish heat step 1, then pause the presentation layers, heat steps 2-3, the depot raid and the map redesign; the depot raid and map redesign are redesigned on the new rival economy and district data | planned | ROADMAP: Empire pivot (owner, 19 October) |
| D-76 | 2026-10-19 | Rafa is the employer and early voice, Benny his fixer; after the takeover the story is told by characters, not one narrator | planned | ROADMAP: Empire pivot (owner, 19 October) |
| D-77 | 2026-10-19 | Blotter, The House and the arena become optional ventures with lasting economic and faction consequences | planned | ROADMAP: Empire pivot (owner, 19 October) |
| D-78 | 2026-10-19 | The takeover stays in chapter 4, aiming at about two hours to the boss's seat (to be measured); the half-empire loss (D-35) stays, on its own RNG stream | planned | ROADMAP: Empire pivot (owner, 19 October) |
| D-79 | 2026-10-19 | Walking, driving, flying and fighting stay first-class after the takeover: the boss desk and character play are two ways into one simulation (partly supersedes D-58's 'flying is not the focus') | planned | ROADMAP: Empire pivot (owner, 19 October) |
| D-80 | 2026-10-19 | A larger world with several cities, every one fully explorable (D-81) | planned | ROADMAP: Empire pivot (owner, 19 October) |
| D-81 | 2026-10-19 | Every city is fully explorable on foot, by car and by air; none stays a strategy-only abstraction (answers O-1) | planned | ROADMAP: Empire pivot (owner, 19 October) |
| D-82 | 2026-10-19 | When the boss dies or is jailed, the next in line in the organisation's hierarchy takes over, and the player carries on as that character (answers O-2) | planned | ROADMAP: Empire pivot (owner, 19 October) |
| D-83 | 2026-10-19 | After any campaign ending the player just carries on in the sandbox; endings are recorded, not game-overs (answers O-3) | planned | ROADMAP: Empire pivot (owner, 19 October) |
| D-84 | 2026-10-19 | The Living District's third organisation is the Morettis, run as a business organisation on the same rules (answers O-4) | planned | ROADMAP: Empire pivot (owner, 19 October) |
| D-85 | 2026-10-19 | Time acceleration on the desk: x1, x4, x16, x60; held at x1 while a human is flying or on foot in a hostile area; in multiplayer only the leader accelerates, and only with every human seat parked (owner: Claude's call, O-5) | planned | ROADMAP: Empire pivot (owner, 19 October) |
| D-86 | 2026-10-30 | Rebuild the map from scratch now: this lifts the map redesign's pause under D-75. The plan, its layer order and its owner gates (the layout sketch, the screenshots, the playtest) stay as written in MAP_REDESIGN.md; the queue it waits on (#373, #374, #396) is landed first | planned | ROADMAP: Map redesign (owner, 18 October; planned) |
| D-87 | 2026-10-30 | The agents also work Codex's queue, open every change as a pull request that auto-merges on green CI, and look for GitHub repositories (permissive licence, pure GDScript or data) that finish unfinished work | planned | ROADMAP: Working structure (owner, 18 October) |
| D-88 | 2026-10-30 | Playtest asks: fast-forward (backslash, x1/x2/x4/x8), a News app and a finished-objectives (Done) app on the phone, a phone call when the savings cover the first plane, the player's dealers resupplied from other stashes, the starter car enterable, the job board's scroll steady, the Old Quarry walls softened | in-pr | #473 |
| D-89 | 2026-10-30 | When the owner does not answer a question or switches task, the agent logs the task it was on in a list and marks it off when finished and checked | planned | ROADMAP: Working structure (owner, 18 October) |
| D-90 | 2026-10-30 | Build the loop ideas now (docs/LOOP_IDEAS.md, additions 2 to 8; 1 is built): cover cargo first; dirty money (3) still after heat step 2 (D-27) | planned | ROADMAP: Product and money loop ideas (owner asked 18 October; for decision) |
| D-91 | 2026-10-30 | Claude may merge its own risk-class PRs itself once CI is green on the head and every review finding is fixed and resolved (no wait for the other agent's review) | planned | ROADMAP: Working structure (owner, 18 October) |
| D-92 | 2026-10-30 | Make the first chapters less bare: goal markers to the next chapter, a flight debrief with route records and Benny's time, reactive phone banter, a first cheap upgrade, early weather and small dangers, side gigs at the strips, hidden strips to discover | planned | ROADMAP: Product and money loop ideas (owner asked 18 October; for decision) |
