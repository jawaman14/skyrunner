# Handoff: Claude ⇄ ChatGPT (Codex) relay

The owner works with **one AI at a time**: Claude Code or ChatGPT/Codex runs until its tokens run out, then the
other one takes over from wherever the first stopped. A session can be **cut off mid-task with no warning**, so
this file is kept current *while* working, not written at the end. It is the only channel between the two AIs:
neither can see the other's chat.

`CLAUDE.md` (conventions, commands, layout) applies to both AIs; `AGENTS.md` points Codex here. Code facts live
in the code and `docs/DESIGN.md`; release evidence in `docs/PROJECT_STATUS.md`; the long-term queue in
`docs/ROADMAP.md`. Older handoffs: [docs/HANDOFF_HISTORY_2026-09.md](docs/HANDOFF_HISTORY_2026-09.md).

## For the owner: switching AIs

Paste this into the new AI:

> Continue the Skyrunner work (github.com/jawaman14/skyrunner). Read HANDOFF.md and follow its "Taking over"
> checklist, then carry on from the baton's next step. If HANDOFF.md on `main` has no "baton" section, read it
> from the branch of the newest open pull request instead.

The baton usually lives on the working branch until that PR is merged. Merging finished PRs promptly keeps `main`'s
copy current.

If you decided anything in the old AI's chat that isn't in **Owner decisions** below, tell the new one; it will
write it down. Nothing else is needed after a cut-off: the baton says where work stopped.

## The baton (overwrite this section; don't append)

| | |
|---|---|
| **Holder** | Claude, 2026-10-10 |
| **Task** | Carrying out BACKLOG.md's four approved actions |
| **Branches / PRs** | Docs: `ccr-958eacf7-ugmwgs` / #293. Action 1: `claude/restore-lost-fixes` / **#295**. Action 2: `claude/integrate-clean-prs` / **#294**. All draft, CI pending. |
| **Done** | (4) closed #92, #99, #102, #117, #118, #139, #158, #174 (#97 stays open). (1) PR #295 opened: restored fixes, focused tests pass. (2) PR #294 opened: 14 PRs replayed onto main; the 16-PR preview passed 1,067/0. |
| **Next step** | When CI is green on #294 and #295: merge them (owner approved; they touch disjoint files). Then (3): create `claude/employed-pilot-opening` off the new `main` and replay #250, #251, #252, #255's code (each diff against its own base: `git diff origin/<base>...origin/<head>`). Expect conflicts in `pilot_app.gd`/`story.gd` to vanish once #229/#230 are in; skip #253's video. Then regenerate `docs/PROJECT_STATUS.md` and open a PR. |
| **Watch out** | A local full-suite run for #295 is in `scratchpad/restore_full.log` (not pushed). Check that merges delete nothing already on `main` (the `d91975f` failure). Keep branches `codex/gameplay-inspiration`, `codex/draft-completion-review`, `codex/gameplay-feature-audit` until their PRs are rebased. After #294 merges, close PRs #227–#231, #235–#240, #245, #248, #258 with a link to it. |

## Taking over (checklist for the incoming AI)

1. `git fetch origin`, check out the baton's branch, then `git status` and `git log --oneline -8`.
   - If the branch has commits **newer than the baton's last checkpoint**, the previous AI was cut off after
     committing: read those commits (messages and diff) before anything else.
   - If the branch or PR is merged or closed, start the next step on a new branch off `main`.
   - Uncommitted work from a cloud session is gone. On the owner's machine, check `git status` and
     `git stash list` for leftovers; inspect them, don't discard them.
2. Check the PR's CI (the GitHub UI, `gh pr checks`, or `github_ci_status` from `tools/mcp/`).
3. **Re-verify, don't trust:** run the focused tests for the area you are about to touch
   (`./tools/test.sh <filter>`). A baton describes what was true then.
4. Read **Owner decisions** and **Open questions**.
5. Put yourself in the baton as holder, commit and push it, then continue from **Next step**.

## Working rules (both AIs)

- **Checkpoint constantly.** After each working step: commit, push, and update the baton *in the same commit*. A
  cut-off then loses at most one step. `WIP:` commits are fine on your own branch. If you sense your budget or
  context running low, update the baton before anything else.
- **Pre-push checklist** (each of these has failed CI at least once; all run in under a minute with a warm import):
  1. `godot --headless --script res://tools/project_status.gd -- --check`. If you added or removed a test, chapter or export,
     run it with `--write` and commit `docs/PROJECT_STATUS.md`. CI checks it *before* any test, so every lane fails at once.
  2. `./tools/test.sh docs`: every relative link in the main docs must resolve, so don't link to a file you left out.
  3. New scripts: commit their `.gd.uid` files (run `--import` first).
  4. If you replayed or merged someone else's work, `git diff origin/main --stat` and look for **deletions** you didn't
     intend (the `d91975f` failure).
- **Say what is broken.** If a checkpoint leaves tests failing (mid-refactor), the baton says which ones and why.
- **One task = one branch off `main` = one draft PR into `main`.**
  - Stack on an unmerged branch only when the code really depends on it, and say so in the PR.
  - After a base is squash-merged, rebase its dependents onto `main` straight away.
  - Claude's cloud sessions may be pinned to an assigned branch name; the baton records which branch is in use.
- **Evidence goes in the PR body:** commands run, pass/fail counts, what was not verified. No new dated
  `docs/*_YYYY-MM-DD.md` reports. Regenerate `docs/PROJECT_STATUS.md`'s inventory block
  (`tools/project_status.gd -- --write`) when tests, chapters or exports change.
- **Respect the other AI's work.** Don't redo something logged as done. Don't silently revert it: if you think it is
  wrong, add an Open question for the owner and carry on with something else.
- **Finishing a task:** add a Log entry (newest first, at most ~12 lines: what merged or was pushed, how it was
  verified, what was not verified, what's next). Then set the baton to the next task, or to "idle".
- **Record the owner's decisions.** Anything the owner tells you that the other AI will need goes in Owner decisions,
  with a date.
- Keep your tool's co-author trailer on commits; the Log names the AI, so `git log` and this file agree.

## Owner decisions

- **2026-10-10:** Claude and ChatGPT/Codex work in relay (above). This file is how they hand over.
- **2026-10-10:** Approved BACKLOG.md's four proposed actions (restore lost fixes, integrate the clean stacks, rebase
  the employed opening, close duplicate/superseded/done issues).
- **2026-10-10:** Close the documentation PRs (#241, #242, #243, #246, #249, #264, #273). Done; branches kept.
- **2026-10-10:** Fold the documentation PRs into the game's design docs (DESIGN.md, ROADMAP.md and others) before
  any PR clean-up. Done: see the Log.
- **2026-10-10:** Both AIs should check the code and docs, not just add features. Codex's 4–10 Oct work was
  reviewed by Claude (Log below).

## Open questions

- **[Claude → owner, 2026-10-10] Rebasing the gameplay stacks.** The docs PRs are closed. Next, rebase the
  gameplay stacks onto `main` one at a time (the employed opening first, then logistics loading endpoints
  #235/#237/#265/#267/#268/#274/#276)? Each becomes one clean PR into `main`.
- **[Claude → Codex, 2026-10-10]** Review findings 1–3 (Log, 2026-10-10) are in code Codex wrote recently. If one
  is intended behaviour, say so here before anyone "fixes" it.

## Log

### 2026-10-10 — Claude (docs PRs closed)
- Closed #241, #242, #243, #246, #249, #264 and #273 at the owner's request. Each has a comment saying where its
  content now lives.
- No branches deleted: #250, #274 and #247 are based on three of them, and all three PRs are still open (checked).


### 2026-10-10 — Claude (documentation PRs folded into the design docs)
- **Read in full:**
  - direction and research: #249 (PLAYER_DIRECTION, GAMEPLAY_INSPIRATION, PLAYER_DIRECTION_DELIVERY);
  - implementation plans: #241, #242, #243;
  - audit: #246;
  - process records: #264 (PR_COMPLETION, EMPLOYED_OPENING) and #273 (DRAFT_COMPLETION_REVIEW).
- **Now in `docs/`:**
  - **DESIGN.md:** new §0, the owner-approved direction (core experience, employed start, economy and workers,
    turf, loss and recovery, world and campaign, multiplayer, product order, what to borrow from Warband,
    Schedule I and Cities: Skylines, playtest questions, open questions). Pillar 5. Up to 16 players. §7 now
    documents the wire contracts (#259/#260) and previews, and the snapshot rate is corrected to 20 Hz. §9 is
    marked historical. §21 points to the employed opening. New §46 covers jobs and their pay rules, checked
    against `jobs.gd` and `Session._grade`.
  - **ROADMAP.md:** "Where we are heading" (product order, with the overhaul queue as prerequisites). "Next
    implementation packages" A–D from #241, #242, #243 and #246, with #246's already-fixed network findings marked
    fixed. The #184–#200 "draft" wording is marked historical, and queue item 1 corrected.
  - **EMPIRE_MILESTONE.md:** marked as superseded where §0 differs (competitive play is no longer deferred).
  - **GUIDE.md:** §5.2 has the pay rules. **FEATURES.md / LIBRARIES.md:** the retired classic map, and the
    missing `docs/audio/` links replaced with the `tools/sound_demo.gd` command.
- **Left out on purpose:**
  - #264 and #273's per-PR disposition tables and test counts: dated, superseded by `github_pr_triage`.
  - #246's network findings 1–3: fixed on `main`.
  - Loading-audit counts from unmerged stacks, except as a range.
- **Verified:** `tests/test_docs.gd` 2/2 (links resolve). No code changed.


### 2026-10-10 — Claude (review of the 4–10 Oct work, MCP server, this handoff)
- **Verified:** `main` @ `f703a9f` plus the UID commit: full suite **1,027 passed, 0 failed, no script/parse
  errors** (`tools/test.sh`, 1,165 s, one process, Linux, Godot 4.7.2). CI on #293's first head: all 11 jobs green.
- **Pushed (#293, draft):**
  - Ten missing `.gd.uid` files committed.
  - `tools/mcp/skyrunner_mcp.py`: an MCP server with game tools (tests, smoke, screenshot, balance, tool scripts,
    command/switch introspection) and GitHub tools (PR triage, CI status/logs, PRs, issues, branch cleanup).
    Codex can call it too, from any MCP client. All 24 tools were exercised over stdio except the GitHub write
    tools (PR create/update/close, comments, issue writes, branch deletion), which have not been run.
  - This file and `AGENTS.md`.
- **Review findings** (read from source; not yet fixed):
  1. `scripts/ui/command_presentation.gd` `poll()` calls `link.snapshot()` every frame, and `station_app.gd`
     `_process` already builds one. On a `LocalLink` (hot-seat/AI desks) that is two full `Snapshot.build` calls
     per frame instead of one. Pass the frame's snapshot into `poll()`.
  2. `scripts/net/net_client.gd`: `read_lines` caps the buffer at `MAX_LINE + 1`, but only the host drops an
     oversized frame. A client receiving a line over 1 MiB stops reading forever, silently. Mirror the host's
     `buf.size() > MAX_LINE` check and close with an error.
  3. `scripts/net/host_server.gd` `_poll`: with at most 64 lines extracted per poll, a backlog of complete lines
     over 1 MiB trips the oversized-frame drop on a well-behaved client. Unlikely at current rates; check
     `extract_lines`' leftover for a newline before dropping.
  4. The rackets "turn" preview (`action_descriptions.gd`) repeats `Rackets._recruit`'s wage formula with a
     literal skill of 0.3; the two can drift apart. Expose one helper.
  5. `PhoneCalls._calls` keeps every call forever and is saved; it's needed for source de-duplication. Low impact,
     but cap the history or store only source IDs for terminal calls.
  6. Docs:
     - `CLAUDE.md`'s layout still said new handlers go in `session_commands.gd`; they go in `cmds_*.gd` since
       #284 (fixed in #293).
     - `docs/FEATURES.md:36` says `--map 0` is the classic island, but that map is retired.
     - `docs/ROADMAP.md` calls #184–#200 "prepared as draft continuations" right after saying #178–#209 are merged,
       and queue item 1 still points at #184.
     - `docs/FEATURES.md` and `docs/LIBRARIES.md` link a `docs/audio/` folder that never existed.
  7. Process: ~15 dated evidence reports in `docs/` duplicate PR bodies. The Protocol above (rule 4) stops new ones;
     consolidating the existing ones is optional.
- **Not verified:** human gates (exported Windows walkthrough, two-machine multiplayer/voice, controller,
  read-aloud) are unchanged and still open.
- **Next:** owner's answer on the PR clean-up question, then fix findings 1–2 and the doc errors in one PR.

### 2026-10-04 → 2026-10-09 — Codex (reconstructed by Claude from `git log`; Codex left no handoff)
32 commits on `main` (25 carry the Codex co-author trailer), +13.3k/−2.1k lines. Merged, in order:
- **Overhaul stack** (#119, #178–#209 and replacements #216–#222):
  - dialogue reliability/navigation;
  - read-only action previews with Cancel-first confirmation (`ActionDescriptions`, `ActionReview`);
  - menu focus and modal input;
  - station outcomes (`CommandPresentation`), map layers and a role-filtered feed;
  - site footprints/entrances with the Ctrl+F2 access overlay (`SiteLayout`, `SiteAccess`);
  - interaction occlusion, checked road surfaces and graded bridges;
  - enterable stash interiors and period props.
- **Features and CI:** incoming Family calls on the shared phone (#225); macOS export and launch CI (#223); the
  logistics route baseline (#226: all 99 audited truck routes fail checked access).
- **Reliability (#259–#263):** bounded TCP framing, per-connection command de-duplication, stale remote-input
  expiry, debris expiry, race feedback, fight-snapshot privacy.
- **#280–#292:**
  - parity-state restore and RNG scanner;
  - vegetation coverage;
  - host/voice lifecycle;
  - **command handlers moved into six `cmds_*.gd` domain modules (#284)**;
  - CI split into logic/simulation/presentation/socket lanes (#286);
  - shared seat screen (#285);
  - taxi coverage (#288);
  - worker map layer (#289);
  - failed-host cleanup (#290);
  - frozen parity fixture (#291);
  - generated `PROJECT_STATUS.md` inventory (#287);
  - faction-AI 40-seed study (#292, docs only).
- **Left open:** 38 PRs, mostly drafts stacked on each other (36 conflict into `main`). The largest gameplay stacks are logistics loading
  endpoints and the employed-pilot opening. Its own records are in `docs/PR_INTEGRATION_2026-10-08.md`,
  `docs/OPEN_PR_AUDIT_2026-10-08.md` and the other dated docs, plus each PR body.
