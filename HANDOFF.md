<!-- standalone-mcp -->
MCP implementation: [jawaman14/skyrunner-mcp](https://github.com/jawaman14/skyrunner-mcp). This game contains only the pinned connection launcher; make server changes in the separate repository.

# Handoff: Claude ⇄ ChatGPT (Codex) relay

**Mode: relay.** The owner uses one AI until its tokens run out, then the other. Neither agent can see the other's
chat, and a session can end without warning: keep this file's baton current in every commit. The planning inputs
are the owner's [work split](docs/AGENT_WORK_SPLIT.md) and [allocation tracker](docs/AI_WORK_ALLOCATION.md)
(tiers A/B/C, hard merge rules, lanes). If two sessions ever overlap on one checkout, use the MCP board
([tools/mcp/COLLABORATION.md](tools/mcp/COLLABORATION.md)) and separate worktrees.

`AGENTS.md` (conventions, commands, layout, lanes) is the rules file for both AIs; `CLAUDE.md` imports it. Code facts live
in the code and `docs/DESIGN.md`; release evidence in `docs/PROJECT_STATUS.md`; the queue in
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
| **Holder** | Codex cloud checkpoint; Claude remains the integration owner |
| **Task** | Package A (road and loading access), one PR per slice from `main`. Merged: #302 (`1156136`, nearby road connections after dead ends; #270 closed). This PR (#301): district overview Q-return fix (#271 replayed); `test_hq_action_review` 9/9, 8/1 with the fix reverted. #296 (employed opening) is merged. |
| **Branches / PRs** | **#301** `claude/district-overview-back` (ready, CI + review pending). **#304** docs-only wording after #296 (draft). **#300** lobby layout + screenshot matrix (needs a human look). Held: #244, #247, #269, #253. |
| **Next step** | Merge #301 on green with Codex's review read. Then, one PR each from `main`: #265 (villa), #267 (FRM approach, creates `tools/road_access_components.gd`), #268, #272, #274, #275, #276; re-run `tools/logistics_routes.gd` at the end. Close #271 after #301. Then P05 (reference action-preview screen, Claude), #97 entry-path tests (Codex), trim `docs/ROADMAP.md` to the lane queue, gate register in PROJECT_STATUS.md. |
| **Codex cloud task** | #97 join/seat startup tests on `codex/startup-entry-tests`, based on merged main `909efaf` (#301). Four new loopback entry-point regressions; tests/status/handoff only. Claude: review this branch and run current-head CI; the broader #97 matrix stays open. Preserve the Package A work listed above. |
| **Watch out** | Wait for Codex's review to finish before merging; its comments arrive minutes after CI. Regenerating `docs/PROJECT_STATUS.md` conflicts the next PR on that line: merge `main`, run `godot --headless --import` (a fresh worktree needs it), then `project_status.gd -- --write` and `--check` before pushing. Don't `pkill -f <name>`. The MCP board is per-machine; HANDOFF.md carries state between AIs. |

## Taking over (checklist for the incoming AI)

1. Read the MCP collaboration board, verify your checkout, then `git fetch origin`, `git status` and
   `git log --oneline -8`. Use your own linked worktree; never check out a branch under another active agent.
   - If the branch has commits **newer than the baton's last checkpoint**, the previous AI was cut off after
     committing: read those commits (messages and diff) before anything else.
   - If the branch or PR is merged or closed, start the next step on a new branch off `main`.
   - Uncommitted work from a cloud session is gone. On the owner's machine, check `git status` and
     `git stash list` for leftovers; inspect them, don't discard them.
2. Check the PR's CI (the GitHub UI, `gh pr checks`, or `github_ci_status` from `tools/mcp/`).
3. **Re-verify, don't trust:** run the focused tests for the area you are about to touch
   (`./tools/test.sh <filter>`). A baton describes what was true then.
4. Read **Owner decisions** and **Open questions**.
5. Claim the task's explicit paths on the shared board before editing. Update the baton on your own branch
   with your task and preserve other agents' active tasks in notes; continue from your assigned next step.

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
  5. **Before merging a PR, read its review comments** (and your notification queue). Codex's automated review lands
     about two minutes after CI goes green, and #295 was merged with three valid findings unread (all fixed in #297).
     `github_pr_merge` now refuses while a review thread has no reply.
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

- **2026-10-10 (cloud session):** Begin collaboration using the documented Claude/Codex split. Claude is on the owner’s local computer; this cloud board is separate. Use published branches and committed handoffs across machines; local notes do not reach Claude’s board.

- **2026-10-11:** Claude and Codex may collaborate simultaneously through the same local MCP implementation.
  Use shared file claims, persistent notes, per-checkout Godot locking and separate linked worktrees.

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

- **2026-10-11 — Claude, seat-picker cancellation coverage (#97, own initiative while Codex was out of credits):** On
  `claude/startup-picker-tests` from main `e384241`, added `tests/test_startup_picker.gd` (socket lane). Through the real
  `Main.start` / `_join` / `_enter_game` against a real running-game host, a guest who joined without a seat reaches the
  live `SeatPicker` and leaves it: (1) the link is closed, nothing of the join is left (no picker, client, room, desk,
  3D seat, voice, host service or game), exactly one Lobby is shown, `args.new` is false, the host sees the guest go
  and no seat is held; (2) a late `role_changed` or claim on the closed link, before and after the deferred frees,
  opens nothing and reaches no seat, and the link and picker are released; (3) leaving with a claim already sent
  leaves no guest UI and the seat is `ai` or `reserved` (the host holds a dropped guest's seat for `Seats.HOLD_S`),
  never `human`. No production change. Whether a deliberate Leave should hold a granted seat like a dropped
  connection is an open design question, so test 3 pins only the safe invariants. Windows Godot 4.7.2: focused 3/3,
  socket lane 147/147, docs 2/2, status current, hygiene OK. Linux and the full suite are left to CI. #97 stays open
  (SeatPicker-cancel by controller B button, reload restoring a waiting-room seat choice, and the two-machine
  checks remain).

- **2026-10-11 — Claude, waiting-room startup coverage (#97, assigned by Codex):** On `claude/startup-room-tests`
  from main `909efaf`, added `tests/test_startup_room.gd` (socket lane): through the real `Main._open_room` /
  `RoomScreen._start` / `_cancel` / `Main.start` paths, (1) a host who keeps the pilot seat flies with the room's own
  server and beacon, one voice pipeline, seat held; (2) a host closing the room leaves no network services, frees the
  server and beacon and the port can be listened on again; (3) a room that cannot listen returns to the lobby with
  no server, beacon or game; (4) a guest leaving the waiting room closes and releases its link and the host sees
  them go. Note for future tests: `await process_frame` resumes before that frame's delete queue is flushed, so wait
  more than one frame before asserting a `queue_free`d node is gone. Windows Godot 4.7.2: focused 4/4, socket lane
  137/137, docs 2/2, project-status current, hygiene OK. No gameplay, `main.gd`, RNG, save or wire changes; Linux and
  the full suite are left to CI. #97 stays open. Overlaps #306/#307 on the PROJECT_STATUS count and this Log: regenerate
  the status after whichever merges last. Next (read-only, per Codex): reproduction plan for the stale `main._mp`
  reference when `_leave` frees an open multiplayer menu without `close()`.

- **2026-10-11 — Codex, Claude review follow-up on #307:** Claude independently reviewed `f544bcf` with no blocking findings, reran host startup 3/3 and docs 2/2, and checked service/session ownership and teardown. All 13 CI jobs at that head passed. Adopted the real `HostServer.host_claim` API and added host-name and controller/pilot seat ownership assertions; focused host tests still pass 3/3 without script/parse errors. Fresh CI is required for this follow-up. Claude's next assigned slice is waiting-room pilot start and host/guest cancellation/listen-failure regressions on a separate main-based branch; #97 remains open. No merge or human gate completion.

- **2026-10-11 — Codex, host startup coverage:** On `codex/host-startup-tests` from main `909efaf`, added three real entry-point tests for explicit direct hosting, implicit co-op hosting, and the waiting-room host choosing the controller desk. They check one authoritative server/session, one voice pipeline, and one server-owned beacon; the room-to-desk transition reuses its listener and beacon. Registered the file in the socket lane and refreshed the declared-test inventory. Windows Godot 4.7.2: focused host startup 3/3, socket lane 136/136, docs 2/2; project-status current and diff hygiene pass. No gameplay, RNG, save or wire changes. Full suite on this branch and human gates remain unverified; #97 stays open. Separate #306 at `b24b239` has all 13 CI jobs green. Claude terminal MCP connection is confirmed by shared-board acknowledgment #7; primary dirty checkout preserved. Next: independent Claude review and current-head full CI before integration.

- **2026-10-10 — Codex cloud, startup coverage:** Added four real loopback tests through Main.start/_join/_enter_game/_seat: password-bearing direct co-pilot join, unseated late join plus host-confirmed controller claim, waiting-room host start, and explicit 3D co-pilot seating. Five startup tests pass; socket lane 137 pass; docs 2 pass; generated-status and hygiene checks pass. No gameplay, Session, RNG, save or wire-format changes. Regenerated only the declared-test inventory. Published branch `codex/startup-entry-tests`, implementation commit `a1a4b91`, base `909efaf`. Draft PR creation was refused by GitHub API (`Forbidden`); Claude can create it locally with title “Test real multiplayer join and seat startup transitions” and the validation above. Claude review/current-head CI and remaining #97 entry paths are still required. Known Godot shutdown diagnostics remain; physical voice/controller/two-machine gates are unperformed. This cloud board cannot reach Claude's local board; use this committed handoff.

- **2026-10-11 — Codex, CI follow-up:** Windows MCP CI passed at a73f8a4. Linux exposed a test assumption:
  GNU timeout starts successfully and exits 127 for a missing child, while Windows raises a spawn error.
  The regression now disables the wrapper to exercise the intended startup-error cleanup on both hosts.
  Cancellation also tolerates a POSIX process group exiting between its state check and signal, with a
  focused exit-race regression. Re-run Windows/Linux MCP jobs on the updated head; prior success is stale.

- **2026-10-11 — Codex:** Extended #298 for the owner's simultaneous collaboration request. Added atomic
  shared path claims with renewal/expiry, durable recipient notes/cursors, startup checkout/revision/source
  fingerprint, unique logs, cross-process Godot locks (including introspection), and public GitHub reads
  without credentials while writes refuse before dispatch. Added Claude/Codex startup instructions and
  updated the old relay wording. Local Windows checks: 12 runtime methods, 7 coordination methods and
  2 guard methods pass; Godot docs 2/2 via actual MCP. Two installed stdio clients saw the same board and
  Claude-addressed note; public issue #97 read succeeded. Actual Claude participation/client reload and
  fresh Linux CI are not yet verified. Primary dirty game files preserved; local connection settings
  contain no tokens. No PR merged, GitHub write tool exercised or human release gate marked complete.

### 2026-10-11 — Codex (MCP Windows integration)
- Reproduced Windows startup failure on missing SIGHUP; fixed signal registration and process-tree cancellation/deadlines.
- Portable Python worker removes Bash dependency from tests and refuses tests after import errors. UTF-8 logs preserve per-file counts.
- Seven real runtime/worker/stdio tests pass, plus seven guard regression cases. Added Windows/Linux MCP checks to the beta workflow.
- Through actual MCP calls: status current, import and docs 2/2, zero-match filter correctly FAILED, smoke 1800 SMOKE OK.
- Full game suite and Linux runtime not run locally; CI must establish Linux evidence. Human gates unchanged.
- Next: review #298 with #293, then rebase #298 onto main after #293 merges. Keep primary crew-map changes untouched.


### 2026-10-11 — Codex (MCP safeguards)
- Reject zero-test success, unknown mergeability, and empty CI job lists.
- Added dependency-free AST regression checks: seven cases across two test methods pass.
- Based on #293 at d276eefa; primary crew-map checkout preserved.
- Godot import, project-status check and docs tests (2/2) passed. Full suite and MCP protocol integration unverified. No PR merged.
- Next: complete docs/status checks, publish a draft dependent PR, then rebase after #293 merges.


### 2026-10-10 (latest) — Claude (review findings on #295)
- Codex's automated review of #295 posted three findings two minutes after CI went green; I merged without reading
  them. All three were valid: (P1) the restored autopilot intercept overwrote the real waypoint, so a route behind
  the aircraft cascaded and "arrived" kilometres from the destination; (P2) `known_radar_zones()` read live police
  sensor state, leaking the secret aerostat to the runner's route; (P2) `demand()` dropped staffed roles whose target
  fell to zero. Fixed in #297 with tests that fail on the old code (e.g. the aircraft ended 11,843 m off).
- Process: the pre-push checklist now includes reading review comments before merging, and `github_pr_merge` refuses
  while a review thread has no reply.

### 2026-10-10 (later) — Claude (backlog actions)
- **Merged:** #294 (integration of #227–#231, #235–#240, #245, #248, #258; full CI green) and #295 (restores the
  autopilot intercept, payroll demand and radar-aware routing deleted by `d91975f`, plus `known_radar_zones()` and tests).
  Both squash-merged after all 11 jobs passed, pinned to the verified head SHA.
- **Opened #296:** the employed opening, replaying #250/#251/#252/#255 on `main` (they only conflicted because they
  needed #229/#230 from #294). Focused tests and the fresh-story smoke pass; full CI pending.
- **Closed:** the 14 source PRs of #294 and 7 docs PRs (branches kept); issues #92, #99, #102, #117, #118, #139, #158, #174.
  #97 stays open (`_join()`/`_seat()` untested).
- **CI failures I caused, now in the checklist:** a dead link to a dated report (#294) and a stale
  `PROJECT_STATUS.md` count (#295). A restored test (`test_hot_route_penalty…`) had a zone the route never crossed;
  rewritten. #245 depended on #244's tests: kept only its own.
- **MCP server:** `github_pr_update(ready_for_review)` failed in cloud sessions (GraphQL is blocked there); fixed to use
  the CCR route, and a guarded `github_pr_merge` was added.
- **Not verified:** QRY/PNR circling in actual flight; human gates unchanged.

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
  - `tools/mcp/skyrunner_mcp.py` (since moved to the separate skyrunner-mcp repo, see top): an MCP server with game tools (tests, smoke, screenshot, balance, tool scripts,
    command/switch introspection) and GitHub tools (PR triage, CI status/logs, PRs, issues, branch cleanup).
    Codex can call it too, from any MCP client. All 24 tools were exercised over stdio except the GitHub write
    tools (PR create/update/close, comments, issue writes, branch deletion), which have not been run.
  - This file and `AGENTS.md`.
- **Review findings** (read from source; not yet fixed; a host-backlog finding was withdrawn: `read_lines` caps the buffer at `MAX_LINE + 1` and any extracted line leaves at most `MAX_LINE`, so a well-behaved client can't trip the drop):
  1. `scripts/ui/command_presentation.gd` `poll()` calls `link.snapshot()` every frame, and `station_app.gd`
     `_process` already builds one. On a `LocalLink` (hot-seat/AI desks) that is two full `Snapshot.build` calls
     per frame instead of one. Pass the frame's snapshot into `poll()`.
  2. `scripts/net/net_client.gd`: `read_lines` caps the buffer at `MAX_LINE + 1`, but only the host drops an
     oversized frame. A client receiving a line over 1 MiB stops reading forever, silently. Mirror the host's
     `buf.size() > MAX_LINE` check and close with an error.
  3. The rackets "turn" preview (`action_descriptions.gd`) repeats `Rackets._recruit`'s wage formula with a
     literal skill of 0.3; the two can drift apart. Expose one helper.
  4. `PhoneCalls._calls` keeps every call forever and is saved; it's needed for source de-duplication. Low impact,
     but cap the history or store only source IDs for terminal calls.
  5. Docs:
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
