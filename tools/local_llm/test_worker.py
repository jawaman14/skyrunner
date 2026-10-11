"""Tests for tools/local_llm/worker.py: python tools/local_llm/test_worker.py (stdlib only; never contacts a server)."""
import io
import json
import os
import sys
import tempfile
import unittest
import urllib.error

sys.path.insert(0, os.path.dirname(__file__))
import worker  # noqa: E402

NL = chr(10)
TICKS = chr(96) * 3


def fenced(path, body):
    return "FILE: %s%s%s%s%s%s%s" % (path, NL, TICKS, "python", NL, body, TICKS)


class FakeResponse:
    def __init__(self, payload):
        self.payload = payload

    def __enter__(self):
        return io.BytesIO(json.dumps(self.payload).encode())

    def __exit__(self, *a):
        return False


class Pure(unittest.TestCase):
    def test_the_tier_comes_from_the_paths_not_from_the_model(self):
        self.assertEqual(worker.tier_of(["docs/X.md", "README.md"]), 0)
        self.assertEqual(worker.tier_of(["docs/X.md", "scripts/ui/hud.gd"]), 1)
        self.assertEqual(worker.tier_of(["tools/collab/notify.py"]), 1)
        self.assertEqual(worker.tier_of(["scripts/ui/hud.gd", "scripts/sim/session.gd"]), 2)
        self.assertEqual(worker.tier_of(["tests/fixtures/golden.json"]), 2)

    def test_first_draft_refuses_protected_and_unsafe_paths_and_too_many_files(self):
        self.assertIsNone(worker.check_paths(["tools/x.py", "tests/test_x.py"]))
        for bad in (".github/workflows/skyrunner-beta.yml", "project.godot", "HANDOFF.md", "tests/fixtures/a.json", "scripts/sim/switches.gd",
                    "tools/mcp/launch.py", "tools/local_llm/worker.py", "../outside.py", "/etc/passwd", "C:/x.py"):
            self.assertIsNotNone(worker.check_paths([bad]), bad)
        self.assertIsNotNone(worker.check_paths(["a", "b", "c", "d"]))
        self.assertIsNotNone(worker.check_paths([]))

    def test_only_named_files_with_a_fenced_block_are_taken_from_an_answer(self):
        answer = fenced("tools/x.py", "print(1)" + NL) + NL + NL + fenced("tools/other.py", "evil()" + NL) + NL + "FILE: tools/y.py" + NL + "no fence here"
        got = worker.parse_files(answer, {"tools/x.py", "tools/y.py"})
        self.assertEqual(got, {"tools/x.py": "print(1)" + NL})

    def test_clip_keeps_the_start_and_the_end_of_a_long_log(self):
        text = "START " + "x" * 5000 + " END"
        out = worker.clip(text, 200)
        self.assertTrue(out.startswith("START") and out.endswith("END") and "cut" in out and len(out) < 400)
        self.assertEqual(worker.clip("short", 200), "short")


class Client(unittest.TestCase):
    def setUp(self):
        os.environ["SKYRUNNER_LOCAL_LLM"] = "http://localhost:1"
        os.environ.pop("SKYRUNNER_LOCAL_LOG", None)

    def test_no_server_address_is_an_error_not_a_default(self):
        os.environ.pop("SKYRUNNER_LOCAL_LLM")
        with self.assertRaises(worker.LocalLLMError):
            worker.chat("hi")

    def test_a_completion_is_returned_and_logged(self):
        log = os.path.join(tempfile.mkdtemp(), "usage.jsonl")
        os.environ["SKYRUNNER_LOCAL_LOG"] = log
        seen = {}

        def opener(req, timeout):
            seen["url"] = req.full_url
            seen["body"] = json.loads(req.data)
            return FakeResponse({"choices": [{"message": {"content": " hello "}}], "usage": {"total_tokens": 7}})
        self.assertEqual(worker.chat("hi", system="s", opener=opener), "hello")
        self.assertTrue(seen["url"].endswith("/v1/chat/completions"))
        self.assertEqual(seen["body"]["messages"][0]["role"], "system")
        self.assertEqual(json.loads(open(log).read())["usage"]["total_tokens"], 7)

    def test_a_refusal_an_unreachable_server_and_an_empty_answer_are_errors(self):
        def refuses(req, timeout):
            raise urllib.error.HTTPError(req.full_url, 400, "bad", {}, io.BytesIO(b"Failed to load model: insufficient memory"))

        def down(req, timeout):
            raise urllib.error.URLError("unreachable")

        def empty(req, timeout):
            return FakeResponse({"choices": [{"message": {"content": "  "}}]})
        for opener in (refuses, down, empty):
            with self.assertRaises(worker.LocalLLMError):
                worker.chat("hi", opener=opener)


class Jobs(unittest.TestCase):
    def setUp(self):
        os.environ["SKYRUNNER_LOCAL_LLM"] = "http://localhost:1"

    def test_digest_sends_a_clipped_log_and_returns_the_answer(self):
        path = os.path.join(tempfile.mkdtemp(), "build.log")
        open(path, "w").write("error: x" + "y" * 50000)
        sent = []
        args = type("A", (), {"file": path, "pr": None})()
        out = worker.job_digest(args, ask=lambda prompt, **kw: sent.append(prompt) or "one failure")
        self.assertEqual(out, "one failure")
        self.assertLess(len(sent[0]), 26000)

    def test_draft_replies_drafts_only_for_unanswered_threads_and_never_posts(self):
        comments = [{"id": 1, "path": "a.py", "line": 3, "in_reply_to_id": None, "body": "fix this"},
                    {"id": 2, "path": "b.py", "line": 4, "in_reply_to_id": None, "body": "and this"},
                    {"id": 3, "path": "b.py", "line": 4, "in_reply_to_id": 2, "body": "done"}]
        calls = []
        real = worker.gh
        worker.gh = lambda args, run=None: calls.append(args) or json.dumps(comments)
        try:
            args = type("A", (), {"pr": 9})()
            text = worker.job_draft_replies(args, ask=lambda p, **kw: "ok [TODO: what was done]")
        finally:
            worker.gh = real
        self.assertIn("comment 1", text)
        self.assertNotIn("comment 2", text)
        self.assertIn("NOT posted", text)
        self.assertTrue(all(c[0] == "api" for c in calls), "it only reads")

    def test_first_draft_dry_run_writes_nothing_and_a_bad_answer_is_an_error(self):
        root = tempfile.mkdtemp()
        task = os.path.join(root, "task.md")
        open(task, "w").write("add a helper")
        args = type("A", (), {"paths": "tools/x.py", "root": root, "task": task, "slug": "x", "dry_run": True, "test": None})()
        out = worker.job_first_draft(args, ask=lambda p, **kw: fenced("tools/x.py", "print(1)" + NL))
        self.assertIn("dry run", out)
        self.assertFalse(os.path.exists(os.path.join(root, "tools", "x.py")))
        with self.assertRaises(worker.LocalLLMError):
            worker.job_first_draft(args, ask=lambda p, **kw: "I cannot do that")
        args.paths = "HANDOFF.md"
        with self.assertRaises(worker.LocalLLMError):
            worker.job_first_draft(args, ask=lambda p, **kw: "x")


if __name__ == "__main__":
    unittest.main()
