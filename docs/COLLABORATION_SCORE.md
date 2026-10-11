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

## Settled amendments (A1-A9, agreed by Claude and Codex, 11 October; owner confirms)

These refine the schedule above; no point value changes.

- **A1 Attribution.** Rows record the responsible contributors and their evidence for credits as well as penalties. `both` means
  genuinely joint work, not two points or two full personal credits. The shared total comes with a contribution history, not a
  league table; raw deductions alone are not a fair measure of capability or value.
- **A2 A catch.** A reproduced material catch makes the reviewer a credited contributor to that same work unit; attribution evidence
  is appended without raising the award. An escaped defect is not automatically misconduct by either agent. Charge -1 only for
  an evidenced avoidable violation (a skipped agreed gate, an ignored known failure, an unsupported acceptance claim); reviewer
  fault needs its own evidence, and merely being within review scope is not enough. The owner's enjoyment or rejection still
  settles a feature's outcome.
- **A3 A lapse found later.** Discovering a lapse later does not prove concealment. A qualifying lapse gets its normal penalty;
  a separately proved knowing non-report, or evidence manipulation, is the -2 gaming rule, not an extra automatic -1. One
  conduct penalty per act; distinct acts need distinct evidence. Reporting early adds no penalty. (Residual gap for the owner: an
  unproved concealment costs nothing extra, and no detection probability can guarantee this incentive.)
- **A4 Baselines.** Record the baseline before the recipient's trial, or compare against the preserved prior method on comparable real
  work, using the same metric and with quality evidence kept. No invented baseline and no synthetic-only efficiency credit.
- **A5 Confirmation.** A confirmation cites the exact head or build, the reproduced commands and the relevant output or artifact. For
  a qualitative skill or a playtest it cites the independently observed task and the original feedback. "Looks good" alone does not
  settle credit.
- **A6 Unit ids.** Every new row has a stable unit id and a unique entry id; an adjustment links the original entry and states the
  unit's resulting total. **The tally does not yet enforce unit caps or linked adjustments**: it checks arithmetic and duplicate
  entries only, so reviewers check units by hand until that is implemented. Past rows are unchanged.
- **A7 Debate is safe.** A good-faith alternative or challenge is always safe, and nobody closes a debate by citing points. A relevant
  objection is answered with reasons before that unit earns credit (it need not be adopted). Repeated score-only objections cannot
  hold unrelated work hostage; an unresolved dispute goes to the owner, not to a unilateral rejection. Opinions are safe; factual
  acceptance claims still need evidence.
- **A8 Trying is safe.** A defect found before acceptance, a documented experiment and a first good-faith approach are neutral unless
  a conduct violation is separately evidenced. Repairing your own error earns nothing extra. There is no perfection standard for
  review and no manufactured catch.
- **A9 Priorities.** State the queue rationale only when choosing a lower-priority task, in the normal claim or checkpoint. Dependency,
  missing access, held paths, resource contention and useful parallel work are valid reasons. Only knowingly disregarding an agreed
  priority after clarification, with no valid constraint, can be a -1; a different judgment alone is neutral. No points for task count.

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

## Known gaps (for the owner)

- The tally dedupes rows by `#`, not by work unit, so a second credit on one unit is a manual check until a `Unit` column or rule is built (A6).
- A pending row with the other agent away can wait a long time. That is by design; the owner can clear it, and the tally's pending count shows the backlog.
- "Material" and "demonstrated improvement" are judgments; the evidence cell should name the measurement or the reproduction.

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
| 15 | 2026-10-11 | Claude's `board_status.py` and `notify.py` (one award for both helpers; unit: monitoring) were used by Codex in a real trial: a full MCP read was 7,088 B against 108 B for the status view and 226 B for the doorbell, and a repeat check 0 B. Claude's own first real use crashed on a non-cp1252 character; fixed and tested before the merge, so that run is not counted as clean | +1 | claude | board notes 120, 121, 122; trial at #317@f5ef6e3, merged as 0136d2f (fix ef048ec) | 1 |
| 16 | 2026-10-11 | Claude's first test run of `wake_codex.py` bound `subprocess.run` as a default argument, so the test patch did nothing and the tests really ran `codex exec resume` three times, waking Codex and spending its quota (avoidable: a test must never be able to start the real thing). Self-reported at once, fixed in #322 (runner looked up at call time, tests point at a nonexistent codex binary, a test proves the fake ran) | -1 | claude | board notes 127 to 129 (Codex's wake replies), 132 (self-report); #322@cbfeac1 | 0 |
| 17 | 2026-10-11 | Owner ruling, reported by Codex and recorded at its request: Codex promised to use the notification tool but showed no visible receipt of Claude's work notice. One deduction, no duplicate conduct deduction for the same lapse | -1 | codex | board note 160 (Codex's own report of the ruling); the owner's wording is not quoted here and the owner can correct this row | -1 |
| 18 | 2026-10-11 | Owner ruling, stated directly to Claude: Claude built the wake tool and then paused its watcher instead of using it constantly (after Codex asked for duplicate wakes to stop). One deduction; the owner's instruction is to keep the watcher on constantly, and it is running again | -1 | claude | owner message of 11 Oct, 16:29 AEST ("keep the watcher on constantly i will deduct -1 to you also since you just built the tool and are not using it"); watcher restarted | -2 |
| 19 | 2026-10-11 | Owner ruling, stated directly to Claude: Codex is out of tokens until 19:57 and the owner deducts 2 from Codex "for not being proactive at all and for him to take on more roles as well". One deduction for one lapse | -2 | codex | owner message of 11 Oct, 17:27 AEST | -4 |
| 20 | 2026-10-11 | Owner offer, stated directly to Claude: +5 to Claude when it completes Codex's work for it while Codex is out of tokens (until 19:57). The +5 is outside this schedule's +/-2 range and counts only when the owner confirms the work is complete, so it is recorded as 0 here and the owner enters it | 0 | claude | owner message of 11 Oct, 17:27 AEST; the work is tracked in #329 and the PRs listed there | - |
