# Roadmap

Current queue, rewritten 18 October 2026. The 12 October text is in git history (PR #370); the 9 October text is kept in
git history (`git show 40bf0d44:docs/ROADMAP.md`); older progress is in
[ROADMAP_HISTORY_2026-10.md](archive/ROADMAP_HISTORY_2026-10.md). Live state of every PR and issue is in
`github_merge_queue` and [PROJECT_TRIAGE_2026-10-12.md](archive/PROJECT_TRIAGE_2026-10-12.md); generated facts are in
[PROJECT_STATUS.md](PROJECT_STATUS.md). Every owner decision and where its work is tracked: [DECISIONS.md](DECISIONS.md)
(read it first when rewriting this file).

## Product direction (owner, 8 October 2026)

The approved direction is [DESIGN.md §0](DESIGN.md#0-where-the-game-is-heading-owner-approved-direction-8-october-2026):
build an empire from nothing, starting as a hired pilot. Four steps, in order:

| Step | Status (4 Nov, checked against the code) | Evidence |
|---|---|---|
| 1. The early rise: employed pilot, the business slides into smuggling, first aircraft earned | **Done**, polish continuing | Employed opening (#296), free retryable first missions (#376), and the D-92 early-chapter pass on main: goal markers and the NEXT line, flight debrief, banter, the LORAN upgrade, story weather, side gigs, hidden strips. A human pacing walkthrough and the first-aircraft price remain on the playtest list (#345). |
| 2. Setup-driven automation: assignments, then conditional orders and task sequences; manual play always remains | **Not started** | Payroll's fixed assignments and the dealers' auto-resupply toggle are the only pieces. Needs a design note in `DESIGN.md` first. |
| 3. Faction competition and the civilian economy | **In progress** | Turf districts (#378), roadside truck fights (#384, #387) and the end of the rival plane and air hijack (#377, #388) are on main. The visible territory map is #494. Every rival inflow is a named ledger account in #496; removing them (D-65) waits on the Living District. Rival depot raid paused (D-75). |
| 4. Multiplayer: co-op and competitive modes for 2–16 players | **Furthest along** | Host service steps 1–9 of #97, protocol v3, seats, voice and the waiting room are on main. Two-machine play and voice are not yet verified by a person. New multiplayer features wait on the Living District (D-71). |

The full mechanic-by-mechanic status (112 built, 9 in PR, 8 half done, 54 planned, 12 paused) is in [FEATURES.md](FEATURES.md).

## Owner decisions of 17 October

- **The polish-week feature freeze is removed.** New features and the roadmap are back on, in the order below.
- **#378 (turf war) lands now**, after Codex's exact-head review and green CI.
- **Strips: change the strips** (do not gate the job generator): Mesa del Aguila 560 m and Old Quarry 620 m with a wider exit
  (#396 draft). The Cessna 172 now lifts its full 609 lb from EGL and from QRY's east end.
- **Vehicles:** #367 is closed; #374 (Codex's period vehicle rebuild) replaces it and still needs the owner's screenshot review.
- **Next after the freeze: presentation layers**, then the rival depot raid.

## Now: land the queue

Open PRs on 4 November, all green on CI with no review findings left. Each author merges their own (D-52); the risk-class
ones need the other agent's exact-head review or D-91.

| PR | What | Risk class |
|---|---|---|
| #493 | The pilot's chart: our squads' routes and the AI pilot's remaining legs, clipped to the scope | No |
| #494 | Territory map: districts tinted by holder on the desks' map and the chart | No |
| #495 | Island job boards on remote desks; boards survive a save, story games included | Yes (save format) |
| #496 | F-3 finished: every money change is a named ledger transfer, the rivals' free inflows included | Yes (money, Session layer) |
| #491 | Loop idea 8b: the lawyer's discount after a seized load | Yes (balance) |
| #497 | BALANCE entries 62 and 63: buyers' orders and the case files, measured | No |

#491 took BALANCE entry 61, so #497's entries became 62 and 63. #493 and #495 also edit this file's
half-done list; the version below supersedes them.

## Repeatable goal: the week's work (owner, 4 November)

The owner asked for a repeatable goal and for the World of Warcraft study's lessons to go into the game (D-93, D-94). The study
found WoW kept players with a short payoff inside a long one: a weekly raid reset and a tier you could see. Skyrunner's answer is
the week's work (DESIGN 52): every island week (90 game minutes) posts three goals drawn from what is open, each paying renown,
all three paying a bonus and a run of cleared weeks; the rank is the Renown tier, whose perks already exist. No money is paid
(D-65). The phone's Week app shows it.

The other lessons, one PR each (D-94): buyers' orders retuned until taking them pays; the job board led by a few best-fit jobs;
streak protection on catastrophic rolls (customs, truck stops); the only aircraft never forfeited before the takeover; lying low
as a visible bonus; loop-length targets in DESIGN, measured by the playtest digest. All six are on `main` (the last, 8 November: the
first sentence in a story game spares the pilot's only aircraft, with a warning).

## The Borderlands study (owner, 7 November)

The owner asked for a Borderlands study like the WoW one and said yes to building its first three ideas (D-95); the study is a doc,
"Borderlands deep-dive: what Skyrunner can take". One PR each, in order:
- **Breakaway** (DESIGN 58): a stop on the ground (arrest on landing, raid while unloading, a sting) opens a 45 s window to get
  out: take off and get clear, dump the hot load, or pay the officer. One an island day, more with renown; the window running out
  is the bust as before. Merged (#517).
- **Wanted names:** rival lieutenants and task-force captains with one signature prize each, at a stated 1-in-N per take-down,
  and a title card on first contact (DESIGN 59, BALANCE 70). Merged (#519).
- **Makers:** four fictional brands with one behaviour each across the dealership, with small two- and three-model set
  bonuses (DESIGN 43, Makers). Merged (#518). Aircraft parts and the arsenal can take makers later.
Then, from the study's second round, one PR each: cursed jobs (DESIGN 60, #522), a weekly black market and weekly hot job
(DESIGN 61, #523), the heat dial (DESIGN 62, #524), and last, the one-life extraction run as its own mode (the last run,
DESIGN 63).

## Empire pivot (owner, 19 October)

The game becomes a hybrid of open-world character play and a persistent empire simulation, with equal design weight on both
(D-65 to D-80). The plan and PR order are in [EMPIRE_PIVOT.md](EMPIRE_PIVOT.md). The simulation contract (ledger, inventory,
one clock, actors, organisation AI, saves, the Living District's acceptance tests) is in
[EMPIRE_SIMULATION_SPEC.md](EMPIRE_SIMULATION_SPEC.md).

Order (D-75): land the queue above and finish heat step 1, then:

1. **Now, independent of the simulation:** the pivot docs (this section); story text with Rafa as the employer and Benny as his
   fixer, and Manny Arce renamed in the flying lessons; `rafa.dialogue` wired into the prelude and chapter 2; stale docs.
2. **Foundations (Claude, risk class):**
   - F-1, the save migration chain, comes first.
   - F-2, the ledger wrap, with no behaviour change.
   - F-3a-f, the money sites moved by domain.
   - F-4, inventory. The model, the stash and aircraft wrap, and (7 November) the trucks' and raids' moves booked by name and
     the lots saved; 8 November, the last direct changes: the Collective's barter and circuit sales and the cheat fill are
     named moves (`Logistics.book`), so a stash's stock changes only by a named move. Finished; the five-second reconcile stays
     as the safety net. (The trade's own `stock` with no logistics has no stashes and no inventory places, so nothing to move.)
   - F-5, `command_as` and actors. 7 November: `Actor`, `Session.command_as` with `command` as its shim, events tagged
     with the actor and org, and `job_delivered` gains `by` and `mode`. The ownership and manager-budget checks wait for
     businesses (L-1) and managers (L-4); story goals counting by org is L-5.
   - F-6, the scheduler and daily books; nights become a report; `strategic_ref` parity retires (D-74). 7 November, F-6a:
     the scheduler (`Schedule`, saved) and the 06:00 books (`Books`, each org's day from the ledger, saved). F-6b first part:
     the day's debrief from the books and the day's events (`Debrief`, saved). 8 November: the nights behind a switch
     (`NightDirector.ENABLED`), `strategic_ref` retired for its Godot golden, and the HQ orders run any time (queued while the
     crew is out), their money a named transfer. F-6 is finished; the "N days" balance sim that replaces the nights is L-7.
   - F-7, time acceleration, after D-12.
   - Progress on 4 November: F-1 and F-2 are on main; F-3 is finished in #496; F-4 has the inventory model and a session wrap
     with no call sites moved; F-5 to F-7 not started (`job_delivered` has no `by` or `mode` yet).
3. **The Living District (P0, D-72):** San Telmo Centro, with three organisations (the player's, Los Cuervos and the Morettis, D-84).
   - Two supply chains.
   - The desk's business books.
   - Direct and delegated delivery equivalence.
   - Acceptance tests A1-A9 and P1.
   - The owner's playtest (G1).
   - Progress on 8 November: L-1's sim side is on main (DESIGN §64: the twelve businesses as data, tills, buy/fund/take, rent
     and bills at the books close into arrears, district state); placing them in the world is the 3D side's. L-2's legit import-to-retail chain is on main (DESIGN §66);
     the product chain's money on the ledger is #528. L-3 (the Morettis and org AI v1) is next.
4. **After the gate:** organisation depth (hierarchy, schedules, budgets, conditional orders, trust D-11), then the campaign pivot
   (story v6 with ventures, the takeover on the ledger, both views kept, the ending and the sandbox), then more cities, each fully explorable (D-81).

Paused by D-75 until the gate: the presentation layers, heat steps 2-3 and the rival depot raid (the map redesign was resumed by D-86 on 30 October). Every PR keeps
the sockets lane green (D-71). The owner answered O-1 to O-5 on 19 October (D-81 to D-85): every city fully explorable,
the next in line takes over when the boss dies or is jailed, the sandbox carries on after any ending, the Morettis are the
third organisation, and the acceleration caps are as specified.

## Next: presentation layers (owner's pick)

*Paused by D-75 until the Living District gate (Empire pivot, above).*

Full text: [PRESENTATION_LAYERS.md](PRESENTATION_LAYERS.md). Read-only presentation that follows the simulation. None of it may
change a sim outcome or draw on a sim RNG stream.

1. **Territory radio and era music.** Each crew gets a station that is stronger in its district; per-year stations from the
   owner's own tracks in `user://radio/<station>/` (`.ogg` best, `.mp3`, 16-bit `.wav`); distance-based static
   (FM 6 km, AM 20 km, shortwave 60 km) is designed, not built. Music evolves by era through stems and changes only at natural
   breaks.
2. **Era fashion and liveries,** in step with the music; owned aircraft keep their livery.
3. **Crew colours, signage and graffiti** that mark who holds a street and repaint when a district changes hands.
4. **City pulse:** the economy sets the rhythm, each faction gets a motif, consequences give a directional stinger.
5. **Heat in the look:** streetlight flicker, more patrols, darker clothing as heat rises.

## Story: the uncle and the boss's seat (owner, 12 October; not built)

*Now Phase 3 of the Empire pivot (above): the takeover is built on the ledger, and direct play stays first-class after it (D-79).*

Recorded in [PROJECT_TRIAGE_2026-10-12.md §8.5](archive/PROJECT_TRIAGE_2026-10-12.md) and HANDOFF; missing from the 12 October roadmap.
The boss is the player's uncle, **Rafael "Rafa" Quintero**: jovial, bigger than life, with a darkness you can't place.

1. **Chapter 1-2:** name the employer as Rafa in the employed opening; two or three dialogue beats in chapter 2 as he
   reveals his business (talk scenes, `scripts/game/talk.gd`).
2. **Chapter 4 (Cocaine Cowboys):** after the first Los Cuervos incident a scripted beat: the player **hears** Rafa was
   killed by Los Cuervos (not witnessed). The turf war starts and the player **takes his seat**: the boss desk and its
   orders become the player's.
3. **A crumbling empire** (owner, 18 Oct): half survives: half the stashes (the least known ones), half the crew, the
   trucks that were parked, and a quarter of Rafa's cash.
4. **Not locked in:** every other layer (flying, the ground, the desks) stays open; **delegating a flight costs money**
   (a hired pilot flies it with the existing bot).
5. **Reputation is trust with each crew** (accepted table: Morettis up means Los Cuervos down; Los Cuervos up means the
   Morettis and the street dealers down; the Company up means the Sunrise Collective down a little; the Collective up
   means the Company down a little; the street dealers up means Los Cuervos down a little); lost shipments cost
   trust, and a crew without trust buys elsewhere.

6. **Flight skill** (owner, 18 Oct): good landings, short strips and clean approaches give optional bonus goals (money or
   reputation); they never block a chapter.

7. **The boss layer** (owner, 18 Oct; D-58): when the player takes the seat, the game turns to organising: choosing the crew, the
   routes and the orders, and delivering is optional, by a crew pilot or by the player. Flying cargo becomes one part of the
   logistics system, not the focus. Before the takeover the player flies the cargo themselves and meets each mechanic one chapter
   at a time (the flights, the load planner, the stash and trucks, the street, the law, the court), so the boss's seat is
   understood when it arrives. This sets what delegation (D-10) and the orders (D-59) are for.

Who: Claude the beat, the unlock, the takeover state, delegation and trust; Codex the dialogue and the scene.
Order: with the rival depot raid, after the presentation layers, unless the owner moves it up.

## Heat and the law (owner, 18 October)

*Step 1 finishes; steps 2-3 are paused by D-75 until the Living District gate (Empire pivot, above).*

Agreed order (owner, 18 Oct). Each step: a design note first, its own switch, its own RNG stream, tests first, a balance run.

1. **Case files and kinds of heat** (in progress). Design #400 (DESIGN §48); the stash case files (lead, surveillance,
   warrant, raid; lying low drops a case; an emptied stash is raided for nothing) are built on `claude/heat-case-file`.
   The lawyer's warrant challenge, aircraft heat (per tail number) and district heat are built; the balance run against the old
   raid roll is BALANCE entry 63. Still to do: pilot evidence, and the street war's police AI raids stashes without
   reading the case files (`GroundWar._think_police`). The phone Heat app is in #446 (Codex), using the existing case-file visibility rules.
2. **The police search and the ladder down.** Helicopters search outward from the last known position; checkpoints on
   likely escape roads; dispatch chatter on the scanner; visible ways to cool off from wanted (break line of sight, go
   under cloud, swap the transponder code, hide the aircraft in a hangar, change aircraft or repaint).
3. **Patterns, escalation, corruption, ground chases.** Habitual routes and hours raise the risk and draw roadblocks and
   radar pickets (pattern exposure from the HQ season, in live play); new agencies at heat thresholds (state police, the
   DEA, a military radar picket); paid cops who warn and can be flipped by Internal Affairs, crew loyalty and leaks, the
   accountant slowing the RICO case; a stopped truck or a raid nearby becomes a short car or foot chase.

Who: Claude the simulation of every step; Codex the Heat app, the HUD and the in-world look (the presentation layers'
"heat in the look").

## Then: the rival depot raid

*Paused by D-75: to be redesigned on rival inventories once the shared economy (D-65) lands.*

Owner's decided design (17 October; saved in memory and on the board): stolen cargo and weapons go to a **rival depot at the
rival HQ** with a value; a **tip-off a few minutes after the theft** marks it on the map; a raid costs **all four** of casualties
(garrison fight), police heat, a rival grudge (more ambushes for a while) and squad upkeep and time; success returns **all of the
cargo and weapons**, minus the raid's cost. Build behind a static switch registered in `scripts/sim/switches.gd`, on its own RNG
stream, tests first, as a follow-up to #384/#387. Depends on #378 and #387 landing.

## After that: the four product steps

1. **Step 2, automation.** Conditional orders (stock thresholds) first, then task sequences. Workers follow instructions; AI
   never invents assignments. Needs a design note in `DESIGN.md` before any code.
2. **Step 3, the rest.** The AI knowledge policy is decided (owner, 18 Oct): the AI police and rivals act only on what a
   human in their seat would see (radar, sightings, tips, informants); audit where they read more today and fix it. Then
   rivals' starting strengths and civilian jobs, demand and prosperity. The escort and stakeout balance (#244, #98) can now be tuned.
3. **Logistics access (#241 series).** The 99 audited logistics pairs were blocked by grade, footprint and unauthored meeting
   points; the access stack (#265–#276) was closed unmerged on 12 October, and new work starts from `main`. Re-run
   `tools/logistics_routes.gd` for the current count. Never raise connector limits or restore straight-line fallbacks to make
   numbers pass.
4. **Empire command and feedback (#242).** Owner overview, durable order lifecycle, operational debriefs, and teaching the first
   empire decisions at the existing unlocks.
5. **Coastal art and release (#243).** One reference corridor first (HAR, the coastal road, Warehouse 7, the harbour), then
   architecture, period vehicles (#374), cockpit surfaces and feedback. Frame-time captures before and after each asset batch.

## Forgotten or half done (found 18 October)

Rewritten 4 November against the code. The items from 18 October that are finished are listed once at the end.

**Half done (some code merged, not finished):**

- **3D pilot app, fixed 30 Hz step with smoothing** (D-12): the host loop has it (#356), and since #512 the pilot app does too,
  behind `PilotApp.FIXED_STEP` (off by default; `--fixed-step` turns it on): whole 1/30 s steps through `HostLoop`, the
  aircraft and the chase camera drawn between the last two steps, key presses carried to the next step. What's left is a
  person at the controls judging the feel, then flipping the default; F-7 waits on that.
- **Stock lots and pickup orders** (DESIGN 51 slices 2-3): `StockLot`, `StockLedger`, `StockValue` and `PickupOrder` exist with
  tests and have no gameplay call sites. F-4's inventory (#509) is where they would land; not wired yet.
- **Street-war police and the case files:** with the ground war on, `GroundWar._think_police` raids stashes without reading
  the case files, so heat step 1 only runs when the war is off (found by BALANCE entry 63, #497). A heat step 2 item.
- **Checked vehicle routes:** all 99 audited logistics pairs fail access; waits on the map rebuild's sites and connectors
  (D-86). Never raise connector limits to make the numbers pass.
- **Full NPC truck and squad migration** to physical agents: partly done; needs its own evidence.
- **District-control balance calibration:** the districts and their map are built (#378, #494); the tuning is not.
- **Two-machine multiplayer:** seat, action and voice are implemented and never run by a person (release gate).

**Not started, still owed:**

- **Autopilot mentions (#345):** the owner was asked where an unprompted mention appeared; no answer yet.
- **Wallet and BOINC (owner's machine):** a new Gridcoin beacon needs a little GRC; the BOINC account manager was detached. Not part
  of the game, listed so it is not lost.

**Finished or in PR since 18 October:** Backspace reverse (RB binding and help line were on main), map destination lines (#493), the
island job board gaps (#495), the BALANCE entries for orders and heat step 1 (#497), the rivals' unattributed money (#496),
the lawyer's discount valve (#491), the docs' stream table, terrain cache, strip pins and pit (DESIGN §56, #505), the key audit (#506: the SHIFT shortcuts no longer fall through to the plain key when their system is missing; F1 and F8 match the code), the cleared approach to HAR end 0 (D-37, #514). The quarry's west end and PNR end 1 stay one-way by design (`STRIPS.md`).

## The design epics, in order (owner, 18 October)

Agreed by Claude and Codex and accepted by the owner (D-48; the full table is on #326). One item at a time, each as its
smallest slice with a screenshot, starting once the queue above has landed:

1. First-session playtest protocol (#172), with #155 as its chapter 1-4 tutorial audit and #157 as a local log only. It runs
   first and may reorder the rest.
2. Readability and accessibility (#138, #156).
3. Cockpit clutter (#142).
4. One event model and interruption policy (#120, #151), shared by the feed and the phone's Messages.
5. Contextual lessons and first-use hints as one system (#134, #148).
6. Failure fairness (#165), with #164's assists as explicit settings.
7. "Why did that happen" reasons (#147, #173).

Then Tier 2 with the story, map and presentation layers (#163, #133/#132, #130/#131, #168, #161, #166, #167,
#140/#141/#143/#159, #144/#149, #171) and Tier 3 later. Nine issues (#125, #137, #154, #129, #135, #128, #127, #121, #126)
are foundations, not done: each gets a gap audit before it is scheduled. #169 is deferred.

## Working structure (owner, 18 October)

**Codex unavailable (owner, 7 November, D-96).** Codex isn't available for now and Claude works on the project mostly alone:
Claude merges its own PRs, risk class included, under D-91 (CI green on the exact head, every review finding fixed and
answered, its own diff read end to end), with no wait for a second agent's review. Codex's QA lane (sims, full suites, sweeps,
balance runs) and its UX/UI and dialogue lead fall to Claude meanwhile. Any review that does arrive is still answered before a
merge.

The owner changed the structure (D-52): Claude and Codex each do their own work end to end, including merging it, instead
of Codex being mainly the approver. They hand each other coding jobs through the board. **In effect from 18 October (08:50,
the owner's word), written into AGENTS.md and PIPELINE.md by #408:**

1. The other agent's review is mandatory only for risk-class PRs, defined in AGENTS.md "Working mode: dual work": saves
   (`StrategicSave`, save formats), a new random draw or RNG stream, goldens or frozen fixtures, the `Session` layers
   (`scripts/sim/session_*.gd`), the flight model, or balance numbers, and any PR whose author asks. Every other PR its
   author merges on green CI with every thread answered.
2. Codex still finishes the reviews it owes on the risk-class PRs, then joins the discussion on the board: which jobs it
   wants and which it will not take. The split below is Claude's draft.
3. The open PRs are finished together: Claude merges its low-risk PRs, Codex reviews the risk-class ones and runs the QA lane.

Claude's draft split, for the discussion:

| Lane | Claude | Codex |
|---|---|---|
| Systems | heat steps 2-3, the rival depot raid, the AI knowledge audit, Rafa's takeover state and the trust table, flight-skill goals, saves | the Heat app and the station map lines on top of those |
| Story | beats, unlocks, the takeover | dialogue and scenes for Rafa, briefings and debriefings |
| Map | layers L0 to L5 (data, build tool, map audit), the HAR approach | L6 to L10 (site layouts, asset catalogue, props), the walk and drive checks |
| UX epics | the data behind "why did that happen" (#147, #173), failure fairness (#165) | #172 protocol, #138/#156, #142, #120/#151, #134/#148 |
| Presentation | hooks in the sim | music, graffiti, signage, vehicles, scenery |
| QA | fixes | sweeps, full suites, balance runs, goldens |
| Merging | each merges its own work on green CI; a risk-class PR (saves, RNG streams, goldens or frozen fixtures, the Session layers, the flight model, balance) is reviewed by the other first | the same |

## Map redesign (owner, 18 October; planned)

*Resumed 30 October (D-86): the owner asked for the map to be rebuilt from scratch now. It still starts after #373, #374 and #396 land, and the plan's owner gates stand. Paused earlier by D-75.*

The owner asked for the map to be rebuilt from the ground up with what we have learnt. The plan is
[MAP_REDESIGN.md](MAP_REDESIGN.md): constraints first (strips and their approach volumes, then terrain shaped for them,
water, one district map, roads with classes and real city streets), then parcels, a site manifest with access checks, an
asset catalogue, props and presentation hooks, all baked by one build tool and checked by one map audit. It starts after
the map PRs in the queue land (#373, #374, #378, #396, #402, #404), as a new region beside the current one; the owner
approves the layout sketch (step 0) and the screenshots (step 6), and playtests before the old map is retired. Four
owner questions are open in its section 7.

## Product and money loop ideas (owner asked 18 October; for decision)

The owner asked what could make the loop more dynamic and fun. [LOOP_IDEAS.md](LOOP_IDEAS.md) says where it is flat today and
proposes eight additions: a market board with buyers' orders and deadlines, cover cargo, dirty money with a clock, a readable
calendar, a deal that moves mid-flight, price wars, investments with a return, and comeback valves. The owner answered (18 Oct,
D-58 to D-60): deadlines follow demand, the boss layer organises while flying is optional, and to begin as seen fit.

- **Built (the simulation half of addition 1, #419):** `Orders` and the market board data in `Trade.view`, with tests; DESIGN section 49.
- **Phone interface (#446):** Work has the market board and buyers' orders with premiums/deadlines; Enter calls Benny. Measured in BALANCE entry 62 (the stand-in
  misses most orders; the premiums pay it about $150 a run and the misses cost the Morettis' respect).
- **Not started:** additions 2 to 8, in the order of LOOP_IDEAS section 2 (cover cargo next, then the calendar).

## Stock, ownership and the money loop (owner, 18 October; planned)

The owner (D-63, #427) asked for cargo, stock and logistics to be reworked for the bigger game: flying hot cargo for a client no
longer makes sense once you own stock bought upfront. The design is [DESIGN.md section 51](DESIGN.md). Slices, each its own PR with
a switch and tests first (an RNG stream and a BALANCE entry where the slice draws random numbers or moves the economy):

1. The design note (this section and DESIGN 51). (Claude)
2. Stock lots with grade, age and provenance. This is the stock side of F-4 (`docs/EMPIRE_PIVOT.md`, inventory lots, each lot in exactly one location per `EMPIRE_SIMULATION_SPEC.md` section 4) and uses its single wrap-first save migration rather than a second one. (Claude)
3. Orders and the pickup person; the gun dealer on the same flow, replacing "sell / keep guns". (Claude the sim, Codex the dealer scenes)
4. Storage places and the stock ledger. (Claude the data, Codex the screen)
5. Laundering: one authority (`HQ.Org`), fronts with a per-night cap and a delay; the casino path moves onto it. (Claude)
6. Crew relationships and rackets that close under heat. (Claude the sim, Codex the cards and dialogue)
7. Chapter objectives with deadlines, and what Renown and crew trust unlock at boss level (no new currency). (Claude)
8. The boss desk: worker control, area marking, heat map, ledger tab. (Codex lead, D-62)

## Arms and ammunition (owner, 18 October; planned)

The owner's direction (D-61): **ammunition is a cargo** that is moved and traded, priced by the usual factors; **weapons move as
crates of each type**, which differ in their specs; the **more powerful weapons are in shorter supply** and the weaker ones plentiful;
and all of it ties into the ground and turf war. The design, grounded in `arsenal.gd`, `ground.gd`, `foot_combat.gd` and
`logistics.gd`, is [DESIGN.md section 50](DESIGN.md). Four stages, each its own PR with a balance run:

1. **Crates and the scarcity ladder.** A crate holds one type; each type has its own supply and price (pistols plentiful, rifles
   common, machine guns scarce, RPGs rare); gun runs and buyers follow the ladder. (Claude)
2. **Ammunition as a good.** Rounds per weapon type, in crates, bought, trucked and stored; squads draw the rounds of the weapons
   they carry. (Claude)
3. **The war uses it.** Fights consume rounds, a dry district's ammunition price climbs, a squad without rounds stops firing, and
   holding a port or road changes who can resupply. (Claude, with the turf work)
4. **The screens.** The pack and logistics menus, and the market board (it already carries guns; ammunition joins it). (Codex)

Order: after the buyers' orders (D-59) land; each stage needs a BALANCE entry because the war economy is sensitive to it.

## Human release gates and owner decisions (#326)

- **Gates only a person can pass:** exported Windows and macOS walkthroughs; physical controller and four-resolution visual
  acceptance in both palettes; two-machine multiplayer with seat, action and voice, waiting room, LAN and guest seating;
  functional-site walk and drive; moving and dense-scene performance captures; radio recordings and third-party asset licensing.
- **Decisions still open:** none from this list; see [DECISIONS.md](DECISIONS.md) for every open row.
- **Decided:** strips (change them), the freeze (removed), #367 (closed for #374); on 18 Oct the HAR hill (flatten it),
  flight skill (optional bonus goals), the AI knowledge policy (only what a human would see), the engine (stay on Godot),
  Rafa's empire (half survives), the 52 epics (the agents rank them), Codex's unattended turns (keep them).

## Open technical items

- **Start-up architecture (#97):** entry paths consolidated across steps 1–9; the save-resume gap (a partial campaign resumes
  without its chapter setup) needs a save-format change.
- **Network:** the client-side oversized-frame stall, and the doubled per-frame snapshot on local desks (HANDOFF log, 10 Oct).
- **Test time:** the 11 October run took about 13 minutes under the machine lock, with about 5 minutes for a cold import. These are historical timings; use the current job status when planning access to the lock.
- **Windows memory:** overlapping Godot jobs have caused allocation failures; the lock is the only guard.
- **A flaky test on this machine:** `test_pause_menu` volume fails on clean main here (a saved volume setting); and the `crew`
  filter shows a walker phone test that passes in the full suite.

## Completion gates

- Real input, long/empty/stale content and pending/refused/unknown remote outcomes.
- Both palettes; 1024x768, 1280x720, 1920x1080, 2560x1080; visible focus.
- Walk and drive bridges and every functional entrance; wall occlusion and thresholds.
- Costa Brava and representative generated maps; runway clearance preserved.
- The classic island is retired from player entry points; classic saves are rejected, not rewritten; its geography stays only
  for frozen parity and balance tests.
- Worker assignment, arrival, jail/death, save/load and human/AI handoff.
- Focused and full sharded tests, parity/goldens, export filters and build smoke.
- Fixed-route frame-time and memory comparisons; investigate regressions above 10%.
- Paired-seed balance measurements for travel changes; no arbitrary retuning.
- Exported Windows walkthrough and a real two-machine seat/action/voice session.

## Deferred

New campaign chapters beyond the current twelve, hidden-informant gameplay, arrival-gated payroll, new combat mechanics, UDP
prediction, multiplayer racing, additional aircraft and cloud deployment. Ordinary city houses remain scenery.

## Subsequent GitHub issue pass

The owner asked for every repository issue to be reviewed after the overhaul. 54 of the 97 open issues of 7 October (#80–#177) were
closed with a pointer to [#326](https://github.com/jawaman14/skyrunner/issues/326) (owner gates, decisions and design epics); the agent-doable engineering work is in one other issue linked from it. Evaluate each against verified code and the queues above; overlapping master programs and
already-implemented work must not create duplicate systems. Keep issues needing human playtests, physical controllers, rights
decisions or two real machines unresolved until their evidence exists. Publishing a draft PR is not integration or proof of
release acceptance.

- **Turf expansion (Codex, branch codex/turf-war-expansion):** `Territories` adds map-scoped district IDs while retaining the four economy markets as parent rollups. Costa Brava has ten authored areas; classic/generated maps use their current market centres. Ground control, squad decisions and exposed one-leg truck routes read the local layer. Stable region IDs allow later maps to bring their own districts. Initial local verification passed (898 tests, Costa Brava smoke, and a 200-seed war balance run); the balance run shifts the war economy and losses and needs interpretation before tuning. The visible territory map is built (districts tinted by holder on the desks' map and the pilot's chart, `StationMap.turf_rows`). Not yet: balance calibration for district control, and authored content for an additional region.

### UI decision follow-through (19 October 2026)

- #446 implements the existing market/order and heat data on the phone, and D-62's phone use during flight.
- #447 addresses D-62's dealership scroll reset independently.
- D-62's full worker-control desk waits for L-1/F-5 and L-4 in [EMPIRE_PIVOT.md](EMPIRE_PIVOT.md); gun pickup needs the authoritative PickupOrder work. These are not complete.
- D-75's presentation layers and world-map redesign remain paused. Station-map navigation and existing destination-line feedback can be improved without changing world geography or inventing new simulation orders.
