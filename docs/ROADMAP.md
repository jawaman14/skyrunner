# Roadmap

The work queue after beta 0.9.0-beta.1, in priority order. Each item is a feature branch and a PR.

## 1. Balance re-fly on the Godot flight model (done - see entry 35, one number needs a decision)
The balance numbers were measured with JSBSim; the game now flies its own model.
1. Done: `cli.gd -- tactical --seeds 10 --workers 8`, `sim-results/calibration.json` and `tactical.json`
   committed (the air-risk table reads them). 630 flights; the crash rate fell from 19% to 2% (the
   castering-gear fix, 336a0dc, was the cause - see entry 35).
2. Done: `cli.gd -- feasibility` again (the castering-gear fix changed takeoffs): 240 trials, a net
   +12 passes (concentrated at Old Quarry for the Cessna 182 - the mountain-strip question
   docs/STRIPS.md left open), but the twins lost some landings. See entry 35.
3. Done: `cli.gd -- strategic --n 100`: the equilibrium moved to 58.4%, outside the 50 ± 5% target -
   almost certainly the crash-rate drop removing a tax that kept the sides even (ablating "crews"
   alone drops it to 36%, by far the largest lever). **Not tuned yet** - this is 10x fewer seasons
   per matrix cell than the run it's compared against, so a bigger re-run would help confirm the
   drift is real before anyone retunes a rule. See entry 35 (docs/BALANCE.md) for the numbers.
4. Done: `tools/live_balance.gd -- 80 3` and `-- 40 12 story`; BALANCE entry 35 written and
   `docs/BALANCE.md` regenerated. **Open:** "BETA.md's balance note" - no `docs/BETA.md` exists in
   this repo (nor anywhere else under that name), so nothing was added under that name; flagging
   rather than guessing what it should be.

## 2. Playtest feedback (first real play session)
First wave, small and high value. **Done (in PRs):** the Esc pause menu; runways and landing (keyboard
flight assist, ramped throttle and brake, gentler ground steering, fairer touchdown rules, visible
runways, the strip audit in docs/STRIPS.md); throttle steps. **Still to do:** F1 scrolling, the compass,
the tutorial's red squares, crew, autopilot.
- **Esc menu.** Done: resume, save, load, settings (graphics, volume, colours, flight assist, controls),
  quit to lobby or desktop.
- **Runways.** Done, see docs/STRIPS.md. Open there: mountain strips versus the Cessna 182 and half loads.
- **Throttle.** Done: Z/X ramp (twice for instant), R/F a finer step.
- **F1 help** isn't scrollable: put it in a ScrollContainer.
- **Compass.** Add a HUD heading tape or rose with a wind arrow overlaid.
- **Tutorial:** explain the four red squares shown in flight (they are the PAPI lights: white over white
  is high, red over red is low).
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
- **Physical NPCs (the design rule, from playtest).** Every worker, driver, soldier and dealer has to
  be *somewhere*: a body on the map that walks or drives there, not a row in a table. The sim stays
  the authority (deterministic, seeded, headless), but position and travel time become real inputs:
  - **Agents.** A worker gets a position, a route and a task (walk, load, refuel, repair, drive, guard,
    fight). Trucks, boats and squads are agents' vehicles and groups: a squad is its men, a convoy is
    its driver and escort. Payroll, Logistics, GroundWar and StashNet keep their books, but a job is
    done when the agent arrives and does it, not when a timer runs out.
  - **Turf war.** Squads and firefights are made of those bodies, present at the place, with contact,
    cover and losses coming from who is physically there. The engine still resolves outcomes (odds,
    morale, arrests, the Family's and the court's reactions); the 3D world shows the same people.
  - **Pathfinding.** Better than one A* on the road graph: cost by road class and slope, no impossible
    roads, off-road for foot, ramps and bridges, avoiding known checkpoints, ambushes and hot spots,
    re-routing when blocked, no pile-ups at junctions.
  - **Order of work:** (1) an `Agent` and a task queue in the sim behind a static switch; (2) drivers
    and hauled cargo in Logistics; (3) squads built of agents; (4) the 3D side shows every agent;
    (5) the pathfinding upgrade; each step keeps the parity tests green and gets its own PR and BALANCE
    entry (agents change travel times, so the balance moves).
- **Roads.** Done (in a PR): a planned network in `data/maps/city_roads.json` from `tools/plan_roads.gd`,
  see docs/ROADS.md. Still open there: La Selva has no road, and the balance has to be re-run on it.
- **Map:**
  - more bridges if more rivers are ever crossed (the planner makes them, the renderer draws them);
  - a starter car at the airport.
- **Physical logistics by truck, boat or plane.** Player-set pick-up and drop-off jobs for hired
  bots, multi-stop routes, and automatic refuelling at fuel stations. Fuel prices join the economy.
- **Boats** don't carry over to a new game or map.

## 3. Later
- A real-app playtest pass on every seat.
- A browser (web) build, single-player.
