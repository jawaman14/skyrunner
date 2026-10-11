#!/usr/bin/env python3
"""One screen for the collaboration: both agents, their claims, the newest notes and the open pull requests.

    python tools/collab/dashboard.py            # live, redraws every 5 s; Ctrl+C quits
    python tools/collab/dashboard.py --once     # draw once and exit (also what a pipe gets, without colour)
    python tools/collab/dashboard.py --no-prs   # skip the GitHub call (offline)

Read-only: it reads the board file and, for the pull requests, `gh pr list` (cached 60 s). It writes nothing, acknowledges
nothing and wakes nobody. Colour follows the terminal; set NO_COLOR=1 to turn it off. Lines are cut to the terminal width.

Marks: a green dot is an agent with nothing waiting, a yellow one has notes waiting, red is STALE (unanswered and quiet longer
than --quiet-min, a post-time guess, not proof). For a pull request: CI ok / failing / running, and whether it is a draft.
"""
import argparse
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
import board_status  # noqa: E402
import review_packet  # noqa: E402

COLORS = {"reset": "\033[0m", "dim": "\033[2m", "bold": "\033[1m", "red": "\033[31m", "green": "\033[32m",
          "yellow": "\033[33m", "cyan": "\033[36m", "magenta": "\033[35m"}
PR_CACHE_S = 60.0


def paint(text, color, on):
    return COLORS[color] + text + COLORS["reset"] if on and color else text


def ago(seconds):
    if seconds is None:
        return "never"
    m = seconds / 60.0
    if m < 1:
        return "now"
    if m < 90:
        return "%dm" % round(m)
    return "%.1fh" % (m / 60.0)


def cut(text, width):
    text = " ".join(str(text).split())
    return text if len(text) <= width else text[:max(0, width - 1)] + "…"


def read_board(db, now, quiet_min, notes=8):
    """Everything the screen shows from the board: the agent summary and the newest notes."""
    summary = board_status.summarize(db, now, quiet_min)
    rows = db.execute("SELECT id, author, recipient, text, created FROM notes ORDER BY id DESC LIMIT ?", (notes,)).fetchall()
    recent = [{"id": r[0], "author": r[1], "to": r[2], "text": r[3], "age_s": now - r[4]} for r in reversed(rows)]
    return {"agents": summary, "notes": recent}


def pr_state(item):
    """('ok'|'fail'|'run'|'none', draft) from one `gh pr list` row; check runs and legacy status contexts both count."""
    checks = item.get("statusCheckRollup") or []
    if not checks:
        return "none", bool(item.get("isDraft"))
    states = [review_packet.check_state(c) for c in checks]
    return ("fail" if "fail" in states else ("run" if "run" in states else "ok")), bool(item.get("isDraft"))


def next_action(item, state, draft):
    """Who has to act next on a pull request, from what `gh pr list` gives: (who, what). Unanswered review threads are not in
    that data; review_packet.py lists them."""
    if state == "fail":
        return "author", "CI failing"
    if state == "run":
        return "ci", "CI running"
    if item.get("mergeable") == "CONFLICTING":
        return "author", "sync main"
    if draft:
        return "author", "mark ready"
    head = item.get("headRefOid", "")
    marks = [r for r in item.get("reviews") or [] if ((r.get("author") or {}).get("login", "")).lower() not in ("chatgpt-codex-connector", "")
             and not ((r.get("author") or {}).get("login", "")).endswith("[bot]")]
    current = [r for r in marks if (r.get("commit") or {}).get("oid") == head]
    if any((r.get("state") or "").upper() == "CHANGES_REQUESTED" for r in current):
        return "author", "fix requested changes"
    if any((r.get("state") or "").upper() == "APPROVED" for r in current):
        return "integrator", "merge"
    return "reviewer", "review head" if not marks else "re-review head"


def load_prs(root, run=subprocess.run):
    """Open pull requests, or None when gh is missing or fails (the screen says so and carries on)."""
    try:
        out = run(["gh", "pr", "list", "--json", "number,title,isDraft,author,statusCheckRollup,reviewDecision,mergeable,headRefOid,reviews", "--limit", "30"],
                  cwd=root, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=30)
    except (OSError, subprocess.TimeoutExpired):
        return None
    if out.returncode != 0:
        return None
    try:
        rows = []
        for p in json.loads(out.stdout):
            state, draft = pr_state(p)
            who, what = next_action(p, state, draft)
            rows.append({"number": p["number"], "title": p["title"], "author": (p.get("author") or {}).get("login", "?"),
                         "state": state, "draft": draft, "review": p.get("reviewDecision") or "", "who": who, "what": what})
        return rows
    except (ValueError, KeyError, TypeError):
        return None


def render(data, prs, width=100, color=True, now=None):
    """The whole screen as a string. Pure: the data in, text out, so it is tested without a terminal."""
    width = max(60, width)
    now = time.time() if now is None else now
    out = [paint("Skyrunner collaboration", "bold", color) + paint("  " + time.strftime("%H:%M:%S", time.localtime(now)), "dim", color), ""]
    for agent, s in data["agents"].items():
        mark, tone = ("●", "green")
        if s["unanswered"]:
            mark, tone = "●", "yellow"
        if s["stale"]:
            mark, tone = "●", "red"
        last = None if s["last_post_min_ago"] is None else s["last_post_min_ago"] * 60
        wait = "nothing waiting" if not s["unanswered"] else "%d waiting (oldest %s)" % (s["unanswered"], ago(s["oldest_unanswered_min"] * 60))
        out.append("%s %s  last post %s ago · %s%s" % (paint(mark, tone, color), paint("%-6s" % agent, "bold", color), ago(last), wait,
                                                         paint("  STALE", "red", color) if s["stale"] else ""))
        for c in s["active_claims"]:
            out.append("    " + paint("claim", "dim", color) + " " + cut(c["title"], width - 30) + paint("  (%dm left)" % c["expires_in_min"], "dim", color))
    out += ["", paint("Newest notes", "bold", color)]
    if not data["notes"]:
        out.append("    none")
    for n in data["notes"]:
        who = n["author"].split("-")[0]
        tone = "cyan" if who == "claude" else ("magenta" if who == "codex" else "")
        head = "#%d %s→%s %s" % (n["id"], who, n["to"], ago(n["age_s"]))
        out.append("  " + paint(head, tone, color) + "  " + cut(n["text"], width - len(head) - 6))
    out += ["", paint("Pull requests", "bold", color)]
    if prs is None:
        out.append("    " + paint("unavailable (gh missing, offline, or --no-prs)", "dim", color))
    elif not prs:
        out.append("    none open")
    else:
        marks = {"ok": ("✓", "green"), "fail": ("✗", "red"), "run": ("…", "yellow"), "none": ("-", "dim")}
        for p in prs[:14]:
            sym, tone = marks[p["state"]]
            tags = ("draft " if p["draft"] else "") + (p["review"].lower().replace("_", " ") + " " if p["review"] else "")
            nxt = ("-> %s: %s" % (p["who"], p["what"])) if p.get("who") else ""
            out.append("  %s #%-4d %s%s  %s" % (paint(sym, tone, color), p["number"], paint(nxt, "yellow" if p.get("who") in ("reviewer", "author") else "dim", color),
                                                 paint(tags.rstrip() + " ", "dim", color), cut(p["title"], max(10, width - 16 - len(nxt) - len(tags)))))
        if len(prs) > 14:
            out.append("    … %d more" % (len(prs) - 14))
    return "\n".join(cut_ansi(line, width) for line in out)


def cut_ansi(line, width):
    """Cut a line to the width without counting colour codes (they are zero-width)."""
    plain, i, visible, result = line, 0, 0, []
    while i < len(plain):
        if plain[i] == "\033":
            j = plain.find("m", i)
            j = len(plain) - 1 if j < 0 else j
            result.append(plain[i:j + 1])
            i = j + 1
            continue
        if visible >= width:
            result.append(COLORS["reset"] if "\033" in line else "")
            break
        result.append(plain[i])
        visible += 1
        i += 1
    return "".join(result)


def enable_ansi():
    if os.name != "nt":
        return
    try:  # switch the Windows console to understand colour codes (ENABLE_VIRTUAL_TERMINAL_PROCESSING), no shell involved
        import ctypes
        kernel = ctypes.windll.kernel32
        handle = kernel.GetStdHandle(-11)
        mode = ctypes.c_uint32()
        if kernel.GetConsoleMode(handle, ctypes.byref(mode)):
            kernel.SetConsoleMode(handle, mode.value | 0x0004)
    except (AttributeError, OSError):
        pass


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--db", default="")
    ap.add_argument("--root", default=".")
    ap.add_argument("--once", action="store_true")
    ap.add_argument("--no-prs", action="store_true")
    ap.add_argument("--interval", type=float, default=5.0)
    ap.add_argument("--quiet-min", type=float, default=20.0)
    ap.add_argument("--notes", type=int, default=8)
    args = ap.parse_args(argv)
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass
    path = args.db or board_status.board_path(args.root)
    if not os.path.exists(path):
        raise SystemExit("no board at " + path)
    live = not args.once and sys.stdout.isatty()
    color = sys.stdout.isatty() and not os.environ.get("NO_COLOR")
    if color:
        enable_ansi()
    prs, fetched = None, 0.0
    try:
        while True:
            db = sqlite3.connect("file:%s?mode=ro" % path.replace("\\", "/"), uri=True)
            try:
                data = read_board(db, time.time(), args.quiet_min, args.notes)
            finally:
                db.close()
            if not args.no_prs and time.time() - fetched > PR_CACHE_S:
                prs, fetched = load_prs(args.root), time.time()
            width = shutil.get_terminal_size((100, 30)).columns
            screen = render(data, prs, width, color)
            if live:
                sys.stdout.write("\033[H\033[2J" + screen + "\n\n" + paint("Ctrl+C to quit · redraws every %.0f s" % args.interval, "dim", color) + "\n")
                sys.stdout.flush()
                time.sleep(args.interval)
            else:
                print(screen)
                return 0
    except KeyboardInterrupt:
        return 0


if __name__ == "__main__":
    sys.exit(main())
