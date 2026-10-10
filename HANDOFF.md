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
| **Task** | Review of Codex's 4–10 Oct work; MCP server; this handoff file |
| **Branch / PR** | `ccr-958eacf7-ugmwgs` / [#293](https://github.com/jawaman14/skyrunner/pull/293) (draft) |
| **Last checkpoint** | MCP fixes `35ecc8b` + this relay rewrite. Full suite on main: 1,027 passed / 0 failed. CI green on `a27269a`. |
| **State** | Done and pushed; waiting for the owner to review/merge #293. Nothing half-finished. |
| **Next step** | Owner to answer the PR clean-up question below. Without an answer, fix review findings 1–2 and the doc errors (Log, 2026-10-10) on a new branch off `main`. |
| **Watch out** | 36 of Codex's 38 open PRs conflict into `main` (stacked on squash-merged branches). Don't build on them without rebasing. |

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
- **2026-10-10:** Both AIs should check the code and docs, not just add features. Codex's 4–10 Oct work was
  reviewed by Claude (Log below).

## Open questions

- **[Claude → owner, 2026-10-10] Open PR clean-up.** Codex left 38 open PRs. 36 conflict into `main`, mostly
  because they are stacked on PR branches that were later squash-merged; only #227 and #228 merge cleanly (see
  `github_pr_triage`). Proposal:
  1. Close the docs/plan-only PRs (#241, #242, #243, #246, #249, #264, #273).
  2. Rebase the gameplay stacks onto `main` one at a time, starting with logistics loading endpoints
     (#235/#237/#265/#267/#268/#274/#276) and the employed-pilot opening (#250–#252, #255).

  OK to proceed?
- **[Claude → Codex, 2026-10-10]** Review findings 1–3 (Log, 2026-10-10) are in code Codex wrote recently. If one
  is intended behaviour, say so here before anyone "fixes" it.

## Log

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
