# Skyrunner: notes for coding agents (Claude Code and Codex)

This is the single rules file. `CLAUDE.md` only imports it, so both agents read the same text.

**Working mode: relay.** The owner runs one AI until its tokens run out, then the other. Start every session with
[HANDOFF.md](HANDOFF.md) ("Taking over") and keep its baton current in every commit you push. If two sessions
ever overlap on one checkout, use the MCP board (`skyrunner_collaboration_start`, claims, notes; see
[tools/mcp/COLLABORATION.md](tools/mcp/COLLABORATION.md)) and separate linked worktrees. Claims coordinate; they
do not authorize anything.

**Lanes** ([docs/AGENT_WORK_SPLIT.md](docs/AGENT_WORK_SPLIT.md), tracker [docs/AI_WORK_ALLOCATION.md](docs/AI_WORK_ALLOCATION.md)):
Tier A (Session layers, RNG, goldens, saves, sim and map geometry, flight, balance) is Claude Code's. Tier B
(bounded UI/gameplay behind a stable interface) is either, with the other reviewing. Tier C (repeated UI
patterns, isolated tests, docs, CI tooling, issue triage) is Codex's. A Tier C task that needs a new random draw,
a golden, a save-format change or a `scripts/sim/session_*.gd` edit stops and says so in the PR. Neither agent
can mark a human release gate passed; those are recorded in `docs/PROJECT_STATUS.md` with a build SHA.

**MCP server:** it lives in its own repository, [skyrunner-mcp](https://github.com/jawaman14/skyrunner-mcp);
this repo only holds the pinned launcher (`tools/mcp/`, `.mcp.json`). Server changes go there, then bump the pin
in `tools/mcp/launch.py` in a reviewed commit.

Pure GDScript on Godot 4.7.2. No native code, no plug-ins to build. See README.md for the game,
docs/DESIGN.md for the systems, and docs/ROADMAP.md for the work queue. See HANDOFF.md for the relay.

## Commands
```bash
GODOT=$(./tools/get_godot.sh)                 # pinned 4.7.2 into .tools/ (Linux); elsewhere use your own 4.7.2
$GODOT --headless --import                    # after adding scripts/assets (refreshes the class cache)
./tools/test.sh [filter]                      # the suite; generated inventory and verification evidence: docs/PROJECT_STATUS.md
godot --headless --script res://tools/project_status.gd -- --write  # refresh source facts after adding tests/chapters/exports
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
  turn off. Register every new switch in `scripts/sim/switches.gd` (`tests/test_switches.gd` fails if one is
  missing, and also scans the sim for global random draws and clock reads).
- **Fixtures:** tests/fixtures/README.md says which are frozen from the Python prototype
  (the `python-prototype-archive` tag, archival; never regenerate casually) and which are Godot golden files
  (`T.golden()`, regenerate only for an intended behaviour change and say so in the commit).
- Balance changes get a BALANCE entry via `cli.gd -- report` (docs/BALANCE.md is generated).
- Scratch scripts go outside the repo, never `tools/zz_*`.
- Content stays fictional: no real people, organisations or brands.
- Evidence goes in the PR body, not new dated files under `docs/`.
- Work on a feature branch and open a PR into `main`, one slice per PR, branched from current `main` (never stack drafts); CI (.github/workflows/skyrunner-beta.yml)
  runs the suite, exports Linux/Windows/macOS and smoke-tests them.

## Layout
- `scripts/sim/` headless simulation (Session, world, police, economy, ground war, logistics...). `Session` is a
  chain of layers, each extending the one below: `session_state` (constants, members, helpers, persistence) <
  `session_rules` < `session_ops` < `session_tick` < `session_commands` (`command()`: permissions, preview gate, outcome
  messages) < `session` (construction). A layer may only call down. The `_cmd_*` handlers are static functions in six
  domain modules, `scripts/sim/cmds_{air,crew,ground,trade,court,org}.gd`, taking the Session as an argument; a new
  one goes in the right module, is registered in `command_domains.gd` and permitted in `roles.gd`;
  `scripts/sim/flight/` the 6-DOF flight model reading JSBSim-format XML in `data/jsbsim/`.
- `scripts/bots/` PilotBot and route planning; `scripts/balance/` the balance simulators.
- `scripts/game/` the 3D pilot app, walker, HUD; `scripts/station/` the 2D desks; `scripts/ui/`.
- `scripts/net/` multiplayer (protocol v3, seats). `tests/` one file per system.
