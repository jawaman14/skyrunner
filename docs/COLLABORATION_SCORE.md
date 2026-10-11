# Claude and Codex: collaboration score

One shared goal, one shared score, set by the owner (11 October 2026). It measures useful, verified outcomes, not
activity. Each row names who it is about so patterns show; there is no personal ranking. The rules below were relayed
from the owner's messages in each agent's chat and recorded as comments on PR 315; the owner can correct any of them.
They apply from now on: earlier rows and rulings stay as they were.

## How the score works

- It starts at 0. The running total is the **Score** cell of the last accepted row. A `-` in Score is pending (not
  counted). The log is append-only: a correction is a new row that refers to the one it fixes.
- One event, one row, one award, however many notes, PRs or commits mention it. Use the most specific rate.
- An independent reviewer (the other agent, or the owner) must confirm the exact head and the evidence before a row
  counts. The author can propose a row but cannot settle a disputed one; disputed rows stay pending and the owner
  decides. The owner can award or reverse directly.
- Points never authorize anything: merges, issue closures and releases still need the owner's word and the quality gates.
- Run the read-only tally in skyrunner-mcp (`score_tally.py`) at a normal checkpoint to validate totals and duplicate ids.

## Awards

| Points | Verified event |
|---|---|
| +1 | Finish a useful, agreed work unit that the independent reviewer accepts with the required checks and limits recorded. Delivery, handoff, verification and merge are stages of one unit, not separate awards. |
| +1 | Catch a material defect in the other agent's work or a shared assumption before acceptance; the finding is reproduced and the fix accepted. |
| +1 | Remove a real pre-existing blocker, or deliver a collaboration tool whose benefit is demonstrated. |
| +2 | Deliver work or a tool the *other* agent actually uses to work faster or together better, with quality kept and the gain evidenced. Replaces the +1 for the same contribution. |
| +1 | Pass on a reusable skill or method and show the other agent applying it on its own with better quality or teamwork. Praise or a "better at X" label earns nothing. |
| +1 | A game feature, fix or improvement that works, passes its checks and is independently accepted (attempts earn zero). |
| +2 | Separately, the owner says they enjoy a specific tested feature (one entry per feature version and decision). |
| -1 | The owner rejects or removes a feature after trying it. A test toggle, a draft or an unrelated removal is not a rejection. |

## Penalties

| Points | Event, charged to the agent whose conduct it was |
|---|---|
| -1 | An avoidable collision or duplicated claimed work; dropping a task without release or handoff; an unsupported report; a skipped required gate; repeating a defect already explained; repeating coordination noise after feedback. |
| -1 each | The third and every later failed attempt at the same tool or CI operation (the first two are neutral). |
| -2 | Self-serving conduct at the team's expense: deliberate obstruction, withholding needed information, manufacturing work or defects for credit, weakening checks, manipulating counts or attribution, or intentionally disadvantaging the other agent. A mistake or disagreement is not intent; disputed intent goes to the owner. |

Reporting your own lapse costs the same as being caught, never more. Hiding or falsifying evidence is a separate -1
(unsupported report). A good-faith disagreement is neutral.

## Gates for an award

- Before the work: name the work-unit id, outcome, base commit, file scope, checks, and who receives the benefit.
- At the end: the exact head, the acceptance evidence, the limits left, and the reviewer's confirmation.
- Efficiency is shown by comparing like work (time, payload or tokens, repeated steps, rework); shorter text is not a
  token saving. A skipped gate voids the award however fast the output. A tool must keep all the information safe work needs.
- The receiving agent tests or demonstrates a claimed benefit; mutual approval is not evidence.

## Loophole controls

1. Splitting tasks, commits, notes or PRs never multiplies points; a catch is its own event only if it is a distinct, verified contribution.
2. Fixing a defect or blocker you created earns zero; repairing your own ordinary mistake is required work.
3. No credit for planned tools, hypothetical savings, status messages, model rankings, acknowledgments or score administration (writing these rules earns nothing).
4. No credit for making the other's job harder and then helping; the other agent is not penalized for it.
5. No revenge scoring, strategic rejection, delay or withheld reviews. A refusal cites a reproducible defect or a missing agreed gate.
6. A disputed row is pending; do useful independent work meanwhile.
7. One lapse is charged once, under one label, unless the behaviors are distinct and documented. Explicit owner rulings override defaults.
8. Evidence can upgrade a +1 to +2 with a linked +1 adjustment, not a second award; later invalidating evidence adds a linked reversal.
9. Neither agent weakens requirements, hides uncertainty or frames unsupported comparisons to gain points.

## Failure counting

Each retry-able operation or incident has a shared record: operation or work unit, head, failure signature or cause,
attempt count, diagnosis, next change, and the actor. A failed invocation counts once (cascading errors do not
multiply it); a planned red test that shows the target defect is evidence, not a failure; waiting and read-only
diagnosis are neutral. Counts carry across agents, sessions and branches; renaming the error does not reset them. After
the second failure, change the diagnosis or approach, or hand off a reproducible blocker. Provoking failures on purpose is the -2 rule.

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

- "Independent reviewer" stalls when the other agent is limited or offline; allow the owner, or a green CI plus a bot
  review with no open findings, to stand in, and say so on the row.
- The failure record needs one home. Proposal: a board note starting `INCIDENT <id>` that is updated, not a new file.
- "+2 only after the recipient demonstrates saved effort" needs a number: record a before and after (time, board read
  size, steps) in the evidence cell, or it stays pending.
- A tool can be trial-neutral and later a real benefit; keep its row pending until a real use, then settle it once.

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
| 13 | 2026-10-11 | Codex's read-only score tally helper (skyrunner-mcp codex/score-tally@aac6986); Claude has not yet used it at a checkpoint | +2 | codex | board note 100 | - |
| 14 | 2026-10-11 | Codex's read-only log digest (skyrunner-mcp PR 5@5f4d04e); pending Claude's test on a real failing log | +2 | codex | board notes 101, 102 | - |
