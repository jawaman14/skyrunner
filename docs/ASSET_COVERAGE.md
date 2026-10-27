# Asset Bible coverage — 7 October 2026

Runtime consumers establish coverage; an imported pack does not. This is the
continuation queue, not a claim of exported human acceptance.

| Bible group | Existing runtime coverage | Remaining work |
|---|---|---|
| Architecture | Airfield/HQ builders, eight stash interiors, city houses/shops, hotel/casino, harbour warehouses | Reference-corridor thresholds/loading/access verification; shutters, gutters, weathering and service identity |
| Infrastructure | Road surfaces/bridge decks, street lamps, runway lights, tower antennas | Coastal direction signs, period utility poles, safe fences/gates and drains; no network regeneration |
| Workshop/fuel | Pumps, drum/pallet clusters, notices, benches; HAR tool chest/vice/rack in #227 | Generator/welding kit where actually used; reference-area performance checks |
| Docks | Kenney docks/boats/crates/barrels; original first-pier mooring equipment in coastal batch | Verify actual deck placement/collision; nets, hand trucks and usable service/loading areas |
| Vehicles | Shared ModelLib vehicle consumers, dealership cars and squad vehicles | Period silhouette audit, starting with modern luxury SUVs; authoritative condition visuals and distant simplification |
| Aircraft | Existing procedural fleet, flight HUD, cockpit glareshield | Analogue panel/radio/compass presentation from current state; no additional aircraft |
| Vegetation | Existing trees, palms, rocks/bush scenery with distance limits | Check corridor density and distant transitions; reuse suitable assets before adding more |
| Characters | Existing faction bodies and payroll identity/movement | Period clothing/role readability and lifecycle verification; no extra simulation bodies |
| Technology | Existing radio/menu presentation and some furnished interiors | Period desk/VHF radios, telephones and paper equipment where useful; no modern filler |
| Strategic presentation | Shared map layers, permission-filtered markers/feed | Existing-seat polish and uncertainty validation; no hidden-state artwork |

Order: finish HAR–coastal road–Warehouse 7–harbour/services, then vehicles, then
existing-aircraft cockpits. Large gameplay expansions and additional aircraft
remain deferred. Bible quantities are targets, not an instruction to import
unused assets. Provenance is recorded in ASSET_PROVENANCE.md.

Each batch needs source/budget records, rendered review on all presets, access
checks, fixed-route frame time/memory comparisons and export evidence. Physical
controller and real two-machine checks remain separate release gates.

## Proposal: ambient life, effects and the PS2 direction (16 October 2026)

A to-do list, not a commitment. Nothing here is scheduled, and none of it overrides the order above; items wait for
the owner's go-ahead. It follows the rules in this file: Bible quantities are targets, assets need a runtime consumer
before import, and ambient figures are render-only (no new simulation bodies, authoritative state or random draws on
existing streams).

### Decision needed first: the PS2 budget and texture policy

The owner's direction is a slow move from low-poly toward a PS2 look. That changes the pipeline, not only the numbers:

- **Budgets** (Asset Bible §1): small props 20 to 500 tris is PS1-tier. PS2-era is roughly 200 to 2,000 for props and
  3,000 to 8,000 for vehicles and characters. Needs an owner decision and an Asset Bible edit.
- **Texturing:** the look is 128² to 512² painted textures with grime, baked vertex-colour AO, bilinear filtering and no
  normal maps. The flat palette used by `assets/models/airfield` is the opposite, so it stays for hard-surface props
  (poles, tanks, lights) and weathered things (buildings, vehicles, crates, people) move to UV-unwrapped atlases of
  about 256² per prop family.
- Settle this before more props are built, or each is built twice.

### Priority rule: simulated figures first, render-only figures for the rest

(Owner, 16 October, on PR #380.) Where the simulation already has an actual worker, driver or soldier, the render uses
that data (`People`, `Agent`, squad render data) and nothing else, so the player never sees a second pedestrian or
vehicle standing in for the same activity. Render-only figures are added only for roles the simulation does not model.

| Case | Source |
|---|---|
| Workers, drivers, crews, police and ground-war soldiers that exist as `People` / `Agent` / squads | The existing render data. Better models and animation, no extra bodies |
| Roles the simulation does not model (casino patrons, bar smokers, fishermen on piers, gulls and shore birds) | Render-only figures: no sim state, no authoritative position, no draws on existing random streams |
| Anything that could be mistaken for a modelled role (a "road traffic" van next to a real courier route, a "dock worker" beside a payroll worker) | Not added until it has been checked against the simulated version first |

This is compatible with the no-new-sim-state rule above and takes priority over every row below.

### Props, by how much life they add

| Tier | Item | Notes |
|---|---|---|
| 1 | Gulls and shore birds | Render-only flocks; scatter near aircraft and boats |
| 1 | Ambient road traffic | Pickup, bus, motorbike on existing roads; render-only, and only where no simulated vehicle covers the same road (see the priority rule) |
| 1 | Idle pedestrians | Smokers outside bars, fishermen on piers, casino patrons; period clothing, no payroll identity, never standing in for a simulated worker |
| 1 | Dock activity | Forklift, cranes, nets drying, moored fishing boats bobbing |
| 1 | Moving small details | Laundry lines, ceiling fans, flags in the wind |
| 2 | Utility poles and wires | Sagging wires, transformer, payphone (also listed under Infrastructure above) |
| 2 | Period signage | Fictional beer and shop signs, awnings, hand-painted hoardings |
| 2 | Lit interiors | TVs, radios and cassette players glowing at night; bar stools, jukebox, pool table |
| 2 | Fuel and workshop kit | Generator, welding kit, oil drums, rope coils (Bible props 1 to 10) |
| 3 | Clutter | Bins, dumpsters, pallets, tyres, chain-link and wooden fences, boat trailers, lobster pots, market stalls, hand trucks, luggage |

### Effects, by priority

Already in: `FX` (fire, smoke, blasts, splashes, debris, scorch), `WeatherFX` (rain, lightning, storm fog), the wet-ground
shader, street-lamp light pools, wind-sway vegetation and the VHS screen filter.

1. Heat shimmer over runways and tarmac; dust trails from vehicles and prop wash.
2. Bloom and sun / runway-light lens flare.
3. Time-of-day tinted distance fog.
4. Glow cards for lamps, runway lights and lit windows at night.
5. Shoreline foam, boat wakes and propeller spray.
6. Dithered fade at LOD changes instead of pop-in.
7. Touchdown tyre smoke and skid marks.
8. An optional PS2 screen-filter mode (slight blur, bloom, colour banding) beside the VHS one (`ScreenFilter.MODES`). **Done (18 Oct):** `ScreenFilter` mode `ps2` (F9), `shaders/ps2_filter.gdshader`; screenshots `docs/img/ps2-filter-off.png` and `ps2-filter-on.png`.

### Suggested order

1. Decide the budget and texture policy (one Asset Bible edit).
2. Tier 1 ambient life with effects 1 to 3.
3. Tier 2, then Tier 3 as filler.

Each batch follows the batch rules above: source and budget record, rendered review on all presets, fixed-route frame time
and memory comparison, and export evidence.
