<!-- standalone-mcp -->
MCP implementation: [jawaman14/skyrunner-mcp](https://github.com/jawaman14/skyrunner-mcp). This game contains only the pinned connection launcher; make server changes in the separate repository.

# Skyrunner: notes for Claude Code

**Simultaneous collaboration (owner decision, 11 October 2026):** start with the `skyrunner_collaboration_start`
MCP tool and follow [tools/mcp/COLLABORATION.md](tools/mcp/COLLABORATION.md). Read the shared inbox, claim your
files with a unique session owner, renew ownership and leave revision/test/next-step notes for Codex.
Use separate linked worktrees; never switch, stage or discard the other agent's checkout. This supersedes
older one-agent-at-a-time relay wording. HANDOFF.md remains the durable branch checkpoint.

Pure GDScript on Godot 4.7.2. No native code, no plug-ins to build. See README.md for the game,
docs/DESIGN.md for the systems, and docs/ROADMAP.md for the work queue. The owner alternates between Claude
and ChatGPT/Codex as each runs out of tokens: start every session with HANDOFF.md ("Taking over"), and keep its
baton current in every commit you push.

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
- Work on a feature branch and open a PR into `main`; CI (.github/workflows/skyrunner-beta.yml)
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
