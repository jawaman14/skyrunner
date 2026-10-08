# Roadmap

Current continuation queue — 8 October 2026. The owner-approved direction is
an employed pilot building an interconnected empire, then commanding people,
business and territory. See [PLAYER_DIRECTION.md](PLAYER_DIRECTION.md) and
[PLAYER_DIRECTION_DELIVERY.md](PLAYER_DIRECTION_DELIVERY.md).

## Verified baseline and implemented scopes

Main has 1,002 passing desktop tests following #259–#263 and the #266 integration
record. The unmerged period-vehicle stack has 1,059 passing tests. These are
separate trees; neither establishes human release acceptance. See
[PROJECT_STATUS.md](PROJECT_STATUS.md) and the
[draft completion review](DRAFT_COMPLETION_REVIEW_2026-10-08.md).

Already implemented: the original interface/world overhaul; campaign outcome,
guidance and dialogue corrections; loading-endpoint lookup; shared squad and
district cards; observed-only targeting/fights; bounded own-unit battle reports;
escort/stakeout and battle-removal fixes; the employed opening and first-aircraft
milestone; controls tabs; the villa/FRM approaches and functional-building setbacks;
workshop/coastal props and period land-vehicle silhouettes. Verify/integrate these
scopes rather than scheduling their implementation again.

Review follow-ups: [#270](https://github.com/jawaman14/skyrunner/pull/270) checks
alternate connected access; [#271](https://github.com/jawaman14/skyrunner/pull/271)
fixes district return/held-key seat toggles; [#272](https://github.com/jawaman14/skyrunner/pull/272)
indexes graph construction with exact node/edge parity. Six documentation PRs
(#241–#243, #246, #249, #264) are ready for review as plans/audits, not completed
feature packages. Their future implementations remain below.

## Remaining work in dependency order

1. **Accept and integrate existing slices.** Keep narrow dependencies; the first
   asset branch is updated to current main. Use a squash commit per completed,
   tested PR. Do not merge evidence-dependent drafts solely for green CI. The
   historical code chain and remaining per-PR gates are in the completion review.
2. **Physical Costa Brava access.** Current loading audit: 21/99 reachable,
   78 blocked. Author the missing Family meeting area and targeted road/grade
   corrections; validate the whole road width, entrances, thresholds, loading
   areas and bridge approaches. Preserve La Selva/offshore remoteness. Do not
   increase access limits or restore straight-line routing to conceal failures.
3. **Measured travel migration.** Move trucks and squads separately after physical
   approaches work. Reject unreachable orders before goods/money leave; preserve
   last valid travel state, blocked reasons, saves and human/AI handoff. Keep the
   existing penalty hook and measure paired seeds without compensation tuning.
4. **Empire decisions and feedback.** Build the owner-only overview, durable order
   lifecycle, recorded operational debriefs and richer own-unit custody/tactical
   accounts proposed in #242. Reuse existing cards/previews/feed; preserve hidden
   intelligence, command authority and older-peer behavior. Explain delegation,
   wages, stock and recovery at existing unlocks before adding mechanics.
5. **Complete the coastal art reference.** Finish the usable HAR–Warehouse 7–harbour
   corridor, then crew/vehicle loading and parking, authoritative condition visuals,
   existing-aircraft analogue cockpits and event-driven effects/cleared audio.
   Reuse period assets/materials and LODs; record actual use/provenance and moving
   gameplay/dense-combat frame time and memory. Current vehicle bodies do not add
   damage or crew animation. See [ASSET_COVERAGE.md](ASSET_COVERAGE.md).
6. **Balance and human playability.** Wider isolated paired-seed evidence is still
   required for the earlier AI/map outcome changes. Record early pilot, first war
   and empire sessions; distinguish strategic mistakes from instructions, access,
   repetitive travel and opaque automation before changing payouts or hazards.
7. **Release gates.** Human exported Windows walkthrough, physical controller,
   audible read-aloud, both palettes/four supported resolutions and a real
   two-machine action/seat/voice session remain unperformed. Radio redistribution
   rights (#175) remain unresolved. Automated CI exports/smoke supplement these.

Costa Brava is the player focus; generated maps are optional and classic geometry
is internal regression only. Preserve four tutorial/twelve story chapters, aircraft
performance, payroll/combat authority, save compatibility and parity fixtures.
Physical-member combat (#85), new aircraft/chapters, multiplayer racing, prediction,
hidden-informant play and cloud deployment stay deferred until their prerequisites
pass. Planning quantities are not instructions to import unused assets.

Historical queues and verified counts are preserved in
[ROADMAP_HISTORY_2026-10.md](ROADMAP_HISTORY_2026-10.md); do not treat dated reviews
or screenshots as current physical/human evidence.
