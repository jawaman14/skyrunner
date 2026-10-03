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
3. Done: `cli.gd -- strategic --n 100`: the equilibrium moved to 58.4%, outside the 50 +/- 5% target - almost
   certainly the crash-rate drop removing a tax that kept the sides even (ablating "crews" alone drops it to 36%,
   by far the largest lever). **Tuned (BALANCE entry 45):** a run of 200 per cell read 54.6% by luck; 1,000 per
   cell confirmed 58.3%, a sweep of the base value of a run (HQ rule `run_payout`) found 10750 puts it at 51.7%
   (51.6% at 2,000 per cell), and every other target holds there (comebacks 21.8%, every ending above 8%).
4. Done: `tools/live_balance.gd -- 80 3` and `-- 40 12 story`; BALANCE entry 35 written and
   `docs/BALANCE.md` regenerated. BETA.md (at the repo root, not under docs/) now carries the balance note.

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
- **A phone on foot.** Done: T on foot opens `PhoneMenu` (scripts/ui/phone_menu.gd), a phone
  book of whoever is switched on this game - Manny's hiring hall, the buyers, the lawyer, the Family, the
  General's aide - plus the boss's desk (orders, or the squads in a war) and dispatch. Each one is the same
  call the cockpit's Shift keys make, so a conversation runs as it does there (the walker stands still
  while it does). Not done: ringing someone *in* (the phone only calls out; an offer still arrives as a
  line on the ticker), and the cockpit keeps its Shift keys rather than the phone.
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
    - **(2) done:** every stash truck has a driver's `Agent` (`StashNet.Truck.start_agent`, from
      `Session._truck_out` and `Logistics._dispatch`, once the route, driver and duration are settled): a `load` task at the yard for TRUCK_LOAD_S, then a
      `drive` along the truck's road route (a task can now carry its own planned `route`; an agent
      has its own `speed`, carries leftover time across tasks, and can be `hold()`-ed). The truck is
      delivered when its agent arrives. The agent is the authority for progress; `t0` is derived from
      it each tick (`Truck.sync`), so the ground war's readers of `t0`/`dur` and the logistics view
      are untouched, and the three places that paused a truck by writing `t0` now call
      `Truck.hold(seconds)`. The hiring hall's roster says where a driver is ("driving a truck, 3.2 km
      to go"). `Agent.ENABLED` is true now; the Python-replay parity tests turn it off.
      **No balance move by design - and measured:** live_balance.gd -- 40 3 with agents on vs off is
      identical in 8 of 9 configs; logistics (where trucks matter) moves $54,538 -> $54,627 (0.16%,
      tick-level noise). tests/test_agent.gd (9): an agent-driven truck arrives within 0.1 s of its
      old timer on a bent road and a straight line, a 30 s pull-over costs exactly 30 s, and the
      truck's fields stay readable for the war; tests/test_logistics.gd: a payroll driver's body is
      the one on the road.
    - **(3) done, the bodies (a PR):** a `GroundWar.Squad` is its men: `members`, one `Agent` per man,
      named `S-3.2`, resynced every ground tick (`GroundWar._sync_members`). The squad stays the
      authority - its x, y, route and s are written in a dozen places and the firefight odds read
      them - so the men *follow* it: on foot they string out in file behind the point man along the
      road (6 m apart), in a car or truck they are in the vehicle, stood still they ring the spot, in
      a firefight they spread into a firing line across the enemy's bearing. Casualties and arrests
      take men off the back of the file. The hiring hall says what a soldier's squad is doing ("with
      squad S-3, marching"). **No balance move, and tested rather than assumed:**
      tests/test_squad_agents.gd (6) runs the same 600 s war with the bodies on and off and compares
      every squad's men, position, state and morale, the dead and the money - identical.
      **Not done yet, deliberately:** contact, cover and losses still come from the squad's point and
      its men count (the "turf war" bullet above); that is the step that moves the balance, so it
      gets its own PR and BALANCE entry once the 3D side (step 4) can show whether the men look
      right.
    - **(4) done for squads (a PR):** `Squad.dict()` carries `at`, where each man stands, and
      `SquadRender` draws every man there instead of on its own 4-column grid, so the figures you see
      (and that `Gunplay` aims at) are the sim's bodies: in file on the road, in the car while it
      moves, ringed round it once it stops, in a firing line in a fight. A dict with no `at` (Agent
      off, an old snapshot) still draws the old grid, so remote seats and the render tests are
      unchanged. Still to draw: the payroll's own people (a dealer on his corner, a lookout at his
      stash, a driver in a truck on the road) - they have no body of their own yet beyond the truck's
      driver, so that waits on the next payroll-task pass. Looked at on screen (GPU render, a squad
      after a short firefight): the men stand where their agents do - ragged and spread, not the old
      4-column block - with no render errors. A tidier look at a column on a real road is still worth
      a pass once the walker can follow a squad.
      Next: step 5, the pathfinding upgrade.
    - **(5) first slice, and what it found (a PR):** `RoadGraph.path/route` take a penalty hook
      (extra metres per edge, never negative so the heuristic stays admissible), and
      `GroundWar.route(faction, a, b)` uses it: the organisation's and Los Cuervos' squads, and the
      organisation's trucks (`Session._truck_out`, `Logistics._dispatch`, `checkpoint_on`), pay for
      climbs steeper than 5% and for roads within 400 m of a police checkpoint (+4 km), and the
      organisation also for places shot up in the last 15 minutes (+2 km, 300 m); police squads pay
      only for climbs - they know where their own checkpoints are. `GroundWar.SMART_ROUTES` switches
      it off. **It changes nothing on today's map, and that is the finding:** the planned city
      network has 1,187 nodes, 1,202 edges and 16 independent loops - it is a tree, so a checkpoint
      on the road has no road round it. Measured: 135 random routes with a checkpoint midway, 0 went
      round; 144 random routes with no checkpoint, 0 differed (the slope term never beat a
      shortest road either); live_balance 40 3 is identical in all nine configs with it on and off.
      tests/test_pathfinding.gd (5) proves the hook on a two-road diamond (the long way round, and a
      lone road is still a road). **So the lever was the map, not the search - and the next PR
      pulled it:** three ring links (`RINGS` in `tools/plan_roads.gd`, `RoadPlanner.detour_route`)
      take the network from 107.7 to 143.6 km and from 0% to 59% of checkpointed routes having a way
      round (mean 34% longer); docs/ROADS.md. Only the war configuration of live_balance moves
      (organisation money p50 $43.3k -> $51.4k, task force $6.5k -> $6.0k; $49.4k / $8.1k from the
      new roads alone) - BALANCE entry 36, deliberately not retuned until the larger strategic re-run. Not done: re-routing a squad or truck already under way
      when a checkpoint appears on its road (pointless until there is a road to switch to), road
      class costs (the road data carries no class), off-road legs for foot, junction pile-ups.
    - **(6) the payroll's people (a PR):** `People` (scripts/sim/people.gd, `Payroll.people`) gives every
      worker who is not already a body somewhere else - a soldier is his squad's man, a driver is in the
      truck, a pilot or mule on a run is away - an `Agent` at his post: a lookout on the street by his
      stash, a dealer on his corner, everyone else round the base. A new hire starts at the base and goes
      to his post, driving along the road if it is further than 600 m (so a lookout posted to a stash across
      town arrives some minutes later), on foot if not; someone hired long ago (a loaded save) is already
      there. The hiring hall says so ("heading out to the boathouse, 3.2 km to go"). `SquadRender.sync`
      takes `People.draw_list()` and draws them (idle or walking, a car while being driven).
      **The payroll stays the authority and nothing is gated on arrival** - a lookout counts from the
      moment he is posted - so no balance moves; tests/test_people.gd (6) runs the same 900 s with the
      bodies on and off and compares every worker, the money and the wages. Not done: shooting or arresting
      a worker where he stands, 2D station maps showing them, and making a post count only once its man has
      arrived (that one would move the balance).
    - **Turf war, the engagement (a PR; decided 2026-10-03):** fights have geometry
      (`GroundWar.ENGAGEMENT`). Each weapon has the effective range `Arsenal.TIERS` already listed
      (pistol 50 m, rifle 300, machine gun 600, RPG 300) x `RANGE_SCALE`; its fire is all of it inside
      half that, 15% at the range, none 30% beyond (`GroundWar.eff`). `GroundWar.fire_at(shooter,
      target)` is what each man's weapon does at *his own* distance to the nearest enemy man
      (`Squad.members`, step 3), so a squad strung out or flanked loses the fire of the men who cannot
      reach. Squads on foot in a fight close at 3 m/s until each is at the distance its best weapon
      likes (60% of its range, 25-500 m): long guns stand off, pistols have to come in, a vehicle stays
      where it is (`_close_in`). The AI's odds still use the flat `fire()`. **Calibration:** at the
      weapons' own ranges (x1) the war came out 7% richer for the organisation and Los Cuervos lost 28%
      fewer men than the flat model; x4 is within noise of it on every count (200 seeds each, same seeds:
      org money mean $51.9k vs $50.2k, fights 14.4 vs 14.05, police losses 18.0 vs 17.5, org arrests
      17.75 vs 17.7), so x4 ships - squad fights start 250 m apart, a first-person range is the wrong unit
      there. BALANCE entry 37. Not done: men taking the best cover near them (cover is still the squad
      centre's terrain), retreating to keep a range, vehicles dismounting, and a squad deciding to fight
      or flee from the geometry rather than from the flat odds.
- **Roads.** Done: a planned network in `data/maps/city_roads.json` from `tools/plan_roads.gd`,
  see docs/ROADS.md. La Selva has no road on purpose (it stays the remote strip). The balance re-run on the ring roads is
  BALANCE entry 36 (a larger re-run with a confidence interval is under way).
- **Map:**
  - more bridges if more rivers are ever crossed (the planner makes them, the renderer draws them);
  - a starter car at the airport: the **taxi half is done**: the phone's "A taxi" lists the aircraft, the boss's
    desk, the job board, the load planner, the hangar and each live stash house with the distance, the ride (13 m/s over
    roads 1.3x the crow's line) and the fare ($15 + $1 per 250 m, paid up front); a ride runs the world ahead at 30 sim
    seconds a frame and puts you down at the other end. The **drivable car** (decided 2026-10-03: both) is done too: `Car` (scripts/game/car.gd), a parked car beside the aircraft's right wing made the first time you step out; E at it to get in, W/S throttle and brake (S reverses once stopped), A/D steer (the wheel bites with speed, less the faster you go), SPACE the handbrake, E to get out (not above 4 m/s), a chase camera. Arcade: a real body on the island's collision that stops against buildings and the parked aircraft and will not drive into deep water; a road is fast (26 m/s, about 95 km/h), anywhere else a crawl (11 m/s). The walker rides along hidden, so the phone, the sim and the HUD know where you are; TAB and the phone are refused until you are out. Driving through a police checkpoint (within 45 m, over 6 m/s) adds 6 suspicion to the runner's case, once per checkpoint per two minutes; slowing down is a wave-through. Not done: cargo in the car, police chasing it, damage, other cars on the road to hit, a handbrake turn that slides. **The car's radio**: R turns it on, `,` and `.` tune, in the car only. The dial is 19 stations of real recordings from 1979-86: Miami's Y100, WIOD and Disco 96, Jamaica's RJR, Colombia, Antigua, the Turks & Caicos, Haiti, the Dominican Republic, Honduras, Belize, Costa Rica, Nicaragua, Cuba (exile and clandestine stations) and Radio Marti on shortwave, all from listeners' recordings on the Internet Archive (assets/radio/README.md lists each, and says plainly that they are not CC0: they ship at the owner's decision and come out on request). A station is always on air (its place in the programme follows the sim clock); short recordings fall to static between plays. Folders in `user://radio/` are the player's own stations. Not done: the radio outside the car, the aircraft's cockpit radio, news items tied to the sim's events.
- **Physical logistics by truck, boat or plane.** Done: **fuel** (scripts/sim/fuel.gd): the hired fleet burns it at the economy's price - a truck 0.35 gal a km from a 25-gal tank with a 4-minute refuel stop when it will not make the trip, a go-fast boat 1.6 gal a km charged when the job is accepted, a hired pilot's 40-gal tank at the pump (15 min) - the bill is `Session.fuel_spent` and shows in the logistics view; and **multi-stop rounds** (`Logistics.cash_round` / `goods_round`, `cash_round` / `goods_round` commands, the logistics menu's Round row): ONE truck through several stashes, taking the cash at each as it reaches it or dropping product at each in turn, 75 s at each stop, the planner working from the farthest in toward home; the AI sends a round when two or more stashes are worth a trip. BALANCE entries 36 and 37: fuel costs the hired-fleet configurations 3-5%; rounds lose fewer trucks for later money (-1.4% p50 in the logistics configuration). **Not done:** fuel stations as places on the map (the price is the economy's, the stop is a delay), a fuel gauge on the truck, rounds for boats and aircraft.
- **Mount & Blade's ideas, where they fit** (the owner's inspiration, 2026-10-03; each is its own PR behind a switch):
  **renown** is done (DESIGN section 25): a score from deliveries, sales, raids foiled and verdicts won, lost at half weight
  to busts and raids, in five tiers that improve the hiring hall's candidates, the bulk buyers' prices and how closely the task
  force watches. **Veteran squads and field orders** are done too (DESIGN section 26): squads rank up from the fights they
  survive (Green, Blooded, Veteran, Elite: more fire, steadier nerve, dearer upkeep), and on foot Z / X / C / V hold, call,
  charge or fall back the nearest of our squads. **The rackets** too (DESIGN section 27): the streets we hold pay tribute (fair or squeezed, from the phone's
  collectors) and the rival squads we rout leave prisoners to ransom, turn or release. **Stash works** (DESIGN section 28): a hidden vault and a guard post, two levels each, bought in the logistics menu.
  **The arena** (DESIGN section 29): a street race in the car and an air circuit at every strip, a field of four
  against the clock, prize money and renown by place. A race chip on the HUD and a book (bets on a win or a place) are done. Not done: races between players.
- **Saves keep the organisation.** Done (the old line here said "boats don't carry over to a new
  game or map", which turned out to be the whole of a save: it kept only money, aircraft, gear, upgrades,
  location, the arsenal, campaign, story and tutorial, and every stash house, crew member, squad and case
  started fresh on a load). `StrategicSave` (scripts/sim/strategic_save.gd, the save's `sim` key) now also
  keeps the stash houses (heat, intel, burned) and the product and cash in them, the whole payroll (crew,
  their posts, candidates, jail, wages owed), the runner's case file, the court case and its history, the
  organisation's squads, and the session clock so a trial date still means what it did. A save is written
  parked at an airfield, so nothing is in flight: trucks, boats (they only exist as a go-fast per drop job),
  jobs and the workers on them are not saved - those workers load free. Also kept now, by name through
  `SaveVars` (lists of property names in `strategic_save.gd`, each round-tripped through JSON in
  `tests/test_strategic_save.gd`): the Family (regard, the loan, offers, tribute), the product trade, the
  economy and its market, the island, the Company, the chronicle, the three arsenals, the ground war's books
  and commanders, the rackets' counters and prisoners, and the rival and task-force squads (where they stood,
  at rest). And the HQ season (`NightDirector` / `HQ.Season`: the organisation, the task force, Los Cuervos,
  the season's books and both random streams); a night that was mid-operation comes back at its planning
  phase. Nothing of the world is left out of a save now, except what is in flight (trucks, boats, jobs).

## 3. Later
- A real-app playtest pass on every seat.
- A browser (web) build, single-player.
