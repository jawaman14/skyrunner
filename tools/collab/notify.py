#!/usr/bin/env python3
"""A cheap doorbell for the shared board: say when a new note has arrived for an agent, and optionally ring.

    python tools/collab/notify.py once  --recipient codex --cursor-file PATH     # gate: prints nothing when nothing is new
    python tools/collab/notify.py watch --recipient codex [--interval 15] [--toast] [--wake-cmd "..."]

A note on the board does not wake anyone: the receiving agent only sees it on its next read. This is the missing bell.

  once   Reads the board read-only, finds notes addressed to the recipient (or to everyone) that it has not been told about
         yet (the cursor file remembers the last id announced), and prints one short line per note, id, sender and the first
         160 characters. Exit status 10 means "something new", 0 means nothing. With nothing new it prints nothing at all, so
         an agent's scheduled check costs one tiny command instead of a board read. It never writes to the board and never
         acknowledges anything: the announced cursor is only this tool's.
  watch  The same check on a timer. For each new note it prints the line, rings the terminal bell and, with --toast, shows a
         Windows notification so the person at the machine can prompt the agent. --wake-cmd runs a command you choose for
         each batch (for example one that starts the agent's own command-line turn). It is OFF unless you pass it: starting
         another agent spends its quota and lets it act on its own, so that is the owner's decision, not a default.

Notes never authorize anything; a notification only says that one exists. The board file is the SQLite file the MCP server keeps
in the clone's Git directory (SKYRUNNER_BOARD overrides it).
"""
import argparse
import json
import os
import shlex
import sqlite3
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
import board_status  # noqa: E402

PREVIEW = 160


def new_notes(db, recipient, after):
    """(id, author, text-preview) for notes after `after` addressed to the recipient or to everyone, not sent by it."""
    rows = db.execute("SELECT id, author, text FROM notes WHERE id>? AND recipient IN ('all', ?) AND author NOT LIKE ? ORDER BY id",
                      (after, recipient, recipient + "%")).fetchall()
    return [(r[0], r[1], " ".join(str(r[2]).split())[:PREVIEW]) for r in rows]


def line(note, recipient):
    return "%s: note %d from %s: %s" % (recipient, note[0], note[1], note[2])


def read_cursor(path, db, recipient):
    """The last announced id. A first run starts at the current newest note addressed to the recipient's past, so an old
    backlog is not announced as new: use board_status.py for the backlog."""
    if path and os.path.exists(path):
        try:
            return int(open(path, encoding="utf-8").read().strip())
        except ValueError:
            pass
    return db.execute("SELECT COALESCE(MAX(id), 0) FROM notes").fetchone()[0]


def write_cursor(path, value):
    if path:
        os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(str(value))


def toast_command(title, body):
    """The PowerShell that shows a Windows toast (Windows PowerShell 5.1, no module needed). Returned, not run."""
    def q(s):
        return s.replace("'", "''")
    script = (
        "[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null;"
        "[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null;"
        "$x = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02);"
        "$t = $x.GetElementsByTagName('text');"
        "$t.Item(0).AppendChild($x.CreateTextNode('%s')) | Out-Null;"
        "$t.Item(1).AppendChild($x.CreateTextNode('%s')) | Out-Null;"
        "$n = [Windows.UI.Notifications.ToastNotification]::new($x);"
        "[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\\WindowsPowerShell\\v1.0\\powershell.exe').Show($n)"
    ) % (q(title), q(body))
    return ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", script]


def ring(notes, recipient, toast, wake_cmd):
    for n in notes:
        print(line(n, recipient), flush=True)
    sys.stdout.write("\a")
    sys.stdout.flush()
    if toast and os.name == "nt":
        body = notes[-1][2] if len(notes) == 1 else "%d new notes; latest from %s" % (len(notes), notes[-1][1])
        subprocess.run(toast_command("Skyrunner board: note for %s" % recipient, body), capture_output=True)
    if wake_cmd:
        env = dict(os.environ, SKYRUNNER_NOTE_IDS=",".join(str(n[0]) for n in notes), SKYRUNNER_RECIPIENT=recipient)
        # no shell: the command is split into arguments, and only note ids (integers) reach it, never note text
        subprocess.run(shlex.split(wake_cmd, posix=(os.name != "nt")), env=env)


def open_board(args):
    path = args.db or board_status.board_path(args.root)
    if not os.path.exists(path):
        raise SystemExit("no board at " + path)
    return sqlite3.connect("file:%s?mode=ro" % path.replace("\\", "/"), uri=True)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("mode", choices=["once", "watch"])
    ap.add_argument("--recipient", required=True, choices=board_status.AGENTS)
    ap.add_argument("--db", default="")
    ap.add_argument("--root", default=".")
    ap.add_argument("--cursor-file", default="", help="remembers the last announced id (once: required for a useful gate)")
    ap.add_argument("--interval", type=float, default=15.0)
    ap.add_argument("--toast", action="store_true")
    ap.add_argument("--wake-cmd", default="", help="OFF by default; a command run for each batch (see the module notes)")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)
    if args.mode == "once":
        db = open_board(args)
        try:
            fresh = bool(args.cursor_file) and not os.path.exists(args.cursor_file)
            after = read_cursor(args.cursor_file, db, args.recipient)
            notes = new_notes(db, args.recipient, after)
        finally:
            db.close()
        if fresh:
            write_cursor(args.cursor_file, after)  # the first run fixes the starting point, or the next run would skip what came between
        if not notes:
            return 0
        if args.json:
            print(json.dumps([{"id": n[0], "from": n[1], "preview": n[2]} for n in notes]))
        else:
            for n in notes:
                print(line(n, args.recipient))
        write_cursor(args.cursor_file, notes[-1][0])
        return 10
    db = open_board(args)
    after = read_cursor(args.cursor_file, db, args.recipient)
    db.close()
    print("watching the board for %s (every %.0f s); Ctrl+C to stop" % (args.recipient, args.interval), flush=True)
    while True:
        db = open_board(args)
        try:
            notes = new_notes(db, args.recipient, after)
        finally:
            db.close()
        if notes:
            ring(notes, args.recipient, args.toast, args.wake_cmd)
            after = notes[-1][0]
            write_cursor(args.cursor_file, after)
        time.sleep(args.interval)


if __name__ == "__main__":
    sys.exit(main())
