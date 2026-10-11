#!/usr/bin/env python3
"""Post Codex's board-note reviews to GitHub, verbatim and labelled as relayed, so nobody has to do it by hand.

    python tools/collab/relay_reviews.py once  [--dry-run]
    python tools/collab/relay_reviews.py watch [--interval 30]

An unattended Codex turn has the MCP but no GitHub network, and cannot call the approval-gated `github_pr_review`, so it gives its verdict as a
board note in one exact form:

    REVIEW #<pr>@<sha7 or longer> approve|changes|comment: <findings>

This reads those notes (from authors named codex..., addressed to claude or all; read-only on the board) and posts each as a GitHub review that
the merge queue understands (`tools/collab/post_review.py`'s marker), quoting the note word for word under a line saying it was relayed by Claude
and adding no finding of its own. Codex agreed to this on 11 October (board note 220).

What it refuses, and prints instead of posting: a note that does not match the form exactly; a PR that is not open; a sha that is not the PR's
CURRENT head (a stale review must be redone), and fewer than 7 hex characters; a PR that Codex itself wrote (an agent cannot review its own
work); and any note it has already handled. It posts only to the PR the note names, never merges or closes, and calls `gh` without a shell.
"""
import argparse
import json
import os
import re
import sqlite3
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, os.path.dirname(__file__))
import board_status  # noqa: E402
import post_review  # noqa: E402

FORM = re.compile(r"^\s*REVIEW\s+#(?P<pr>\d+)@(?P<sha>[0-9a-f]{7,40})\s+(?P<verdict>approve|changes|comment):\s*(?P<text>\S.*)$", re.S)
LIMIT = 3000


def parse(text):
    """The fields of a REVIEW note, or None if it is not in the exact form."""
    m = FORM.match(text or "")
    if not m or len(m.group("text")) > LIMIT:
        return None
    return {"pr": int(m.group("pr")), "sha": m.group("sha"), "verdict": m.group("verdict"), "text": m.group("text").strip()}


def decide(note_id, text, info):
    """(review dict, None) if this note may be relayed, else (None, the reason). `info` is the PR's headRefOid/headRefName/state."""
    fields = parse(text)
    if fields is None:
        return None, "not in the form `REVIEW #<pr>@<sha7> approve|changes|comment: <findings>`"
    if (info.get("state") or "OPEN").upper() != "OPEN":
        return None, "#%d is not open" % fields["pr"]
    head = info["headRefOid"]
    if not head.startswith(fields["sha"]):
        return None, "stale: the review is for %s but #%d is now at %s" % (fields["sha"][:8], fields["pr"], head[:8])
    why = post_review.check(info, "codex", fields["verdict"], head, fields["text"])
    if why:
        return None, why
    body = ("RELAYED by Claude from Codex's board note #%d (Codex's unattended turn has no GitHub network and cannot call github_pr_review; "
            "the note is quoted word for word). Claude has added no finding of its own to this review.\n\n> %s" % (note_id, fields["text"].replace("\n", "\n> ")))
    return {"pr": fields["pr"], "head": head, "verdict": fields["verdict"], "body": body}, None


def new_notes(db, after):
    return db.execute("SELECT id, author, text FROM notes WHERE id>? AND author LIKE 'codex%' AND recipient IN ('claude','all') ORDER BY id", (after,)).fetchall()


def load(path):
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return {}


def run_once(db, state_path, dry_run=False, run=subprocess.run, out=print):
    state = load(state_path)
    after = state.get("after")
    if after is None:  # first run: start from now, never relay history
        after = db.execute("SELECT COALESCE(MAX(id), 0) FROM notes").fetchone()[0]
        state["after"] = after
    done = []
    for note_id, author, text in new_notes(db, after):
        state["after"] = note_id
        if not (text or "").lstrip().startswith("REVIEW"):
            continue
        fields = parse(text)
        if fields is None:
            out("relay: note %d from %s is not in the REVIEW form; not relayed" % (note_id, author))
            continue
        try:
            info = json.loads(post_review.gh(["pr", "view", str(fields["pr"]), "--json", "headRefOid,headRefName,state"], run))
        except SystemExit as e:
            out("relay: note %d: could not read #%d (%s)" % (note_id, fields["pr"], e))
            continue
        review, why = decide(note_id, text, info)
        if why:
            out("relay: note %d not relayed: %s" % (note_id, why))
            continue
        marker = post_review.marker("codex", review["verdict"], review["head"])
        if dry_run:
            out("relay (dry run): would post %s on #%d at %s" % (review["verdict"], review["pr"], review["head"][:8]))
            continue
        url = post_review.gh(["api", "repos/{owner}/{repo}/pulls/%d/reviews" % review["pr"], "-f", "commit_id=" + review["head"], "-f", "event=COMMENT",
                              "-f", "body=" + marker + "\n" + review["body"] + "\n", "--jq", ".html_url"], run).strip()
        out("relay: note %d -> %s" % (note_id, url))
        done.append(note_id)
    if not dry_run:
        with open(state_path, "w", encoding="utf-8") as fh:
            json.dump(state, fh)
    return done


def main(argv=None, run=subprocess.run):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("mode", choices=["once", "watch"])
    ap.add_argument("--db", default="")
    ap.add_argument("--root", default=".")
    ap.add_argument("--state", default="")
    ap.add_argument("--interval", type=float, default=30.0)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args(argv)
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
            run_once(db, state, args.dry_run, run)
        finally:
            db.close()
        if args.mode == "once":
            return 0
        time.sleep(args.interval)


if __name__ == "__main__":
    sys.exit(main())
