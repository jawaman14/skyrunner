# Current handoff

## Agent work-split document import — 2026-10-11

Codex imported the owner's [Google Doc](https://docs.google.com/document/d/1Gvc3qsZruv8uB6FWVj6YUqyqVabRRi9caebwn9nCdrE/edit) into [docs/AGENT_WORK_SPLIT.md](docs/AGENT_WORK_SPLIT.md), preserving the original proposal, review replies, consolidated operating decisions, templates, gate register and repository-check snapshot. Repository counts and PR statuses in that document are historical claims, not fresh verification. This import does not apply the proposed instruction-file or roadmap rewrites.

Validation: converted the complete native document's one tab, including tables, lists and embedded command blocks; checked the source section coverage. Documentation-only change; game tests were not run. Next: review this draft PR and reconcile any adopted guidance with #293 before changing shared instructions. Human release gates remain outstanding.

Also imported both tabs of the owner's [allocation spreadsheet](https://docs.google.com/spreadsheets/d/1IEaOf5spBK-FMJp5IIRZeUk1k_U7BNheWPZpUhhoZto/edit) as CSV and [a reviewed Markdown snapshot](docs/AI_WORK_ALLOCATION.md). Review findings: correct #244's faction scope label; start the gate register before test runs; add #297/#298 review assignments and explicit human visual/traversal gates; extend bounded summary COUNTIF ranges when adding rows. All 23 source task values are preserved; the live Sheet was not edited. PR #299 includes both planning imports. GitHub query returned 22 open PRs; no CI or human gates were freshly validated in this tracker review.

The authoritative current state is [docs/PROJECT_STATUS.md](docs/PROJECT_STATUS.md).
Its source inventory is generated; regenerate with `godot --headless --script res://tools/project_status.gd -- --write` after source changes. Passing runs and human gates remain separately recorded.
Historical handoff notes below are retained for provenance and are not current
test or feature claims.

# Update 2026-10-03: everything below the line was written on 2026-09-28; this is what changed since

**Where things are.** `main` has all of the work stacked since the cloud handoff (PRs #1-#38, merged bottom-up
as merge commits). Tests: see [PROJECT_STATUS.md](docs/PROJECT_STATUS.md); this historical note is retained for provenance. CI was green on the recorded baseline
(tests, exports, smoke). The balance re-fly (K3) that item 1 below describes was finished (BALANCE entry 35) and
the playtest list's first wave was done (pause menu, runway/landing fixes, roads, autopilot routing, crew).

**What was added** (each has a DESIGN section and a ROADMAP line; most have a BALANCE entry, newest last in `docs/BALANCE.md`):
- Physical NPCs: `Agent` and its task queue, drivers in every stash truck, a squad is its men, the 3D world draws them,
  road pathfinding, the payroll's people are bodies; a phone on foot; a taxi; a drivable starter car.
- Ring roads, La Selva kept isolated on purpose, the turf war's engagement geometry, strategic saves (stashes, crew, case, court, squads).
- Logistics: fuel for the hired fleet and multi-stop rounds. Mount and Blade-inspired systems, each behind an `ENABLED`
  switch: renown, veteran squads + field orders (Z/X/C/V on foot), the rackets (tribute, prisoners), stash works, the arena (races).
- A car radio with real 1979-86 recordings (`assets/radio/`; **not CC0**, see its README), and a `user://radio/` folder for your own.
- Art: ~3,000 Kenney/KayKit/Quaternius CC0 models and 2D sprites vendored; the city is dressed with them (`CityDress`), scenery,
  road markings, the villa and the club furnished, the city's buildings are solid (`CityDress.colliders`).
  Still unused: the Pirate kit (docks), Quaternius downtown, the 2D packs.

**Working notes that will save you time:**
- `skyrunner-godot/` (an untracked stray folder in the repo root) must never be `git add`ed: stage files by name.
- Balance runs: `tools/live_balance.gd -- 200 3 [config]`; 40 seeds is noise (+-$5k), use 200+. Run variants in separate
  `git worktree`s (never switch branches under a running job), copy `sim-results/strategic.json` (gitignored) into a worktree
  before `cli.gd -- report` or BALANCE.md loses section 3. `live.json` keeps only mean/p10/p50/p90.
- Screenshots work on Windows: `--headless --import` first (after switching branches too), then the console exe with
  `--audio-driver Dummy --resolution 1280x720 --script tools/shots/pilot_shot.gd -- ...`, but call
  `RenderingServer.force_draw(true)` before `get_image().save_png` or the PNG is flat grey.
- Tests that load the city map must call `World.use_map(0)` afterwards (`after_each`), or `test_world`'s Python-parity checks fail.
- CI once failed ~40 model-load checks from a cold-import timeout; a re-run passed (`tools/test.sh` now allows 900 s for the import).
- Not checked by eye: the club's furniture layout (the club only exists on the city map), the air circuit's gates.

---

# Handoff: cloud session → local development (2026-09-28)

**The project lives at https://github.com/jawaman14/skyrunner (`main`).** It moved out of the AutoGPT
fork on 2026-09-28 with full history (`git subtree split` of `games/skyrunner-godot`).
jawaman14/AutoGPT#5 is closed, and the `claude/cargo-flight-game-2g413p` branch there is an archive:
don't develop on it. Everything from the cloud session is committed and pushed here; nothing was left
uncommitted, stashed or on other branches.

Read these with this file:
- `CLAUDE.md`: commands and conventions;
- `docs/ROADMAP.md`: the prioritised queue;
- `docs/DESIGN.md`: the systems.

## Current state
- **Beta 0.9.0-beta.1.** Pure GDScript on Godot 4.7.2: no GDExtension, no JSBSim library. The game's
  own 6-DOF model (`scripts/sim/flight/`) reads JSBSim-format XML as data.
- **Tests:** historical handoff count; see [PROJECT_STATUS.md](docs/PROJECT_STATUS.md) for current verified evidence.
- **CI** (`.github/workflows/skyrunner-beta.yml`) runs on `main`, pull requests and manual dispatch:
  - tests;
  - exports for Linux, Windows and macOS (universal, ad-hoc signed);
  - a headless AI-flown smoke run on Linux and Windows;
  - an llvmpipe screenshot on Linux.
  - Builds are the run's artifacts.
- **Terrain:** the built-in maps' terrain is baked in `data/terrain/*.bin` (zstd). Generated islands
  are cached in `user://terrain`.

## What was in progress / next
1. **Balance re-fly (K3).** The balance was measured with JSBSim, and the Godot model flies differently.
   - The tactical sweep hadn't finished when the session moved, and `sim-results/tactical.json` and
     `calibration.json` are still the JSBSim-era numbers.
   - Steps: re-run tactical, then feasibility, then strategic, then live_balance, and write BALANCE
     entry 35. Commands and targets are in `docs/ROADMAP.md` §1.
   - The pilot bot fixes that led up to it are committed:
     - the approach speed floor;
     - holding the glide path altitude en route to hilltop strips;
     - the go-around window;
     - `Session.ARRIVE_MARGIN_M`;
     - the C182/PA-28 castering mains.
2. **The playtest feedback list** in `docs/ROADMAP.md` §2. None of it is started. The first wave:
   - the Esc pause menu (Esc currently quits: `pilot_app.gd` about lines 309 and 377,
     `station_app.gd` about line 319);
   - runways and landing;
   - throttle steps;
   - F1 scrolling;
   - a compass with wind;
   - the tutorial's red squares;
   - crew auto-hire and instant deaths;
   - the autopilot circling, its routing, and flying differently with illegal cargo.

## Open bugs and known issues
- **Windows + AMD (RX 7900 XT), Vulkan:** the CI build crashes at startup with 0xC0000374 (heap
  corruption) after shader compilation. Seen from local testing.
  - The log shows duplicate `VK_LAYER_AMD_switchable_graphics` layers and a missing Rockstar Social
    Club Vulkan layer. These are implicit layers registered by other software.
  - It runs fine with `--rendering-driver opengl3`.
  - **Diagnosed (2026-09-29): not a game bug.** A leftover Vulkan Configurator override
    (`VK_LAYER_LUNARG_override` in `HKCU\SOFTWARE\Khronos\Vulkan\ImplicitLayers`) forces
    `VK_LAYER_KHRONOS_validation` into every Vulkan app. With `VK_LOADER_LAYERS_DISABLE=VK_LAYER_LUNARG_override`
    the build runs under Vulkan (Forward+). INSTALL.md troubleshooting now covers it.
  - Still open: an automatic fallback (`rendering/rendering_device/fallback_to_opengl3`) only helps
    when Vulkan fails to initialise, not for this mid-run crash, so it isn't worth adding for this.
- **DHC-6 flaps:** the aircraft balloons when its flaps are lowered at speed. The aero data is at
  fault (it did the same under JSBSim). Documented in BETA.md.
- **Hands off at high power,** some aircraft roll slowly left from propeller torque. That's
  intended, and the tests allow for it.
- **Leak messages:** headless test runs end with "RID allocations leaked at exit" errors. They're
  harmless, and the runner's own summary line is what counts.

## Conventions the next agent must follow
Details are in CLAUDE.md. The ones that bite:
- **Warnings are errors.** Type any variable whose value comes from a Variant, or the script
  silently fails to parse, which looks like a hang.
- **Determinism.**
  - New randomness goes on a new RNG stream.
  - New systems go behind a static switch that the parity tests turn off.
  - Never regenerate the Python-frozen fixtures.
  - Regenerate the Godot golden fixtures (`tools/regen_flight_golden.gd`) only for an intended
    flight change, and say so in the commit.
- **Keep the repo clean.** Scratch scripts go outside it; `sim-results/strategic.json` (11 MB)
  stays gitignored.
- **Keep it fictional:** no real people, organisations or brands.
- **Workflow:** a feature branch, then a PR to `main`, and the CI must be green.

## Testing
- **Full suite:** `./tools/test.sh`, or `./tools/test.sh flight` to filter by file name.
  - It needs bash. On Windows use Git Bash, with `GODOT` pointing at the Godot 4.7.2 console exe,
    e.g. `export GODOT="/c/Godot/Godot_v4.7.2-stable_win64_console.exe"`.
  - `TEST_TIMEOUT` (default 900 s) raises the limit.
- **Smoke:** `"$GODOT" --headless --path . -- --unlocks open --watch --new --smoke 1800`, which
  prints `SMOKE OK`.
- **Screenshot:** `"$GODOT" --path . -- --new --shot out.png --frames 240`.
- **Export:** Project → Export, or `--export-release Windows export/windows/Skyrunner.exe`. This
  needs the 4.7.2 export templates.

## Environment not in the repo (all regenerable)
- The Godot binary: `./tools/get_godot.sh` fetches the Linux one into `.tools/`. On Windows, install
  Godot 4.7.2 yourself.
- The export templates, in `~/.local/share/godot/export_templates/4.7.2.stable/` on Linux or
  `%APPDATA%\Godot\export_templates\4.7.2.stable\` on Windows.
- `user://` holds saves, `terrain/` caches and `feedback/`. Nothing there is needed for development.
- `sim-results/strategic.json` is regenerated by `cli.gd -- strategic`.
- No environment variables beyond `GODOT` and `TEST_TIMEOUT`, and no secrets.
