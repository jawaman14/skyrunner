# Dry-road crossing correction — 8 October 2026

The checked audit exposed a physical fault at sloping junctions. Each road ribbon
was flattened to its highest terrain edge. Two crossing streets could therefore
have different raised deck heights, creating a lip when entering the other
street. At (2000, -9195), the query reached 21.4% grade despite roughly 8.8%
underlying terrain grade. This was not a route-search failure.

Dry ribbons now follow the terrain height at each edge. Rendering, deck collision,
wheel/foot queries, lane paint and curbs share those cross-sections. Water samples
retain flat raised decks and the existing graded bridge clearance. No terrain,
map roads, route graph, connector limits, vehicle speed or strategic anchor changes.

## Verification

- Reproduced the fault first on intersecting roads over planar 14% terrain. The
  test failed before the change and passes afterwards across the full road width.
- All five road-surface tests pass, including actual walking/driving across both
  bridge approaches in both directions and identical render/collision geometry.
- Complete regression: **1,064 passed, zero failed** (352 / 362 / 350), with no
  script or parse errors. Isolated desktop smoke: `SMOKE OK`; hygiene passed.
- Ten paired three-hour war seeds match the previous raw rows and every aggregate.
  [Current rows](../sim-results/junction-war-2026-10-08.json) are retained.
- Read-only physical road audit: grade-blocked edges **118 → 54**. Failures
  classified as surface-added steepness fell **51 → 2**; the other 52 already
  have steep underlying terrain. The first reproduced Costa Brava lip now follows
  roughly 8.6–9.0% grade.
- The fixed loading matrix remains **26/99 reachable** with no previously
  reachable journey lost. Clearing these lips does not join disconnected roads
  or make the remaining steep sections usable.

## Render comparison and limits

Used the existing moving coastal-camera tool, low preset, 1280×720, GL compatibility,
hidden native windows: 360 warmup and 360 sampled frames per run. Three isolated
pairs average 0.5376 → 0.5406 ms engine frame interval (+0.55%). Mean of per-run
p95 values: 0.6803 → 0.7043 ms (+3.5%). Static memory: 228,844,569 → 228,900,861
bytes (+0.025%); draw calls remained 147.

One p95 result rose 10.6%; repeated pairs showed -5.1% and +5.6%, without a
consistent >10% regression. Initial pairs 1/2 potentially overlapped the final
headless smoke and were excluded from the isolated comparison; their raw files
are retained. See [comparison](../sim-results/junction-render-comparison-2026-10-08.json).

These render-only engine intervals are not a gameplay FPS promise, GPU profile
or dense-combat acceptance. Human/exported bridge and road walkthroughs remain
unperformed. The two residual surface-added cases are near (10750, 562.5) and
(-7500, 7964.8); they remain explicit targets for local authoring. Preserve
intentional remote access and measure future truck/squad migration separately.
