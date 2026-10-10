# Roadmap

Current continuation queue, reviewed 9 October 2026. Each slice is a separate
feature branch and draft PR. Historical progress is preserved in
[ROADMAP_HISTORY_2026-10.md](ROADMAP_HISTORY_2026-10.md); the source-backed
findings and reproduction checks are in [UI_WORLD_REVIEW.md](UI_WORLD_REVIEW.md).

## Where we are heading (owner direction, 8 October 2026)

The approved direction is [DESIGN.md §0](DESIGN.md#0-where-the-game-is-heading-owner-approved-direction-8-october-2026):
build an empire from nothing, Warband-style, starting as a hired pilot. Product order:

1. **The early rise.** A new story opens employed by a legitimate air service, flying its Cessna. The business
   slides into smuggling, which becomes unavoidable, and the player earns their first aircraft. Sandbox unlocks
   come from money, reputation and activity, with the campaign as an alternative route. *Implemented as one
   rebased PR, #296 (from Codex's #250, #251, #252 and #255; nine employment tests), awaiting merge. Needs rebasing, a
   human pacing walkthrough and a calibrated first-aircraft price (draft: $18,000).*
2. **Setup-driven automation.** Explicit assignments first (payroll has these), then conditional orders
   (stock thresholds) and multi-step task sequences. Manual play always remains. Workers follow instructions;
   AI never invents assignments.
3. **Faction competition and the civilian economy.** Rivals with distinct starting strengths, growing through the
   economy; expansion-driven diplomacy; civilian jobs, demand and prosperity; turf war arrives late or by choice.
4. **Multiplayer teamwork and competition.** Separate co-op and competitive modes for 2–16 players, with
   organisation, rival and police sides. A leader leaving halts the session.

The overhaul queue below (menus, stations, access, roads, interiors, NPCs, art) and the completion gates are the
**reliability prerequisites inside each step**, not a separate product phase. Loss and recovery (hospital,
impound, rebuilding with survivors) supports step 1. Specify the network ownership contracts early, so step 4
doesn't force a rewrite.

## Next implementation packages (from Codex's planning PRs #241–#243 and audit #246)

Each package is a series of separate branches and draft PRs off `main`, with focused tests and the evidence in the
PR body. None is implemented beyond what the queue below records.

**A. Physical access and movement (#241).** Prerequisite for automation and faction competition.
- *Where it stands:* the recorded route baseline had all 99 audited directed logistics pairs blocked. The
  authored loading endpoints (#235) and validated local detours (#237) are now on `main` (#294); the remaining
  access series (#265–#276) is unmerged and reached 13–26 of 99 in its own audits. Re-run `tools/logistics_routes.gd`
  for the current number. Failure kinds are grade, footprint, an unauthored meeting point,
  a disconnected network, and no nearby access.
- *Never:* raise connector limits or restore straight-line fallbacks to make the numbers pass.
1. Reproduce HAR, Warehouse 7, HQ and dock access in the Ctrl+F2 overlay. Record site IDs, entrance and loading
   coordinates, road node, obstruction and intended travel mode.
2. Fix grade and footprint failures with narrow authored approach corrections, checked in both directions.
   - Respect bridges, foundations, occlusion, runway clearance and water.
   - Keep La Selva without a public road.
   - Mark boat-only and foot-only destinations as such, instead of promising vehicle access everywhere.
3. Author the Family's meeting and loading point where the club actually is (draft #274), then re-audit all 99
   pairs with before/after lengths and reasons.
4. Migrate logistics dispatch only for validated vehicle endpoints.
   - Refuse unreachable orders before money or stock leaves.
   - Persist the blocked reason and last valid position.
   - Never duplicate cargo on reroute, save/load or cancel.
   - Keep the legacy route API for callers not yet migrated.
5. Migrate squads separately, after the trucks. One worker identity through truck, foot, squad, jail, away and
   death; animation never decides arrival.
6. Only then measure issue #85, member-level combat contact, on paired seeds against the current accounting.

**B. Empire command and feedback (#242).** Builds on #236 (squad cards), #238 (visible-only targeting), #239
(district summary), #240 and #245 (own-unit battle accounts), all now on `main` (#294); don't rebuild those.
1. An owner-only empire overview showing:
   - money and stock: safe cash, cash out at sites, stock;
   - obligations: payroll and squad upkeep;
   - crew: available, assigned and jailed.

   Rows use stable IDs and open the existing previews. No single "net worth" and no promised income.
2. A durable order lifecycle (accepted, travelling, arrived, blocked, refused, result unknown).
   - It correlates with sequence acknowledgements; an acknowledgement and a refreshed snapshot are separate
     evidence.
   - It never resends after a disconnect.
3. Operational debriefs built from recorded events (deliveries, interceptions, transfers, wages, injuries,
   arrests, collections), ordered and de-duplicated by event ID.
   - Missing evidence shows as "unknown".
   - Never reconstruct a cause from today's state, and never reveal unseen police or rival decisions.
4. Battle accounts extended with custody, retreat and observed tactical facts (range, cover, surprise), stated as
   observations rather than causes. Combat maths unchanged.
5. Teach the first empire decisions at the existing unlocks: how flights fund stock, wages, repairs and defence.
   No new mechanics or payouts.

**C. Coastal art, playability and release (#243).**
1. Finish one reference corridor first: HAR, the coastal road, Warehouse 7, the harbour and services. Audit
   foundations, doors, desks, loading and parking, waterfront edges and yard transitions before adding decoration.
   Drafts #227/#228 are the starting point.
2. Then:
   - functional coastal architecture and wayfinding;
   - period vehicles (draft #269) and readable crew identity;
   - analogue cockpit surfaces on the existing aircraft;
   - event feedback through effects and cleared audio: arrival, incoming fire, damage, retreat, lost contact.

   Neon stays in nightlife and the interface. No unresolved radio audio (#175).
3. Before and after each asset batch, capture a fixed moving route and a dense-squad scene at matched
   seed, time, preset and hardware. Record mean and P95 frame time, define the memory metric, and investigate
   regressions over 10%. The 7 October static benchmark is not enough.

**D. Open review items (#246, Claude's review in HANDOFF.md).**
- #246's network findings (command de-duplication, frame limits, stale input) are **fixed on `main`** by
  #259/#260.
- Still open:
  - **AI knowledge policy:** police and rival AI read broader simulation state than a human in the same role
    sees. Decide the intended knowledge before tuning, and before #244's escort/stakeout changes are balanced.
  - The client-side oversized-frame stall, and the doubled per-frame snapshot on local desks (HANDOFF.md log,
    2026-10-10).

## Baseline and completed work

Faction-AI corrections now have a [forty-seed isolated evidence record](FACTION_AI_ISOLATION_2026-10-09.md). Keep #244 and #98 open: surveillance effects change, and the stand-in has no cargo trucks to measure active escorts. No balance tuning accompanies this study.

Worker-map port #289 and startup failure cleanup #290 are squash-merged through `a3f66fb`, each after eleven exact-head checks passed. The original desktop changes remain preserved. #291 completes the read-only fixture audit and is squash-merged as `aae28fa` after eleven exact-head checks. Merged main `c7b8763` passes all 1,027 desktop tests in three shards, with zero test/script/parse failures. Generated status #287 is squash-merged as `c7b8763` after eleven exact-head checks. Issues #94, #96, #101 and #177 are completed. Broader #97 entry-path coverage and physical/human gates remain open. Do not reschedule the integrated taxi, seat, worker-marker, failed-host or immutable-fixture work.

**Latest integrations:** #280/#281/#282/#284 are squash-merged through main `9d879ba`, each after all eight current-head CI jobs passed. Parity/seed registration (#93) and command separation (#95) are complete. Seat consolidation #285 and test lanes #286 are now squash-merged through `828ba50`, each after eleven CI jobs passed. #288 is squash-merged as `549ec05` after eleven current-head checks passed, publishing taxi coverage and the #94 acceptance matrix. Generated checkout facts and separate validation/human gates are in [PROJECT_STATUS.md](PROJECT_STATUS.md). The dated baseline/stack descriptions below remain history.

**Earlier reliability baseline, 8 October 2026:** #254 and #259–#263 are
squash-merged; main `3347007` passes 1,002 post-merge desktop tests, smoke and
hygiene. Superseded #232/#233/#234/#256/#257 are closed. Use the
[per-PR integration record](PR_INTEGRATION_2026-10-08.md) for the current queue
and remaining acceptance gates; older dated stack descriptions below are history.

**Integration update, 7 October 2026:** #119, #178–#209, and replacement
PRs #216–#220 are merged. [#222](https://github.com/jawaman14/skyrunner/pull/222)
fixes map keyboard routing and fixer review coverage; the corrected desktop
suite passes 985 tests (315 / 337 / 333). The draft-stack descriptions below
are retained as implementation history, not the current merge queue.
Use [PROJECT_STATUS.md](PROJECT_STATUS.md) for verified and pending evidence.
[#225](https://github.com/jawaman14/skyrunner/pull/225) integrates the first
incoming Family-call source; its dated desktop baseline was 990 passing tests.
Additional incoming-call sources/evidence (#83), radar-aware routing (#87), and
human release gates remain open. [#223](https://github.com/jawaman14/skyrunner/pull/223)
is merged with passing macOS bundle/launch validation. The
[dated verification report](VALIDATION_2026-10-07.md) records current evidence.

Before truck routing migrates, fix loading/meet endpoint connectors: the
[route baseline](LOGISTICS_ROUTE_BASELINE.md) originally found all 99 audited endpoint pairs
blocked by checked access. The unmerged authored-loading/surface stack now reaches 26 of 99;
73 remain blocked. See the loading triage in [draft #276](https://github.com/jawaman14/skyrunner/pull/276);
that report is not integrated into main yet. Keep this a measured slice rather than replacing the
legacy fallback globally.

The four-chapter Costa Brava flying tutorial and twelve-chapter Costa Brava story stay.
Save expansion, the six-layer Session split, role support, switch registry and
strategic calibration are implemented; do not restart them from older reviews.

*Everything from #178 to #209, including the "draft continuations" #184–#200 named in the next two paragraphs,
is merged; the wording records the state on 6–7 October.*

The historical overhaul stack was #178 (menu/HUD foundation), #179 (job previews),
#180 (read-only fuel previews and feedback), #181 (airfield props), #182 (fuel
cache props), #183 (interface/world audit). Those PRs and #119 (patterns/Asset
Bible) are merged; do not schedule that completed work again.
[Baseline reconciliation #184](https://github.com/jawaman14/skyrunner/pull/184),
[Costa Brava map focus #185](https://github.com/jawaman14/skyrunner/pull/185), and
[dialogue reliability/navigation #186](https://github.com/jawaman14/skyrunner/pull/186)
are prepared as draft continuations of that stack.
[Dialogue input hardening #187](https://github.com/jawaman14/skyrunner/pull/187) and
[shared action previews #188](https://github.com/jawaman14/skyrunner/pull/188)
continue in that order. Draft continuations #189 (documentation), #190 (menu focus),
#191 (station outcomes/feed), #192 (interaction occlusion), #193 (checked road
surfaces) and #194 (shared site records/overlay) follow in dependency order.
Draft #195 adds stash interiors, #196 graded bridge approaches and #197 modal input.
Draft continuations [#198](https://github.com/jawaman14/skyrunner/pull/198) (map layers),
[#199](https://github.com/jawaman14/skyrunner/pull/199) (HQ/outcomes) and
[#200](https://github.com/jawaman14/skyrunner/pull/200) (remote action review) follow.
The source baseline through #197 passed
948 tests across three shards (313 / 316 / 319, zero failures and no script errors).
Existing Godot shutdown resource diagnostics persist. The #193 CI run
[37546858573](https://github.com/jawaman14/skyrunner/actions/runs/37546858573)
passed all three shards, dedicated server, exports and Linux/Windows smoke checks.
The earlier #186 CI run
[37487390571](https://github.com/jawaman14/skyrunner/actions/runs/37487390571)
passed shards, dedicated-server checks, exports and Linux/Windows smoke tests;
that export evidence does not validate the later commits. Exported Windows human walkthrough
and real two-machine remote/voice validation remain unperformed.

## Ordered implementation queue

1. **Baseline consolidation:** the stack (#178–#209) is merged; the export and human release evidence
   (completion gates below) is what remains.
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
