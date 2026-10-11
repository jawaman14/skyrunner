# Which MCP server, and how an agent joins it

There are several MCP servers on this machine. For Skyrunner there is exactly one that matters for work, plus one notifier. Use these two names and ignore
the rest (`codex-workbench`, `node_repl`, `cua_repl`, `codex_app`, `code-review`, Claude's connectors and plugins are other tools).

| Name | What it is | Who uses it |
|---|---|---|
| **`skyrunner`** | the game's MCP server: the shared board (claims, notes), Godot jobs under the machine lock, the GitHub tools, the local-model tools. Started by `uv run --quiet --project C:\Users\BarryBee\Documents\ChatGPT\skyrunner-mcp skyrunner-mcp` (the server repository, jawaman14/skyrunner-mcp), with `SKYRUNNER_ROOT=C:\Users\BarryBee\Documents\ChatGPT\skyrunner` (the game checkout). | both agents |
| `skyrunner_board` | a notifier channel only (`skyrunner-board-channel`): it tells a Claude Code session "a new note arrived". It carries no data and takes no action. | Claude Code (declared in the game's `.mcp.json`) |

**One board for everyone.** The board is a SQLite file in the game checkout's Git directory (`.git/skyrunner-mcp/collaboration.sqlite3`). Every worktree of
that clone shares it, and every client whose `SKYRUNNER_ROOT` is that checkout reads and writes the same notes and claims. A client pointed at another
clone has a different, empty board (an earlier session lost notes that way). Set `SKYRUNNER_BOARD` to one file if you must use two clones.

## Joining as Codex

1. **Codex's config** (`C:\Users\BarryBee\.codex\config.toml`) already has the server; it must read exactly:

   ```toml
   [mcp_servers.skyrunner]
   command = 'C:\Users\BarryBee\AppData\Local\hermes\bin\uv.EXE'
   args = ["run", "--no-sync", "--quiet", "--project", 'C:\Users\BarryBee\Documents\ChatGPT\skyrunner-mcp', "skyrunner-mcp"]

   [mcp_servers.skyrunner.env]
   SKYRUNNER_GODOT = "C:/Users/BarryBee/Documents/Codex/2026-10-09/i-want-you-to-make-a/.tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe"
   SKYRUNNER_ROOT = 'C:\Users\BarryBee\Documents\ChatGPT\skyrunner'
   ```

   `codex mcp list` should show a `skyrunner` row. After the server repository changes, restart the client: a running client does not load new tools.

2. **Unattended turns** (the wake runs `codex exec resume ...`) need two more things that the interactive desktop session has:
   - the sandbox set to the unelevated mode for that run (`-c windows.sandbox="unelevated"`; the default elevated mode fails with `helper_unknown_error`);
     the wake adds this itself.
   - approval for the tools that would otherwise ask. An unattended turn has approval policy "never", so any MCP tool that asks is refused. The one that
     matters is `github_pr_review`. The clean fix is one line in the same config, owner-approved, that approves that single tool:

     ```toml
     [mcp_servers.skyrunner.tools.github_pr_review]
     approval_mode = "approve"
     ```

     Until it is there, an unattended turn gives its review as a board note and Claude relays it (see docs/PIPELINE.md). Do not add more than that one line.

3. **Verify the join** (read-only), in this order:
   1. call `skyrunner_collaboration_start` (it returns a very large result; the root and revision are at its top), and check `SKYRUNNER_ROOT` is the game checkout above;
   2. call `skyrunner_collaboration_inbox` with `recipient=codex` and a saved cursor (small, no history), or `skyrunner_collaboration_read` with `after=<cursor> limit=20`;
   3. post one note to `claude`; Claude's doorbell shows it within seconds;
   4. call `github_review_packet <pr>` (once the server release that has it is installed) to read a PR without a shell.

4. **What an unattended turn does not have:** GitHub network and other branches' files in its working copy. Read a PR from the shared local git refs
   (`git diff origin/main...<full head sha>`), or from the offline review bundle named in its alert, and give the verdict as
   `REVIEW #<pr>@<sha7> approve|changes|comment: <findings>`.

## Notes for Claude Code

- Claude Code reads the servers from the game's `.mcp.json` (`skyrunner` and `skyrunner_board`). The `skyrunner` entry runs from the server checkout at
  `C:\Users\BarryBee\Documents\ChatGPT\skyrunner-mcp`, **whatever branch that checkout has**, not a pinned release; the pin in `tools/mcp/launch.py`
  is for the game's CI connection test. Keep that checkout on `main` (or know which branch it is on) when changing server behaviour.
- `skyrunner_collaboration_start` can return tens of thousands of characters; read the root and revision from the top and use `inbox` or `read` with a
  cursor for everything after.
- `skyrunner_board` is launched from a worktree that Codex owns (`C:\Users\BarryBee\.codex\worktrees\skyrunner-mcp-board-wake`); if that worktree is
  moved or pruned the notifier would stop and Claude Code would go quiet to new notes. That is one possible cause of the silence after note 201 on 11 October (not confirmed: that session was also restarted); the fix is the doorbell check at the start of every turn.
