# Project status

This file is the single status reference. Update it when a release or verified
baseline changes; historical counts belong in `docs/ROADMAP_HISTORY_2026-10.md`.
It separates implemented work from evidence so a feature is not advertised as
human-tested merely because source code exists.

Source audit: 9 October 2026. The source inventory is generated; validation and release evidence are maintained separately.

<!-- BEGIN GENERATED PROJECT STATUS -->
## Generated source inventory

This section describes **this checkout**. Run `godot --headless --script res://tools/project_status.gd -- --write` after source changes. CI checks it after import. Passing test runs, shipped builds and human verification are separate evidence below.

| Field | Source value | Meaning / source |
|---|---|---|
| Version | 0.9.0-beta.1 | project.godot |
| Declared automated tests | 1078 methods in 136 test files | Compiled source inventory; this is not a test result |
| Flying tutorial | 4 Costa Brava chapters | Campaign.CHAPTERS |
| Main story | 12 chapters | Story.CHAPTERS; distinct from the tutorial |
| Configured exports | Linux, Windows, macOS | Export presets; build/manual acceptance is recorded below |
| Multiplayer protocol | 3 | Implemented wire version; real two-machine verification remains pending |

<!-- END GENERATED PROJECT STATUS -->

| Field | Current value | Evidence / limit |
|---|---|---|
| Engine | Godot 4.7.2, GDScript, Jolt | project configuration |
| Latest merged-main desktop run | 1,027 passed, 0 failed across three serial shards | Main `c7b8763`; 314 / 357 / 356 passed in 254.6 / 163.0 / 313.1 seconds; no script/parse failures; known shutdown cleanup diagnostics remain |
| Overhaul branch evidence | 1,076 passed, 0 failed at `8c08b41` in 799.7 seconds | #283 historical stack, including unmerged world work; no script/parse failures; not a main or human acceptance claim |
| Player map | Costa Brava | Classic geometry remains internal regression only; generated maps are optional |
| Desktop targets | Linux, Windows and macOS exported and smoke-launched in CI | PR #223 CI run 37568034562; human exported-build walkthroughs remain pending |
| Multiplayer | protocol and remote preview/ack paths implemented | real two-machine seat, action and voice session remains unperformed |
| Human verification | controller, read-aloud, four-resolution visual walkthrough and exported Windows walkthrough pending | record evidence before release claims |
| Asset rights | used third-party notices included; bundled radio redistribution rights unresolved | `docs/ASSET_PROVENANCE.md` and issue #175 |

## Faction-AI diagnostic evidence

The [forty-seed isolation study](FACTION_AI_ISOLATION_2026-10-09.md) records 160 runs across baseline, escort-only, stakeout-only and combined variants. Stakeout cleanup increases mean arrests and burned stashes. Escort neutrality is limited to a stand-in without cargo trucks. PR #244 and issue #98 remain open; this record changes no gameplay or tuning.

## Feature state

### Issue-audit integration, 8 October 2026

[#280](https://github.com/jawaman14/skyrunner/pull/280) restores exact prior parity state and hardens the seeded-generator scanner; [#281](https://github.com/jawaman14/skyrunner/pull/281) adds vegetation preset/determinism coverage. [#282](https://github.com/jawaman14/skyrunner/pull/282) deduplicates host/client voice setup and fixes waiting-room beacon lifetime. [#284](https://github.com/jawaman14/skyrunner/pull/284) moves all 105 command handlers into six stateless modules without changing their bodies or Session authority. Each was squash-merged after all eight current-head CI jobs passed. CI lane separation [#286](https://github.com/jawaman14/skyrunner/pull/286) and shared seat screen [#285](https://github.com/jawaman14/skyrunner/pull/285) are also squash-merged, each after all eleven current-head jobs passed. This dated batch reached `549ec05`; later integrations and desktop evidence are recorded below. Issues #93 and #95 are completed; broader startup and physical/hardware gates remain open. Taxi coverage and the complete #94 action matrix are squash-merged through [#288](https://github.com/jawaman14/skyrunner/pull/288), after all eleven current-head checks passed.

The older dated evidence below is historical; it does not override the generated checkout inventory or upgrade source checks into human acceptance.

### Follow-up integration, 9 October 2026

Own-worker map presentation [#289](https://github.com/jawaman14/skyrunner/pull/289) and occupied-port host cleanup [#290](https://github.com/jawaman14/skyrunner/pull/290) are squash-merged through `a3f66fb`, each after eleven exact-head CI jobs passed. The protected desktop checkout remains unchanged. The worker port passed permission/layer checks (2), people regressions (11) and network checks (16). Startup reproduction failed before the fix and passed afterward (1), with host-service checks (4). Read-only fixture audit [#291](https://github.com/jawaman14/skyrunner/pull/291) is squash-merged as `aae28fa` after eleven exact-head checks; its contract (1) and existing parity checks (16) pass. Generated status [#287](https://github.com/jawaman14/skyrunner/pull/287) is squash-merged as `c7b8763` after eleven exact-head checks. Issues #94, #96, #101 and #177 are completed on automated acceptance; broader #97 entry paths and human release gates remain open.

Desktop post-integration run: **1,026 passed, zero failed in 863.3 seconds** at `28e66cb`, with an identical tracked tree to main `a3f66fb`. Final status/fixture candidate: **1,027 passed, zero failed in 909.3 seconds** at `6c7f3ef` (identical tracked tree after retargeting at `9faac70`). The latter includes all game/test files now on main `aae28fa` plus the status generator and documentation. Subsequent evidence edits change documentation only. Focused final checks pass: save/load 33, determinism 5, export filters 2; isolated Costa Brava desktop smoke prints `SMOKE OK`; hygiene and generated-status consistency pass. No script/parse errors occur. ObjectDB/resource/PagedAllocator shutdown diagnostics remain separate from functional results. Runs overlap independent balance measurements, so these durations are not gameplay frame-time benchmarks.

Merged-main confirmation at `c7b8763`: **1,027 passed, zero failed** (314 / 357 / 356), three serial shards in 254.6 / 163.0 / 313.1 seconds. All processes exit zero with no script/parse failures; known shutdown resource diagnostics remain. The diagnostic/evidence follow-up changes no game or test source.

Performed: automated desktop input/state/layout, full regression, save/load, parity/determinism, export filters, hygiene and isolated smoke. Linux/Windows/macOS exports and smoke pass in each completed PR's CI. Unperformed: human exported Windows walkthrough, physical controller/read-aloud/visual acceptance, two-machine seat/action/voice session, functional-site walk/drive acceptance and moving/dense-scene performance capture. Local Windows packaging remains unverified without matching export templates. Radio redistribution rights remain unresolved; no automated result clears those gates.

### Reliability integration, 8 October 2026

[#254](https://github.com/jawaman14/skyrunner/pull/254) records the open-PR audit.
[#259](https://github.com/jawaman14/skyrunner/pull/259) and
[#260](https://github.com/jawaman14/skyrunner/pull/260) integrate bounded framing,
command deduplication, stale-input neutralization and seat-generation checks.
[#261](https://github.com/jawaman14/skyrunner/pull/261),
[#262](https://github.com/jawaman14/skyrunner/pull/262) and
[#263](https://github.com/jawaman14/skyrunner/pull/263) integrate debris expiry,
race feedback/selection and fight privacy. Each is squash-merged separately;
superseded originals are closed with replacement links. The exact post-merge
tree passes 1,002 tests, isolated desktop smoke and hygiene. See the
[integration/disposition record](PR_INTEGRATION_2026-10-08.md) for evidence and
remaining drafts. Main's eight CI jobs pass, including exports and all three
desktop smoke jobs. Final focused checks pass: save 33, parity 14 and export
filters two. The save process returned a nonzero native cleanup exit after its
tests passed; no script/parse/test failures occurred. Human and rights gates
remain open.

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
[#225](https://github.com/jawaman14/skyrunner/pull/225) is squash-merged. Its
[CI run](https://github.com/jawaman14/skyrunner/actions/runs/37569523063)
passed every test shard, dedicated-server checks, exports and Linux/Windows/macOS
smoke jobs. Desktop save checks passed 33 tests and the 1,800-frame smoke reported
`SMOKE OK`. The merged game/test tree matches the tested feature head.

The read-only Costa Brava logistics route audit enumerates 99 directed pairs
using current dispatch endpoints. All fail checked vehicle access: 62 obstructed
access legs and 37 without nearby checked access. These are nominal simulation
endpoints, not proof that physical loading areas are unusable. Fix and validate
loading/meet connectors before switching dispatch to checked routes; replacing
the router alone would block this entire audited set. See
`tools/logistics_routes.gd` and `docs/LOGISTICS_ROUTE_BASELINE.md`.
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
