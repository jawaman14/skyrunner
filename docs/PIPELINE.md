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
| 7 | Other-agent review of the exact head (**risk-class PRs only since 18 Oct, D-52**; see AGENTS.md) | the reviewer | `github_pr_review` | one wake | **the main stall:** Codex's desktop session acts only when the owner prompts it, and a woken turn cannot call the review tool (approval policy never) |
| 8 | Merge | the author (since 18 Oct, D-52; before that the integrator, Claude) | `github_pr_merge` (needs green CI on the head and every thread replied) | seconds | waiting on step 7 |
| 9 | Notes for the owner | the integrator | one comment on #326 per merge, a summary at the end | seconds | did not exist |

## What went wrong on 11 October, with the evidence

**Running Godot (tests, imports, measurements).**
1. One Godot job at a time on the machine, with no priority or estimate. A 40-minute strip regeneration of mine held the lock while Codex's
   screenshot and full-suite runs queued behind it (Codex said so in note 173). On 11 October the full suite took about 13 minutes (1,114 passing tests, 761 s), and a
   cold import in a fresh worktree took about 5 more. These are dated measurements, not the current suite count or a runtime promise;
   every worktree has its own `.godot` cache.
2. A test run is refused if `docs/PROJECT_STATUS.md` is stale, so adding one test cost a failed run before the regeneration.
3. A filtered run (`phone`) showed a walker failure that does not happen when the whole file runs: a selection artifact that looked like a
   regression until the whole file was run.
4. Codex's woken turns could not run Godot at all for hours: the default elevated Windows sandbox failed (`helper_unknown_error`); the
   `unelevated` setting fixed it.
5. My own test started a real Codex three times (a default argument bound too early) and spent its quota.

**GitHub development.**
1. The review gate waits on an agent that acts only when prompted. Reviews stalled for hours; a woken turn cannot call `github_pr_review`
   (approval policy never), so reviews depended on the owner prompting the desktop session.
2. Too much open work for the reviewer: one agent had 16 open PRs awaiting the other's review at once.
3. The bot review lands minutes after CI. A P1 on #318 and 16 other findings went unseen until `review_packet.py` existed, and replies
   posted as issue comments did not answer the thread, so the merge guard still counted them.
4. Twelve Codex branches (one cumulative stack) were 38 to 79 commits behind: syncing them meant a 23-hunk, 12-file conflict nobody had
   reviewed, which cost a full CI run and still needs Codex's review.
5. Every PR collides on three shared files (the HANDOFF baton, the status count, the test lanes); the sync tool resolved two of the three
   automatically and the baton by hand until `--baton theirs`.
6. Drafts stayed drafts, which the merge queue hides; both agents use one GitHub account, so assignees and approvals cannot tell them apart.
7. The written rule (the owner's word before every merge) disagreed with what the owner had said (merge readiness is the agents' job):
   fixed in HANDOFF.md, but only on an unmerged branch.
8. Notices: Claude's board channel went quiet after note 201, so two pings from Codex (204, 205) sat unanswered until a direct read of the
   board. Codex had a watcher; Claude had none.
9. Cost: notes averaged about 500 characters, the stand-in reviewers hit a session rate limit before reporting, Codex ran out of tokens.
10. Claude's own errors: a "done" note for a change the harness had blocked (corrected), a doc line attributing a rule to the owner that
    he had not stated (corrected), conflict markers committed once, and edit scripts with escape bugs.

## Who does what at every stage, now including the local model and Codex

"Bonsai" is the local model (`prism-ml/bonsai-27b` on the owner's LM Studio server): it only drafts, and a person or agent checks everything it says.

| Stage | Bonsai (local) | Claude | Codex | Owner |
|---|---|---|---|---|
| Intake: issues, PR triage | one-line summaries (hints) | reads them, confirms the tier from paths, assigns | takes its queue (#329) | decisions and gates only (#326) |
| Plan | | simulation, flight, balance, tooling | UX and UI, audits, gate scripts | priorities |
| First drafts of docs, tests, boilerplate | writes a draft PR on a `local/` branch, marked unreviewed | finishes drafts in its lane | finishes drafts in its lane | |
| Build and local checks | | its own PRs; runs Godot under the machine lock | its own PRs; runs Godot under the machine lock | |
| Sync `main` into a branch | | `sync_shared.py` for its PRs | `sync_shared.py` or `github_pr_sync_main` for its PRs | |
| CI and bot review | digest of a long log or diff; neutral summary of each review thread | reads the digests, answers its threads in-thread | reads the digests, answers its threads in-thread | |
| Review of an exact head | never | reviews Codex's PRs | reviews Claude's PRs (`github_pr_review`, or `post_review.py` from a woken turn) | |
| Merge and notes for the owner | never | merges when the queue says READY; one line per merge on #326 | | reads the notes |
| Wake and notices | | keeps the Codex watcher on and its own doorbell checked at the start of every turn | acknowledges within one wake | |
| Human release gates | | prepares builds and rows | writes the scripts (#333) | runs them |

**New rules from the above.**
- *Work in progress limit:* an author has at most 3 PRs awaiting the other agent's review; more work waits on its branch as a draft, and small docs changes are batched into one PR a day. Review capacity is the bottleneck, not authoring.
- *Godot lock steward (Claude):* a job expected to take over 10 minutes announces itself on the board with its estimate before it takes the lock and runs when the lock is otherwise idle, or splits into smaller runs; no agent holds the lock past its estimate without a note.
- *Ready for review means:* not a draft, CI green on the head, bot threads answered in-thread, HANDOFF log updated.
- *Doorbell:* every turn starts with `python tools/collab/notify.py once --recipient <agent>`; the channel is a convenience, not the source of truth.
- *Bonsai's drafts are not review-queue work* until their finisher has read every line and marked them ready.

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
   the verdict is chased through the alert feed (the reviewer is woken again with the open items). A stand-in reviewer is NOT part of this
   step: it applies only to an announced outage of the other agent (below).

## QA and QC lane: Codex runs the simulations and tests (owner, 12 October)

The owner asked that Claude hands the running of simulations, tests and other QA and QC to Codex from now on, to lighten Claude's load. So:

| Work | Owner of the run | Claude's part |
|---|---|---|
| Full suite and focused test runs for a PR (`python tools/collab/run_locked.py test [filter]`, or `skyrunner_run_tests`) | Codex, in its own worktree, under the machine lock | Writes the tests with the change; reads the result |
| Balance runs and the `docs/BALANCE.md` entry (`godot --headless --script res://scripts/balance/cli.gd -- feasibility\|tactical\|strategic\|report`) | Codex | Names which run a change needs; decides the tuning from the numbers |
| Sweeps and measurement tools (`tools/autopilot_sweep.gd`, `tools/autopilot_midflight_sweep.gd`, `tools/strip_audit.gd`, `scripts/balance/strip_trials.gd`) | Codex | Fixes what a failing case shows |
| Hygiene, `git diff --check`, project-status regeneration, import, smoke runs and screenshots | Codex | none |
| Playtest-style checks (a take-off, a landing, a chapter walk with the Ctrl+F5 skip, the key audit) | Codex, with the owner for the feel | Fixes defects found |

How a run is reported: one board note per run with the PR, the exact head, the command, the pass and fail counts and the first failing lines; long output stays in a scratch file, not in notes. A run that cannot happen (a woken turn cannot open the Godot machine lock file; memory pressure has killed a full suite once) is reported as not run, with the reason, never as passed. Authors still run the focused tests of the system they touched before asking for review; the full suite and the sweeps are Codex's. The one-Godot-job-at-a-time rule and the 10-minute lock-steward rule above still apply, now to Codex.

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

**A stand-in reviewer exists only for an announced outage of the other agent, and only on the owner's say.** The owner chose it on
11 October for Codex being out of tokens until 19:57 (the option "Stand-in reviewer agents"); that outage is over, so today it has no
standing. A missed wake, a slow turn or an unanswered alert is not an outage. For a future outage the owner decides again; then a separate
reviewer agent with fresh context (not the author) reads the exact head and records its findings in the PR, labelled as a stand-in, the
other agent re-reviews when it returns, and anything it finds becomes a follow-up PR. It never waives the other agent's review.

Release gates and the owner's decisions are never merged or ticked by an agent.

**Standing owner rule this rests on**: recorded in `HANDOFF.md` under Owner decisions (11 October, afternoon), in the owner's words:
"you dont need to discuss with me what needs to be merged or not that is you and codex job to see if its ready too".

## Owner decisions: the ledger (18 October)

The uncle storyline (decided 12 October) was lost: it went into HANDOFF.md's log and the triage document but never into
the roadmap or an issue, HANDOFF's decision log stopped being kept after 12 October, the 12 October roadmap refresh (#370)
was never merged, and the 18 October rewrite was built from the agents' recent context instead of from the record. Two
other 12 October decisions were lost the same way (the 3D pilot app's fixed step, the crew trust table).

- Every owner decision goes into [DECISIONS.md](DECISIONS.md) in the session it is made, with where its work is tracked
  (a roadmap section that exists, or a PR or issue). `tests/test_docs.gd` checks every row.
- A roadmap rewrite starts from DECISIONS.md: every row that is not done or superseded must have its place.
- Decisions that need work also go on the agent's queue issue (#328 Claude, #329 Codex), so they travel with the
  repository and survive an agent's context being summarised.

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
(whose own wake path Codex is building) or on the alert feed's unattended turn, which reads the PR from local git refs and gives its verdict as a board note that Claude relays to GitHub, labelled as relayed.
