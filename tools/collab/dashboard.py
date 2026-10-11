#!/usr/bin/env python3
"""One screen for the collaboration board: both agents, their claims and the newest notes.

    python tools/collab/dashboard.py            # live, redraws every 5 s; Ctrl+C quits
    python tools/collab/dashboard.py --once     # draw once and exit (also what a pipe gets, without colour)

Read-only: it reads the board file and nothing else. It writes nothing, acknowledges nothing and wakes nobody. It shows NO GitHub data: the
owner's rule is that GitHub reads go through the `skyrunner` MCP tools, so the pull-request view is `github_merge_queue` (and `github_review_packet`
for one PR), not this script. Colour follows the terminal; set NO_COLOR=1 to turn it off. Lines are cut to the terminal width.

Marks: a green dot is an agent with nothing waiting, a yellow one has notes waiting, red is STALE (unanswered and quiet longer than --quiet-min, a
post-time guess, not proof).
"""
import argparse
import os
import shutil
import sqlite3
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
import board_status  # noqa: E402

COLORS = {"reset": "\033[0m", "dim": "\033[2m", "bold": "\033[1m", "red": "\033[31m", "green": "\033[32m",
          "yellow": "\033[33m", "cyan": "\033[36m", "magenta": "\033[35m"}


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


def render(data, width=100, color=True, now=None):
    """The whole screen as a string. Pure: the data in, text out, so it is tested without a terminal."""
    width = max(60, width)
    now = time.time() if now is None else now
    out = [paint("Skyrunner collaboration", "bold", color) + paint("  " + time.strftime("%H:%M:%S", time.localtime(now)), "dim", color), ""]
    for agent, s in data["agents"].items():
        tone = "red" if s["stale"] else ("yellow" if s["unanswered"] else "green")
        last = None if s["last_post_min_ago"] is None else s["last_post_min_ago"] * 60
        wait = "nothing waiting" if not s["unanswered"] else "%d waiting (oldest %s)" % (s["unanswered"], ago(s["oldest_unanswered_min"] * 60))
        out.append("%s %s  last post %s ago · %s%s" % (paint("●", tone, color), paint("%-6s" % agent, "bold", color), ago(last), wait,
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
    try:
        while True:
            db = sqlite3.connect("file:%s?mode=ro" % path.replace("\\", "/"), uri=True)
            try:
                data = read_board(db, time.time(), args.quiet_min, args.notes)
            finally:
                db.close()
            screen = render(data, shutil.get_terminal_size((100, 30)).columns, color)
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
