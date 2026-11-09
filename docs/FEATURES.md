# Feature reference

Every mechanic in the game, checked against the code on `main` @ 290832e (3 November 2026) and the open pull requests,
grouped by domain and system. The status column says what exists, not what is planned in a document: the DECISIONS ledger
marks many shipped rows "planned", so this table goes by the code. Update a row when its PR merges or its status changes.
The README has the short version; [DESIGN.md](DESIGN.md) has how each system works.

| Status | Means | Count |
|---|---|---|
| Built | On `main` and wired into play (most behind an on-by-default switch). Automated tests only unless PROJECT_STATUS says a person checked it | 122 |
| In PR | Finished on a branch with tests, waiting on review and merge (#491, #493 to #497) | 9 |
| Half done | Some code merged, but incomplete: a model with no call sites, part of the scope missing, or a gap found by measurement | 10 |
| Planned | Decided or designed (a DECISIONS row, a DESIGN section or a roadmap slice), no gameplay code yet | 42 |
| Paused | Planned, then parked by D-75 until the Living District gate | 12 |
| Deferred | On ROADMAP's Deferred list | 6 |
| Removed | Built, then deliberately taken out | 2 |

## Mechanics by domain

### Flight and aircraft

| System | Mechanic | Status | Notes | Ref |
|---|---|---|---|---|
| Flight model | 6-DOF flight dynamics from JSBSim XML | Built | scripts/sim/flight; frozen flight golden stays through the pivot (D-74) | fdm.gd |
| Flight model | Wind, gusts and turbulence in the FDM | Built | Driven by the weather system |  |
| Flight model | Fixed 30 Hz step with render smoothing in the pilot app | Half done | The host loop has it (#356); the 3D pilot app doesn't. Needed before desk acceleration | D-12 |
| Aircraft and loading | Five aircraft, every item a point mass at its station arm | Built |  |  |
| Aircraft and loading | Load planner: stations, fuel slider and presets, CG on the envelope, range and reserve | Built |  |  |
| Aircraft and loading | Fuel burn, fuel price and ferry tank (bladder-to-wing pump) | Built |  |  |
| Aircraft and loading | Airframe and engine wear, repairs, the mechanic | Built | DESIGN §39 | airframe.gd |
| Aircraft and loading | Rough-strip rolls wear the airframe | Built |  | #393 |
| Aircraft and loading | First aircraft as an earned milestone | Built | Price still uncalibrated; on the playtest list | #296 · #345 |
| Aircraft and loading | Additional aircraft | Deferred |  |  |
| Strips and airfields | Tight strips rated for approach, strip trials harness | Built |  |  |
| Strips and airfields | Mesa del Aguila 560 m and Old Quarry 620 m with wider exit | Built | C172 lifts full load from EGL and QRY east | #396 · #462 |
| Strips and airfields | Hidden strips found by flying low (story games) | Built | Discovery.ENABLED; only a fresh story hides them | D-92 |
| Strips and airfields | Flatten HAR's runway-0 approach hill | Planned | Terrain change, re-bake, strip trials | D-37 |
| Strips and airfields | Quarry west end and PNR end 1 one-way | Built | By design (terrain/trees in the climb-out) |  |
| Autopilot and assists | Autopilot, F3 hands the aircraft to the AI | Built |  |  |
| Autopilot and assists | AI pilot says where it's going, and its route is drawn | In PR | Dashed line through the legs still to fly on the scope and chart | #391 · #493 |
| Autopilot and assists | Fast-forward x1/x2/x4/x8 (backslash) | Built | Whole sim steps per frame; pauses while driving | D-88 |
| Autopilot and assists | Backspace slow reverse | Built | RB binding, F1 and GUIDE lines were already on main; the roadmap note was stale | #394 |
| Pilot experience | Nerves: tunnel vision, heartbeat, shaking hands; co-pilot steadies you | Built |  |  |
| Pilot experience | Flight debrief with route records and Benny's time to beat | Built |  | D-92 |
| Pilot experience | LORAN-C receiver, $600 first upgrade | Built | On every hangar shelf | D-92 |
| Pilot experience | Flight-skill bonus goals (landings, short strips, approaches) | Planned | Optional, never blocks a chapter | D-38 |

### Detection, sensors and comms

| System | Mechanic | Status | Notes | Ref |
|---|---|---|---|---|
| Radar | 4/3-earth horizon, sea and rain clutter, MTI notch, per-site sweep rates | Built | SensorNet.REALISM |  |
| Radar | Tracks with trails, Mode C, real squawks (7500/7600/7700 get Center) | Built |  |  |
| Radar | Radar blind-valley shading on the desk (G) | Built |  |  |
| Radio | VHF line of sight, police and crew channels | Built | RadioNet.REALISM |  |
| Radio | Call length sets DF quality; least-squares fix with error ellipse | Built | SHIFT+O burst codeword |  |
| Weather and light | Nightly forecast, cloud, rain, storms, moon phase, sea fog | Built | Storms ground helos and the aerostat |  |
| Weather and light | Weather spells in the story game, forecast in News | Built |  | D-92 |
| Weather and light | Day/night cycle | Built |  |  |
| Task-force intelligence | Pattern of life (repeat routes, up to +45% detection) | Built |  |  |
| Task-force intelligence | Canary trap via a bribed dispatcher | Built |  |  |
| Task-force intelligence | The analyst desk every tip crosses | Built | DESIGN §34 | analyst.gd |
| Task-force intelligence | Undercover agent plants a beacon on the parked aircraft | Built | DESIGN §35 | undercover.gd |
| Task-force intelligence | Spare helicopters patrol and join as flankers | Built |  |  |

### Law, heat and the court

| System | Mechanic | Status | Notes | Ref |
|---|---|---|---|---|
| Task force | Chief's desk, orders, funds ($40/min + forfeiture), AI chief | Built |  |  |
| Task force | Task-force upgrade tree (sensors, signals, intel, interdiction) | Built |  |  |
| Task force | Early-chapter police pace | Built | PoliceSystem.EARLY_PACE |  |
| Task force | AI knows only what a human in the seat would see | Planned | Audit of where the AI reads more not done | D-36 |
| Heat step 1: case files | Stash case files: lead, surveillance, warrant, raid; lying low drops a case | Built | Investigation.ENABLED | DESIGN §48 |
| Heat step 1: case files | Lawyer's warrant challenge as a command | Built | In cmds_ground.gd |  |
| Heat step 1: case files | Aircraft heat per tail number, district heat | Built |  |  |
| Heat step 1: case files | Phone Heat app (read-only) | Built |  | #446 |
| Heat step 1: case files | Step 1 balance run and BALANCE entry | In PR | Measured: the files raid about twice as often as the old roll, from a very low base | #497 |
| Heat step 1: case files | Street-war police reading the case files | Half done | With the ground war on, the war's police AI raids stashes without consulting the files | GroundWar._think_police |
| Heat steps 2 and 3 | Police search outward from last position, checkpoints on escape roads, scanner chatter | Paused |  | D-75 |
| Heat steps 2 and 3 | Ways to cool off: break LOS, cloud, swap squawk, hangar, repaint | Paused |  | D-75 |
| Heat steps 2 and 3 | Pattern escalation, new agencies (state police, DEA, radar picket) | Paused |  | D-75 |
| Heat steps 2 and 3 | Paid cops, Internal Affairs, leaks, accountant slows RICO | Paused |  | D-75 |
| Heat steps 2 and 3 | Short car/foot chases from stops and raids | Paused |  | D-75 |
| Heat steps 2 and 3 | Dirty money with a clock (loop idea 3) | Planned | Waits on heat step 2 | D-90 · D-27 |
| Heat steps 2 and 3 | Hidden-informant gameplay | Deferred |  |  |
| The court | Charges, bail hearing, lawyers, motions, plea/cooperation/jury | Built | DESIGN §16 | court.gd |
| The court | Sentencing, forfeiture, one appeal, skipping bail | Built |  |  |
| The court | Pilot is never held; arrest costs money, cargo, aircraft, heat | Built | Court.PILOT_FREE | D-64 |

### Economy and trade

| System | Mechanic | Status | Notes | Ref |
|---|---|---|---|---|
| Markets | Per-market prices moved by turf, police, seizures, gluts, fuel, storms, news | Built | Economy.REALISM |  |
| Markets | Supply/demand per drug per market, breakable networks, upstream sources | Built | DESIGN §18 |  |
| Markets | The Company's pipeline: cheap cocaine north, guns south | Built |  |  |
| Markets | Civilian economy: jobs, demand, neighbourhood prosperity | Planned | Formulas not designed | DESIGN §0 |
| The trade | Grass before cocaine; cocaine opens when the Colombians call | Built |  |  |
| The trade | Dealers corner by corner (from Manny's hall) | Built |  |  |
| The trade | Bulk buyers: Morettis, the Company, rifles to three sides | Built | Benny Ruiz, SHIFT+B |  |
| The trade | Fixer: business between flights | Built | DESIGN §36 |  |
| Loop ideas (LOOP_IDEAS.md) | 1. Market board and buyers' orders with deadlines and premiums | In PR | BALANCE entry: the AI stand-in misses most orders; premiums ~$150/run, the cost is trust | #419 · #497 |
| Loop ideas (LOOP_IDEAS.md) | 2. Cover cargo lowers the customs check | Built | BALANCE entry 55 | D-90 |
| Loop ideas (LOOP_IDEAS.md) | 3. Dirty money has a clock | Planned | After heat step 2 | D-90 |
| Loop ideas (LOOP_IDEAS.md) | 4. A readable calendar (carnival, harvest, crackdowns) | Built | Latest merge on main | #490 |
| Loop ideas (LOOP_IDEAS.md) | 5. The deal moves mid-flight (drop moves, pay doubles, cutter on picket) | Built | BALANCE entry 58 | #479 |
| Loop ideas (LOOP_IDEAS.md) | 6. Price wars and supply cuts | Planned |  |  |
| Loop ideas (LOOP_IDEAS.md) | 7. Investments with a return (strip, depot, safehouse, informant) | Planned |  |  |
| Loop ideas (LOOP_IDEAS.md) | 8. Comeback valves | In PR | Windfall built; lawyer's discount (review fixes pushed); a loan shark already exists as the Family's loan | #480 · #491 |
| Early-game content | Side gigs: aerial photos, banner tow, flour-sack pass | Built | BALANCE entry 59 | D-92 |
| Early-game content | Reactive phone banter from Rafa and Benny | Built |  | D-92 |
| Early-game content | Goal markers and HUD NEXT line | Built |  | D-92 |
| Businesses | Hotel Cielo casino on Isla Soberana, the tables, walkable | Built | DESIGN §40-42 |  |
| Businesses | Car dealership | Built | DESIGN §43 |  |
| Businesses | Laundering through the fronts (nightly allowance, soft ceiling, fee, delay) | Built | DESIGN §72; the casino cage stays its own path | #535 |

### Logistics, stock and arms

| System | Mechanic | Status | Notes | Ref |
|---|---|---|---|---|
| Physical logistics | Eight stash houses, heat with use, raids burn them | Built |  |  |
| Physical logistics | Product and cash live somewhere; trucks, escorts, cash bags | Built | DESIGN §22 |  |
| Physical logistics | Map colours trucks by cargo, Escort button | Built |  |  |
| Physical logistics | Dealers auto-resupplied from another stash (toggle) | Built |  | D-88 · #472 |
| Physical logistics | Checked vehicle routes for dispatch | Half done | All 99 audited pairs failed access; waits on the map rebuild's sites and connectors | #241 · D-86 |
| Physical logistics | Stash works (two works, two levels) | Built | DESIGN §28 |  |
| Stock rework (DESIGN §51) | Stock lots with grade, age, provenance | Half done | Grades at the source (own strips, the island) and the street pays for grade and age (DESIGN §74); bulk sales, buyers by grade, cutting not yet | slice 2 |
| Stock rework (DESIGN §51) | Pickup orders and the pickup person; gun dealer replaces sell/keep | Half done | Ordering, the window at a stash, collection by the pilot or a lookout, late and cancel (DESIGN §75); the gun dealer and interception not yet | slice 3 |
| Stock rework (DESIGN §51) | Storage places and the stock ledger screen | Half done | The ledger (lots, place, grade, age, best named quote) on the phone, DESIGN §73; storage caps and costs not built | slice 4 |
| Stock rework (DESIGN §51) | Crew relationships, rackets that close under heat | Planned |  | slice 6 |
| Stock rework (DESIGN §51) | Chapter objectives with deadlines, boss-level unlocks | Planned |  | slice 7 |
| Arms and ammunition (DESIGN §50) | Arsenals for all three factions, gun runs, police arm from seizures | Built | Arsenal.REALISM |  |
| Arms and ammunition (DESIGN §50) | Crates of one type and the scarcity ladder | Planned |  | D-61 stage 1 |
| Arms and ammunition (DESIGN §50) | Ammunition as a traded, trucked good | Planned |  | D-61 stage 2 |
| Arms and ammunition (DESIGN §50) | Fights consume rounds; dry districts, resupply by port/road | Planned |  | D-61 stage 3 |
| Arms and ammunition (DESIGN §50) | Pack, logistics and market screens for ammo | Planned |  | D-61 stage 4 |
| Isla Soberana | Air, mules on the airliner, containers on the freighter | Built | DESIGN §15 |  |
| Isla Soberana | Customs odds from both sides' perks; the General's passage and purge | Built |  |  |
| Job board | Island-wide boards that outlive visits | In PR | Remote desks list the other strips; boards saved (optional key, no version bump) | #383 · #495 |
| Job board | Drop a job from the phone | Built |  | #477 |

### Factions and the ground war

| System | Mechanic | Status | Notes | Ref |
|---|---|---|---|---|
| Organisations | Los Cuervos AI cartel: turf, tempers, truces, backward induction | Built |  |  |
| Organisations | Rival aircraft and air hijack | Removed | Removed | #377 · #388 |
| Organisations | The Family (Morettis): offers with a read, street tax, RICO | Built | DESIGN §14 |  |
| Organisations | The Agency's Contra pipeline and its double game | Built | DESIGN §13 |  |
| Organisations | The Sunrise Collective: acid for grass | Built | DESIGN §44 |  |
| Organisations | The news: random and milestone events, real 1979-86 headlines | Built | Chronicle.ENABLED |  |
| Organisations | Rival money from nowhere | In PR | Every inflow now a named outside account in the ledger; removing them is a Living District balance call | B-2 · #496 |
| Ground war | Lanchester square-law firefights on weapons, cover, nerve | Built |  |  |
| Ground war | Doctrines: guerrilla org/rivals vs narcotics-unit police | Built |  |  |
| Ground war | Engagement geometry, smart routes, veteran squads | Built | GroundWar.ENGAGEMENT/SMART_ROUTES/VETERANS |  |
| Ground war | Roadside truck firefights | Built |  | #384 · #387 |
| Ground war | Full NPC truck and squad migration to physical agents | Half done | Listed as needing further evidence | PROJECT_STATUS |
| Ground war | New combat mechanics | Deferred |  |  |
| Turf | Map-scoped districts (ten in Costa Brava) rolled into markets | Built | Territories.ENABLED | #378 |
| Turf | Visible territory map | In PR | Districts tinted by holder on the desks' map and the chart | #494 |
| Turf | District-control balance calibration | Planned |  |  |
| Turf | Rackets: tribute and prisoners | Built | DESIGN §27 |  |
| Turf | Renown | Built | DESIGN §25 |  |
| Turf | Rival depot raid | Paused | To be redesigned on rival inventories | D-19 · D-75 |
| Turf | Trust per crew with the trust table | Planned |  | D-11 |
| Hired hands | Payroll: roles, hiring hall, payday, skim/walk/snitch | Built | DESIGN §17 |  |
| Hired hands | Workers as bodies on the map with task queues | Built | agent.gd |  |
| Hired hands | Explicit assignments (product step 2, part one) | Built | Payroll's fixed assignments only |  |
| Hired hands | Conditional orders and task sequences (step 2 proper) | Planned | Needs a DESIGN note first | D-01 |

### On foot, driving and the world

| System | Mechanic | Status | Notes | Ref |
|---|---|---|---|---|
| On foot | First-person walker, torch, solid buildings, climbable kerbs | Built |  |  |
| On foot | Guns on foot (1-4), walls stop rounds, arrest or doctor's bill | Built |  |  |
| On foot | Pack: guns, rounds, medkits, 24 kg limit | Built |  |  |
| Driving | Starter car (enterable) and the car radio | Built |  | D-88 |
| Driving | The arena: street and air races | Built | DESIGN §29 |  |
| Driving | Multiplayer racing | Deferred |  |  |
| The phone | Calls, Work, Empire/Heat, News, Done apps | Built | Stays open airborne with a temporary AP hold | #446 · #473 |
| Map | Costa Brava city coast (San Telmo, ~6,900 buildings) | Built | Default map |  |
| Map | Generated islands (--map N) | Built | Classic island kept as a test fixture only |  |
| Map | Map rebuild L1: strips as authored data, map audit, MapCity loader | Built |  | D-86 · #476 · #489 |
| Map | Map rebuild L2-L10: terrain, water, districts, roads, parcels, sites, fill, props, hooks | Planned | Owner gates: layout sketch, screenshots, playtest | D-86 |
| Map | Enterable sites: club, stashes, hangar, customs house | Planned |  | D-45 |
| Map | Valle Verde as a small town | Planned |  | D-46 |
| Map | More cities, each fully explorable | Planned | Phase 4 | D-80 · D-81 |
| Look and sound | Terrain, sea, sky, vegetation, lights, fire, smoke, wet streets | Built |  |  |
| Look and sound | Kenney/KayKit/Quaternius models, docks and downtown dress | Built |  |  |
| Look and sound | Period vehicles and Costa Brava frontage | Built | Merged after screenshot review | #373 · #374 |
| Look and sound | Synth sound; one radio for cockpit and car | Built | Radio redistribution rights unresolved | #175 |
| Look and sound | Shift from low-poly towards a PS2-era look | Planned | Polygon/texture budgets need an owner call | #380 |
| Presentation layers | Territory radio and era music | Paused |  | D-23 · D-75 |
| Presentation layers | Era fashion and liveries | Paused |  |  |
| Presentation layers | Crew colours, signage, graffiti that repaint | Paused |  |  |
| Presentation layers | City pulse: rhythm, motifs, stingers | Paused |  |  |
| Presentation layers | Heat in the look | Paused |  |  |

### Story and progression

| System | Mechanic | Status | Notes | Ref |
|---|---|---|---|---|
| Campaign | Twelve chapters, 1979 Square Grouper to 1988 Last Flight | Built | Includes Blotter and The House |  |
| Campaign | Four-chapter flying-lessons campaign | Built |  |  |
| Campaign | Employed-pilot opening (Costa Brava Air Services) | Built |  | #296 |
| Campaign | Rafa as employer, Benny his fixer; rafa.dialogue cues | Built | Chapter 4 news beat still held for the takeover | D-76 · #422 |
| Campaign | Optional tutorial for every seat and system | Built |  |  |
| Campaign | Open mode with every system and a $10k float | Built |  |  |
| Takeover and boss layer | Rafa killed by Los Cuervos (heard, not seen) in chapter 4 | Planned |  | D-09 · D-78 |
| Takeover and boss layer | Half the empire survives the takeover | Planned | Own RNG stream | D-35 |
| Takeover and boss layer | Boss layer: organise; delivering optional, direct play stays first-class | Planned |  | D-58 · D-79 |
| Takeover and boss layer | Delegating a flight costs money | Built | DESIGN §69 | D-10 |
| Takeover and boss layer | Succession: next in line takes over when the boss dies or is jailed | Planned |  | D-82 |
| Campaign pivot (Phase 3) | Story v6: Blotter, The House, arena become optional ventures | Planned |  | D-77 |
| Campaign pivot (Phase 3) | Goals counted by org (direct or delegated) | Planned | Needs F-5 |  |
| Campaign pivot (Phase 3) | Ending choice, then an alternate-history sandbox after 1989 | Planned |  | D-70 · D-83 |
| Campaign pivot (Phase 3) | New chapters beyond twelve | Deferred |  |  |

### Empire simulation (the pivot)

| System | Mechanic | Status | Notes | Ref |
|---|---|---|---|---|
| Foundations | F-1 save migration chain; unsupported versions refuse visibly | Built | strategic_save.gd STEPS | D-73 |
| Foundations | F-2 ledger wrap: money and law funds booked as transfers | Built | ledger.gd; war chests tracked | D-65 |
| Foundations | F-3 named transfers by domain | In PR | 166 named sites, 0 raw; an hour of live play books nothing unattributed | #496 |
| Foundations | F-4 inventory lots and locations | Half done | Pure model plus a session wrap; call sites not moved |  |
| Foundations | F-5 command_as and actors; job_delivered gets by and mode | Built | Actor, command_as (L-3), Session.deliver by and mode (L-5) | B-7 |
| Foundations | F-6 scheduler and daily books; nights become a report | Planned | No Nights.ENABLED switch yet | D-67 |
| Foundations | F-7 desk time acceleration x1/x4/x16/x60 | Planned | After D-12 | D-85 |
| Living District (P0 gate) | L-1 business entities and San Telmo Centro district state | Built | DESIGN §64 | D-72 |
| Living District (P0 gate) | L-2 product chain on the ledger plus a legit import-to-retail chain | Built | DESIGN §65-66 |  |
| Living District (P0 gate) | L-3 Morettis as an economic org; org AI v1 | Built | DESIGN §67 | D-84 |
| Living District (P0 gate) | L-4 desk business books, staff, orders, blocked reasons | Built | DESIGN §70, on the phone | D-69 |
| Living District (P0 gate) | L-5 direct vs delegated delivery equivalence | Built | DESIGN §69 | D-66 |
| Living District (P0 gate) | L-6 operations settle while the player is away | Built | DESIGN §68 |  |
| Living District (P0 gate) | L-7 acceptance A1-A9, P1 perf, N-days balance sim | Built | DESIGN §71; then the owner's G1 playtest |  |
| After the gate | Org depth: hierarchy, schedules, budgets | Planned | Phase 2 |  |
| After the gate | Boss desk: worker control, area marking, heat map, ledger tab | Planned |  | D-62 |
| After the gate | Detail levels (tick_full / tick_aggregate) | Half done | Both ticks exist (L-6); no district runs on the aggregate one yet | D-68 |
| After the gate | Co-op authority: who's boss, disconnects, simultaneous orders | Planned | Phase 6 |  |

### Multiplayer and seats

| System | Mechanic | Status | Notes | Ref |
|---|---|---|---|---|
| Seats | Every role AI until a human takes it; 30 s reconnect token | Built | DESIGN §12 |  |
| Seats | Remote desks (station app), table talk | Built |  |  |
| Networking | Protocol v3, bounded framing, command dedup, seat generations | Built |  |  |
| Networking | Host service, LAN discovery, waiting room, dedicated server | Built | #97 steps 1-9 | #364 |
| Networking | Radio-style voice chat | Built | DESIGN §31 |  |
| Networking | Two-machine seat, action and voice session | Half done | Never run by a human | release gate |
| Networking | New multiplayer features | Paused | Frozen until the Living District passes | D-71 |
| Networking | UDP prediction | Deferred |  |  |

### UI, controls and accessibility

| System | Mechanic | Status | Notes | Ref |
|---|---|---|---|---|
| Controls | Full rebinding, analogue axes by name, invert/deadzone/expo | Built |  |  |
| Controls | Controller glyphs with fallback | Built |  | #414 · #468 |
| Controls | Key audit (every key, what help says) | Planned | Not started | #345 |
| Accessibility | Colour-safe palette (ΔE ≥ 20 under all three simulations) | Built |  |  |
| Accessibility | VHS filter and colour-blindness sims (F9) | Built |  |  |
| Accessibility | Read-aloud | Removed | Removed | #385 |
| Feedback | One UI theme, real tables, clickable key caps | Built |  |  |
| Feedback | Destination lines: boats and stash trucks | Built |  | #390 |
| Feedback | Destination lines for squads, convoys, station map, AI pilot route | In PR | Desk map already had squads; the chart gains our squads and the AI route | #493 |
| Design epics (agreed order) | First-session playtest protocol | Planned |  | #172 |
| Design epics (agreed order) | Readability and accessibility | Planned |  | #138 · #156 |
| Design epics (agreed order) | Cockpit clutter | Planned |  | #142 |
| Design epics (agreed order) | One event model and interruption policy | Planned |  | #120 · #151 |
| Design epics (agreed order) | Contextual lessons and first-use hints as one system | Planned |  | #134 · #148 |
| Design epics (agreed order) | Failure fairness and explicit assists | Planned |  | #165 · #164 |
| Design epics (agreed order) | "Why did that happen" reasons | Planned |  | #147 · #173 |

## Feature descriptions

The longer descriptions below were written for the October 2026 state and are kept as a reference for how the built
systems play. Where a description and the table above disagree, the table is current.

It has:
- five aircraft with every item a point mass at its station arm
- tight strips
- the task force and its sensors, airdrops and boats, and the campaign
- co-op and versus seats over the network, and the two HQs' seasons
- the pilot bot and the balance simulators

Beyond the prototype:
- **Load planner.** Pick the station for every item, set the fuel with a slider or presets (25/50/75%,
  full, or "route + 30 min"), and watch the take-off and zero-fuel CG move on the envelope, with
  endurance, range and the route's reserve.
- **HQ order menus for both sides.** The boss and the chief get navigable order lists. Each order shows
  its cost, its effect and its current state. LEFT/RIGHT sets it (which front, who to bribe, how many
  crews, which zone to patrol) and ENTER issues it.
- **A competing smuggling organisation: Los Cuervos.** A third, AI-run cartel flies its own loads every
  night:
  - It fights you for turf: where it owns the market your loads pay less.
  - It splits the task force's attention.
  - It hijacks your load if you meet it on the same route without a truce.
  - The boss can hit it, buy a truce or sell its route to the police.
  - The chief can send a gang unit after it.
  - Its planes fly in the 3D game as AI traffic.
- **On foot, first person.** TAB out of a parked aircraft and walk the apron, the hangars and the three
  headquarters. E uses what you face: the job board, the load planner at the fuel desk, the hangar
  workbench, the boss's desk (the organisation's orders) and the map table (what you know of Los
  Cuervos). F is a torch. The island, every building and the parked aircraft are solid; you climb
  kerbs and terraces but can't swim.
- **Generated islands.** `--map N` (or the lobby's island picker) grows island N: terrain, ten strips
  sited and rated for approach, and the HQs placed where each side would want them - the villa near the
  cove, the task force by the hub, the rival compound up in the hills. The classic island (`--map 0`) is retired
  from play; its geography is kept as a test fixture: the frozen parity and balance tests, and about 85 `World.use_map(0)` call sites across ordinary system and UI tests, so changing it touches far more than the fixtures.
- **The realism layer** (found and tuned by the scenario sweeps; details in
  [docs/BALANCE.md](BALANCE.md) 14-19):
  - *Weather and the moon.* A nightly forecast both HQs see (right 75% of the time). Cloud, rain and a
    dark moon hide you; storms ground helicopters and the aerostat, keep cutters in port, and more than
    double crash risk. In the air: wind and gusty turbulence in the flight model, rain, lightning, the moon's phase.
    Parked aircraft are tied down. On calm, dry nights, about three in ten, sea fog rolls in: visibility
    drops to a few hundred metres, the crews see 35-60% less, thick fog (over 75%) grounds the
    helicopters, and the radar doesn't care.
  - *Pattern of life.* The task force's analysts learn your routine: repeat a route and they expect you
    (up to +45% detection). Mixing your routes is the inspection game's answer.
  - *Canary trap.* The chief can feed a bribed dispatcher a fake patrol. Swerve around it and your man is
    arrested, so a leak is never ground truth.
  - *Rival tempers.* Los Cuervos are tit-for-tat, grudge-holders or opportunists, and you learn which
    from how they behave. Truces unravel as the season runs out (backward induction).
  - *Spare helicopters patrol.* The task force keeps one helicopter for the chase and flies every
    spare over a zone before the run - where the analysts expect you. Flag one and it joins the
    chase as a flanker, aiming ahead to cut you off; two aircraft on your tail box you in (the bust
    meter fills 50% faster). The sims showed why: one chaser already catches every runner it can
    reach, so extra aircraft pay by finding you, not by chasing harder.
  - *Nerves.* Stress follows what real smuggling pilots feared. Past the Yerkes-Dodson hump the screen
    tunnels, you hear your heartbeat and your hands shake (8-12 Hz, human hands only). A co-pilot
    steadies you.
- **Radar and radio that behave like the real thing:**
  - *Radar.* 4/3-earth horizon, sea clutter that rises with the wind, rain clutter, and an MTI notch:
    cross the beam or fly slow and a primary radar cancels you as clutter. Every site turns at its own
    rate (ASR 4.8 s, the aerostat 12 s); detection falls off with range and the aircraft's size. Tracks
    keep a trail and, with a transponder on, Mode C altitude. Squawk codes are real: 1200 VFR, and 7700,
    7600 and 7500 get a response from Center (key 7). The desk shades each site's blind valleys (G).
  - *Radio.* VHF line of sight over the terrain; police dispatch and tactical channels, the runner crew
    and the boat. The length of a call sets how well it DFs (SHIFT+O sends a one-second codeword), and a
    least-squares fix draws its error ellipse on the desk's map. Crew chat is radio too.
- **Upgrade trees for both sides** (hangar LEFT/RIGHT for the runner; U at the task-force desk):
  | Runner | |
  |---|---|
  | Electronics & counter-surveillance | scanner -> programmable scanner -> burst transmitter; radar detector -> direction-finding detector -> transponder spoofer |
  | Espionage | lookouts; bug sweeps -> mole in dispatch -> double agent |
  | Airframe | ferry tank; low-visibility paint -> quiet propeller; heavy-duty gear |
  | Weaponry | armed boat crew -> armed strip guards |

  | Task force | |
  |---|---|
  | Sensors | Doppler processing -> airborne early warning; coastal radar |
  | Signals | encrypted radios; helicopter DF -> intercept runner channels -> jammer van (J) |
  | Intelligence | informant network -> undercover agent; mole hunt |
  | Interdiction | armed helicopter -> Blackhawk; fast patrol boat |

  The runner pays from their money. The task force pays from its funds: a budget of $40 a minute plus
  asset forfeiture ($3,000 a bust, $1,500 + $100 a bale for a seized boat, more when the crew was
  armed). With no human at the desk the AI chief buys the cheapest thing it can afford as the money
  comes in. Weaponry is abstract: it changes chases, boardings and raids, never shows a wound, and it
  raises the stakes.
- **Costa Brava, the city coast (the default map).** The port city of San Telmo (a street grid of
  ~6,900 buildings with windows lit at night, the docks with cranes and a harbour basin), the
  international airport on the coastal plain, a meandering river to a mangrove estuary, a farm plain
  of patchwork fields, a jungle range with a mesa strip, scrub hills and the old quarry, the cove and
  the cays. Land use drives the terrain shader, the vegetation (mangroves, jungle, thorn scrub) and
  the physics: buildings are obstacles, kept out of every glide path. The HQs are Club Tropicana
  downtown (the boss's office upstairs), the customs house on the docks with a radar tower, and Los
  Cuervos' hacienda in the foothills. `--map city` or positive `--map N` (generated), or
  the lobby's map picker; old saves keep their island.
- **Stash houses.** Eight of them (a farm barn, a mangrove shack, Warehouse 7 on the docks, a lock-up
  in Barrio Chino, a jungle camp, a quarry shed, a boathouse on the cays, a hillside villa). A stash
  run lands at a nearby strip; the crew trucks the load in while you fly on. Police overhead or a
  roadblock can stop the truck (likelier as the stash heats up with use, at a police strip, or when
  you're tipped). The task force can raid a stash it knows about (X at the desk; the AI raids busy
  ones), burning it for good.
- **Markets.** Every good has a price in each market (the town and the three zones) that moves with
  rival turf and rival flights (they undercut you on drugs and buy guns), police presence (a risk
  premium where they're thick), seizures (scarcity island-wide), your own deliveries (a glut where you
  sell), fuel (a price of its own that passes through to fares, freight and fuel drums), storms and
  the news. Contraband is paid at the street price on delivery; legal work as agreed. J, then
  LEFT/RIGHT, shows the market.
- **Gun running and arsenals.** The organisation, the task force and Los Cuervos each hold weapons
  (pistols, rifles, machine guns, RPGs) and ammunition. Gun runs bring crates in: on delivery sell
  them at the street price or keep them for your soldiers (G on the job board). The fence buys, a
  dealer sells. Whatever the police seize - a busted load, a stopped truck, a raided stash, the
  guns off men arrested in a firefight - goes into the police arsenal and arms their patrols.
- **The ground war.** Soldiers, Los Cuervos' crews and narcotics squads on foot, in cars and trucks,
  driving the city's roads. Firefights are Lanchester's square law on weapons, cover and nerve.
  The organisation and Los Cuervos fight as guerrillas (ambushes at chokepoints, hit and run,
  melting into the barrio, the jungle and the mangroves, decoy cars, harassment); the task force
  fights like a narcotics unit (stakeouts, tailing a truck home, informants' controlled buys,
  buy-busts, a cordon before the raid, checkpoints, saturation patrols, SWAT, and restraint: it
  doesn't fire first and it prefers arrests). Trucks run the roads past checkpoints, with escorts.
  Who's on the streets moves the markets and, night by night, Los Cuervos' turf. The AI commands
  every side until a human takes the **lieutenant** or **patrol commander** seat; the boss, chief
  and controller can take over too (Q at their desk).
- **On foot with a gun.** Out of the aircraft, 1-4 draw a pistol, rifle, machine gun or RPG from the
  armoury; the left button fires (walls stop rounds). Squads who have it in for you shoot back.
  Go down near the police and you're arrested; elsewhere it's a doctor's bill and the gun.
- **Every seat is the AI's until someone takes it.** Join a game mid-way, see the live seat list,
  and take any role the AI is playing: pilot, co-pilot, spotter, boat, boss, lieutenant,
  controller, police pilot, cutter, chief or patrol. Leave, and the AI takes it back; drop, and
  the seat waits 30 s for your reconnect token. Table talk to everyone or your side. F3 hands the
  aircraft to the AI so the host can sit at another desk. ([docs/MULTIPLAYER.md](MULTIPLAYER.md) section 7)
- **The news.** Breaks and bad luck for all three outfits, some random and some milestones (the
  first delivery, a burned stash, officers down, flash money that gets noticed), each changing
  something real, run as headlines by the island's papers and radio. A timeline of real
  1979-86 headlines runs too, from the Mariel boatlift to Iran-Contra.
- **The Agency.** A covert arms pipeline to the Contras runs through the island's strips. Fly for
  it and it protects you: busts quashed from Washington, checkpoints told to wave your trucks
  through. Every quash leaves a trail; the task force can dig (V at the desk), and when it's
  exposed the hearings end it. Fiction, inspired by the documented Iran-Contra record
  ([docs/DESIGN.md](DESIGN.md) section 13). It plays a double game too: under pressure it
  gives your name away, lets the DEA have a flight, or "mails" your pay.
- **The Family.** A (fictional) Cosa Nostra family whose help might be a trap. Every offer (a loan,
  laundering, the docks' union, a gun fence, a crew of soldiers, a lawyer) comes with our people's
  read on it, right about four times in five. It levies a street tax when you're rich, sells to
  Los Cuervos too, and a RICO case with a rat in it turns it against you (section 14). Sit down
  with Sal Moretti (Shift+F in the cockpit, C at the desks): hear the offer, your man's read on it,
  press him for a second read, take it or leave it; pay or stall the tribute.
- **Isla Soberana.** An island republic over the southern horizon (SOB). Product is cheap there;
  get it home by air, as mules on the airliner, or in a container on the freighter. Customs' odds
  depend on both sides' perks: bought baggage handlers, forged papers and false bottoms against
  dogs, profiling, X-ray and crackdowns. The task force can't follow past the line; the General
  sells passage past his MiGs until a purge closes the island (section 15). His aide, Captain
  Ibarra, meets you on the ramp when you land, or on the radio (Shift+G / G): passage, the
  island's news, mules and containers with customs' odds in the answers. What gets through lands in
  the docks stash as product to sell, not as cash (when logistics is on).
- **The court.** A bust is a federal case now:
  - **Charges:** possession, trafficking, firearms, conspiracy.
  - **The bail hearing:** post it all, buy a bond, or sit in custody. The prosecutor calls a rich
    pilot or a friend of the island a flight risk.
  - **Lawyers:** the public defender, a Calle Ocho attorney, a Brickell Avenue drug lawyer, or
    the Family's man, who may be working for the other side.
  - **Motions:** suppress an illegal search, discovery, continuances.
  - **Off the books:** a witness leaned on, a judge who takes money (either can become
    obstruction).
  - **The outcome:** a plea, a cooperation deal that sells out the organisation, or a jury.
  - **The sentence:** mandatory minimums after 1986, the aircraft forfeited, time inside to wait
    out, and one appeal.

  Skip bail to the island and you're a fugitive. The task force prosecutes from its desk (N W K
  D Y), or the AI does. Talk it through with your lawyer (Shift+L; section 16).
- **Hired hands.** Both cartels run on a payroll:
  - **Roles:** soldiers crew the squads (no soldiers, no squad); drivers take the trucks past
    checkpoints; mules fly the island run; lookouts see raids coming; an accountant cleans the
    books or skims them; contract pilots fly runs of their own.
  - **Hiring:** hire from Manny Ortega's hall (Shift+W, W at the desks). Skill shows; loyalty only
    as a hint.
  - **Payday every 10 minutes:** the unpaid skim, walk off or call the task force.
  - **The arrested** get cases of their own: a lawyer keeps them quiet, the prosecutor's deal
    (A at the desk) makes them talk.
  - **The AI:** Los Cuervos hire, pay, lose people and trade with the island the same way. The
    organisation's AI runs your payroll when nobody sits the boss's or lieutenant's chair.

  See [docs/DESIGN.md](DESIGN.md) section 17.
- **Sound.** Synthesized, so nothing to license:
  - the engine and propeller, pitched by the engine RPM;
  - the wind, the stall horn and the tyres;
  - the radio's squelch;
  - gunfire at the fights and from your own gun;
  - police rotors, sirens and outboards;
  - surf, rain and thunder;
  - One radio for the cockpit (F7, `,` `.`) and the car (R, `,` `.`): real 1979-86 broadcasts; the car's dashboard shows the station and what is playing.

  The UI clicks are Kenney's (CC0). To hear samples, render them: `godot --headless --script res://tools/sound_demo.gd -- <out dir>`.
- **Your own controls (F8).**
  - Every flight key and gamepad button can be rebound. The remapping and button names come from Input Helper.
  - Each analogue control is bound by moving it: yoke, throttle lever, rudder pedals, left and right toe brakes. They can be on several USB devices, which are matched by name, so replugging or reordering them doesn't matter.
  - Each has invert, deadzone and expo. Everything is saved to `user://controls.cfg`.
- **Tutorial (optional).** The lobby's *Tutorial* box (ticked for your first game) or `--tutorial`.
  - **Lessons in any mode.** It works in the story, the open world and the sandbox. Each lesson finishes
    when you do the thing: take a job, open the load planner, climb past 300 ft, deliver, try the
    transponder.
  - **Lessons follow the game.** A system's lesson waits until the system is in the game: the hiring
    hall, trucking cash home, cash for the growers, going on foot, bulk buyers, the Family, the island,
    the Company. In the story, each chapter's new faction gets its lesson when it opens.
  - **Tips.** One-off tips cover the first time you're wanted, low on fuel, busted, in fog or a storm,
    short of wages, raided, a truck stopped, or the Colombians calling.
  - **Controls.** F10 skips a step, SHIFT+F10 turns it off or on. Progress rides in the save.
  - **The desks too.** The boss, the lieutenant, the controller, the chief, the patrol desk and the
    co-pilot get their own lessons, in their own keys (orders, logistics, squads, launches, raids, sweeps,
    RICO, the prosecutor). They finish on that seat's own orders, so they work from a remote seat.
- **The story: Costa Brava, 1979-1989** (the lobby's *Unlocks: Story*, the default). Eight chapters take you
  from a bush pilot flying square grouper to the organisation the coast answers to. Each chapter opens part
  of the game, so you meet each system on its own first:

  | Year | Chapter | Opens |
  |---|---|---|
  | 1979 | Square Grouper | grass, the stash houses, the hiring hall, the papers |
  | 1980 | The Connection | logistics, the dealership; the Colombians call when you've moved enough |
  | 1980 | Blotter | the Sunrise Collective: acid for grass (the lab is taken at the end) |
  | 1981 | Cocaine Cowboys | cocaine, Los Cuervos and the street war, gun runs, soldiers |
  | 1982 | Family Business | the Moretti family |
  | 1983 | The Task Force | the federal court: bail, lawyers, pleas, juries |
  | 1984 | Isla Soberana | the island, mules and containers |
  | 1985 | The Company | the Agency and its pipeline |
  | 1986 | Kingpin | sixty-five grand, and walk away |
  | 1987 | The Hearings | the Company's war ends in a subpoena: keep the case cold, bank $40,000 |
  | 1988 | Last Flight | ninety grand and a clear case, then the story is told |

  The goals are measured by the systems themselves (pounds landed, dealers on corners, cash home, a deal
  with the Morettis, loads from the island). A faction that's gone before you deal with it doesn't strand
  a chapter. `--chapter N` skips ahead. *Unlocks: Open* (`--unlocks open`) has every faction and mechanic
  from the first minute, cocaine included, and starts with a $10,000 float. The four-chapter *Flying lessons* campaign also runs on Costa Brava.
- **Logistics: product and cash are somewhere** (SHIFT+H in the aircraft, K at the boss's and
  lieutenant's desks).
  - Loads land in a stash house, and a dealer sells only what's in a stash in his own market.
  - Street money piles up where it's made. Wages, loads, lawyers and upgrades come out of the club's safe,
    so the cash has to be trucked home, or flown home as cash bags (about $4,500 a pound, and evidence if
    you're busted).
  - Bulk lots go by truck to the buyer's meet (the Morettis' club in town, Los Cuervos' hacienda), and the
    money rides back. The Company sends a plane instead: it lands at the strip nearest the goods.
  - The growers and the connection want cash on the strip, so you fly money out and product in.
  - Every truck can be stopped at a roadblock or a checkpoint (all of it forfeited), hijacked by Los
    Cuervos, escorted through, or talked past by a good driver. A raid takes the stash's product and cash.
  - Guns are physical too: the armoury sits in one place (the club, or a stash). A gun sale is trucked
    to the buyer; the whole armoury can be moved. A seized gun truck arms the police, a hijacked one
    Los Cuervos.
  - The maps colour our trucks by what they carry (cash green, product white, guns red, a buyer's lot
    amber) with a line to where each is going; a ring marks one pulled over for police ahead. Each truck
    in the panel has an **Escort** button: the nearest free squad of ours rides with it.
  - The AI boss runs regular pickups and moves product to where the dealers are.
- **The trade: dealers, buyers, and grass before cocaine.**
  - You start the way the 1970s smugglers did: cheap, bulky loads of grass from the farm strips into your stash.
  - Dealers (hire them from Manny) sell it corner by corner, competing with Los Cuervos' dealers. They get picked
    up by the police and caught in the street wars.
  - Bulk buyers (SHIFT+B, Benny Ruiz):
    - the Morettis, whose sales flood the town;
    - the Company, which feeds its pipeline;
    - rifles to the Family, the Company or Los Cuervos, each arming a different side of the wars.
  - Cocaine opens once the Colombians call.
  - The law sweeps corners and follows the money.
- **A street that moves.**
  - Under the prices, each drug has supply and demand in each market, a distribution network that can break,
    and an upstream source.
  - **Arrests** dry the corners: your bust, your workers', Los Cuervos' men, a gunfight's prisoners.
  - So do **raids** and **seizures**, and informants roll up whole networks.
  - Competing factions move it:
    - rival containers flood the docks;
    - their losses dry up their markets;
    - the Family's fall takes the gun fence.
  - Island hurricanes and purges raise the wholesale price.
  - Island loads pay today's street price.
  - The market page shows supply/demand per market and which networks are broken, and why.
- **The Company's pipeline.** Cocaine north, guns south, as in the Contra era:
  - it floods one market with cheap cocaine;
  - it spends the proceeds on guns, so gun prices rise;
  - it offers protected "return legs";
  - it leaves a trail the task force can follow.
- **Fire, smoke and weather you can see.**
  - Crashed police aircraft and your own wreck burn, and burned-out stash houses smoke; the smoke leans downwind.
  - RPGs going off in the ground war's fights, and your own, blow up with flash, sparks, smoke and debris that tumbles on the physics engine (Jolt).
  - Bales throw up a splash when they hit the sea.
  - Storms soak the world: darker ground, shining roads, rain rings on the sea. It dries off slowly afterwards.
  - Sprites are Kenney's Particle Pack (CC0).
- **Street furniture.** KayKit's CC0 City Builder Bits in town:
  - lamp posts that light at night;
  - traffic lights at the junction;
  - hydrants, benches, dumpsters and bins.
- **Your pack (I on foot).**
  - Carry spare guns, rounds and medkits, up to 24 kg; over 12 kg you slow down.
  - 5 uses a medkit.
  - Climbing back in returns the guns to the armoury.
  - Arrested, the pack is evidence for the task force.
- **Colour-safe palette and screen filters.**
  - Under simulated colour blindness, the neon status colours collapse into each other. Examples: "on" green vs the pink accent under protanopia, and warning amber vs danger red under deuteranopia.
  - The colour-safe palette (F8) switches to Okabe–Ito-style colours that stay apart under all three simulations. `test_accessibility` checks every pair: ΔE ≥ 20.
  - F9 cycles a VHS-tape filter and the colour-blindness simulations used for that check.
- **One UI, redesigned.** A single theme across every screen; real tables with titled columns (the job
  board colours the landing roll against the strip length); key caps in every footer that you can
  also click; readouts as tiles; a HUD laid out by what you need when (status chips, wanted stars,
  flight tiles, job cards, fading radio toasts, and a crew strip saying what the co-pilot is doing).
  The co-pilot's desk opens on a Flight tab of crew jobs with live tiles, has a chat line to the pilot,
  and hires a spotter wherever you click a strip. ESC asks before leaving a seat. The UI scales with
  the window (tested 1024x768 to 2560x1080).
- **Graphics overhaul:**
  - chunked, LOD'd terrain with a biome splat shader (sand, grass, forest floor, dry grass, rock
    triplanar on steep faces, normal-mapped); a depth-aware sea with shoreline foam; a procedural sky
    with clouds, sun, stars and the moon; palm, broadleaf, conifer and bush MultiMeshes swaying in the
    wind; hangars, terminals, fuel desks and the three HQs as real walkable buildings with lit windows
    and lamps
  - a day/night cycle driving sun, sky and fog
  - runway edge and threshold lights, aircraft nav lights, strobes and landing lights, and police
    light bars and a searchlight at night
  - shaded terrain (rock on steep faces, detail noise, a wet shoreline) and animated water
  - MultiMesh forests, directional shadows, glow, and SSAO and volumetric fog on Forward+
  - dust on unpaved take-off rolls, boat wakes and prop discs

- **The 1980s-coast look.** Pastel art-deco blocks (flamingo, mint, lilac, peach) with white,
  turquoise or pink trim along the roofline, "speed line" bands, and neon strips that glow pink and
  cyan after dark; palm-lined boulevards; a sky that goes orange, magenta and violet at sunset and
  violet at night, with the city's glow on the haze; a saturated colour grade. The UI is hot pink
  and electric cyan on deep violet with brush-script neon headlines (Kaushan Script and Monoton,
  both under the SIL Open Font Licence, in `assets/fonts/`), and a big banner when a run pays off
  or you're busted. Original art throughout: the genre's look, nobody's assets.

- **Low-poly models (Kenney, CC0).** The people, cars, guns, boats and street palms are from Kenney's
  public-domain kits (Blocky Characters, Car Kit, Weapon Pack, Watercraft Kit, Nature Kit), in
  `assets/models/kenney/` and loaded through `ModelLib`, which scales them to metres and turns them
  to face forward. The nearest men in the ground war are animated characters: the faction's looks
  (suits and vests for the organisation, bandoliers for Los Cuervos, uniforms, plain clothes and SWAT
  black for the task force), the gun from their squad's loadout at the chest, and the kit's walk,
  run, aim, fire and fall. Further out they're cheap MultiMesh figures. The first-person gun is the
  Weapon Pack's; the go-fast is a speedboat, and the cutter a white hull with an orange-red stripe.
  The aircraft stay procedural, built to the aircraft data's dimensions. Without the model files
  everything falls back to procedural boxes.

| **Dusk on the boulevard** | **Sunset over San Telmo** | **The city at night** |
|---|---|---|
| ![street](img/vice-street.png) | ![dusk](img/vice-dusk.png) | ![night](img/vice-night.png) |
| **The lieutenant's desk** | **Take a seat: the AI plays the rest** | **A firefight at the docks** |
| ![lieutenant](img/ui-lieutenant.png) | ![seats](img/ui-seats.png) | ![docks](img/ground-docks.png) |
| **The cast and the cars (Kenney CC0)** | **On foot with a rifle** | **Isla Soberana, over the horizon** |
| ![cast](img/models-cast.png) | ![rifle](img/foot-rifle.png) | ![island](img/island-approach.png) |
| **A sit-down with the Family** | **The General's aide on the ramp** | **The bail hearing** |
| ![talk](img/talk.png) | ![aide](img/talk_island.png) | ![court](img/court.png) |
| **Manny Ortega's hiring hall** | **The same, colour-safe palette** | **Through the VHS filter (F9)** |
| ![crew](img/crew.png) | ![crew-safe](img/crew-safe.png) | ![vhs](img/vhs.png) |
| **Controls (F8): keys, buttons, yoke, pedals** | **Downtown: KayKit street furniture, a burning wreck** | **The same street in a storm: wet** |
| ![controls](img/controls.png) | ![street](img/street-fire.png) | ![rain](img/street-rain.png) |
| **Your pack (I, on foot)** | **Sea fog (80%): the helicopters stay home** | **Logistics (SHIFT+H): stashes, cash, trucks** |
| ![pack](img/pack.png) | ![fog](img/fog.png) | ![logistics](img/logistics.png) |
| **The story: 1981, Cocaine Cowboys** | **The tutorial: a lesson and a tip** | **The lieutenant's desk, learning** |
| ![story](img/story.png) | ![tutorial](img/tutorial.png) | ![desk tutorial](img/tutorial-desk.png) |

| Mid-afternoon on the runway (medium) | Dusk, climbing out near Eagle's Nest (high) | Night: edge lights on |
|---|---|---|
| ![runway](img/runway-medium.png) | ![dusk](img/dusk-high.png) | ![night](img/night-runway.png) |
| **Load planner** | **Boss: the organisation's orders** | **Task-force desk** |
| ![load](img/ui-load.png) | ![boss](img/ui-boss.png) | ![desk](img/ui-desk.png) |
| **Job board** | **Chief: the task force's orders** | **Low preset** |
| ![jobs](img/ui-jobs.png) | ![chief](img/ui-chief.png) | ![low](img/low-preset.png) |
| **On foot at the hangars** | **The boss's desk, inside the villa** | **The villa, sited by the generator** |
| ![foot](img/on-foot-hangar.png) | ![villa](img/villa-desk.png) | ![org](img/hq-org.png) |
| **A storm night** | **Full moon** | **Generated island #7** |
| ![storm](img/storm.png) | ![moon](img/full-moon.png) | ![map7](img/map-seed7.png) |
| **The HUD, crewed airdrop** | **Co-pilot's desk** | **Lobby** |
| ![hud](img/ui-hud.png) | ![copilot](img/ui-copilot.png) | ![lobby](img/ui-lobby.png) |
| **Runner upgrades (hangar)** | **Task-force upgrades (desk, U)** | **The market** |
| ![upgrades](img/ui-upgrades.png) | ![lawtree](img/ui-lawtree.png) | ![market](img/ui-market.png) |
| **San Telmo, downtown** | **The port at night** | **Costa Brava, the map** |
| ![downtown](img/city-downtown.png) | ![night](img/city-night.png) | ![map](img/map-city.png) |

*(Rendered on a GPU-less box: Mesa llvmpipe with Godot's compatibility renderer under Xvfb. SSAO and
volumetric fog need Forward+ on a real GPU.)*
