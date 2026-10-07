# FRM service approach — 8 October 2026

The Company's meeting location depends on the shipment source. For HQ stock,
the existing meeting resolves to the FRM shed loading yard at approximately
`(-2143.017, -2754.816)`. Its nearest authored road vertex was 144.663 m away,
outside the existing 120 m checked-access limit. A clear direct leg alone did
not make it an accepted connector.

The new approximately 96 m service spur joins the existing vertex `(-2062.5, -2875)` and
ends at `(-2115, -2795)`, leaving a checked 48.987 m loading leg. Rendering,
collision and travel-surface queries consume the same added road. The original
road and bridge indices are preserved because the spur is appended. Terrain,
loading coordinates, buildings, runway locations and access limits are retained.
La Selva and the island boathouse gain no public road.

Service approaches are explicitly recorded in `MapLayout.access_roads`. The
physical road array still supplies rendering, collision and surface queries.
`RoadGraph` accepts the service roads separately for checked routing; GroundWar
constructs its legacy nodes, edges and stubs from the original road array.
Legacy dispatch therefore remains staged until its intentional migration.

Sixteen road tests pass. The new regressions check both travel directions,
every returned leg, full 9 m road width against functional footprints and
runway exclusion areas, repeatable authoring, identical legacy nodes/edges/routes
and checked availability of a staged service spur.

The full 99-pair loading audit remains **13 reachable / 86 blocked**. The new
local FRM access exposes upstream failures; HQ and barn journeys to the Company
still report a disconnected travel network. The Company's meeting also moves
to other strips for other sources, so this is not a fix for every meeting.
See `sim-results/agency-loading-access-2026-10-08.json`.

The camp investigation found a southern road terminal and northern loading
area separated by the camp footprint. Candidate detours also failed the
vehicle grade limit on the hillside. Those candidates were not retained.
The lock-up's nearest road approach likewise fails grade validation. These
need physically graded approaches rather than wider routing tolerances.

The repeatable `tools/road_access_components.gd` diagnostic reports 115 checked
components, including isolated vertices: 118 authored edges fail vehicle grade
and three fail building footprints (law HQ, barn and lock-up). These are current
validator results, not human driveability measurements. Endpoint entries report
the connector selected by the current nearest-usable-node policy; they do not
enumerate every alternative connector. Raw evidence is in
`sim-results/road-access-components-2026-10-08.json`.

The first unisolated spur prototype changed 64 aggregate fields over ten paired
war seeds: median money $39,056 to $38,284 and law funds $5,782 to $6,912.
That prompted the explicit legacy/checked staging boundary, not compensatory
balance tuning. The initial evidence is retained as
`sim-results/agency-spur-legacy-impact-2026-10-08.json`; its incomplete full-suite
run is not presented as a pass.

At code head `a91370e`, ten paired three-hour war seeds (1–10) have identical
canonical aggregate outputs to the immediately preceding Villa baseline: zero
changed fields, median money $39,056 and law funds $5,782. Elapsed wall time is
excluded. This stand-in does not exercise full logistics or human pacing, and
does not accept the earlier map rebuild/AI outcome shifts. See
`sim-results/agency-approach-balance-2026-10-08.json`. Runs overlapped regression
and are not performance evidence. Isolated 1,800-frame startup reports `SMOKE OK`;
repository hygiene passes. Full stack at `a91370e`: **1,054 passed, zero failed**
(340 / 361 / 353), with no script or parse failures. Native Godot shutdown
ObjectDB/resource/PagedAllocator diagnostics remain separate from test results.
Exported human driving/walking, moving performance and the earlier broad
map/AI balance gates remain pending. Keep live truck/squad migration gated;
no payout, speed or hazard compensation is applied.

## Next physical corrections

Investigate the customs-HQ road at `(937.5, -11187.5)`–`(937.5, -11145.5)`,
the Barrio Chino diagonal at `(1511.7, -9511.7)`–`(1480.5, -9480.5)` and the
farm spur at `(-691.4, -3365.2)`–`(-722.7, -3339.8)`. Their current centre lines
intersect functional footprints. Validate full widths, entrances/loading areas
and grade before accepting any setback or road correction. Preserve strategic
anchors and legacy dispatch until a measured migration explicitly changes them.

Then classify the 118 grade-rejected edges into terrain slope, road joins and
surface transitions. Correct geometry per reproduction; do not simply raise the
grade limit. Rerun the 99-pair audit after each measured batch, and migrate
trucks/squads only when the required endpoints and connecting network work.
