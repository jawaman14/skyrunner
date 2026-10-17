# Skyrunner: notes for coding agents (Claude Code and Codex)

This is the single rules file. `CLAUDE.md` only imports it, so both agents read the same text.

**Working mode: dual work** (owner, 18 October 2026, D-52). Each agent owns its lanes end to end: it writes, tests and
merges its own work, and Codex is not only a reviewer. The lanes are in ROADMAP "Working structure". Jobs pass between
the agents on the board: an `assign` note (`assign <task> | files | base SHA | test command | done when`) that the other
agent answers by claiming the task. **The other agent's exact-head review is mandatory only for risk-class PRs:** any change
to saves (`StrategicSave`, save formats), a new random draw or RNG stream, goldens or frozen fixtures, the `Session` layers
(`scripts/sim/session_*.gd`), the flight model, or balance numbers, and any PR whose author asks for one. Every other PR
the author merges when CI is green on the head, every review thread has a reply, and they have read their own diff. The
other agent may still review after the merge and fix what it finds. Human release gates stay the owner's.

**Earlier mode: simultaneous, Claude Code leads** (owner, 11 October 2026; kept for the task format). Both agents work at the same time.
Claude Code turns the [HANDOFF.md](HANDOFF.md) baton into tasks, keeps Tier A and B (below) and posts at most three
Tier C tasks at a time to Codex, each with a goal, base SHA, allowed files, test command and done-when. Codex
implements those in parallel and reviews every Claude PR at its exact head; Claude reviews Codex's. Start every
session with HANDOFF.md ("Taking over") and the board, and keep the baton current in every commit you push.

**One clone, one board.** The MCP board (`skyrunner_collaboration_start`, claims, notes; see
[tools/mcp/COLLABORATION.md](tools/mcp/COLLABORATION.md)) is a file in the clone's Git directory, so only linked
worktrees of the same clone share it. On the owner's machine the canonical clone is
`%USERPROFILE%\Documents\ChatGPT\skyrunner`: work in your own linked worktree of it (Claude in `~/.claude-worktrees/`,
Codex in `~/.codex/worktrees/`), never in a second clone or in another agent's worktree. Codex cloud and other
machines have no board; they use pushed branches and the committed HANDOFF.md.

**Everything through the MCP** (owner, 11 October 2026). Board reads, claims and notes, Godot imports, tests,
smoke and balance runs, and GitHub reads and writes go through the `skyrunner` MCP tools, so both agents share
its claims, job locks and merge guards. Never write the board's database directly or start Godot from a shell
beside it; if a tool is missing, add it to skyrunner-mcp.

**Board etiquette.** One owner id per session (`claude-<session id>`, `codex-<thread id>`). A claim is the
acknowledgement: no notes that only say "ack". Notes stay short (see Compact notes), as
`task | branch@sha | tests run (pass/total) | not run | PR | next or ask`; the detail goes in the PR body. Claims
and notes coordinate; they never authorize. `python tools/collab/board_status.py` (read-only, about ten lines) shows who has
not answered what, so check it before assuming silence means no. `python tools/collab/notify.py once --recipient <agent> --cursor-file <path>` is a silent-when-nothing-new check (exit 10 when a note arrived); `python tools/collab/wake_codex.py watch --session <id> --cursor-file <path>` resumes that Codex session with one fixed prompt when a note for it arrives (cooldown, hourly cap, one at a time, `--dry-run`; it spends Codex quota), and
`watch` rings a terminal bell or Windows toast when one does; a scheduled agent should call `once` rather than read the board. Merging, closing issues and anything published need the owner's word
in that agent's own chat, or a standing rule under **Owner decisions** in HANDOFF.md.

**The pipeline** (issue to `main`, roles, limits, review tiers, known stalls): [docs/PIPELINE.md](docs/PIPELINE.md).

**Compact notes** (owner asked for fewer tokens, 11 October; the 10 to 11 October averages were about 500 characters a note). Aim for
under 250 characters: no greeting, thanks, recap or restating what a PR, commit or earlier note already shows; cite it by
`#PR@sha7` or `n<id>`. Shape: `<refs> <verb>: <fact> | <ask>`, verbs `done`, `review +/-`, `block`, `ask`, `fyi`. Evidence goes in the
PR body or a doc, the note carries the pointer. Send nothing when there is no new fact and no ask; the read cursor is the receipt,
and a woken turn answers with at most one note. Read with `after=<cursor> limit=20`, never the whole board; use
`tools/collab/board_status.py`, `notify.py once` and `dashboard.py` (the board only), and the MCP tools `github_merge_queue`, `github_review_packet` and `github_pr_states` for GitHub state, instead of full reads. A
visible receipt is only for an owner-required one: `ack <id>`.

**Merging** (one PR at a time; since 18 October each author merges their own, see Working mode). The author keeps the
merge queue in the HANDOFF baton and merges through the MCP's `github_pr_merge` (it refuses unless CI is green on the expected head SHA and
every review thread has a reply), never `gh pr merge`. Before a PR joins the queue:
1. its author merges current `main` into it in their own worktree (merge, not rebase, so review history survives),
   reruns the focused tests and regenerates `docs/PROJECT_STATUS.md` last. `python tools/collab/sync_shared.py` does the
   merge and resolves the three files every PR collides on (HANDOFF's Log, the test count, the test lanes); it stops
   and leaves the merge open if anything else conflicts;
2. if it is a risk-class PR, the other agent reviews the exact head, including how conflicts were resolved
   (`git show --remerge-diff <merge>` shows only the resolution);
3. CI is green on that head.

After each merge, the next PR in the queue merges `main` straight away. Run `github_pr_triage` each session: it
shows which open PRs conflict with `main` and with each other, so overlapping work is split or ordered before
either side builds on it. A PR whose files another open PR rewrites waits for that one, then merges `main`. Keep
PRs short-lived: anything more than about a day or 20 commits behind `main` merges `main` before more work goes
on it. Merges need the owner's word or a standing rule: D-52 (dual work mode) in docs/DECISIONS.md is the standing rule for each
author's own PRs.

**Heavy jobs.** One full suite, cold import or balance run on the machine at a time. The server now takes a
machine-wide Godot lock (skyrunner-mcp #1), so jobs from either agent queue instead of exhausting commit memory
(Windows has run out doing it). The MCP's test tools run in the primary checkout only; from a linked worktree use
`python tools/collab/run_locked.py test <filter>` (also `import`, `status [--write]`, or `-- <command>`), which takes
the same lock. Say on the board when you start and finish a long one, and reuse CI results for a SHA instead of
rerunning them locally.

**Lanes** (from the 11 October work split, archived in [docs/archive/AGENT_WORK_SPLIT.md](docs/archive/AGENT_WORK_SPLIT.md)):
Tier A (Session layers, RNG, goldens, saves, sim and map geometry, flight, balance) is Claude Code's. Tier B
(bounded UI/gameplay behind a stable interface) is either, with the other reviewing. Tier C (repeated UI
patterns, isolated tests, docs, CI tooling, issue triage) is Codex's. A Tier C task that needs a new random draw,
a golden, a save-format change or a `scripts/sim/session_*.gd` edit stops and says so in the PR. Neither agent
can mark a human release gate passed; those are recorded in `docs/PROJECT_STATUS.md` with a build SHA. Since 12 October Codex also
leads UX/UI and dialogue (Claude reviews) and runs the QA lane: sims, full suites, sweeps and balance runs.

**MCP server:** it lives in its own repository, [skyrunner-mcp](https://github.com/jawaman14/skyrunner-mcp);
this repo only holds the pinned launcher (`tools/mcp/`, `.mcp.json`). Server changes go there, then bump the pin
in `tools/mcp/launch.py` in a reviewed commit.

Pure GDScript on Godot 4.7.2. No native code, no plug-ins to build. See README.md for the game,
docs/DESIGN.md for the systems, and docs/ROADMAP.md for the work queue. See HANDOFF.md for the baton, and
docs/README.md for every document; dated reports and old plans are in docs/archive/ (records, not instructions).

## Owner decisions: the ledger (owner, 18 October 2026)

Every owner decision goes into [docs/DECISIONS.md](docs/DECISIONS.md) in the session it is made, with where its work is
tracked (a `ROADMAP: <section>` or a PR/issue); `tests/test_docs.gd` fails a row with no tracker. Read the ledger before
planning or rewriting the roadmap (Claude's SessionStart hook prints the open rows). Before a session's final report,
check the owner's messages for decisions not yet in it. Work items also go on #328 (Claude) or #329 (Codex).

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
