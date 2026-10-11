#!/usr/bin/env python3
"""Merge the base branch into this one and resolve the files every Skyrunner PR collides on.

    python tools/collab/sync_shared.py [--base origin/main] [--commit] [--message TEXT] [--no-fetch]

Every open PR edits the same three shared files, and each merge of main used to be a hand-resolved conflict:
HANDOFF.md (a new entry at the top of the Log), docs/PROJECT_STATUS.md (the declared-test count) and
tests/test_lanes.json (a new test file in a lane). This merges the base with --no-commit, then

  * keeps both sides of a conflict inside HANDOFF's Log (never in the baton above it, which is overwritten),
  * recounts the declared-test inventory the way tools/project_status.gd does,
  * takes the union of both sides in a test lane, sorted, and checks every lane still parses without duplicates,
  * refuses, leaving the merge in progress, if any other file conflicts or any conflict marker is left.

It never pushes. With --commit it also commits the merge. Run the focused tests afterwards (through the MCP, or
tools/collab/run_locked.py), and run project_status.gd --check before pushing.
"""
import argparse
import glob
import json
import os
import re
import subprocess
import sys

BLOCK = re.compile(r"<<<<<<< [^\r\n]*\r?\n(.*?)=======\r?\n(.*?)>>>>>>> [^\r\n]*\r?\n", re.S)
MARKER = re.compile(r"^(<{7}|={7}|>{7})( |$)", re.M)
INVENTORY = re.compile(r"\| Declared automated tests \| \d+ methods in \d+ test files \|")
INVENTORY_LINE = re.compile(r"^\| Declared automated tests \| \d+ methods in \d+ test files \|.*$")
HANDLED = ("HANDOFF.md", "docs/PROJECT_STATUS.md", "tests/test_lanes.json")


class Unresolved(Exception):
    """A conflict this tool will not guess at."""


def _newline(text):
    return "\r\n" if "\r\n" in text else "\n"


def keep_both_in_log(text):
    """HANDOFF.md: both sides of a conflict below '## Log' (theirs first, then ours); a conflict above it is the
    baton, which is overwritten, not appended, so it is left for a person."""
    nl = _newline(text)
    log_at = text.find("## Log")

    def sub(m):
        if log_at < 0 or m.start() < log_at:
            raise Unresolved("a conflict in HANDOFF.md above the Log (the baton): merge it by hand")
        ours, theirs = m.group(1), m.group(2)
        return theirs.rstrip("\r\n") + nl + nl + ours

    return BLOCK.sub(sub, text)


def resolve_status(text):
    """docs/PROJECT_STATUS.md: only a conflict made of nothing but the inventory line on both sides; the count is
    recomputed afterwards."""
    def sub(m):
        for side in (m.group(1), m.group(2)):
            for line in side.splitlines():
                if line.strip() and not INVENTORY_LINE.match(line.strip()):
                    raise Unresolved("a conflict in docs/PROJECT_STATUS.md beyond the test count: merge it by hand")
        return m.group(2)

    return BLOCK.sub(sub, text)


def union_lanes(text):
    """tests/test_lanes.json: the union of both sides of a conflict, sorted, one test file per line."""
    nl = _newline(text)

    def sub(m):
        names = set()
        indent = "    "
        for side in (m.group(1), m.group(2)):
            for line in side.splitlines():
                s = line.strip().rstrip(",")
                if not s:
                    continue
                if not re.fullmatch(r'"test_[A-Za-z0-9_]+\.gd"', s):
                    raise Unresolved("a conflict in tests/test_lanes.json that is not just test file names")
                indent = line[: len(line) - len(line.lstrip())] or indent
                names.add(s)
        return "".join(indent + n + "," + nl for n in sorted(names))

    out = BLOCK.sub(sub, text)
    # a union at the end of an array leaves a comma before the closing bracket
    return re.sub(r",(\s*\])", r"\1", out)


def count_tests(root):
    """(methods, files) as tools/project_status.gd counts them: unique test_ method names per tests/test_*.gd."""
    files = [f for f in glob.glob(os.path.join(root, "tests", "test_*.gd")) if os.path.basename(f) != "test_case.gd"]
    total = 0
    for f in files:
        with open(f, encoding="utf-8") as fh:
            total += len(set(re.findall(r"^func (test_\w+)", fh.read(), re.M)))
    return total, len(files)


def set_inventory(text, methods, files):
    new = "| Declared automated tests | %d methods in %d test files |" % (methods, files)
    return INVENTORY.sub(new, text)


def check_lanes(text):
    """Raise ValueError unless the lanes parse and no test file is in two lanes."""
    lanes = json.loads(text)
    seen = {}
    for lane, names in lanes.items():
        for n in names:
            if n in seen:
                raise ValueError("%s is in both the %s and %s lanes" % (n, seen[n], lane))
            seen[n] = lane


def _read(path):
    with open(path, encoding="utf-8", newline="") as fh:
        return fh.read()


def _write(path, text):
    with open(path, "w", encoding="utf-8", newline="") as fh:
        fh.write(text)


def resolve_tree(root):
    """Resolve the handled files in a working tree that is mid-merge. Returns the files it changed."""
    changed = []
    for rel, fn in (("HANDOFF.md", keep_both_in_log), ("docs/PROJECT_STATUS.md", resolve_status),
                    ("tests/test_lanes.json", union_lanes)):
        path = os.path.join(root, rel)
        if not os.path.exists(path):
            continue
        text = _read(path)
        out = fn(text)
        if out != text:
            _write(path, out)
            changed.append(rel)
    status = os.path.join(root, "docs", "PROJECT_STATUS.md")
    if os.path.exists(status):
        methods, files = count_tests(root)
        text = _read(status)
        out = set_inventory(text, methods, files)
        if out != text:
            _write(status, out)
            if "docs/PROJECT_STATUS.md" not in changed:
                changed.append("docs/PROJECT_STATUS.md")
    lanes = os.path.join(root, "tests", "test_lanes.json")
    if os.path.exists(lanes):
        check_lanes(_read(lanes))
    for rel in HANDLED:
        path = os.path.join(root, rel)
        if os.path.exists(path) and MARKER.search(_read(path)):
            raise Unresolved("conflict markers are still in " + rel)
    return changed


def _git(root, *args, check=True):
    p = subprocess.run(["git", "-C", root, *args], capture_output=True, text=True)
    if check and p.returncode != 0:
        raise SystemExit("git %s failed: %s" % (" ".join(args), (p.stderr or p.stdout).strip()))
    return p


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", default=".", help="the worktree to merge into (default: here)")
    ap.add_argument("--base", default="origin/main")
    ap.add_argument("--no-fetch", action="store_true")
    ap.add_argument("--commit", action="store_true", help="commit the merge when it resolves cleanly")
    ap.add_argument("--message", default="", help="merge commit message (default: 'Merge <base> into <branch>')")
    args = ap.parse_args(argv)
    root = os.path.abspath(args.root)
    if not args.no_fetch:
        remote = args.base.split("/", 1)[0] if "/" in args.base else ""
        if remote:
            _git(root, "fetch", "-q", remote)
    if _git(root, "status", "--porcelain", "--untracked-files=no").stdout.strip():
        raise SystemExit("the working tree has uncommitted changes; commit or stash them first")
    branch = _git(root, "rev-parse", "--abbrev-ref", "HEAD").stdout.strip()
    merge = _git(root, "merge", "--no-ff", "--no-commit", args.base, check=False)
    if "Already up to date" in merge.stdout:
        print("already up to date with " + args.base)
        return 0
    conflicted = [f for f in _git(root, "diff", "--name-only", "--diff-filter=U").stdout.split() if f]
    unhandled = [f for f in conflicted if f not in HANDLED]
    if unhandled:
        print("NOT RESOLVED, merge left in progress. These conflict beyond the shared files:", file=sys.stderr)
        for f in unhandled:
            print("  " + f, file=sys.stderr)
        return 2
    try:
        changed = resolve_tree(root)
    except (Unresolved, ValueError) as e:
        print("NOT RESOLVED, merge left in progress: %s" % e, file=sys.stderr)
        return 3
    methods, files = count_tests(root)
    _git(root, "add", *[f for f in HANDLED if os.path.exists(os.path.join(root, f))])
    print("resolved %s; declared tests %d methods in %d files" % (", ".join(changed) or "nothing", methods, files))
    if args.commit:
        message = args.message or "Merge %s into %s\n\nShared files resolved by tools/collab/sync_shared.py." % (args.base, branch)
        _git(root, "commit", "-q", "-m", message)
        print("committed " + _git(root, "rev-parse", "--short", "HEAD").stdout.strip())
    else:
        print("staged; commit it, rerun the focused tests, check project_status.gd --check, then push")
    return 0


if __name__ == "__main__":
    sys.exit(main())
