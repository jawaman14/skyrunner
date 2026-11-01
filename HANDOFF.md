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

### 27 October 2026 - automatic merge review gate (Codex)

The label-driven merge workflow was found to merge non-draft PRs after green CI even when independent review or review threads remained open. #414 and #446 merged while their final findings were still being fixed; #467 and #468 carry those fixes. This branch makes auto-merge require an approval from the other agent on the exact head, all review threads resolved, and a head current with main. Removed the `automerge` label from unsafe open PRs while the workflow change is reviewed. This workflow PR must remain draft and unlabeled until its own review and CI gates pass.


### 19 October 2026 — phone operations (#446, Codex)

Work now opens market indices and buyers' orders (remaining cargo, premium, deadline; Enter calls Benny without accepting a sale). Empire opens a read-only Heat view, with raid countdowns restricted to posted lookouts. The phone stays open airborne and owns only a temporary AP hold it starts; pre-existing routes are never copied or restored. Ground services remain parked-only. GUIDE and decision trackers updated. Regression checkpoint 4d573571 failed the Work/waypoint assertions in CI job 117954655516 as expected; implementation CI and fresh review still required. D-62's full desk and pickup scenes remain dependent on L-1/F-5/L-4 and PickupOrder; D-75's world rebuild and later presentation remain paused.

### 22 October 2026 - phone operations review fixes (#446, Codex)

The handset now closes on a moving ground aircraft, preserves only overlays it opened for the temporary airborne hold, and sends the first explicit U from Phone to Map to the selected chart waypoint. The focused phone regression passes (1/1); PROJECT_STATUS is current. Exact-head CI and independent review are next; PR stays draft until the review findings are cleared.

### 27 October 2026 - Controls glyph binding fallback after #414 (Codex)

The glyph column now removes a binding label only when its active-device glyph actually resolves and can render. In headless mode, or for an unsupported rebound key, the empty slot keeps every binding readable. Added a headless menu regression and explicit missing-glyph coverage; focused glyph tests pass 6/6. #414 merged while this review finding was being fixed, so the fix will go in a separate PR. Exact-head CI and independent review remain before integration.

### 27 October 2026 - phone Controls hold follow-up to #446 (Codex)

Fixed the remaining phone hold transition from Settings to Controls: when the pause panel belongs to the phone, opening Controls retains its temporary airborne autopilot hold until Controls closes. Added a regression for that path; the focused phone app test passes (1/1). #446 merged while this review fix was being prepared, so this fix will go in a separate PR. Broader tests, exact-head CI and independent review remain before integration.

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

**Vehicle rebuild draft (Codex, 14 Oct), #374:** Separate branch off main, original procedural period bodies for all 12 dealer/squad model keys. IDs, catalogue prices/specs, saves, physics and collision remain unchanged. Five new render-contract tests pass clean locally; eight existing car-physics tests also pass with baseline cleanup resource warnings. Local full import retains ActionReview.COMMANDS error under 4.6.3. Capture script passes parse check; read-only pinned CI will render 15 staged asset views in WorldScene plus the actual dealership. References: 1981 Ford brochure, 1983 C/K pickup brochure, Mercedes W123/Porsche 944 archives, Vice City/Stories and Driver Parallel Lines (1978 fleet). No copied assets or real brands shipped. Scenery PR #373 remains independent. First pinned capture/import/inventory and export passed on f004e14. Visual review exposed dropped hull panels from mixed indexed/unindexed batches; fixed by expanding primitive indices and checking every triangle winding plus hull presence. Five render tests pass again. Next: inspect corrected captures, latest pinned CI and review; no merge or human gate passed.

Local PC continuation (14 Oct): verified the fetched #374 head and exact-head CI. Added the handoff's parked-vehicle follow-up: three task-force patrol cars, the club boss's car and the casino guest car now use cached period models with the existing footprint collision. Added coverage in `test_period_vehicles.gd`; pinned Godot 4.7.2 full suite: 1,158 passed, 0 failed; project status current and `git diff --check` clean. Godot logs a Windows root-certificate warning; the full run also reports renderer/resource leaks at process shutdown and a transient already-in-use listener warning, despite all test files passing. Original exact-head beta and vehicle-capture CI both passed on `c4f663e`; the follow-up awaits fresh CI. No PR merge, human gameplay gate, or final visual walk/drive check is claimed. Coordinate the shared building-file overlap with #373 during review.

Visual README follow-up (14 Oct): the owner chose a 1979–82 visual baseline throughout the story. README now describes current scenery, period vehicle silhouettes, weather/effects and unfinished vehicle/weapon art. Retried visual capture: the MCP screenshot tool cannot run here because `xvfb-run` is absent on this Windows host; earlier local headless capture stalled and the windowed renderer exited with a Windows runtime error. GitHub's #374 vehicle screenshot artifact exists, but its images could not be opened locally. `git diff --check` passes; no gameplay tests or visual acceptance claimed. Next: inspect the exact-head CI images on a functioning viewer and perform the human walk/drive check before visual sign-off. Draft #374 is not approved to merge.

Windows capture fix (14 Oct): root cause is twofold: Windows `--headless` selects a dummy renderer (no viewport image), and this host's WinRT speech service throws at startup while `audio/general/text_to_speech=true`. `tools/capture_period_vehicles.gd` now fails fast in headless mode; `tools/capture_period_vehicles.ps1` runs windowed OpenGL under the shared lock, disables TTS only for the capture process, then restores the exact `project.godot` bytes. Local run produced 16/16 PNGs in `.build/visual-audit/vehicles-20261014-232010`; reviewed sedan, utility, luxury, patrol and dealership frames. The playable #374 build was launched in Forward+ with a temporary separate profile for the owner's visual check. No gameplay code, save, merge, or human acceptance gate changed. Capture workflow CI and cross-PR integration remain to verify after push.

Publication status: the Windows capture fix is committed locally, but `git push` failed first against the configured proxy and then because Git's credential prompt script could not start (`Win32 error 5`). Draft #374 is still at remote head `ced9ea0`; no exact-head CI exists for this local fix. Preserve the clean local commit and retry publication when Git credentials work.

TTS follow-up (14 Oct): after the owner reported that the game was still invisible, removed `audio/general/text_to_speech=true` from `project.godot` and guarded the default speech callback. The setting caused a reproducible WinRT startup exception on this PC. The Windows capture launcher no longer edits project settings; it produced 16/16 PNGs after the change. A fresh game process launched through the `SkyRunner Review` desktop shortcut and has a responsive `Skyrunner (DEBUG)` window. The desktop controller cannot select or focus that window, so visibility to the owner remains unverified. The main checkout's dirty `project.godot` and `scripts/game/speech.gd` were patched with the same TTS fix without disturbing its editor plugin setting.

**Map scenery draft (Codex, 14 Oct), #373:** Airport/docks, rural, HQ/casino/city, terrain/sidewalk and Miami street details are pushed. Club Tropicana planted arrival beds and canopy, Hotel Cielo outer-court planting, deeper cafe frontage and the deterministic low-rise shop-awning pass are implemented. Six raised beds add matching solid collision inside existing pavement, clear of the central approaches and casino drive. The awnings reuse the Kenney commercial kit, batch per city chunk and add no collision or interactions. Focused checks recorded before the awning follow-up: 13/13 for access, footprint and per-bed triangle budget. Latest known exact-head CI/captures passed on 797a40d. This follow-up has not had Godot tests, import, or a capture run; the current machine's GitHub fetch failed through its proxy. Design and plan: `docs/superpowers/specs/2026-10-14-costa-brava-city-frontage-design.md` and `docs/superpowers/plans/2026-10-14-costa-brava-city-frontage-plan.md`. No human gameplay check or merge is claimed. Waterfront streets remain a future slice; other baton tasks above remain active.

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

- **2026-10-27 - Codex, #373 after #414/#446/#447:** Synced the scenery PR with `main` `6f2d2344`, preserved both handoff histories and regenerated the project status after importing the new glyph add-on. Focused `city_dress` 12/12, `period_props` 8/8 and `docs` 3/3 pass. The awning regression remains in place. Next: exact-head CI, scenery captures, independent review and resolution of open threads before merging; the `automerge` label remains removed.

- **2026-10-27 - Codex, #373 scenery integration:** Synced the remote PR head with `main` `1117604b` in a fresh linked worktree; the older #373 worktree has unrelated dirty files and was preserved. Main's period building parcels displaced the old commercial kit, so the awning placement now also accepts period shop models; the real-map placement test selects eligible shops across the map. Focused `city_dress` 12/12, `period_props` 8/8 and `docs` 3/3 passed. Project status was regenerated; trailing blank lines in the PR diff were removed. Next: exact-head CI, visual capture and independent review before merge.
- **2026-10-27 - Codex, #447 current-main sync:** Merged `main` `1117604b` into the isolated dealer-scroll worktree without conflicts. The PR diff remains this handoff, `dealer_menu.gd`, and `test_game_menus.gd`; focused `game_menus` 8/8 and `dealership` 14/14, project status current, and `git diff --check` clean. Next: push this head, wait for exact-head CI and independent Claude review, then merge only if the queue is ready. The dirty primary checkout was untouched.

- **2026-10-26 - Codex, #447 after #463:** Merged main `3744307c` into the dealer-scroll branch without conflicts. The PR still changes only this handoff, `dealer_menu.gd`, and its existing menu test; the F-4 inventory delivery merge remains intact. New exact-head CI is required. The owner's requested Codex technical review found no blocking issue at the previous head; the project still needs an independent review at the new head before merge.

- **2026-10-25 - Codex, #447 dealer scroll integration:** Merged `main` at `fa4ff455` into the dealer-scroll branch in a separate linked worktree. The only conflict was in `tests/test_game_menus.gd`: kept #447's viewport-backed wheel-scroll regression and #431's keyboard traversal regression. The source merged automatically. Focused `game_menus` 8/8 and `dealership` 14/14; project-status check passed. The first cold Godot import segfaulted during asset import, then a locked retry completed; no test assertion ran on the failed attempt. Exact-head CI passed 14/14 at `fadb70b7`, then main advanced to `7e8e9d75` (#459); the second merge was conflict-free and requires new checks. Next: verify and push the refreshed head, get fresh CI and independent exact-head review, then integrate #447 if all gates pass. The primary dirty checkout was untouched.

- **2026-10-26 - Codex, #450 contract integration:** Synced the PR branch with main `3744307c` after F-4 step 4, retaining both the 23 October #431 checkpoint and the 20 October empire contract entry. The three-file PR diff is documentation only. The two earlier automated spec findings are addressed at `69137aa4`. Fresh exact-head CI and independent Claude review are required before merge.

- **2026-10-27 - Codex, #374 period vehicle integration:** Synced the PR branch with `main` `1117604b`. Retained the vehicle work and its historical handoff; kept main's retired speech-script deletion and archived link targets, and regenerated `PROJECT_STATUS.md`. Focused `period_vehicles` 6/6, `car_physics` 8/8 and `docs` 3/3 passed on pinned Godot 4.7.2. Next: inspect the PR-only diff, push for exact-head CI and vehicle captures, obtain independent review, then resync after #373 lands if needed. The primary dirty checkout was untouched.

- **2026-10-23 - Codex, #431 dealer navigation integration:** Merged current main into Claude's dealer-scroll PR in an isolated worktree. Only generated PROJECT_STATUS conflicted; regenerated it to 1,258 methods and checked current. The PR's lot-to-Yours UP/DOWN behavior remains intact. Focused game menus 8/8 and dealership 14/14; diff check clean. Exact-head CI and a fresh independent review of the merge remain before integration with #447.

- **2026-10-20 - Codex, empire contract follow-up:** `codex/empire-contract-fixes` corrects the F-1 unsupported-save gate, names passive Los Cuervos income for F-3, makes F-6's nightly report independent of the capped transient event bus, and normalises A5's fee in transfers and balances. `test_docs` passed 3/3; `git diff --check` was clean. No gameplay code changed. F-1's code guard is a separate follow-up based on draft #441; later F-3, F-6 and L-5 implementations still need their own tests.

- **2026-10-22 - Codex, #446 review fixes:** In an isolated worktree, fixed the three open phone findings: overlay ownership, moving-ground handset control, and first-U waypoint routing. Focused phone test 1/1; project status check current; primary checkout untouched. Next: exact-head CI, review, and thread resolution before integration.

- **2026-10-19 - Codex, phone operations:** On `codex/phone-operations`, recorded the plan and regression expectations for Work market/orders, Empire Heat and in-flight phone hold (D-27/D-49/D-62). This checkpoint intentionally precedes implementation: the new expectations should fail. Worktree creation and local Git writes were denied; verification uses CI. Main's previous N-2/N-3/N-4 history is preserved. Next: demonstrate the failure, implement through current interfaces, then finish CI/review/integration.

- **2026-10-19 - Codex, empire pivot N-2/N-3/N-4:** #442 names Rafa as employer and Benny as fixer, including the flying lessons' assertions; its 14 CI jobs passed at `a62f581`. #444 opens the prelude/chapter-2 scenes, saves a cue only at natural END, and tests hangup/retry/save-load; all test lanes passed at `e0128f35`, with visual capture still running when recorded. #443 retires active speech claims and release gates, dates old suite evidence/timings, and preserves this shared handoff plus current-main inventory/roadmap. Review findings were answered in their inline threads. Local Git writes and shell network access were denied, so changes were published through the GitHub connector and verified in CI; the dirty primary checkout was untouched. PR states and the shared board are authoritative for subsequent integration and risk-review updates.

- **2026-10-19 - Claude (cloud session, no board), empire pivot docs:** On `claude/empire-pivot-docs` from `main` `34fd7f2`, added `docs/EMPIRE_PIVOT.md` (revision 2: the owner's direction from Codex's review, decisions, verified blockers, PR order) and `docs/EMPIRE_SIMULATION_SPEC.md` (the Living District contract), decisions D-65 to D-80 with the roadmap section `Empire pivot (owner, 19 October)`, pause notes on D-19, D-23, D-43 and their roadmap sections (D-75), and D-58's note (D-79). Docs only; no sim, save or test change. The baton above is left as Codex's. Next: Codex reviews the contracts (spec sections 3-7) before F-1; text-only N-2 to N-4 can start now in Codex's lane.

- **2026-10-18 - Codex, Rafa dialogue draft (#511 item 6):** On `codex/rafa-dialogue` from `main` `939b4e0b`, added five independent entry points for the employment opening, three chapter-2 beats and chapter-4 off-screen death report. `test_talk` passes 12/12; full suite reports 1,214 passed and 4 failed (two core-parity golden tests and two police radar tests, whose files are unchanged from `origin/main`). Generated status is current at 1,218 methods / 149 files; `git diff --check` is clean. The entries are not hooked into the story until Claude's beat/takeover scene work calls them. Next: publish the requested draft PR and wait for exact-head CI/review.

Older entries (up to 17 October 2026): [docs/archive/HANDOFF_LOG_2026-10.md](docs/archive/HANDOFF_LOG_2026-10.md).
