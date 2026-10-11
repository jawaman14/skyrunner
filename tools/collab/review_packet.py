#!/usr/bin/env python3
"""A bounded review packet for one pull request at its exact head: what changed, what covers it, CI, reviews, open threads.

    python tools/collab/review_packet.py 322 [--diff 150] [--json]

One call instead of five (`gh pr view`, the files, the checks, the review comments, the diff). Read-only: it only calls `gh`.
The packet is pinned to the head SHA it was built at, and every review is marked CURRENT or STALE (made on an older head), so a
review of an earlier push is never mistaken for a review of this one. It lists the tests that sit beside each changed source file
by name (tests/test_<name>.gd, a heuristic, not a dependency analysis) and whether the PR already changes any test.

--diff N adds at most N diff lines (default 0: the file list and stats are usually enough to decide what to read).
"""
import argparse
import json
import os
import subprocess
import sys

VIEW_FIELDS = "number,title,author,isDraft,headRefOid,baseRefName,mergeable,mergeStateStatus,files,statusCheckRollup,reviews,reviewDecision"
NL = chr(10)
FAIL = ("FAILURE", "CANCELLED", "TIMED_OUT", "ACTION_REQUIRED", "STARTUP_FAILURE")


def gh(args, root, run=subprocess.run):
    out = run(["gh"] + args, cwd=root, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=60)
    if out.returncode != 0:
        raise SystemExit("gh %s failed: %s" % (" ".join(args[:2]), " ".join((out.stderr or "").split())[:200]))
    return out.stdout


def parse_pages(text):
    """`gh api --paginate` prints one JSON array per page back to back; join them into one list."""
    items, decoder, i = [], json.JSONDecoder(), 0
    text = text or ""
    while True:
        while i < len(text) and text[i].isspace():
            i += 1
        if i >= len(text):
            return items
        page, i = decoder.raw_decode(text, i)
        items += page if isinstance(page, list) else [page]


def covering_tests(path, root, in_pr=None, deleted=()):
    """Test files named after a changed source file: tests/test_<stem>.gd. A heuristic, said so in the packet. It exists if the
    PR's own file set adds or changes it (the reviewer's checkout may not have the head) or, failing that, if the local checkout
    has it and the PR does not delete it."""
    stem = os.path.splitext(os.path.basename(path))[0]
    if path.startswith("tests/") or not path.endswith(".gd"):
        return []
    cand = "tests/test_%s.gd" % stem
    if cand in deleted:
        return []
    if in_pr is not None and cand in in_pr:
        return [cand]
    return [cand] if os.path.exists(os.path.join(root, cand)) else []


def check_state(c):
    """'ok', 'fail' or 'run' for one statusCheckRollup entry. A CheckRun has status and conclusion; a legacy StatusContext has
    only `state` (SUCCESS, FAILURE, ERROR, PENDING, EXPECTED) and a `context` name."""
    state = (c.get("state") or "").upper()
    if state and not c.get("conclusion") and not c.get("status"):
        return "ok" if state == "SUCCESS" else ("fail" if state in ("FAILURE", "ERROR") else "run")
    conclusion = (c.get("conclusion") or "").upper()
    if conclusion in FAIL:
        return "fail"
    if (c.get("status") or "").upper() not in ("COMPLETED", "") or not conclusion:
        return "run"
    return "ok"


def is_test_path(path):
    """tests/, test_*.py, *_test.py, test_*.gd: this repository's test files, wherever they sit (not .uid or fixtures)."""
    base = os.path.basename(path)
    named = base.startswith("test_") and base.endswith((".py", ".gd"))
    return (path.startswith("tests/") or named or base.endswith("_test.py")) and not path.endswith((".uid", ".json"))


def check_summary(rollup):
    rollup = rollup or []

    def name(c):
        return c.get("name") or c.get("context") or "?"
    return {"passed": len([c for c in rollup if check_state(c) == "ok"]),
            "failed": sorted({name(c) for c in rollup if check_state(c) == "fail"}),
            "running": sorted({name(c) for c in rollup if check_state(c) == "run"}), "total": len(rollup)}


def build(view, comments, root, diff_text=""):
    head = view["headRefOid"]
    files = view.get("files") or []
    paths = {f["path"] for f in files}
    deleted = {f["path"] for f in files if (f.get("changeType") or "").upper() == "DELETED"}
    tests, changed_tests = {}, [f["path"] for f in files if is_test_path(f["path"])]
    for f in files:
        found = covering_tests(f["path"], root, paths - deleted, deleted)
        if found:
            tests[f["path"]] = found
    reviews = []
    for r in view.get("reviews") or []:
        oid = (r.get("commit") or {}).get("oid", "")
        reviews.append({"by": (r.get("author") or {}).get("login", "?"), "state": r.get("state", ""),
                        "current": oid == head, "commit": oid[:7], "body": " ".join(str(r.get("body") or "").split())[:200]})
    # inline comments: an unanswered thread root is a comment with no reply to it
    replied = {c.get("in_reply_to_id") for c in comments if c.get("in_reply_to_id")}
    open_threads = [{"path": c.get("path"), "line": c.get("line") or c.get("original_line"), "by": (c.get("user") or {}).get("login", "?"),
                     "text": " ".join(str(c.get("body", "")).split())[:160]}
                    for c in comments if not c.get("in_reply_to_id") and c.get("id") not in replied]
    return {"number": view["number"], "title": view["title"], "author": (view.get("author") or {}).get("login", "?"),
            "draft": bool(view.get("isDraft")), "head": head, "base": view.get("baseRefName"), "mergeable": view.get("mergeable"),
            "merge_state": view.get("mergeStateStatus"), "files": [{"path": f["path"], "add": f.get("additions", 0), "del": f.get("deletions", 0)} for f in files],
            "tests_by_name": tests, "pr_changes_tests": changed_tests, "ci": check_summary(view.get("statusCheckRollup")),
            "reviews": reviews, "open_threads": open_threads, "diff": diff_text}


def cap_diff(diff_text, lines):
    """At most `lines` diff lines, for both the text and the JSON output."""
    return NL.join(diff_text.splitlines()[:lines]) if lines else ""


def render(p, diff_lines=0):
    ci = p["ci"]
    out = ["PR #%d %s%s | %s -> %s | head %s | %s/%s" % (p["number"], "[draft] " if p["draft"] else "", p["title"], p["author"], p["base"],
                                                         p["head"][:7], p["mergeable"], p["merge_state"]),
           "CI on this head: %d passed%s%s of %d" % (ci["passed"], ", FAILED: " + ", ".join(ci["failed"]) if ci["failed"] else "",
                                                        ", running: " + ", ".join(ci["running"]) if ci["running"] else "", ci["total"])]
    if not p["reviews"]:
        out.append("Reviews: none")
    for r in p["reviews"]:
        out.append("Review by %s: %s at %s (%s)%s" % (r["by"], r["state"], r["commit"], "CURRENT" if r["current"] else "STALE: older head",
                                                    ": " + r["body"] if r.get("body") and r["current"] else ""))
    out.append("Open review threads: %d" % len(p["open_threads"]))
    for t in p["open_threads"][:6]:
        out.append("  %s:%s %s: %s" % (t["path"], t["line"], t["by"], t["text"]))
    total_add = sum(f["add"] for f in p["files"])
    total_del = sum(f["del"] for f in p["files"])
    out.append("Files (%d, +%d/-%d):" % (len(p["files"]), total_add, total_del))
    for f in p["files"][:25]:
        out.append("  +%d/-%d %s%s" % (f["add"], f["del"], f["path"], "   tests by name: " + ", ".join(p["tests_by_name"][f["path"]]) if f["path"] in p["tests_by_name"] else ""))
    if len(p["files"]) > 25:
        out.append("  ... %d more files" % (len(p["files"]) - 25))
    out.append("The PR changes %d test file(s)%s. (Test-by-name is a heuristic, not a dependency analysis.)" % (
        len(p["pr_changes_tests"]), ": " + ", ".join(p["pr_changes_tests"][:6]) if p["pr_changes_tests"] else ""))
    if diff_lines and p["diff"]:
        lines = p["diff"].splitlines()
        out.append("Diff (first %d of %d lines):" % (min(diff_lines, len(lines)), len(lines)))
        out += lines[:diff_lines]
    return "\n".join(out)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("number", type=int)
    ap.add_argument("--root", default=".")
    ap.add_argument("--diff", type=int, default=0)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass
    for attempt in range(2):  # the calls are not one snapshot: read the head again and rebuild once if it moved
        view = json.loads(gh(["pr", "view", str(args.number), "--json", VIEW_FIELDS], args.root))
        comments = parse_pages(gh(["api", "repos/{owner}/{repo}/pulls/%d/comments" % args.number, "--paginate"], args.root))
        diff = gh(["pr", "diff", str(args.number)], args.root) if args.diff else ""
        now = json.loads(gh(["pr", "view", str(args.number), "--json", "headRefOid"], args.root))["headRefOid"]
        if now == view["headRefOid"]:
            break
    moved = now != view["headRefOid"]
    packet = build(view, comments, args.root, cap_diff(diff, args.diff))
    packet["head_moved_while_reading"] = moved
    text = json.dumps(packet) if args.json else render(packet, args.diff)
    print(text + (NL + "WARNING: the head moved while this was read (now %s); run it again." % now[:7] if moved and not args.json else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
