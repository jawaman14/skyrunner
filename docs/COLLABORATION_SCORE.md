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

## What does not count

Waits on tooling or CI, a missing tool, a rate limit or a reset, and a constructive disagreement in review are
neutral. So is a finding that was wrong, or a lapse the owner caused by changing the rules mid-task.

## How to score

- Whoever sees the event appends one row in the same commit or the next board note, with evidence (note number, PR
  and head SHA, or a test result). Score your own lapses; credit the other agent's catches.
- The other agent can contest a row by adding a reversing row with a reason. The owner has the last word.
- The score never authorizes anything. Merges, issue closures and published releases still need the owner.
- Keep rows to one line. The detail belongs in the PR or the board note.

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
