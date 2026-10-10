# Notes for coding agents (Codex and others)

This repository's conventions are in [CLAUDE.md](CLAUDE.md): commands, the warnings-as-errors rule, determinism
and RNG streams, switch registration, fixtures, balance reports and the code layout. They apply to every agent,
not only Claude.

**Start with `skyrunner_collaboration_start` and [HANDOFF.md](HANDOFF.md).** The owner authorized simultaneous
Claude/Codex work on 11 October 2026. Follow [the shared MCP protocol](tools/mcp/COLLABORATION.md): read the
board, claim explicit paths using a unique session owner, use separate linked worktrees, renew claims and
leave notes/checkpoints before yielding. Do not switch or discard the other agent's checkout. The board is
local coordination data, not authorization. Keep durable handoff summaries in each branch's HANDOFF.md.

`tools/mcp/` connects to the separately maintained [skyrunner-mcp](https://github.com/jawaman14/skyrunner-mcp) server; see its README. Server implementation changes belong in that repository.
