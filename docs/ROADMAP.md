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
First wave, small and high value - **all done, in PRs:** the Esc pause menu; runways and landing
(keyboard flight assist, ramped throttle and brake, gentler ground steering, fairer touchdown rules,
visible runways, the strip audit in docs/STRIPS.md); roads (docs/ROADS.md); throttle steps; F1
scrolling; the compass; the tutorial's red squares; crew; autopilot. Second wave (below) is next.
- **Esc menu.** Done: resume, save, load, settings (graphics, volume, colours, flight assist, controls),
  quit to lobby or desktop.
- **Runways.** Done, see docs/STRIPS.md. Open there: mountain strips versus the Cessna 182 and half loads.
- **Throttle.** Done: Z/X ramp (twice for instant), R/F a finer step.
- **F1 help.** Done: a ScrollContainer, mouse-wheel scroll, the same panel proportions as F8.
- **Compass.** Done: a heading tape under the wanted stars (scripts/ui/widgets/compass.gd), with a wind
  arrow (points toward where the wind is blowing FROM, a weather-vane needle) when a season has weather.
- **Tutorial.** Done: the HUD tells Tutorial the moment the PAPI lights are actually on screen
  (Hud._papi -> note("papi_seen")), and a one-off tip explains them.
- **Crew.** Done, three playtest complaints that turned out to be one: the organisation's AI already
  runs the payroll and the ground war in solo play (by design: Payroll.ai/GroundWar.commanders[f].ai
  turn off only when a human claims the boss or lieutenant seat, which solo never does) - nothing was
  broken, nothing was explained.
  - "hired crew die at once": deaths were real but unexplained. `GroundWar.place_name()` (was
    `_place_name`, now public) gives `Payroll.lose()` a `where` clause, so "Pepe (soldier) was killed
    in the town (squad S-1)" now follows the "Shots fired in the town: S-1 vs P-6" the player already
    saw, instead of landing with no context.
  - "the AI hires without asking": a new tutorial lesson ("org_crew", scripts/sim/tutorial.gd) fires
    the first time the AI actually hires for the organisation (Payroll._think -> note("ai_hired_org")),
    explaining that it runs itself and that SHIFT+W shows the roster.
  - "isn't clear where they are / what they do": the hiring hall (SHIFT+W) has a new "Who's working for
    me?" choice listing everyone - role, and what they're doing (Payroll.doing(): watching a named
    stash, with a squad, driving a truck, ...) - not just the headcount it showed before.
- **Autopilot.** Done. U still just holds heading and altitude; a second U (no new key: SHIFT+U
  already means something else when the island's in the game) routes to a destination - the active
  job's strip if there is one landable, else the nearest airfield other than the one just departed;
  a third U turns it off. Legal cargo is a straight shot at a proper cruise altitude; a hot load is
  a winding RoutePlanner valley route low over the ground. The altitude is one number for the whole
  leg (the route's highest terrain plus a margin), not continuous terrain-following, which would
  react late to what's coming up.
  - **"It circled":** confirmed, and it was a real bug, not just a missing feature - aiming the bank
    straight at the destination and re-aiming every frame (pure pursuit) is only stable far from a
    bank-limited turn's own turn radius; from a bad initial angle it can settle into a permanent
    orbit around the point instead of ever reaching it. Fixed by flying a fixed course line for each
    leg with a cross-track correction (Autopilot._along_across, the same technique PilotBot already
    uses for a landing centreline) instead of re-aiming at a moving reference frame.
  - **"You automatically have the squawker on, and decide whether to turn it off depending on
    heat":** right, and the sim already agrees - PoliceSystem._classify gives a clean squawk zero
    suspicion gain unless it's already been tipped, so squawking is the *safer* default even with a
    hot load, not an automatic tell. Session._autopilot_navigate only goes dark on a hot leg once
    there's heat to hide from: wanted, tipped, or suspicion at or above 50
    (AUTOPILOT_HOT_DARK_SUSPICION) - and only below the clutter floor does dark actually make the
    track vanish; above it, a squawk that cuts out is itself the tell (HELP_TEXT already said this).
  - Open: it doesn't route round known radar coverage, only under its clutter floor (same idea, more
    work: RoutePlanner has no notion of an avoid-zone yet, only terrain cost).
  - tests/test_autopilot.gd (13): the U cycle, legal altitude/route shape, hot altitude/route shape
    while still squawking with no heat on you, going dark once wanted/tipped/suspicious, no circling
    from a bad angle, hands back control on arrival, target selection (job over nearest, never the
    field just left), and the too-close-to-bother fallback.
- **"At the boss's table the game controls like an RTS - you move people and routes - but leaving
  the desk should go back to AI."** It already did, for StationApp's seated boss in co-op
  (squad_mode: CLICK a squad, RIGHT-CLICK to send it, Session.seat_driver stands the ground war's AI
  commander aside exactly like it does for a human lieutenant) - the gap was that solo play's own
  physical desk (walk up, E) only ever opened the abstract season-orders board, which needs the
  fifth rule layer nobody runs solo. HQMenu (scripts/ui/hq_menu.gd) now has the same squad_mode:
  Q swaps the board for a live StationMap, claims the boss's seat for as long as that lasts
  (Session.seat_driver, fixed to also stand the AI aside for a human boss - it only did for a human
  lieutenant before), and hands it straight back on Q again or on leaving. With no season running
  (every solo game) the desk opens straight on the squads - a GPU-rendered walkthrough showed the
  first thing a solo player saw was a "no season" note with squad command hidden behind a small Q.
  tests/test_seats.gd and tests/test_walker.gd (test_the_boss_desk_commands_squads) cover it.

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
    - **(1) done:** `scripts/sim/agent.gd` - a position, a route (the road graph for `car`, straight
      there for `foot` - better pathing is step 5) and a FIFO queue of `Agent.Task` (`kind`, `at`,
      `dur`); `update(dt, graph)` walks the route then waits out `dur` before returning the task's
      `kind` once, so a caller polling every frame never double-counts an arrival. `Agent.ENABLED`
      (false) gates nothing yet - nothing in the sim creates one until step 2 (drivers in Logistics)
      reads a real position instead of a status string. tests/test_agent.gd (6): walking straight,
      waiting out a task's duration, running a queue in order, idle with nothing queued, `clear()`,
      and a car agent actually following the city map's road graph (never a shorter path than the
      crow flies).
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
