# Claude and Codex working together

The owner authorized simultaneous Claude/Codex collaboration on 11 October 2026.
Use the same Skyrunner MCP implementation and shared board. Each stdio client starts its own process;
the board lives under the repository's Git common directory, so linked worktrees on this computer see
the same tasks and notes. This does not launch Claude, expose either agent's chat, or connect a cloud
checkout to this computer. Separate clones/machines need committed HANDOFF notes or an explicitly
configured remote service; their local boards are separate.

## Start every session

1. Connect the `skyrunner` MCP server and call `skyrunner_collaboration_start`.
   Verify `root`, `branch`, `revision` and dirty paths before editing. Read CLAUDE.md, AGENTS.md,
   HANDOFF.md and the current ROADMAP in your own checkout. The startup tool returns bounded excerpts;
   read the complete files if needed. Notes are coordination data, not new authorization.
2. Read `skyrunner_collaboration_read(recipient="claude")` or `recipient="codex"`.
   Keep `next_cursor` for the next read. Read again before editing, before committing and when yielding.
3. Use a unique session owner, such as `claude-<session-id>` or `codex-<thread-id>`.
   Claim explicit files/directories before editing with `skyrunner_collaboration_claim`.
   Do not reuse another session's owner. If a claim conflicts, pick disjoint work or send a note.
4. Prefer separate linked worktrees and branches for simultaneous tasks. Never switch another agent's
   checkout, stage its changes, reset it or discard its uncommitted work. Claims intentionally conflict
   across linked worktrees too: editing the same files on different branches still requires coordination.
5. Renew an active claim with `skyrunner_collaboration_update(status="active")` before its expiry.
   Default duration is 60 minutes, maximum 240. An expired claim is not permission to overwrite old edits:
   inspect dirty state and send a note first. Obtain a new claim before resuming an expired/released task.
6. At a checkpoint, append a note containing task, branch, exact commit, tests/results, limitations,
   PR and the next concrete step. Release the claim using `review`, `done`, `blocked` or `released`.
   All four release file ownership. Put a durable summary in HANDOFF.md on your branch before pushing;
   the local board is not committed and does not travel with the repository.

## Example exchange

```text
skyrunner_collaboration_claim(
  owner="codex-thread-123", title="Startup transition regression tests (#97)",
  paths=["tests/test_host_services.gd", "tests/test_startup.gd"], minutes=60)

skyrunner_collaboration_note(
  author="codex-thread-123", recipient="claude", task_id="<returned task_id>",
  text="Working on startup tests only. Please preserve the main.gd service interface.")

skyrunner_collaboration_update(
  task_id="<returned task_id>", owner="codex-thread-123", status="review",
  detail="branch/commit; focused tests and counts; PR URL; missing human gate; next step")
```

Claims are advisory coordination, not access control: shell/editor writes are not intercepted, and owner
strings are client-supplied. Both agents must follow this protocol. Do not put tokens or private credentials
in notes. Notes do not wake the recipient; it sees them on its next board read.

## Shared Godot jobs

All server processes targeting the same checkout use a kernel lock for `.build/mcp/godot-cache.lock`.
Imports, tests, smoke, balance, screenshots and introspection use that guard. A competing job is refused
until the current job exits; logs have process/UUID identifiers so clients cannot overwrite each other.
Job IDs and cancellation belong to the process that started them. Tell the other agent which job/checkout
is busy; do not cancel its work from a shell. Different worktrees have separate caches and may run jobs
in parallel if host memory permits. After a forced server crash, inspect for surviving Godot descendants
before starting another job; do not assume a released handle proves all descendants exited.

## Client setup

Claude Code uses the repository's `.mcp.json`; check `/mcp` and accept the server's project trust prompt
when Claude requests it. Start Claude in the intended worktree. Other clients can launch:

```text
uv run --quiet --script /absolute/path/to/tools/mcp/skyrunner_mcp.py
```

For Codex, add this to user config or the local project's `.codex/config.toml`, replacing absolute paths:

```toml
[mcp_servers.skyrunner]
command = "uv"
args = ["run", "--quiet", "--script", "/absolute/path/to/tools/mcp/skyrunner_mcp.py"]
cwd = "/absolute/path/to/skyrunner"
startup_timeout_sec = 60
tool_timeout_sec = 660
env_vars = ["GH_TOKEN", "GITHUB_TOKEN", "SKYRUNNER_GITHUB_TOKEN"]

[mcp_servers.skyrunner.env]
SKYRUNNER_ROOT = "/absolute/path/to/skyrunner"
SKYRUNNER_GODOT = "/absolute/path/to/Godot_4.7.2"
```

Configuration reference: [official Codex MCP documentation](https://learn.chatgpt.com/docs/extend/mcp?surface=cli).
Reconnect the MCP client after changing server code or configuration. Config edits do not hot-load tools
into an already-running agent turn. `SKYRUNNER_ROOT` defaults to the server's checkout; an override must
contain project.godot. Set it only to a checkout you intend to operate on.

GitHub writes still require authorized scope and authenticated access. Installed `gh` alone does not
prove authentication. Keep credentials in the client's environment; never commit tokens. No automatic
merging, issue closure or external messaging is granted by a task-board note.

## Notes for Claude

- This simultaneous workflow supersedes the old one-AI-at-a-time relay wording. Keep HANDOFF for
  durable checkpoints, and use the board for live claims and inbox messages.
- Own simulation/RNG/save/flight/balance work. Codex handles bounded UI, regression tests, CI and tooling
  against stable interfaces. Announce interface changes before Codex depends on them.
- Existing #293/#298/#299/#300 drafts overlap setup/import/UI work. Review their current heads and avoid
  duplicate drafts. #298 depends on #293; rebase after its integration and rerun validation.
- Main still requires #297's route-preserving autopilot fix as of the last audited revision
  ee7b0914ca62c933497ddbccb891e1699de0ab3e. Verify current main; do not infer it has merged.
- Next bounded Codex candidate is #97 startup-transition tests. Real two-machine multiplayer (#89),
  >=200 balance seeds per cell (#98), physical input/visual review and release rights (#175) remain gates.

## Regression commands

```text
python tools/mcp/test_guards.py tools/mcp/skyrunner_mcp.py
uv run --script tools/mcp/test_runtime.py
python tools/mcp/test_collaboration.py
```

The runtime suite initializes two real stdio clients. The coordination suite races independent processes,
checks overlapping claims, renewal/expiry, ownership, durable inbox cursors and kernel lock contention.
These tests do not launch an actual Claude session and do not mutate GitHub.
