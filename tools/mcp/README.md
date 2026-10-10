# Skyrunner MCP connection

The server is maintained in [jawaman14/skyrunner-mcp](https://github.com/jawaman14/skyrunner-mcp).
This game checkout contains only a launcher and connection test. Implementation, Python tests and the Godot introspection adapter belong in the server repository.

Install uv, then enable the project's `.mcp.json` in Claude Code. The launcher sets `SKYRUNNER_ROOT` to this checkout and installs the server pinned at `faee6dc79fa6e0f9221a70ad4b637f6924956f17`. Set `SKYRUNNER_GODOT` to your Godot executable if needed. Codex can use the same launcher in its MCP configuration. Never commit tokens.

Follow [COLLABORATION.md](COLLABORATION.md) before editing. Server updates require independent Windows/Linux tests and a reviewed commit change in `launch.py`.
