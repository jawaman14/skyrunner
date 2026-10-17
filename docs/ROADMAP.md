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

| Step | Status (18 Oct) | Evidence |
|---|---|---|
| 1. The early rise: employed pilot, the business slides into smuggling, first aircraft earned | **Done**, polish continuing | Employed opening #296 merged; first missions free and retryable (#376); chapter 1 goals reworded (#390 draft). A human pacing walkthrough and the first-aircraft price remain on the playtest list (#345). |
| 2. Setup-driven automation: assignments, then conditional orders and task sequences; manual play always remains | **Not started** | Payroll's fixed assignments are the only merged piece. Needs a design note in `DESIGN.md` first. |
| 3. Faction competition and the civilian economy | **In progress** | Rivals cannot take cargo from the air (#377 merged); the rival plane and hijack are removed (#388 draft, retire target 56,000); roadside truck firefights (#384, #387); turf-war districts and the General's choice (#378 draft, landing now). Rival depot raid designed, not built. |
| 4. Multiplayer: co-op and competitive modes for 2–16 players | **Furthest along** | Host service steps 1–9 of #97 merged (#364 and earlier); #97 stays open for broader entry-path coverage. Two-machine play and voice are not yet verified by a human. |

## Owner decisions of 17 October

- **The polish-week feature freeze is removed.** New features and the roadmap are back on, in the order below.
- **#378 (turf war) lands now**, after Codex's exact-head review and green CI.
- **Strips: change the strips** (do not gate the job generator): Mesa del Aguila 560 m and Old Quarry 620 m with a wider exit
  (#396 draft). The Cessna 172 now lifts its full 609 lb from EGL and from QRY's east end.
- **Vehicles:** #367 is closed; #374 (Codex's period vehicle rebuild) replaces it and still needs the owner's screenshot review.
- **Next after the freeze: presentation layers**, then the rival depot raid.

## Now: land the queue

Draft PRs, each tested; none merged yet. Review order (Codex's exact-head review is required for each, since the server refuses
a Claude review of Claude's own work):

1. **#378** turf war expansion (owner: land now).
2. **The small fixes:** #390 (chapter 1 wording, boat pickup messages, destination lines on the map), #391 (the AI pilot says
   where it is going), #392 (radar tip), #393 (rolling on a rough strip wears the airframe), #394 (Backspace slow reverse),
   #395 (Deliver step covers unloading), #385 (read-aloud removed).
3. **Ground and economy:** #383 (island-wide job board), #384 (roadside firefight, redundant once #387 lands), #388 (rival
   aircraft and hijack removed, retire target 56,000).
4. **#396** the strip changes, stacked on #323 and #319 (the strip evidence PRs).
5. **#373** (scenery) and **#374** (period vehicles) after the owner's screenshot review.
6. **QA lane (Codex):** goldens and BALANCE for #377, #383, #393 and #396; a hands-on look at the quarry exit and the map lines.

## Next: presentation layers (owner's pick)

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

Who: Claude the beat, the unlock, the takeover state, delegation and trust; Codex the dialogue and the scene.
Order: with the rival depot raid, after the presentation layers, unless the owner moves it up.

## Heat and the law (owner, 18 October)

Agreed order (owner, 18 Oct). Each step: a design note first, its own switch, its own RNG stream, tests first, a balance run.

1. **Case files and kinds of heat** (in progress). Design #400 (DESIGN §48); the stash case files (lead, surveillance,
   warrant, raid; lying low drops a case; an emptied stash is raided for nothing) are built on `claude/heat-case-file`.
   Still to do in step 1: the lawyer's warrant challenge as a command; pilot evidence, aircraft heat (per tail number)
   and district heat; the phone Heat app (Codex); the balance run and BALANCE entry.
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

These were finished in part, dropped from the 12 October list, or never written down.

- **Backspace reverse (#394):** no gamepad binding and no F1/GUIDE help line.
- **Map destinations (#390):** only go-fast boats and stash trucks have destination lines. Squads, convoys and the station map
  (`station_map.gd`) do not; the AI pilot's route is announced (#391) but not drawn.
- **HAR runway end 0** (owner, 18 Oct; D-37): flatten the hill about 22 m high 1.2 km out so both ends work (terrain
  change, re-bake, strip trials).
- **3D pilot app, fixed 30 Hz step with smoothing** (owner, 12 Oct; DECISIONS D-12): the host loop has it (#356), the pilot
  app does not. Its own task, needs render interpolation.
- **Key audit (#345):** every key, which are still used, what the help text says. Not started.
- **Autopilot mentions (#345):** the owner was asked where an unprompted mention appeared; no answer yet.
- **Job board (#383):** remote desks still get only the current strip's board; boards are not saved (a load redeals once).
- **Wallet and BOINC (owner's machine):** a new Gridcoin beacon needs a little GRC; the BOINC account manager was detached.
  Not part of the game, listed so it is not lost.
- **Quarry west end and PNR end 1:** one-way by design (terrain or trees in the climb-out); keep documented in `STRIPS.md`.
- **The uncle story (Rafa Quintero) was missing from the roadmap:** now its own section above.
- **Docs to update:** HANDOFF and DESIGN (the strip pin option, the pit constants, `CACHE_VERSION` 3, the RNG stream table for
  the island boards); `docs/ROADMAP.md` itself was stale on 9 and 12 October.
- **Stale PRs:** #321 (28 behind main), #305 (waits on the strip decision, now made), #370 (superseded by this rewrite).
- **Local housekeeping:** scratch worktrees under `.claude-worktrees` and terrain cache backups.

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

The owner asked for the map to be rebuilt from the ground up with what we have learnt. The plan is
[MAP_REDESIGN.md](MAP_REDESIGN.md): constraints first (strips and their approach volumes, then terrain shaped for them,
water, one district map, roads with classes and real city streets), then parcels, a site manifest with access checks, an
asset catalogue, props and presentation hooks, all baked by one build tool and checked by one map audit. It starts after
the map PRs in the queue land (#373, #374, #378, #396, #402, #404), as a new region beside the current one; the owner
approves the layout sketch (step 0) and the screenshots (step 6), and playtests before the old map is retired. Four
owner questions are open in its section 7.

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
- **Test time:** the full suite takes about 13 minutes under the machine lock; a cold import in each worktree adds about 5.
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

- **Turf expansion (Codex, branch codex/turf-war-expansion):** `Territories` adds map-scoped district IDs while retaining the four economy markets as parent rollups. Costa Brava has ten authored areas; classic/generated maps use their current market centres. Ground control, squad decisions and exposed one-leg truck routes read the local layer. Stable region IDs allow later maps to bring their own districts. Initial local verification passed (898 tests, Costa Brava smoke, and a 200-seed war balance run); the balance run shifts the war economy and losses and needs interpretation before tuning. Not yet: a visible territory map, balance calibration for district control, and authored content for an additional region.
