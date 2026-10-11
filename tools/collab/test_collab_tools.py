"""Tests for tools/collab: python tools/collab/test_collab_tools.py (stdlib only; needs git on PATH)."""
import json
import os
import sqlite3
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(__file__))
import board_status  # noqa: E402
import notify  # noqa: E402
import post_review  # noqa: E402
import relay_reviews  # noqa: E402
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


class PostReview(unittest.TestCase):
    HEAD = "c" * 40
    SERVER_RE = __import__("re").compile(r"<!-- skyrunner-review agent=(claude|codex) verdict=(approve|changes|comment) head=([0-9a-f]{40}) -->")

    def info(self, branch="claude/x", head=None):
        return {"headRefOid": head or self.HEAD, "headRefName": branch, "isDraft": False}

    def test_the_marker_is_the_one_the_servers_queue_parses(self):
        for agent in post_review.AGENTS:
            for verdict in post_review.VERDICTS:
                m = self.SERVER_RE.search(post_review.marker(agent, verdict, self.HEAD))
                self.assertEqual(m.groups(), (agent, verdict, self.HEAD))

    def test_it_refuses_what_the_tool_refuses(self):
        ok = post_review.check(self.info("claude/x"), "codex", "approve", self.HEAD, "read the diff, ran the tests")
        self.assertIsNone(ok)
        self.assertIn("own work", post_review.check(self.info("codex/x"), "codex", "approve", self.HEAD, "fine"))
        self.assertIn("review the current head", post_review.check(self.info(head="d" * 40), "codex", "approve", self.HEAD, "fine"))
        self.assertIn("empty review", post_review.check(self.info(), "codex", "approve", self.HEAD, "  "))
        self.assertIn("40-character", post_review.check(self.info(), "codex", "approve", "abc123", "fine"))
        self.assertIn("verdict", post_review.check(self.info(), "codex", "merge", self.HEAD, "fine"))

    def test_author_agent_reads_the_branch_prefix(self):
        self.assertEqual([post_review.author_agent(b) for b in ("claude/a", "codex/b", "codexfix/c", "feature/d", "")], ["claude", "codex", "", "", ""])

    def test_it_posts_one_marked_review_pinned_to_the_head_without_a_shell(self):
        calls = []

        def fake(cmd, **kw):
            calls.append((cmd, kw))
            out = json.dumps(self.info("claude/x")) if cmd[1] == "pr" else "https://github.com/o/r/pull/9#pullrequestreview-1"
            return subprocess.CompletedProcess(cmd, 0, out, "")
        code = post_review.main(["--pr", "9", "--head", self.HEAD, "--verdict", "changes", "--agent", "codex", "--body", "the lock races"], run=fake)
        self.assertEqual(code, 0)
        self.assertEqual(len(calls), 2)
        post = calls[1][0]
        self.assertEqual(post[:2], ["gh", "api"])
        self.assertIn("commit_id=" + self.HEAD, post)
        body = [x for x in post if x.startswith("body=")][0]
        self.assertTrue(self.SERVER_RE.search(body), "the queue can read it")
        self.assertIn("the lock races", body)
        for _, kw in calls:
            self.assertNotIn("shell", kw)

    def test_a_refused_review_posts_nothing(self):
        calls = []

        def fake(cmd, **kw):
            calls.append(cmd)
            return subprocess.CompletedProcess(cmd, 0, json.dumps(self.info("codex/x")), "")
        code = post_review.main(["--pr", "9", "--head", self.HEAD, "--verdict", "approve", "--agent", "codex", "--body", "ok"], run=fake)
        self.assertEqual(code, 2)
        self.assertEqual(len(calls), 1, "only the read happened")


class RelayReviews(unittest.TestCase):
    HEAD = "c" * 40

    def info(self, branch="claude/x", head=None, state="OPEN"):
        return {"headRefOid": head or self.HEAD, "headRefName": branch, "state": state}

    def test_only_the_exact_form_parses(self):
        ok = relay_reviews.parse("REVIEW #331@9f3e0d1 approve: read all changes")
        self.assertEqual((ok["pr"], ok["sha"], ok["verdict"], ok["text"]), (331, "9f3e0d1", "approve", "read all changes"))
        for bad in ("review #1@9f3e0d1 approve: x", "REVIEW #1@zzzzzzz approve: x", "REVIEW #1@9f3e0d approve: x", "REVIEW #1@9f3e0d1 merge: x",
                    "REVIEW #1@9f3e0d1 approve:", "REVIEW 1@9f3e0d1 approve: x", "please REVIEW #1@9f3e0d1 approve: x", "REVIEW #1@9f3e0d1 approve: " + "x" * 3001):
            self.assertIsNone(relay_reviews.parse(bad), bad)

    def test_a_current_head_review_is_relayed_verbatim_with_a_label_and_no_added_finding(self):
        review, why = relay_reviews.decide(212, "REVIEW #7@cccccccc changes: the lock races", self.info())
        self.assertIsNone(why)
        self.assertEqual((review["pr"], review["head"], review["verdict"]), (7, self.HEAD, "changes"))
        self.assertIn("RELAYED by Claude from Codex's board note #212", review["body"])
        self.assertIn("> the lock races", review["body"])
        self.assertIn("no finding of its own", review["body"])

    def test_stale_closed_own_and_malformed_reviews_are_refused(self):
        stale, why = relay_reviews.decide(1, "REVIEW #7@aaaaaaa approve: ok", self.info())
        self.assertIn("stale", why)
        self.assertIn("not open", relay_reviews.decide(1, "REVIEW #7@ccccccc approve: ok", self.info(state="MERGED"))[1])
        self.assertIn("own work", relay_reviews.decide(1, "REVIEW #7@ccccccc approve: ok", self.info(branch="codex/x"))[1])
        self.assertIn("form", relay_reviews.decide(1, "looks fine", self.info())[1])

    def board(self):
        db = sqlite3.connect(":memory:")
        db.execute("CREATE TABLE notes (id INTEGER PRIMARY KEY, author TEXT, recipient TEXT, text TEXT, created REAL)")
        return db

    def add(self, db, author, recipient, text):
        db.execute("INSERT INTO notes (author, recipient, text, created) VALUES (?,?,?,0)", (author, recipient, text))

    def test_it_relays_new_codex_notes_once_posts_only_to_the_named_pr_and_skips_history_and_other_authors(self):
        db = self.board()
        self.add(db, "codex-old", "claude", "REVIEW #7@ccccccc approve: old history")
        state = os.path.join(tempfile.mkdtemp(), "state.json")
        calls = []

        def fake(cmd, **kw):
            calls.append(cmd)
            out = json.dumps(self.info()) if cmd[1] == "pr" else "https://github.com/o/r/pull/7#pullrequestreview-9"
            return subprocess.CompletedProcess(cmd, 0, out, "")
        lines = []
        self.assertEqual(relay_reviews.run_once(db, state, run=fake, out=lines.append), [], "history at the first run is never relayed")
        self.add(db, "claude-x", "claude", "REVIEW #7@ccccccc approve: not from codex")
        self.add(db, "codex-new", "claude", "REVIEW #7@ccccccc approve: fine")
        self.add(db, "codex-new", "codex", "REVIEW #7@ccccccc approve: not addressed to claude")
        self.assertEqual(relay_reviews.run_once(db, state, run=fake, out=lines.append), [3])
        posts = [c for c in calls if c[1] == "api"]
        self.assertEqual(len(posts), 1)
        self.assertIn("repos/{owner}/{repo}/pulls/7/reviews", posts[0][2])
        self.assertTrue(any(x.startswith("body=<!-- skyrunner-review agent=codex verdict=approve head=" + self.HEAD) for x in posts[0]))
        self.assertEqual(relay_reviews.run_once(db, state, run=fake, out=lines.append), [], "a note is relayed once")

    def test_dry_run_posts_nothing_and_a_malformed_note_is_reported_not_relayed(self):
        db = self.board()
        state = os.path.join(tempfile.mkdtemp(), "state.json")
        relay_reviews.run_once(db, state, run=lambda *a, **k: None, out=lambda x: None)
        self.add(db, "codex-new", "claude", "REVIEW #7@ccccccc approve: fine")
        self.add(db, "codex-new", "claude", "REVIEW but not in form")
        lines = []

        def fake(cmd, **kw):
            assert cmd[1] != "api", "a dry run must not post"
            return subprocess.CompletedProcess(cmd, 0, json.dumps(self.info()), "")
        relay_reviews.run_once(db, state, dry_run=True, run=fake, out=lines.append)
        self.assertTrue(any("dry run" in x for x in lines))
        self.assertTrue(any("not in the REVIEW form" in x for x in lines))


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
