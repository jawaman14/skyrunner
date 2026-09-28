# Roadmap

The work queue after beta 0.9.0-beta.1, in priority order. Each item is a feature branch and a PR.

## 1. Balance re-fly on the Godot flight model (in progress)
The balance numbers were measured with JSBSim; the game now flies its own model.
1. `cli.gd -- tactical --seeds 10 --workers 4`, then commit `sim-results/calibration.json` and
   `tactical.json` (the air-risk table reads them).
2. `cli.gd -- feasibility` again: the castering-gear fix changed takeoffs.
3. `cli.gd -- strategic --n 100`: the equilibrium must stay at 50 ± 5%.
4. `tools/live_balance.gd -- 80 3` and `-- 40 12 story`; BALANCE entry 35; BETA.md's balance note.

## 2. Playtest feedback (first real play session)
First wave, small and high value:
- **Esc menu.** Esc quits the game today (`pilot_app.gd` on foot and in flight, `station_app.gd`).
  Make it a pause menu instead: resume, save, load a save, settings (graphics, controls F8,
  palette, audio), and quit to the lobby or desktop. This also frees the keys it replaces.
- **Runways.** They look wrong and landing is impossible. Check the runway mesh against the
  levelled terrain (`Terrain._shape_fields`), the threshold markings, and `Session._arrive`/the
  crash checks on touchdown.
- **Throttle.** Z/X are full and cut; R/F and PgUp/PgDn should step smoothly. Make that clearer, or
  give Z/X a graduated rate.
- **F1 help** isn't scrollable: put it in a ScrollContainer.
- **Compass.** Add a HUD heading tape or rose with a wind arrow overlaid.
- **Tutorial:** explain the four red squares shown in flight.
- **Crew:**
  - hired crew die at once;
  - the AI hires on the player's behalf without asking;
  - it isn't clear where the crew are or what they do.
- **Autopilot:**
  - it circles;
  - it should route itself to airfields (RoutePlanner);
  - it should fly differently with illegal cargo (low, transponder off, around radar) than with legal
    cargo (direct, at cruise altitude).

Second wave, larger features:
- **A phone on foot** to reach the crew and desk menus.
- **Workers as physical NPCs** who walk, load, refuel and repair, and can be given specific tasks.
- **Map:**
  - some roads are too steep or in the wrong place;
  - bridges over streams;
  - a starter car at the airport.
- **Physical logistics by truck, boat or plane.** Player-set pick-up and drop-off jobs for hired
  bots, multi-stop routes, and automatic refuelling at fuel stations. Fuel prices join the economy.
- **Boats** don't carry over to a new game or map.

## 3. Later
- A real-app playtest pass on every seat.
- A browser (web) build, single-player.
