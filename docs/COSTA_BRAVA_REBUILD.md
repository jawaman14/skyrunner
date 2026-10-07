# Costa Brava rebuild — 8 October 2026

## Direction and delivered foundation

The Asset Bible governs a weathered 1979–1982 coast: plaster, ochre, terracotta, faded paint, timber and corrugated workshops. Neon belongs to existing nightlife and interface accents. The new `CostaBravaPlan` replaces the generic city-box generator with deterministic street-front parcels, open courtyards and reserved working plots.

Current authored districts: Camino del Aeropuerto workshops, San Telmo Viejo, Plaza del Mercado, Barrio Chino, Puerto de San Telmo, Pueblo Morales and Talleres de la Cantera. The generated census is 3,144 parcels (including harbour cranes) and 108 additional local street polylines. Local roads are rendered/collided/queried through the existing shared road surface; the painted-only grid is disabled. Wet, steep or runway-crossing candidate legs are rejected. New buildings have stable parcel IDs, dry foundations, road setbacks, reserved site clearances and runway approach limits.

Original reusable residential, shop and warehouse meshes add terracotta/corrugated roofs, shutters, doors, fascia and warm windows. Each has fewer than 500 triangles, uses shared geometry and one shared material, and fits the authoritative footprint/height. Existing chunking, collision and distant box LODs remain. Low quality keeps its inexpensive box representation. Inland courtyard trees replace universal street palms; waterfront palms use original procedural green foliage at restrained spacing. No new external assets or runtime dependencies were imported.

This is the first code foundation of the requested whole-map rebuild, **not completion of every landscape, site or access gate**. The existing relief, river/coast shaping, trunk-road network, bridge spans, nine airfield anchors, eight stash identities, functional interiors and offshore destination remain. Their reuse preserves campaign references while their physical layout is reviewed. Existing saves still identify the same destinations; safe recovery of old saved world positions against changed scenery needs dedicated acceptance evidence. No claim of balance neutrality or full save-position migration is made.

## Research-to-design decisions

| Evidence | Design inference for Skyrunner | Validation |
|---|---|---|
| Ryan, Rigby and Przybylski (2006), four studies: perceived autonomy/competence associated with enjoyment; multiplayer survey also supports relatedness | Make route, load and delegation choices explain their tradeoffs. Keep flight mastery rewarding as management opens. | Ask players to explain their next decision and its cost/risk; observe first deliveries and delegation |
| Pichlmair and Johansen, *Designing Game Feel* (2020/2021), survey of more than 200 sources distinguishing physicality, amplification and support | Prioritise predictable access/movement, then event-specific feedback, then reduce command friction | Separate collision/navigation failures from tactical mistakes; measure order-to-outcome comprehension |
| Tyack and Mekler (2024), critical review of 259 SDT-related HCI games papers | Treat psychological principles as hypotheses, not a recipe or evidence that this particular game is enjoyable | Combine observed behaviour, task completion and interviews; do not infer enjoyment from automated balance completion |

Primary sources: [2006 paper](https://selfdeterminationtheory.org/SDT/documents/2006_RyanRigbyPrzybylski_MandE.pdf), [game feel survey](https://arxiv.org/abs/2011.09201), [critical SDT review](https://arxiv.org/abs/2405.12639). These applications are our design inferences, not prescriptions tested in Skyrunner.

Concrete UX work: visible destination/loading signs, distinct district silhouettes, reported-risk route options, durable order outcomes, operational/battle debriefs, affordable delegation boundaries and clear recovery after loss. Avoid adding geography that creates travel repetition without a strategic purpose. Preserve four tutorial chapters, twelve story chapters and existing combat/payroll authority.

## Godot repository review

Reviewed project pages/licences on 8 October 2026. A repository licence is not blanket permission for all bundled demo media. Candidate status is distinct from actual asset usage.

| Repository | Potential use | Decision |
|---|---|---|
| [Terrain3D](https://github.com/TokisanGames/Terrain3D), MIT | Editable terrain, foliage instancing, mesh/foliage LODs | Prototype only after defining a height-query adapter; replacing authoritative terrain silently would break flight, navigation and determinism. Native GDExtension exports require platform verification. Not imported. |
| [ProtonScatter](https://github.com/HungryProton/scatter), MIT addon | Editor authoring of vegetation/props with exclusion shapes | Suitable for an isolated editor prototype and baked deterministic placements. Keep runtime simulation independent. Its demo texture licensing is distinct. Not imported. |
| [Waterways](https://github.com/Arnklit/Waterways), MIT | River meshes, flow/foam baking | Useful reference/prototype for Rio Negro. The reviewed README includes older shader API examples; validate a matching Godot 4 revision before adoption. Keep authoritative water/height queries unchanged. Not imported. |
| [Godot demo projects](https://github.com/godotengine/godot-demo-projects), MIT | Mesh, instancing and editor-tool patterns | Use the matching stable branch for future focused prototypes; master follows engine development. No demo project/media imported. |
| [citygen-godot](https://github.com/t-mw/citygen-godot) | Procedural street generation reference | Reviewed listing targets Godot 3; licence was not verified in this audit. No direct copying or import. Original parcel/street code used instead. |

## Remaining whole-map work and gates

1. Replace temporary rectilinear old-town composition with authored lanes/plazas and differentiated civic landmarks; complete quarry village coverage (terrain rejection currently leaves two parcels). Improve service signs and readable destinations.
2. Survey and rebuild physical airfield yards, stash/loading approaches, HQ plots and harbour transitions together. Preserve runway approach clearance and La Selva's deliberate isolation. Do not connect offshore cays by invented public roads.
3. Correct graded connectors and remaining checked routes before migrating truck/squad dispatch. The updated audit finds 13/99 loading pairs reachable, versus 7/99 in the preceding baseline; **86 remain blocked**. Nominal-centre routes still fail all 99. New streets are not evidence that logistics is solved.
4. Continue rural/mangrove/jungle/quarry/cay art and shared infrastructure, then period vehicles and cockpit surfaces. Existing stash interiors remain functional builders rather than decorative inventory.
5. Validate old save positions, human campaign pacing and paired strategic seeds. Geography/cover/routes changed; do not compensate with speculative speed/pay/hazard tuning.
6. Walk and drive every entrance/loading area/bridge, verify collision and LOD transitions on all presets, and record exported Windows and two-machine sessions. Those human gates remain outstanding.

Use `tools/costa_review.gd -- OUTPUT_DIRECTORY` for reproducible high-quality old-town/port/overview renders, `tools/coastal_benchmark.gd` for the fixed moving reference route, and `tools/logistics_routes.gd` for route evidence. Screenshots show layout and rendering only; they are not a walkthrough.

## Validation record

Initial focused city/render/road/site checks: 51 passed, zero failed, including six new placement/mesh regressions. Desktop smoke: `SMOKE OK`. Full desktop regression: **1,033 passed, zero failed** across shards 352 / 363 / 318, with no script/parse errors. Export exclusions and diff whitespace checks pass. Paired balance and performance evidence follow below. Godot shutdown ObjectDB/resource/PagedAllocator cleanup diagnostics remain distinct from assertion/script failures.

### Paired war-seed evidence

`tools/live_balance.gd -- 10 3 war 1` ran against baseline `ad45107` and changed
code `6e27423`, using seeds 1–10 and identical three-hour stand-ins. The canonical
aggregate outputs are preserved in
`sim-results/costa-rebuild-balance-2026-10-08.json`. This configuration does not
exercise the full logistics pipeline or human flying.

| Measure | Before | Rebuild |
|---|---:|---:|
| Organisation cash median | $54,693 | $39,056 |
| Organisation cash mean | $55,706.6 | $51,246.2 |
| Law funds median | $6,256.37 | $5,782.83 |
| Organisation arrests mean | 23.5 | 18.5 |
| Burned stashes mean | 0.8 | 1.0 |
| Organisation combat losses mean | 6.3 | 6.1 |
| Recruitment spending mean | $4,400 | $5,050 |
| Upkeep spending mean | $2,142.9 | $2,495.5 |
| Payroll shortage share | 0 | 0 |

This is a material outcome change and requires broader paired seeds and human
review. No speed, payout or hazard tuning was applied. Runs overlapped other
validation work; their 167s/272s wall times are not isolated performance evidence.

### Routing performance investigation

A separate sequential headless profile built each map's road graph and queried
all 56 directed stash-to-stash legacy routes once. Baseline: 1,576 nodes,
182.5ms graph initialization, 2.068ms mean query and 4.173ms p95. Rebuild: 1,949
nodes, 294.0ms initialization, 4.403ms mean query and 10.119ms p95. These are small
machine-specific samples, without the dynamic police penalty or a dense combat
scene. The increase exceeds the 10% investigation trigger. More local streets
increase search work; the existing A* scans its open list to pick each minimum.
Preserve tie/order determinism while profiling/optimising that search in a
separate tested slice before integration. Do not silently remove valid streets
or hide the cost by increasing simulation intervals.

### Render evidence and remaining performance gate

Two fixed moving coastal runs per version, low preset at 1280×720, used 360 warmup
and 360 measured frames. Baseline mean frame times were 1.921 / 2.894ms; rebuild
2.261 / 2.390ms. P95 was 3.821 / 5.770ms before and 4.609 / 4.573ms after.
Reversing run order showed substantial desktop variance, so no reliable frame-time
improvement or regression is claimed. Static memory was about 266.6MB before and
252.3MB after; final-frame draw calls were 164 versus 138. Raw results, route
profiles, full test counts and all 99 loading-pair results are preserved in
`sim-results/costa-rebuild-validation-2026-10-08.json`. These runs do not validate
high-preset/dense combat performance. The measured routing cost increase remains
an integration blocker even though the rendering sample is inconclusive.

Visual review images under `docs/screenshots/costa-rebuild-2026-10-08-*` show the
current composition and period mesh rendering. They are development evidence,
not final art approval or proof that every location is physically usable.

Implementation draft: [PR #247](https://github.com/jawaman14/skyrunner/pull/247).
