# Skyrunner design: runners, kickers and the task force

> This is the design document of the Godot game (the one game). It began life with the original
> Python prototype, which is now kept only as the reference that generated the frozen parity
> fixtures in `tests/fixtures/`; nothing in the Godot build needs it. Sections 10-12 cover what
> the Godot build added.

This is the plan for taking Skyrunner from a single-player bush-flying game to an
asymmetric **traffickers vs. law enforcement** game. It supports solo play against AI,
co-op crews, and team-vs-team multiplayer, and it follows a campaign that gets harder
year by year.

Status legend: **[done]** in the code now · **[planned]** planned, see *Roadmap* (the extra human roles are queued in docs/REVIEW_2026-10.md).

---

## 1. Pillars

1. **The aircraft is the puzzle.** Weight, balance and fuel are one budget: every pound of
   fuel is a pound of cargo you can't carry. The flight model flies the result honestly.
2. **Information is the weapon.** Neither side sees the truth. Traffickers work from radar
   warnings, scanner chatter and spotter calls. Police work from radar tracks, tips and
   direction-finding fixes. Most of the game is about controlling what the other side knows.
3. **Every tool has a counter.** Each gadget exists together with the thing that beats it
   (see the matrix in §4). Balance comes from the pairs, not from raw stats.
4. **Complexity arrives one year at a time.** The campaign adds one system per chapter, so
   by 1986 you juggle all of them, but you learned each one alone.

## 2. Modes

| Mode | Humans | AI fills | Status |
|---|---|---|---|
| **Solo runner** | Pilot | Police, optional AI co-pilot | [done] |
| **Solo task force** | Controller | AI smuggler flights + boats | [done] |
| **Co-op crew** | Pilot + co-pilot (+ spotter) | Police | [done] (co-pilot and spotter use the station client) |
| **Versus** | Runner crew vs. controller (+ interceptor pilot) | Empty roles | [done]; controller and spotter use the station client; the interceptor pilot flies in a 3D seat (`RemoteSeat`) |
| **Campaign** | Solo or co-op | Scripted threats per chapter | [done]: chapters 1–4 playable, 5–8 scripted in this doc |

Any seat without a human is filled by AI, so the same match can be played by 1 to 6 people.

## 3. Roles

### Runner side

| Role | Job | Sees | Status |
|---|---|---|---|
| **Pilot** | Flies. Transponder, flaps, autopilot. | Out the window, HUD, radar-detector light | [done] |
| **Co-pilot / kicker** | Loads the aircraft (twice the loading speed), pumps ferry fuel, kicks bales out over drop zones, runs the radio scanner and calls the boat | Tactical map: own aircraft, boat, bales, intercepted police traffic, radar-warning status | [done] (station client + AI fallback) |
| **Spotter** | Watches one airstrip from the ground. Reports police units and roadblocks near it. Can relocate (takes time). | Units within 5 km of the watched strip, reported with a delay | [done] (AI-driven reports; human uses the station client) |
| **Boat captain** | Go-fast boat. Waits at the rendezvous, fishes bales out of the water, runs for the cove. | Surface picture around the boat | [done] AI; a human takes the seat at a 2D desk and right-clicks to send the go-fast |
| **Fixer** | Books jobs, hires spotters, buys gear, manages heat and money between flights | Job boards, the crew, the Family | [done] (section 36) |
| **Mechanic** | Field refuelling from caches, quick repairs at bush strips | The aircraft's true condition, the cost of the work | [done] (section 39) |

### Law side

| Role | Job | Sees | Status |
|---|---|---|---|
| **Controller** (radar/intel desk) | Reads the fused radar picture, classifies tracks, dispatches helicopters, interceptors and cutters, sets radio encryption, requests the aerostat | Radar tracks (with position noise, no identity for non-squawking targets), tips, DF bearings. Never the true runner position. | [done] (station client + AI fallback) |
| **Interceptor pilot** | Flies the chase aircraft and makes the visual ID | Out the window, its own radar | AI [done]; human pilot [done] (`RemoteSeat`) |
| **Coast Guard cutter** | Hunts boats and seizes floating bales | Surface radar | [done] AI; a human takes the seat at a 2D desk and sends the cutter |
| **Analyst** | Works the informant network, fuel-purchase records and tail numbers | Tip feed | [done] (section 34) |
| **Undercover agent** | Plants a tracking beacon on a runner aircraft on the ground | The strip the aircraft is parked at, the odds, their cover | [done] (section 35) |

### Hidden role (versus, [planned])
**The informant.** One runner-side player may secretly be working for the task force. They
score if the crew gets busted and lose if they're caught leaking, so they have to sabotage
quietly (a bad load plan, "forgetting" to pump fuel, calling the boat on an open channel).
This is the social-deduction layer that gives crews a reason to watch each other.

## 4. Gadgets and counters

| Runner tool | What it does | Law counter | Counter to the counter |
|---|---|---|---|
| **Flying low** | Below the radar floor (≈45 m AGL + 9 m per km of range), and behind terrain, primary radar can't see you | **Aerostat radar** (tethered balloon at 2.5 km altitude: huge line of sight, low floor) | Stay out of its footprint; it's winched down in high wind or lightning [done] (HQ season) |
| **Transponder off** | No secondary return, so no identity | An unidentified primary track builds suspicion fast | Keep squawking to look like legit traffic. But turning it *off* while tracked ("squawk lost") is a big red flag. |
| **Transponder on** | You look like a normal charter | You're tracked the whole time you're in coverage; an informant tip names your tail | Only squawk on legit legs |
| **Radar detector** ("fuzzbuster") | Warns when a radar illuminates you, and whether you're above its detection floor | No direct counter (passive) | – |
| **Radio scanner** | Hears police dispatch in plain voice: unit, base, heading | **Encrypted radio** (controller toggle): dispatch becomes garbled static | Encryption slows coordination (dispatch delay +8 s) |
| **Boat radio calls** | Needed to bring the boat to the drop point | **Direction finding**: every transmission gives the task force a bearing, and two stations give a fix | Keep calls short, call from a different spot than the drop, or pre-plan the rendezvous with no call (the boat waits longer, and waiting boats get spotted) |
| **Ground spotters** | Early warning of police at your destination | **Informants**: a hired spotter may leak your destination (a tip with a 3 km circle) | Pay more for trusted spotters [planned], vary destinations |
| **Ferry tanks** | Long runs from offshore, no fuel stops | **Fuel-purchase tracking**: buying ferry fuel at a police field raises a tip chance | Fuel caches at bush strips (fly the drums in first) |
| **Airdrops to boats** | Never land with the goods | **Coast Guard cutters** and the "drop pattern" classifier (a slow, low track circling over water) | Drop fast, drop in the dark [planned], decoy boats [planned] |
| **Decoy flights** [done] (the HQ season's decoy crews) | A clean aircraft flies the obvious route | Controller has limited units: committing to the decoy is the cost | – |

**Resource limits keep the controller honest.** The task force starts with 1 helicopter,
2 interceptors and 1 cutter, each with a launch delay and a fuel endurance. They're
refuelled and recommitted at a base. The runner crew is always cheaper to field
than the full response, which is how the side with less information stays viable.

## 5. Systems

### 5.1 Fuel is weight [done]
- The flight model burns fuel from real tank locations, so the CG moves during the flight.
- The HUD shows endurance and still-air range from the live fuel flow.
- **Ferry bladder tanks** are cargo items (25 lb empty + fuel) that take up a cabin station.
  Their fuel only reaches the engine if someone pumps it into the wing tanks. The co-pilot
  pumps 60 lb/min; solo, the pilot can run the electric pump at 25 lb/min.
- Buying fuel beyond wing-tank capacity at a police field has a chance to produce a tip.

### 5.2 Loading takes time [done]
- Every item moved on the ground takes `4 s + 0.02 s/lb` of crew time. Crew = pilot, plus
  co-pilot, plus the ramp crew at hubs. Loading at a bush strip while the spotter reports
  police inbound is the tension beat.

### 5.3 Airdrops [done]
- Droppable items (bales) are kicked out of the door by a crew member: 2 s per bale for the
  co-pilot, 4 s for the pilot on autopilot. Above 130 kt the door can't be used.
- Each bale is a ballistic object with drag (terminal velocity ≈ 35 m/s) that inherits the
  aircraft's velocity. If it lands in the water, it floats and drifts. If it lands on land,
  it's lost (ground drop zones with a pickup truck are [planned]).
- The boat collects bales within 40 m (5 s each), then runs for the cove. The job pays per
  bale delivered to the cove.
- **Autopilot** (wing leveller + altitude hold) exists so a solo pilot can go aft and kick.

### 5.4 Sensors and the track picture [done]
- Every emitter and target produces a `Signature`: position, height above ground, speed,
  transponder state, recent radio transmissions.
- Sensors (ground radar, aerostat, unit eyeball/FLIR, direction-finding stations) turn
  signatures into **tracks** with position noise and an age.
- AI police steer to the **last known position**, not the truth. Break contact and they
  search the last place they saw you.

### 5.5 Radio [done]
- One message log per channel (`police`, `runner`). Police dispatch is plain voice
  unless encrypted. The runner scanner intercepts plain police messages. Runner
  transmissions can be heard by DF stations.

## 6. Storyline (campaign)

**Setting.** Palmetto Cay, a fictional island between the Florida Keys and the Bahamas,
1979–1986. The tone draws on the era's documentaries and dramas about the South Florida
smuggling boom and the Miami-based task forces sent to stop it (the *Cocaine Cowboys*
documentaries, *Miami Vice*, *American Made*, *Blow*, *Air America*, *Narcos*). All characters
and events here are original.

**Protagonist.** *Jack "Dusty" Callahan*, a bush pilot who owes the bank for a tired
Cessna 172. His sister *Rosa* runs the mail contract and is your first co-pilot. The fixer is
*Manny Arce*, a charming boat dealer from Smuggler's Cove. The antagonist on the law side is
*Special Agent Evelyn Hart*, who takes over the island's interdiction desk in 1983.

| Ch. | Year | Title | Introduces | Objectives | Status |
|---|---|---|---|---|---|
| 1 | 1979 | **Mail Run** | Flying, W&B, short strips | Earn $5,000 legally, land at Eagle's Nest | [done] |
| 2 | 1980 | **A Favor for Manny** | Contraband, radar floors, flying low | Deliver one hot cargo without reaching wanted ★ | [done] |
| 3 | 1981 | **Kickers** | Co-pilot, airdrops, boat rendezvous, radio calls | Drop 4 bales to the *Lady Luck*, 3 must reach the cove | [done] |
| 4 | 1982 | **Long Legs** | Ferry tanks, fuel planning, offshore entry, fuel caches | Fly in from the south entry point with a ferry tank and make a drop | [done] |
| 5 | 1983 | **The Balloon** | Aerostat radar goes up, radar detector, spotters | Complete a run inside aerostat coverage without being tracked for more than 60 s | [planned] |
| 6 | 1984 | **Blue Water** | Coast Guard cutters, encrypted police radio, DF | Make two drops in one night with encryption active | [planned] |
| 7 | 1985 | **The Leak** | Informants, decoy flights, hidden-role versus | Find the leak (one of three spotters) before the big run | [planned] |
| 8 | 1986 | **Last Run / Flip** | Everything | Branch: pull off the biggest run of your life, **or** take Hart's deal and play the finale on the law side | [planned] |

**The task-force campaign** (law side, 1983–1986) replays the same years from Hart's desk:
building the radar net, getting encryption budget approved, turning Callahan's spotters. In
chapter 8 the two campaigns meet: the runner's "Flip" branch hands you Hart's desk for the
final interdiction.

**Difficulty ramp.** Each chapter raises the threat level: 1 radar site in 1979, plus
interceptors in 1981, the aerostat and cutters in 1983, encryption and DF in 1984, informants
in 1985. It also removes a crutch, such as a free loadmaster or a daytime-only schedule.

## 7. Multiplayer architecture

```
 Pilot's game (3D, Godot 4) ─────────────┐   authoritative Session (flight + AI + rules), 60 Hz
   └─ listen server (HostServer, TCP) ───┤   snapshots 15 Hz, filtered per role (fog of war)
                                         │
 Station clients (2D tactical UI) ◄──────┘   TCP, newline-delimited JSON
   co-pilot · spotter · controller           commands -> Session.command(role, name, args)
```

- **Authoritative host.** The pilot's machine runs the only simulation. Remote players send
  *commands* (validated against a per-role permission table) and receive *snapshots* built
  for their side only. A controller snapshot contains radar tracks, never the true runner
  position.
- **Why TCP + JSON now:** zero dependencies, trivial to debug, and fine at 15 Hz on a LAN or a
  decent WAN. Station UIs are map views, so a 100 ms delay is invisible there.
- **Phase 3:** a remote *pilot* (interceptor or second runner) needs UDP with client-side
  prediction of their own flight model (ENet through Godot's MultiplayerPeer), with the
  server reconciling. Snapshots already carry sequence numbers for this.
- **Dedicated server:** `Session` has no rendering dependency, so a headless server is the same
  code minus the window (`godot --headless --script res://scripts/net/dedicated.gd`).

## 8. Balance notes and tuning knobs

| Knob | Default | Effect |
|---|---|---|
| Radar floor | 45 m + 9 m/km | Lower = police stronger; tune per chapter |
| Aerostat floor | 20 m + 3 m/km | Makes flying low necessary but not sufficient |
| Suspicion rate | 8–33 %/s in coverage | How long a runner can clip radar coverage |
| Bust time | ~4.5 s within 350 m | How close an interceptor must fly formation |
| Encryption dispatch delay | +8 s | Cost of denying the scanner |
| Spotter leak chance | 15% per hired spotter per job | Informant pressure |
| Ferry-fuel tip chance | 25% at police fields | Pushes runners to caches |

Balance target for versus: a competent crew completes about 55% of runs against a competent
controller. The AI controller should land at about 70% for new players.

## 9. Roadmap

1. **Phase 1 [done]:** single-player core. Flight-model W&B, tight strips, jobs, radar/wanted, AI police.
2. **Phase 2 [done] (framework):** roles and permissions, command API, event bus, sensors and
   tracks, radio/scanner/DF, spotters and informants, transponder, radar detector, aerostat, ferry
   tanks, loading time, autopilot, airdrops, boats and cutters, AI smuggler, controller mode,
   campaign engine with chapters 1–4, listen server + station client, role-filtered snapshots.
3. **Phase 3 [done] (seats, HQs, bots, balance):** remote 3D seats (co-pilot in the right seat; police
   pilot flying a heli/interceptor with the AI units' envelope, fog-of-war visuals) over TCP with
   interpolation; boss and chief HQ seats and a season of nights (`scripts/sim/hq.gd`, `nights.gd`); decoy
   flights and contract crews; rule layers scaled by player count (`scripts/sim/layers.gd`); a pilot bot flying
   the aircraft, HQ bots, and feasibility / tactical / strategic simulators that drove the balance changes
   in [BALANCE.md](BALANCE.md); textured graphics with low/medium/high presets. Design reasoning:
   [MULTIPLAYER.md](MULTIPLAYER.md).
4. **Phase 4 (depth):** UDP snapshots with prediction, human-driven boats, night and FLIR, wind,
   AEW patrol aircraft, fixer/mechanic roles, the hidden informant, planted beacons, persistent
   career across chapters, chapters 5–8 and the task-force campaign, smarter runner bots.
5. **Phase 5 (content):** bigger map (mainland coast + island chain), more aircraft (from the
   JSBSim-format `L410`, `C130` data), audio, real 3D models, matchmaking and a dedicated server.

## 10. What the Godot build added

- **Engine.** Godot 4.7 (from 4.4), GDScript only: no GDExtension, so a stock editor opens, runs and exports it
  to Linux, Windows and macOS. The simulation is in `scripts/sim/`; the Python-exact RNGs, maths and terrain
  generator in `scripts/util/` stay bit-exact with the Python reference where the fixtures say so
  ([PORTING.md](PORTING.md)). The flight model (`scripts/sim/flight/`, `FlightDynamics`) is the game's own: a
  6-DOF rigid body at 120 Hz with quaternion attitude, reading JSBSim-format aircraft files as data (their
  aerodynamic functions and tables, flight-control channels, mass and tanks, gear contacts, piston and
  turboprop engines with propeller C_T/C_P tables and a constant-speed governor), spring-damper gear with
  rolling, braking and side friction, the ISA atmosphere, wind and Gauss-Markov gusts. It replaced JSBSim
  1.3.1, which the game used to link through a C++ extension. The C172's propeller carries calibration factors
  (static rpm, ground roll, climb against the handbook): its stock tables left a 160 hp engine short.
- **Realism layer.** Weather and moon, pattern of life, canary traps, rival tempers, spare-helicopter
  patrols, nerves ([BALANCE.md](BALANCE.md) entries 14-19).
- **Radar and radio** that behave like the real thing (`sensors.gd`, `comms.gd`): radar horizon, clutter,
  MTI, scan rates, Pd, trails, Mode C, squawk codes and coverage; VHF line of sight, channels,
  push-to-talk length, least-squares DF with an error ellipse, jamming.
- **Upgrade trees** for both sides (`upgrades.gd`), paid from runner cash and task-force funds.
- **Costa Brava**, the city coast and default map (`map_city.gd`): the port city of San Telmo, estuary,
  farm plain, jungle range, quarry, cays; stash houses (`stashes.gd`) with trucked deliveries and raids.
- **Markets** (`economy.gd`): prices per good per market, moved by rivals, police, seizures, gluts,
  fuel, weather and the news.

## 11. The ground war, gun running and arsenals

- **Arsenals** (`arsenal.gd`): the organisation, the task force and Los Cuervos each hold weapons by
  tier (pistols, rifles, machine guns, RPGs) and ammunition. Gun runs bring crates in; on delivery you
  **sell** them at the street price or **stock** your own arsenal. Everything the police seize
  (busted loads, trucks, raided stashes, lost firefights) goes into *their* arsenal and arms their
  patrols.
- **Squads** (`ground.gd`): gang soldiers, Los Cuervos' crews and police patrols, on foot, in cars and
  in trucks, driving the city's roads (`road_graph.gd`). They guard stashes, escort trucks, set
  checkpoints, patrol and raid. Where they meet, a firefight is resolved with Lanchester's square law
  on each side's weapons, cover and morale. Squad-minutes in a zone move the turf, and turf moves the
  markets and the season.
- **Commanders.** Each faction's squads are run by an AI commander by default; a human
  **lieutenant** (runner side) or **patrol commander** (law side) can take over at any time, and the
  boss and chief set the budgets.
- **On foot.** Out of the aircraft you can draw a weapon from your side's arsenal and shoot it out
  with squads near you, who are simulated man by man inside a 300 m bubble.

**What it costs** (section 24, BALANCE entry 29). The live-play simulator steps the war. The organisation's AI keeps a $30k reserve, raises a squad at most every 30 minutes (only when it has none or is outnumbered), and pays soldiers only for the squads it fields. With the war on, three hours end at $50.0k against $62.5k without it.

## 12. Seats: every role AI until a human takes it

Every role in every mode exists from the start and is run by the AI. Humans join mid-game and
claim any free seat from the role picker; leaving (or dropping for more than 30 s) hands it back to
the AI. The host's `Seats` table is the single place this happens. See [MULTIPLAYER.md](MULTIPLAYER.md)
for the protocol, the roster and chat.

## 13. The Agency, and the history the season runs through

**The Company** (`scripts/sim/agency.gd`) is a covert intelligence agency running guns south to
the Contras through the island's strips: a fourth player in the drug war, and the task force's most
awkward opponent. It offers "southern front" arms flights on the shady strips' boards. Carrying its
cargo, or for half an hour after a run, you're protected: a bust is quashed by a call from
Washington ("national security"), and police checkpoints are told to wave your trucks through. A
trusted organisation gets favours (crates of rifles, an informant "reassigned"). Every quash and
flight leaves a trail; the task force can dig (V at the desk: subpoenas and bank records, cheaper
the more cases were quashed) and at 100% exposure the hearings end it: no more protection, the
task force gets the budget, and the organisation's pilots are named in the testimony.

It is fiction inspired by the documented record, not a claim about real people:

- the **Boland Amendments** (1982, and Boland II in 1984) barred U.S. funding for the Contras, and
  the supply effort went private and covert
  ([Boland Amendment](https://en.wikipedia.org/wiki/Boland_Amendment));
- in October 1986 a Contra supply plane was shot down over Nicaragua and its surviving crewman
  talked; the **Iran-Contra affair** broke that November
  ([Iran-Contra affair](https://en.wikipedia.org/wiki/Iran%E2%80%93Contra_affair));
- the Senate subcommittee chaired by John Kerry (the **Kerry Committee**, report 1989) found that
  people involved in Contra supply networks were also involved in drug trafficking, and that U.S.
  agencies were at times aware of it
  ([Kerry Committee report](https://en.wikipedia.org/wiki/Kerry_Committee_report)).
  Stronger claims made later (for example in the "Dark Alliance" series) remain disputed, and the
  game doesn't rely on them.

The **Chronicle** also runs a timeline of real headlines, one per stretch of play, in order: the
1979 Dadeland mall shootout, the 1980 Mariel boatlift, Operation Greenback, the 1982 South Florida
Task Force, the Boland Amendments, Customs' air-interdiction jets and Blackhawks, crack reaching
the streets, the 1986 shoot-down, Iran-Contra, the 1986 Anti-Drug Abuse Act and the Kerry
inquiry. Each moves something in the game: the task force's funds and arsenal, Los Cuervos'
recruits, the markets, and the Agency's exposure.

## 14. The Family, the Company's double game, and the research behind them

**The Family** (`scripts/sim/family.gd`) is a fictional Cosa Nostra crime family, the Morettis,
out of Tampa by way of New York. It runs the docks' union, casino count rooms, bookmakers and a
loan-sharking book. The design rule is that **every helping hand might be a trap**:

- Each offer carries a hidden `honest` flag and a *read* (what our people notice, e.g. "the
  steward was seen at the federal building"). The read is right about four times in five, so
  accepting is a judgement call.
- The offers are: a loan (the con: the vig "changes" and the enforcers come), laundering through a
  count room (the con: a skim and a wiretap), the union at the docks (the con: the Coast Guard gets
  the schedule), a gun fence (the con: a buy-bust), a crew of the Family's soldiers (the con: a
  stash sold to Los Cuervos) and a lawyer (the con: he reports to the prosecutor).
- Honesty falls with greed, low respect and pressure. The task force's RICO case grows; past 60% a
  made man may flip, and a family with a rat in it sells everyone out. At 100% the Commission
  trial ends the Family, and what it knew about our stash houses goes into evidence.
- Unasked, the Family also: levies a street tax on a rich organisation, sells rifles to Los
  Cuervos too, puts a sergeant on the payroll who leaks raids, and moves in on a weak organisation's
  stash.

**Talking to them.** The offers can be taken with a key, or at a sit-down with Sal Moretti
(`dialogue/family.dialogue`, run by Dialogue Manager): he pitches the offer in his own words, your man
gives his read, and you can take it, turn it down, or **press him** - a second read, an independent
roll just as likely right, for two points of respect. Two agreeing reads are right about 94% of the
time; two that disagree are a coin toss. That makes asking a real decision. The tribute can be paid,
refused or **stalled** (five more minutes, once, for five points of respect).

**The Company's double game** (in `agency.gd`, on its own RNG stream):

- The limited hangout: at high exposure it may give our names to the task force itself.
- A stung flight: it hands a flight to the DEA. The notes may say "the contact changed at the last
  minute", a hint that is right about three times in four.
- "The check's in the mail": part of the pay is withheld.
- Both sides: Los Cuervos' planes get waved through too.
- Disinformation, both ways.
- Brokering its cash through the Family's casinos.

### What the research found, and where it went

Fiction built on documented history. No real person appears in the game; events are reported as
the papers did.

| History | In the game |
|---|---|
| The CIA recruited mobsters (Giancana, Roselli, Trafficante) to kill Castro in 1960-63; it came out in the Church Committee hearings (1975); Roselli was later found in an oil drum in Biscayne Bay ([CIA plots on Castro](https://en.wikipedia.org/wiki/CIA_assassination_attempts_on_Fidel_Castro), [Mob Museum](https://themobmuseum.org/blog/mob-attempts-assassinate-castro/)) | The Company and the Family know each other: the Company's cash goes through the Family's casinos with us as go-between; the "drum_found" event (a witness silenced, the RICO case sets back) |
| The Kerry report (1989): the State Department paid Contra "humanitarian" contracts to companies run by traffickers, including SETCO Air and a Costa Rican seafood firm, Frigorificos de Puntarenas, set up to launder drug money ([Kerry Committee](https://en.wikipedia.org/wiki/Kerry_Committee_report), [report text](https://archive.org/stream/KerryCommitteeReport/Kerry%20Committee%20Report_djvu.txt)) | Crates marked "humanitarian aid"; the "shrimp_front" laundering event; the 1989 headline raises the Agency's exposure |
| A cocaine pilot flew out of Mena, Arkansas, flipped to become a DEA informant in 1983, flew a camera-rigged C-123 on a CIA-linked mission, and was shot dead in 1986 ([Barry Seal](https://en.wikipedia.org/wiki/Barry_Seal)) | The "pilot_flips" event; the 1986 headline (informants go quiet); the stung flight |
| Norman's Cay, Bahamas: a private island with a 1,000 m strip, armed guards, dogs and radar, used as a transshipment base (1978-82) ([Norman's Cay](https://en.wikipedia.org/wiki/Norman%27s_Cay), [Carlos Lehder](https://en.wikipedia.org/wiki/Carlos_Lehder)) | The offshore pickup island (next phase) |
| Operation Greenback (1980) followed the cash through the banks; the Opa-locka seizure; Great American Bank fell in 1982 ([Operation Greenback](https://en.wikipedia.org/wiki/Operation_Greenback)) | Headlines; laundering costs; the "bank_collapse" event |
| 1986: a DEA probe of Eastern Airlines baggage handlers at Miami International, who moved cocaine past customs and dogs for years ([CS Monitor, 1986](https://www.csmonitor.com/1986/0214/aline.html)) | The 1986 headline tightens the airports; airport smuggling with bought handlers (next phase) |
| The Pizza Connection trial (1985-87) and the Commission trial (1985-86, bosses convicted under RICO) ([Pizza Connection](https://en.wikipedia.org/wiki/Pizza_Connection_Trial), [Commission trial](https://en.wikipedia.org/wiki/Mafia_Commission_Trial)) | Both headlines raise the RICO case |
| 1988: Noriega indicted in Miami for selling traffickers safe passage; his money sat in BCCI ([Manuel Noriega](https://en.wikipedia.org/wiki/Manuel_Noriega)) | The 1988 headline: laundering costs more |
| Cuba, 1989: General Ochoa and Colonel de la Guardia were executed after a trial for arranging cocaine drops in Cuban waters, handed to speedboats for Florida ([Arnaldo Ochoa](https://en.wikipedia.org/wiki/Arnaldo_Ochoa)) | The island's corrupt officers and their purge (next phase) |

Storylines and jobs these suggest, some of them built next:

- **The island**: a Cuba-like offshore state with cheaper product, corrupt officers selling safe
  passage in its waters, and its own politics. A purge can close the route overnight.
- **Airport runs**: mules and bought baggage handlers at the international airport, against
  customs, dogs and a crackdown after a scandal.
- **Informant flights**: the DEA flips your pilot and wants photographs of the next pickup.
- **The seafood front**: aid contracts that launder money until an inquiry reads the books.

## 15. Isla Soberana: the island trade, the airport and the port

An island republic about 23 km off San Telmo, beyond the map's southern edge (`scripts/sim/island.gd`,
drawn by `scripts/render/island_render.gd`). Its strip (SOB) is landable but isn't one of the mainland's
strips (`MapLayout.foreign`), so the mainland's boards, AI and police are unchanged. It is fiction
inspired by the Ochoa affair (section 14): officers who sold cocaine drops in their waters until
their own government tried them.

- **Cheap product.** The island's board sells loads: a job with a price paid up front ($18/lb)
  worth the street price home ($55/lb before the market). A defector wanting a ride north pays
  well and costs the General's goodwill.
- **Three routes home.**
  - **Air:** the usual game, flown.
  - **Mules:** four on the airliner (Shift+U, or U at the lieutenant's desk). Each is caught
    independently; odds start at 10%.
  - **A container:** 500 lb on the freighter (Shift+I / I). One roll; odds start at 8%.

  Both are timed shipments, resolved on arrival against the odds then. So a crackdown ordered
  after they left still counts.
- **Where it lands.** With logistics on (live play, the dedicated server, the story from 1980), a
  cleared container or a mule run pays nothing on arrival: its pounds go into the stash by the docks
  and the airport (`logistics.site_at("HAR")`, Warehouse 7 by the port), or the nearest stash if
  that one is burned, and warms that stash as any load arriving does. From there it's sold like any
  other load (section 22). Without logistics the
  old instant payout at the street price stays. BALANCE entry 30 has why: 500 lb sold at once, past
  the dealers and the buyers' caps, paid $150k-$800k over a 12-hour story.

  | Factor | Mule caught | Container found |
  |---|---|---|
  | Heat after a catch (decays) | x(1 + heat) | x(1 + heat) |
  | Sniffer dogs (law) | x1.6 | x1.15 |
  | Passenger profiling (law) | x1.4 | |
  | Container X-ray (law) | | x1.7 |
  | Crackdown / inspections (law, 30 min) | x1.8 | x1.5 |
  | Trained mules / forged papers / baggage handlers (ours) | /1.25, /1.3, /2.2 | |
  | False bottoms (ours) | | /2 |
  | The Family's docks deal (honest / a rat) | | x0.5 / x2 |
  | A boatlift swamping the Coast Guard | | x0.7 |

  A caught mule may talk (unless her papers are forged). The desks show the odds and every factor.
- **Sovereign airspace.** South of the territorial line the task force's aircraft break off and
  won't re-acquire. The island's MiGs may intercept a plane that hasn't bought the General's
  passage (a "landing fee").
- **The island's politics.** Hurricanes hold the freighters and close the strip's board; shortages
  raise prices; a glut drops them; a boatlift swamps the Coast Guard; the General's birthday. A
  purge (random when relations are low, or the 1989 headline) closes the island: no loads, no
  passage, and soldiers on the ramp for whoever lands.
- **The General's aide.** Captain Ibarra (`dialogue/general.dialogue`) meets you on the ramp when
  you land and answers the island frequency (Shift+G, G at the lieutenant's desk). He sells passage,
  gives the island's news (and a warning when the General's friends are in danger - relations
  under 40 are where purges happen), and takes orders for mules and containers, with customs' current
  odds in the answer text. During a purge a stranger answers.

## 16. The court: lawyers, bail, pleas and juries

Without a court a bust is a fine and the impound. With one (`scripts/sim/court.gd`, `court: true`
in live play, RNG seed + 107), a bust opens a federal case against the pilot. It is modelled on
how 1980s South Florida drug cases ran, with invented lawyers and judges.

| Stage | What happens | Choices |
|---|---|---|
| Arrest | Charges from the case: possession (any load), importation and trafficking (over 150 lb), a firearm (weapons aboard, or armed strip guards), conspiracy (a heavy case). Evidence is built from the load, the task force's suspicion, informants, an undercover agent, witnesses (arrested soldiers talk), and whether there was a chase. The load is seized as evidence. | - |
| Bail hearing (90 s) | A judge is drawn: Pike (hard), Ruiz (by the book) or Dunne (lives well for a judge). Bail is $10k per charge weight × the judge × 1.5 for a flight risk (rich, or the General's friend). | Post it all (returned at trial), a bond (10%, gone), or custody. The prosecutor can ask for no bail. |
| Pretrial (20 min) | On bail you fly; a new arrest revokes it (+15 evidence). In custody the aircraft sits and you can fast-forward. | Hire a lawyer; file motions (suppress, discovery, continuance); lean on a witness or pay the judge through the Family; take a plea; sign a cooperation deal. |
| Trial | Conviction odds: logistic((evidence − 50)/12 + judge bias × 3 − lawyer skill × 2.2 + 0.25 per witness + jury noise). A close jury can hang (retrial in 10 min, evidence −10). | Skipping the trial on the island makes you a fugitive: failure to appear, a warrant, the bail forfeit. |
| Sentence | Years from the charges × the judge (trafficking has a 10-year minimum after the 1986 act), 2 game minutes a year up to an hour. A fine plus 30% of the cash (80% to the task force), and the aircraft is forfeited. | One appeal (15% + 40% × the lawyer's skill to reverse); or wait it out. |

**The lawyers.**

| Lawyer | Cost | Skill | Notes |
|---|---|---|---|
| The public defender | free | 0.15 | |
| Arturo Vega | $6,000 | 0.4 | |
| Roy Kessler | $25,000 | 0.65 | |
| Leonard Castellano | the Family's offer | 0.7 | If the Family's offer was a con, he works for the prosecutor: +1.5 on the trial's odds and worse pleas. |

Skill drives three things:
- **Suppression:** 10% + 50% × skill, +25% when the stop had no cause (a random landing check below 40% suspicion). Success takes 30 points off the evidence.
- **The trial's odds** (the formula above).
- **The appeal.**

**Off the books.**
- **Leaning on a witness** ($5,000 to the Family): 35% it becomes obstruction (+20 evidence, bail revoked); otherwise one witness fewer and −12 evidence.
- **Paying Judge Dunne** ($20,000): 30% it's a sting (45% with an undercover agent), and Judge Pike takes the case; otherwise the judge leans your way.

**Deals.**
- **The plea:** the top charge at 45% of the years (30% on the second, lenient offer), more as the evidence grows.
- **Cooperation:** a tenth of the time. In exchange every stash house gets +35 police intel, the Family's respect drops to 0 and its RICO case jumps, and the organisation's soldiers lose heart.

**The task force's side** (controller's desk N W K D Y, or the AI prosecutor when nobody human
sits the law's chair):
- no bail;
- immunity for a crewman ($4,000: +1 witness, +10 evidence);
- the bank records (a civil forfeiture: 20% of the cash, 80% of it to the task force);
- a conspiracy count (at 50% evidence);
- a plea offer.

**The lawyer's conversation** (`dialogue/lawyer.dialogue`, Shift+L, L at the desks) walks
through all of it: the hearing, the case as he sees it (the exact odds once discovery is in),
each option, the witness and the judge in lowered voices, the deal, and the appeal.

## 17. Hired hands: the payroll, and NPCs in every system

`scripts/sim/payroll.gd` (`payroll: true` in live play, RNG seed + 109). Both outfits, the
organisation and Los Cuervos, hire people and pay them.

| Role | Wage / payday | What they do | If lost |
|---|---|---|---|
| Soldier | $80 | Crew the ground war's squads. An outfit raises a squad only from soldiers on its payroll; events and the Family's lent crew are exempt. | Men lost in a fight are 40% arrested, 60% dead |
| Driver | $100 | Takes a stash truck through the checkpoints; a sharp one talks his way past (skill × 40%). No driver hired means a street driver: triple fee, less loyal. | Arrested when the truck is stopped |
| Mule | $60 | Flies the island's airliner run (a practised mule is harder to read: odds × (1.2 − 0.4 × skill)). Short of mules, street mules. | Arrested when caught at customs |
| Lookout | $50 | Posted at a stash house, sees a raid coming (35% + 45% × skill; not if disloyal). The house comes up empty and cold. | - |
| Accountant | $250 | Clean books cool the task force's case every payday (−4 × skill). A sour one skims 5% of the cash. | Knows the most (flip weight 1.5) |
| Contract pilot | $300 | Flies a run of his own every 20 min: $2,400–3,600, less likely as the case heats up. | A bust: arrested (or dead) |

**The labour market and loyalty.**
- Candidates refresh every 10 minutes. Skill shows; loyalty shows only as a hint ("did two years
  and never said a word" vs "asked a lot of questions about the money"), right about 80% of the time.
- Hiring costs two wages up front.
- Each payday pays the loyal first. Paid workers gain +0.02 loyalty; unpaid ones lose 0.25.
- Under 0.35 loyalty, each payday brings a 15% chance of trouble:
  - they skim $500–2,000;
  - they walk off the job;
  - they tip the task force (a stash house, the suspicion, weighted by what they know).
- A bonus (a wage each) buys +0.1 loyalty.
- A fired man with a grudge may talk.

**The jailed.**
- Arrested workers get their own cases (15 minutes).
- A flip's chance is 35% × (1 − loyalty), which:
  - halves if the outfit paid a $2,000 lawyer (and the crew sees you look after your own);
  - doubles with the prosecutor's deal (A at the controller's desk);
  - is 1.5× for street hires.
- A flip gives up what he knows:
  - for the organisation, stash-house intel and suspicion;
  - for Los Cuervos, cash seized and their corners raided.
- Otherwise the worker is convicted (gone) or released (back to work).

**NPCs in every system.**
- Los Cuervos' AI hires, pays (from the cartel's cash), loses and flips people the same way. It
  sends containers of its own through Isla Soberana's customs every 20 minutes: a glut on the
  street, or the task force's seizure.
- The organisation's AI (when no human boss or lieutenant sits):
  - hires to its needs (soldiers, drivers, lookouts per stash, mules for the island, an
    accountant and a contract pilot when rich);
  - posts lookouts at the hottest houses;
  - pays lawyers for the jailed who know things;
  - gives bonuses when the crew is sour;
  - lays people off when the money runs out.

The AI prosecutor and the Family were already NPCs in these systems (sections 14, 16).

**The hiring hall** (`dialogue/crew.dialogue`, Shift+W / W): Manny Ortega shows four candidates
with their skill, wage and the hint, and handles bonuses and lawyers for the jailed.


## 18. The street: supply and demand, and the Company's pipeline

Prices were a random walk with premiums (rivals, police, seizures, gluts, news). Under it there is now a street
(`scripts/sim/market.gd`): for each hot good (cocaine, marijuana, guns) and each market, **supply** and **demand**
(1 = normal); for each market a **disruption** of its distribution network; for each good an upstream
**source**. The street price follows (demand / supply)^0.55, clamped to x0.55-x1.9. Supply relaxes toward
source x (1 - 0.6 x disruption) in about 15 minutes. Demand recovers in about 40, networks heal in about
25, the source in about 60.

**What moves it** (the session's event bus):

| Event | Effect |
|---|---|
| The pilot busted, a cooperation deal, an informant | the organisation's markets (its stash-house zones) lose their corners |
| A worker arrested | a smaller hit to that outfit's markets |
| A long sentence | the whole street goes quiet for a while (demand down) |
| A stash house raided | that zone's network broken, its product off the street |
| A truck or a go-fast seized | supply falls there |
| A hijacked load | sold in Los Cuervos' strongest market |
| A gunfight | corners close while it lasts; every man arrested or down is a dealer off the street |
| A Los Cuervos container through customs | floods the docks |
| Their plane busted | dries up their market |
| The Commission trial | the Family's fall takes the town's network and its gun fence (guns short island-wide) |
| A hurricane or a purge on the island | chokes the source: the island's wholesale price rises and its connection restocks slower |
| A glut on the island | reaches the docks |
| An airport crackdown | fewer mules get through: the town runs short |
| The street's own news (own table) | spring break, a bad batch, a crusade, a new disco |

The island's loads are now paid at today's street price when they land: mules in town, containers through the
port in town. A dry street pays more; your own flood pays less. Los Cuervos' island loads earn at the street
price too, so the market feeds the rival's war chest.

**The Company's pipeline: cocaine north, guns south.** As the Kerry Committee described the Contra supply
networks (section 14). Every 15 minutes, while the Agency is in business:
1. Its contacts buy cocaine upstream (the island's wholesale rises a little).
2. Its protected planes land it on one market's street: a flood, cheap cocaine there, which hurts the
   organisation's cocaine trade.
3. The proceeds buy guns off the street and out of the fences' hands, and buyers bid for what's left: guns get
   dear in town and the west, which is good for our gun running and the fence.
4. The war chest puts more southern-front flights on the boards, and "return legs": protected cocaine flights
   north for us to fly.
5. Every cycle leaves a trail (exposure). The task force sees the pattern: cocaine prices crash where the
   unregistered flights land, and a buyer takes every gun. A hangout pauses it for an hour; the hearings end it.

In the live simulator (BALANCE section 7), cocaine in town swings between about x0.64 and x1.7 of its usual price in
a 3-hour run with everything on (x0.6-x1.4 without). Guns average x1.37 with the Company buying (x1.12
without). It flies about 24 lots north and buys about 25 lots of guns per run.

Its own RNG streams (the street: seed + 113; the pipeline: seed + 127). Off with `Economy.REALISM`, like the
rest of the market, for the Python replays.


## 19. The trade: stock, dealers, buyers, and grass before cocaine

`scripts/sim/trade.gd`. The organisation now holds product: pounds of cocaine and marijuana in its stash houses.

**Own loads.** The job boards offer our own loads alongside the courier work:
- **Grass** at the bush strips (the farm): about $2 a pound, 200-500 lb a load. It's bulky, so weight and balance
  bite.
- **Cocaine** from the Colombian connection at the shady strips: about $22 a pound, 40-170 lb a load.

Both are paid up front, flown to a stash strip, and go into the stash. A raid takes 30% of what's there.

**The career** (live play, `career: true`). It starts with grass, the way the 1970s smugglers did: cheap, bulky,
less heat. The Colombians only call once our dealers have sold 1,200 lb of grass, we've landed two tons of it in our stashes, or made $25,000 in the trade. Until then
there's no cocaine work on the boards, no island trade, and no return legs for the Company.

**Street sellers.** Dealers are a payroll role for both outfits (hire them from Manny).
- They're posted to the outfit's corners: ours where our stash houses are, Los Cuervos' where they hold turf.
- Each dealer moves 0.6 lb of cocaine or 5 lb of grass a minute, at the street price, scaled by skill.
- Competition matters: each of the other outfit's dealers on the same corner takes 12%, and Los Cuervos' hold on
  the market takes up to 40%.
- Their sales put product on the market's street, so the price softens.
- The police pick dealers up, more often where police are thick and for cocaine (the market's arrest hooks
  follow).
- A gunfight in their market can take them.
- Los Cuervos' AI sends a squad at markets where two or more of ours sell and it holds a quarter of the turf.

**Bulk buyers.** Talk to Benny Ruiz: SHIFT+B in the pilot seat, M at the boss's, lieutenant's or co-pilot's
desk.

| Buyer | Takes | Pays | And then |
|---|---|---|---|
| The Moretti family (respect 25+) | cocaine, grass, rifles | 72% / 80% of the town's street; the fence's price for rifles | sells the drugs on in town (more on its street); arms its crews against Los Cuervos (their cash suffers); respect +2 |
| The Company (in business, not hung out) | cocaine, rifles | 85% of the north's street; 130% of the fence for rifles | cocaine into the pipeline's war chest and its next load north; rifles south (guns scarcer here); trust +, exposure + |
| Los Cuervos | rifles | 120% of the fence | their armoury grows (they fight better, us included); guns in the west; our suspicion rises |

Each buyer has only so much appetite (it refills over 30 minutes). With no boss in the chair, the organisation's
AI sells whatever its dealers can't move in two hours to the best buyer.

**The law.**
- A street sweep (M on the law's desks, $2,500) picks up 45% of the dealers in the market under the mouse, ours and
  theirs, and breaks the corner.
- Following the money (T, $4,000) traces the Company's pipeline:
  - it adds exposure;
  - a quarter of the war chest is forfeited to the task force;
  - it names the market where the next load lands.

  Our bulk sales from the last hour are in the trail too (suspicion +4 each).

**Balance** (BALANCE section 7, entry 27). The trade config ends at $72k cash plus about $20k of product
(control $70k), with the Colombians calling after about 75 minutes.


## 20. Sea fog, and the town's side streets

**Sea fog.** Advection fog forms when warm, moist air drifts over cooler water on calm nights. A breeze or a storm clears it, and it can sit on a coast for hours.
- **When it happens.** `Session.set_weather` rolls it on its own stream (`seed + 137`), but only when live play asks with `fog: true`. The replays and the balance sims never see it.
- **The roll.** On a night that isn't stormy, with wind of 10 kt or less, there's a 30% chance of fog, with a density of 0.4-0.95. The HQ season's forecast can also set `fog` outright.
- **The effect.**
  - The crews' visual range is multiplied by `1 - 0.65 x density`.
  - Above 0.75 the helicopters are grounded: no heli launches, since nobody flies a helicopter at night in 500 m visibility.
  - The radar, the transponder and DF are unaffected. That is the point of the trade-off: in fog the runner can slip past eyes, but not a controller who is watching the scope.
- **On screen.** Exponential fog (visibility about 3/density), about 2 km at 0.4 and 700 m at 0.8. It swallows the sky and is tinted pale grey by the sun or the town's glow.

**Junctions.** The city shader draws a street grid every 110 m. The street furniture now puts a traffic light at every third crossing of that grid inside the urban land use, not only where the arterial roads meet, so downtown reads as a town of blocks rather than a handful of highways. That gives 26 sets of lights on Costa Brava.

## 21. The story: Costa Brava, 1979-1989, and the open mode

The game had grown a dozen systems, all on from the first minute. The story (`story.gd`) opens them one chapter at a time. A new player meets the trade before the war, the war before the Family, the Family before the court, and only then the island and the Company.

| Chapter | Year | Opens | Goals |
|---|---|---|---|
| Square Grouper | 1979 | trade (grass only), payroll, the papers | 300 lb of grass landed, a dealer on a corner, $4,000 from the trade |
| The Connection | 1980 | logistics | $3,000 of street money home; the Colombian connection calls |
| Cocaine Cowboys | 1981 | the street war, gun runs and gun sales, soldiers | 60 lb of cocaine flown home, 8 weapons in the armoury |
| Family Business | 1982 | the Moretti family | a deal with them (offer, loan or bulk sale); $30,000 in the bank |
| The Task Force | 1983 | the federal court | 3 hot loads delivered, the case under 60% |
| Isla Soberana | 1984 | the island, mules | a load home from the island |
| The Company | 1985 | the Agency | a job for the Company, 4 guns sold to it |
| Kingpin | 1986 | (all open) | $65,000 in cash, stock and street money |

**How it works**
- `Session.enable_system(key)` builds a system mid-game. Each system has always had its own random stream, so one that arrives in 1983 behaves as it would have from the start.
- `Session.unlocked(key)` answers the finer locks: guns (gun runs, gun buys and sales), and which roles the hiring hall offers (soldiers, mules).
- **Goals.** Goals are read from the event bus (`job_delivered` now says which good, how many pounds, whose job and where from; `cash_home`; `bulk_sale`; `island_shipment`) or from state: dealers on corners, the connection, the armoury, money, net worth.
- **Softlocks.** A faction that's gone first (the Commission trial convicts the Morettis; the Company is burned or hangs us out) satisfies its chapter, so the story can't strand you.
- **Saves and entry points.** The story is saved in `story.json`, and loading rebuilds every system its chapters opened. `--chapter N` skips ahead.
- **Open mode.** `--unlocks open`, or the lobby's Unlocks: Open, has everything from the first minute, cocaine included. A new open game starts with a $10,000 float (`Session.OPEN_FLOAT`, Benny Ruiz fronts it; the story starts on $3,000). BALANCE entry 34: at $3k the safe dips below zero in the worst tenth of runs, from $10k it doesn't, and more up front mostly buys a bigger war.

**Pacing** (BALANCE §7, 40 AI runs of 12 hours with the street war on from 1981; a flight every 15 minutes rolls the tactical sweep's odds, `AirRisk`):

| Chapter | Reached by the AI |
|---|---|
| 1980 | about 1 hour, every run |
| 1981 | about 3 hours, every run |
| 1983 | about 5.5 hours, 92% of runs |
| 1985 | about 7 hours, 85% of runs |
| 1986 | about 8.5 hours, 80% of runs |
| The end | 62% of runs finish within 12 hours, at about 8 hours |

The stand-in's flown runs count as the pilot's deliveries (every other one hot), as a player's jobs do. The island's product lands as stock (section 15), so it's sold at the street's pace, not paid on arrival; the Kingpin's goal went from $200k to $80k with it (BALANCE entry 30), then to $65k once the stand-in's flights could be busted or crash (entry 31: about 2 busts and 2 crashes a story, $8k in fines and $5k in repairs).

A human who trucks the cash home without waiting for the AI's pickups goes faster.

## 22. Logistics: stock and cash have places

In the 1980s cocaine trade, the product and the money were both physical, heavy and exposed: a stash, a count house, cash in duffel bags, a courier. `logistics.gd` makes them so. It's an opt-in system (live play and the dedicated server ask for it; in the story it opens in 1980).

**Where things are**
- **Product** sits in a stash house: the one at the strip its load was bought for. `Trade.stock` becomes the total of all the stashes.
- **Dealers** sell only what's in a stash in their own market. Their takings go into that stash's cash, not the safe.
- **Island product** lands in the stash by the docks and the airport (Warehouse 7), or the nearest one if it's burned: containers and mules alike (section 15).
- **Street money** stays in the stash until moved. The organisation's `money` is the club's safe (Club Tropicana, the HQ), which pays wages, loads, lawyers and upgrades.

**Moving it**
- **Trucks** (`move_goods`, `move_cash`, and a bulk sale) are StashNet trucks. They take the road graph, face roadblocks and the street war's checkpoints, tails and hijacks, can have escorts, and draw a payroll driver or a day driver.
  - A seized truck forfeits everything to the task force: half the cash goes to its funds. It adds suspicion: +4 for cash (a laundering lead), +6/+10 for product.
  - A hijacked truck's cash goes to Los Cuervos.
- **Bulk sales** are trucked to the buyer's meet and settled there at that moment's quote. The cash, and anything the buyer wouldn't take, rides back to the stash on a second truck, which is exposed too.
- **Cash bags.** $4,500 of street bills weighs about a pound. `load_cash` / `unload_cash` work at a stash's strip, or at the club's strip (HAR, whose bags go to the safe). The bags ride in the load planner as hot cargo, and a bust takes them.
- **Sellers.** An own load is paid for from the bags aboard: the growers and the connection want cash on the strip.

**The AI boss**
- Collects any stash holding $1,000+ after 20 minutes, and batches past $8,000.
- Sends one cash truck at a time, and past $3,000 when the safe can't meet the payroll.
- Moves product at most every 10 minutes, to markets where it has dealers and no stock.

**Balance** (BALANCE §7, entry 28). The trade configuration with logistics ends at $55.8k in the safe plus $10.4k still out, against $71.8k without: about 8% less, lost to money in transit and trucks lost (about $900 and 120 lb a run).

**On the road** (balance entry 29):
- **Drivers watch the road.** Police ahead on the route (a checkpoint, or a patrol that isn't busy) and the truck pulls over until they've gone or an escort arrives. Only a patrol that turns up right on top of it still catches it by surprise.
- **Patrols and checkpoints differ.** A passing patrol pulls a truck over a quarter of the time, half if it's heading for a stash the police know; a checkpoint stops everything.
- **Our own vans are quieter.** A van between our own places warms its stash a third as much as a load off an aircraft, and a cash truck to the club leaves nothing to tail.
- **Losses are recorded by cause** (`lost_by`): seized, hijacked, raided, bust.

**Seeing and guarding them**
- **The maps.** The runner's maps (minimap and desks) colour our trucks by what they carry (`truck_info`): cash, product, guns, a buyer's lot, a load off an aircraft. Each has a line to its destination, and a ring when it has pulled over. The task force's map still shows plain dots.
- **Escorts.** `escort_truck {job_id}` (pilot, boss, lieutenant; the panel's **Escort** button) orders the nearest free squad of ours to ride with the truck. A checkpoint then gets a fight instead of a search, and an ambush meets guns.

**The Company collects** (`meet_pos`). It keeps no shop: its plane lands at the strip nearest the goods (never a police strip), the way the Contra supply flights did. Its lots take a short drive, not a run through Los Cuervos country to a hangar up north.

**Guns** (`Logistics.send_guns`)
- **One armoury, one place.** It's `Arsenal.cache` (a stash), or the club.
- **Gun sales** (to the Morettis, the Company, Los Cuervos) are trucked from the armoury to the buyer's meet and settled there, rifle by rifle against the buyer's appetite. The cash, and whatever the buyer didn't want, rides back.
- **`move_armoury`** trucks the whole rack to a stash or the club, and the cache moves when it arrives. While it's on the road, nothing is in the rack for the squads.
- **Losses.** A seized gun truck goes into the police armoury (`_seize_weapons`); a hijacked one arms Los Cuervos.

## 23. The tutorial (optional)

`tutorial.gd` is a layer over any mode, not a mode of its own. A new player learns the game they chose, and the story's pacing does the rest.

**Lessons**
- Each lesson finishes on evidence that you did it:
  - an event: `job_accepted`, `job_delivered` (with its good or the Company's flag), `cash_home`, `bulk_sale`, `island_shipment`;
  - the state: airborne above 300 ft, a dealer on a corner, cash bags aboard, the transponder toggled;
  - or a note from the seat's UI: the load planner opened, stepping out on foot, a talk opened.
- The first lesson not yet done whose system is in the game is the one shown. So the list grows as the game does, and the panel counts only what can be taught now ("2/9").
- In the story, a newly opened faction's lesson comes up when its chapter begins.
- **Everything added since the first cut is taught too:** the phone, the starter car, the car radio, squad orders (Z/X/C/V), renown, the collectors, stash works, rounds, the arena (each waits for its system; `renown`, `rackets` and `races` are needs like `trade`). They finish on the thing itself: a menu opened (`menu_phone`, `menu_rackets`), the car entered, the radio on, the command succeeding (`field_order`, `stash_works`, `cash_round`/`goods_round`), a race run (`race_run`), a name of 40 points. A one-off tip says what to do with prisoners.
- **The ending.** When the last lesson the game can teach is finished a closing card ("TUTORIAL COMPLETE - That's the tour") stays up 40 seconds (`Tutorial.GRADUATION_S`); new lessons appear later if more of the game opens up.

**Tips.** Tips are one-off. They fire on the moment (wanted, fuel under a quarter, busted with a court, fog, storm, a payday the safe can't cover, a raid, a stopped truck, the connection) and stay on screen for 20 seconds.

**Control and persistence**
- F10 skips a lesson; SHIFT+F10 turns the tutorial off or on.
- The lobby ticks the box for the first game only (`tutorial_seen` in `user://settings.cfg`).
- Progress (lessons done, tips shown, on or off) is saved with the game.

**The desks** (`DESK_LESSONS`)
- **Their own lessons.** Every seat has its own, written in that desk's real keys:
  - the boss: orders, K logistics, M buyers;
  - the lieutenant: squads, raising them, W the hall, C the Family;
  - the controller: launches, X raids, M sweeps, T the money, O RICO, L/P the airport and port, the prosecutor's keys;
  - the chief: orders, the street;
  - the patrol: squads, RICO;
  - the co-pilot: the crew keys.
- **Finishing.** A desk lesson finishes when that role's own command succeeds (`Session.command` tells the tutorial), so it works from a remote seat as well as a local one.
- **Display.** The snapshot carries the seat's view, and the desk shows it over the map.
- **Keys.** F10 and SHIFT+F10 go through the `tutorial` command, which every role may send.
- **Saving.** Progress per role is saved with the game.

## 24. What the street war costs

The live-play simulator steps the war now (balance entry 29). It stands in for the police's cooling of the case with a tenth of `PoliceSystem.SUSPICION_DECAY`, since the war keeps them looking.

**The first measurement.** The organisation's AI was a spendthrift:
- It raised squads whenever it held $12k and bought rifles past $15k.
- It paid eight soldiers whether or not it fielded a squad.
- It hired a $2,000 lawyer for every corner dealer the war put in a cell.
- The result: $26k after three hours against $58k without the war.

**The guerrilla doctrine now applies to the money too:**
- **Reserve.** $30k is kept before anything is spent on the war (`GroundWar.ORG_RESERVE`).
- **Recruiting.** A squad at most every 30 minutes (`ORG_RECRUIT_S`), and only with no squad in the field or Los Cuervos outnumbering us.
- **Soldiers.** Paid for the squads fielded plus one in reserve (`Payroll.needs`).
- **Lawyers.** Only for the jailed who know a lot: the accountant, the contract pilots. Corner dealers talk a little more often as a result (0.7 flips a run).

**Now:**
- $50.0k against $62.5k over three hours: the war costs about a fifth.
- Suspicion cools between the runs.
- About 0.7 stash houses a run are burned.

## 25. Renown (Mount & Blade's renown)

How big your name is on the street. It is made of what the organisation does and is read off the event bus
(`scripts/sim/renown.gd`; a session asks for it with `renown: true`, and the live game does):

| Gains | | Losses (half of the same size) | |
|---|---|---|---|
| a load delivered | +3 | the pilot busted | -3 |
| bales delivered | +2 | the pilot sentenced | -4 |
| an island container through customs | +3 | a crash | -1.5 |
| a raid foiled | +3 | a stash raided | -2 |
| a jury lets the pilot walk | +6 | a truck hijacked / seized | -1.5 / -1 |
| the case dropped from above | +4 | a flight hijacked | -1 |
| a bulk sale | +1 to +5 by size | a boat seized | -1.5 |
| the money home | +0.3 | one of our men takes the government's deal | -2 |

It never goes below nothing. Five tiers (0 Nobody, 40 A name on the street, 120 Known, 300 Feared, 650 A legend); a
tier going up is said ("RENOWN - Known. Better recruits (+6 skill), buyers pay +3.0%, and the task force cools 12%
slower."). What a tier is worth:

- the hiring hall: every candidate has +3 points of skill and +2 of loyalty a tier (no extra random draws: the
  payroll's stream is the same, only the values shift);
- the bulk buyers pay 1.5% more a tier;
- the task force watches the famous: suspicion cools 6% slower a tier (`PoliceSystem.decay_mult`).

The phone shows the tier and the score on its title line; a save keeps the score (`StrategicSave`). BALANCE entry
(the list's "Renown"): a +0.5% to +3% effect on money, with the task force a little warmer, by design small.

## 26. Veteran squads and the orders on the ground (Mount & Blade's troops and battle commands)

**Experience** (`GroundWar.VETERANS`, `Squad.xp`). A fight a squad survives is worth 1, a fight it wins 2 (and
breaking off from one is 1 for both). A squad that has lost half its men loses half its experience first: the
good men are the ones who died. Four ranks:

| Rank | Experience | Fire per man | Breaks at morale | Upkeep |
|---|---|---|---|---|
| Green | 0 | x1.00 | 0.30 | x1.00 |
| Blooded | 4 | x1.07 | 0.26 | x1.25 |
| Veteran | 10 | x1.14 | 0.22 | x1.50 |
| Elite | 20 | x1.21 | 0.18 | x1.75 |

A rank-up is said on the desk's message line ("S-2 is now veteran."), the desk's squad table shows the rank beside
the men, and the save keeps the experience. Both sides learn: the rival's and the task force's squads rank up too.

**Field orders.** On foot, with a ground war: **Z** hold, **X** come to me, **C** charge, **V** fall back. The order
goes to the nearest squad of ours within 250 m (`GroundWar.field_order`; the command `field_order` is the pilot's,
the boss's and the lieutenant's): *come* walks it to where you stand, *charge* sends it at the nearest rival or
police squad it can see within 450 m of it (a hidden squad cannot be charged), *fall back* is the melt order (to
cover, out of sight), *hold* stops it. A squad given an order is under a human's hand and the AI leaves it alone.

## 27. The rackets: tribute, and the men we take (Mount & Blade's villages and prisoners)

`scripts/sim/rackets.gd`, with a ground war and `rackets: true` (the live game); the phone's **The collectors**
opens the menu, `rackets` is the boss's, the lieutenant's and the pilot's command.

**Tribute.** Every 10 minutes the collectors go round the four markets (town, west, north, sea). A market in which
the organisation holds more than half the street (`GroundWar.org_share`) pays `$160 x (share - 0.5) x 2`, so $160
at full control, times the name you have (Renown's price multiple). Each market has terms, cycled with ENTER:

| Terms | Pays | Costs |
|---|---|---|
| fair | the amount above | nothing |
| squeeze | 2.2x | our hold there drops by 15% a round, and the case against us warms by 2 |
| off | nothing | nothing |

**Prisoners.** When one of our squads routs one of Los Cuervos', a third of what is left of it is taken (a squad of
three or fewer gives nobody up). The menu's keys: **A** ransom them (Los Cuervos pay $350 a head, up to what cash
they have; the men go back), **F** put them on the payroll (they come as soldiers: skill 0.3, loyalty 0.25, so a
bad risk, at the street rate), **G** let them go (half a point of renown a man). Held men get away at one in eight
every 10 minutes (a group under eight is guarded).

The save keeps the terms, the prisoners and the total collected.

## 28. Stash works (Mount & Blade's village improvements)

`scripts/sim/stash_works.gd`. Two works at each live stash house, two levels each, bought from the safe in the
logistics menu (the row "Build at the house in from"; the `stash_works` command is the boss's, the pilot's and the
lieutenant's). The levels are kept on the stash (`works`), so a save keeps them and the stash net, the logistics view
and the raid all read them where they stand.

| Work | Level 1 | Level 2 | Does |
|---|---|---|---|
| Hidden vault | $2,500 | $6,000 | a raid carries off 35% less of what is inside, a level; the rest is spirited away to another house (cash straight to the safe) |
| Guard post | $2,000 | $5,000 | traffic warms the house 20% less, and its heat cools 25% faster, a level |

A burned house cannot be improved. `StashWorks.ENABLED` switches it off (every level then counts as 0).

## 29. The arena (Mount & Blade's tournaments)

`scripts/sim/races.gd`, `scripts/game/race_markers.gd`; the phone's **The track** lists the courses at the strip you
are at (`race_enter` is the pilot's, the boss's and the lieutenant's command).

| Course | Where | Gates | Par | Entry | Prize |
|---|---|---|---|---|---|
| Street race (the car) | a loop on the roads from the strip through the two nearest of the club and the stash houses and back (the nearer one alone if that would pass 10 km; 3 to 12 km in practice); needs a ground war | every 500 m, 24 m radius | length / 19 m/s | $70 | $700 |
| Air circuit (the aircraft) | six gates 2.5 km from the strip, round and back to the first | 130 m radius, 180 m above the ground, 110 m tolerance up or down | length / 42 m/s | $140 | $1,400 |

The first gate is the start: the clock begins when you cross it and the gates have to be taken in order (the next one
is a glowing ring with a beam, the one after it a dim ring). A field of four rivals runs at par x 0.85 to 1.35 (their
times come from a stream seeded by the session and the course, so the field is the same every time). Your place in
the field is the prize: first the whole prize, second half, third a quarter, and renown +6 / +3 / +1. A course pays
once an hour (after that it is for the glory). You are out, and the fee is gone, if you get out of the car mid-race,
land from the circuit or take three times par. The save keeps what each course last paid and the winnings.
`Races.ENABLED` switches it off.

**The race chip and the book.** A chip on the HUD says where you are ("RACE  The Smuggler's Cove dash  gate 4/11  1:12.4
par 4:42.0", or "take the start gate" before the clock runs). The track menu (the phone's *the track*) takes a bet on
yourself: B cycles the stake ($0 / 100 / 200 / 300), N chooses a win (pays 3x the stake, the stake is not returned) or a
place (top three, 1.5x). The stake is paid with the entry and is lost if you drop out. The book is only open on a race
that is paying, a course that paid within the hour takes no bets, so betting cannot be a faster way to the same money.
The save keeps the book's running total.

## 30. Effects and lighting (the 2026-10-03 upgrade)

**Fire** (`FX.burn`): three layers - an outer flame (Kenney `fire_01`), a white-hot core (`flame_04`) and embers that drift up
(`spark_01`) - drawn additively at HDR brightness (the material's albedo is above 1, so the glow bloom catches it), a
light that flickers (three beating sines, a phase of its own per fire) and a charred patch on the ground. The smoke is
lit orange by the fire at its foot, then soot, then a thin grey veil: soft, so the flames show through it.

**Blasts** (`FX.blast`): a one-frame white flash, a fast fireball and a slower rolling one, sparks, a dust ring flung along the
ground, a shock ring racing out over it, a mushroom of smoke with a broader grey cap, debris, a scorch mark that stays
45 s, and a light that spikes to 12 and fades over two seconds. Bullets that hit a wall or the ground throw sparks and dust
(`FX.impact`). A blast nearby shakes the camera (`FX.shake_at`: up to 0.18 m of Camera3D offset, by size, distance and
the 1.6 s after it).

**Street lamps** (`StreetLights`): the town's lamp heads are glowing meshes, far too many to be lights, so a pool of
OmniLights (5 on medium, 10 on high, none on low) follows the lamps within 90 m of the camera: warm sodium pools on the
road and pavement at night.

**The car's headlights**: two spot lights come on at night (the scene's night above 0.35) while you drive.

## 31. Voice chat that works like a radio

Push-to-talk voice between the people at the table (`scripts/net/voice_*.gd`, `radio_voice.gd`). **Hold ` to talk on your side's
net; SHIFT + ` to the whole table** (rebindable in `user://voice.cfg`). It rides the host connection the seats already use: no new port.

- **On the wire** (`VoiceCodec`): 8 kHz mono, 40 ms frames of 320 samples, mu-law (one byte a sample): 8 kB/s plus base64 in the
  JSON line (about 11 kB/s per talker). `{t: voice, ch: net|all, s, d, end}` up; the host sends each listener
  `{t: voice, from, id, role, ch, s, q, k, d, end}` with the quality they hear it at and what kind of hearing it is. The host drops
  frames over 25 a second or a transmission over 30 s (a stuck key).
- **Who hears whom** (`VoiceRouter`, on the host): the **net** is your side's seats (runners: pilot, co-pilot, boss, lieutenant,
  spotter, boat; law: controller, chief, patrol, interceptor, cutter); the **table** is everyone, clear, always. On the net the
  quality falls with distance and is zero past the VHF horizon or behind a hill (`RadioNet.can_hear`, the scanner's and DF
  stations' own line-of-sight); the pilot and co-pilot are the aircraft (so altitude buys range), the desks are their
  headquarters' masts, and seats with no place on the map (spotter, boat) are a flat 0.75.
- **The other side listening in**: the law hears the runners' net once it owns **Intercept runner channels**, at 0.85 of the quality;
  a runner hears the police net with the **scanner**, and it arrives **scrambled** when the task force has paid for encryption.
  A runner transmission from the air is also a real runner transmission for DF: when the key comes up the DF stations take their
  bearing (`Session.voice_transmitted`), a long call sharpening it like any other.
- **The sound** (`RadioVoice`): a 300 Hz to 2.8 kHz band, a little crunch, hiss that grows as the signal weakens, dropouts at the edge
  of range, a squelch click as a talker keys up and a burst of noise as they let go; a scrambled voice is spectrally inverted
  (the rhythm of speech, none of the words). The effect slider in the settings runs from a clean voice to the full radio.
- **Devices**: `VoiceChat` captures the microphone through a muted capture bus (project setting `audio/driver/enable_input`; the macOS build
  declares the permission) and plays each talker through a generator; without a microphone it is a listener only. Settings
  (microphone, key, volumes, effect strength, mutes) are in `user://voice.cfg`, never in a save.

## 32. The multiplayer menu, the table and finding games

**F4 in a game** (or the lobby's *Multiplayer* button) opens the multiplayer menu (`MultiplayerMenu`, opened by `Main.open_mp`), with three tabs:

- **Games**: the games on your network (LAN discovery), double-click to join; or join by address with a seat and a name; and, when you
  host, where your game is (the addresses a friend would type), whether it is **shown on the network**, and whether the table is **closed
  to new players** (someone who held a seat can still come back).
- **Table**: the roster (the host first, a dot for whoever is talking), **mute** anyone, **remove** anyone (the host: they are told, and cannot
  rejoin this game), take a free seat or give yours back to the AI, and the table's chat (to everyone, or to your side).
- **Voice**: voice chat on/off, the push-to-talk key (click, then press the key you want), the microphone, microphone and radio volumes, how
  much radio is in your voice (0 clean ... 1 full), and a loop-back test with a level meter.

**Finding games** (`LanDiscovery`): a hosting game (and the dedicated server) sends a small JSON beacon every two seconds by UDP broadcast to
port 47801 (name, TCP port, mode, players, closed); the menu listens and forgets a game not heard from for 7 s. Joining still goes through the
host's own port and seats: the beacon is only where the game is.

**The host runs the table** (`HostServer`): `kick(id, ban)`, `locked`, `max_players` (16), `roster()`. Players are known to each other by a
**public id** (a hash of their reconnect token; the token itself is only ever sent to its owner), which is what voice frames, mutes and kicks use.

## 33. The waiting room: choosing roles before the game starts

The lobby's **Host a multiplayer game** opens a **waiting room** instead of starting at once (`Room`, `RoomScreen`; `HostServer.start_room`).
The host listens before the game exists; friends join (from the Multiplayer list, an address, or `--connect`) and see every seat by side
(the runners, the task force) with who has it (a player or the AI). Each player takes one seat or gives it back, ticks **ready**, and chats;
the host sees who is not ready and presses **Start the game** when everyone has a seat and is ready. Seats nobody took are the AI's.

- **The host takes a seat too**: the pilot's (3D, the default) or a desk (a 2D station: `HostDesk` runs the session, serves the guests, and
  the AI flies the aircraft until a guest takes the pilot's seat). The police pilot's 3D seat is for guests.
- **Rules**: a co-op table is the runners only (the law is the AI); a task-force game has no pilot; one player a seat and one seat a
  player; changing seat un-readies a guest; the host can remove a player or close the table.
- **On the wire**: `welcome` carries `phase: room`; guests send `room_claim`, `room_release`, `ready`, `say`; the host broadcasts `room`
  (mode, players, seats, whether it can start) when it changes, and `start {role}` when the game begins (`HostServer.begin` hands every
  chosen seat to the session, and the guests go straight into theirs). A guest who joins a game that is already running gets the old seat
  picker, so joining mid-game still works.


## 34. The analyst: the desk every tip crosses

The task force's analyst seat (`scripts/sim/analyst.gd`, `Roles.ANALYST`, behind `Analyst.ENABLED`). Without a player in it
nothing changes: a tip goes straight to dispatch. With one, tips wait on the desk first (`PoliceSystem.add_tip` hands them
to `Analyst.intake`; `release_tip` is what dispatch does with one):

- **What arrives**: an informant's word, an undercover agent's leak, the fuel desk's note that a tail number bought ferry
  fuel, an anonymous caller, and a double agent's plant. The sim knows which are real (`truth`); the desk does not.
- **Verify** (V, 45 s): checks the source and the tail number; the verdict, *sound* or *doubtful*, is right 85% of the time.
- **Forward** (F): to dispatch, where a helicopter goes up for it. A false lead costs the task force $1,000 in funds.
- **Bin** (X): a real lead thrown away is a load that got through (counted as a miss).
- **Stale**: a tip nobody touches goes to dispatch as it is after 150 s, and a desk holds at most 12 (the oldest is
  forwarded). Handing the seat back forwards everything waiting.

The seat is in the waiting room, the seat picker and the police-mode seat list like the others. The desk's dice are their own
stream (seed + 909). Not saved: the desk is empty after a load.


## 35. The undercover agent: a beacon on the parked aircraft

The task force's agent seat (`scripts/sim/undercover.gd`, `Roles.UNDERCOVER`, behind `Undercover.ENABLED`). The AI chief never
does this (the law upgrade "undercover" still leaks destinations by itself); it is a seat for a player.

- **Plant** (P): only while the aircraft is parked at a strip. It works 75% of the time, 50% when a spotter of the runners'
  watches that strip. A live beacon (25 minutes) puts the aircraft on the controller's picture wherever it flies, with a
  25 m error, radar or no radar, transponder or none (`PoliceSystem.tick` reports it as source `BCN`).
- **Fail** and the agent is burned: half the cover goes, the crew is told a stranger was seen at the tail, and the agent
  lies low for 10 minutes. Cover regrows one point in 30 s; at zero the agent is blown for 20 minutes.
- **The counter**: a runner with the bug sweep upgrade finds a fresh beacon half the time (the agent then lies low for 5
  minutes). The seat's dice are their own stream (seed + 919).


## 36. The fixer: the business between flights

The organisation's business desk (`Roles.FIXER`, a runner-side seat open at a co-op table, in the waiting room and in the seat
list). The pilot flies; the fixer does everything the pilot does on the ground that is not flying, from a 2D desk:

- **Jobs** (the table): the board at the field the aircraft is parked at and the jobs in hand; ENTER books or drops one.
- **Gear and spotters**: G the scanner, H the radar detector, F the ferry tank, S a spotter at this strip.
- **The people**: W the hiring hall (Manny Ortega), C the Family (Sal Moretti's offers, Y / N / P at the desk), L the pilot's
  lawyer, M the buyers (Benny Ruiz), K logistics (stock, cash and trucks).
- **The picture**: the money, the heat (suspicion and wanted stars), the payroll and payday, the spotters watching, the
  pilot's case, the Family's offers, the street and the island.

The permission list is the pilot's business commands without the flying ones (no kick, pump, autopilot, transponder, squawk,
turn around or call the boat). Nothing new in the sim: it is a desk over the commands that were already there, so the AI
needs no stand-in (the pilot, or the AI boss, does the same things when nobody sits here).


## 39. Wear, repairs and the mechanic

`scripts/sim/airframe.gd` (`Airframe`, behind `Airframe.ENABLED`; asked for with the session option `airframe: true`, which the
game's own start sets) gives each aircraft you own an **engine** and an **airframe** condition, 0 to 100, on their own RNG
stream (seed + 929).

- **What wears.** The engine wears 0.12 points a minute in the air (about 7 an hour). The airframe wears on touchdowns harder
  than 60 % of the gear's limit (up to 14 points at the limit), on gravel, grass, dirt and sand strips (0.4 to 0.8 a landing),
  and in a storm (0.1 a minute).
- **What it does.** Engine under 60: it runs rough and gives less power, down to 80 % at zero (the HUD says ENGINE ROUGH).
  Engine under 30: it may quit in the air (up to 5 % a minute at zero) for 90 seconds, the throttle forced to idle, and then
  catches again (ENGINE OUT). Airframe under 50: the gear collapses at a softer landing, down to 60 % of the limit
  (AIRFRAME WEAK).
- **Repairs** happen on the ground, over time and for money by the point (engine $30, airframe $20 at a hangar). A hangar (a
  field with a shop, or a hub or regional strip) does 12 points a minute; a bush strip patches at 5 a minute at 1.5x the
  price; a **mechanic** (a human in `Roles.MECHANIC`) does 24 a minute, anywhere, at 0.6x the price. The aircraft cannot take
  off while the work is running (the cowling is off, the throttle held at idle); it stops by itself when the work is done, the
  money runs out or the aircraft is moved. From the hangar menu (H) the service row starts and stops the work on both.
- **What you see.** The pilot and everyone else read good / worn / poor / failing. The mechanic reads the numbers, the
  chance it quits a minute, the power left and what the gear will take (his I key says it aloud), and haggles the farmer's drum
  fuel 40 % cheaper at bush strips.
- **The AI ground crew**: a bot (`AutoRunner`) has a worn aircraft (under 70) serviced at a hangar before it flies, and patched
  at a bush strip only when it is under 40. The save keeps each aircraft's condition.

The mechanic's desk: ↑ ↓ choose the part, Enter repairs it, B both, S stops the work, I inspects, F adds 10 % fuel.
