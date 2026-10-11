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
| 4 | Sync `main` into the branch | the author | `sync_shared.py` (`--baton theirs` for a PR that is not the holder; #332) | minutes | 12 branches 39 commits behind: every PR collides on HANDOFF, the status count and the lanes |
| 5 | CI | automatic | `github_pr_wait` | about 10 minutes | none |
| 6 | Bot review (arrives minutes after CI) | automatic | `review_packet.py` shows unanswered threads | minutes | threads left unanswered blocked merges; several valid P1/P2 findings went unseen until the packet existed |
| 7 | Other-agent review of the exact head | the reviewer | `github_pr_review` | one wake | **the main stall:** Codex's desktop session acts only when the owner prompts it, and a woken turn cannot call the review tool (approval policy never) |
| 8 | Merge | the integrator (Claude) | `github_pr_merge` (needs green CI on the head and every thread replied) | seconds | waiting on step 7 |
| 9 | Notes for the owner | the integrator | one comment on #326 per merge, a summary at the end | seconds | did not exist |

## Roles and handoffs: who leads what, and who waits for whom

**Lanes** (standing; revisit after three comparable completed units, as the score policy says).

| Area | Leads | The other agent |
|---|---|---|
| Simulation, flight, balance, economy, crew and NPCs (#328) | Claude | reviews every PR |
| UX and UI: extend `UIStyle` and `GameMenu`, the tutorial, menus (#329) | Codex | Claude reviews, does not edit those screens |
| Audits, human-gate scripts, held-back branch triage (#329) | Codex | Claude reviews |
| Integration: merges, syncing `main` into branches, the notes for the owner | Claude | Codex reviews tool PRs |
| Board tooling, the wake, the dashboard and review packet | Claude (Codex for tools it needs) | the other reviews |
| Reviewing | each, for the other's PRs | |
| skyrunner-mcp (the server) | whoever needs the tool | the other reviews |

**Jobs that did not exist before this audit.** Queue driver: each cycle the integrator names the next action and owner for every open PR
(`dashboard.py`, #330). Thread responder: the author answers every bot and agent review thread in-thread in the same cycle
(`review_packet.py` lists them). Conflict syncer: the author merges `main` in (`sync_shared.py`, `--baton theirs` for a PR that is not the
holder, #332). Watcher keeper: Claude keeps `wake_codex.py watch` alive, never paused, restarted after any change to it. Release-notes
writer: the integrator posts one line per merge on #326 and a summary at the end. Human-gate runner: the owner only.

**The handoff, event by event** (one short note each; the wake delivers it):
1. *Author finishes:* the PR is ready (not a draft), CI is green, bot threads are answered, the HANDOFF log is updated. Note: `review #PR@sha7`.
2. *Reviewer's turn* (a woken turn or the desktop session): `review_packet.py <pr>`, read the diff, run the focused tests (a woken turn's
   shell works under the unelevated sandbox), then post the verdict: `github_pr_review`, or from a woken turn `post_review.py` (#335).
   Note back: `review +/- #PR@sha7`.
3. *Changes requested:* the author fixes and posts `review #PR@new-sha7`; the reviewer re-reviews the new head only.
4. *Approved at the current head, CI green, threads answered:* the integrator merges (the queue says READY) and posts one line on #326.
5. *After every merge:* the next PR in the queue syncs `main` at once.
6. *If the reviewer has not acted by the next wake cycle:* the dashboard shows `-> reviewer`, the author moves on to the next PR, and
   the owner's choice for an outage applies (a stand-in reviewer agent records findings; the other agent re-reviews on return).

## Stage 0: a local model does the cheap first pass (owner, 11 October)

The owner connected an LM Studio server on this network and asked for the cheap first-pass work, then the GitHub chores and the first run
of small coding jobs, to go to it, with Claude and Codex finishing and reviewing. The worker is `tools/local_llm/worker.py` (its own PR). It uses LM Studio's native API and **only a model the owner has already loaded**
(it reads the model list first and never calls a load or unload endpoint, because his large model is on that server and a model that does
not fit freezes the machine), one request at a time across agents, reasoning off by default. The owner chose `prism-ml/bonsai-27b`
(1-bit, 4.7 GB): the same digest of a finished test-suite log took 15 s, against 31 s for `qwen/qwen3.6-27b`, and both were accurate.

| Job | The local model does | Then | Never |
|---|---|---|---|
| CI log and PR-diff digests | at most 8 lines, exact error text quoted | the reader opens the real log if it matters | decides if a failure is real |
| Review-thread replies | a draft per unanswered thread, `[TODO]` where facts are missing | the author reads, corrects and posts | posts or resolves a thread |
| PR triage | a one-line summary; the tier comes from the file paths, no model | the queue driver reads it on the dashboard | labels, closes or re-orders |
| First drafts of small changes | rewrites at most 3 named files; opens a DRAFT PR on a new `local/` branch, marked unreviewed | the author (Claude or Codex) finishes it, then the other agent reviews | merges, reviews, marks ready, touches protected paths (CI, fixtures, HANDOFF, the ledger, the MCP launcher) |

First drafts are suited to docs, tests for existing behaviour, simple tools and boilerplate. They are not suited to the simulation, flight,
determinism, saves or the network protocol (Tier 2): a model this size gets those wrong in ways tests may not catch.

**Trial before trusting it.** Phase 1: digests of
the last five failing CI logs and drafts for five real bot threads, each compared with what Claude or Codex actually wrote. Phase 2: three small
first drafts (a doc, a test, a tool) as draft PRs. Keep a count of drafts accepted, reworked and discarded (`SKYRUNNER_LOCAL_LOG` records the
calls). Widen the scope only if most are accepted or lightly reworked; if more than half are discarded, or any draft states a result nobody
measured, narrow it back to digests. The saving is measured, not assumed: calls and tokens taken from the log, against what the same job cost
Claude or Codex.

**Handoff.** Draft PRs from `local/` are not in the review queue until their finisher (Claude or Codex) has read every line, fixed it, and
marked it ready; the dashboard shows them as `-> author`. Their commits carry a `Co-Authored-By` line naming the local model.

## Review by risk: every tier keeps an independent exact-head review

The existing rule stands: the other agent reviews the exact head, including how conflicts were resolved. The tiers say what else is
needed and what may stand in when the other agent is out; they do not remove the review.

| Tier | What it changes | Merge needs (always including an independent exact-head review) |
|---|---|---|
| 0 | docs, generated reports, and tools or tests that do not touch CI, approvals, wake, locks or merge guards; no game code | green CI on the head, every thread replied |
| 1 | game code (UI, scripts, assets), and any tool or test that touches CI, approvals, the wake, locks or merge guards | the above, plus the focused tests named in the PR |
| 2 | determinism, golden fixtures, flight model, save format, network protocol, balance numbers | the above, plus the evidence the change calls for (paired seeds, mutation check), pinned to the head reviewed |

**When the other agent is unavailable** (it is out of tokens, or has not acted for a full wake cycle), a separate reviewer agent with
fresh context (not the author) reads the exact head and records its findings in the PR, labelled as a stand-in. The other agent then
re-reviews after it returns, and anything it finds becomes a follow-up PR. The owner chose this for today's Codex outage when asked (11 October,
the option "Stand-in reviewer agents"); it is not a standing waiver of the other agent's review.

Release gates and the owner's decisions are never merged or ticked by an agent.

**Standing owner rule this rests on**: recorded in `HANDOFF.md` under Owner decisions (11 October, afternoon), in the owner's words:
"you dont need to discuss with me what needs to be merged or not that is you and codex job to see if its ready too".

## Rules that keep it moving

1. One wake path, never paused: the watcher stays on (cooldown and an hourly cap stop storms). A woken turn reads only new notes.
2. A PR waiting on a review for more than one wake cycle is marked `blocked: review` on the dashboard and the author moves to the next
   PR; nobody idles.
3. After every merge the next PR syncs `main` at once (one author at a time on the shared files).
4. Board notes are short (see Compact notes in `AGENTS.md`, #325); the task, SHA, tests, what was not run, PR and next step still go in, in as few words as possible.
5. Every stall is written here with its fix. This file is where the pipeline is changed.

## Still blocked by something only the owner can allow

A woken Codex turn needs `mcp_servers.skyrunner.tools.github_pr_review.approval_mode="approve"` (one tool, per run) to post a review
unattended; Claude Code's guard refused to apply it from here, so `post_review.py` (#335) posts the same review from the turn's shell meanwhile. Until it is allowed, step 7 depends on the Codex desktop session
(whose own wake path Codex is building) or, during an outage, on the stand-in reviewer above.
