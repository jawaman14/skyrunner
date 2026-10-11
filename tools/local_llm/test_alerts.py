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


def pr(n, branch, head=H, draft=False, ci="success", conflicts=False, reviews=(), title="Thing", bad=()):
    return {"number": n, "title": title, "branch": branch, "head": head, "draft": draft, "conflicts": conflicts, "behind": 0, "ci": ci,
            "ci_bad": list(bad), "reviews": list(reviews), "waiting": []}


def review(agent, verdict, head):
    return {"agent": agent, "verdict": verdict, "head": head}


class FakeMcp:
    def __init__(self, states=None, packet="PACKET"):
        self.states, self.packet, self.calls = states or {"open": [], "merged": []}, packet, []

    def call(self, tool, **arguments):
        self.calls.append((tool, arguments))
        return json.dumps(self.states) if tool == "github_pr_states" else self.packet


class Events(unittest.TestCase):
    def kinds(self, prs, me, **kw):
        return [(e[2], e[3]) for e in alerts.events(prs, me, **kw)]

    def test_a_review_is_needed_only_for_the_other_agents_ready_pr_without_a_current_review_from_me(self):
        ready = pr(1, "claude/x")
        self.assertEqual(self.kinds([ready], "codex"), [("review", 1)])
        self.assertEqual(self.kinds([pr(2, "claude/x", draft=True)], "codex"), [], "a draft is not ready")
        self.assertEqual(self.kinds([pr(3, "claude/x", ci="failure")], "codex"), [], "CI must be green first")
        self.assertEqual(self.kinds([pr(4, "claude/x", ci="pending")], "codex"), [])
        self.assertEqual(self.kinds([pr(5, "claude/x", conflicts=True)], "codex"), [])
        self.assertEqual(self.kinds([pr(6, "claude/x", reviews=[review("codex", "approve", H)])], "codex"), [], "already reviewed this head")
        self.assertEqual(self.kinds([pr(7, "claude/x", reviews=[review("codex", "approve", H2)])], "codex"), [("review", 7)], "a review of an older head does not count")
        self.assertEqual(self.kinds([pr(8, "claude/x", reviews=[review("codex", "comment", H)])], "codex"), [("review", 8)], "a plain comment is not a verdict")
        self.assertEqual(self.kinds([pr(9, "codex/x")], "codex"), [], "my own PR needs no review from me")

    def test_my_own_pr_alerts_for_ci_failure_conflicts_and_waiting_threads(self):
        mine = [pr(10, "codex/a", ci="failure", bad=["test 1/3"]), pr(11, "codex/b", conflicts=True), pr(12, "codex/c")]
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
        self.assertEqual(len(alerts.new_events(found, seen, 100.0)), 1)
        self.assertEqual(alerts.new_events(found, seen, 200.0), [], "the same need is not repeated")
        moved = alerts.events([pr(1, "claude/x", head=H2)], "codex")
        self.assertEqual(len(alerts.new_events(moved, seen, 300.0)), 1, "a new head is a new alert")

    def test_a_need_that_still_stands_is_repeated_after_the_reminder_interval_only(self):
        seen = {}
        found = alerts.events([pr(1, "claude/x")], "codex")
        alerts.new_events(found, seen, 0.0, remind=1800.0)
        self.assertEqual(alerts.new_events(found, seen, 1000.0, remind=1800.0), [])
        self.assertEqual(len(alerts.new_events(found, seen, 1900.0, remind=1800.0)), 1, "a reminder")
        self.assertEqual(alerts.new_events(found, seen, 2000.0, remind=1800.0), [], "and not again at once")


class Runs(unittest.TestCase):
    def setUp(self):
        d = tempfile.mkdtemp()
        self.out, self.state = os.path.join(d, "alerts.md"), os.path.join(d, "state.json")

    def gatherer(self, prs, waiting=None, merged=()):
        return lambda me: (prs, waiting or {}, list(merged))

    def test_the_first_run_writes_a_digest_marked_as_data_and_a_second_run_stays_silent(self):
        g = self.gatherer([pr(1, "claude/x", title="Add a tool")])
        sent = alerts.run_once("codex", self.out, self.state, False, gather_fn=g, min_gap=0)
        self.assertEqual(len(sent), 1)
        text = open(self.out, encoding="utf-8").read()
        self.assertIn("REVIEW NEEDED #1@aaaaaaa head=" + H + " branch=claude/x Add a tool", text, "the full head and branch, for a turn with no network")
        self.assertIn("REVIEW #<pr>@<sha7>", text, "the digest says how to give the verdict")
        self.assertIn("DATA", text)
        os.remove(self.out)
        self.assertEqual(alerts.run_once("codex", self.out, self.state, False, gather_fn=g, min_gap=0), [])
        self.assertFalse(os.path.exists(self.out), "nothing new, so the file is not rewritten and the wake is not triggered")

    def test_a_merge_after_the_first_look_is_announced_but_the_backlog_is_not(self):
        alerts.run_once("codex", self.out, self.state, False, gather_fn=self.gatherer([], merged=[5, 6]), min_gap=0)
        self.assertFalse(os.path.exists(self.out), "old merges at the first look are not news")
        sent = alerts.run_once("codex", self.out, self.state, False, gather_fn=self.gatherer([], merged=[5, 6, 7]), min_gap=0)
        self.assertEqual(sent, ["MERGED #7"])

    def test_the_model_adds_neutral_lines_to_thread_alerts_and_its_failure_loses_nothing(self):
        waiting = {12: [{"id": 5, "path": "a.py", "line": 3, "body": "fix this"}]}
        g = self.gatherer([pr(12, "codex/c")], waiting)
        sent = alerts.run_once("codex", self.out, self.state, True, gather_fn=g, min_gap=0, ask=lambda p, **kw: "ASK: x CHECK: y")
        text = open(self.out, encoding="utf-8").read()
        self.assertIn("1 REVIEW THREAD(S) waiting on your #12", text)
        self.assertIn("a.py:3 ASK: x CHECK: y", text)

        def broken(p, **kw):
            raise worker.LocalLLMError("model unloaded")
        os.remove(self.state)
        os.remove(self.out)
        sent = alerts.run_once("codex", self.out, self.state, True, gather_fn=g, min_gap=0, ask=broken)
        self.assertEqual(len(sent), 1, "the alert still goes out")
        self.assertNotIn("ASK:", open(self.out, encoding="utf-8").read())

    def test_digests_are_spaced_by_the_minimum_gap_and_pending_items_wait(self):
        two = self.gatherer([pr(1, "claude/x"), pr(2, "claude/y")])
        bundles = lambda n, head, branch, title: "bundle-%d.md" % n
        sent = alerts.run_once("codex", self.out, self.state, False, gather_fn=self.gatherer([pr(1, "claude/x")]), now=10_000.0, min_gap=600.0, bundle_fn=bundles)
        self.assertEqual(len(sent), 1)
        self.assertIn("bundle=bundle-1.md", open(self.out, encoding="utf-8").read())
        os.remove(self.out)
        self.assertEqual(alerts.run_once("codex", self.out, self.state, False, gather_fn=two, now=10_100.0, min_gap=600.0, bundle_fn=bundles), [], "inside the gap: held")
        self.assertFalse(os.path.exists(self.out))
        sent = alerts.run_once("codex", self.out, self.state, False, gather_fn=two, now=10_700.0, min_gap=600.0, bundle_fn=bundles)
        self.assertEqual(len(sent), 1, "after the gap the held item goes")
        self.assertIn("#2@", sent[0])
        # a held item whose need went away is dropped
        os.remove(self.out)
        alerts.run_once("codex", self.out, self.state, False, gather_fn=self.gatherer([pr(3, "claude/z")]), now=10_800.0, min_gap=600.0, bundle_fn=bundles)
        gone = self.gatherer([pr(3, "claude/z", draft=True)])
        self.assertEqual(alerts.run_once("codex", self.out, self.state, False, gather_fn=gone, now=20_000.0, min_gap=600.0, bundle_fn=bundles), [])

    def test_gather_reads_everything_from_one_github_pr_states_call_and_waiting_only_for_my_prs(self):
        mine, theirs = pr(1, "codex/a"), pr(2, "claude/b")
        mine["waiting"] = [{"id": 5, "path": "a", "line": 1, "body": "x"}]
        theirs["waiting"] = [{"id": 6, "path": "b", "line": 1, "body": "y"}]
        mcp = FakeMcp({"open": [mine, theirs], "merged": [7]})
        rows, waiting, merged = alerts.gather("codex", mcp)
        self.assertEqual((len(rows), list(waiting), merged), (2, [1], [7]))
        self.assertEqual([c[0] for c in mcp.calls], ["github_pr_states"])

    def test_the_review_bundle_wraps_the_mcp_packet_under_the_full_head_and_reads_only(self):
        mcp = FakeMcp(packet="## Files - a.gd (cut)")
        path = alerts.review_bundle(9, H, "claude/x", "A title", mcp, folder=tempfile.mkdtemp())
        text = open(path, encoding="utf-8").read()
        self.assertIn("Head (full): " + H, text)
        self.assertIn("(cut)", text)
        self.assertEqual([c[0] for c in mcp.calls], ["github_review_packet"])
        source = open(alerts.__file__, encoding="utf-8").read()
        for forbidden in ("subprocess", '"gh"', "'gh'"):
            self.assertNotIn(forbidden, source)

    def test_the_digest_is_replaced_atomically(self):
        alerts.write_digest(self.out, "claude", ["- one"])
        alerts.write_digest(self.out, "claude", ["- two"])
        text = open(self.out, encoding="utf-8").read()
        self.assertIn("- two", text)
        self.assertNotIn("- one", text)
        self.assertEqual([f for f in os.listdir(os.path.dirname(self.out)) if f.endswith(".tmp")], [])


if __name__ == "__main__":
    unittest.main()
