"""Tests for tools/collab: python tools/collab/test_collab_tools.py (stdlib only; needs git on PATH)."""
import json
import os
import re
import sqlite3
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(__file__))
import board_status  # noqa: E402
import dashboard  # noqa: E402
import review_packet  # noqa: E402
import notify  # noqa: E402
import run_locked  # noqa: E402
import sync_shared as sync  # noqa: E402


def conflict(ours, theirs):
    return "<<<<<<< HEAD\n%s=======\n%s>>>>>>> origin/main\n" % (ours, theirs)


class ResolveText(unittest.TestCase):
    def test_log_conflict_keeps_both_entries_newest_first(self):
        text = "# Handoff\n## The baton\n| a | b |\n\n## Log\n\n" + conflict("- ours\n", "- theirs\n") + "\n- older\n"
        out = sync.keep_both_in_log(text)
        self.assertEqual(out, "# Handoff\n## The baton\n| a | b |\n\n## Log\n\n- theirs\n\n- ours\n\n- older\n")
        self.assertFalse(sync.MARKER.search(out))

    def test_a_conflict_in_the_baton_is_left_for_a_person(self):
        text = "# Handoff\n" + conflict("| holder | claude |\n", "| holder | codex |\n") + "\n## Log\n\n- entry\n"
        with self.assertRaises(sync.Unresolved):
            sync.keep_both_in_log(text)

    def test_crlf_files_keep_their_line_endings(self):
        text = ("## Log\r\n\r\n<<<<<<< HEAD\r\n- ours\r\n=======\r\n- theirs\r\n>>>>>>> origin/main\r\n").replace("\n\r\n", "\n\r\n")
        out = sync.keep_both_in_log(text)
        self.assertNotIn("\n-", out.replace("\r\n-", ""))
        self.assertIn("- theirs", out)
        self.assertIn("- ours", out)

    def test_status_conflict_on_the_count_line_resolves_and_recounts(self):
        line = "| Declared automated tests | %d methods in %d test files | Compiled source inventory |\n"
        text = "| x | y |\n" + conflict(line % (1095, 139), line % (1097, 140)) + "| z | w |\n"
        out = sync.set_inventory(sync.resolve_status(text), 1101, 141)
        self.assertIn("| Declared automated tests | 1101 methods in 141 test files |", out)
        self.assertFalse(sync.MARKER.search(out))

    def test_status_conflict_beyond_the_count_line_is_not_guessed(self):
        text = conflict("| Version | 1 |\n", "| Version | 2 |\n")
        with self.assertRaises(sync.Unresolved):
            sync.resolve_status(text)

    def test_lanes_union_is_sorted_and_drops_the_trailing_comma(self):
        text = '{\n  "socket": [\n    "test_a.gd",\n' + conflict('    "test_leave.gd",\n', '    "test_picker.gd"\n') + "  ]\n}\n"
        out = sync.union_lanes(text)
        self.assertEqual(json.loads(out)["socket"], ["test_a.gd", "test_leave.gd", "test_picker.gd"])

    def test_lanes_conflict_that_is_not_test_names_is_not_guessed(self):
        text = '{\n  "socket": [\n' + conflict('    "oops",\n', '    "test_b.gd",\n') + "  ]\n}\n"
        with self.assertRaises(sync.Unresolved):
            sync.union_lanes(text)

    def test_a_test_file_in_two_lanes_is_rejected(self):
        with self.assertRaises(ValueError):
            sync.check_lanes(json.dumps({"logic": ["test_a.gd"], "socket": ["test_a.gd"]}))

    def test_count_tests_counts_unique_methods_per_file_and_skips_the_base_class(self):
        with tempfile.TemporaryDirectory() as d:
            os.makedirs(os.path.join(d, "tests"))
            for name, body in (("test_one.gd", "func test_a():\n\tpass\nfunc test_b():\n\tpass\nfunc helper():\n\tpass\n"),
                               ("test_two.gd", "func test_a():\n\tpass\n"),
                               ("test_case.gd", "func test_base():\n\tpass\n")):
                with open(os.path.join(d, "tests", name), "w") as fh:
                    fh.write(body)
            self.assertEqual(sync.count_tests(d), (3, 2))


class RunLocked(unittest.TestCase):
    def make_repo(self):
        d = tempfile.mkdtemp()
        subprocess.run(["git", "init", "-q", d], check=True)
        src = os.path.join(d, "server", "src")
        os.makedirs(src)
        with open(os.path.join(d, ".mcp.json"), "w") as fh:
            json.dump({"mcpServers": {"skyrunner": {"args": ["run", "--project", os.path.join(d, "server"), "skyrunner-mcp"],
                                                    "env": {"SKYRUNNER_GODOT": "/opt/godot"}}}}, fh)
        return d, src

    def test_test_preset_runs_the_filter_under_the_wait_lock_with_the_server_on_the_path(self):
        d, src = self.make_repo()
        cmd, env = run_locked.plan(d, ["test", "startup"], bash="/bin/bash", env={})
        self.assertEqual(cmd[1:4], ["-m", "skyrunner_mcp.locked", "--wait"])
        self.assertEqual(cmd[-3:], ["/bin/bash", "tools/test.sh", "startup"])
        self.assertEqual(env["GODOT"], "/opt/godot")
        self.assertTrue(env["PYTHONPATH"].startswith(src))

    def test_no_wait_and_status_write(self):
        d, _ = self.make_repo()
        cmd, _ = run_locked.plan(d, ["status", "--write"], wait=False, bash="/bin/bash", env={})
        self.assertNotIn("--wait", cmd)
        self.assertIn("--write", cmd[-1])
        self.assertIn("project_status.gd", cmd[-1])

    def test_a_missing_godot_is_a_clear_error(self):
        d, _ = self.make_repo()
        with open(os.path.join(d, ".mcp.json"), "w") as fh:
            json.dump({"mcpServers": {"skyrunner": {"args": ["--project", os.path.join(d, "server")]}}}, fh)
        with self.assertRaises(SystemExit):
            run_locked.plan(d, ["import"], bash="/bin/bash", env={})


class BoardStatus(unittest.TestCase):
    def board(self):
        db = sqlite3.connect(":memory:")
        db.execute("CREATE TABLE tasks (id TEXT PRIMARY KEY, owner TEXT, title TEXT, paths TEXT, checkout TEXT, revision TEXT, status TEXT, expires REAL, updated REAL, detail TEXT)")
        db.execute("CREATE TABLE notes (id INTEGER PRIMARY KEY AUTOINCREMENT, author TEXT, recipient TEXT, task TEXT, text TEXT, created REAL)")
        return db

    def note(self, db, author, recipient, minutes_ago, now=10000.0):
        db.execute("INSERT INTO notes (author, recipient, task, text, created) VALUES (?,?,?,?,?)",
                   (author, recipient, "", "t", now - minutes_ago * 60))

    def test_notes_sent_after_an_agents_last_post_are_unanswered_and_it_is_stale_when_quiet(self):
        now = 10000.0
        db = self.board()
        self.note(db, "codex-a", "claude", 100)
        self.note(db, "claude-1", "codex", 60)  # waited 60 min
        self.note(db, "claude-1", "all", 30)     # also for codex
        self.note(db, "claude-1", "claude", 5)   # not for codex
        s = board_status.summarize(db, now, quiet_min=20)
        self.assertEqual(s["codex"]["unanswered"], 2)
        self.assertEqual(s["codex"]["oldest_unanswered_min"], 60.0)
        self.assertEqual(s["codex"]["last_post_min_ago"], 100.0)
        self.assertTrue(s["codex"]["stale"])
        self.assertEqual(s["claude"]["unanswered"], 0, "its only inbound note came before it spoke")
        self.assertFalse(s["claude"]["stale"])

    def test_an_agent_that_posted_after_the_notes_has_nothing_waiting(self):
        now = 10000.0
        db = self.board()
        self.note(db, "claude-1", "codex", 50)
        self.note(db, "codex-b", "claude", 10)
        s = board_status.summarize(db, now)
        self.assertEqual(s["codex"]["unanswered"], 0)
        self.assertEqual(s["claude"]["unanswered"], 1, "codex's note is waiting for claude")
        self.assertFalse(s["claude"]["stale"], "10 minutes is not quiet")

    def test_claims_and_rendering(self):
        now = 10000.0
        db = self.board()
        db.execute("INSERT INTO tasks VALUES ('x','claude-1','a very long task title','[]','','','active',?,?,'')", (now + 1800, now))
        db.execute("INSERT INTO tasks VALUES ('y','claude-1','released one','[]','','','review',?,?,'')", (now + 1800, now))
        s = board_status.summarize(db, now)
        self.assertEqual([c["title"] for c in s["claude"]["active_claims"]], ["a very long task title"])
        text = board_status.render(s)
        self.assertIn("nothing waiting", text)
        self.assertIn("never posted", text)
        self.assertIn("30 min left", text)


class Notify(unittest.TestCase):
    def board(self):
        db = sqlite3.connect(":memory:")
        db.execute("CREATE TABLE notes (id INTEGER PRIMARY KEY AUTOINCREMENT, author TEXT, recipient TEXT, task TEXT, text TEXT, created REAL)")
        return db

    def add(self, db, author, recipient, text="hello"):
        db.execute("INSERT INTO notes (author, recipient, task, text, created) VALUES (?,?,?,?,0)", (author, recipient, "", text))

    def test_only_notes_for_the_recipient_after_the_cursor_and_not_its_own(self):
        db = self.board()
        self.add(db, "claude-1", "codex", "first")    # 1
        self.add(db, "claude-1", "claude", "other")   # 2: not for codex
        self.add(db, "codex-a", "claude", "mine")     # 3: from codex
        self.add(db, "claude-1", "all", "for everyone " + "x" * 400)  # 4
        notes = notify.new_notes(db, "codex", 0)
        self.assertEqual([n[0] for n in notes], [1, 4])
        self.assertEqual(len(notes[1][2]), notify.PREVIEW, "the preview is bounded")
        self.assertEqual([n[0] for n in notify.new_notes(db, "codex", 1)], [4])
        self.assertEqual(notify.new_notes(db, "codex", 4), [])

    def test_once_is_silent_when_nothing_is_new_and_exits_10_when_something_is(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "board.sqlite3")
            db = sqlite3.connect(path)
            db.execute("CREATE TABLE notes (id INTEGER PRIMARY KEY AUTOINCREMENT, author TEXT, recipient TEXT, task TEXT, text TEXT, created REAL)")
            db.execute("INSERT INTO notes (author, recipient, task, text, created) VALUES ('claude-1','codex','','old',0)")
            db.commit()
            cursor = os.path.join(d, "cursor.txt")
            args = ["once", "--recipient", "codex", "--db", path, "--cursor-file", cursor]
            import contextlib
            import io
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                self.assertEqual(notify.main(args), 0, "a first run starts at the newest note: the backlog is not announced")
            self.assertEqual(out.getvalue(), "")
            db.execute("INSERT INTO notes (author, recipient, task, text, created) VALUES ('claude-1','codex','','new one',0)")
            db.commit()
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                self.assertEqual(notify.main(args), 10)
            self.assertIn("note 2 from claude-1: new one", out.getvalue())
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                self.assertEqual(notify.main(args), 0, "announced once, then silent")
            self.assertEqual(out.getvalue(), "")
            db.close()

    def test_a_note_with_an_arrow_prints_on_a_cp1252_console_instead_of_crashing(self):
        import io
        raw = io.BytesIO()
        console = io.TextIOWrapper(raw, encoding="cp1252", errors="strict")
        real, sys.stdout = sys.stdout, console
        try:
            with self.assertRaises(UnicodeEncodeError):
                print("a → b")
                console.flush()
            console = io.TextIOWrapper(io.BytesIO(), encoding="cp1252", errors="strict")
            sys.stdout = console
            notify.utf8_streams()
            print("a → b")
            console.flush()
            self.assertIn("a → b".encode("utf-8"), console.buffer.getvalue())
        finally:
            sys.stdout = real

    def test_the_toast_command_quotes_its_text_and_the_wake_command_is_split_without_a_shell(self):
        cmd = notify.toast_command("Board", "it's here")
        self.assertEqual(cmd[0], "powershell.exe")
        self.assertIn("it''s here", cmd[-1])
        self.assertNotIn("shell=True", open(os.path.join(os.path.dirname(__file__), "notify.py"), encoding="utf-8").read().replace("no shell", "").replace("shell=True with", ""))


ESC = chr(27)
NL = chr(10)


class Dashboard(unittest.TestCase):
    def board(self):
        db = sqlite3.connect(":memory:")
        db.executescript("""CREATE TABLE notes (id INTEGER PRIMARY KEY, author TEXT, recipient TEXT, task TEXT, text TEXT, created REAL);
            CREATE TABLE tasks (id TEXT, owner TEXT, title TEXT, paths TEXT, checkout TEXT, revision TEXT, status TEXT, expires REAL,
                updated REAL, detail TEXT);""")
        now = 100000.0
        db.execute("INSERT INTO notes (author, recipient, text, created) VALUES ('claude-1','codex','please review 322 → now',?)", (now - 3000,))
        db.execute("INSERT INTO notes (author, recipient, text, created) VALUES ('codex-1','claude','done',?)", (now - 600,))
        db.execute("INSERT INTO notes (author, recipient, text, created) VALUES ('claude-1','codex','x' || char(10) || 'y',?)", (now - 100,))
        db.execute("INSERT INTO tasks VALUES ('t','claude-1','a very long claim title for the screen','[]','c','r','active',?,?,'')", (now + 3600, now))
        return db, now

    def test_the_screen_shows_agents_claims_notes_and_prs_without_colour_codes_when_off(self):
        db, now = self.board()
        prs = [{"number": 322, "title": "Add wake", "author": "x", "state": "ok", "draft": True, "review": ""},
               {"number": 7, "title": "Broken thing", "author": "x", "state": "fail", "draft": False, "review": "CHANGES_REQUESTED"}]
        text = dashboard.render(dashboard.read_board(db, now, 20.0), prs, 100, False, now)
        self.assertNotIn(ESC, text)
        for needle in ("claude", "codex", "claim", "#1 claude→codex", "#322", "draft", "changes requested", "✓", "✗"):
            self.assertIn(needle, text)
        self.assertIn("1 waiting", text, "codex has one unanswered note (id 3) after its last post (id 2)")

    def test_every_line_fits_the_width_even_with_colour_and_long_text(self):
        db, now = self.board()
        db.execute("INSERT INTO notes (author, recipient, text, created) VALUES ('codex-1','claude',?,?)", ("long " * 200, now - 1))
        data = dashboard.read_board(db, now, 20.0)
        prs = [{"number": 1, "title": "t" * 300, "author": "x", "state": "run", "draft": False, "review": ""}]
        for color in (False, True):
            for line in dashboard.render(data, prs, 70, color, now).split(NL):
                visible = re.sub(ESC + r"\[[0-9;]*m", "", line)
                self.assertLessEqual(len(visible), 70, visible)
        self.assertIn(ESC, dashboard.render(data, prs, 70, True, now))

    def test_a_missing_gh_is_a_message_not_a_crash_and_ci_states_are_classified(self):
        db, now = self.board()
        text = dashboard.render(dashboard.read_board(db, now, 20.0), None, 100, False, now)
        self.assertIn("unavailable", text)

        def boom(*a, **k):
            raise OSError("no gh")
        self.assertIsNone(dashboard.load_prs(".", run=boom))
        ok = {"statusCheckRollup": [{"status": "COMPLETED", "conclusion": "SUCCESS"}], "isDraft": False}
        bad = {"statusCheckRollup": [{"status": "COMPLETED", "conclusion": "SUCCESS"}, {"status": "COMPLETED", "conclusion": "FAILURE"}]}
        run = {"statusCheckRollup": [{"status": "IN_PROGRESS", "conclusion": ""}]}
        self.assertEqual([dashboard.pr_state(x)[0] for x in (ok, bad, run, {})], ["ok", "fail", "run", "none"])

    def test_once_prints_the_screen_from_a_real_board_file(self):
        tmp = tempfile.mkdtemp()
        path = os.path.join(tmp, "b.sqlite3")
        con = sqlite3.connect(path)
        con.executescript("""CREATE TABLE notes (id INTEGER PRIMARY KEY, author TEXT, recipient TEXT, task TEXT, text TEXT, created REAL);
            CREATE TABLE tasks (id TEXT, owner TEXT, title TEXT, paths TEXT, checkout TEXT, revision TEXT, status TEXT, expires REAL,
                updated REAL, detail TEXT);""")
        con.execute("INSERT INTO notes (author, recipient, text, created) VALUES ('claude-1','codex','hi',1.0)")
        con.commit()
        con.close()
        out = subprocess.run([sys.executable, os.path.join(os.path.dirname(__file__), "dashboard.py"), "--db", path, "--once", "--no-prs"],
                             capture_output=True, text=True, encoding="utf-8")
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("Newest notes", out.stdout)
        self.assertIn("#1 claude→codex", out.stdout)
        self.assertNotIn(ESC, out.stdout, "piped output has no colour codes")


class ReviewPacket(unittest.TestCase):
    def view(self):
        return {"number": 9, "title": "Fix thing", "author": {"login": "claude-bot"}, "isDraft": False, "headRefOid": "b" * 40,
                "baseRefName": "main", "mergeable": "MERGEABLE", "mergeStateStatus": "CLEAN",
                "files": [{"path": "scripts/sim/people.gd", "additions": 10, "deletions": 2}, {"path": "tests/test_people.gd", "additions": 5, "deletions": 0},
                          {"path": "docs/x.md", "additions": 1, "deletions": 0}],
                "statusCheckRollup": [{"name": "a", "status": "COMPLETED", "conclusion": "SUCCESS"},
                                      {"name": "b", "status": "COMPLETED", "conclusion": "FAILURE"}, {"name": "c", "status": "IN_PROGRESS", "conclusion": ""}],
                "reviews": [{"author": {"login": "codex"}, "state": "APPROVED", "commit": {"oid": "a" * 40}},
                            {"author": {"login": "codex"}, "state": "COMMENTED", "commit": {"oid": "b" * 40}}]}

    def test_a_review_on_an_older_head_is_stale_and_ci_failures_are_named(self):
        root = tempfile.mkdtemp()
        os.makedirs(os.path.join(root, "tests"))
        open(os.path.join(root, "tests", "test_people.gd"), "w").close()
        comments = [{"id": 1, "path": "a.gd", "line": 3, "user": {"login": "bot"}, "body": "unanswered"},
                    {"id": 2, "path": "b.gd", "line": 4, "user": {"login": "bot"}, "body": "answered"},
                    {"id": 3, "in_reply_to_id": 2, "user": {"login": "me"}, "body": "done"}]
        text = review_packet.render(review_packet.build(self.view(), comments, root), 0)
        self.assertIn("STALE: older head", text)
        self.assertIn("CURRENT", text)
        self.assertIn("FAILED: b", text)
        self.assertIn("running: c", text)
        self.assertIn("Open review threads: 1", text)
        self.assertIn("a.gd:3", text)
        self.assertNotIn("b.gd:4", text)
        self.assertIn("scripts/sim/people.gd", text)
        self.assertIn("tests by name: tests/test_people.gd", text)
        self.assertIn("changes 1 test file", text)
        self.assertLess(len(text), 2500, "the packet stays small")

    def test_pages_from_gh_paginate_are_joined_and_the_diff_is_capped(self):
        pages = '[{"a":1}]' + NL + '[{"a":2},{"a":3}]'
        self.assertEqual(review_packet.parse_pages(pages), [{"a": 1}, {"a": 2}, {"a": 3}])
        self.assertEqual(review_packet.parse_pages(""), [])
        packet = review_packet.build(self.view(), [], tempfile.mkdtemp(), NL.join("line %d" % i for i in range(500)))
        text = review_packet.render(packet, 20)
        self.assertIn("first 20 of 500 lines", text)
        self.assertIn("line 19", text)
        self.assertNotIn(NL + "line 20" + NL, NL + text + NL)


class EndToEnd(unittest.TestCase):
    """A real repository where main and a branch both change the three shared files."""

    def git(self, d, *a):
        subprocess.run(["git", "-C", d, "-c", "user.name=t", "-c", "user.email=t@t", *a], check=True,
                       capture_output=True, text=True)

    def write(self, d, rel, text):
        path = os.path.join(d, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", newline="") as fh:
            fh.write(text)

    def test_merging_main_resolves_the_shared_files_and_commits(self):
        status = "| Declared automated tests | %d methods in %d test files | Compiled |\n"
        handoff = "# H\n\n## The baton\n\n| a | b |\n\n## Log\n\n%s"
        lanes = '{\n  "socket": [\n    "test_a.gd"%s\n  ]\n}\n'
        with tempfile.TemporaryDirectory() as d:
            self.git(d, "init", "-q", "-b", "main")
            self.git(d, "config", "user.name", "t")
            self.git(d, "config", "user.email", "t@t")
            self.write(d, "tests/test_a.gd", "func test_a():\n\tpass\n")
            self.write(d, "docs/PROJECT_STATUS.md", status % (1, 1))
            self.write(d, "HANDOFF.md", handoff % "- base\n")
            self.write(d, "tests/test_lanes.json", lanes % "")
            self.git(d, "add", "-A")
            self.git(d, "commit", "-qm", "base")
            self.git(d, "checkout", "-qb", "feature")
            self.write(d, "tests/test_feature.gd", "func test_f1():\n\tpass\nfunc test_f2():\n\tpass\n")
            self.write(d, "docs/PROJECT_STATUS.md", status % (3, 2))
            self.write(d, "HANDOFF.md", handoff % "- feature entry\n\n- base\n")
            self.write(d, "tests/test_lanes.json", lanes % ',\n    "test_feature.gd"')
            self.git(d, "add", "-A")
            self.git(d, "commit", "-qm", "feature")
            self.git(d, "checkout", "-q", "main")
            self.write(d, "tests/test_main.gd", "func test_m():\n\tpass\n")
            self.write(d, "docs/PROJECT_STATUS.md", status % (2, 2))
            self.write(d, "HANDOFF.md", handoff % "- main entry\n\n- base\n")
            self.write(d, "tests/test_lanes.json", lanes % ',\n    "test_main.gd"')
            self.git(d, "add", "-A")
            self.git(d, "commit", "-qm", "main")
            self.git(d, "checkout", "-q", "feature")
            code = sync.main(["--root", d, "--base", "main", "--no-fetch", "--commit"])
            self.assertEqual(code, 0)
            with open(os.path.join(d, "HANDOFF.md")) as fh:
                log = fh.read()
            self.assertIn("- main entry", log)
            self.assertIn("- feature entry", log)
            self.assertFalse(sync.MARKER.search(log))
            with open(os.path.join(d, "docs/PROJECT_STATUS.md")) as fh:
                self.assertIn("4 methods in 3 test files", fh.read())  # a + main + f1 + f2
            with open(os.path.join(d, "tests/test_lanes.json")) as fh:
                self.assertEqual(json.load(fh)["socket"], ["test_a.gd", "test_feature.gd", "test_main.gd"])
            merges = subprocess.run(["git", "-C", d, "log", "--merges", "--oneline"], capture_output=True, text=True).stdout
            self.assertEqual(len(merges.splitlines()), 1)

    def test_a_conflict_in_another_file_stops_without_committing(self):
        with tempfile.TemporaryDirectory() as d:
            self.git(d, "init", "-q", "-b", "main")
            self.git(d, "config", "user.name", "t")
            self.git(d, "config", "user.email", "t@t")
            self.write(d, "code.gd", "a\n")
            self.git(d, "add", "-A")
            self.git(d, "commit", "-qm", "base")
            self.git(d, "checkout", "-qb", "feature")
            self.write(d, "code.gd", "feature\n")
            self.git(d, "commit", "-qam", "feature")
            self.git(d, "checkout", "-q", "main")
            self.write(d, "code.gd", "main\n")
            self.git(d, "commit", "-qam", "main")
            self.git(d, "checkout", "-q", "feature")
            self.assertEqual(sync.main(["--root", d, "--base", "main", "--no-fetch", "--commit"]), 2)
            merges = subprocess.run(["git", "-C", d, "log", "--merges", "--oneline"], capture_output=True, text=True).stdout
            self.assertEqual(merges.strip(), "")


if __name__ == "__main__":
    unittest.main()
