#!/usr/bin/env python3
"""Post Codex's board-note reviews to GitHub, verbatim and labelled as relayed, through the skyrunner MCP tools.

    uv run --project <server checkout> python tools/collab/relay_reviews.py once  [--dry-run]
    uv run --project <server checkout> python tools/collab/relay_reviews.py watch [--interval 30]

(or just `python tools/collab/relay_reviews.py ...`: it re-runs itself under the server's uv environment when the `mcp` package is missing.)

An unattended Codex turn has the MCP board but no GitHub network, and cannot call the approval-gated `github_pr_review`, so it gives its verdict
as a board note in one exact form:

    REVIEW #<pr>@<sha7 or longer> approve|changes|comment: <findings>

This reads those notes (authors named codex..., addressed to claude or all; the board is read-only here) and posts each as a GitHub review by
calling the MCP tool `github_pr_review` itself, so the server's own guards apply (pinned to the head, never by the PR's author agent) and the merge
queue reads the result. The body quotes the note word for word under a line saying Claude relayed it and added no finding of its own. Codex agreed
to this on 11 October (board note 220). GitHub is reached only through the MCP, as the owner's rule requires.

What it refuses, and prints instead of posting: a note that does not match the form exactly; a PR that is not open; a sha that is not the PR's
CURRENT head (a stale review must be redone) or has fewer than 7 hex characters; a PR that Codex itself wrote; and any note already handled. It
posts only to the PR the note names and never merges or closes.
"""
import argparse
import json
import os
import re
import sqlite3
import sys
import tempfile
import time

sys.path.insert(0, os.path.dirname(__file__))
import board_status  # noqa: E402
from mcp_client import McpClient, McpError, ensure_mcp  # noqa: E402

FORM = re.compile(r"^\s*REVIEW\s+#(?P<pr>\d+)@(?P<sha>[0-9a-f]{7,40})\s+(?P<verdict>approve|changes|comment):\s*(?P<text>\S.*)$", re.S)
LIMIT = 3000
RELAY_REVIEWER = "codex-relayed-by-claude"


def parse(text):
    """The fields of a REVIEW note, or None if it is not in the exact form."""
    m = FORM.match(text or "")
    if not m or len(m.group("text")) > LIMIT:
        return None
    return {"pr": int(m.group("pr")), "sha": m.group("sha"), "verdict": m.group("verdict"), "text": m.group("text").strip()}


def author_agent(branch):
    m = re.match(r"(claude|codex)(?![a-z])", (branch or "").lower())
    return m.group(1) if m else ""


def decide(note_id, text, states):
    """(review dict, None) if this note may be relayed, else (None, the reason). `states` is the parsed `github_pr_states` answer."""
    fields = parse(text)
    if fields is None:
        return None, "not in the form `REVIEW #<pr>@<sha7> approve|changes|comment: <findings>`"
    pr = next((p for p in states.get("open", []) if p["number"] == fields["pr"]), None)
    if pr is None:
        return None, "#%d is not open" % fields["pr"]
    if not pr["head"].startswith(fields["sha"]):
        return None, "stale: the review is for %s but #%d is now at %s" % (fields["sha"][:8], fields["pr"], pr["head"][:8])
    if author_agent(pr["branch"]) == "codex":
        return None, "codex wrote #%d (branch %s): an agent cannot review its own work" % (fields["pr"], pr["branch"])
    body = ("RELAYED by Claude from Codex's board note #%d (Codex's unattended turn has no GitHub network and cannot call github_pr_review; "
            "the note is quoted word for word). Claude has added no finding of its own to this review.\n\n> %s" % (note_id, fields["text"].replace("\n", "\n> ")))
    return {"pr": fields["pr"], "head": pr["head"], "verdict": fields["verdict"], "body": body}, None


def new_notes(db, after):
    return db.execute("SELECT id, author, text FROM notes WHERE id>? AND author LIKE 'codex%' AND recipient IN ('claude','all') ORDER BY id", (after,)).fetchall()


def load(path):
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return {}


def run_once(db, state_path, mcp, dry_run=False, out=print):
    """Relay the new REVIEW notes. `mcp` has `.call(tool, **arguments)` (an McpClient, or a fake in tests)."""
    state = load(state_path)
    after = state.get("after")
    if after is None:  # first run: start from now, never relay history
        after = db.execute("SELECT COALESCE(MAX(id), 0) FROM notes").fetchone()[0]
        state["after"] = after
    done, states = [], None
    for note_id, author, text in new_notes(db, after):
        state["after"] = note_id
        if not (text or "").lstrip().startswith("REVIEW"):
            continue
        if parse(text) is None:
            out("relay: note %d from %s is not in the REVIEW form; not relayed" % (note_id, author))
            continue
        if states is None:
            states = json.loads(mcp.call("github_pr_states"))
        review, why = decide(note_id, text, states)
        if why:
            out("relay: note %d not relayed: %s" % (note_id, why))
            continue
        if dry_run:
            out("relay (dry run): would post %s on #%d at %s" % (review["verdict"], review["pr"], review["head"][:8]))
            continue
        try:
            result = mcp.call("github_pr_review", number=review["pr"], reviewer=RELAY_REVIEWER, verdict=review["verdict"], body=review["body"],
                              expected_head_sha=review["head"])
        except McpError as e:
            out("relay: note %d refused by the server: %s" % (note_id, str(e)[:200]))
            continue
        out("relay: note %d -> %s" % (note_id, result.strip()[:200]))
        done.append(note_id)
    if not dry_run:
        with open(state_path, "w", encoding="utf-8") as fh:
            json.dump(state, fh)
    return done


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("mode", choices=["once", "watch"])
    ap.add_argument("--db", default="")
    ap.add_argument("--root", default=".")
    ap.add_argument("--state", default="")
    ap.add_argument("--interval", type=float, default=30.0)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args(argv)
    ensure_mcp(args.root)
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass
    path = args.db or board_status.board_path(args.root)
    state = args.state or os.path.join(os.environ.get("TEMP") or tempfile.gettempdir(), "skyrunner-relay-reviews.json")
    while True:
        db = sqlite3.connect("file:%s?mode=ro" % path.replace("\\", "/"), uri=True)
        try:
            if load(state).get("after") is None:  # first run: start from now, with no session
                with open(state, "w", encoding="utf-8") as fh:
                    json.dump({"after": db.execute("SELECT COALESCE(MAX(id), 0) FROM notes").fetchone()[0]}, fh)
            if any((text or "").lstrip().startswith("REVIEW") for _, _, text in new_notes(db, load(state)["after"])):
                with McpClient(args.root) as mcp:  # a session only when there is something to relay: starting the server costs seconds
                    run_once(db, state, mcp, args.dry_run)
            else:
                st = load(state)
                rows = new_notes(db, st["after"])
                if rows:
                    st["after"] = rows[-1][0]
                    with open(state, "w", encoding="utf-8") as fh:
                        json.dump(st, fh)
        except McpError as e:
            print("relay: " + str(e), file=sys.stderr, flush=True)
        finally:
            db.close()
        if args.mode == "once":
            return 0
        time.sleep(args.interval)


if __name__ == "__main__":
    sys.exit(main())
