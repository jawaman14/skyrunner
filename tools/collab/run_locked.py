#!/usr/bin/env python3
"""Run Godot work for THIS worktree under the machine-wide Godot lock, without the shell setup.

    python tools/collab/run_locked.py test <filter>        # bash tools/test.sh <filter> (import, status check, tests)
    python tools/collab/run_locked.py import               # godot --headless --import
    python tools/collab/run_locked.py status [--write]     # project_status.gd --check, or --write
    python tools/collab/run_locked.py -- <any command>     # e.g. -- bash tools/hygiene.sh
    add --no-wait before the command to fail fast when another job holds the lock.

The MCP's test tools only run in the primary checkout, so work in a linked worktree goes through the shell. The
server ships a lock for that (skyrunner-godot-lock), but using it by hand meant finding the server source, the Godot
executable and a bash that is not WSL's. This does that from the game's .mcp.json (or SKYRUNNER_MCP_SRC, SKYRUNNER_GODOT
and GIT_BASH), runs the command with this worktree as the working directory, and queues behind the other agent's jobs.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys


def canonical_root(worktree):
    """The clone every linked worktree belongs to: the parent of the Git common directory."""
    out = subprocess.run(["git", "-C", worktree, "rev-parse", "--path-format=absolute", "--git-common-dir"],
                         capture_output=True, text=True)
    if out.returncode != 0:
        raise SystemExit("not inside a Git worktree: " + out.stderr.strip())
    return os.path.dirname(out.stdout.strip())


def mcp_settings(root):
    """(server project path, godot path) from the canonical clone's .mcp.json, either may be ''."""
    path = os.path.join(root, ".mcp.json")
    if not os.path.exists(path):
        return "", ""
    with open(path, encoding="utf-8") as fh:
        servers = json.load(fh).get("mcpServers", {})
    entry = servers.get("skyrunner", {})
    args = entry.get("args", [])
    project = args[args.index("--project") + 1] if "--project" in args else ""
    return project, entry.get("env", {}).get("SKYRUNNER_GODOT", "")


def find_bash():
    """A real bash. On Windows, `bash` on PATH is often WSL's, which cannot see the Windows paths or environment."""
    if os.environ.get("GIT_BASH"):
        return os.environ["GIT_BASH"]
    if os.name != "nt":
        return shutil.which("bash") or "bash"
    git = shutil.which("git")
    if git:
        exec_path = subprocess.run(["git", "--exec-path"], capture_output=True, text=True).stdout.strip()
        # <Git>/mingw64/libexec/git-core -> <Git>/usr/bin/bash.exe
        cand = os.path.normpath(os.path.join(exec_path, "..", "..", "..", "usr", "bin", "bash.exe"))
        if os.path.exists(cand):
            return cand
    return shutil.which("bash") or "bash"


def plan(worktree, argv, wait=True, env=None, bash=None):
    """The (command, environment) that run `argv` under the lock; nothing is executed here."""
    env = dict(os.environ if env is None else env)
    project, godot = mcp_settings(canonical_root(worktree))
    server_src = env.get("SKYRUNNER_MCP_SRC") or (os.path.join(project, "src") if project else "")
    if not server_src or not os.path.isdir(server_src):
        raise SystemExit("cannot find the skyrunner-mcp source: set SKYRUNNER_MCP_SRC or fix --project in .mcp.json")
    godot = env.get("SKYRUNNER_GODOT") or godot
    if not godot:
        raise SystemExit("cannot find Godot: set SKYRUNNER_GODOT")
    env["GODOT"] = godot
    env["PYTHONPATH"] = server_src + (os.pathsep + env["PYTHONPATH"] if env.get("PYTHONPATH") else "")
    shell = bash or find_bash()
    cmd = [sys.executable, "-m", "skyrunner_mcp.locked"] + (["--wait"] if wait else []) + ["--"]
    if argv and argv[0] in ("test", "import", "status"):
        kind, rest = argv[0], argv[1:]
        if kind == "test":
            cmd += [shell, "tools/test.sh", *rest]
        elif kind == "import":
            cmd += [shell, "-c", '"$GODOT" --headless --import']
        else:
            flag = "--write" if "--write" in rest else "--check"
            cmd += [shell, "-c", '"$GODOT" --headless --script res://tools/project_status.gd -- ' + flag]
    else:
        cmd += argv
    return cmd, env


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--no-wait", action="store_true")
    ap.add_argument("--root", default=".", help="the worktree to run in (default: here)")
    ap.add_argument("command", nargs=argparse.REMAINDER)
    args = ap.parse_args(argv)
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command:
        ap.error("give test <filter>, import, status, or -- <command>")
    worktree = os.path.abspath(args.root)
    cmd, env = plan(worktree, command, wait=not args.no_wait)
    return subprocess.call(cmd, cwd=worktree, env=env)


if __name__ == "__main__":
    sys.exit(main())
