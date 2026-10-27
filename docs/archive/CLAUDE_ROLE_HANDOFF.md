# Taking over the Claude seat: handoff (12 October 2026)

For whoever replaces the Claude terminal session (`claude-03bab66e-4d93-4d6b-ac7f-d1362fa70db3`) on this project: a human, a fresh Claude, or
another agent. It is a snapshot of the process and of the open work at 00:20 AUSEST on 12 October. `HANDOFF.md` is the branch checkpoint,
`AGENTS.md` the rules, `docs/PIPELINE.md` the pipeline map; this file is the practical "what is running, what is stuck, what to do first".
Everything here was true when written; verify against GitHub and the board before acting (state moves fast).

## 1. The setup in one page

* **Project:** Skyrunner, a Godot 4.7.2 pure-GDScript game (`C:\Users\BarryBee\Documents\ChatGPT\skyrunner`, repo `jawaman14/skyrunner`).
  The shared MCP server lives in a separate repo, `jawaman14/skyrunner-mcp` . The committed `.mcp.json` starts it through
  `tools/mcp/launch.py`, which installs the package from the **pinned git commit** (`SERVER_COMMIT`). On this machine the working `.mcp.json` is an
  uncommitted local override that runs the sibling checkout `C:\Users\BarryBee\Documents\ChatGPT\skyrunner-mcp` with `uv run --project`: here,
  fast-forwarding that checkout changes the active server; on any other clone only a pin bump (a game PR editing `SERVER_COMMIT`) does.
* **People:** the owner (BarryBee) decides and does the human release gates; **Claude** (this seat) integrates: triage, review, merge, notes for
  the owner; **Codex** leads UX/UI and authors a lot of work, and is the independent reviewer of Claude's PRs. **Bonsai** (a local 1-bit 27B
  model on LM Studio) does cheap first-pass work only. Codex has two forms: a desktop session (acts when the owner prompts it) and *woken
  turns* (`codex exec resume`) started by the wake watcher.
* **The owner's rules that matter most** (all in `AGENTS.md`; quotes in `HANDOFF.md` "Owner decisions"):
  1. *Everything through the MCP*: board reads, claims, notes, Godot imports/tests/smoke, and **all GitHub reads and writes** go through the
     `skyrunner` tools. Never `gh`, never write the board's database directly, never start Godot from a shell beside it. If a tool is
     missing, add it to skyrunner-mcp. (This session broke the rule several times with `gh` helpers and has been converting them; see 4.)
  2. *Merging is the agents' job*: "you dont need to discuss with me what needs to be merged or not that is you and codex job to see if its
     ready too". Needs: the other agent's review of the exact head, green CI on that head, every review thread answered. **Human release
     gates and owner decisions (issue #326) are never merged or ticked by an agent.**
  3. *Keep the Codex wake watcher on constantly* (never pause it). Codex leads UX/UI; Claude reviews.
  4. *Be careful with the LM Studio server* (the owner's large model is on it): use only an already-loaded model, never load or unload
     unless the owner says so.
  5. Output should be concise; lead with the result. Notes on the board are short (AGENTS.md compact-notes rule).
* **Scores:** `docs/COLLABORATION_SCORE.md` is the owner's ledger (Claude and Codex have each been docked for specific failures). Report
  honestly; do not game it, and do not claim any award that is not a row in that file.

## 2. Daily loop (what the seat actually does)

1. `skyrunner_collaboration_start`, then read your notes **incrementally**: `skyrunner_collaboration_read recipient=claude after=<cursor> limit=20`
   (keep `next_cursor`; an unbounded first read returns the whole history and is huge). The doorbell Monitor (section 3) prints new note ids.
   Claim paths before editing; use your own linked worktree.
2. `github_merge_queue` (what is ready) and `github_pr_triage` (everything open). Under the WIP limit (3 PRs awaiting review per author) most
   drafts stay draft until review capacity frees.
3. For a PR you may merge: author merged `main` in (`python tools/collab/sync_shared.py --commit` resolves the shared files
   HANDOFF/PROJECT_STATUS/test_lanes; the `--baton theirs` option for a PR that is not the baton holder exists only in the open PR #332), the other agent reviewed the exact head, CI green (`github_pr_wait`), then `github_pr_merge` with the
   full expected sha and `reviewed_comments`. Reply to each bot thread **in-thread** (`github_pr_comment` with `reply_to_comment_id`), not as an
   issue comment: the guard counts only thread replies.
4. After every merge: one line on #326 ("Merged #n (`sha`): what, what was verified, what was not"). Final summary for the owner at the end.
5. Re-arm the doorbell Monitor every 30 minutes (below); check that the background processes are alive.

## 3. What is running (all background; all must stay up)

| Process | Command (from `C:\Users\BarryBee\.claude-worktrees\...`) | What it does |
|---|---|---|
| Codex wake watcher | `python wake-codex\tools\collab\wake_codex.py watch --session 01a1295c-4302-7ac0-b59d-248e3fa193ec --cursor-file %TEMP%\wake_rt_cursor --cooldown 90 --max-per-hour 40 --interval 20 --timeout 1500 --codex-config windows.sandbox="unelevated" --alerts-file %TEMP%\skyrunner-alerts-codex.md` | Starts a Codex turn (`codex exec resume`) when a note addressed to codex arrives or the alert digest changes; fixed prompts only (ids/path, never note text), OS file lock, cooldown + hourly cap. This is the complete command as recorded on 12 Oct; if the process has died, start it once with exactly this line. **Never pause.** |
| Alert feed (LEGACY, uses `gh`) | `localworker\tools\local_llm\alerts.py watch --for codex --interval 90` | Decides alerts by code (review needed, CI failed, threads waiting, sync needed, merged), batches (min gap 600 s), writes the digest the wake reads. The running copy calls `gh`: see the note below. |
| Review relay (LEGACY, uses `gh`) | `postreview\tools\collab\relay_reviews.py watch --root <game> --interval 30` | Posts Codex's `REVIEW #n@sha7 approve|changes|comment: ...` board notes to GitHub, labelled "RELAYED", verbatim. The running copy calls `gh`: see the note below. |
| Claude doorbell | Monitor: `collab-tools\tools\collab\notify.py watch --recipient claude --interval 15 --cursor-file %TEMP%\claude_monitor_cursor` | One event per new note to claude. Expires every 30 min: re-arm (Monitor, timeout 1800000). |

**The two legacy processes break the owner's rule** (all GitHub through the MCP; no exception has been authorized). They are older copies loaded in
memory; the files in PR #335 / #336 call the MCP instead but need skyrunner-mcp PR 7 (`github_pr_states`) merged and the server updated first. They
should be **stopped now** (two PIDs each: the venv launcher and the python it starts): in PowerShell,
`Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'relay_reviews|alerts\.py' } | ForEach-Object { Stop-Process -Id $_.ProcessId }`.
The session that wrote this was blocked by its permission classifier from doing so, so the owner or the new seat must. After they are stopped, post
Codex's `REVIEW #n@sha7 ...` board notes yourself with `github_pr_review` (reviewer `codex-relayed-by-claude`, body quoting the note, labelled
RELAYED) and read the review bundle/threads with `github_pr_view`. Do not delete the worktrees `wake-codex`, `localworker`, `postreview`,
`collab-tools` while their processes run (their paths are the command lines).

## 4. State of the work at handoff

**Merged today (11 Oct–12 Oct):** #318 (autopilot approach route height), #324 (tutorial footer clickable; chips made non-focusable after the bot's
P1), #325 (compact board notes), #330 (board-only dashboard), #331 (docs/PIPELINE.md), plus the earlier startup/room/leave tests (#306-#309),
#310, #311, #312, #313, #315, #317. Landing notes are on #326.

**Immediate action needed:**
1. **skyrunner-mcp PRs 6 and 7 are approved and green but unmerged.** PR 6 `1a0504a` (local_llm tools), PR 7 `c8844ed` (`github_review_packet`,
   `github_pr_states`); Codex approved both (board notes 258/259). The `skyrunner` MCP tools only reach the game repo, so merging them needs
   `gh` on that repo, which the owner's rule forbids. **The owner was asked** (a) allow `gh` once, or (b) add a `repo` argument to
   `github_pr_review`/`github_pr_merge` in skyrunner-mcp (recommended; it is its own PR). Do not merge until the owner answers.
2. After PR 7 merges: update the server checkout beside the game (fast-forward `main`), bump the game's pin (`tools/mcp/launch.py`) and the expected
   tool count in `tools/mcp/test_connection.py` (37 -> 41+) in a game PR, restart relay + alert feed from the MCP-based code, then verify with
   `relay_reviews.py once --dry-run`.
3. **Owner action pending:** one line in Codex's `config.toml`, `[mcp_servers.skyrunner.tools.github_pr_review] approval_mode = "approve"`,
   so woken Codex turns can post reviews themselves (until then the relay does it). Documented in `tools/mcp/JOIN.md` (PR #340).

**Open PR stack (28 open; `github_pr_triage` is the live view).** Mine, all draft, waiting on review capacity: #340 (JOIN.md), #339
(PIPELINE_DISCUSSION), #336 (local_llm worker + alerts), #335 (relay + mcp_client), #334 (chapter audit), #333 (human-gate scripts), #332
(sync_shared `--baton theirs`, not yet on main), #323/#319 (strip payload, STRIPS.md), #321 (score rows), #320 (working plan), #305/#304/#303/#300 (older
branches synced to main; #303/#305 are Claude-desktop work), #337/#338 (Bonsai first drafts, duplicates: finish #338, close #337). Codex's
stack #244-#276 (11 PRs, 38-79 commits behind) was synced once at the top (#276, 23 hunks) but is **unreviewed and undecided**; it needs
Codex's review plus an owner decision on whether to land it as one.

**Pipeline gaps (see `docs/PIPELINE.md` for the full retrospective):** the review gate is the bottleneck (Codex acts only when woken); woken
Codex turns have no GitHub network, cannot call `github_pr_review`, cannot take claims reliably, cannot write inside a linked worktree's `.git`
(e.g. `ORIG_HEAD.lock`), and cannot open the Godot machine lock file. Compensations: the alert digest carries what it needs (review bundle
path, thread text), Codex answers in the exact `REVIEW #n@sha7 ...` note form, and Claude relays/merges. Where a Codex PR needs a trivial fix
and Codex is blocked, Claude may make it (as on #324) and says so on the PR and the board.

## 5. How the tools work (and traps)

* **Godot:** `python tools/collab/run_locked.py import|test <filter>|status --write` (from a merged-main worktree; `collab-tools` today).
  One Godot job at a time machine-wide. The full suite is ~13 min (1,114 tests, 761 s clean). A filtered run can show order-dependent
  artifacts: confirm by running the whole file. A stale `docs/PROJECT_STATUS.md` makes tests refuse; regenerate with `status --write`.
* **GDScript:** warnings are errors; give variables explicit types when the right side is a Variant; new random draws go on their own RNG
  stream; new switches register in `scripts/sim/switches.gd`. See `CLAUDE.md`.
* **Sync:** `tools/collab/sync_shared.py` (merge `origin/main` into a branch and auto-resolve HANDOFF Log, PROJECT_STATUS, test_lanes;
  `--baton theirs` when the branch is not the baton holder: only in open PR #332). Real conflicts elsewhere need a human-grade merge.
* **Merge guard:** `github_pr_merge` needs the full 40-char head sha, green CI on it, no unanswered threads, a review by the other agent. Review
  markers live in GitHub review bodies (`<!-- skyrunner-review agent=... verdict=... head=... -->`; the server writes it).
* **Local model (Bonsai) via LM Studio** (`SKYRUNNER_LOCAL_LLM=http://169.254.83.107:6456`): only loaded models, native `/api/v1/chat`,
  `reasoning` off by default, one request at a time (OS file lock), input budget follows the loaded context (262,144 tokens set by the
  owner, cap 400,000 chars). A second Bonsai instance for Codex's alerts is not loaded (the owner loads it). Its output is a draft; never
  trust it to decide anything.
* **Gotchas learned the hard way:** generated scripts with `\n` in Python strings via shell heredocs corrupt easily (use the Write/Edit tools);
  a test with an early-bound default argument started a real Codex; "done" notes must be true (note #184 was wrong); the board channel
  can be quiet while notes arrive, so keep the Monitor doorbell; do not probe unloaded LM Studio models; an agent reviewing its own PR is refused
  by the server, by design.

## 6. Where things live

```
skyrunner/                         the game repo (this checkout is Codex's dirty primary tree: do not edit/clean it)
  AGENTS.md  CLAUDE.md  HANDOFF.md the rules, project notes, and the durable branch checkpoint (every PR logs in HANDOFF)
  docs/PIPELINE.md                 the pipeline map and the 11 Oct retrospective
  docs/COLLABORATION_SCORE.md      the owner's ledger
  docs/archive/CLAUDE_ROLE_HANDOFF.md      this file
  tools/collab/                    sync_shared, run_locked, board_status, notify, wake_codex, dashboard, (PR #335: relay_reviews, mcp_client)
  tools/local_llm/                 (PR #336) worker.py, alerts.py, README.md
  tools/mcp/                       the pinned launcher, JOIN.md (PR #340), COLLABORATION.md
~\.claude-worktrees\<name>\        my linked worktrees, one per branch (see section 7)
skyrunner-mcp/                     the MCP server repo (separate); worktrees mcp-packet (PR 7), mcp-local-llm (PR 6)
```

The primary checkout holds the owner's/Codex's uncommitted files (`dist/`, `dsm5-site/`, `usb-*`, `addons/codex_workbench/`, `.codex-remote-attachments/`,
`opencode.json`, AGENTS/CLAUDE edits). They are not Claude's to move or delete; ask the owner before touching them.

## 7. Worktrees (cleaned up 12 October)

Removed (clean, fully pushed, nothing running from them; branches still on the remote): agents-collab, autopilot-approach, bump-mcp-pin,
collab-score, csv-import, dash-main, note-format, pipeline, startup-leave, startup-picker, startup-room, strip-feasibility, and the two
`.build/` verification worktrees. Kept because something runs from them: **wake-codex, localworker, postreview, collab-tools**. Kept because their
PRs are open: mcpjoin, pdisc, chapteraudit, humangates, sync-baton, strip-payload, score-row, working-plan, strips-doc, p303, p304, p305, s300,
stack, mcp-packet, mcp-local-llm, skyrunner-mcp-gh and -shared, role-handoff (this one). Left alone because they are not mine: `.local-llm-*` (Bonsai
drafts for #337/#338), `dashboard` (2 uncommitted files, superseded by the merged #330), `phone-ui`, `pr307-review`, `s324` (branches never pushed under
that name), and everything under `~\.codex\worktrees\`. Remove a worktree only with `git worktree remove <path>` (it refuses if dirty), never by
deleting the folder.

## 8. First hour checklist for the new seat

1. Read `AGENTS.md`, `CLAUDE.md`, `HANDOFF.md` (owner decisions), `docs/PIPELINE.md`, this file. Open #326, #327, #328, #329.
2. `skyrunner_collaboration_start`; read notes addressed to claude; check claims. Arm the doorbell Monitor.
3. Confirm the wake watcher and the doorbell in section 3 are alive (`Get-CimInstance Win32_Process` filtered on `claude-worktrees`); if the watcher is dead start it with the exact command in section 3, once. Stop the two LEGACY `gh` processes (relay, alert feed) as described there. Do not run a second copy of anything.
4. `github_merge_queue`, then work section 4 top to bottom. Start by asking the owner for the decision on the server-repo merge path.
5. Post what you did on the board in one compact note per event; keep #326 landing lines one per merge.
