# Notes for coding agents (Codex and others)

This repository's conventions are in [CLAUDE.md](CLAUDE.md): commands, the warnings-as-errors rule, determinism
and RNG streams, switch registration, fixtures, balance reports and the code layout. They apply to every agent,
not only Claude.

**Start every session with [HANDOFF.md](HANDOFF.md).** The owner alternates between Claude and you: one AI works
until its tokens run out, then the other continues. Follow the file's "Taking over" checklist, pick up from the
baton's next step, and keep the baton current in every commit you push (a session can end mid-task without
warning). Record the owner's decisions there; the other AI can't see your chat.

`tools/mcp/` has an MCP server for this project (tests, smoke runs, screenshots, PR triage, CI logs); see its
README if your client supports MCP.
