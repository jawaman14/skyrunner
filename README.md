# Skyrunner

**Bush flying, smuggling and the long arm of the law, on a fictional Caribbean coast, 1979-89.**

You start as a bush pilot with half a Cessna and a fuel bill. You can end up as the organisation the coast
answers to: the crews, the stash houses, the street war, the lawyers, the Family and the Company. Or you can
sit at the task force's desk and hunt that pilot down. Every seat is playable alone (the AI plays the rest) or
with friends over the network.

It is all one Godot 4 project: pure GDScript, no plug-ins to build and no compiler, with its own 6-DOF flight model
reading [JSBSim](https://github.com/JSBSim-Team/jsbsim)-format aircraft data. A stock Godot 4.7 opens it, plays it and
exports it to Linux, Windows and macOS.

| | |
|---|---|
| **Play it** | [INSTALL.md](INSTALL.md): download a build or run from source. Beta testers: [BETA.md](BETA.md) (report with F12). |
| **Version** | 0.9.0-beta.1 |
| **Engine** | Godot 4.7.2, GDScript only, Jolt physics |
| **Size** | about 44,000 lines of game code, about 740 tests |

| **Dusk on the boulevard** | **A firefight at the docks** | **The city at night** |
|---|---|---|
| ![street](docs/img/vice-street.png) | ![docks](docs/img/ground-docks.png) | ![night](docs/img/city-night.png) |
| **Load planner** | **The boss's desk** | **Take a seat: the AI plays the rest** |
| ![load](docs/img/ui-load.png) | ![boss](docs/img/ui-boss.png) | ![seats](docs/img/ui-seats.png) |

*(More screenshots are in [docs/img/](docs/img/); they were rendered on a GPU-less machine with Godot's compatibility
renderer, so SSAO and volumetric fog, which need Forward+ on a real GPU, are missing.)*

## Quick start

```bash
git clone https://github.com/jawaman14/skyrunner && cd skyrunner
GODOT=$(./tools/get_godot.sh)         # pinned Godot 4.7.2 into .tools/ (or use your own 4.7 install)
$GODOT --path .                       # the lobby: pick a mode, or host or join a game
$GODOT --path . -- --unlocks open     # skip the lobby: everything open from the first minute
./tools/test.sh                       # the test suite, headless (about 7 minutes)
```

Nothing to build: you can also just open the folder in Godot 4.7 and press play. Press **F1** in game for the
keys, **F8** to rebind them, **F4** for the multiplayer menu.

## The game

### Fly

- **Five aircraft** with every item a point mass at its station arm, a **load planner** that shows the take-off
  and zero-fuel centre of gravity moving on the envelope, and tight bush strips where the numbers matter.
- **A flight model written for the game** (`scripts/sim/flight/`): propeller torque, stalls, wind,
  gusts and rain, flown with keyboard assist, a gamepad, a yoke or pedals (every control rebindable, F8).
- **Weather you can see and plan around.** A nightly forecast (right three times in four), the moon, storms that
  ground helicopters and balloons, sea fog, wet roads, fire and smoke that lean downwind, street lamps and headlights
  that really light the street.
- **Radar and radio that behave like the real thing.** A 4/3-earth horizon, sea clutter, an MTI notch, real squawk
  codes; VHF line of sight over the terrain; direction finding that fixes the length of your calls.

### Run the coast

- **The story** (the default): twelve chapters, 1979 to 1988 (*Square Grouper*, *The Connection*, *Blotter*, *Cocaine
  Cowboys*, *Family Business*, *The Task Force*, *Isla Soberana*, *The House*, *The Company*, *Kingpin*, *The Hearings*, *Last Flight*). Each chapter opens part
  of the game, so you meet each system on its own. *Unlocks: Open* has all of it from the start; the old flying
  campaign is still there as the *Tutorial* (Palmetto Cay, four chapters).
- **A dedicated server** (`docs/SERVER.md`): run the game headless on a cloud VM (Docker, systemd, or a Google Compute Engine script) and let
  friends join as remote seats, with a password, saves, an AI pilot and a status probe.
- **Costa Brava**, the default map: the port city of San Telmo (about 6,900 buildings), docks, an airport, a river
  and mangrove estuary, a farm plain, a jungle range, the cove and the cays. Or a generated island (`--map N`).
- **Logistics and trade.** Product and cash are somewhere: trucked, flown, hijacked, stopped at checkpoints. Fuel
  has a price. Dealers sell corner by corner, bulk buyers take lots, and the markets move with arrests, raids,
  rivals and storms.
- **Hired hands.** Soldiers, drivers, mules, lookouts, accountants and pilots on a payroll, with wages, loyalty
  and people who walk off or talk.
- **The ground war.** Squads on foot and in cars fighting over the streets, with veterans who rank up and field
  orders you can give on foot. Rival cartel Los Cuervos fights back and splits the task force's attention.
- **Renown, rackets and stash works.** How big your name is (it changes prices, hiring and how closely you are
  watched); tribute from the streets you hold and the prisoners you take; a hidden vault and a guard post for each
  stash.
- **The arena.** A street race in the car and an air circuit at every strip, for prize money and renown.
- **Powers that help and hurt.** The Family (a Cosa Nostra family whose offers might be traps), the Company (a
  covert arms pipeline that protects you until it does not), Isla Soberana (cheap product over the horizon, a General
  who sells passage), and a federal **court** when you are busted: bail, lawyers, motions, pleas, juries, sentences.
- **On foot.** Walk the apron, the hangars and the headquarters; draw a gun; carry a pack; use the phone for crew,
  buyers and a taxi; drive the car beside the aircraft, with real 1979-86 broadcasts on its radio.
- **A tutorial** that teaches by doing, in any mode, for every seat.

### Hunt them

- **The task-force desk**: the radar picture, dispatch, aerostat, encryption, informants, wiretaps, audits and
  budget; upgrade trees for both sides; stakeouts, tails, buy-busts, checkpoints and SWAT on the ground.
- **The two HQs' seasons**: the organisation's boss and the task force's chief give nightly orders against each
  other's, with a rival cartel as a third player.

### Play together

- **Every seat is the AI's until someone takes it**: pilot, co-pilot, spotter, boat, boss, lieutenant, controller,
  police pilot, cutter, chief or patrol. Join mid-game, take a seat, leave and the AI takes it back.
- **A waiting room** before the game starts: players join, pick seats and ready up; the host starts it.
- **Voice that works like a radio**: push-to-talk (`` ` ``), with a radio sound, channels by side, range and hills
  that cut you up, and a task force that can intercept the runners' net (or a scrambled channel if they encrypt).
- **The multiplayer menu (F4)**: games on your network, the table (mute, remove, seats, chat) and voice settings.

## Command line

All flags are optional; any flag skips the lobby.

| Flag | Meaning |
|---|---|
| `--unlocks story\|open` | the story chapters (default) or everything from the start |
| `--tutorial` / `--chapter N` | the tutorial; skip ahead to a story chapter |
| `--mode solo\|campaign\|coop\|versus` | game mode (co-op and versus host remote seats) |
| `--police` | the task-force desk against AI runners, offline |
| `--players N` / `--layer 1-5` | seats and rule layers for a table of N (5+ adds the HQs and seasons) |
| `--map city\|N` | `city` = Costa Brava (default for new games), `0` = the classic island, `N` = generated island N |
| `--graphics low\|medium\|high` | quality preset |
| `--watch` | the pilot bot flies the career; you watch |
| `--host` / `--port 47800` | open remote seats in solo |
| `--connect HOST:PORT [--role R] [--name N] [--seat3d]` | join; `--role pick` opens the live seat list |
| `--hour 0-24` / `--weather clear\|cloud\|storm[,moon]` | time of day and weather to start at |
| `--new` / `--seed N` | a fresh save / the job-board seed |
| `--shot out.png --frames N` / `--smoke N` | render and save a screenshot / run N frames headless and print `SMOKE OK` (CI) |

A dedicated server: `$GODOT --headless --path . --script res://scripts/net/dedicated.gd -- --port 47800`. Every
seat is run by the AI until a player claims it.

## For developers

The code is a seeded, replayable simulation that runs headless (`scripts/sim/`), with the 3D game, the 2D desks and
the network layered on top. [CLAUDE.md](CLAUDE.md) has the conventions; the short version:

- **Deterministic.** Every random draw is seeded on its own stream (the table is in
  [docs/DESIGN.md](docs/DESIGN.md)); new systems sit behind a static switch registered in `scripts/sim/switches.gd`,
  and a test scans the sim for global random draws and clock reads.
- **Warnings are errors.** Give locals an explicit type whenever the value is a Variant.
- **Tests.** `./tools/test.sh [filter]`: about 740 tests in 90 files, including parity and golden fixtures
  ([tests/fixtures/README.md](tests/fixtures/README.md)). CI runs them as three parallel shards, exports Linux,
  Windows and macOS builds and smoke-tests them ([.github/workflows/](.github/workflows/)).
- **Layout.** `scripts/sim/` the simulation (`Session` is a chain of layers, state to commands); `scripts/bots/`
  the pilot bot and route planning; `scripts/balance/` the balance simulators; `scripts/game/` the 3D pilot app;
  `scripts/station/` and `scripts/ui/` the 2D desks and menus; `scripts/net/` multiplayer and voice.
- **Balance** is measured, not guessed: `scripts/balance/cli.gd` and `tools/live_balance.gd` write
  [docs/BALANCE.md](docs/BALANCE.md) (a change needs at least 200 seeds behind it).

```bash
$GODOT --headless --import                                              # after adding scripts or assets
$GODOT --headless --path . -- --unlocks open --watch --new --smoke 1800  # the CI smoke run
$GODOT --headless --path . --script res://scripts/balance/cli.gd -- all --workers 4
```

The game started as a Python prototype, kept on the git tag `python-prototype-archive`; it generated the frozen
parity fixtures and you never need it to build, play or test ([docs/PORTING.md](docs/PORTING.md)).

## Docs

- [docs/GUIDE.md](docs/GUIDE.md): the player's guide: every role, every mechanic and every key.
- [docs/FEATURES.md](docs/FEATURES.md): the long feature reference (what the README used to list, system by system).
- [docs/DESIGN.md](docs/DESIGN.md): roles, gadgets and counters, every system, the storyline, the ground war, the
  seat model, voice and the waiting room.
- [docs/MULTIPLAYER.md](docs/MULTIPLAYER.md): design research for asymmetric versus play, hidden information and the
  network protocol.
- [docs/BALANCE.md](docs/BALANCE.md): the balance report, with a numbered entry for every change.
- [docs/ROADMAP.md](docs/ROADMAP.md) and [docs/REVIEW_2026-10.md](docs/REVIEW_2026-10.md): what is done and the work queue.
- [docs/LIBRARIES.md](docs/LIBRARIES.md): the open-source libraries and art used or considered.
- Demo videos in [docs/video/](docs/video/): the UI, the on-foot tour, the city, the ground war and a bust.

## Licences

The game's own code and content are MIT ([LICENSE](LICENSE)). All the people, organisations and places in it are fictional.

- **Aircraft data.** The aircraft, engine and propeller descriptions in `data/jsbsim/` come from the JSBSim project
  and are LGPL-2.1 (`data/jsbsim/COPYING.LGPL`). They are data read by the game's own flight model; changed files
  say so in an XML comment. No JSBSim code is shipped.
- **Radio recordings are the exception.** `assets/radio/` holds short excerpts of real 1979-86 broadcasts from the
  Internet Archive, included at the project owner's decision for a historical-fiction game. They are **not** CC0 or
  MIT; read [assets/radio/README.md](assets/radio/README.md) before redistributing.
- **Art.** Low-poly models from Kenney (CC0, `assets/models/kenney/`), KayKit's City Builder Bits (CC0) and
  Quaternius's Downtown City MegaKit (CC0); Kenney's particle sprites and UI sounds (CC0). Fonts are Kaushan Script
  and Monoton (SIL OFL, `assets/fonts/`). Every other sound is synthesized in `scripts/game/sound.gd`.
- **Add-ons** (all in `addons/`, each with its licence): Dialogue Manager and Input Helper (Nathan Hoad, MIT), Debug
  Menu (Hugo Locurcio, MIT), SimpleGodotCRTShader (Henrique Lacreta Alves, MIT) and GATO's colour-blindness shader
  (MPL-2.0, unmodified). Godot and Jolt are MIT.

[docs/LIBRARIES.md](docs/LIBRARIES.md) lists the libraries considered and the art removed again.
