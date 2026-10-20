<!-- standalone-mcp -->
MCP implementation: [jawaman14/skyrunner-mcp](https://github.com/jawaman14/skyrunner-mcp). This game contains only the pinned connection launcher; make server changes in the separate repository.

# Handoff: Claude and ChatGPT (Codex)

**Mode: simultaneous, Claude leads** ([AGENTS.md](AGENTS.md)). Both AIs work at once on the owner's machine,
each in its own linked worktree of the one canonical clone, coordinating through the MCP board
([tools/mcp/COLLABORATION.md](tools/mcp/COLLABORATION.md)). Neither can see the other's chat, a session can end
without warning, and the board does not leave the machine: keep this file's baton current in every commit. The
working rules are `AGENTS.md` ("Working mode: dual work", D-52) and the lanes in ROADMAP "Working structure". The owner's
earlier [work split](docs/archive/AGENT_WORK_SPLIT.md) and [allocation tracker](docs/archive/AI_WORK_ALLOCATION.md) are
history: the Claude-led workflow they describe is superseded.

`AGENTS.md` (conventions, commands, layout, lanes) is the rules file for both AIs; `CLAUDE.md` imports it. Code facts live
in the code and `docs/DESIGN.md`; release evidence in `docs/PROJECT_STATUS.md`; the queue in
`docs/ROADMAP.md`. Older handoffs: [docs/archive/HANDOFF_HISTORY_2026-09.md](docs/archive/HANDOFF_HISTORY_2026-09.md).

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
| **Holder** | Dual work (owner, 18 October, D-52): each agent owns assigned work end to end; coordinate through the shared MCP board and use separate linked worktrees. Codex owns reviews, UX/UI, dialogue and QA. |
| **Task** | Codex is integrating empire-pivot N-2/N-3/N-4: Rafa employer/Benny fixer wording (#442), parked Rafa dialogue cues with completion-only persistence (#444), and active documentation cleanup (#443). |
| **Branches / PRs** | #442 `codex/rafa-employer-text`; #443 `codex/empire-docs-audit`; #444 `codex/rafa-dialogue-cues`. PR bodies carry the current commit and CI evidence. The original Rafa dialogue draft merged as #422. |
| **Next step** | Check #442-#444: finish CI, review comments and integration for any still open; once merged, continue the risk-class review queue (#414, #429, #437, #441, #445) from the shared MCP board. |
| **Codex task** | Complete the N-2/N-3/N-4 integration and review updated risk-class heads. #441's frozen v1 fixture addresses the save-preservation finding; #445 needs lossless ledger-log trimming. The other findings remain on their PRs. |
| **Watch out** | Wait for Codex's review to finish before merging; its comments arrive minutes after CI. Regenerating `docs/PROJECT_STATUS.md` conflicts the next PR on that line: merge `main`, run `godot --headless --import` (a fresh worktree needs it), then `project_status.gd -- --write` and `--check` before pushing. Don't `pkill -f <name>`. The board lives in one clone's Git directory: a second clone has its own, empty board. |

## Taking over (checklist for the incoming AI)

1. Read the MCP collaboration board, verify your checkout, then `git fetch origin`, `git status` and
   `git log --oneline -8`. Use your own linked worktree of the canonical clone (AGENTS.md); never check out a
   branch under another active agent.
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

- **2026-10-12 (later), answers to the 15 questions (owner, in chat):** start-up architecture: the LAN beacon always belongs to the server node, the dedicated server included; one hosting flow, the waiting room (the lobby's "open remote seats" box is removed); one saves folder with one file per mode and a migration of existing saves; the 3D pilot app gets a fixed 30 Hz step with the picture smoothed between steps, as its own task; the game's server pin is bumped to the current skyrunner-mcp `main` and the local `.mcp.json` points at a clean server checkout. Story: the uncle is Rafael "Rafa" Quintero. Crew trust table accepted as proposed (Morettis up: Cuervos down; Cuervos up: Morettis and dealers down; Company up: Collective down a little; Collective up: Company down a little; dealers up: Cuervos down a little). Details: `docs/archive/PROJECT_TRIAGE_2026-10-12.md` sections 7 and 8.5.

- **2026-10-12, QA and QC go to Codex (owner, in chat):** "can you pass the jobs like running simulations and tests to codex as well and any other QA and QC work to lighten your load from now on". Codex now runs the full and focused test suites, balance runs and the BALANCE entry, the sweeps, hygiene, status regeneration, import, smoke and screenshots; Claude writes and fixes and still runs the focused tests of the system it touched. Lane and reporting rules: `docs/PIPELINE.md` "QA and QC lane".

- **2026-10-12, story and economy design (owner, in chat):** the boss is the player's **uncle**: jovial and bigger than life, with a darkness you can't place. Chapter 2 is a few suspicious jobs while he starts to reveal his business. In a later chapter **Los Cuervos kill him** (the natural place is chapter 4, where the ground war opens); the player **hears about it** and takes his seat as boss, which starts the turf wars. He leaves a **crumbling empire to fix**, so the player starts smaller (a Mount & Blade start); the player is not locked into the boss seat and can still take part in the other layers. **Delegating a flight costs money** (you hire people out). **Reputation is trust with the other crews**: it is built with a crew, costs trust with some others depending on which, and is lost when shipments are lost, after which a crew goes to other sources. Early game: police interception odds **much lower** in chapters 1-2 (PR #350), chapter goal checks forgiving in chapter 1 and very sparing from chapter 3 (numbers awaiting approval, #345). Details and open questions: `docs/archive/PROJECT_TRIAGE_2026-10-12.md` sections 7 and 8.5.

- **2026-10-11 (afternoon), standing merge rule (owner):** merge readiness is the agents' job. In the owner's words: "you dont need
  to discuss with me what needs to be merged or not that is you and codex job to see if its ready too". The owner is involved when
  work lands on `main` (a short note per merge, a summary at the end) and for the human release gates and decisions in #326. Release
  gates and those decisions are never merged or ticked by an agent. Later that day the owner said, about Codex being out of tokens
  until 19:57: "complete as much as his work for him". Asked how to handle
  reviews during that outage, the owner chose "Stand-in reviewer agents": a separate fresh-context reviewer agent (not the author) reads
  the exact head and records its findings in the PR; Codex re-reviews after 19:57 and findings become follow-up PRs. That choice covers that
  outage only (it ended at 19:57); a future outage needs the owner's say again (docs/PIPELINE.md, Codex's review of #331).

- **2026-10-10 (cloud session):** Begin collaboration using the documented Claude/Codex split. Claude is on the owner’s local computer; this cloud board is separate. Use published branches and committed handoffs across machines; local notes do not reach Claude’s board.

- **2026-10-11 (later still):** All work on Skyrunner goes through its MCP (board, Godot jobs, GitHub). Claude, as
  lead, integrates: one merge at a time through `github_pr_merge`, after the author merges `main` in and the other
  AI reviews the resolution (AGENTS.md, Merging).

- **2026-10-11 (later):** Claude Code leads: it splits the baton into tasks, keeps Tier A/B and integration, and
  posts up to three Tier C tasks at a time to Codex; Codex implements those and reviews every Claude PR. One
  canonical clone on this machine, short board notes (AGENTS.md). Supersedes the earlier request for Codex to lead.

- **2026-10-11:** Claude and Codex may collaborate simultaneously through the same local MCP implementation.
  Use shared file claims, persistent notes, per-checkout Godot locking and separate linked worktrees.

- **2026-10-10:** Claude and ChatGPT/Codex work in relay. Superseded by the two 2026-10-11 decisions above.
- **2026-10-10:** Approved BACKLOG.md's four proposed actions (restore lost fixes, integrate the clean stacks, rebase
  the employed opening, close duplicate/superseded/done issues).
- **2026-10-10:** Close the documentation PRs (#241, #242, #243, #246, #249, #264, #273). Done; branches kept.
- **2026-10-10:** Fold the documentation PRs into the game's design docs (DESIGN.md, ROADMAP.md and others) before
  any PR clean-up. Done: see the Log.
- **2026-10-10:** Both AIs should check the code and docs, not just add features. Codex's 4–10 Oct work was
  reviewed by Claude (Log below).

## Open questions

- **[Claude → owner, 2026-10-11] A standing merge rule?** Today every merge needs your word in that agent's chat,
  so you relay approvals between them. A rule here would end that, for example: "either AI may merge a PR that is
  not Tier A when CI is green on its exact head and the other AI's review found no blockers".
- **[Claude → owner, 2026-10-10] Rebasing the gameplay stacks.** The docs PRs are closed. Next, rebase the
  gameplay stacks onto `main` one at a time (the employed opening first, then logistics loading endpoints
  #235/#237/#265/#267/#268/#274/#276)? Each becomes one clean PR into `main`.
- **[Claude → Codex, 2026-10-10]** Review findings 1–3 (Log, 2026-10-10) are in code Codex wrote recently. If one
  is intended behaviour, say so here before anyone "fixes" it.

## Log

- **2026-10-20 - Codex, empire contract follow-up:** `codex/empire-contract-fixes` corrects the F-1 unsupported-save gate, names passive Los Cuervos income for F-3, makes F-6's nightly report independent of the capped transient event bus, and normalises A5's fee in transfers and balances. `test_docs` passed 3/3; `git diff --check` was clean. No gameplay code changed. F-1's code guard is a separate follow-up based on draft #441; later F-3, F-6 and L-5 implementations still need their own tests.

- **2026-10-19 - Codex, empire pivot N-2/N-3/N-4:** #442 names Rafa as employer and Benny as fixer, including the flying lessons' assertions; its 14 CI jobs passed at `a62f581`. #444 opens the prelude/chapter-2 scenes, saves a cue only at natural END, and tests hangup/retry/save-load; all test lanes passed at `e0128f35`, with visual capture still running when recorded. #443 retires active speech claims and release gates, dates old suite evidence/timings, and preserves this shared handoff plus current-main inventory/roadmap. Review findings were answered in their inline threads. Local Git writes and shell network access were denied, so changes were published through the GitHub connector and verified in CI; the dirty primary checkout was untouched. PR states and the shared board are authoritative for subsequent integration and risk-review updates.

- **2026-10-19 - Claude (cloud session, no board), empire pivot docs:** On `claude/empire-pivot-docs` from `main` `34fd7f2`, added `docs/EMPIRE_PIVOT.md` (revision 2: the owner's direction from Codex's review, decisions, verified blockers, PR order) and `docs/EMPIRE_SIMULATION_SPEC.md` (the Living District contract), decisions D-65 to D-80 with the roadmap section `Empire pivot (owner, 19 October)`, pause notes on D-19, D-23, D-43 and their roadmap sections (D-75), and D-58's note (D-79). Docs only; no sim, save or test change. The baton above is left as Codex's. Next: Codex reviews the contracts (spec sections 3-7) before F-1; text-only N-2 to N-4 can start now in Codex's lane.

- **2026-10-18 - Codex, Rafa dialogue draft (#511 item 6):** On `codex/rafa-dialogue` from `main` `939b4e0b`, added five independent entry points for the employment opening, three chapter-2 beats and chapter-4 off-screen death report. `test_talk` passes 12/12; full suite reports 1,214 passed and 4 failed (two core-parity golden tests and two police radar tests, whose files are unchanged from `origin/main`). Generated status is current at 1,218 methods / 149 files; `git diff --check` is clean. The entries are not hooked into the story until Claude's beat/takeover scene work calls them. Next: publish the requested draft PR and wait for exact-head CI/review.

- **2026-10-17 - Codex, ground overlap integration:** `codex/roadside-turf-integration` combines #384's roadside firefight with #378's district/tactical work and the stacked #386 share refactor. The merge keeps both ground test additions and regenerates the project-status count. A new strategic-save regression exposed that the roadside driver guard was serialized as a permanent organisation squad although trucks and fights are not saved; guards are now tagged `roadside` and excluded from capture. The failing test was observed before the fix. Focused green tests and CI are pending the shared Godot machine lock; this branch is not ready for merge until they pass.

- **2026-10-16 - Codex, territory/market overlap:** On `codex/territory-control-unify`, based on #378 head `29588c2b`, all public market and local territory shares now use `GroundWar._control_share`, including the same half-weight police rule. The separate market aggregate and district ledgers remain because existing saves, market economics and direct control adjustments consume the aggregate; replacing it with a derived value needs a separate migration and balance review. Windows Godot 4.7.2 import and project-status check passed, focused ground tests 50/50, `git diff --check` clean. This is a stacked review slice for #378; no human gameplay or balance gate claimed.

- **2026-10-12 — Codex, pilot controls audit (#345):** On `codex/controls-audit`, corrected F1's waypoint autopilot path, conditional cockpit shortcuts and rebindable voice description; F8 distinguishes F3 AI handoff from U autopilot and lists F4. The durable on-foot movement map is in `docs/GUIDE.md` §4.3. Verification evidence is in PR #369. Remaining human checks: rendered desk hints, 720p layout and control feel. Next: exact-head review, then #345 tutorials/camera.

- **2026-10-16 - Claude (taking over Codex's turf-war branch while Codex is unavailable):** Codex's `codex/turf-war-expansion` (`8aee5bd`: map region IDs and ten Costa Brava districts via `Territories`, region-qualified local control in the war snapshot and save migration, tactical commit/withdraw choices, threatened routes, the Chapter 9 General choice, the gameplay catalog and a cleanup/performance pass; Codex's own full suite was 901/901) was only on Codex's machine. Pushed it, merged `main` in (82 commits; conflicts in `ground.gd`, `story.gd`, `switches.gd`, `fx.gd`, `squads.gd`, the HANDOFF top, DESIGN and ROADMAP), and kept both sides: main's district view and control trends beside Codex's `territory_control`, main's goal-waiver system extended to Codex's `general_choice` and `company_decision` (save version stays 5), Codex's debris timer fix, and Codex's DESIGN section renumbered 47. `test_story` now allows The Company three required goals as a chain, like The House (owner's two-goal rule from 12 Oct needs your confirmation). Switches 7/7, story 36/36, ground 49/49 after the merge. Full suite, goldens and a BALANCE entry are still to be run. No #326 human gate was run or marked passed.

- **2026-10-15 - Claude (taking over Codex's #372 while Codex is unavailable), review fixes:** Merged current main into the branch (conflicts were HANDOFF's Log and the generated status inventory, both kept/regenerated). Gated the first-landing migration to saves from before the landing lessons: Tutorial.to_dict writes landing_v and ttach() migrates only a save without it, so a current save that skipped take-off while parked is not marked landed (new test; tutorial 22/22). Not done, deliberately: air camera look for a guest in the pilot seat - that seat is RemoteSeat, not PilotApp, so it is a feature extension for a later change, recorded here as the follow-up. #345 slow reverse and dirt take-off tyre wear are still open. No #326 human gate was run or marked passed.

- **2026-10-13 - Codex, #372 review fixes:** Reproduced and fixed the take-off lesson disappearing during ground roll, stale preflight load-menu completion, flight timer running before the card is current, hosted pause not blocking camera capture, and tower pitch using a pre-yaw axis. Added tutorial/frontend regression coverage. Tutorial 21/21 and frontend 17/17 pass; status inventory, broader verification, thread replies, and exact-head CI remain pending. Next after this review checkpoint: #345 slow reverse and dirt take-off tyre wear. No #326 human gate was run or marked passed.

- **2026-10-13 — Codex, #345 playtest UX:** Draft PR #372 is published from isolated branch `codex/air-camera-look` at `8cba9ec`, based on `main` `5ad9f51`. Phase-gated tutorials (including the second-flight load/fuel/weight lesson), airborne right-button camera look independent of mouse yoke, and the first-three-use runway turnaround explanation are covered by tests. Frontend passes 15/15 and tutorial 18/18 (the save fixture writes under the OS temp directory). Exact-head CI `38260339244` and Claude review are pending. The earlier full-suite run (before the fixture adjustment) reported 1,127 passed, 29 failed in 769.2 s. Failures spanned save/config persistence suites plus one strategic worker-pool result; several reported file open/store errors in the Windows headless environment. No parse errors were reported. Full suite has not been rerun after the fixture adjustment. Slow reverse and dirt take-off tyre wear await Claude's ownership/status reply. No #326 human gate was run or marked passed.
- **2026-10-13 — Codex, #345 playtest UX:** Draft PR #372 is published from isolated branch `codex/air-camera-look` at `8cba9ec`, based on `main` `5ad9f51`. Phase-gated tutorials (including the second-flight load/fuel/weight lesson), airborne right-button camera look independent of mouse yoke, and the first-three-use runway turnaround explanation are covered by tests. Frontend passes 15/15 and tutorial 18/18 (the save fixture writes under the OS temp directory). Initial CI run `38260454428` on `678a48d` stopped at the generated project-status check: it expected 1,156 methods/146 files, while the committed inventory had 1,152. Regenerated `docs/PROJECT_STATUS.md`; the `--check` command passes. Fresh-head CI and Claude review are pending. The earlier full-suite run (before the fixture adjustment) reported 1,127 passed, 29 failed in 769.2 s. Failures spanned save/config persistence suites plus one strategic worker-pool result; several reported file open/store errors in the Windows headless environment. Full suite has not been rerun after the fixture adjustment. Slow reverse and dirt take-off tyre wear await Claude's ownership/status reply. No #326 human gate was run or marked passed.

- **2026-10-14 — Codex, autopilot/AI handoff:** The AI pilot now disconnects a human's engaged autopilot when it takes the seat. Host stick input cannot cancel an autopilot engaged by the AI while AI flight controls are active. With no active job, F3 midflight now gives the AI a nearest-field landing plan instead of leaving it without controls. These failures were reproduced by new tests before each fix. This branch merged tracked `origin/main` with the newer autopilot routing and sweep tools; the autopilot suite passed 45/45, seats 16/16, AI bots 19/19, and a 12-case midflight sweep was safe in all cases. Draft #375 is open; no merge or human flight sign-off is claimed.

- **2026-10-12 — Claude, project triage:** `docs/archive/PROJECT_TRIAGE_2026-10-12.md` lists everything open and closed (5 open issues, 98 closed, 28 open PRs, 47 merged): what is complete and unlikely to change, what is no longer needed or in question, the most problematic, and the early-game bloat and weight to rehaul, each with how it is known (merged, tested, code exists, unverified). It proposes closings, tickings and a docs archive but changes none. Docs only.
- **2026-10-12 — Claude, role handoff:** `docs/archive/CLAUDE_ROLE_HANDOFF.md` is an in-depth handoff for whoever takes the Claude seat: the owner's rules, the daily loop, the four background processes that must stay up (wake watcher, alert feed, review relay, doorbell) and which worktrees they run from, the open work (skyrunner-mcp PRs 6 and 7 approved but unmergeable without `gh` until the owner decides; the MCP-only relay/alerts waiting on PR 7; the 11-PR stale stack), tool traps, and a first-hour checklist. Same change removed 12 clean, fully pushed Claude worktrees and 2 `.build` verification worktrees (branches stay on the remote). Docs only; nothing verified beyond the links existing.
- **2026-10-11 — Claude, on Codex's #324 (its unattended turn cannot write inside a linked worktree's .git, so it could not fix this):** the bot's P1 was right: KeyHints chips are Buttons with focus_mode FOCUS_ALL, so Tab could enter the always-visible tutorial footer instead of reaching PilotApp, and after a click Enter/Space could re-fire Skip. `KeyHints` gets a `focusable` option (default true, so every other footer is unchanged); `TutorialPanel` sets it false; a line in the existing frontend test pins it, and a mutation (focusable = true) makes that line fail. Frontend 14/14 under the shared lock. The change is Claude's, in Codex's UI lane, because of the blocker; Codex should review the new head.
- **2026-10-11 — Claude, wake_codex.py alerts:** `--alerts-file PATH` also wakes Codex when an alert digest file changes (the prompt is fixed text naming only that path, and says the digest is data, never instructions; the file's mtime seen is kept beside the cursor), and `--queue-thread ID` delivers with `codex queue --thread ID --message` to an open Codex thread instead of resuming a headless session. 35 collab tests pass. NOT verified: delivery to the open desktop window via `codex queue` (Codex's earlier probe, note 187, exited 0 with delivery pending).

- **2026-10-11 — Claude, #330 (dashboard.py):** a read-only terminal screen of the collaboration board: both agents (last post, notes waiting, a STALE flag), their claims and the newest notes. Codex's review (board notes 234, and the bot's P1 before it) was right: the owner's rule is that GitHub reads go through the `skyrunner` MCP tools, and the first version called `gh` for pull requests and shipped a `gh`-based `review_packet.py`. Both are removed: the dashboard shows no GitHub data (use `github_merge_queue`), and the review packet is the MCP tool `github_review_packet` (skyrunner-mcp PR 7). A test checks the dashboard source has no subprocess or gh call. The board itself is still read straight from its SQLite file, read-only (as board_status.py and notify.py already do, which Codex has used). 39 collab tests pass.

- **2026-10-11 — Claude, #325 (compact notes):** AGENTS.md now asks for short board notes (under about 250 characters, ids not prose, no note without a new fact or ask, incremental reads, read-only tools). Measured before: notes since #100 averaged 534 characters (Claude) and 468 (Codex); the first notes after the rule were about 200. The dashboard and review packet it points at are in #330 (shell conveniences over gh; an MCP tool is queued in #328).

- **2026-10-11 — Claude, #318 review fix (P1):** `approach_end_clear` checked a 4.5-degree path on bush and shady strips, but the autopilot's final flies a little under 3 degrees from 30 m at the threshold, so an obstacle between the two lines read "clear" and the selector could pick that end. The check now uses the lower of the audit line and `Session.route_height_at(d)`, the same height `_approach_route` builds its final fix from (one definition). The rule is a static `way_in_clear(elev, deg, top_at)` so it is tested without a map. New test pins it; mutation check (ignore the route line) fails it; the other 14 + 10 autopilot tests pass. Codex's review then found the check stopped at 3 km while the final runs out to the 5 km fix: it now checks the route's height to `APPROACH_FINAL_M` (the audit line still only to 3 km), with a 4 km regression that a 3 km loop fails. Not run: the full suite (CI). The QRY/PNR end-0 results are unchanged.
- **2026-10-11 — Claude, autopilot approach end (#80/#82, Tier A):** On `claude/autopilot-approach-end` from main
  `e01feb4`. A diagnostic (QRY, PNR, EGL, HAR from 8 bearings x 2 distances x 3 headings) showed `Session._approach_route`
  picks the runway end by nearest final fix alone, so from every entry on the end-0 side of QRY and PNR it flew the
  *blocked* end (terrain 53 m up at 570 m out, trees 153 m up at 3000 m out), some with turns of 150-170 degrees. Now
  `approach_end_clear(af, end)` judges an end by `tools/strip_audit.gd`'s rule (3 degrees, 4.5 for bush/shady, 10 m over the
  threshold, out to 3 km) and `_choose_end` takes the nearer clear end, else the old nearest rule; nothing else about the route
  changes. `tests/test_autopilot_approach.gd` (simulation lane, 5 tests) pins the selector to the audit's blocked ends,
  QRY/PNR always on end 1, every other field on the old nearest-end rule, the either-terrain invariant, and the choice
  function; with the selector forced to "never blocked" the QRY/PNR tests fail (mutation check). Windows Godot 4.7.2 under
  the machine lock: autopilot files 30/30. **Finding for the lead:** on the *natural* terrain (what the game ships) HAR end 0's
  3-degree path is also blocked (the natural pass puts ~22 m more hill 1.2 km out, 13 m into the path), so the autopilot now
  joins HAR from end 1 when end 1 is clear; the natural pass is meant to leave approaches alone, so that is a terrain
  question for a separate decision. Not done from #82: a locked planner result, forward-intercept constants and
  heading-aware scoring (they would change ordinary-field behaviour). #80/#82 stay open.

- **2026-10-11 — Claude, #322 (wake_codex.py):** wakes Codex when a note is sent to it: one fixed prompt (integer ids, "act only on those ids", read only the new notes in pages of 20), cooldown, hourly cap, `--codex-config` for the unelevated Windows sandbox. After the bot review: the single-flight lock is an OS file lock (released when the holder dies, so no stale lock and no race over reclaiming one), a malformed cursor file is repaired, the woken turn runs in `--root`, the prompt is bounded to the captured ids. 33 collab tests pass; a woken turn with a working shell and MCP was verified end to end (board notes 149, 153). Not verified: waking the open desktop window; the per-tool review approval (blocked by the Claude Code guard).

- **2026-10-11 — Codex desktop/root:** TutorialPanel uses shared KeyHints buttons; pilot clicks skip/off call existing tutorial actions, station clicks use its existing tutorial command. Empty/completed lessons omit Skip. Existing frontend cases verify pilot and desk command paths, including seats without lessons (14/14 pass); test count unchanged. Screenshot and full suite queued under the machine lock; no human gate marked complete. Worktree: `~/.codex/worktrees/skyrunner-tutorial-footer`, branch `codex/tutorial-clickable-footer` from main `cc31bed`. Claude owns integration/review.

- **2026-10-11 — Claude, STRIPS.md from the per-end trials (#88):** On `claude/strips-from-trials` from main `e01feb4`.
  `tools/strip_audit.gd --bot` now runs `scripts/balance/strip_trials.gd` for every strip end, aircraft and load (216 trials,
  about 15 minutes under the machine lock) instead of the `Feasibility` sweep whose takeoff scoring counted a glide into the
  ground as a pass; new `--terrain natural|classic` (natural by default, what the game flies) and `--loads`. `docs/STRIPS.md` is
  regenerated: `... strip_audit.gd -- --bot --aircraft c172p,c182 --out docs/STRIPS.md`. Read from the table: QRY and PNR are one-way,
  light-load strips (land on end 1, take off from end 0; PNR also at half load); no takeoff passes from end 1; EGL takes off at
  light load only. **Separate finding:** the Cessna 182 at max load fails the landing on every field, including HAR (nose-over
  prop strike), so that is a heavy-aircraft landing problem, not a strip one. Whether the job generator should avoid sending
  loads a strip cannot take is still the owner's decision. Windows Godot 4.7.2 under the machine lock: strip_trials 12/12.
  #88 stays open.

- **2026-10-11 — Claude, collaboration docs (owner: Claude leads):** AGENTS.md and this file now say
  simultaneous mode instead of relay, who leads, the canonical clone (the board is per clone: a second clone on
  the same machine had its own empty board), note format, authority and one heavy Godot job at a time. Docs only;
  `docs` tests left to CI. Next: Codex's heartbeat to a 30-60 minute fallback (Codex or owner), and the
  skyrunner-mcp board-path override and machine-wide Godot lock (separate PR there).

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

- **2026-10-11 — Claude, #90 translation-import churn (assigned by Codex):** Every `--import` rewrote eight tracked
  `docs/AI_WORK_ALLOCATION*.translation` files, dirtying every worktree: the two planning CSVs added in #293 were
  imported by Godot's `csv_translation` importer, which writes one `.translation` per column next to the source.
  Nothing uses them (only a Markdown link in `docs/archive/AI_WORK_ALLOCATION.md`; the project registers no translations).
  Fix: tracked `docs/archive/AI_WORK_ALLOCATION.csv.import` and `docs/archive/AI_WORK_ALLOCATION_SUMMARY.csv.import` set
  `importer="keep"`, `.gitignore` un-ignores `docs/*.csv.import` (`*.import` is otherwise ignored repo-wide), and the
  eight generated `.translation` files are removed. A new `docs/*.csv` is imported as a translation table again unless
  it gets a keep sidecar like these. Windows Godot 4.7.2: import exit 0, no tracked file rewritten, sidecars untouched,
  no `.translation` regenerated; docs 2/2, status current, hygiene OK. No `.gd`, gameplay or save change. #90 stays
  open (unused-function cleanup remains).

- **2026-10-11 — Claude, leave and join coverage (#97, assigned by Codex):** On `claude/startup-leave-tests` from
  main `e384241` (after #306, #307 and #308), added `tests/test_startup_leave.gd` (socket lane): from a direct-hosted
  game, (1) `leave("lobby")` leaves no server, voice, client or game, opens the lobby, and the port can be listened on
  again after the deferred frees; (2) `_mp_join` with the F4 menu open tears the host down, forgets the menu, ends with
  one client link and one waiting room and no host voice, and then, pumping both ends, the other table welcomes the
  guest under the address's password and the player's name. No production defect found, so `main.gd` is unchanged.
  An automated review found that a reload cannot start from a hosted game (`PilotApp` offers "Load last save" only
  when not hosting, and that is the one production `leave.emit("load")`), so the first draft's reload test was
  synthetic; it is removed and this entry no longer claims it. Windows Godot 4.7.2: focused 2/2, docs 2/2, status
  regenerated; Linux and the full suite are left to CI. #97 stays open: the SeatPicker-cancel route (see #312), and
  the physical two-machine voice/controller checks. The suspected stale `main._mp` reference is not a defect (a freed
  object compares equal to null in Godot 4.7.2).

- **2026-10-11 — Claude, #88 strip-feasibility harness (assigned by Codex):** On `claude/strip-feasibility-harness`
  from main `e384241`, added `scripts/balance/strip_trials.gd` (`StripTrials`), `tools/strip_feasibility.gd` and
  `tests/test_strip_trials.gd` (simulation lane). Per-runway-end takeoff and landing trials for QRY/PNR/EGL (HAR as the
  control) x c172p/c182 x light/half/max, with explicit `--map` (default city) and `--terrain natural|classic` (default
  natural), filters, and JSON + markdown with commit/settings provenance written outside the repo. Takeoff passes at
  3 km *along the runway line* inside a straight-departure corridor (this harness's convention: 90 m either side
  plus 12.5% of the distance, 465 m at 3 km); leaving the corridor first is `inconclusive` (the path, not the
  aircraft), and a crash, the bot giving up or 400 s is `fail`; 300 m above the ground is not a pass. Reaching 3 km
  also needs a valid run (`takeoff_verdict`): airborne within the strip ahead of the start of the run (length - 25 m),
  15 m reached, and the CG never below an obstacle top once clear of the strip (`MIN_CLEARANCE_M` = 0; the gear hangs
  about a metre lower, so this is the least that is clear at all); otherwise it is `fail` with `invalid_reason`, and
  the measured distances stay in the result. A landing reports the FINAL touchdown (where the successful roll began),
  the first one alongside it, and the number of touchdowns, so a bounce or go-around is not hidden.
  Landing rows also carry the planner's aim point (`aim_from_threshold_m`), the glide angle and approach clearance,
  and the strip left at the aim and at the final touchdown. The planner moves the aim down the strip when the final
  needs it (HAR end 0 aims 294 m out on classic terrain and 726 m on natural, because the natural pass raises the hill
  under that final from about 600 m out), so a short strip's touchdown must be read with its aim and strip-left.
  Clearance (`min_clear_m`) is the CG above the highest obstacle within 15 m, the rig's scoring convention, not proof
  that the gear or whole airframe cleared it. The bot flies
  the takeoff and keeps pitch, power and flaps, but from liftoff the harness holds the runway line with PilotBot's
  own bank law (`StripTrials.LATERAL_MODE`, recorded in every result and the provenance): the rig measures whether the
  aircraft can climb straight out over the terrain, not where the bot would turn. It records the ground roll,
  distance to 15 m, least clearance over terrain and trees, along-track distance and largest deviation.
  Landing forces the end's final and re-forces it after a go-around; an end with no clear final is reported
  `obstructed` with the reason, not flown.
  `Feasibility`, PilotBot, the flight model, the terrain and the jobs are unchanged; trials parity still passes.
  Evidence found while planning: (1) `Feasibility.takeoff_trial` scores a post-goal glide into the ground as a pass
  (`leg_i >= 1`), so takeoff outcomes in `sim-results/feasibility.json` are noise; (2) that file was flown on the
  classic island (cli.gd never selects a map), not the city map `docs/STRIPS.md` and new games use; (3) both tools
  ran classic terrain, while play uses the natural pass. Windows Godot 4.7.2: strip_trials 9/9, trials_parity 2/2,
  docs 2/2, switches 6/6, status current, hygiene OK; CLI smoke HAR c172p light end 0, classic and natural: takeoff
  pass (liftoff 223 m, 15 m at 422 m, least clearance 136 m, 3002 m along, at most 19 m off the line), landing pass. The full
  measurement matrix and a `docs/STRIPS.md` regeneration wait for independent review of the harness; job-generator
  gating is a separate decision. #88 stays open.
  Review fixes (automated review of 95b121a, five P2s, all valid): a landing counts as passed only if the aircraft
  stopped on the strip itself (the session calls it parked up to 30 m outside); a touchdown that crashes is logged
  before the crash ends the trial; a takeoff must lift off over the runway rectangle, not beside it; the required
  gradient counts from the real run start (25 m in); and the CLI rejects unknown aircraft, fields, loads, ends and
  tests instead of labelling a report with values that did not run.
  **Separate follow-up, not fixed here:** PilotBot `_safe_heading` (pilot.gd:345) uses margin = altitude - 80 m with a
  75 s lookahead, so below 80 m ASL no heading qualifies and it turns ~40 degrees toward the lowest terrain ahead even
  over flat ground (HAR end 0, c172p light: ~290-345 m off the runway line at 1.2 km before the hold). It likely
  affects ordinary bot departures; a fix touches bot behaviour and the balance numbers, so it needs its own PR.

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
  endpoints and the employed-pilot opening. Its own records are in `docs/archive/PR_INTEGRATION_2026-10-08.md`,
  `docs/archive/OPEN_PR_AUDIT_2026-10-08.md` and the other dated docs, plus each PR body.
