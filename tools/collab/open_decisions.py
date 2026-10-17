"""SessionStart hook: put the owner's open decisions in front of every new Claude session (owner, 18 Oct 2026).

Reads docs/DECISIONS.md from this checkout first (a decision is recorded on a branch before it reaches main), else from
origin/main, else from the branch that introduced it (claude/roadmap-redo, PR #397), and prints every row that is not done or superseded, with the ledger rule. Read-only: it only
runs `git show` on refs already fetched, so it is fast and never touches the network or the working tree.
"""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REFS = ["origin/main", "origin/claude/roadmap-redo"]
CLOSED = {"done", "superseded"}


def ledger():
    path = os.path.join(ROOT, "docs", "DECISIONS.md")
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            return f.read(), "this checkout"
    for ref in REFS:
        try:
            out = subprocess.run(["git", "-C", ROOT, "show", ref + ":docs/DECISIONS.md"], capture_output=True, timeout=10)
        except Exception:
            continue
        if out.returncode == 0 and out.stdout:
            return out.stdout.decode("utf-8", "replace"), ref
    return "", ""


def main():
    text, source = ledger()
    if not text:
        print("OWNER DECISIONS: docs/DECISIONS.md not found on origin/main, origin/claude/roadmap-redo or this checkout.")
        return 0
    rows = []
    for line in text.splitlines():
        if not line.startswith("| D-"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) >= 5 and cells[3] not in CLOSED:
            rows.append(f"{cells[0]} [{cells[3]}] {cells[2]} -> {cells[4]}")
    print(f"OWNER DECISIONS still open ({len(rows)}, from docs/DECISIONS.md on {source}):")
    for r in rows:
        print("  " + r)
    print("Rule: a new owner decision goes into docs/DECISIONS.md in the same session, with where its work is tracked "
          "(a ROADMAP section or a PR/issue); read the ledger before planning or rewriting the roadmap; before the final "
          "report of a session, check the owner's messages for decisions not yet in it.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
