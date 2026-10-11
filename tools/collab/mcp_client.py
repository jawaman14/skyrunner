#!/usr/bin/env python3
"""Call the skyrunner MCP server's tools from a script, exactly as an agent does, so a background program obeys the same rule: GitHub reads
and writes go through the MCP tools (the owner's rule, 11 October 2026), never `gh`.

    from mcp_client import McpClient
    with McpClient(root) as mcp:
        states = json.loads(mcp.call("github_pr_states"))
        mcp.call("github_pr_review", number=331, reviewer="codex-relayed-by-claude", verdict="approve", body="...", expected_head_sha=head)

The server definition is read from the game's `.mcp.json` (the `skyrunner` entry), so a script starts the very server the agents use, with the
same guards. The `mcp` package lives in the server's environment, not in the system Python: a script that imports this re-runs itself under
`uv run --project <the server checkout>` when `mcp` is missing (`ensure_mcp()`).

Each session starts a server process (a couple of seconds), so keep one client open for a whole poll.
"""
import asyncio
import json
import os
import sys
import threading


class McpError(Exception):
    """A tool refused or failed; the text is the server's own message."""


def load_server(root):
    """(command, args, env) of the `skyrunner` server from root/.mcp.json."""
    with open(os.path.join(root, ".mcp.json"), encoding="utf-8") as fh:
        entry = json.load(fh)["mcpServers"]["skyrunner"]
    return entry["command"], list(entry.get("args", [])), dict(entry.get("env", {}))


def server_project(args):
    """The server checkout in a `uv run --project <dir> ...` argument list, or ''."""
    for i, a in enumerate(args):
        if a == "--project" and i + 1 < len(args):
            return args[i + 1]
    return ""


def ensure_mcp(root="."):
    """Re-run the calling script under the server's uv environment if the `mcp` package is not importable here."""
    try:
        import mcp  # noqa: F401
        return
    except ImportError:
        pass
    command, args, _ = load_server(root)
    project = server_project(args)
    if not project:
        raise SystemExit("the `mcp` package is missing and .mcp.json names no --project to borrow it from")
    os.execv(command, [command, "run", "--quiet", "--project", project, "python"] + sys.argv)


class McpClient:
    """One stdio session with the server, kept open for several calls. Use as a context manager.

    The session is opened and closed by ONE task on a background event loop (the MCP client library requires that), and `call` hands each
    request to that loop, so the caller can be ordinary synchronous code."""

    def __init__(self, root=".", timeout=120.0, start_timeout=60.0):
        self.root, self.timeout, self.start_timeout = root, timeout, start_timeout
        self._loop = None
        self._thread = None
        self._session = None
        self._stop = None
        self._ready = threading.Event()
        self._error = None

    def __enter__(self):
        self._thread = threading.Thread(target=self._run, name="mcp-client", daemon=True)
        self._thread.start()
        if not self._ready.wait(self.start_timeout) or self._error:
            self._shutdown()
            raise McpError("could not start the skyrunner MCP server: %s" % (self._error or "timed out"))
        return self

    def __exit__(self, *exc):
        self._shutdown()
        return False

    def _shutdown(self):
        if self._loop and self._stop:
            self._loop.call_soon_threadsafe(self._stop.set)
        if self._thread:
            self._thread.join(15.0)

    def _run(self):
        self._loop = asyncio.new_event_loop()
        try:
            self._loop.run_until_complete(self._own_the_session())
        except BaseException as e:  # reported to the caller, never swallowed silently
            self._error = e
            self._ready.set()
        finally:
            self._loop.close()

    async def _own_the_session(self):
        from mcp import ClientSession, StdioServerParameters
        from mcp.client.stdio import stdio_client
        command, args, env = load_server(self.root)
        params = StdioServerParameters(command=command, args=args, env={**os.environ, **env})
        self._stop = asyncio.Event()
        async with stdio_client(params) as (read, write):
            async with ClientSession(read, write) as session:
                await session.initialize()
                self._session = session
                self._ready.set()
                await self._stop.wait()

    def call(self, tool, **arguments):
        """The text a tool returns. Raises McpError with the server's message if the tool refuses or the server is gone."""
        async def go():
            result = await self._session.call_tool(tool, arguments)
            text = "".join(getattr(c, "text", "") for c in result.content)
            if getattr(result, "isError", False):
                raise McpError(text)
            return text
        try:
            return asyncio.run_coroutine_threadsafe(go(), self._loop).result(self.timeout)
        except McpError:
            raise
        except Exception as e:
            raise McpError("%s failed: %s" % (tool, e)) from e
