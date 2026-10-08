# Test execution lanes — 8 October 2026

CI now runs a small headless logic lane, three simulation shards, a presentation lane and a socket/integration lane on every pull request. All lanes remain merge gates; exports, dedicated-server validation and platform smoke remain unchanged. Existing three simulation check names remain stable.

`TEST_LANE=logic|simulation|presentation|socket` selects a partition before the existing SHARD=i/n subdivision. With no lane, the full suite retains its original sorted order and coverage. The checked-in tests/test_lanes.json manifest classifies existing files; new files default to simulation, so an omitted manifest entry cannot hide a test. Contract tests reject duplicate assignments, stale file names and unknown lanes. An invalid requested lane fails before execution.

The initial manifest contains 6 logic, 55 simulation, 51 presentation and 14 socket files. The new lane-contract file defaults to simulation. The classification groups UI/render concerns as presentation, actual network dependencies as socket, and Session/world-dependent tests as simulation. Update explicit assignments when a new test should run in another lane.

The same pinned Godot binary is cached by OS, architecture and exact version. Mutable imports/simulation state are not cached across tests. The harness records duration and outcome per file and a final lane total, supporting measured follow-up optimisation. It now treats failed imports and import/runtime parse errors as blockers. Known Godot shutdown resource diagnostics remain distinguishable from functional errors.

Desktop evidence: logic lane 41 passed, zero failed in 9.8 seconds; lane-contract tests two passed, zero failed. Socket/presentation and full CI validation remain pending. YAML parsed successfully with six explicit test matrix entries. Compared with the recorded 799.7-second overhaul regression, this provides prompt feedback for the small pure-logic group while retaining complete required coverage.

No shared mutable Session fixture was introduced. Many apparent read-only checks instantiate systems with event subscriptions, global parity settings or teardown-sensitive resources. A safe fixture reuse requires per-file timing and lifecycle review; #101 remains open for that measured follow-up and current-head acceptance. This change is execution organisation, not a gameplay or balance change.
