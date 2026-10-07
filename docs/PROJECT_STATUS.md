# Project status

This file is the single status reference. Update it when a release or verified
baseline changes; historical counts belong in `docs/ROADMAP_HISTORY_2026-10.md`.
It separates implemented work from evidence so a feature is not advertised as
human-tested merely because source code exists.

Generated snapshot: 7 October 2026

| Field | Current value | Evidence / limit |
|---|---|---|
| Version | 0.9.0-beta.1 | `README.md`, release metadata |
| Engine | Godot 4.7.2, GDScript, Jolt | project configuration |
| Test files | 100+ `tests/test_*.gd` files | count from repository; run `./tools/test.sh` for the current result |
| Verified automated baseline | 948 tests through PR #197; later slices have focused evidence | PR #197 and subsequent PR bodies; resource shutdown diagnostics remain |
| Tutorial | Four Costa Brava flying chapters | `docs/DESIGN.md`; preserved |
| Story | Twelve Costa Brava chapters | `README.md`/`docs/DESIGN.md`; preserved |
| Player map | Costa Brava | Classic geometry remains internal regression only; generated maps are optional |
| Desktop targets | Linux, Windows and macOS export presets | export configuration; exported Windows walkthrough and macOS launch evidence remain pending |
| Multiplayer | protocol and remote preview/ack paths implemented | real two-machine seat, action and voice session remains unperformed |
| Human verification | controller, read-aloud, four-resolution visual walkthrough and exported Windows walkthrough pending | record evidence before release claims |
| Asset rights | used third-party notices included; bundled radio redistribution rights unresolved | `docs/ASSET_PROVENANCE.md` and issue #175 |

## Feature state

Implemented and automated-verified: dialogue acknowledgement/navigation and
commitment reviews; shared action previews; menu focus and modal input; station
outcomes, map layers and role-filtered feed; site records/overlay; interaction
occlusion; checked road geometry/bridges; stash interiors; period props; bulk
logistics and armoury previews; payroll checked travel and in-transit state.

Implemented but requiring further evidence: complete entrance/threshold/loading
walkthrough, terrain-specific remote access, remaining hangar/HQ/casino states,
full NPC truck/squad migration, Costa Brava coastal art reference area,
performance route captures, exported builds, physical controllers, read-aloud,
macOS launch, two-machine multiplayer/voice and radio rights decision.

Deferred until the overhaul gates pass: new chapters, hidden informant gameplay,
arrival-gated payroll, new combat mechanics, UDP prediction, multiplayer racing,
additional aircraft and cloud deployment.

## Updating

Use `tools/test.sh` for a full sharded run and record its three shard totals in
this file and the dated roadmap history. Focused PR evidence belongs in the PR
body and roadmap. Do not replace a verified count with a source estimate.
