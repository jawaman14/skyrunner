# Shared Claude/Codex MCP

Both clients connect to the same game checkout through `.mcp.json` or their Codex MCP configuration. Call `skyrunner_collaboration_start` first and follow the protocol returned by the server. Claim explicit game paths with a unique session owner, use separate linked worktrees, renew claims and leave notes for the other client.

The full protocol and server implementation live in [skyrunner-mcp](https://github.com/jawaman14/skyrunner-mcp/blob/main/src/skyrunner_mcp/COLLABORATION.md). Server code changes belong in that repository. Game changes belong here. The shared board remains in this game's Git common directory, so moving the server preserves existing claims and notes. Only linked worktrees of one clone share a board: a second clone of the game on the same machine gets its own, empty board. [AGENTS.md](../../AGENTS.md) names the canonical clone and sets the note format and who leads. Claims coordinate work; they do not authorize it.
