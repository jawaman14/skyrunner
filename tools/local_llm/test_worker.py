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


MODELS = {"models": [
    {"type": "llm", "key": "big/model", "loaded_instances": [{"id": "big/model"}]},
    {"type": "llm", "key": "other/model", "loaded_instances": []},
    {"type": "embedding", "key": "embed", "loaded_instances": [{"id": "embed"}]},
]}


class Server:
    """A fake LM Studio: records every request so a test can prove nothing was loaded or unloaded."""

    def __init__(self, models=MODELS, answer=None, chat_error=None):
        self.models, self.requests = models, []
        self.answer = answer or {"output": [{"type": "message", "content": " hello "}], "stats": {"total_output_tokens": 2, "reasoning_output_tokens": 0}}
        self.chat_error = chat_error

    def __call__(self, req, timeout):
        path = req.full_url.split(":1", 1)[1] if ":1" in req.full_url else req.full_url
        self.requests.append((req.get_method(), path, json.loads(req.data) if req.data else None))
        if path.endswith("/api/v1/models"):
            return FakeResponse(self.models)
        if self.chat_error:
            raise self.chat_error
        return FakeResponse(self.answer)


class Client(unittest.TestCase):
    def setUp(self):
        os.environ["SKYRUNNER_LOCAL_LLM"] = "http://localhost:1"
        for k in ("SKYRUNNER_LOCAL_LOG", "SKYRUNNER_LOCAL_MODEL"):
            os.environ.pop(k, None)
        os.environ["SKYRUNNER_LOCAL_PAUSE"] = "0"
        os.environ["SKYRUNNER_LOCAL_LOCK"] = os.path.join(tempfile.mkdtemp(), "lock")

    def test_no_server_address_is_an_error_not_a_default(self):
        os.environ.pop("SKYRUNNER_LOCAL_LLM")
        with self.assertRaises(worker.LocalLLMError):
            worker.chat("hi")

    def test_only_loaded_language_models_count_and_the_single_loaded_one_is_used(self):
        server = Server()
        self.assertEqual(worker.loaded_models(server), ["big/model"])
        self.assertEqual(worker.chat("hi", system="s", opener=server), "hello")
        chats = [r for r in server.requests if r[1].endswith("/api/v1/chat")]
        self.assertEqual(len(chats), 1)
        self.assertEqual(chats[0][2]["model"], "big/model")
        self.assertEqual(chats[0][2]["reasoning"], "off", "reasoning is off unless asked for")
        self.assertEqual(chats[0][2]["system_prompt"], "s")
        self.assertFalse(chats[0][2]["store"])

    def test_it_never_asks_for_a_model_that_is_not_loaded_and_never_loads_one(self):
        server = Server()
        os.environ["SKYRUNNER_LOCAL_MODEL"] = "other/model"
        with self.assertRaises(worker.LocalLLMError) as cm:
            worker.chat("hi", opener=server)
        self.assertIn("never loads", str(cm.exception))
        self.assertEqual([r[1] for r in server.requests if r[0] == "POST"], [], "no chat request was sent for the unloaded model")
        for method, path, _ in server.requests:
            self.assertNotIn("load", path.replace("loaded", ""), "no load or unload endpoint is ever called")
        os.environ.pop("SKYRUNNER_LOCAL_MODEL")
        with self.assertRaises(worker.LocalLLMError):
            worker.chat("hi", opener=Server(models={"models": [{"type": "llm", "key": "x", "loaded_instances": []}]}))
        two = {"models": [{"type": "llm", "key": "a", "loaded_instances": [1]}, {"type": "llm", "key": "b", "loaded_instances": [1]}]}
        with self.assertRaises(worker.LocalLLMError):
            worker.chat("hi", opener=Server(models=two))

    def test_a_model_loaded_twice_has_two_instance_ids_and_the_job_names_the_one_it_may_use(self):
        two = {"models": [{"type": "llm", "key": "prism-ml/bonsai-27b", "loaded_instances": [{"id": "prism-ml/bonsai-27b"}, {"id": "prism-ml/bonsai-27b:2"}]}]}
        server = Server(models=two)
        self.assertEqual(worker.loaded_models(server), ["prism-ml/bonsai-27b", "prism-ml/bonsai-27b:2"])
        with self.assertRaises(worker.LocalLLMError):
            worker.chat("hi", opener=server)
        os.environ["SKYRUNNER_LOCAL_MODEL"] = "prism-ml/bonsai-27b:2"
        self.assertEqual(worker.chat("hi", opener=server), "hello")
        sent = [r for r in server.requests if r[1].endswith("/chat")][0][2]
        self.assertEqual(sent["model"], "prism-ml/bonsai-27b:2")
        os.environ["SKYRUNNER_LOCAL_MODEL"] = "prism-ml/bonsai-27b:3"
        with self.assertRaises(worker.LocalLLMError):
            worker.chat("hi", opener=server)

    def test_thinking_is_a_choice_and_a_log_line_is_written(self):
        log = os.path.join(tempfile.mkdtemp(), "usage.jsonl")
        os.environ["SKYRUNNER_LOCAL_LOG"] = log
        server = Server()
        worker.chat("hi", think=True, opener=server)
        self.assertEqual([r[2]["reasoning"] for r in server.requests if r[1].endswith("/chat")], ["on"])
        self.assertEqual(json.loads(open(log).read())["stats"]["total_output_tokens"], 2)

    def test_a_refusal_an_unreachable_server_and_an_empty_answer_are_errors(self):
        refuses = Server(chat_error=urllib.error.HTTPError("u", 400, "bad", {}, io.BytesIO(b"insufficient memory")))
        down = Server(chat_error=urllib.error.URLError("unreachable"))
        empty = Server(answer={"output": [{"type": "message", "content": "  "}], "stats": {}})
        for server in (refuses, down, empty):
            with self.assertRaises(worker.LocalLLMError):
                worker.chat("hi", opener=server)

    def test_a_thinking_run_that_uses_its_whole_budget_says_so(self):
        server = Server(answer={"output": [], "stats": {"reasoning_output_tokens": 300}})
        with self.assertRaises(worker.LocalLLMError) as cm:
            worker.chat("hi", max_tokens=300, think=True, opener=server)
        self.assertIn("raise max_tokens", str(cm.exception))

    def test_a_second_job_waits_its_turn_instead_of_running_beside_the_first(self):
        held = worker._wait_turn(5)
        try:
            with self.assertRaises(worker.LocalLLMError):
                worker._wait_turn(0)
        finally:
            held.close()
        worker._wait_turn(5).close()


class Budget(unittest.TestCase):
    def setUp(self):
        os.environ["SKYRUNNER_LOCAL_LLM"] = "http://localhost:1"
        os.environ.pop("SKYRUNNER_LOCAL_MAX_CHARS", None)

    def models(self, context):
        return Server(models={"models": [{"type": "llm", "key": "m", "loaded_instances": [{"config": {"context_length": context}}]}]})

    def test_the_input_budget_follows_the_loaded_context_and_is_capped(self):
        self.assertEqual(worker.input_budget(self.models(16384)), 32768)
        self.assertEqual(worker.input_budget(self.models(262144)), worker.MAX_INPUT_CHARS, "a long prompt is slow, so there is a cap")
        self.assertGreater(worker.input_budget(self.models(262144)), 100_000, "whole diffs fit")

    def test_an_unknown_context_or_an_unreachable_server_gives_the_small_default_and_the_environment_overrides(self):
        self.assertEqual(worker.input_budget(Server(models={"models": []})), worker.DEFAULT_INPUT_CHARS)

        def down(req, timeout):
            raise urllib.error.URLError("unreachable")
        self.assertEqual(worker.input_budget(down), worker.DEFAULT_INPUT_CHARS)
        os.environ["SKYRUNNER_LOCAL_MAX_CHARS"] = "5000"
        self.assertEqual(worker.input_budget(self.models(262144)), 5000)
        os.environ["SKYRUNNER_LOCAL_MAX_CHARS"] = "99999999"
        self.assertEqual(worker.input_budget(self.models(262144)), worker.MAX_INPUT_CHARS)
        os.environ.pop("SKYRUNNER_LOCAL_MAX_CHARS")


class Jobs(unittest.TestCase):
    def setUp(self):
        os.environ["SKYRUNNER_LOCAL_LLM"] = "http://localhost:1"

    def test_digest_sends_a_clipped_log_and_returns_the_answer(self):
        path = os.path.join(tempfile.mkdtemp(), "build.log")
        open(path, "w").write("error: x" + "y" * 50000)
        sent = []
        args = type("A", (), {"file": path})()
        out = worker.job_digest(args, ask=lambda prompt, **kw: sent.append(prompt) or "one failure")
        self.assertEqual(out, "one failure")
        self.assertLess(len(sent[0]), 26000)

    def test_the_worker_never_calls_gh(self):
        source = open(worker.__file__, encoding="utf-8").read()
        for forbidden in ('"gh"', "'gh'", "def gh(", "gh(["):
            self.assertNotIn(forbidden, source)

    def test_first_draft_dry_run_writes_nothing_and_a_bad_answer_is_an_error(self):
        root = tempfile.mkdtemp()
        task = os.path.join(root, "task.md")
        open(task, "w").write("add a helper")
        args = type("A", (), {"paths": "tools/x.py", "root": root, "task": task, "slug": "x", "dry_run": True, "test": None, "think": False})()
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
