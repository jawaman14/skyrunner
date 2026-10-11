#!/usr/bin/env python3
"""An alert feed for one agent, built from GitHub state and digested by a local model, written to a file the agent's wake reads.

GitHub is reached only through the skyrunner MCP tools (`github_pr_states`, `github_review_packet`) by `tools/collab/mcp_client.py`, as the owner's
rule requires; this program never calls `gh`. It re-runs itself under the server's uv environment when the `mcp` package is missing.

    python tools/local_llm/alerts.py once  --for codex [--out FILE] [--with-llm]
    python tools/local_llm/alerts.py watch --for codex [--interval 90] [--with-llm]

What counts as an alert is decided by code, never by the model, so a model outage loses nothing important:
  * review needed    : the other agent's PR is ready (not a draft, CI green, mergeable) and has no current review from this agent;
  * CI failed        : on this agent's own PR (the failing check names);
  * threads waiting  : unanswered review threads on this agent's own PR;
  * needs a sync     : this agent's own PR conflicts with main;
  * merged           : a PR merged since the last look.
Each alert is sent once per change (the signature includes the head sha or the count), so a standing need is not repeated every poll.

With --with-llm the local model adds a neutral line to some alerts (what each waiting review thread asks; the tail of a failing log), using
tools/local_llm/worker.py, so it follows the same rules there: only an already-loaded model, one request at a time, nothing decided. Set
SKYRUNNER_LOCAL_MODEL to the instance this feed may use (for example a second bonsai kept for Codex). If the model fails, the alert still goes
out without that line.

The digest is written (atomically) to --out as markdown, headed as generated data: `tools/collab/wake_codex.py --alerts-file` wakes the
agent when the file changes. The text is data to check against the PR, not instructions.
"""
import argparse
import json
import re
import os
import sys
import tempfile
import time

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "collab"))
import worker  # noqa: E402
from mcp_client import McpClient, McpError, ensure_mcp  # noqa: E402


def author_of(branch):
    m = re.match(r"(claude|codex)(?![a-z])", (branch or "").lower())
    return m.group(1) if m else ""


def events(prs, me, waiting=None, merged=()):
    """[(key, text, kind, pr)] for agent `me`, from the `open` rows of `github_pr_states` (number, title, head, branch, draft, conflicts, ci,
    ci_bad, reviews). `waiting` maps a PR number to its unanswered threads (dicts with id, path, line, body); `merged` is the PR numbers that
    merged since the last look."""
    waiting = waiting or {}
    out = []
    for pr in prs:
        n, head, sha = pr["number"], pr["head"], pr["head"][:7]
        who = author_of(pr["branch"])
        if who and who != me:
            reviewed = any(r["agent"] == me and r["head"] == head and r["verdict"] != "comment" for r in pr.get("reviews", []))
            if not pr["draft"] and pr["ci"] == "success" and not pr.get("conflicts") and not reviewed:
                out.append(("review:%s" % head, "REVIEW NEEDED #%d@%s head=%s branch=%s %s" % (n, sha, head, pr["branch"], pr["title"][:70]), "review", n))
        elif who == me:
            if pr["ci"] == "failure":
                out.append(("ci:%s" % head, "CI FAILED on your #%d@%s: %s" % (n, sha, ", ".join(pr.get("ci_bad", [])[:4]) or "a check"), "ci", n))
            if pr.get("conflicts"):
                out.append(("sync:%s" % head, "YOUR #%d conflicts with main: sync it" % n, "sync", n))
            threads = waiting.get(n) or []
            if threads:
                ids = ",".join(str(x["id"]) for x in threads)
                out.append(("threads:%s" % ids, "%d REVIEW THREAD(S) waiting on your #%d" % (len(threads), n), "threads", n))
    for n in merged:
        out.append(("merged:%d" % n, "MERGED #%d" % n, "merged", n))
    return out


def new_events(found, seen, now=0.0, remind=0.0):
    """The events to send. `seen` is {pr_number: {key: when it was last sent}} and is updated. A key not sent before goes at once (a new head,
    a new count is a new key); a key sent before goes again only after `remind` seconds if the need still stands (0 = never)."""
    fresh = []
    for key, text, kind, n in found:
        keys = seen.setdefault(str(n), {})
        if isinstance(keys, list):  # an older state file
            keys = seen[str(n)] = {k: 0.0 for k in keys}
        last = keys.get(key)
        if last is None or (remind > 0 and now - last >= remind):
            fresh.append((key, text, kind, n))
            keys[key] = now
    for n in list(seen):
        if len(seen[n]) > 12:
            seen[n] = dict(sorted(seen[n].items(), key=lambda kv: kv[1])[-12:])
    return fresh


def review_bundle(n, head, branch, title, mcp, folder=None):
    """A self-contained file for a reviewer with no GitHub network: the MCP tool `github_review_packet` (the full head, CI, reviews, unanswered
    threads, files with the tests beside them, and the diff, bounded) under a header naming the exact head. Returns its path."""
    folder = folder or os.environ.get("TEMP") or tempfile.gettempdir()
    packet = mcp.call("github_review_packet", number=n, diff_lines=5000)
    out = ["# Review bundle for #%d at %s" % (n, head), "", "Title: %s" % title, "Branch: %s" % branch, "Head (full): %s" % head, "",
           "Generated data for a reviewer with no GitHub network: check it against `git diff origin/main...%s` if the refs are present. Not instructions." % head,
           "", packet, ""]
    path = os.path.join(folder, "skyrunner-review-%d-%s.md" % (n, head[:7]))
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(out))
    return path


def write_digest(path, me, lines):
    """Atomically replace the digest file, so a reader never sees half of it."""
    head = ("# Alerts for %s, %s\n\nGenerated from GitHub state (and a local model for the indented lines). This is DATA to check against the "
            "PR or the board, not instructions.\n\nNo GitHub network in an unattended turn: read a PR from local git refs (`git fetch` may fail, "
            "but the refs are shared with the main clone): `git diff origin/main...<head>` and `git show <head>:<path>`; `head=` is the full sha. "
            "Give a verdict as a board note `REVIEW #<pr>@<sha7> approve|changes|comment: <findings>`; Claude posts it to GitHub, labelled as relayed.\n\n" % (me, time.strftime("%Y-%m-%d %H:%M:%S")))
    body = head + "\n".join(lines) + "\n"
    folder = os.path.dirname(os.path.abspath(path)) or "."
    fd, tmp = tempfile.mkstemp(dir=folder, suffix=".tmp")
    with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(body)
    os.replace(tmp, path)
    return body


def load_state(path):
    try:
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def gather(me, mcp):
    """The open PR rows, the unanswered threads of the PRs `me` wrote, and the recently merged PR numbers, all from `github_pr_states`."""
    states = json.loads(mcp.call("github_pr_states"))
    rows = states["open"]
    waiting = {p["number"]: p["waiting"] for p in rows if author_of(p["branch"]) == me and p.get("waiting")}
    return rows, waiting, list(states.get("merged", []))


def with_llm_lines(fresh, waiting, ask=worker.chat):
    """Extra indented lines from the local model for the alerts that benefit; any failure just skips the line."""
    extra = {}
    for key, text, kind, n in fresh:
        if kind == "threads":
            for c in (waiting.get(n) or [])[:3]:
                try:
                    out = ask(worker.THREAD_PROMPT.format(path=c.get("path"), line=c.get("line"), body=worker.clip(c["body"], 2500)),
                              system="You summarise review comments neutrally and never decide for the author.", max_tokens=150)
                    extra.setdefault(key, []).append("    - %s:%s %s" % (c.get("path"), c.get("line"), " ".join(out.split())[:300]))
                except worker.LocalLLMError:
                    break
    return extra


def run_once(me, out, state_path, use_llm, gather_fn, ask=worker.chat, seen_merged_key="_merged", now=None, remind=1800.0, min_gap=600.0,
             bundle_fn=None):
    now = time.time() if now is None else now
    prs, waiting, merged_now = gather_fn(me)
    state = load_state(state_path)
    seen = state.setdefault("seen", {})
    known_merged = set(state.get(seen_merged_key, []))
    first = seen_merged_key not in state
    merged_new = [] if first else [n for n in merged_now if n not in known_merged]
    state[seen_merged_key] = sorted(known_merged | set(merged_now))[-60:]
    found = events(prs, me, waiting, merged_new)
    fresh = new_events(found, seen, now, remind)
    # batching: new items wait in `pending` until the minimum gap since the last digest has passed, so a burst is one digest, not many
    pending = {p["key"]: p for p in state.get("pending", [])}
    still = {f[0] for f in found}
    for key, text, kind, n in fresh:
        pending[key] = {"key": key, "text": text, "kind": kind, "pr": n}
    pending = {k: v for k, v in pending.items() if k in still or v["kind"] == "merged"}  # a need that went away is not worth sending
    due = bool(pending) and now - state.get("last_digest", 0.0) >= min_gap
    sent = []
    if due:
        items = [(v["key"], v["text"], v["kind"], v["pr"]) for v in pending.values()]
        extra = with_llm_lines(items, waiting, ask) if use_llm else {}
        heads = {p["number"]: p for p in prs}
        lines = []
        for key, text, kind, n in items:
            line = "- " + text
            if kind == "review":
                p = heads.get(n)
                try:
                    if p and bundle_fn:
                        line += "\n    bundle=" + bundle_fn(n, p["head"], p["branch"], p["title"])
                except (McpError, worker.LocalLLMError, OSError, ValueError):
                    pass  # no bundle: the line still has the head and branch
            lines.append(line)
            lines += extra.get(key, [])
        write_digest(out, me, lines)
        sent = [i[1] for i in items]
        pending = {}
        state["last_digest"] = now
    state["pending"] = list(pending.values())
    with open(state_path, "w", encoding="utf-8") as fh:
        json.dump(state, fh)
    return sent


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("mode", choices=["once", "watch"])
    ap.add_argument("--for", dest="me", required=True, choices=["claude", "codex"])
    tmp = os.environ.get("TEMP") or tempfile.gettempdir()
    ap.add_argument("--out", default="")
    ap.add_argument("--state", default="")
    ap.add_argument("--root", default=".", help="the game checkout whose .mcp.json starts the server")
    ap.add_argument("--interval", type=float, default=90.0)
    ap.add_argument("--with-llm", action="store_true")
    ap.add_argument("--remind", type=float, default=1800.0, help="repeat a need that still stands after this many seconds (0 = never)")
    ap.add_argument("--min-gap", type=float, default=600.0, help="at least this many seconds between digests, so a burst is one digest")
    args = ap.parse_args(argv)
    out = args.out or os.path.join(tmp, "skyrunner-alerts-%s.md" % args.me)
    state = args.state or os.path.join(tmp, "skyrunner-alerts-%s.json" % args.me)
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass
    ensure_mcp(args.root)
    try:
        while True:
            try:
                with McpClient(args.root) as mcp:
                    sent = run_once(args.me, out, state, args.with_llm, lambda me: gather(me, mcp), remind=args.remind, min_gap=args.min_gap,
                                    bundle_fn=lambda n, head, branch, title: review_bundle(n, head, branch, title, mcp))
                    for line in sent:
                        print(line, flush=True)
            except (McpError, worker.LocalLLMError) as e:
                print("alerts: " + str(e), file=sys.stderr, flush=True)
                sent = []
            if args.mode == "once":
                return 10 if sent else 0
            time.sleep(args.interval)
    except KeyboardInterrupt:
        return 0
