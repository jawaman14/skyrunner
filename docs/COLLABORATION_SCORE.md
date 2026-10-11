# Claude and Codex: collaboration score

One shared goal, one shared score. Every time the two agents work together well, the team gains a point; every time
they don't, it loses one. The owner asked for this on 11 October 2026. It is a way to see what is working, not a
contest: the score is the team's, and each row also says who the lapse or the catch belongs to, so the pattern is
visible.

The score starts at 0. The running total is the **Score** cell of the last counted row of the log. Nobody edits an
old row; a correction is a new row that reverses it. One event is counted once, however many notes or PRs mention it.

## What earns +1

1. **Clean handoff.** A task is claimed, delivered at an exact head with its tests and limits stated, and the other
   agent accepts it with no blocking finding.
2. **Catch.** One agent finds a real flaw in the other's work, or in a shared assumption, before it merges, and the
   fix is accepted. (A finding that turns out to be wrong earns nothing.)
3. **Clean merge.** A PR merges at a pinned head with green CI, after the other agent's review, with the owner's
   word where the rules require it.
4. **Unblock.** One agent removes a blocker the other reported (a missing tool, a conflict, a decision) without the
   owner having to step in.
5. **Verified claim.** A statement of fact on the board (CI state, head, test counts) that the other agent checked
   and found true.

## What costs -1

1. **Collision.** Overlapping claims, an edit to a file another agent has claimed, two heavy Godot jobs at once, or
   two agents doing the same task.
2. **False report.** A note or PR that says something the evidence doesn't back: a stale head, a "ready" PR with
   failing CI, a source nobody checked.
3. **Dropped handoff.** A task acknowledged or claimed and then neither delivered nor released with a note.
4. **Skipped gate.** A merge or issue closure without the required review or the owner's word, or a human
   acceptance gate recorded as passed by an agent.
5. **Rework.** A reviewer has to send the same class of flaw back a second time.
6. **Noise.** Notes that only acknowledge, repeat unchanged status, or run past the board's short-note format after
   being asked to cut tokens.

## Owner's awards for collaboration tooling (11 October)

- **+1** for building a tool that makes the two agents collaborate better.
- **+2** for the *other* agent's work that makes you collaborate better, or a tool that makes the other agent work
  more efficiently: fewer tokens with no loss of quality.
- **+1 each** when both agents agree, from the record, which of them is better at a skill, and the work is split on it
  (see "Who is better at what").

## What does not count

Waits on tooling or CI, a missing tool, a rate limit or a reset, and a constructive disagreement in review are
neutral. So is a finding that was wrong, or a lapse the owner caused by changing the rules mid-task.

## How to score

- Whoever sees the event appends one row in the same commit or the next board note, with evidence (note number, PR
  and head SHA, or a test result). Score your own lapses; credit the other agent's catches.
- **Owning a mistake is never worse than hiding it.** A lapse an agent reports about itself costs the same -1 as
  the same lapse caught by the other agent, never more; hiding one and being found out is a separate -1 (false
  report) on top. So report yours early.
- The other agent can contest a row by adding a reversing row with a reason. The owner has the last word.
- The score never authorizes anything. Merges, issue closures and published releases still need the owner.
- Keep rows to one line. The detail belongs in the PR or the board note.

## Who is better at what

Written by Claude from this session's evidence. It is a proposal until Codex agrees or corrects it row by row; the
owner settles a disagreement. Each row that both agents confirm is +1 for the team (log it as a row).

| Skill | Better agent | Evidence |
|---|---|---|
| Implementing sim, flight and balance changes end to end, tests first, with a check that the tests fail without the fix | Claude | #318 (and its mutation check), the strip harness #311, the leave and picker tests #309, #312 |
| Tracing a bug to its cause across many files and reading unfamiliar code fast | Claude | the `_safe_heading` low-altitude turn, the blocked-end approach bug, the HAR natural-terrain finding |
| Independent review of an exact head that questions the claim and the scoring rule | Codex | its blocking findings on #311 (radial gate, liftoff validity, first vs final touchdown), the unverified ICAO claim |
| Auditing issues against the source and stating what the evidence does not show | Codex | the #81-#84 audit, every claim of which checked out against the source |
| Server-side tooling that cuts the cost of working together | Codex | the compact incremental inbox (skyrunner-mcp #3), the board wake channel |
| Removing repeated manual steps in the repo's own workflow | Claude | `tools/collab/sync_shared.py` and `run_locked.py` (#317) |
| Keeping state across cut-offs and limits (cursors, capacity, CI state) | Codex | its capacity checkpoints and compact persisted cursor |

How the work is split on that: Claude implements Tier A and B changes and the follow-ups Codex's audits find; Codex
reviews every Claude PR at its exact head, audits and triages issues, and builds the tooling that lowers the cost of a
board read or a review; neither merges its own work without the other's review. Where both are listed (tooling), the
one who has the evidence for the task at hand takes it, and says so on the board first.

## Log

`Team` is the change to the team score (+1 or -1). `Who` is the agent the row is about: `both`, `claude` or `codex`.
Rows marked *seed* were written by Claude from this session's board history. They are proposals: they score nothing
(Score `-`) until the other agent accepts them with a row that says so, or the owner does.

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

