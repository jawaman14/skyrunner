# Site access validation — 7 October 2026

Source/terrain diagnostic, not an exported walkthrough. Costa Brava with
`Terrain.natural = true` reports 12 checked walking/loading candidate pairs.
The initial straight-leg probe checked five; nearby footprint detours add seven.
These counts measure the shared authoring records, not all scenery or gameplay reachability.

Remaining examples:

- HAR hangars/pump: candidate lengths approximately 129–133m exceed the conservative 120m local connector search. An authored apron/access corridor is still needed; this does not establish physical impossibility.
- VAL and other strips: 309–557m candidates need authored access corridors. La Selva remains deliberately without a public road; no network is regenerated.
- Rival HQ and lock-up: vehicle grade checks fail and need physical reproduction/correction.
- Camp/quarry/villa: no validated detour for the current building/terrain candidates.
- Cay boathouse and Hotel Cielo: offshore/foreign locations do not acquire an imaginary Costa Brava public-road connection.
- Harbour docks: long candidates need a shared shore/service corridor, rather than individual straight lines across shore scenery.

The developer overlay now draws validated walking/loading paths and retains explicit
failure reasons. Checks use primary functional footprints, a 0.8m walking and 2.6m
vehicle clearance, 4m terrain/deck samples, runway polygons and mode-specific grades.
The visibility search is deterministic and read-only; road topology, terrain,
flight performance, payroll and economy are unchanged. Ancillary scenery, thresholds/
steps and complete exported physical/network routes still require validation.

Evidence: five SiteAccess tests and four SiteLayout regression tests, with no script
errors. Tests cover short obstacles, footprint detours, water/deck differences,
mode-specific grades, runway exclusion, disconnected graphs, unchanged authoring
records and deterministic Costa Brava/generated records. Scratch probe output is
local diagnostic data, not stored screenshot or human-release evidence.

## Nightclub road-anchor reproduction

The payroll travel probe found its initial road node inside Club Tropicana's
primary footprint: strategic HQ (-1500, -9700), node approximately
(-1500, -9697.3). The physical nightclub now sits 24m east within its reserved
plot, facing west toward the existing north/south street. Both Buildings and SiteLayout consume the
corrected frame. Strategic HQ coordinates, road geometry and terrain remain
unchanged. The road anchor has checked vehicle clearance; exported road/door
walkthrough and ancillary prop collision still require inspection.

The full street-segment probe refined the setback: a northward move cleared the
anchor but still covered the next road leg. The correction uses an eastward
setback and west-facing door; the adjacent full road segment now passes clearance.
