# Post-integration verification, 7 October 2026

## Source review and corrections

Review found that the earlier full runs were interrupted before reporting a
result. The completed review run exposed the fixer action-review regression
and Enter leaking from a focused map layer switch into a job transaction.
PR #222 fixes input routing and explicitly verifies confirmation without
premature mutation. PR #221 restores the missing status document and references.

The incoming-call queue remains a standalone module, referenced only by its
tests. Issue #83 is incomplete. RoutePlanner still lacks the known-radar cost
layer required by #87. Broader crew-demand acceptance in #81 is still pending.
These findings are recorded on PR #218; its merge summary is not completion evidence.

## Automated desktop evidence

Godot 4.7.2 on the owner's Windows desktop, managed worktree. The original
desktop checkout's separate edits were preserved.

| Check | Result |
|---|---|
| Full corrected suite, shard 1 | 315 passed, 0 failed; 330.4 seconds |
| Full corrected suite, shard 2 | 337 passed, 0 failed; 201.6 seconds |
| Full corrected suite, shard 3 | 333 passed, 0 failed; 286.0 seconds |
| Full suite total | **985 passed, 0 failed; no script or parse errors** |
| Fixer preview/confirmation | 6 passed, 0 failed |
| Native map keyboard/layer controls | 4 passed, 0 failed |
| Final save checks | 32 passed, 0 failed |
| Switch registry, parity switch restoration and randomness/clock scan | 4 passed, 0 failed |
| Export filters | 2 passed, 0 failed |
| Repository hygiene | `hygiene OK` |
| AI smoke, 1,800 frames | `SMOKE OK 0.9.0-beta.1 t=12.7s phase=parked money=9847` |

The merged main game scripts, tests and dialogue were compared with the
verified #222 tree and matched. Later documentation and CI-only changes do
not alter that game tree. Godot lambda-capture, ObjectDB/resource and allocator
cleanup diagnostics persist; they are recorded separately from assertion and
script/parse results and have not been fixed by this review.

## Export and platform evidence

[PR #222 CI](https://github.com/jawaman14/skyrunner/actions/runs/37567440333)
passed all three test shards, dedicated-server checks, exports, Linux rendered
and headless smoke, and Windows headless smoke.

[PR #223 CI](https://github.com/jawaman14/skyrunner/actions/runs/37568034562)
adds actual macOS exported-app validation. Its macOS runner successfully
unpacked the artifact, validated the app plist/executable/resources and
development-directory exclusions, and launched the exported app:
`SMOKE OK 0.9.0-beta.1 t=15.3s phase=parked money=9846`.
No script or parse errors were present. The complete run passed all three
regression shards, dedicated-server checks, exports and Linux/Windows/macOS
smoke checks. PR #223 is merged; issue #176's CI launch-validation gate is met.

## Unperformed checks and remaining gates

- Human exported Windows/macOS walkthroughs and first-session playtests.
- Physical controller, read-aloud and human visual checks at all supported sizes.
- Real two-machine multiplayer, seat handoff, remote actions and microphone/voice.
- Full entrance/desk/loading-area and bridge walking/driving walkthroughs.
- Fixed-route performance and memory captures, dense NPC/LOD inspection.
- Paired-seed balance measurements for further travel/hiring changes.
- Radio redistribution rights and final public-release licence audit (#175).
- Local Windows packaging with matching export templates; CI export evidence
  does not replace that local or human check.

Do not close hardware, rights, balance or incomplete-feature issues based solely
on these automated results. Costa Brava remains the player-facing development
map; four tutorial and twelve story chapters remain preserved.
