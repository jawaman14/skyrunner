# Costa Brava working-site setbacks — 8 October 2026

Three authored road sections crossed functional building footprints. The
physical buildings now sit 24 metres east inside their existing reserved plots:

| Site | Strategic anchor (unchanged) | Physical centre |
|---|---|---|
| Customs HQ | `(950, -11170)` | `(974, -11170)` |
| Finca Morales barn | `(-700, -3350)` | `(-676, -3350)` |
| Barrio Chino lock-up | `(1500, -9500)` | `(1524, -9500)` |

Stable IDs, inventory, strategic coordinates, road geometry and legacy dispatch
remain unchanged. Both render builders and access records use `SiteLayout`'s
shared transforms. Only known Costa Brava anchors are shifted; alternate
authoring and optional generated maps do not acquire these offsets.

HQ foundations now sample the corners of their actual transformed plot and use
the rendered base height. Previously the nightclub setback—and any later
setback—left foundation sampling at the strategic anchor. The regression uses
curved ground to distinguish those locations and checks collider depth/top;
a plane's uniform translation would cancel out the foundation-depth difference.

## Physical and routing evidence

Eight site-layout and four stash-interior tests pass. The new tests cover full
road width plus roof margin against footprints, checked walking/loading access,
threshold height, builder/record agreement, unchanged strategic data and actual
rendered collider clearance across each former crossing. Physics rays sample
the centre and both edges of the 9 m ribbon; this includes walls, roofs and
foundations. Existing interior entrance/exit and storage-aisle tests remain.

All three local walking/loading connections verify. Threshold-to-terrain
differences are approximately +0.060 m (customs), -0.113 m (barn) and -0.015 m
(lock-up). These numerical and automated physics checks are not an exported
human walkthrough.

The checked loading matrix improves from **13 to 21 reachable pairs out of 99**;
78 remain blocked. Raw evidence:
`sim-results/site-setback-loading-access-2026-10-08.json`.

The read-only `tools/road_access_components.gd` diagnostic now finds 114
components (including isolated vertices), no functional-footprint-rejected
edges, and 118 grade-rejected edges. It samples terrain and travel-surface
height with the same 4 m spacing used by access validation: 67 rejected edges
have terrain grade at or below 18% but a steeper surface; 51 already have steep
terrain. These categories narrow the investigation and do not prove a specific
join/bridge defect or validate vehicle handling. Raw coordinates and grades:
`sim-results/site-setback-road-components-2026-10-08.json`.

An isolated 1,800-frame startup smoke reports `SMOKE OK`; repository hygiene
passes. Ten paired three-hour war seeds (1–10) at gameplay head `a30900f` have
identical canonical aggregate results to the previous service-road stack:
zero changed fields, median money $39,056 and law funds $5,782. Elapsed wall
time is excluded. Raw comparison:
`sim-results/site-setback-balance-2026-10-08.json`. The stand-in does not exercise
full logistics or establish human pacing; overlapping runs are not performance
evidence and do not accept earlier map/AI outcome shifts. Full regression
at gameplay head `a30900f` passes **1,057 tests, zero failed** (343 / 361 / 353),
with no script or parse failures. The final commit strengthens the foundation
test fixture and adds diagnostic detail/documentation without changing gameplay.
Native Godot shutdown cleanup
diagnostics are kept separate from script, parse and assertion failures.

## Remaining gates

Keep this PR draft behind #267 until dependent work and physical exported
acceptance are ready. Do not enable live truck/squad checked-route migration
while required journeys remain blocked. The next road pass must reproduce the
67 surface-added grade failures before changing geometry, and design usable
approaches for the 51 terrain-slope failures. Preserve runway clearance, bridge
collision/render parity, deliberate remote sites and legacy dispatch until its
measured migration. Do not widen limits or compensate with speed/payout tuning.

Saved player positions, every entrance/loading area, both bridge directions,
moving performance and wider map/AI balance still require their documented
acceptance evidence. Broader human, controller and real two-machine gates are
unchanged.
