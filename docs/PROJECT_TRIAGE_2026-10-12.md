# Project triage, 12 October 2026: what is finished, what is in question, what hurts, what to overhaul

Written for the owner's goal ("close things out properly or tick things partially; list everything: complete and unlikely to change, no longer
needed or in question, the most problematic, and what needs a rehaul from the early parts of the game that is bloat"). It covers all 5 open
issues, the 98 closed ones, the 28 open PRs, the 47 squash-merged PRs on `main`, the repository's weight, and the biggest systems.

**How to read it.** Every row says how it is known: *merged* (a PR on `main`, number given), *tested* (a test file exists and passes in the suite), *code
exists* (present in `scripts/` but not checked beyond that), or *unverified* (a judgement from titles and size, to be confirmed). Nothing here is
closed or ticked by this document: closing and ticking need the owner's say for human gates and decisions (#326), and are proposed, not done, for
the rest (section 6). The 98 closed issues were consolidated on 11 October as "not planned" with pointers, so "closed" does not mean "done": done
means a merged PR or a passing test, and is stated per row.

## 1. Complete and unlikely to change

| Item | Evidence | Note |
|---|---|---|
| Session split into layers and stateless command domains (#95) | merged #284, 1114 tests | Structure of `session_*.gd`; the layering rule is in CLAUDE.md. |
| Determinism: parity switches, RNG streams, misuse scan (#93) | merged #280, `scripts/sim/switches.gd`, `tests/test_switches.gd` | Any new switch must register there. |
| CI split into logic, simulation, presentation, socket lanes (#101) | merged #286; 13 jobs green on every PR | Both MCP runtimes and three desktop smoke jobs included. |
| macOS export smoke and release-package checks (#176) | merged (7 Oct "validate and launch exported macOS builds") | The macOS *walkthrough* is still a human gate. |
| Generated project status as the source of truth (#177) | merged #287, `docs/PROJECT_STATUS.md` | Tests refuse to run if it is stale. |
| Shared multiplayer seat selection and one seat view (#96, #285) | merged #285; startup tests #306-#309, #312 | #97 (entry-path consolidation) is only partly done, see section 4. |
| Network hardening: TCP framing, dedup, stale remote controls, host beacon/voice lifecycle | merged #259, #260, #282, #290 | |
| Smoke tests for previously unverified systems (#94) | merged #288 and the 7 Oct slices | |
| Employed opening: new stories start as an employed pilot, earn your own plane | merged #296 | The owner says this pace is right; do not change it. |
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
| #115 emergent campaign director, #116 hidden informant role, #113 fog of war, #114 crew relationships | Large design programs on top of an unfinished base; each has some code (`campaign`, `informant`, `fog` words appear in 8-25 files) but no acceptance defined. | Owner decision: which, if any, before the first-hour work is done. |
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
4. **Autopilot.** The most reported player-facing defect: take-off engage flew into terrain (fixed in #346), the AI hand-over did nothing in flight (#344), no
   direct turn back and no waypoint (fixed in #346's later commits), and, pending the sweep, some airfield pairs.
5. **Startup architecture (#97).** Entry paths were consolidated by tests (#306-#312) but the code is still split between `main.gd`, `host_desk.gd` and the
   dedicated server; this is where `_mp` lifetime bugs came from.
6. **Test time.** 1,114 tests take about 13 minutes under a machine-wide Godot lock; every worktree re-imports for 5 more. This throttles every agent.
7. **Windows memory.** Codex hit `alloc_static` null-memory failures with overlapping Godot jobs (note 3); the lock policy is the only guard.

## 5. Needs a rehaul: early-game bloat and weight (unverified judgements are marked)

| Area | Fact | Proposal |
|---|---|---|
| Demo videos in `docs/video/` | 5 mp4 files, 40.5 MB of the 71 MB under `docs/` | Move out of git (release assets or LFS) or drop; keep stills. |
| Asset packs | 824 Kenney model files + 85 KayKit + 27 Quaternius under `assets/models` (55 MB total); radio audio licensing unresolved (#175 gate) | #91: list which packs the shipped scenes load; delete the rest. *Unverified which are unused.* |
| `sim-results/` (34 files, about 22,000 lines in #276's stack, 21 files on main) | Generated evidence JSON checked in with each investigation | Stop committing run output; keep a single latest summary per study, or put them in CI artifacts. |
| Large systems around the flying game | `hq.gd` 1,305 lines, `ground.gd` 1,672, `logistics.gd` 1,117, `police.gd` 973, `payroll.gd` 673, `court.gd` 633, `family.gd` 615, `casino.gd` 570 + `casino_games.gd` 479, `island.gd` 536, `trade.gd` 537 | The empire layer is larger than the flying core; owner decision (section 2) on the casino, island and court as optional layers. *Judgement, unverified against playtime.* |
| The first hour | The owner's playtest (#345): start pace is right; too many early police chases; tutorials not split by phase (take-off, flight, landing, loading); dirt take-offs too lethal; runway-end turn-around unexplained; no reverse | The checklist in #345 is the rehaul list. |
| `skyrunner/` folder at the repository root of the owner's checkout | A nested folder not in git | *Unverified:* ask the owner what it is before touching it. |
| Untracked `dist/`, `dsm5-site/`, `usb-*`, `addons/codex_workbench/`, `opencode.json` in the primary checkout | Not game files | Owner decides; none are tracked. |

## 6. Proposed closings and tickings (nothing done yet)

* Tick in #327/#328: nothing is *fully* done there; partials: #80 (end choice fixed, circling unverified), #82 (intercept restored #295, turn-back and waypoint in
  #346), #97 (entry tests merged, consolidation not), #83 (calls merged, cockpit pass open), #90 (CSV churn #310 done, CI hygiene open), #98/#88 waiting on the owner's strips decision.
* Close as done with the evidence above: #95, #93, #94, #96, #101, #176, #177 (all already closed "not planned"; reopen is not needed, add a "done by #n" comment instead).
* Move the 16 dated docs to `docs/archive/` (one PR).
* Open issues for the new findings: #345 (playtest), autopilot sweep results, the #247 ultrareview items.
* Retire or rebase the stale stack #244-#276 per the owner's call, bottom-up, with the focused tests.
