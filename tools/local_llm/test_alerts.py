"""Tests for tools/local_llm/alerts.py: python tools/local_llm/test_alerts.py (stdlib only; no network, no server)."""
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(__file__))
import alerts  # noqa: E402
import worker  # noqa: E402

H = "a" * 40
H2 = "b" * 40


def pr(n, branch, head=H, draft=False, ci="ok", mergeable="MERGEABLE", reviews=(), title="Thing"):
    checks = {"ok": [{"status": "COMPLETED", "conclusion": "SUCCESS", "name": "t"}],
              "fail": [{"status": "COMPLETED", "conclusion": "FAILURE", "name": "test 1/3"}],
              "run": [{"status": "IN_PROGRESS", "conclusion": "", "name": "t"}], "none": []}[ci]
    return {"number": n, "title": title, "headRefName": branch, "headRefOid": head, "isDraft": draft, "mergeable": mergeable,
            "statusCheckRollup": checks, "reviews": list(reviews), "state": "OPEN"}


def review(agent, verdict, head):
    return {"body": "<!-- skyrunner-review agent=%s verdict=%s head=%s -->\nbody" % (agent, verdict, head)}


class Events(unittest.TestCase):
    def kinds(self, prs, me, **kw):
        return [(e[2], e[3]) for e in alerts.events(prs, me, **kw)]

    def test_a_review_is_needed_only_for_the_other_agents_ready_pr_without_a_current_review_from_me(self):
        ready = pr(1, "claude/x")
        self.assertEqual(self.kinds([ready], "codex"), [("review", 1)])
        self.assertEqual(self.kinds([pr(2, "claude/x", draft=True)], "codex"), [], "a draft is not ready")
        self.assertEqual(self.kinds([pr(3, "claude/x", ci="fail")], "codex"), [], "CI must be green first")
        self.assertEqual(self.kinds([pr(4, "claude/x", ci="run")], "codex"), [])
        self.assertEqual(self.kinds([pr(5, "claude/x", mergeable="CONFLICTING")], "codex"), [])
        self.assertEqual(self.kinds([pr(6, "claude/x", reviews=[review("codex", "approve", H)])], "codex"), [], "already reviewed this head")
        self.assertEqual(self.kinds([pr(7, "claude/x", reviews=[review("codex", "approve", H2)])], "codex"), [("review", 7)], "a review of an older head does not count")
        self.assertEqual(self.kinds([pr(8, "claude/x", reviews=[review("codex", "comment", H)])], "codex"), [("review", 8)], "a plain comment is not a verdict")
        self.assertEqual(self.kinds([pr(9, "codex/x")], "codex"), [], "my own PR needs no review from me")

    def test_my_own_pr_alerts_for_ci_failure_conflicts_and_waiting_threads(self):
        mine = [pr(10, "codex/a", ci="fail"), pr(11, "codex/b", mergeable="CONFLICTING"), pr(12, "codex/c")]
        waiting = {12: [{"id": 5, "path": "a", "line": 1, "body": "x"}, {"id": 6, "path": "b", "line": 2, "body": "y"}]}
        got = self.kinds(mine, "codex", waiting=waiting)
        self.assertIn(("ci", 10), got)
        self.assertIn(("sync", 11), got)
        self.assertIn(("threads", 12), got)
        text = [e[1] for e in alerts.events(mine, "codex", waiting=waiting)]
        self.assertTrue(any("test 1/3" in t for t in text), "the failing check is named")
        self.assertTrue(any("2 REVIEW THREAD" in t for t in text))

    def test_an_alert_is_sent_once_per_change_and_again_when_the_head_moves(self):
        seen = {}
        found = alerts.events([pr(1, "claude/x")], "codex")
        self.assertEqual(len(alerts.new_events(found, seen)), 1)
        self.assertEqual(alerts.new_events(found, seen), [], "the same need is not repeated")
        moved = alerts.events([pr(1, "claude/x", head=H2)], "codex")
        self.assertEqual(len(alerts.new_events(moved, seen)), 1, "a new head is a new alert")

    def test_legacy_status_contexts_count(self):
        legacy = pr(1, "codex/x", ci="ok")
        legacy["statusCheckRollup"] = [{"context": "ci/old", "state": "FAILURE"}]
        self.assertEqual(alerts.ci_state(legacy), ("fail", ["ci/old"]))
        legacy["statusCheckRollup"] = [{"context": "ci/old", "state": "PENDING"}]
        self.assertEqual(alerts.ci_state(legacy)[0], "run")


class Runs(unittest.TestCase):
    def setUp(self):
        d = tempfile.mkdtemp()
        self.out, self.state = os.path.join(d, "alerts.md"), os.path.join(d, "state.json")

    def gatherer(self, prs, waiting=None, merged=()):
        return lambda me: (prs, waiting or {}, list(merged))

    def test_the_first_run_writes_a_digest_marked_as_data_and_a_second_run_stays_silent(self):
        g = self.gatherer([pr(1, "claude/x", title="Add a tool")])
        sent = alerts.run_once("codex", self.out, self.state, False, gather_fn=g)
        self.assertEqual(len(sent), 1)
        text = open(self.out, encoding="utf-8").read()
        self.assertIn("REVIEW NEEDED #1@aaaaaaa Add a tool", text)
        self.assertIn("DATA", text)
        os.remove(self.out)
        self.assertEqual(alerts.run_once("codex", self.out, self.state, False, gather_fn=g), [])
        self.assertFalse(os.path.exists(self.out), "nothing new, so the file is not rewritten and the wake is not triggered")

    def test_a_merge_after_the_first_look_is_announced_but_the_backlog_is_not(self):
        alerts.run_once("codex", self.out, self.state, False, gather_fn=self.gatherer([], merged=[5, 6]))
        self.assertFalse(os.path.exists(self.out), "old merges at the first look are not news")
        sent = alerts.run_once("codex", self.out, self.state, False, gather_fn=self.gatherer([], merged=[5, 6, 7]))
        self.assertEqual(sent, ["MERGED #7"])

    def test_the_model_adds_neutral_lines_to_thread_alerts_and_its_failure_loses_nothing(self):
        waiting = {12: [{"id": 5, "path": "a.py", "line": 3, "body": "fix this"}]}
        g = self.gatherer([pr(12, "codex/c")], waiting)
        sent = alerts.run_once("codex", self.out, self.state, True, gather_fn=g, ask=lambda p, **kw: "ASK: x CHECK: y")
        text = open(self.out, encoding="utf-8").read()
        self.assertIn("1 REVIEW THREAD(S) waiting on your #12", text)
        self.assertIn("a.py:3 ASK: x CHECK: y", text)

        def broken(p, **kw):
            raise worker.LocalLLMError("model unloaded")
        os.remove(self.state)
        os.remove(self.out)
        sent = alerts.run_once("codex", self.out, self.state, True, gather_fn=g, ask=broken)
        self.assertEqual(len(sent), 1, "the alert still goes out")
        self.assertNotIn("ASK:", open(self.out, encoding="utf-8").read())

    def test_the_digest_is_replaced_atomically(self):
        alerts.write_digest(self.out, "claude", ["- one"])
        alerts.write_digest(self.out, "claude", ["- two"])
        text = open(self.out, encoding="utf-8").read()
        self.assertIn("- two", text)
        self.assertNotIn("- one", text)
        self.assertEqual([f for f in os.listdir(os.path.dirname(self.out)) if f.endswith(".tmp")], [])


if __name__ == "__main__":
    unittest.main()
