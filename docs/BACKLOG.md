# Backlog: open issues and pull requests

A living register of every open issue and PR: what it is, where it stands against `main`, and what to do with it.
Update it when you close, merge or rebase something; don't start a dated copy. Last full pass: **10 October 2026,
Claude**, against `main` @ `f703a9f`. The product order it follows is in
[DESIGN.md §0](DESIGN.md#0-where-the-game-is-heading-owner-approved-direction-8-october-2026) and
[ROADMAP.md](ROADMAP.md).

Status words: **done** (in `main`, verified in code), **partly**, **not started**, **lost** (merged once, then
removed), **gate** (needs a human, hardware or a legal decision, not code).

## Findings from this pass

1. **Three merged issue fixes were silently undone.** On 7 October, `bb377dd` and `368d171` merged:
   - the autopilot forward intercept (#80/#82);
   - the payroll demand report (#81);
   - radar avoid-zones in the route planner (#87);
   - a macOS smoke job.

   Minutes later, `d91975f` ("Merge complete overhaul implementation repair") deleted all of them and their tests.
   The macOS job came back with #223. The rest did not, but the roadmap's issue-pass note still lists #80, #81, #82
   and #87 as covered. **Fix: re-apply `368d171` and `bb377dd`'s route/payroll hunks, with their tests.**
2. **The 31 open Codex PRs are one long chain**, not separate stacks. Each was branched from the tip of the previous
   one, linked by PRs that have since been closed or superseded (#246, #249, #256/#257, #273). GitHub shows
   36 conflicts into `main`, but replaying each PR's own code commits onto `main` gives a better picture: **16 PRs
   apply cleanly**, and only the employed-opening and road/loading stacks need real rebasing.
3. **The 90 open issues were never updated.** One issue has a comment. Several are done, two are duplicates, and the
   four "program" issues (#118, #139, #158, #174) are superseded by the owner's product order.

## Open pull requests

Replay result: each PR's code and test changes (not its dated docs or `sim-results/` files), applied in stack order
onto `main` with `git apply --3way`. *Clean* means it applied, not that it passes tests; see the combined test run
below.

| Stack | PR | What it does | Replay | Recommendation |
|---|---|---|---|---|
| Assets & campaign polish | #227 | HAR workshop props | clean | Merge with the stack after the combined run |
| | #228 | Coastal props, port dress | clean | 〃 |
| | #229 | Report actual chapter outcomes | clean | 〃 |
| | #230 | Persistent chapter guidance on the phone | clean | 〃 |
| | #231 | Contact dialogue and epilogue polish | clean | 〃 |
| Empire command | #235 | Authored logistics loading endpoints (read-only) | clean | 〃 (package A step 1) |
| | #236 | Squad condition/travel/upkeep cards | clean | 〃 (package B) |
| | #237 | Validated local detours for vehicle access | clean | 〃 |
| | #238 | HQ can only target observed squads | clean | 〃 (an intel-leak fix) |
| | #239 | District control/collection summary | clean | 〃 |
| | #240 | Own-unit battle accounts | clean | 〃 (needs #245) |
| | #244 | Live escorts kept, stale stakeouts cleared | clean | Hold: changes balance (#98); decide the AI knowledge policy first |
| | #245 | Release surviving squads when combatants are removed | clean | Merge with #240 |
| Map & controls | #247 | Costa Brava settlements rebuilt in period architecture | clean | Needs visual review and a performance capture before merging (package C) |
| | #248 | Controls navigation and hardware calibration | clean | Merge after the combined run |
| Employed opening (product step 1) | #250 | New story starts employed; four opening flights; loaned Cessna | **conflicts** (`pilot_app.gd`, `story.gd`, handlers moved by #284) | Rebase onto `main` as one PR, with #251, #252 and #255 |
| | #251 | First criminal run goes to an unpoliced strip | conflicts (depends on #250) | 〃 |
| | #252 | First-ownership milestone in the journal | conflicts | 〃 |
| | #253 | Gameplay recordings, README/player docs | clean (code) | **Don't merge the 30 MB of video into git (#91).** Keep the docs text and put the media in a GitHub release |
| | #255 | Explicit `--chapter` skips the opening | conflicts | Fold into the #250 rebase |
| Road search | #258 | A* heap; identical paths, ~13% faster searches | clean | Merge after the combined run |
| Road & loading access (package A) | #265 | Villa road terminal and loading approach | conflicts | Rebase as one series after #235/#237 land; re-audit the 99 pairs |
| | #267 | FRM service approach for Company loading | conflicts | 〃 |
| | #268 | Clear roads through functional buildings | conflicts | 〃 |
| | #269 | Period land vehicles with LODs | clean | Merge independently (package C), with visual review |
| | #270 | Keep usable connections after dead ends | conflicts | Rebase with the series |
| | #271 | District overview back-navigation, repeated seat toggles | conflicts | Small UI fix: rebase on its own, early |
| | #272 | Spatial index for road-graph construction (167→29 ms) | conflicts (needs #258's benchmark tool) | Rebase after #258 |
| | #274 | The Moretti club and its loading area | conflicts | Rebase with the access series |
| | #275 | No raised lips at sloping crossings | clean | 〃 |
| | #276 | Loading-endpoint diagnostics tool | conflicts (needs #268's tool) | 〃 |
| Docs/tools | #293 | Direction docs, relay handoff, MCP server, UIDs (Claude) | n/a | Merge (CI green) |

## Issues

### Bugs and concrete enhancements (#80–#100, #175)

| # | Title | Status | Recommendation |
|---|---|---|---|
| 80 | Autopilot circling at QRY/PNR | **lost** (see finding 1) | Restore `368d171`'s forward intercept and test; then close |
| 81 | Crew auto-hiring and roles | **lost** demand report; hiring by `needs()` exists | Restore the demand report; the rest belongs to product step 2 (automation) |
| 82 | Autopilot route selection and interception | **lost** (same patch as #80) | Restore with #80. The full planner/lock design in the issue is optional |
| 83 | Incoming calls | partly: Family offers ring the shared phone (#225) | Keep for other call sources; fold #125 and #132 into it |
| 84 | Physical payroll NPCs | partly: payroll bodies and checked travel exist; work isn't arrival-gated (deferred) | Keep; close #102 as its duplicate |
| 85 | Combat from physically present agents | not started | Keep: package A step 6, after movement migration |
| 86 | Pathfinding: terrain, checkpoints, blocked routes | partly: penalty hook, checked routes; #258/#270/#272 drafts | Keep: package A |
| 87 | Radar-aware hot routing | **lost** (avoid zones removed by `d91975f`) | Restore the route-planner zones and test, then wire known radar into `_autopilot_navigate` |
| 88 | QRY/PNR aircraft/load feasibility | documented, not resolved: in `docs/STRIPS.md` the bot's C182 overruns QRY and PNR at light load, and the C172 can't take off from them at half load, so the job board can send a load where it can't fly out | Keep: an owner/balance decision (accept and stop offering those loads, or change the strips) |
| 89 | Two-machine multiplayer verification | gate | Keep until a real two-machine session is recorded |
| 90 | Housekeeping and CI hygiene | partly: `tools/hygiene.sh` enforces the stray-folder, scratch-script and export-filter checks | Narrow to the dead-code scan, or close |
| 91 | Repository weight | not started: `.git` is 190 MB; `docs/video` tracks 41 MB of MP4 | Keep. Move videos to release assets; don't add #253's media |
| 92 | Persist visible strategic systems | **closed 10 Oct**: `StrategicSave` covers every system the issue lists. In-transit trucks, boats and jobs are deliberately not saved: saves are written parked (documented in the file header) | Closed |
| 97 | Centralise host services | partly, **kept open**: #282/#290 share voice and beacon setup and the failed-host path, with tests; but `_join()`, `_seat()` and the other listed entry paths have no coverage (`PROJECT_STATUS.md` agrees) | Keep: add entry-path tests for `_join()` / `_seat()`, then close |
| 98 | Strategic balance pass | gate (evidence) | Keep; run after #244 and the AI-knowledge decision |
| 99 | Reconcile roles and campaign docs | **closed 10 Oct** (done) | Closed |
| 100 | Arena polish | partly: race betting exists (`races.gd`); no lap counter, no player-vs-player races, gate robustness unchecked | Keep; close #117 as its duplicate |
| 175 | Asset and radio licensing | gate (legal) | Keep: blocks public release |

### Feature specs (#102–#117) and the program issue #118

| # | Title | Status | Recommendation |
|---|---|---|---|
| 102 | Physical payroll agents | **closed 10 Oct** as a duplicate of #84 | Closed |
| 103 | Physical cargo manifests | partly: trucks carry stock; cars have no manifest | Keep (step 2/3) |
| 104 | Police intelligence memory | not started as specified (the analyst desk and case exist) | Keep (step 3) |
| 105 | Intel-driven checkpoints | partly: police squads set checkpoints | Keep (step 3), after #104 |
| 106 | Police vehicle pursuit | not started | Keep (step 3) |
| 107 | Vehicle damage and occupants | not started (aircraft wear only) | Keep |
| 108 | Informant system | partly: informant pressure, the analyst desk | Keep (step 3) |
| 109 | Dynamic jobs | partly: boards follow features and origin type | Keep (step 2/3) |
| 110 | Weather and day/night | mostly done: the realism layer's weather, moon and fog | Narrow to whatever is missing, or close |
| 111 | Flight planning and diversion | not started | Keep |
| 112 | Maintenance and specialisation | mostly done: Airframe wear, repairs, mechanic (§39) | Narrow to specialisation, or close |
| 113 | Strategic map and fog of war | mostly done: role-filtered snapshots, station map layers | Close; follow-ups are in package B |
| 114 | Crew relationships | deferred (roadmap) | Keep, labelled deferred |
| 115 | Campaign director | partly: chronicle and events | Keep, deferred |
| 116 | Hidden informant (multiplayer) | deferred; a separate proposal per §0 | Keep, deferred |
| 117 | Races, laps and betting | **closed 10 Oct** as a duplicate of #100 | Closed |
| 118 | Program: #80–#117 order | **closed 10 Oct** (superseded) | Closed |

### UI, UX and player-satisfaction specs (#120–#174)

There are 54 short specs (about 350 characters each) and three program issues. The overhaul merged on 7 October
delivered part of many of them; none has been playtested.

| Group | Issues | Status |
|---|---|---|
| Delivered in large part by the overhaul | #120 event feed, #121 contextual actions and previews, #124 map layers, #130 dialogue framework, #136 command acknowledgement, #141 focus and selection, #143 action feedback | Code merged; human acceptance pending |
| Partly delivered | #122 HUD, #123 radar confidence (report age and source), #125 phone (Family calls), #126 crew screen (people map), #135 station dashboards, #137 pause/save, #138 accessibility (palettes, read-aloud), #140 interaction grammar, #147 reason codes, #149 error states, #150 ownership and latency | Each needs a short "what's left" |
| Feed into package B (empire feedback) | #127 load planner, #129 job risk explanation, #163 debrief, #160 choice audit, #162 career identity | Map onto package B slices |
| Playtest and measurement | #155 onboarding audit, #157 friction telemetry, #171 responsiveness, #172 first-hour protocol | Gates; run with the first human sessions |
| Not started | #128 intelligence desk, #131–#134 dialogue memory, briefings and tutorial, #142, #144–#146, #148, #151–#154, #156, #159, #161, #164–#170, #173 | Keep as a wish list |
| Programs | #139, #158, #174 | **closed 10 Oct** (superseded by the product order) |

**Recommendation:** close the three program issues. Comment on the seven largely-delivered ones with what landed
and close them, opening a narrow follow-up only where something concrete remains. Then label the rest by product
step, so the open list shows what is actually next.

## Proposed actions (need the owner's approval)

1. **Restore the lost fixes** (#80/#82, #81, #87) from `368d171`/`bb377dd` on a branch off `main`, with their tests.
   Small, and already reviewed once.
2. **Merge the clean stacks** (#227–#231, #235–#240, #245, #248, #258) as one integration PR, if the combined test
   run below passes. Hold #244 (balance), #247 and #269 (visual and performance review) and #253 (video weight).
3. **Rebase the employed opening** (#250, #251, #252, #255) onto `main` as one PR: product step 1.
4. **Rebase the road/loading access series** (#265–#276) after step 2, re-auditing the 99 logistics pairs.
5. **Close:**
   - duplicates #102 and #117;
   - programs #118, #139, #158, #174;
   - done #99;
   - and, once confirmed, #92 and #97.

   Each gets a comment saying where its content lives.

## Combined test run (step 2's candidate)

The code of #227–#231, #235–#245, #247, #248 and #258, replayed onto `main` (60 files, +1,896/−229): *result
pending; recorded below when the run finishes.*
