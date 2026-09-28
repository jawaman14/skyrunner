# Roads (city map)

The road network is planned, not drawn. `tools/plan_roads.gd` runs `RoadPlanner` over the city map's
terrain once and writes `data/maps/city_roads.json`; the game only reads that file (nothing is planned at
launch). Re-run the tool after any change to the terrain, the strips or the stash houses, then run the
tests and the balance.

```
godot --headless --path . --script res://tools/plan_roads.gd [-- --dry]
```

## How the planner thinks

- Places to connect: downtown, the customs house, the farms, every strip (an apron point beside it,
  never across it) except the cay's, and every stash house except the boathouse on the cay.
- One place at a time, nearest first, by the cheapest route to the roads already built (Dijkstra on the
  terrain's own 62.5 m grid). A step costs its length times `1 + (grade / 4%)^2`; nothing steeper than 10%;
  riding an existing road costs 35%, so routes share a trunk and meet at real junctions.
- Water is forbidden except the river's own channel, at 60 times the price, so a bridge goes where the
  river is narrowest. Each bridge is then straightened into one straight span between the banks.
- A place that can't be reached at 10% gets one more try as a mountain track (up to 18%).
- Three extra links close loops (Smuggler's Cove to downtown, Valle Verde to the docks, Finca Morales to
  the estuary). Routes are smoothed (corner cutting) and resampled every 40 m.

## Before and after

| | hand-drawn | planned |
|---|---|---|
| length | 68 km, 5 roads | 108 km, 32 roads with shared junctions |
| steeper than 8% | 13.5 km (20%) | 7.8% (8.4 km), 7 km of it on the three mountain tracks |
| steepest 40 m | 101% | 14% on the roads (one road has 840 m over 8%); the tracks are up to 28% over 40 m (18% per grid step by design) |
| water | 450 m over 2 crossings, no bridge | one 221 m bridge (deck, piers, rails) |
| longest straight leg | 6.5 km | 40 m (the resampling step) |

## What is still open

- **La Selva (PNR)** has no road: it is a strip on a ridge, out of reach even by track. Trucks reach it
  by the off-road leg the ground graph adds at each end.
- **Mesa del Aguila (EGL) and the jungle camp** are reached by mountain tracks.
- **Balance:** trucks, squads and the ground war all travel on these roads, so their times changed. The
  balance numbers (`sim-results/`, docs/BALANCE.md) still describe the old roads; the K3 re-fly in
  docs/ROADMAP.md has to be run on this network.
