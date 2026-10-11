# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Connect this game checkout to the separately maintained MCP package."""
import os
from pathlib import Path
import subprocess

SERVER_COMMIT = "1f7acd3533d1cef0ab96f014b90cf65327426052"
SERVER_SOURCE = "git+https://github.com/jawaman14/skyrunner-mcp.git@" + SERVER_COMMIT

def main():
    env = dict(os.environ)
    # Always this checkout: an inherited value from another worktree would aim the tools at it.
    env["SKYRUNNER_ROOT"] = str(Path(__file__).resolve().parents[2])
    return subprocess.call(["uv", "tool", "run", "--from", SERVER_SOURCE, "skyrunner-mcp"], env=env)

if __name__ == "__main__":
    raise SystemExit(main())
