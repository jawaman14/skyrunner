# Skyrunner: notes for Claude Code

Pure GDScript on Godot 4.7.2. No native code, no plug-ins to build. See README.md for the game,
docs/DESIGN.md for the systems, and docs/ROADMAP.md for the work queue.

## Commands
```bash
GODOT=$(./tools/get_godot.sh)                 # pinned 4.7.2 into .tools/ (Linux); elsewhere use your own 4.7.2
$GODOT --headless --import                    # after adding scripts/assets (refreshes the class cache)
./tools/test.sh [filter]                      # the suite: ~470 tests, 7-9 min headless; TEST_TIMEOUT to raise
$GODOT --path . -- --unlocks open             # play, open mode
$GODOT --headless --path . -- --unlocks open --watch --new --smoke 1800   # CI's headless smoke run
$GODOT --headless --script res://scripts/balance/cli.gd -- feasibility|tactical|strategic|report [--seeds N --workers N --n N]
$GODOT --headless --script res://tools/regen_flight_golden.gd   # after a deliberate flight-model change
$GODOT --headless --script res://tools/bake_terrain.gd          # after a terrain generator change
```
On Windows, run the same through Git Bash or WSL, or call the Godot exe directly.

## Conventions
- **Warnings are errors** (project setting). Give variables an explicit type whenever the right
  side is a Variant (`var fl: float = floor(y)`, `var vp: Window = ...`); an untyped inference
  makes the whole script fail to parse, which looks like a hang in headless runs.
- An Array used as a `%` format argument must be wrapped: `"%s" % [arr]`.
- **Determinism:** the sim is seeded and replayable. New random draws go on their own RNG stream
  (see the stream table in docs/DESIGN.md), never on an existing one, or the parity/golden
  fixtures shift. New systems sit behind a static `ENABLED`-style switch that the parity tests
  turn off.
- **Fixtures:** tests/fixtures/README.md says which are frozen from the Python prototype
  (reference/python, archival; never regenerate casually) and which are Godot golden files
  (`T.golden()`, regenerate only for an intended behaviour change and say so in the commit).
- Balance changes get a BALANCE entry via `cli.gd -- report` (docs/BALANCE.md is generated).
- Scratch scripts go outside the repo, never `tools/zz_*`.
- Content stays fictional: no real people, organisations or brands.
- Work on a feature branch and open a PR into `main`; CI (.github/workflows/skyrunner-beta.yml)
  runs the suite, exports Linux/Windows/macOS and smoke-tests them.

## Layout
- `scripts/sim/` headless simulation (Session, world, police, economy, ground war, logistics...);
  `scripts/sim/flight/` the 6-DOF flight model reading JSBSim-format XML in `data/jsbsim/`.
- `scripts/bots/` PilotBot and route planning; `scripts/balance/` the balance simulators.
- `scripts/game/` the 3D pilot app, walker, HUD; `scripts/station/` the 2D desks; `scripts/ui/`.
- `scripts/net/` multiplayer (protocol v3, seats). `tests/` one file per system.
