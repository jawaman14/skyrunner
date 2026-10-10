# Empire and turf-war milestone

Approved direction, 7 October 2026: start as a pilot, build a network, then command
an organisation whose money, people and territory must be protected. The career
loop is earn, invest, expand, attract pressure, defend, recover and expand again.
Flying remains useful; delegation is a progression reward.

**Superseded in part (8 October 2026).** The owner's later answers are in
[DESIGN.md §0](DESIGN.md#0-where-the-game-is-heading-owner-approved-direction-8-october-2026) and win where they
disagree with this page. In particular, co-op *and* competitive play (2–16 players, organisation/rival/police)
are part of the intended first full experience, so competitive modes are no longer deferred; multiplayer racing
and the hidden informant remain separate proposals. The product order there (early rise, automation, faction
competition, multiplayer) is the current one; the delivery sequence below is the reliability work inside it.

## Delivery sequence

1. Verify existing draft heads, dependencies and CI. Squash completed slices in
   dependency order; retain drafts requiring human evidence. Record early-flight,
   first ground-war and later empire playtests separately from automated results.
2. Repair real loading/meeting/arrival connectors before migrating trucks, then
   squads, to checked routes. The previous 99-pair audit failed every checked route;
   this is endpoint evidence, not proof that every physical location is unusable.
   Reject before spending/dispatch; blocked journeys retain position and inventory.
   Preserve La Selva without a public road and one authoritative worker identity.
3. Extend HQ/station command with cash, outlying money, stock, crew, upkeep and
   four existing district cards. Show control direction/policy/collection, friendly
   presence and reported threats. Explain presence decay and squeeze consequences.
   Selected squads show strength, weapons, ammunition, morale, rank, order,
   destination, travel and cost. Explain existing AI/human ownership.
4. Add authoritative operational/battle debriefs: deliveries/losses, money,
   casualties/arrests, control/heat and recorded cover/range/surprise/retreat.
   Teach first management actions at existing unlocks; connect existing flights
   to organisational needs. Never invent causal certainty or enemy intentions.
5. Finish HAR/coastal road/Warehouse 7/harbour/services access and period art,
   then vehicles, clothing, working/parking/disembarking and event-driven effects
   and cleared audio. Preserve collision dimensions and vehicle performance.
6. After movement validation, migrate combat contact/casualties to living,
   present, non-arrested stable members. Preserve bounded deterministic authority,
   morale/court/economy reactions and legacy parity paths. Measure before tuning.
7. Playtest delegation, expansion/consolidation and defeat/recovery. Classify
   piloting/strategic losses separately from unclear information, repetition,
   access problems and opaque automation. Balance stand-ins do not measure fun.

## Compatibility and verification

Keep Session.command's [ok, message] contract, read-only previews and execution
validation, additive filtered snapshots, safe older-peer defaults and old saves.
Acknowledgement is distinct from refreshed state. Unknown results are not retried.
Audit exact fight/hidden-unit intelligence before richer displays; coarse public
news is distinct from exact observation. New history cannot recreate old events.

Each slice is a separate codex branch/reviewable PR with focused tests; integration
requires full shards, smoke, save/parity, hygiene, export filters and platform CI.
Exercise input, long/empty lists, cancellation, stale state, late replies,
disconnect/handoff, blocked travel, body/inventory lifecycle and save/load.
Check both palettes at 1024x768, 1280x720, 1920x1080 and 2560x1080, all presets/LODs.
Measure moving reference routes and dense combat; investigate frame-time/memory
regressions above 10%. Record paired-seed movement/combat effects separately.

Release needs a human exported Windows walkthrough, physical controller/audible
read-aloud, real two-machine seat/action/voice and redistribution rights clearance.
Record unperformed checks explicitly; do not label simulation runs human evidence.

Costa Brava, four tutorials and twelve story chapters remain. Defer new aircraft,
chapters, smaller capture districts, arrival-gated payroll, adaptive difficulty,
relationships, hidden-informant multiplayer, multiplayer racing and major new
combat systems. Ordinary houses remain scenery. Preserve unrelated desktop edits.

## First implementation evidence

Ground snapshots previously serialized all exact fights despite filtering squads.
The first slice requires both participants to be currently observed; unobserved
coordinates, IDs and casualty counters are withheld. Aggregate control remains
the existing public strategic picture, not a claim of exact current deployment.
Two regression tests cover distant, partially observed, observed and lost contact.
No simulation or balance calculations change. Coarse news is retained.
