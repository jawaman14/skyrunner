# Map redesign from the ground up (plan, 18 October 2026)

The owner asked for a plan to rebuild the Costa Brava map from the ground up, using what we have learnt so far. That
includes the terrain, the strips, the roads, the districts, and where the buildings, sites, props and other assets go.
This file is the plan. Nothing in it is built yet. The ledger row is D-43 in [DECISIONS.md](DECISIONS.md), and the
roadmap section is "Map redesign (owner, 18 October; planned)".

## 1. What we learnt from the current map

The current map (`scripts/sim/map_city.gd`, 710 lines) was grown in layers. Each layer was added after the one before
it and then patched to fit. These are the problems that cost us time, with where each one showed up:

| # | Lesson | Where it showed |
|---|---|---|
| 1 | **The strips were placed on terrain that was never made for them.** A strip is sited by a random search near a hand-picked spot, and the terrain is shaped afterwards. The approaches then fail. | HAR end 0 has a 22 m hill 1.2 km out (D-37). QRY end 0 is pierced 53 m up. PNR end 0 has trees 153 m up. EGL has 170 m cliffs past both ends. The bots overrun the 240-380 m strips (STRIPS.md). |
| 2 | **Moving one thing moves everything.** The strip search draws from one RNG in order, so lengthening QRY moved its site onto a road, and pinning it by setting jitter to 0 moved EGL instead. | #396 needed a `pin` applied after the search. Each strip change means re-baking the terrain, re-planning the roads and regenerating the goldens. |
| 3 | **The roads came after everything else.** The road planner is good (grade costs, bridges, ring links round checkpoints), but it routes around a finished map. The city streets are not roads at all: the shader draws a grid every 110 m. | Building facades face the 110 m grid, not the real road (UI_WORLD_REVIEW). The traffic lights are placed on the shader grid. The rings were added late so that checkpoints could be bypassed. |
| 4 | **What you see is not always what you hit.** City buildings are tree points for the aircraft but have no collision on foot. Bridges have no deck collision. The roads are drawn 9 m wide but `Car.ROAD_M` is 7 m. `RoadGraph.route` falls back to a straight line through anything. | UI_WORLD_REVIEW R1, R2 and R5; the city-lot findings. |
| 5 | **Districts, zones and land use are three separate maps.** The sim zones (`west`/`north`/`sea`) are old names. The ten turf territories are overlapping rectangles (Valle Verde is 18 x 6.5 km). Land use is a per-cell class. None of them agree at their edges. | #378 turf. #402 district heat keys on the stash's zone. The presentation layers (radio strength, graffiti, crew colours) need one district per point. |
| 6 | **Functional sites have no access manifest.** Stashes are solid silhouettes with painted doors. Hangars, HQs and shops use fixed offsets. Nothing checks that a truck can reach the loading point or that a door is reachable. | The stash and HQ rows of UI_WORLD_REVIEW. Codex's #373 had to move flower beds clear of the club's car by hand. |
| 7 | **Buildings sit on one elevation.** On a slope this gives buried floors, floating props and door steps in the air. | The terrain row of UI_WORLD_REVIEW. |
| 8 | **Assets come from five kits with no catalogue.** Kenney (city commercial, industrial, suburban, nature, pirate, cars), KayKit city, and Quaternius downtown are each placed by their own script with their own scaling. The period check (1979-89) is done by eye. | `city_dress.gd`, `downtown_dress.gd`, `scenery.gd`, #374 period vehicles. |
| 9 | **What worked and must be kept:** the baked terrain cache, the offline road planner and its JSON output, MultiMesh chunks with visibility ranges, hash-placed scenery that uses no RNG stream, the glide-path height caps, strip trials run by the pilot bot, the frozen classic map for parity, and the PlayableMaps rule for retiring a map without rewriting saves. | All in use today. |

## 2. The approach: constraints first, decoration last

The new map is built in a fixed order. **Each layer may only read the layers above it**, as the Session layers do. Each
layer writes baked data. So nothing upstream moves when something downstream changes, and a strip change can never move a
road it does not touch.

**Two kinds of gate** (Codex's review of this plan): a layer's **own gate** reads only that layer and the ones above it, and
must pass before the next layer is built. An **integration gate** needs a later layer's output (the strip trials need the
shaped terrain, the access checks need the sites), so it is named on the layer it protects but runs after the later layer
is built, and its failure sends the fix back to the earliest layer it names.

**Site anchors come first.** Districts and roads need to know where the functional places are before their details exist.
So `sites.json` has two parts: an **anchor** per site (a point, a rough footprint, the road class it needs, its district),
authored with the brief in L0, and the **layout** (entrance, apron, interactions) that L7 fills in later.

```
L0  Gameplay brief        flight legs, run times, where the story happens, and the site anchors (where each place goes)
L1  Strips + airspace     authored strips; protected approach and climb-out volumes; per-end trials (the gate)
L2  Terrain               macro relief, then a constraint pass that serves L1 (flatten approaches, cut exits, plateaus)
L3  Water                 coast, river, harbour, coves, boat lanes, bridge sites
L4  Districts             one polygon set: territory, sim zone, land use, radio, graffiti, ambient life all read it
L5  Roads                 one graph with classes: highway, arterial, street, track; city streets are real edges
L6  Parcels               blocks between streets, cut into lots with a frontage edge and a pad (a height patch)
L7  Sites                 functional places from a manifest: footprint, entrance, apron, road link, interactions
L8  Fill buildings        style by district and lot, from the asset catalogue, colliders that match the model
L9  Props + vegetation    rules per land use; masks from roads, lots, aprons and approach volumes
L10 Presentation hooks    graffiti surfaces, sign slots, radio masts, spawn points (D-23, D-34)
```

### Where the data lives

- `data/maps/costa_brava/brief.json` (L0) and `strips.json` (L1) are **authored by hand**. These are the design.
- `data/maps/costa_brava/districts.json` (L4) is **authored**: polygons with an id, a name, a parent market, tags and an
  owner at the start.
- `data/maps/costa_brava/sites.json` is **authored**: the anchors with the brief (L0), each site's layout in L7.
- **The baked terrain is never rewritten after L2.** Later levelling (lot pads, site aprons) is written as **height patches**
  (`patches.json`: a rectangle, a height and a batter slope each). The loader applies them over the L2 terrain when the map
  loads, and physics, rendering and the bots all read the patched height. A patch may not touch a strip's volume or its
  pad; the integration gates rerun on the patched terrain.
- Everything else is **generated by one tool** (`tools/build_map.gd`, layer by layer, with `--from L5` to rebuild from a
  layer down) into baked files beside them, like the terrain cache and `city_roads.json` today.
- `scripts/sim/map_city.gd` becomes a loader of these files, not a generator. The game never generates at launch.
- Every random draw in the build gets its own seed per layer and per item (a hash of the layer name and the item id),
  never one shared stream. This fixes lesson 2: adding a stash cannot move a strip.

## 3. Each layer in detail

### L0 The gameplay brief
Decide the map's job before its shape: the flight time from the hub to each strip (2-8 minutes in a Cessna 172), how
far trucks drive (3-10 minutes), how many strips of each kind (hub, regional, bush, shady, beach, pit, plateau), where
chapters 1-4 of the story happen (Rafa's places, the club, the hacienda), and where the police are thick or thin. The
brief is checked against the result by the validator, so "the cove is too close to the hub" is a test failure, not a
playtest finding. The brief also holds the **site anchors** (above), so L4 and L5 can be built before the site layouts.

### L1 Strips and the airspace around them
- Each strip is authored with an exact spot, heading, length, width, surface and kind. **There is no random search.**
- Each end gets a **protected volume**: the approach surface (3 degrees, or 4.5 for bush strips, out to 3 km) and the
  climb-out surface. Terrain, trees, buildings and masts may not enter it. L2 must honour it; L8 and L9 are masked by it.
- A one-way strip is a choice written in `strips.json` (`one_way: 1`), not something found afterwards.
- **Own gate:** each strip's geometry: its length and width suit the aircraft it is meant for, it does not overlap another
  strip or its volume, and its volumes stay inside the map.
- **Integration gate (after L2, again after the patches):** the per-end pilot-bot trials (`strip_trials.gd`) pass for every
  aircraft the strip is meant for, at light and half load. Today's results in STRIPS.md set the bar, and the D-21 lengths
  (EGL 560 m, QRY 620 m) are the starting point.

### L2 Terrain shaped for the strips
- Keep the current generator for the macro relief (lobes, ridges, islets) and the baked cache.
- The constraint pass then flattens each protected volume with a smooth falloff (so there are no walls), cuts pit exits,
  raises plateaus and levels a pad for every strip. This is what D-37 (the HAR hill) asks for, done for every strip at
  once.
- It also levels the town and the plain, and keeps road grades possible: no cell in a district marked `urban` may be
  steeper than 6%.
- **Own gate:** the approach volumes are clear of terrain; the town's grade is in limits. (The strip trials are L1's
  integration gate and run here, on the shaped terrain.)

### L3 Water
The coast, the Rio Negro and its estuary, the harbour basin, the coves and the cays, as today. New: **boat lanes** (from
the cove and the cays to the pickup points) and **bridge sites** are output here, so the roads later use them instead of
finding the narrowest crossing by cost.

### L4 Districts: one map of who and what is where
- One set of polygons with no gaps and no overlaps covers the land. Each has an id, a name, a market (the economy rollup
  #378 uses), tags (city, port, farm, jungle, remote...) and the crew that holds it at the start.
- **Every system reads it:** turf (`Territories`), district heat (#402), the season's zones, the radio's signal strength,
  the graffiti and crew colours, the ambient population, the land use's palette, and the station map's labels.
- The old `west`/`north`/`sea` zones become a rollup of districts, so the existing rules keep working.
- **Own gate:** every point on land maps to exactly one district; every strip and every site anchor is in the district the
  brief says.

### L5 Roads: one graph with classes
- **Classes:** highway (2 lanes each way, 12 m), arterial (9 m), street (7 m, the city), track (5 m, dirt). The class
  sets the drawn width, `Car`'s surface width and the speed, so lesson 4's mismatch (9 m drawn, 7 m driven) cannot happen.
- **The rural network** keeps `RoadPlanner` (grade costs, bridge sites from L3, ring links round checkpoints), run on the
  shaped terrain.
- **The towns get real streets:** a street grid per urban district, bent to the terrain and the coast and clipped by the
  highway, written as graph edges. The shader's 110 m grid goes, and the traffic lights, crossings and facades use the
  real junctions.
- **Junctions are explicit nodes.** No joining loose ends within 450 m and no straight-line fallback: a place the graph
  cannot reach is a build error (UI_WORLD_REVIEW R1, R3).
- **Bridges** get a deck collider and a surface the walker and the car both read (R2).
- **Own gate:** every site anchor has a road link at its class's grade; there is a second route round every checkpoint the
  brief lists; no road enters a strip or an approach volume; the planner reports on grade, length and bridges as ROADS.md
  does.
- **Integration gate (after L7):** each site's entrance and apron, as laid out, joins its road link.

### L6 Parcels
Blocks are the faces between the streets. Each block is cut into lots along its frontage. Each lot gets a **frontage edge**
(the street it faces, so the door faces a real road), a **pad** (a height patch: the ground under it is levelled with a
short batter slope, which fixes lesson 7's buried floors, without rewriting the L2 terrain) and a district. Lots inside an approach volume get a height cap, as the
glide-path rule does today.

### L7 Sites: the functional places, from a manifest
Every place the player uses is an entry in `sites.json`: the airfield buildings (terminal, tower, hangar, pump), the
three HQs, the eight stashes, the shops, the car dealer, the casino, the docks, the track, the taxi stands, Rafa's
places for the story, and the rival depot (D-19).

Each entry says what the site needs:

```json
{"id": "stash.docks", "kind": "warehouse", "district": "the-docks", "footprint": [52, 26],
 "entrance": "front", "apron": {"truck": true, "depth": 18}, "road": "street", "parking": 2,
 "interactions": ["stash", "load"], "enterable": false, "story": []}
```

The build places each site on a lot (or a pad of its own outside town) and then checks that: the footprint fits, the
entrance faces its road link, a truck can turn on the apron, the interactions can be reached on foot without passing
through a wall, and nothing is in a strip's volume. The **access manifest** that UI_WORLD_REVIEW asked for is this file.
Sites are placed **before** the fill buildings, so the fill never takes a plot that a site needs.

Owner decision needed: which sites can be entered (the review found most stashes are silhouettes with painted doors).

### L8 Fill buildings and the asset catalogue
- **A catalogue** (`data/maps/assets.json`) lists every model we may place: the kit, the file, its footprint and height,
  its period (fits 1979-89 or not), the districts and lot sizes it suits, its collider (a box set or a simple shape) and
  its LOD. This replaces the per-kit scaling in `city_dress.gd`, `downtown_dress.gd` and `scenery.gd`. Codex's period
  work (#373, #374) supplies the first period column.
- **The fill:** each lot picks from the catalogue by district style (downtown towers, the Miami-style shopping streets,
  Barrio Chino's flats, the docks' warehouses, farm buildings) and by lot size, from a per-lot hash, so it is the same every
  time and costs no RNG stream.
- **Colliders match the model.** The aircraft's obstacle list, the walker's colliders and the drawn model come from one
  footprint, so what you see is what you hit (lesson 4).
- Rendering keeps the chunked MultiMeshes with visibility ranges, and the box layer stays as the far LOD.

### L9 Props and vegetation
Rules per land use and district: trees and hedgerows, palms on the beaches, rocks on steep ground, street furniture
(lamps, hydrants, benches, bins) along the streets at their real junctions, parked cars from #374 on the streets and
lots. Masks from L1 (approach volumes), L5 (roads), L6 (lots) and L7 (aprons and entrances) mean nothing grows on a
runway, a road or a doorway. Placement stays hash-based (no RNG stream).

### L10 Presentation hooks
Slots that the presentation layers (D-23, D-34) fill later: walls where graffiti can go (so a claimed zone repaints
somewhere visible), sign and billboard slots per district, radio masts per crew, and spawn points for the city's
ambient life. Nothing here changes the sim.

## 4. The checks: one map audit

`tools/map_audit.gd` runs every layer's gate and writes a report, as STRIPS.md does today, and an **overlay image**:
strips with their volumes, districts, road classes, sites with their aprons and access lines, and every failure marked.
It runs in CI on the baked data (fast: no generation) and fails the build on any gate. The owner reviews the image and
screenshots, not the code (#326, "Send me screenshots").

## 5. How it lands without breaking the game

- **A new region beside the old one.** The new map is built as `costa-brava-2` (its own `region_id` and map seed), and
  the current map stays playable until the new one passes its gates and the owner has approved it. Then the old one is
  retired the way the classic island was (`PlayableMaps`): its saves are refused with a message, never rewritten.
- **Parity and goldens:** the classic map stays the parity reference, so the frozen fixtures do not move. The Costa
  Brava goldens and the balance numbers will change; each step that changes them says so in its commit and gets a
  BALANCE entry (CLAUDE.md).
- **Wait for the queue first.** #373, #374, #378, #396, #402 and #404 all touch the map or its consumers. The redesign
  starts after they land, so it builds on them and does not fight them.

## 6. Steps, who does what, and the gates

| Step | What | Who | Gate |
|---|---|---|---|
| 0 | The brief (L0) and a sketch of the new layout: strips, districts, the coast, the main roads | Claude writes it, Codex reviews | **Owner approves the sketch** |
| 1 | The build tool's skeleton: per-layer files, per-item seeds, `--from`, the loader in `map_city.gd`; the audit tool and its overlay | Claude | Audit runs in CI on the current map (as a baseline) |
| 2 | L1 strips and volumes, L2 shaped terrain | Claude | Per-end strip trials pass (Codex runs them) |
| 3 | L3 water and L4 districts; move turf, heat and the season's zones onto districts | Claude | Every system reads one district per point; turf and heat tests pass |
| 4 | L5 roads with classes and real city streets; bridge colliders; `Car` widths from the class | Claude | Access and checkpoint-bypass gates; truck and squad times re-measured (Codex balance run) |
| 5 | L6 parcels and L7 sites from the manifest | Claude the data and checks; Codex the site layouts and walk/drive checks | Every site reachable on foot and by truck |
| 6 | L8 catalogue and fill, L9 props and vegetation | Codex leads (art and UX), Claude reviews the data and colliders | Frame-time captures before and after; **owner approves screenshots** |
| 7 | L10 hooks; the presentation layers start using them | Codex and Claude, by layer | As the presentation layers' own plan |
| 8 | Full suite, goldens, BALANCE entry, smoke, exported builds; owner playtest; retire the old map | Codex the QA run, Claude the fixes | **Owner playtest**; human gates on #326 stay the owner's |

Each step is its own PR, reviewed by the other agent at the exact head, with green CI. Long runs use their own worktree.

## 7. Questions for the owner

**Answered 18 October:** rebuild Costa Brava's geography properly (D-44); enterable: the club, the stashes you load at,
the hangar and the customs house, everything else solid (D-45); Valle Verde becomes a small town (D-46). Still open:
question 2 (the size); the plan assumes 32 x 32 km until the owner says otherwise. The original questions follow.

1. **Same geography or a new one?** Recommended: keep Costa Brava's shape (the city on the south coast, the estuary in
   the west, the farm plain in the middle, the jungle range in the north, the quarry in the east, the cove and cays in
   the south-east) and rebuild it properly. The story, the names and the districts already depend on it.
2. **Same size (32 x 32 km)?** Recommended: yes. Flight times and the balance are tuned to it.
3. **Which sites can be entered?** Recommended: the club, the stashes you load at, the hangar and the customs house;
   the other buildings stay solid.
4. **A second town?** Valle Verde could become a small town with streets instead of an airport in fields. That gives the
   presentation layers a second district identity.
