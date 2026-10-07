# Roadmap

Current continuation queue, approved 7 October 2026. Each slice is a separate
feature branch and draft PR. Historical progress is preserved in
[ROADMAP_HISTORY_2026-10.md](ROADMAP_HISTORY_2026-10.md); the source-backed
findings and reproduction checks are in [UI_WORLD_REVIEW.md](UI_WORLD_REVIEW.md).

## Baseline and completed work

The four-chapter Costa Brava flying tutorial and twelve-chapter Costa Brava story stay.
Save expansion, the six-layer Session split, role support, switch registry and
strategic calibration are implemented; do not restart them from older reviews.

The current draft stack is #178 (menu/HUD foundation), #179 (job previews),
#180 (read-only fuel previews and feedback), #181 (airfield props), #182 (fuel
cache props), #183 (interface/world audit). Integrate in dependency order after
validation; do not merge automatically. #119 (patterns/Asset Bible) is independent.
[Baseline reconciliation #184](https://github.com/jawaman14/skyrunner/pull/184),
[Costa Brava map focus #185](https://github.com/jawaman14/skyrunner/pull/185), and
[dialogue reliability/navigation #186](https://github.com/jawaman14/skyrunner/pull/186)
are prepared as draft continuations of that stack.
[Dialogue input hardening #187](https://github.com/jawaman14/skyrunner/pull/187) and
[shared action previews #188](https://github.com/jawaman14/skyrunner/pull/188)
continue in that order. The integrated source baseline passed
937 tests across three shards (321 / 308 / 308, zero failures and no script errors).
Existing Godot shutdown resource diagnostics persist. The earlier #186 CI run
[37487390571](https://github.com/jawaman14/skyrunner/actions/runs/37487390571)
passed shards, dedicated-server checks, exports and Linux/Windows smoke tests;
that export evidence does not validate the later commits. Exported Windows human walkthrough
and real two-machine remote/voice validation remain unperformed.

## Ordered implementation queue

1. **Baseline consolidation:** reconciliation is prepared in #184; complete
   export and human release evidence before integrating the stack.
2. **Dialogue:** implementation is prepared in #186 with correlated results,
   refreshed-state gating, scrolling/wrapped choices, navigation and failure text.
   Synthetic mouse/controller events, long choices and layout bounds pass in both
   palettes at all four supported sizes, including palette changes while open.
   Actual scene removal/replacement and duplicate pending clicks are covered.
   Complete physical-controller, read-aloud and visual display walkthroughs at
   supported resolutions, plus two-machine delayed-result validation.
3. **Contextual actions:** general read-only descriptions and optional remote
   preview requests are implemented for aircraft/gear/vehicle purchases, vehicle
   and product sales, single cash/goods truck transfers, repairs, prisoner policy/
   bulk actions and squad disbanding. Command execution rechecks current state.
   Hangar/dealer reviews use the shared Cancel-first confirmation. Finish preview
   UI adoption across remaining menus, multi-stop/armoury transfers, dialogue
   commitment review and station clients; unsupported previews stay explicit.
4. **Menus/settings:** finish focus, selection, scrolling, persistent feedback,
   disabled reasons and palette refresh across all menus. Hangar/dealer first,
   logistics/rackets next, then remaining screens. The shared shell now focuses
   task controls, handles real table/controller navigation, restores invoking
   focus, and refreshes open palettes. Dealer/hangar/collector selection follows
   stable IDs; collector commitments use Cancel-first reviews. Hint controls,
   load/pack/controls/HQ/logistics buttons are focusable. Logistics has scrolling,
   a visible exit and retained site choices. Remaining preview adoption and
   remote outcome presentation are still queued.
5. **Stations/maps/feed:** organize fifteen seats by task; selected-entity cards,
   acknowledged orders, grouped map layers and a shared role-filtered event feed.
   Shared persistent sequence outcomes now distinguish acknowledgement from a
   refreshed snapshot, suppress duplicate pending orders and retain unknown
   results without retrying. Station logistics uses this path; selection follows
   IDs and cards consume filtered snapshots. A text-only ordered/deduplicated
   EventBus/Chronicle feed retains source, age and report uncertainty, with
   severity-based expiry. Remote preview adoption and map layer controls remain.
6. **Placement/access:** deterministic footprints, entrances, walk/loading
   approaches and network connectors; diagnostic overlay and interaction occlusion.
   Through-wall interaction is reproduced with actual overlapping physics areas
   and a solid wall. Selection and activation now require an unobstructed ray;
   all eighteen walker tests pass, including existing desks/job boards. Shared
   placement records, developer overlay and all-entrance walkthrough remain.
7. **Roads/bridges:** shared physical/rendered surface, checked routes and safe
   connectors. Preserve La Selva without a public road; no incidental map rebake.
   Road ribbons now share vertices with deck collision and indexed ground-vehicle
   height queries. Checked routes return explicit failure, skip speculative T
   links and retain the route-penalty hook; the legacy simulation route API stays
   unchanged pending measured migration. Synthetic deck/water physics, road and
   car tests pass. Site connectors, real bridge approaches and bidirectional
   exported walking/driving still require validation.
8. **Interiors:** fix existing hangars/HQs/casino; make all eight stash types
   enterable with existing logistics access, real availability and clear exits.
9. **NPCs:** checked pedestrian/vehicle access, identity/task presentation and
   body lifecycle. Payroll/combat remain authoritative; no arrival-gated work.
   Migrate truck/squad connectors separately with paired-seed measurements.
10. **Period art:** validate one existing coastal reference area, then reuse
    architecture, infrastructure, workshop props, vehicles and analogue cockpits.
    Weathered 1979-1982 world; neon concentrated in nightlife and interface accents.
    Maintain [ASSET_PROVENANCE.md](ASSET_PROVENANCE.md) with actual runtime usage.

## Completion gates

- Real input, long/empty/stale content and pending/refused/unknown remote outcomes.
- Both palettes; 1024x768, 1280x720, 1920x1080, 2560x1080; visible focus/read-aloud.
- Walk/drive bridges and every functional entrance; check wall occlusion/thresholds.
- Costa Brava and representative generated maps; preserve runway clearance.
- The classic island is retired from player entry points. Reject classic saves
  without rewriting them; retain geography only for frozen parity/balance tests.
- Worker assignment, arrival, jail/death, save/load and human/AI handoff.
- Focused and full sharded tests, parity/goldens, export filters and build smoke.
- Fixed-route frame-time/memory comparisons; investigate regressions above 10%.
- Paired-seed balance measurements for travel changes; no arbitrary retuning.
- Exported Windows walkthrough and real two-machine seat/action/voice session.

## Deferred

New campaign chapters, hidden-informant gameplay, arrival-gated payroll, new
combat mechanics, UDP prediction, multiplayer racing, additional aircraft and
cloud deployment follow this overhaul. Ordinary city houses remain scenery.
