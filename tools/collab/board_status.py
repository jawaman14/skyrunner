#!/usr/bin/env python3
"""Who has not answered what: a compact, read-only view of the shared board.

    python tools/collab/board_status.py [--db PATH] [--quiet-min 20] [--json]

Prints, for each agent, how long ago it last posted, how many notes addressed to it (or to everyone) have arrived since it
last spoke, how old the oldest of those is, and its active claims. A line is marked STALE when an agent has unanswered
notes and has been silent longer than --quiet-min. It reads the board file directly and read-only, so it costs about ten
lines of output instead of a full board dump, and it never writes, acknowledges or wakes anything.

The shared board is the SQLite file the MCP server keeps in the clone's Git directory (SKYRUNNER_BOARD overrides it).
"""
import argparse
import json
import os
import sqlite3
import subprocess
import sys
import time

AGENTS = ("claude", "codex")


def board_path(root=".", env=None):
    env = os.environ if env is None else env
    if env.get("SKYRUNNER_BOARD"):
        return env["SKYRUNNER_BOARD"]
    out = subprocess.run(["git", "-C", root, "rev-parse", "--path-format=absolute", "--git-common-dir"],
                         capture_output=True, text=True)
    if out.returncode != 0:
        raise SystemExit("not inside the game clone: " + out.stderr.strip())
    return os.path.join(out.stdout.strip(), "skyrunner-mcp", "collaboration.sqlite3")


def summarize(db, now, quiet_min=20.0):
    """{agent: {...}} from an open board connection; times in minutes."""
    out = {}
    for agent in AGENTS:
        last = db.execute("SELECT id, created FROM notes WHERE author LIKE ? ORDER BY id DESC LIMIT 1", (agent + "%",)).fetchone()
        last_id, last_t = (last[0], last[1]) if last else (0, None)
        pending = db.execute("SELECT id, author, created FROM notes WHERE id>? AND recipient IN ('all', ?) "
                             "AND author NOT LIKE ? ORDER BY id", (last_id, agent, agent + "%")).fetchall()
        claims = db.execute("SELECT owner, title, expires FROM tasks WHERE status='active' AND expires>? AND owner LIKE ? "
                            "ORDER BY updated DESC", (now, agent + "%")).fetchall()
        # a claim by "claude-<session>" belongs to claude; a second Claude session is still Claude
        silent = None if last_t is None else (now - last_t) / 60.0
        oldest = None if not pending else (now - pending[0][2]) / 60.0
        out[agent] = {
            "last_post_min_ago": None if silent is None else round(silent, 1),
            "unanswered": len(pending),
            "unanswered_ids": [p[0] for p in pending][-8:],
            "oldest_unanswered_min": None if oldest is None else round(oldest, 1),
            "active_claims": [{"owner": c[0], "title": c[1][:70], "expires_in_min": round((c[2] - now) / 60.0)} for c in claims],
            "stale": bool(pending) and (silent is None or silent > quiet_min) and oldest is not None and oldest > quiet_min,
        }
    return out


def render(summary):
    lines = []
    for agent, s in summary.items():
        said = "never posted" if s["last_post_min_ago"] is None else "last post %.0f min ago" % s["last_post_min_ago"]
        if s["unanswered"]:
            wait = "%d unanswered (oldest %.0f min%s)" % (s["unanswered"], s["oldest_unanswered_min"],
                                                          ", ids " + ",".join(map(str, s["unanswered_ids"])))
        else:
            wait = "nothing waiting"
        lines.append("%-6s %s; %s%s" % (agent, said, wait, "  <-- STALE" if s["stale"] else ""))
        for c in s["active_claims"]:
            lines.append("         claim: %s (%s, %d min left)" % (c["title"], c["owner"], c["expires_in_min"]))
    return "\n".join(lines)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--db", default="", help="board file (default: the clone's shared board)")
    ap.add_argument("--root", default=".")
    ap.add_argument("--quiet-min", type=float, default=20.0)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)
    path = args.db or board_path(args.root)
    if not os.path.exists(path):
        raise SystemExit("no board at " + path)
    db = sqlite3.connect("file:%s?mode=ro" % path.replace("\\", "/"), uri=True)
    try:
        summary = summarize(db, time.time(), args.quiet_min)
    finally:
        db.close()
    print(json.dumps(summary) if args.json else render(summary))
    return 0


if __name__ == "__main__":
    sys.exit(main())
