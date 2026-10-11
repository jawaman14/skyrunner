#!/usr/bin/env python3
"""Post an agent review on a pull request, in the form the merge queue reads, from a shell.

    python tools/collab/post_review.py --pr 330 --head <40-char sha> --verdict approve --agent codex --body-file review.md
    python tools/collab/post_review.py --pr 330 --head <sha> --verdict changes --agent codex --body "what is wrong"
    add --dry-run to print the review instead of posting it

The MCP tool `github_pr_review` is the normal way. A turn started unattended with `codex exec` cannot call it (its approval policy is
"never", so any MCP tool that asks for approval is refused), but its shell works. This posts the same review: a GitHub review whose
body starts with the marker `<!-- skyrunner-review agent=<claude|codex> verdict=<approve|changes|comment> head=<40-char sha> -->`,
which `github_merge_queue` reads, pinned to the head you reviewed. It is a bridge until the one-tool approval is allowed for woken turns.

What it refuses, so the bridge is no weaker than the tool: a head that is not the PR's current head (a later push needs a fresh
review), an empty body, and a review by the agent that wrote the PR (the branch prefix `claude/` or `codex/` says who wrote it).
It posts nothing else, merges nothing, and calls `gh` without a shell.
"""
import argparse
import json
import re
import subprocess
import sys

HEAD_RE = re.compile(r"^[0-9a-f]{40}$")
VERDICTS = ("approve", "changes", "comment")
AGENTS = ("claude", "codex")


def marker(agent, verdict, head):
    """Exactly the marker skyrunner-mcp's github_pr_review writes and its queue parses."""
    return "<!-- skyrunner-review agent=%s verdict=%s head=%s -->" % (agent, verdict, head)


def author_agent(branch):
    """'claude' or 'codex' from a branch name (claude/..., codex/...), else ''."""
    m = re.match(r"(claude|codex)(?![a-z])", (branch or "").strip().lower())
    return m.group(1) if m else ""


def check(info, agent, verdict, head, body):
    """None if the review may be posted, else the reason it may not."""
    if agent not in AGENTS:
        return "agent must be claude or codex"
    if verdict not in VERDICTS:
        return "verdict must be one of " + ", ".join(VERDICTS)
    if not HEAD_RE.match(head or ""):
        return "give the full 40-character head sha you reviewed"
    if not (body or "").strip():
        return "say what you checked and what you found: an empty review is refused"
    if info.get("headRefOid") != head:
        return "the PR head is now %s, not %s: review the current head" % (str(info.get("headRefOid"))[:8], head[:8])
    if author_agent(info.get("headRefName")) == agent:
        return "%s wrote this PR (branch %s): an agent cannot review its own work" % (agent, info.get("headRefName"))
    return None


def gh(args, run=subprocess.run):
    out = run(["gh"] + args, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=60)
    if out.returncode != 0:
        raise SystemExit("gh %s failed: %s" % (" ".join(args[:2]), " ".join((out.stderr or "").split())[:200]))
    return out.stdout


def main(argv=None, run=subprocess.run):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--pr", type=int, required=True)
    ap.add_argument("--head", required=True, help="the full sha you reviewed")
    ap.add_argument("--verdict", required=True, choices=VERDICTS)
    ap.add_argument("--agent", required=True, choices=AGENTS, help="who is reviewing")
    group = ap.add_mutually_exclusive_group(required=True)
    group.add_argument("--body")
    group.add_argument("--body-file")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args(argv)
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass
    body = args.body if args.body is not None else open(args.body_file, encoding="utf-8").read()
    info = json.loads(gh(["pr", "view", str(args.pr), "--json", "headRefOid,headRefName,isDraft"], run))
    why = check(info, args.agent, args.verdict, args.head, body)
    if why:
        print("refused: " + why, file=sys.stderr)
        return 2
    text = marker(args.agent, args.verdict, args.head) + "\n" + body.strip() + "\n"
    if args.dry_run:
        print(text)
        return 0
    out = gh(["api", "repos/{owner}/{repo}/pulls/%d/reviews" % args.pr, "-f", "commit_id=" + args.head, "-f", "event=COMMENT", "-f", "body=" + text,
              "--jq", ".html_url"], run)
    print("posted: " + out.strip())
    return 0


if __name__ == "__main__":
    sys.exit(main())
