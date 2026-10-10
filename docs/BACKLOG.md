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
   and #87 as covered. **Fixed in #295 and corrected in #297.**
2. **The 31 open Codex PRs are one long chain**, not separate stacks. Each was branched from the tip of the previous
   one, linked by PRs that have since been closed or superseded (#246, #249, #256/#257, #273). GitHub shows
   36 conflicts into `main`, but replaying each PR's own code commits onto `main` gives a better picture: **16 PRs
   apply cleanly**, and only the employed-opening and road/loading stacks need real rebasing.
3. **The 90 open issues were never updated.** One issue has a comment. Several are done, two are duplicates, and the
   four "program" issues (#118, #139, #158, #174) are superseded by the owner's product order.

## Open pull requests

Updated 10 October after the integration. What landed and what remains:

| PR | What | Status |
|---|---|---|
| #294 | Integration of #227–#231, #235–#240, #245, #248, #258 | **Merged** (`fceffaa`); the fourteen source PRs are closed, their branches kept |
| #295 | Restores the autopilot intercept, payroll demand report and radar-aware routing | **Merged** (`ee7b091`) |
| #296 | The employed opening (rebased #250, #251, #252, #255) | **Merged** (`4d1e81e`); the four source PRs are closed. Step 1 of the product order |
| #293 | Direction docs, relay handoff, MCP server, this backlog | Open (Claude) |
| #244 | Live escorts kept, stale stakeouts cleared | **Held**: changes balance (#98); decide the AI knowledge policy first |
| #247 | Costa Brava settlements rebuilt in period architecture | **Held**: needs visual review and a performance capture (package C) |
| #269 | Period land vehicles with LODs | **Held**: visual review (package C) |
| #253 | Gameplay recordings, README and player docs | **Held**: don't add 30 MB of video to git (#91); keep the docs text, move the media to a release |
| #265, #267, #268, #270, #271, #272, #274, #275, #276 | Road and loading-access series (villa, FRM, setbacks, connectors, junction surfaces, node index, Moretti club, diagnostics) | **Needs real rebasing** (package A). #271 (district back-navigation) is a small UI fix: rebase it first |

Closed 10 October as superseded or merged: #227–#231, #235–#240, #245, #248, #258 (in #294), #250/#251/#252/#255 (into #296),
and the documentation PRs #241, #242, #243, #246, #249, #264, #273 (folded into `docs/`).

## Issues

### Bugs and concrete enhancements (#80–#100, #175)

| # | Title | Status | Recommendation |
|---|---|---|---|
| 80 | Autopilot circling at QRY/PNR | **partly**: intercept restored (#295) and corrected (#297), with kinematic tests | Fly QRY/PNR with the real flight model, then close |
| 81 | Crew auto-hiring and roles | **done** for the demand report (#295, #297: vacancy and surplus); hiring by `needs()` exists | Close; the rest belongs to product step 2 (automation) |
| 82 | Autopilot route selection and interception | **partly** (same patch as #80, restored in #295/#297) | Close with #80 after the flown check. The full planner/lock design in the issue is optional |
| 83 | Incoming calls | partly: Family offers ring the shared phone (#225) | Keep for other call sources; fold #125 and #132 into it |
| 84 | Physical payroll NPCs | partly: payroll bodies and checked travel exist; work isn't arrival-gated (deferred) | Keep; close #102 as its duplicate |
| 85 | Combat from physically present agents | not started | Keep: package A step 6, after movement migration |
| 86 | Pathfinding: terrain, checkpoints, blocked routes | partly: penalty hook, checked routes; #258/#270/#272 drafts | Keep: package A |
| 87 | Radar-aware hot routing | **done** (#295, #297): route-planner zones, wired into hot autopilot legs from public airfield radars only | Close |
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

## Actions taken on 10 October (owner-approved)

1. **Restored the lost fixes** (#80/#82, #81, #87): merged as #295. The radar zones are now wired into hot autopilot legs
   (`Session.known_radar_zones`), with tests. A flown QRY/PNR check is still to do before closing #80/#82.
2. **Integrated the clean stacks:** merged as #294 (full CI green); the fourteen source PRs are closed.
3. **Employed opening:** rebased and merged as #296 (`4d1e81e`); #250, #251, #252 and #255 closed.
   Also merged #297 (fixes to the three review findings on #295).
4. **Closed issues:** #92, #99, #102, #117, #118, #139, #158, #174. #97 stays open: `_join()`/`_seat()` need tests.

## Next

- Rebase the road and loading-access series (package A), #271 first; re-run `tools/logistics_routes.gd` for the 99-pair number.
- Decide #88 (the job board can send a load a strip can't fly out of) and the AI knowledge policy (#244, #98).
- Add `_join()` / `_seat()` entry-path tests (#97).
- Fly QRY/PNR with the autopilot to confirm #80/#82, then close them.
