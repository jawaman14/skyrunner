# Villa loading approach correction

The authored Costa Brava spur ended at `(-5500, 5500)`, the villa building
centre. Its checked loading access failed against the villa footprint. The
final approach now turns west at `(-5514, 5487)` and ends at `(-5514, 5508)`,
three metres from the existing loading point. The road's full 9 m ribbon clears
the building. Site identity, entrance, loading point, terrain, runway positions,
other trunk roads and bridge indices are unchanged. Only the known terminal
and preceding approach are matched; alternate authoring is not silently edited.

Fourteen road tests pass, including checked travel in both directions between
the yard and the southern spur and footprint clearance for the full road width.
The 99-pair audit still has **13 reachable / 86 blocked**: the local villa wall
failure is removed, exposing upstream disconnected-network and meeting-access
failures. This does not claim the villa is connected to every logistics site.
Raw results: `sim-results/villa-loading-access-2026-10-08.json`.

Full stack at code head `bbf6a24`: **1,052 passed, zero failed** (338 / 361 / 353),
with no script or parse failures. Ten paired three-hour war seeds (1–10) have
identical canonical aggregate outcomes before/after this local correction;
elapsed wall time is excluded. Median cash remains $39,056. The war stand-in
does not exercise full logistics and cannot establish human pacing or physical
usability. Raw paired evidence: `sim-results/villa-approach-balance-2026-10-08.json`.

The exported physical walkthrough remains pending. Do not enable truck/squad
migration or close the map rebuild gate based on this local correction. No
balance compensation is applied; earlier map/AI outcome shifts remain unaccepted.
