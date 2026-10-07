# Roadmap

Current continuation queue, approved 7 October 2026. Each slice is a separate
feature branch and draft PR. Historical progress is preserved in
[ROADMAP_HISTORY_2026-10.md](ROADMAP_HISTORY_2026-10.md); the source-backed
findings and reproduction checks are in [UI_WORLD_REVIEW.md](UI_WORLD_REVIEW.md).

## Baseline and completed work

**Integration update, 7 October 2026:** #119, #178–#209, and replacement
PRs #216–#220 are merged. [#222](https://github.com/jawaman14/skyrunner/pull/222)
fixes map keyboard routing and fixer review coverage; the corrected desktop
suite passes 985 tests (315 / 337 / 333). The draft-stack descriptions below
are retained as implementation history, not the current merge queue.
Use [PROJECT_STATUS.md](PROJECT_STATUS.md) for verified and pending evidence.
[#225](https://github.com/jawaman14/skyrunner/pull/225) integrates the first
incoming Family-call source; the new desktop baseline is 990 passing tests.
Additional incoming-call sources/evidence (#83), radar-aware routing (#87), and
human release gates remain open. [#223](https://github.com/jawaman14/skyrunner/pull/223)
is merged with passing macOS bundle/launch validation. The
[dated verification report](VALIDATION_2026-10-07.md) records current evidence.

Before truck routing migrates, fix loading/meet endpoint connectors: the
[route baseline](LOGISTICS_ROUTE_BASELINE.md) finds all 99 current endpoint pairs
blocked by checked access. Keep this a measured slice rather than replacing the
legacy fallback globally.

The four-chapter Costa Brava flying tutorial and twelve-chapter Costa Brava story stay.
Save expansion, the six-layer Session split, role support, switch registry and
strategic calibration are implemented; do not restart them from older reviews.

Current asset continuation: #227 adds HAR workshop equipment; follow with coastal infrastructure/dock details, period vehicles, then existing-aircraft cockpit polish. See [ASSET_COVERAGE.md](ASSET_COVERAGE.md) for runtime coverage and missing work. Merged-stack descriptions are archived; remaining numbered items below distinguish implementation from pending verification.

Campaign polish is implemented in draft [#229](https://github.com/jawaman14/skyrunner/pull/229), [#230](https://github.com/jawaman14/skyrunner/pull/230) and [#231](https://github.com/jawaman14/skyrunner/pull/231). [#232](https://github.com/jawaman14/skyrunner/pull/232) fixes debris expiry found during regression. The integrated draft tree passes 1,002 desktop tests; all 40 paired campaign seeds match the previous baseline. See [the validation report](CAMPAIGN_POLISH_2026-10-07.md). These PRs are not merged; human acceptance and the asset-baseline dependency remain pending.

## Ordered implementation queue

The approved empire-led continuation is recorded in [EMPIRE_MILESTONE.md](EMPIRE_MILESTONE.md).
Its first slices protect exact ground-fight intelligence, map real loading endpoints
without changing dispatch, and share selected-squad condition/travel/cost detail.
Physical connector correction remains a prerequisite to truck/squad migration.

1. **Baseline verification:** the overhaul stack is integrated; the latest
   verified gameplay baseline is #225 with 990 desktop tests and passing CI.
   Human release evidence remains pending; do not repeat stack integration.
2. **Dialogue:** integrated implementation includes correlated results,
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
   Hangar/dealer reviews use shared Cancel-first confirmation; station and
   supported logistics reviews now request/recheck read-only host consequences.
   Multi-stop cash/goods rounds and whole-armoury relocation now describe
   ordered pickups/deliveries, limited stock, ammunition exclusion and travel obligations.
   Commands reject stale/burned destinations before dispatch. Review callbacks
   freeze argument copies; caller changes cannot substitute a different order.
   Supported dialogue commitments now share Cancel-first host preview/recheck,
   frozen arguments and removal cancellation before command dispatch. Finish
   descriptions for other committing dialogue and remaining menu-specific actions; unsupported previews stay explicit.
4. **Menus/settings:** finish focus, selection, scrolling, persistent feedback,
   disabled reasons and palette refresh across all menus. Hangar/dealer first,
   logistics/rackets next, then remaining screens. The shared shell now focuses
   task controls, handles real table/controller navigation, restores invoking
   focus, and refreshes open palettes. Dealer/hangar/collector selection follows
   stable IDs; collector commitments use Cancel-first reviews. Hint controls,
   load/pack/controls/HQ/logistics buttons are focusable. Logistics has scrolling,
   a visible exit and retained site choices. Remaining preview adoption and
   remote outcome presentation are still queued. Pack/Controls now let native
   buttons handle keyboard navigation before the modal fallback, block held
   Enter repeats, restore invoking focus and refresh their open palette. Pack
   rows retain action IDs and scroll above a visible exit. Single cash-home
   orders retain pending/refusal messages instead of reporting no cash. HQ
   disbanding now uses the shared role-aware Cancel-first review; leaving the
   desk cancels pending review and restores seat/focus ownership. Transfer and
   sale/prisoner acknowledgements include their actual capped outcome, without
   revealing an enemy cash balance.
5. **Stations/maps/feed:** organize fifteen seats by task; selected-entity cards,
   acknowledged orders, grouped map layers and a shared role-filtered event feed.
   Shared persistent sequence outcomes now distinguish acknowledgement from a
   refreshed snapshot, suppress duplicate pending orders and retain unknown
   results without retrying. Station logistics uses this path; selection follows
   IDs and cards consume filtered snapshots. A text-only ordered/deduplicated
   EventBus/Chronicle feed retains source, age and report uncertainty, with
   severity-based expiry. Station maps now group operations, people/logistics and intelligence with
   keyboard-focusable toggles. Visible items consume the role-filtered snapshot
   and preserve report metadata; hidden map markers cannot dispatch/select.
   Capability-advertised previews now drive station commitments and supported
   logistics actions locally/remotely. Approval requests a fresh preview; changed
   consequences require another review. Removal, timeout, disconnect and seat
   changes send no mutation. Older peers explicitly label unavailable previews
   and retain confirmed legacy operation. Dialogue commitment review and the remaining seat-specific refinements remain.
6. **Placement/access:** deterministic footprints, entrances, walk/loading
   approaches and network connectors; diagnostic overlay and interaction occlusion.
   Through-wall interaction is reproduced with actual overlapping physics areas
   and a solid wall. Selection and activation now require an unobstructed ray;
   all nineteen walker tests pass, including existing desks/job boards. Shared
   all-entrance walkthrough and connector validation remain.
   Deterministic site data now supplies airfield parts/frames, HQ/stash frames,
   dock sites and the hotel anchor; records cover footprints, entrances, walking
   approaches, loading points and explicitly unverified connector candidates.
   Ctrl+F2 displays these records, runway/threshold/overlap diagnostics and physics
   colliders. Three focused site tests pass on Costa Brava/generated geometry;
   A read-only SiteAccess validator now checks short walking/loading connectors
   against primary footprints, terrain/water/decks, grades and runway clearance,
   with deterministic detours around nearby footprints. Ctrl+F2 draws checked
   paths and failure reasons. Its 120m local-connector search is conservative:
   longer/remote access remains unverified, not physically declared impossible.
   Ancillary scenery, approach steps and complete end-to-end network/physics
   checks remain ahead of integration.
7. **Roads/bridges:** shared physical/rendered surface, checked routes and safe
   connectors. Preserve La Selva without a public road; no incidental map rebake.
   Road ribbons now share vertices with deck collision and indexed ground-vehicle
   height queries. Checked routes return explicit failure, skip speculative T
   links and retain the route-penalty hook. Their cached topology now preserves
   close authored bends and splits real crossings without changing legacy nodes; the legacy simulation route API stays
   unchanged pending measured migration. Synthetic deck/water physics, road and
   car tests pass. Dry lowland ribbons now follow terrain at a reachable 0.45m
   offset; water retains 2.65m clearance with 10% graded approach fill. Railings
   use the same indexed surface. Four road-surface tests pass, including actual
   bidirectional walking and driving across both synthetic banks. Site
   connectors, Costa Brava bridge approaches and bidirectional
   exported walking/driving still require validation.
8. **Interiors:** fix existing hangars/HQs/casino; make all eight stash types
   enterable with existing logistics access, real availability and clear exits.
   All eight stash shells now have open doors, storage workbenches and clear aisles;
   the shack and boathouse have stepped access. Workbench use focuses logistics
   on the stable stash ID, rechecks burned state and leaves exits open. Focused
   physics checks walk into and out of every type. Pitched stash roofs now have matching slope/end collision; aisle/exit checks
   cover the added geometry. Runway diagnostics use full polygon intersections,
   including crossings and containment. Terrain-specific placement,
   Club Tropicana was reproduced covering its worker road anchor; its shared
   physical frame now sets it back within the reserved plot, preserving strategic
   coordinates and roads. Other hangar/HQ/casino corrections and exported
   walkthroughs remain.
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

## Subsequent GitHub issue pass

The owner requested review and resolution of every repository issue after this
overhaul. The 7 October 2026 inventory contains 97 open issues (#80–#177, excluding
PR #119). Evaluate each against verified code and this completion queue; overlapping
master programs and already implemented work must not create duplicate systems.
Expansion issues follow completion gates. Keep issues requiring human playtests,
physical controllers, rights decisions or two real machines explicitly unresolved
until their evidence exists. Publishing a draft PR is not integration or proof of
release acceptance.
