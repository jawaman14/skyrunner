# Notes for coding agents (Codex and others)

This repository's conventions are in [CLAUDE.md](CLAUDE.md): commands, the warnings-as-errors rule, determinism
and RNG streams, switch registration, fixtures, balance reports and the code layout. They apply to every agent,
not only Claude.

Before you start and when you stop, read and update [HANDOFF.md](HANDOFF.md). It is the shared log between
agents and the owner: claims on work in progress, open questions, and what each session merged, verified and
left undone. Follow its Protocol section (one branch off `main` per slice, evidence in the PR body, no new dated
reports in `docs/`).

`tools/mcp/` has an MCP server for this project (tests, smoke runs, screenshots, PR triage, CI logs); see its
README if your client supports MCP.
