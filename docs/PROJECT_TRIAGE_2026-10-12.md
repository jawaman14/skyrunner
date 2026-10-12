# Project triage, 12 October 2026: what is finished, what is in question, what hurts, what to overhaul

Written for the owner's goal ("close things out properly or tick things partially; list everything: complete and unlikely to change, no longer
needed or in question, the most problematic, and what needs a rehaul from the early parts of the game that is bloat"). It covers all 5 open
issues, the 98 closed ones, the 28 open PRs, the 47 squash-merged PRs on `main`, the repository's weight, and the biggest systems.

**Two issues are cited throughout:** #326 is the owner's single issue (human release gates, decisions, and the 52 design epics) and #345 is the owner's playtest feedback of 12 October, as a checklist.

**How to read it.** Every row says how it is known: *merged* (a PR on `main`, number given), *tested* (a test file exists and passes in the suite), *code
exists* (present in `scripts/` but not checked beyond that), or *unverified* (a judgement from titles and size, to be confirmed). Apart from #337 (a duplicate draft, closed on 12 October) nothing here is
closed or ticked by this document: closing and ticking need the owner's say for human gates and decisions (#326), and are proposed, not done, for
the rest (section 6). The 98 closed issues were consolidated on 11 October as "not planned" with pointers, so "closed" does not mean "done": done
means a merged PR or a passing test, and is stated per row.

## 1. Complete and unlikely to change

| Item | Evidence | Note |
|---|---|---|
| Session split into layers and stateless command domains (#95) | merged #284; the suite then had 1,114 tests | Structure of `session_*.gd`; the layering rule is in CLAUDE.md. |
| Determinism: parity switches, RNG streams, misuse scan (#93) | merged #280, `scripts/sim/switches.gd`, `tests/test_switches.gd` | Any new switch must register there. |
| CI split into logic, simulation, presentation, socket lanes (#101) | merged #286; 13 jobs green on every PR | Both MCP runtimes and three desktop smoke jobs included. |
| macOS export smoke and release-package checks (#176) | merged (7 Oct "validate and launch exported macOS builds") | The macOS *walkthrough* is still a human gate. |
| Generated project status as the source of truth (#177) | merged #287, `docs/PROJECT_STATUS.md` | Tests refuse to run if it is stale. |
| Shared multiplayer seat selection and one seat view (#96, #285) | merged #285; startup tests #306-#309, #312 | #97 (entry-path consolidation) is only partly done, see section 4. |
| Network hardening: TCP framing, dedup, stale remote controls, host beacon/voice lifecycle | merged #259, #260, #282, #290 | |
| Smoke tests for previously unverified systems (#94) | merged #288 and the 7 Oct slices | |
| Employed opening: new stories start as an employed pilot, earn your own plane | merged #296 | The owner says the pace of this opening (how soon a new pilot earns their own aircraft) is right; do not change it. |
| Incoming Family calls and the phone as a handset with apps (#83) | merged #225, #314 | A cockpit-phone pass remains in Codex's queue. |
| Autopilot approach never picks a blocked runway end (#80, #82 part) | merged #318, tests pin it | Mid-flight circling in #80 was never re-verified. |
| Tutorial skip/off are clickable (#324) | merged | Chips are non-focusable so Tab and Enter reach the game. |
| Collaboration stack: MCP pin, shared board, machine lock, sync, locked runner, wake, dashboard, pipeline doc, compact notes, score ledger, handoff | merged #313, #315-#317, #322, #325, #330, #331, #343 | Process, not game. |
| Strip-feasibility harness per runway end (#88 harness) | merged #311 | The *decision* on strips is the owner's (section 3). |
| Planning CSV import churn, road connections, district overview return | merged #310, #302, #301 | |

## 2. No longer needed, or in question where to go

| Item | Why | Suggestion |
|---|---|---|
| #99 Design audit "reconcile human roles and campaign status" | One-off document task; superseded by `docs/PROJECT_STATUS.md` and `docs/AGENT_WORK_SPLIT.md` | Close as done by those documents (unverified that nothing is missing). |
| #118, #139, #158, #174 "program" issues (execution order of #80-#117, #120-#138, #140-#157, #159-#173) | Ordering lists, not work. Already closed. | Keep closed; the order lives in #326 section 3. |
| 16 dated one-off docs: `docs/*_2026-10-0x.md` (ACCESS_VALIDATION, COMMAND_DOMAIN_MIGRATION, COVERAGE_MATRIX, FACTION_AI_ISOLATION, NETWORK_SERVICE_LIFECYCLE, OPEN_PR_AUDIT, PR_INTEGRATION, SHARED_SEAT_SCREEN, STARTUP_FAILURE, TEST_FIXTURE_AUDIT, TEST_LANES, VALIDATION, WORKER_MAP_PORT, REVIEW_2026-10, HANDOFF_HISTORY, ROADMAP_HISTORY) | Point-in-time evidence from the overhaul; nobody reads them to play or build. | Move to `docs/archive/` in one PR (no content change) so `docs/` shows living documents only. |
| `docs/OPEN_PR_AUDIT_2026-10-08.md`, `docs/PR_INTEGRATION_2026-10-08.md` | Describe PRs that are now merged or superseded. | Archive. |
| #100 Arena polish: lap counter, betting, player races, club interior, race gates; #117 player races, laps, betting | `races.gd`, `casino*.gd` (about 1,050 lines) already exist; polish for a side activity. | Owner decision: keep as a side feature, or freeze. |
| #115 emergent campaign director, #116 hidden informant role, #113 fog of war, #114 crew relationships | Large programs on top of an unfinished base: described in detail in section 8. `docs/BACKLOG.md` already says #113 is mostly done (close), #115 partly done (chronicle and events; deferred), #116 deferred. | Owner decision after the first-hour work (section 8 has the proposed first slice of each). |
| #86 pathfinding with ambushes, #87 radar-aware evasion | Radar-aware routing was restored (#295, #297); ambush awareness has no code. | Close #87 as done by #295 (unverified: check the evasion path in `RoutePlanner`); #86 stays a feature. |
| 52 design epics (#120-#138, #140-#157, #159-#173) | All three groups share overlaps (event feed vs notification policy vs error states; dashboards vs HUD vs map layers) and are priced by nobody. | Owner picks an order; the model summary suggests #172 (first-session protocol), #142 (cockpit clutter), #138 (readability) as natural first steps. |

## 3. Owner-only decisions and human gates (not for agents)

All in #326. Open: the seven human release gates (Windows and macOS walkthroughs, controllers and readability at four resolutions, two-machine
multiplayer, functional-site walk, performance captures, radio and asset licensing), and the decisions: job generator vs strips (EGL 19 lb etc.,
`docs/STRIPS.md`), hub approach on natural terrain (HAR end 0), whether flight skill is part of the story goals, which epics first, whether the
wake tool may spend Codex quota unattended. New from the 12 October playtest (#345): the interception pace early game, the first-chapter checkpoints.

## 4. Most problematic (by cost in time, bugs, or process)

1. **The review gate.** Codex acts only when woken; woken turns have no GitHub network, cannot call `github_pr_review`, cannot take claims, cannot write
   inside a linked worktree's `.git`, cannot open the Godot lock. Hours of stalls and several rule breaks (`docs/PIPELINE.md`).
2. **GitHub only through the MCP vs the tools that need `gh`.** The relay and alert feed still run as `gh` copies; the server repo cannot be reviewed or merged
   through the MCP until the `repo` argument ships (skyrunner-mcp PRs 6, 7 approved; a third adds `repo`).
3. **Stale branch stack #244-#276.** 11 PRs, 38-79 commits behind, 156 files in #276; ultrareview refused it (13,597 lines). 22,000 of the lines are 34 generated
   `sim-results/*.json` files. Needs: port onto current `main` bottom-up, or retire as superseded, per the owner. #247's ultrareview found a routing-cost
   doubling with no switch, floating walls on slopes, and a missing BALANCE entry (comment 6112000822).
4. **Autopilot.** The most reported player-facing defect. All of it is now merged: the F3 AI hand-over (#344) and, in #346 (`464cda4`), the take-off hold, the direct turn back, U flying to the waypoint set on the chart,
   terrain look-ahead with a turn toward lower ground, and low-speed power. Evidence: 110 of 112 airfield-to-airfield legs arrive (before: 97, with 14 crashes; the other 2 time out over 95 km of sea) and 119 of 120 random mid-flight
   cases are safe (before: 111). Still open from the owner's list (#345): the autopilot mentioned only when kicking bales. Sweeps: `tools/autopilot_sweep.gd`, `tools/autopilot_midflight_sweep.gd`.
5. **Startup architecture (#97).** Entry paths were consolidated by tests (#306-#312) but the code is still split between `main.gd`, `host_desk.gd` and the
   dedicated server; this is where `_mp` lifetime bugs came from.
6. **Test time.** The suite (1,126 declared test methods in 142 files per `docs/PROJECT_STATUS.md`; 1,114 when last timed at 761 s) takes about 13 minutes under a machine-wide Godot lock; every worktree re-imports for 5 more. This throttles every agent.
7. **Windows memory.** Codex hit `alloc_static` null-memory failures with overlapping Godot jobs (note 3); the lock policy is the only guard.

## 5. Needs a rehaul: early-game bloat and weight (unverified judgements are marked)

| Area | Fact | Proposal |
|---|---|---|
| Demo videos in `docs/video/` | 5 mp4 files, 40.5 MB of the 71 MB under `docs/`. **Owner (12 Oct): new photos and videos are needed; videos go on YouTube.** | Record new videos, upload them to YouTube, link them from README/GUIDE, then remove the mp4 files from git. New stills go in `docs/img`. |
| Asset packs | About 940 Kenney, KayKit and Quaternius model files under `assets/models` (55 MB). **Owner (12 Oct): they are meant to be used in the game so it does not look copy-and-paste; they stay.** Radio audio licensing is still a human gate (#175). | Not a deletion task: a per-pack review of fit for the 1979-86 Caribbean setting, listing which packs the scenes load now and which are still to be placed (#91 becomes this). |
| `sim-results/` (21 files on main, 34 in #276's stack, about 22,000 lines) | **Owner (12 Oct): keep the generated results, or display the data better.** | Keep the JSON; add a generated index (one table: study, date, command, headline numbers, latest file) in `docs/`, and stop adding a new dated file per investigation when the same study is re-run. |
| Large systems around the flying game | `hq.gd` 1,305 lines, `ground.gd` 1,672, `logistics.gd` 1,117, `police.gd` 973, `payroll.gd` 673, `court.gd` 633, `family.gd` 615, `casino.gd` 570 + `casino_games.gd` 479, `island.gd` 536, `trade.gd` 537. **Owner (12 Oct): the empire layer works like the start of Mount & Blade.** | Not bloat: the late game. Start small (one aircraft, one strip, a few crew), grow through contracts, followers and territory; the casino, island and court layers open late and stay gated by the chapter table (`story.gd`). Check the first hour does not show them. |
| The first hour | The owner's playtest (#345): start pace is right; too many early police chases; tutorials not split by phase (take-off, flight, landing, loading); dirt take-offs too lethal; runway-end turn-around unexplained; no reverse | The checklist in #345 is the rehaul list. |
| `skyrunner/` folder at the repository root of the owner's checkout | A nested folder not in git | *Unverified:* ask the owner what it is before touching it. |
| Untracked `dist/`, `dsm5-site/`, `usb-*`, `addons/codex_workbench/`, `opencode.json` in the primary checkout | Not game files | Owner decides; none are tracked. |

## 6. Proposed closings and tickings

Done on 12 October: #337 closed as superseded by #338. Checked and kept open: #304 (still-valid docs after #296, awaiting review) and #339 (a discussion draft Codex has not answered; its useful parts are in `docs/PIPELINE.md`). #320 not yet checked against `docs/PIPELINE.md`.

* Tick in #327/#328: nothing is *fully* done there; partials: #80 (end choice fixed, circling unverified), #82 (intercept restored #295; turn-back, waypoint and terrain look-ahead merged in
  #346, so #82 can be ticked), #97 (entry tests merged, consolidation not), #83 (calls merged, cockpit pass open), #90 (CSV churn #310 done, CI hygiene open), #98/#88 waiting on the owner's strips decision.
* Close as done with the evidence above: #95, #93, #94, #96, #101, #176, #177 (all already closed "not planned"; reopen is not needed, add a "done by #n" comment instead).
* Move the 16 dated docs to `docs/archive/` (one PR).
* Open issues for the new findings: #345 (playtest), autopilot sweep results, the #247 ultrareview items.
* Retire or rebase the stale stack #244-#276 per the owner's call, bottom-up, with the focused tests.

## 7. Decisions made by the owner on 12 October

1. The "complete and unlikely to change" list (section 1) is accepted; open PRs that are superseded are closed (done so far: #337, a smaller duplicate of #338).
2. GitHub work goes through the MCP so the agents do not overwrite each other. When Claude takes over Codex's work it is noted on the PR and the board, and the
   handoff documents exist (`docs/CLAUDE_ROLE_HANDOFF.md`, `docs/PIPELINE.md`, `HANDOFF.md`).
3. The local model reads finished documents as a first-pass reviewer (unclear passages and missing links only); Claude checks every point against the repository.
4. Videos go to YouTube; new photos and videos are needed. The roughly 940 asset files stay and are checked for fit to the era. Generated results stay, with better display.
5. The empire layer follows the start of Mount & Blade (section 5).
6. The boss is the player's **uncle**; chapter 2 is a few suspicious jobs while he starts to reveal his business; in a later chapter **Los Cuervos kill him**, which starts the turf wars, and the player **takes his seat as boss** without being locked out of the other layers (section 8.5).

## 8. The four programs and the 52 design epics, in detail

Each says what exists (file:line from a read of `main`), what is missing, and the smallest first slice. Source: a read-only code survey on 12 October.

### 8.1 Campaign director (#115): partly done
* **Exists.** `Campaign` (`scripts/sim/campaign.gd:97-128`): four tutorial chapters 1979-82, each switching on features for both sides and setting objectives; `apply()` :167,
  `_on_event` :204, `tick()` :220-238. `Story` (`story.gd:20`): twelve chapters 1979-89 reusing `Campaign.Chapter`; `_open` :296 enables systems; `tick` :432-499 polls goals and side
  goals with a bonus; waivers (`_waive` :353) stop a dead faction softlocking progress; one scripted beat (the House uprising, :459). `EmploymentOpening` (`employment_opening.gd:7-12`): three fixed
  stages, one job each, its own comment says the price needs a pacing playtest. `EventBus` (`events.gd`): synchronous bus, last 400 events, tagged by side. `Chronicle` (`chronicle.gd`): the nearest thing
  to a director: one random event about every 480 s on a Poisson clock (:31, :143-165), side then good or bad luck then an event the `_can()` gate allows (:167, :202); real-history headlines on a timer.
  `AISmuggler.Director` (`ai_smuggler.gd:149`) paces AI flights (at most 2). `NightDirector` (`nights.gd`) bridges HQ season and live session.
* **Missing.** Nothing models the player's state (wealth, stress, boredom, recent failures) or reads it; chronicle pacing ignores the situation (constant interval, uniform pick among legal events);
  chapters are linear and time-independent; one-shot setup exists only for campaign chapters 2-4 and the House chapter; the employed opening does not adapt; multiplayer sends only the player's own chapter text.
* **First slice.** A director that sets only the chronicle's event weights and rate from a few measurable player signals (cash vs the next goal, heat, time since last event), behind a switch, with a balance run;
  this is also where the owner's early police-pace request (#345) lands. No branching chapters.

### 8.2 Fog of war and the unified strategic map (#113): mostly done, `docs/BACKLOG.md` says close
* **Exists.** Role-filtered snapshots (`scripts/net/snapshot.gd:19`): runner and law never receive the other side's true state; runner gets own aircraft, boats, intel on known police (:158-171), stashes and trucks,
  spotter reports; law gets radar tracks with age and source (:231-236), known stashes only, DF, radars, jammed zones; the police pilot sees the runner only when `_can_see` passes (:92-96). Ground war
  (`ground.gd:365-380`): 1,500 m sight, 150 m for hidden squads, fights seen only when both sides are observed; district summaries use observed enemies (:1320-1334). The runner's `intel` list is the only last-known
  memory; the minimap fades it by age (`minimap.gd:403-414`); law tracks go stale after 6 s (`station_map.gd:313-318`). Two map renderers: the pilot minimap/chart and `StationMap` (layers :11-14).
  Note: the `fog` session option and `tests/test_fog.gd` are sea-fog weather, not fog of war.
* **Missing.** No persistent explored or known-territory model; no last-seen memory for ground squads (they vanish when unobserved); no shared team picture per side; no single map component (the two renderers
  duplicate logic); no uncertainty drawn for ground units; nothing fogs terrain or districts, only entities.
* **First slice.** One per-side knowledge store (position, time seen, source, confidence, decay) that both existing maps read; the existing `intel`, `tracks` and `known()` lists are its seeds. Close #113 as done by the
  role-filtered snapshots and open this as a smaller issue if the owner wants it.

### 8.3 Hidden informant role (#116) and the informant system (#108): system exists, role deferred
* **Exists (all automated).** `Session._informant_roll` (`session_ops.gd:105-118`): per hot job, chance `1-(1-0.30)*(1-leak)^spotters`, a 3 km tip at the destination, halved by the bug-sweep upgrade. Tips go through
  `PoliceSystem.add_tip` (`police.gd:529-540`) to the human analyst desk if seated (45 s to check, forward or bin; tips can be false). HQ season: informants are a counted law resource capped at 2, hired by order, countered
  by counterintelligence (`hq.gd:216, 664-674, 860-865, 985-993`). Ground war: a controlled buy every 600 s reveals a stash (`ground.gd:1279-1293`). Courts count them as witnesses; chronicle events `informant_turned`, `snitch`, `rat_flipped`.
  Roles: 15 (`roles.gd:9-24`), a hard two-sided split (`side()` :81-82); the waiting room and `HostServer` broadcast every seat's role to all players (`room.gd:115-119`, `host_server.gd:527-541`); chat and voice route by side.
* **Missing for a hidden role.** A third allegiance (a runner-side seat that secretly reports to law); a server-only hidden attribute (today the roster exposes roles); assignment that is not chosen in the open
  waiting room; two information sources for one player (runner state plus a leak to law, with the analyst tip path as the existing sink); play for the informant (act, be detected, counterintelligence for players);
  dedicated-server, reconnect-token and AI-fill handling; and tests (there is no test of hidden seat information).
* **First slice.** None until a design exists: it depends on a decision about whether multiplayer is the priority. If yes: the hidden attribute and the snapshot split first, tested, before any gameplay.

### 8.4 The 52 design epics (#120-#138 UI and dialogue, #140-#157 UX, #159-#173 player satisfaction)
Codex leads UX/UI; all of these are for the owner to order. What the code shows for the topics (keyword survey, so a pointer and not a verdict):
* **Player satisfaction (15).** Partly present: difficulty and assist options (9 files, 1 test), crew attachment (relationship/loyalty words in 12 files, 10 tests), world reactivity (weather 24 files). Absent: telemetry
  (no files), a flight recorder or debrief (2 files, no tests), adaptive pacing (see 8.1). Natural first steps: #172 first-session protocol (the owner's playtest #345 is that protocol), then #165 failure fairness
  (the owner asked for tyre wear instead of instant crash and forgiving first-chapter checkpoints) and #173 transparency.
* **UX (18).** Present: GameMenu/UIStyle shared look, KeyHints with clickable caps (#324), accessibility palettes (3 files). Absent: undo/cancel (1 file, no tests), persistent breadcrumbs, a notification priority
  policy. Overlaps: #140 vs #151 (input grammar and interruption policy), #149 vs #154 (error states and save confidence), #148 vs #155 vs #134 (discoverability, tutorial pacing, onboarding). Natural first step: #142 cockpit
  clutter (the owner wants the autopilot mentioned only when kicking bales) with #155 (tutorials by phase: take-off, flight, landing, loading).
* **UI and dialogue (19).** Present: the phone as a handset with apps and calls (#225, #314), role station dashboards, the shared menu frame. Absent: a dialogue framework with character memory (#130, #131), briefing/debriefing
  scenes (#133). Overlaps: #130 and #131; #135 and #124. Natural first step: #138 accessibility and readability, since it touches everything else.
* **Rule for all 52.** One epic is started only when the owner names it; the first PR is its smallest slice behind the shared UIStyle/GameMenu, with a screenshot, never a rewrite.

### 8.5 The boss layer: the uncle, and taking his seat (owner, 12 October)
* **Owner's story.** The boss is **the player's uncle**. In the second chapter the player flies a few suspicious jobs for him and he slowly starts to reveal his business. In later chapters **Los Cuervos kill him**, which starts the
  **turf-war part of the game**, and the player **takes his seat as boss of the organisation**. The player is not locked into that seat: they can still take part in the other layers (flying, the ground, the desks), the way Mount & Blade lets a lord still fight in the field.
* **Fit with the story table (`scripts/sim/story.gd:20`).** Chapter 1 "Square Grouper" (the employed opening, `employment_opening.gd`) introduces the employer/uncle; chapter 2 "The Connection" is the suspicious jobs and the slow reveal (the connection call, cash home, the dealership);
  chapter 3 "Blotter" widens the business; **chapter 4 "Cocaine Cowboys" already turns on Los Cuervos, the ground war, guns and soldiers** (`story.gd`, opens `ground_war`, `guns`, `role_soldier`): the natural place for the uncle's death and the takeover. Chapters 5-12 are the player as boss
  (the Family, the task force, the island, the House, the Company, Kingpin).
* **Exists.** `Roles.BOSS` (`scripts/sim/roles.gd:13`) is a seat: "the organisation's HQ, night by night" (:29), with its own command list (:54: `hq`, `casino`, vehicles, fleet and barter automation, chat, tutorial). `hq.gd` (1,305 lines) runs the nightly season; `ground.gd` is the turf war. Solo, the boss's desk is a place you walk or taxi to
  ("hq_org", `pilot_app.gd:1020`) with `HQMenu` as the screen; seats are separate in multiplayer (`MODE_ROLES`, `roles.gd:72-78`), and a solo player reaches every desk from the phone, so nothing locks a solo player into one role. Hired pilots exist (`payroll.gd`) and the AI can fly a job (`AutoRunner`, `PilotBot`).
* **Missing.** The uncle as a character (the employer is anonymous in the opening); the chapter-2 reveal beats; a scripted death by Los Cuervos in or after chapter 4 (story beats like the House uprising are scripted, `story.gd:459`, so there is a pattern); the takeover moment (the boss seat and the HQ orders becoming the player's); and a way to delegate your own flights
  to a hired pilot so being the boss is a real alternative to flying. Solo, the boss desk is just another menu from the start.
* **First slice (proposal).** (1) Name the employer as the uncle in the opening and give chapter 2 two or three dialogue beats (talk scenes through `scripts/game/talk.gd`). (2) In chapter 4 a scripted beat after the first Cuervos incident kills the uncle, turns on the turf war and hands the player the boss desk and its orders. (3) A hired pilot who flies delegated jobs with the existing bot.
  Every other layer stays open at all times. Dialogue and the death scene are Codex's lane (UI and dialogue); the beat and the unlock are Claude's.
* **Owner's answers (12 October).**
  * **The uncle's character:** jovial, a character bigger than life, but with a darkness to him that you can't put your finger on. (His name is not given yet.)
  * **His death:** the player **hears about it**; it is not witnessed. He leaves the player a **crumbling empire to fix**, so the player **starts smaller** than he ran it (the Mount & Blade start of section 5). Exactly which stashes, trucks, crew and money survive the takeover is **not decided** (see the open list below).
  * **Delegating a flight costs money**, because you hire people out.
  * **Reputation is trust with the other crews.** It is gained by building trust with a crew and it makes you lose trust with some of the others, depending on which crew. Trust is also **lost when you lose shipments**, and a crew whose trust you have lost **goes to other sources** for the product they sell, and so on down the chain.
* **What this asks of the code.** Trust per crew is **not new state everywhere**: the Sunrise Collective already has an authoritative `Psychedelics.trust` (0..100, `psychedelics.gd:62`, it sets the barter rate at :107-113, changes after trades and raids, is shown in the UI and is saved through `StrategicSave.PSYCH`, `strategic_save.gd:38`), and the Family and the Company keep their own standings in `family.gd` and `agency.gd`. The design therefore needs **one source of truth**: a single per-crew trust table that the Collective, the Family and the Company fields delegate to or migrate into (with a save migration), not a second, divergent number. A lost shipment must hit the trust of the crew it was meant for (`Logistics.lost_by`, `logistics.gd:45`, already counts seized, hijacked, raided and bust losses). A crew that defects needs **an outside or rival supply flow** to go to: `logistics.gd` stashes and convoys hold only our own stock and cash (`logistics.gd:39-44`) and `Trade.BUYERS` (`trade.gd:51`) are downstream buyers, so neither can stand for "another source". Opposing crews give and take trust in a small table. First slice: the shared trust table with migration, a lost-shipment hook, a rival supply flow for one crew, and a visible trust line per crew in the phone. Needs the owner's table of which crews trade trust against which.
* **Still open for the owner.** The uncle's name; the table of crew relationships (who gains when whom loses); how much of the empire is "crumbling" at the start of the takeover (which of the stashes, trucks and crew are still there).

## 9. Start-up architecture (#97): what Claude needs answered before consolidating

Eight entry paths today (solo, direct host, waiting-room host, host at a desk, join, late-join picker, offline police desk, dedicated server) plus campaign, story and the CLI-only `--watch`, `--smoke`, `--shot`. The session
options dictionary is built twice (`main.gd:228`, `dedicated_server.gd:196-208`) and the host frame loop three times with three different steps (`pilot_app.gd:1362-1375` variable dt, `host_desk.gd:26-32` clamped,
`dedicated_server.gd:257-271` fixed 30 Hz); the beacon payload and the pilot-seat AI toggle are duplicated; voice exists only in `main._host_extras`; the lobby omits four join roles that the room allows
(`lobby.gd:34` vs `room.gd:15`); police and campaign cannot be hosted through the room (`main.gd:107`). `docs/BACKLOG.md:68,128` still says `_join()` and `_seat()` are untested, but `tests/test_startup.gd:90-134` covers them.

Questions for the owner:
1. One host service (server, beacon, voice, session loop) used by the pilot app, the host desk and the dedicated server, or does the dedicated server stay a separate headless path?
2. Which update step: variable, clamped, or fixed 30 Hz? Replays and balance runs may depend on the answer.
3. Should the dedicated server have voice, which needs a local mic and mixer decision?
4. Should campaign and police modes be hostable in the waiting room, and should the offline police desk stay?
5. Should the dedicated server run Campaign, chapter selection, the tutorial or `--watch`? Today only the employed story or a saved game.
6. Which options belong in the lobby and which only on the command line (name, port, password, join roles, seed)?
7. Should `--smoke` and `--shot` work on every entry path, including the host desk?
8. Is the beacon always owned by the server node, including the dedicated server?
9. Is the lobby's "open remote seats" box one flow with the waiting room, or two?
10. Where should save selection live? Four paths exist (`campaign.json`, `story.json`, `save.json`, `user://dedicated.json`).

### Answers recorded later on 12 October
* Start-up architecture, question 1: **one shared host service** (server, beacon, voice and session loop) used by the pilot app, the host desk and the dedicated server. Questions 2-10 are still open.
* Landing the three server-repository PRs (skyrunner-mcp 6, 7, 8) with `gh` once: no answer given, so `gh` is **not** used; they stay open until the owner says, or until the running tools can reach that repository.
* The checkbox ticks for #80, #83, #87 (and #82 now that #346 is merged) are recorded as comments on #328 and #329; editing the issue bodies needs skyrunner-mcp PR 8 (`replace_body`).

## 10. Every open item on 12 October, one line each
Taken from `github_pr_triage` and `github_issue_list` at the end of 12 October (37 open pull requests and 5 open issues). Everything that is not listed here is merged (complete) or closed (not needed). Categories: **ready** (done, waiting for the other agent's exact-head review), **keep** (still valid, needs a sync or an owner call), **in question** (the owner or an agent must decide), **retire?** (superseded or stale: a close is proposed, nothing is closed without the owner for the stale stack).

### Open issues
* [ ] **#326** owner: release gates, decisions and design epics. keep (the owner's page; never ticked by an agent).
* [ ] **#327** agents: the work queue index. keep.
* [ ] **#328** Claude queue. keep (ticked from this document: #80, #82, #87).
* [ ] **#329** Codex queue. keep (ticked: #83).
* [ ] **#345** owner playtest of 12 October (checklist). keep (autopilot, F3, goals, police pace done or in review; tutorials by phase, air camera look, slow reverse, tyre wear on dirt, key audit are Codex's QA lane).

### Ready: done, awaiting Codex's exact-head review (usage returns 4:11 PM)
* [ ] **#350** early police pace (BALANCE item 53 added). ready.
* [ ] **#357** dedicated server: campaign, `--chapter`, `--watch`, voice relay (Codex bot's two findings fixed; the third is the follow-up "resuming a partial campaign"). ready.
* [ ] **#358** the waiting room hosts campaign and police tables. ready (sync `police.json` with #365 when the second one merges).
* [ ] **#359** lobby game name, password, port, join roles. ready (same file as #364).
* [ ] **#360** `--smoke` and `--shot` on every entry path. ready.
* [ ] **#361** docs: the owner's second round of answers. ready.
* [ ] **#362** pin skyrunner-mcp `1b8edfd` (43 tools). ready.
* [ ] **#363** the LAN beacon always belongs to the server node. ready.
* [ ] **#364** one hosting flow: the waiting room. ready.
* [ ] **#365** one saves folder with a migration. ready.

### Keep: valid drafts that need a sync or a decision
* [ ] **#321** score rows 15-22 (draft). keep: the owner's ruling is recorded; merge after review.
* [ ] **#320** joint working plan. in question: `docs/PIPELINE.md` and `docs/CLAUDE_ROLE_HANDOFF.md` cover most of it; propose closing.
* [ ] **#304** docs about the employed opening. keep: still valid.
* [ ] **#339** pipeline discussion draft. keep: unanswered questions.
* [ ] **#340** docs: which MCP server and how an agent joins. in question: conflicts; `tools/mcp/README.md` and `docs/COLLABORATION.md` cover it; propose syncing or closing.
* [ ] **#338** first pass by the local model (a test). retire?: a Bonsai draft; the better of the two duplicates, #337, was closed.
* [ ] **#336** `tools/local_llm` worker. keep: conflicts; needed by the local-model tools' reviewers; sync.
* [ ] **#335** relay script and MCP client. keep: conflicts; the on-disk MCP version of the relay.
* [ ] **#334** chapter-goal source audit. keep: docs; conflicts.
* [ ] **#333** scripts for the human release gates. keep: docs; conflicts (Codex's lane).
* [ ] **#332** `sync_shared --baton theirs`. keep: conflicts.
* [ ] **#323** and **#319** strip trials and the STRIPS.md regeneration (#88). keep: wait for the owner's strip decision (#326).
* [ ] **#305** a road node shared by both connector endpoints. keep: conflicts.
* [ ] **#303** P05 action-preview reference screen. keep: UX/UI is Codex's lane.
* [ ] **#300** screenshot matrix and lobby shortcuts. keep: conflicts.

### Stale stack: the owner's call
* [ ] **#244, #247, #253, #265, #267, #268, #269, #272, #274, #275, #276**: eleven stacked road, loading-site, settlement and recording branches from 8-11 October. In question (a decision on the whole stack): either sync each in order on top of main and review, or retire the stack and redo the wanted parts. `#276` is the top of the stack and conflicts with main, 156 files.
