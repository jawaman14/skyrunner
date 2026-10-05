# Autopilot QRY/PNR investigation log

## 2026-10-05 — Investigation by ChatGPT

Investigated the report that routed autopilot behaves normally when engaged mid-flight in most locations but can enter repeated/random-looking circles when routing to QRY (Old Quarry) or PNR (La Selva).

### Confirmed code path

`SessionCommands._cmd_autopilot()` -> `_autopilot_navigate()` -> `_approach_route()` for legal cargo.

### Geometry diagnosis

The current `_approach_route()` selects a runway end by choosing the final approach fix with the smallest Euclidean distance from the aircraft. This is insufficient for asymmetric strips.

QRY and PNR are explicitly one-way/asymmetric in `docs/STRIPS.md`:

- QRY end 0 has an approach obstruction: terrain is about 53 m above the 4.5-degree approach at about 570 m out.
- PNR end 0 has an approach obstruction: trees are about 153 m above the 4.5-degree approach at about 3000 m out.
- The strip audit documents both as strips where the open direction should be used.

The current route builder can also skip the join and target the final fix directly when the aircraft is already close to the join distance. When autopilot is engaged mid-flight this can put the first meaningful target behind the aircraft, requiring a large reversal. The low-level fixed-course autopilot then follows the bad geometry instead of being the source of the geometry error.

### Fix requirements

1. Reject known/derived invalid runway approach ends.
2. Select among valid ends using aircraft position and heading/turn cost, not distance alone.
3. If the aircraft is already inside or past the normal join/final geometry, generate a forward intercept rather than commanding a target behind the aircraft.
4. Do not tune low-level autopilot gains to hide the route-generation problem.
5. Add deterministic regression coverage for QRY and PNR with multiple aircraft positions and headings, including mid-flight engagement.
6. Preserve existing normal mid-flight autopilot behaviour and the previous fixed-course anti-circling fix.

### Repository work

- Working branch: `fix/autopilot-qry-pnr-approach`
- Tracking issue: #80 — `Fix autopilot mid-flight approach circling at QRY/PNR`
- This branch is intentionally separate from `main` until the fix is implemented and tested.

### Claude Code handoff

Claude Code should use issue #80 and this file as the implementation brief. After implementation, run the relevant autopilot/strip tests plus the full project test suite before opening a PR to `main`.
