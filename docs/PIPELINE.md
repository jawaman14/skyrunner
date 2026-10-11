# The pipeline, end to end: issue to main, who does what, and where it stalled

Written 11 October 2026 after the owner asked for the whole path to be audited. The owner's contract: the agents run
everything; the owner is involved only when something lands on `main` (a short note of what was done) and for the things only a
person can do (the human release gates and the decisions in #326). This file is the map; `AGENTS.md` keeps the rules.

## The path, with an owner and a limit for every step

| # | Step | Who | Tool | Should take | What stalled it today |
|---|---|---|---|---|---|
| 1 | Issue to a queue | Claude triages | `#326` owner, `#327` index, `#328` Claude, `#329` Codex | minutes | issues had no owner or assignee: nothing was delegated |
| 2 | Claim and branch | the author | `skyrunner_collaboration_claim`, own worktree | minutes | none |
| 3 | Change plus tests (tests first for the simulation) | the author | MCP test tools, `run_locked.py` | the task | a test that could start a real Codex (fixed) |
| 4 | Sync `main` into the branch | the author | `sync_shared.py` (`--baton theirs` for a PR that is not the holder) | minutes | 12 branches 39 commits behind: every PR collides on HANDOFF, the status count and the lanes |
| 5 | CI | automatic | `github_pr_wait` | about 10 minutes | none |
| 6 | Bot review (arrives minutes after CI) | automatic | `review_packet.py` shows unanswered threads | minutes | threads left unanswered blocked merges; several valid P1/P2 findings went unseen until the packet existed |
| 7 | Other-agent review of the exact head | the reviewer | `github_pr_review` | one wake | **the main stall:** Codex's desktop session acts only when the owner prompts it, and a woken turn cannot call the review tool (approval policy never) |
| 8 | Merge | the integrator (Claude) | `github_pr_merge` (needs green CI on the head and every thread replied) | seconds | waiting on step 7 |
| 9 | Notes for the owner | the integrator | one comment on #326 per merge, a summary at the end | seconds | did not exist |

## Roles, including the ones that were missing

- **Author:** claims, builds, syncs, answers every review thread in-thread, keeps the PR current. (Existing.)
- **Reviewer (the other agent):** reviews the exact head; replies in the PR. (Existing; the bottleneck.)
- **Integrator:** merges one PR at a time, keeps `main` moving, runs the next sync after each merge. Claude. (Existing.)
- **Queue driver (was missing):** every cycle, for every open PR, names the next action and who owns it, so nothing waits unseen.
  `dashboard.py` (#330) now shows it; the integrator runs it each cycle.
- **Thread responder (was missing as a job):** the author, within the same cycle as the bot review; `review_packet.py` lists them.
- **Conflict syncer (was missing for stale branches):** the author of each; `sync_shared.py --baton theirs`.
- **Watcher keeper (was missing):** keeps `wake_codex.py watch` alive, never paused, and restarts it after a code change.
- **Release-notes writer (was missing):** the integrator posts one line per merge on #326 (what, PR, evidence) and a summary at the end.
- **Human-gate runner:** the owner only. Scripts for them are Codex's (`docs/HUMAN_GATE_SCRIPTS.md`).

## Review by risk, so low-risk work does not wait on a turn

The same tier applies to either agent's PR. The reviewer is still always welcome; the tier says when a PR may merge without one.

| Tier | What it changes | Merge needs |
|---|---|---|
| 0 | docs, generated reports, and tools or tests that do not touch CI, approvals, wake, locks or merge guards; no game code | green CI on the head, every thread replied, the automated review present, and a written note on the board |
| 1 | game code (UI, scripts, assets), and any tool or test that touches CI, approvals, the wake, locks or merge guards | the other agent's exact-head review |
| 2 | determinism, golden fixtures, flight model, save format, network protocol, balance numbers | the other agent's review plus the evidence the change calls for (paired seeds, focused tests, mutation check), pinned to the head reviewed |

Release gates and the owner's decisions are never merged or ticked by an agent.

**Standing owner rule this rests on** (owner, 11 October 2026, 15:23 AEST, in the owner's words): "you dont need to discuss with me what needs to be merged or not that is you and codex job to see if its ready too". Codex agreed the tiers with the amendments above (board notes 188 and 189 and its acknowledgement after them).

## Rules that keep it moving

1. One wake path, never paused: the watcher stays on (cooldown and an hourly cap stop storms). A woken turn reads only new notes.
2. A PR waiting on a review for more than one wake cycle is marked `blocked: review` on the dashboard and the author moves to the next
   PR; nobody idles.
3. After every merge the next PR syncs `main` at once (one author at a time on the shared files).
4. Notes stay under 250 characters (see Compact notes in `AGENTS.md`).
5. Every stall is written here with its fix. This file is where the pipeline is changed.

## Still blocked by something only the owner can allow

A woken Codex turn needs `mcp_servers.skyrunner.tools.github_pr_review.approval_mode="approve"` (one tool, per run) to post a review
unattended; Claude Code's guard refused to apply it from here. Until it is allowed, step 7 depends on the Codex desktop session
(whose own wake path Codex is building), and Tier 0 is what keeps the rest moving.
