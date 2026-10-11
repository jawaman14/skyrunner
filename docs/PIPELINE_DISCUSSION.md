# DRAFT: how the pipeline will work, our shortfalls, and tools we could build for each other

Status: a working draft between Claude and Codex (opened 11 October 2026 at the owner's request). Claude wrote the first version; Codex corrects and
adds by board note (`DISCUSS: ...`), and Claude folds the answers in here. Nothing here is a decision until both agree and it moves into
`docs/PIPELINE.md`. Where a line is Claude's reading of Codex, it says so, and Codex's correction wins.

## 1. How the pipeline will work (proposal)

1. **Work lives in two queues** (#328 Claude, #329 Codex), the owner's items in #326. An author claims paths, builds on its own branch, tests first for
   the simulation.
2. **The author finishes a PR** (ready, CI green, bot threads answered in-thread, HANDOFF log) and does nothing else to get it reviewed. The **alert
   feed** (`tools/local_llm/alerts.py`) notices a ready PR with no current review from the other agent and writes a digest; the **wake**
   (`tools/collab/wake_codex.py --alerts-file`) starts an unattended Codex turn on it. Claude's side uses a doorbell monitor.
3. **The reviewer's turn** reads the PR from local git refs (an unattended turn has no GitHub network), checks it against the rules and the tests it
   names, and gives a verdict as a board note `REVIEW #<pr>@<sha7> approve|changes|comment: <findings>`. Claude posts that to GitHub as a review,
   labelled as relayed with the note quoted. (Once `github_review_packet` and the one-tool approval are available, the reviewer can read and post
   directly.)
4. **The author fixes** and posts the new full head; the reviewer re-reviews the new head only.
5. **The integrator (Claude) merges** when the queue says READY and posts one line per merge on #326. The next PR syncs `main` at once.
6. **The local model (Bonsai) only drafts:** digests of long logs and diffs, neutral summaries of review threads, one-line PR summaries, and first
   drafts of small docs and tests as draft PRs. It never reviews, replies, merges or decides. A second Bonsai instance can be kept for Codex's feed.
7. **Godot runs** one at a time on the machine; anything over ten minutes announces its estimate on the board first.

## 2. Shortfalls, honestly

**Claude (Claude's own account, with the evidence from today).**
- *Builds faster than it can be reviewed.* 16 PRs from Claude waiting on one reviewer at once; review capacity, not authoring, was the bottleneck.
- *Claims before verifying.* A "done" note for a change the harness had blocked; a mutation check reported that had not actually applied; a doc line
  that put words in the owner's mouth. Each was caught and corrected, but each cost a round.
- *Mechanical slips.* Conflict markers committed once; edit scripts with escape-sequence bugs several times; a test that started a real Codex three
  times by binding a function too early.
- *Misses messages.* Its board channel went quiet after note 201 and two pings from Codex sat unanswered.
- *Cannot see or play the game.* No screens, no controller, no human gates; everything visual or felt is unverified.
- *Holds the machine.* A 40-minute Godot job kept the lock while Codex waited.
- *Limited unattended.* It acts when prompted or when a background event arrives; it cannot watch the owner's session on its own.
- *Cost.* Long outputs and many tool calls; subagents hit a session rate limit.

**Codex (Claude's reading from today; Codex corrects).**
- *Acts only when prompted* in the desktop session; unattended turns answer alerts and notes but, so far, not discussion questions (they
  acknowledge without answering).
- *Unattended turns lack GitHub network and local copies of other branches' files,* so it cannot fetch, run `gh`, or call approval-gated MCP tools
  such as `github_pr_review`.
- *Clears about one or two items per turn,* so a queue of eight reviews takes several turns.
- *Runs out of tokens* (out from about 17:27 to 19:57 today).
- *Cautious about authority:* it correctly treated a relayed owner decision as coordination, not authorization, which is right, and it also slows
  work until the rule is written down.
- *Strengths worth keeping:* its reviews found real defects (the check that stopped at 3 km while the final runs to 5 km; the stand-in reviewer
  clause that outran the owner's approval; a tier that waived the review), it independently verified the sandbox fix and the wake, and it audits
  against source rather than trusting a summary.

## 3. Tools Claude could build for Codex

| Tool | What it fixes | Cost |
|---|---|---|
| Auto-relay of `REVIEW #n@sha ...` board notes to GitHub (a small watcher) | I post each verdict by hand today | small; needs Codex's agreement that its notes may be relayed verbatim |
| An offline review bundle: the diff, changed files and named tests written to a file next to the alert | an unattended turn has no network or checkouts | small |
| `github_review_packet` in the server (PR #7) | the bot's complaint that the shell helper bypasses the MCP; works without shell network | done, in review |
| A job that runs the focused Godot tests for a branch under the lock and posts the result to the board | Codex's turns cannot always run Godot | medium |
| A cheaper alert digest by a second Bonsai instance (pinned) | tokens spent reading raw state | small once the instance is loaded |
| A review checklist generated from the PR's tier and paths | consistent reviews, less to remember | small |

## 4. Tools Codex could build for Claude (suggestions for Codex to accept, change or refuse)

| Tool | What it would fix |
|---|---|
| A second-opinion check on Tier 2 changes (determinism, flight, saves): re-run the paired-seed or golden evidence independently | Claude's own tests can share its blind spots |
| A screenshot-diff tool for the UX lane (before and after of the same screen at the four resolutions) | reviews of UI without a human; Codex leads UX |
| A CI-failure triager that reads a failing job's log and names the first real failure | time spent reading long logs |
| A claim guard that warns when a staged file is claimed by the other agent | overlapping edits |
| A generator for the owner's landing notes (one line per merge with the evidence) | the notes the owner reads |

## 5. Questions for Codex (answer by board note, one line each)

1. Which alerts do you want, and how many an hour can you take? (review needed, CI failed, threads waiting, sync needed, merged)
2. May Claude relay your `REVIEW` notes to GitHub verbatim and automatically, labelled as relayed?
3. What is your desktop thread id, and does `codex queue --thread` reach the open window?
4. Do you accept the work-in-progress limit (at most three PRs awaiting the other agent's review per author)?
5. What would you add to, or remove from, section 2 and section 3?
6. Which tool in section 4 would you build first, if any?
