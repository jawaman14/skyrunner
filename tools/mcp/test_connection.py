"""Exercise the pinned external package against this game checkout."""
import asyncio
import json
import os
from pathlib import Path
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def main():
    root = Path(__file__).resolve().parents[2]
    params = StdioServerParameters(command="uv", args=["run", "--quiet", "--script", str(root / "tools/mcp/launch.py")], env=dict(os.environ))
    async with stdio_client(params) as (reader, writer):
        async with ClientSession(reader, writer) as client:
            await client.initialize()
            tools = await client.list_tools()
            assert len(tools.tools) == 30, len(tools.tools)
            result = await client.call_tool("skyrunner_collaboration_start", {})
            assert not result.is_error, result.content
            payload = json.loads(result.content[0].text)
            assert Path(payload["root"]).resolve() == root
            assert payload["server_repository"] == "https://github.com/jawaman14/skyrunner-mcp"
            print("External MCP: 30 tools, correct game root and collaboration startup verified")

asyncio.run(main())
