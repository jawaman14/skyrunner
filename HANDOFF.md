# Agent handoff log

This is the shared channel for every agent working on this repository (Claude Code, Codex/ChatGPT, or anyone
else) and for the owner. Agents never talk directly; they talk here. `CLAUDE.md` (conventions) and
`AGENTS.md` (Codex's entry point) both point to this file.

- **Facts about the code** live in the code, `CLAUDE.md` and `docs/DESIGN.md`.
- **Release evidence** lives in `docs/PROJECT_STATUS.md`.
- **The queue** lives in `docs/ROADMAP.md`.
- This file records **who is doing what, what changed hands, and what one agent needs the other to know.**

Older handoffs (28 Sep and 3 Oct, cloud session → local) are in
[docs/HANDOFF_HISTORY_2026-09.md](docs/HANDOFF_HISTORY_2026-09.md).

## Protocol

1. **Before starting:** read the newest Log entries, the Claims table and Open questions below. Don't redo work
   that is logged as merged. If you disagree with something another agent did, add an Open question; don't
   silently revert it.
2. **Claim the slice.** Add a row to Claims (agent, branch, scope) and push it with your first commit. Never edit
   files inside someone else's claimed scope. If a claim is older than 3 days with no commits, ask in Open questions
   before taking it over.
3. **One slice = one branch off `main` = one PR into `main`.** Stack on another unmerged branch only when the code
   really depends on it, and say so in the PR. After a base is squash-merged, rebase its dependents onto `main` the
   same day. A stacked PR whose base was squash-merged conflicts with `main` and rots.
4. **Evidence goes in the PR body:** commands run, counts, what was not verified. Don't add new dated
   `docs/*_YYYY-MM-DD.md` reports. Update `docs/PROJECT_STATUS.md` only for release-level evidence, and regenerate
   its inventory block (`tools/project_status.gd -- --write`) when tests/chapters/exports change.
5. **When you stop,** prepend a Log entry (newest first, at most ~12 lines):
   date, agent, what merged/pushed (PR numbers), what is verified and how, what is NOT verified, and what's next.
   Remove your Claims row when its PR merges or you abandon it (say which in the Log).
6. **Questions** for the other agent or the owner go in Open questions with your name and date. Answer under the
   question, then move the resolved item into a Log entry.
7. **Commit attribution:** keep your tool's co-author trailer. The Log names the agent, so `git log` and this file
   agree.

## Claims (work in progress — don't touch these scopes)

| agent | branch / PR | scope | since |
|---|---|---|---|
| Claude | `ccr-958eacf7-ugmwgs` / #293 | `tools/mcp/`, `tools/mcp_introspect.gd`, `.mcp.json`, this file, `AGENTS.md`, `CLAUDE.md` layout fix | 2026-10-10 |

## Open questions

- **[Claude → owner, 2026-10-10]** Codex left 38 open PRs. 36 conflict into `main`, mostly because they are stacked
  on PR branches that were later squash-merged; only #227 and #228 merge cleanly (see `github_pr_triage`). Proposal: close the docs/plan-only PRs (#241, #242, #243, #246, #249, #264, #273),
  then rebase the gameplay stacks onto `main` one at a time, starting with logistics loading endpoints
  (#235/#237/#265/#267/#268/#274/#276) and the employed-pilot opening (#250–#252, #255). OK to proceed?
- **[Claude → Codex, 2026-10-10]** Review findings below (Claude review 2026-10-10). Items 1–3 are in code you wrote
  recently; reply here if any is intended behaviour before someone fixes it.

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
