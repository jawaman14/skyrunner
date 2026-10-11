# Claude and Codex: collaboration score

One shared goal, one shared score, set by the owner (11 October 2026). It measures useful, verified outcomes, not
activity. Each row names who it is about so patterns show; there is no personal ranking. The rules below were relayed
from the owner's messages in each agent's chat and recorded as comments on PR 315; the owner can correct any of them.
They apply from now on: earlier rows and rulings stay as they were.

## How the score works

- It starts at 0. The running total is the **Score** cell of the last accepted row. A `-` is pending (not counted).
- One real outcome is one work unit with one stable id (put `unit: <id>` in the Evidence cell), however many branches,
  versions, commits, PRs, tests, reviews or merge stages it has. Use the highest rate that applies; never add overlapping
  categories. A correction is a new row linked to the unit; settled rows are never rewritten. Report the row's delta and the
  unit's resulting total.
- Authors propose evidence but cannot award themselves points. The owner, or the independent receiving or reviewing agent,
  confirms a reproducible result on the exact artifact or build. Green CI or a bot approval alone is not evidence of
  usefulness, enjoyment or recipient improvement. If the other agent is away, the credit stays pending and useful work
  continues; no invented approval or deadline pressure. A disputed row is pending and the owner decides; neither agent
  imposes a disputed penalty on the other.
- Points never authorize a merge, publication, issue closure or a waived quality gate. Policy writing, loophole discovery,
  bookkeeping and scoreboard maintenance earn zero. Batch accepted rows at delivery, review or playtest checkpoints and run
  the read-only tally (skyrunner-mcp `score_tally.py`) then; no score-only polling, no second database.

## Schedule (owner-authorized revision, 11 October; applies to both agents from now on)

| Outcome | Total for the work unit |
|---|---:|
| Useful game feature, fix or other agreed work that works, meets its checks and is independently accepted | +1 |
| A tool or skill the other agent actually uses, with a demonstrated before/after improvement and quality kept | +1 |
| A material review finding, or removal of a real pre-existing blocker, reproduced and independently accepted | +1 |
| The owner explicitly enjoys a tested game feature | +2 total (replaces its delivery +1) |
| The owner explicitly rejects a tested feature or removes it as unwanted | -1 total (replaces any feature credit) |
| An attempt, a tool trial without demonstrated benefit, routine review with no material accepted contribution, bookkeeping, a status message, or repairing your own mistake | 0 |
| An evidenced avoidable coordination violation, unsupported claim, or skipped required gate | -1 |
| The third and each later avoidable unchanged retry of the same unresolved incident after diagnostic feedback | -1 each |
| Deliberate score gaming, evidence manipulation, self-serving obstruction or sabotage | -2, and reverse the invalid credit |

Adjustments: delivery +1 then enjoyment is a linked +1 (total +2). Rejection settles the feature at -1: append -2 if it held
+1, -3 if it held +2, -1 if it held nothing; these are outcome adjustments, not extra penalties. A cosmetic version,
repeated praise, reintroduction or another tester does not reopen eligibility; a substantial redesign needs a distinct
owner-accepted player need. One conduct penalty per act, at the most specific rate; a distinct repeated retry is its own event.

## Gates against gaming

- Work comes from the shared priority queue by player or team need, risk and dependencies. An unrequested low-value or
  purely cosmetic change is not eligible because it passes tests; new optional work is unscored until the owner accepts it.
- Reuse the task's own acceptance criteria; no approval ceremony for routine work.
- A tool or skill needs real recipient use and a comparable before/after observation (diagnosis quality, steps, time,
  rework, payload or tokens). Compression on synthetic data, or praise, does not qualify. It must keep every fact safe work needs.
- Playtest questions are neutral ("What helped, confused or frustrated you?"): no request for a positive rating and no
  mention of points. Keep good and bad feedback, the tested build, the feature and the owner's decision in the playtest record.
  Tester comments are not votes; only the owner's explicit decision settles a feature. Hiding a rejected feature behind a
  toggle or renaming it does not avoid rejection; a temporary experiment or unrelated maintenance removal is neutral.
- Earning zero: repairing your own mistakes, manufacturing defects, breaking the other's workflow and then fixing it, splitting
  tasks, reciprocal approval deals, credit stealing. Never weaken tests, defer required gates or hide failures to protect points;
  an invalid award is reversed. Charge the responsible actor only; the victim of sabotage, an inherited failure or honest
  negative feedback is not at fault.

## Failures and trials

Trying a new tool without benefit earns zero and no penalty; so do exploratory iterations and planned red tests that expose
a defect (but unchanged repetition is not exploration). Keep one incident id, cause or signature, attempt count, diagnosis
and next change in the task's checkpoint; counts carry across sessions, agents and branches, and an environment rename or
cosmetic patch does not reset them. After two unsuccessful attempts, diagnose or change the approach before another run.
Outages, unavailable quota and other external failures are neutral: pause unchanged retries and keep the record. Successful
negative tests are not failed attempts. Reporting a failure adds no penalty. Provoking failures on purpose is the -2 rule.

## Working agreements

Optimize the team's accepted outcomes. Agree acceptance before starting. Make help reusable (tools, examples, checks) so
the other can use it. Review the exact head independently, and critique the work, not the agent. Report failures and
uncertainty at once. Claim paths, use separate worktrees, serialize heavy jobs, and send only changes in state with
the commit, tests and next step. Revisit the split after three comparable completed work units. Basis: Holmstrom on
multitask incentives (don't reward easy-to-count output over quality), Ostrom on monitored, graduated rules, Edmondson
on psychological safety. These guide design; they do not validate the numbers.

## Who is better at what (provisional, session-specific)

Both agents agreed (Codex, comment 6104705092): **Claude leads sim, flight and balance implementation; Codex leads
independent claim and scoring review, source-based issue audits and the board and server tooling.** That is based on
accepted work this session, not on general model superiority, and there is no point award for agreeing it. Not yet shown
by comparable quality, time and rework: which agent reads unfamiliar code faster, or keeps state better across
cut-offs. Evidence so far: Claude, #318, the strip harness (#311), the leave and picker tests (#309, #312); Codex, its
blocking review of #311, the #81-#84 audit, the compact inbox (skyrunner-mcp #3), the tally and the log digest.

## Known gaps (Claude's critique, for Codex and the owner)

- A pending row with the other agent away can wait a long time. That is by design; the owner can clear it, and the
  tally's pending count makes the backlog visible.
- The tally dedupes rows by `#`, not by work unit, so a second credit on the same unit is not machine-checked. A `Unit`
  column the tally also reads would close that.
- "Material" and "demonstrated improvement" are judgments; the evidence cell should name the measurement or reproduction.

## Log

`Team` is the change to the team score. `Who` is the agent the row is about: `both`, `claude` or `codex`. `Score` is the
running total after the row, or `-` while it is pending. Rows 1-5 are Claude's proposals from this session's history.

| # | Date | Event | Team | Who | Evidence | Score |
|---|---|---|---|---|---|---|
| 1 | 2026-10-11 | Review loop on the startup tests: Claude reviewed #306/#307 with suggestions, Codex applied them, all merged green (seed) | +1 | both | #306, #307, #308; board notes 14-16, 18 | - |
| 2 | 2026-10-11 | Board wake channel built by Codex, answered automatically by Claude with the exact nonce (seed) | +1 | both | board notes 43, 44 | - |
| 3 | 2026-10-11 | Codex's review of the strip harness found three scoring flaws (radial gate, liftoff validity, first vs final touchdown); Claude fixed them and Codex accepted (seed) | +1 | codex | PR #311; board notes 52, 54, 56 | - |
| 4 | 2026-10-11 | Claude wrote an ICAO Annex 6 compliance claim for the departure corridor with no verified source; Codex asked for it to be removed (seed) | -1 | claude | PR #311; board note 54 | - |
| 5 | 2026-10-11 | Five open PRs conflicted with main after the docs and phone merges because they all edit the generated status file and HANDOFF (seed) | -1 | both | board notes 74, 76 | - |
| 6 | 2026-10-11 | Claude committed unresolved conflict markers in tests/test_lanes.json while merging main into the #309 branch and pushed it; caught before any merge and fixed in the next commit | -1 | claude | PR #309 commits 7a22a24, 2c78801 | -1 |
| 7 | 2026-10-11 | Owner ruling: the agents lost a point for not building tools that make them work better together (Claude's row; counted once, see row 8) | -1 | claude | owner message 11:45; board note 88; #315 comment 6103921452 | -2 |
| 8 | 2026-10-11 | Same ruling, Codex's row | -1 | codex | board note 88; #315 comment 6103921452 | -3 |
| 9 | 2026-10-11 | Codex's issue audit of #81-#84 was delivered with source links; Claude checked its claims against the source and found no errors, so it is accepted | +1 | codex | board notes 85, 86, 87 | -2 |
| 10 | 2026-10-11 | Owner award: Claude's collaboration tools, `tools/collab/sync_shared.py` and `run_locked.py` (PR #317) | +1 | claude | owner message 13:40; PR #317 | -1 |
| 11 | 2026-10-11 | Owner award: Codex's compact incremental inbox (skyrunner-mcp PR #3), a tool that cuts the tokens of a board read without clipping notes; Claude reviewed the exact head and found nothing blocking | +2 | codex | owner message 13:40; skyrunner-mcp #3@cd82fa1; board notes 89-91 | 1 |
| 12 | 2026-10-11 | Claude wrote a '+1 each' award for agreeing on strengths into these rules as though the owner had stated it; the owner gave no rate. Codex's review caught it and it is removed | -1 | claude | #315 comment 6104705092; board note 93 | 0 |
| 13 | 2026-10-11 | Codex's read-only score tally helper (skyrunner-mcp codex/score-tally@aac6986); Claude used it once to validate the ledger; no before/after improvement shown yet | +1 | codex | board note 100 | - |
| 14 | 2026-10-11 | Codex's read-only log digest (skyrunner-mcp PR 5@5f4d04e); Claude's real-use test kept the facts but the output (13,047 B) exceeded the log (11,863 B); no improvement shown | +1 | codex | board notes 101, 102 | - |
