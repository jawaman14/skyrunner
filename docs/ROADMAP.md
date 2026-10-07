# Roadmap

Current continuation queue, approved 7 October 2026. Each slice is a separate
feature branch and draft PR. Historical progress is preserved in
[ROADMAP_HISTORY_2026-10.md](ROADMAP_HISTORY_2026-10.md); the source-backed
findings and reproduction checks are in [UI_WORLD_REVIEW.md](UI_WORLD_REVIEW.md).

## Baseline and completed work

The four-chapter Palmetto Cay tutorial and twelve-chapter Costa Brava story stay.
Save expansion, the six-layer Session split, role support, switch registry and
strategic calibration are implemented; do not restart them from older reviews.

The current draft stack is #178 (menu/HUD foundation), #179 (job previews),
#180 (read-only fuel previews and feedback), #181 (airfield props), #182 (fuel
cache props), #183 (interface/world audit). Integrate in dependency order after
validation; do not merge automatically. #119 (patterns/Asset Bible) is independent.
The integrated art baseline passed 909 tests. Exported Windows human walkthrough
and real two-machine remote/voice validation remain unperformed.

## Ordered implementation queue

1. **Baseline consolidation:** verify the draft stack against main and exports;
   reconcile documentation. Preserve historical reviews and desktop changes.
2. **Dialogue:** wait for sequence-correlated host results; scroll/wrap choices;
   support keyboard/controller selection beyond nine; block repeated activation;
   show actual failures in every command-bearing conversation.
3. **Contextual actions:** extend read-only Session descriptors to purchases,
   sales, transfers, repairs, prisoners and disbanding; add remote previews;
   revalidate execution and default destructive confirmations to Cancel.
4. **Menus/settings:** finish focus, selection, scrolling, persistent feedback,
   disabled reasons and palette refresh across all menus. Hangar/dealer first,
   logistics/rackets next, then remaining screens.
5. **Stations/maps/feed:** organize fifteen seats by task; selected-entity cards,
   acknowledged orders, grouped map layers and a shared role-filtered event feed.
6. **Placement/access:** deterministic footprints, entrances, walk/loading
   approaches and network connectors; diagnostic overlay and interaction occlusion.
7. **Roads/bridges:** shared physical/rendered surface, checked routes and safe
   connectors. Preserve La Selva without a public road; no incidental map rebake.
8. **Interiors:** fix existing hangars/HQs/casino; make all eight stash types
   enterable with existing logistics access, real availability and clear exits.
9. **NPCs:** checked pedestrian/vehicle access, identity/task presentation and
   body lifecycle. Payroll/combat remain authoritative; no arrival-gated work.
   Migrate truck/squad connectors separately with paired-seed measurements.
10. **Period art:** validate one existing coastal reference area, then reuse
    architecture, infrastructure, workshop props, vehicles and analogue cockpits.
    Weathered 1979-1982 world; neon concentrated in nightlife and interface accents.

## Completion gates

- Real input, long/empty/stale content and pending/refused/unknown remote outcomes.
- Both palettes; 1024x768, 1280x720, 1920x1080, 2560x1080; visible focus/read-aloud.
- Walk/drive bridges and every functional entrance; check wall occlusion/thresholds.
- City, classic and representative generated maps; preserve runway clearance.
- Worker assignment, arrival, jail/death, save/load and human/AI handoff.
- Focused and full sharded tests, parity/goldens, export filters and build smoke.
- Fixed-route frame-time/memory comparisons; investigate regressions above 10%.
- Paired-seed balance measurements for travel changes; no arbitrary retuning.
- Exported Windows walkthrough and real two-machine seat/action/voice session.

## Deferred

New campaign chapters, hidden-informant gameplay, arrival-gated payroll, new
combat mechanics, UDP prediction, multiplayer racing, additional aircraft and
cloud deployment follow this overhaul. Ordinary city houses remain scenery.
