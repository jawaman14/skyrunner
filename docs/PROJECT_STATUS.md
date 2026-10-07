# Project status

This file is the single status reference. Update it when a release or verified
baseline changes; historical counts belong in `docs/ROADMAP_HISTORY_2026-10.md`.
It separates implemented work from evidence so a feature is not advertised as
human-tested merely because source code exists.

Source audit: 7 October 2026. This is a maintained evidence record, not generated test output.

| Field | Current value | Evidence / limit |
|---|---|---|
| Version | 0.9.0-beta.1 | `README.md`, release metadata |
| Engine | Godot 4.7.2, GDScript, Jolt | project configuration |
| Test files | 123 `tests/test_*.gd` files, excluding `test_case.gd` | source count on 7 October; run `./tools/test.sh` for test results |
| Verified automated baseline | 985 passed, 0 failed across three desktop shards (315 / 337 / 333) | 7 October review and PR #222; no script/parse errors; lambda/resource cleanup diagnostics remain |
| Tutorial | Four Costa Brava flying chapters | `docs/DESIGN.md`; preserved |
| Story | Twelve Costa Brava chapters | `README.md`/`docs/DESIGN.md`; preserved |
| Player map | Costa Brava | Classic geometry remains internal regression only; generated maps are optional |
| Desktop targets | Linux, Windows and macOS exported and smoke-launched in CI | PR #223 CI run 37568034562; human exported-build walkthroughs remain pending |
| Multiplayer | protocol and remote preview/ack paths implemented | real two-machine seat, action and voice session remains unperformed |
| Human verification | controller, read-aloud, four-resolution visual walkthrough and exported Windows walkthrough pending | record evidence before release claims |
| Asset rights | used third-party notices included; bundled radio redistribution rights unresolved | `docs/ASSET_PROVENANCE.md` and issue #175 |

## Feature state

### Post-merge review, 7 October 2026

The overhaul stack (#119 and #178–#209) and replacement PRs #216–#222 are
merged. PR #219 restored source and test files missing from the initial
integration. PR #220 updated the mechanic regression for explicit action review.
Focused evidence on the repaired tree: payroll 21 passed, airframe 11 passed.
Luna's interrupted full runs did not establish a pass. Review reproduced two
failing tests on the earlier integrated tree (983 passed, 2 failed); PR #222
fixes map Enter routing and updates fixer confirmation coverage. The corrected
three-shard run passed all 985 tests. CI for #222 passed exports, dedicated-server
checks and Linux/Windows smoke. PR #223's complete CI run
[37568034562](https://github.com/jawaman14/skyrunner/actions/runs/37568034562)
also passed every shard and all three desktop smoke jobs. Final merged-tree
checks passed: save 32, switches/parity/randomness 4, export filters 2,
repository hygiene and the 1,800-frame AI smoke.

At the review baseline, `PhoneCalls` was a standalone queue used only by its unit tests.
The incoming-call integration slice now connects Family offers to Session,
save/restore, permitted runner snapshots and the shared cockpit/on-foot phone.
Answer/decline commands revalidate expiry and offer availability. Answering
opens the existing dialogue without accepting the offer. Source IDs suppress
recreated calls after save/load; missed/declined history is visible. Other event
sources and real remote/hardware evidence remain outside this first slice.
PR #223 adds a verified macOS bundle/launch
job and satisfies issue #176's CI gate. RoutePlanner still lacks the known-radar
cost layer required by #87; broader crew-demand criteria in #81 remain pending.
The earlier PR #218 summary is
not evidence that these gameplay and platform integrations are finished.

No open PRs remained at the start of this review. Open issues still require
individual acceptance checks; merging the overhaul does not close them.

Implemented and automated-verified: dialogue acknowledgement/navigation and
commitment reviews; shared action previews; menu focus and modal input; station
outcomes, map layers and role-filtered feed; site records/overlay; interaction
occlusion; checked road geometry/bridges; stash interiors; period props; bulk
logistics and armoury previews; payroll checked travel and in-transit state.

Implemented but requiring further evidence: complete entrance/threshold/loading
walkthrough, terrain-specific remote access, remaining hangar/HQ/casino states,
full NPC truck/squad migration, Costa Brava coastal art reference area,
performance route captures, exported builds, physical controllers, read-aloud,
human macOS walkthrough, two-machine multiplayer/voice and radio rights decision.

Deferred until the overhaul gates pass: new chapters, hidden informant gameplay,
arrival-gated payroll, new combat mechanics, UDP prediction, multiplayer racing,
additional aircraft and cloud deployment.

## Updating

The dated [post-integration verification report](VALIDATION_2026-10-07.md)
records performed and unperformed checks, known diagnostics and review findings.

Use `tools/test.sh` for a full sharded run and record its three shard totals in
this file and the dated roadmap history. Focused PR evidence belongs in the PR
body and roadmap. Do not replace a verified count with a source estimate.
