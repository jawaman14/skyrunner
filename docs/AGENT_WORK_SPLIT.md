# Skyrunner: Claude Code vs Codex work split

> Imported from the [Google Doc](https://docs.google.com/document/d/1Gvc3qsZruv8uB6FWVj6YUqyqVabRRi9caebwn9nCdrE/edit) on 11 October 2026. This is a preserved planning snapshot; repository counts, PR states, and capability claims must be rechecked. The “OPERATING DECISIONS — consolidated” section records the document’s consolidated guidance. Existing repository instructions and verified release evidence remain in CLAUDE.md, HANDOFF.md, and docs/PROJECT_STATUS.md.

Oct 11, 2026 · @Evan

## Summary

Claude Code takes anything that has to respect cross-file invariants: the Session layers, determinism and goldens, the flight model, world geometry, story writing, and integrating drafts. Codex takes one known pattern applied across many screens, issues or tests, as long as the result can be checked headless. Neither can clear the human release gates, and those are now the real bottleneck.

Three process fixes come before handing out any more work:

1. Add AGENTS.md. Codex doesn't read CLAUDE.md by default, so it probably hasn't been getting the repo's rules.
1. Trim ROADMAP.md back to a queue. Both agents read it every session, and right now it's mostly PR evidence.
1. Stop stacking Codex drafts. Start with three open, each branched from current main.

This is all based on main at fceffaa (11 Oct 2026, PR #294).

## What the repo shows today

Skyrunner is a mature codebase already worked on by both agents, so this is about formalising a split that's half there.

| Fact | Value |
| --- | --- |
| Engine | Godot 4.7.2, pure GDScript, Jolt physics |
| Code size | About 80,000 lines of GDScript in 386 scripts |
| Tests | 1,058 declared in 135 files; 1,027 passing on main at c7b8763 |
| CI | 11 jobs: test lanes, dedicated server, three exports, Linux/Windows/macOS smoke |
| Core constraints | Seeded, replayable sim; RNG streams per system; parity and golden fixtures; warnings are errors |
| Agent rules file | CLAUDE.md only; no AGENTS.md |

The history in the last 400 commits splits into three phases:

| Dates | Who | What |
| --- | --- | --- |
| 11 Oct | Claude | Integrated 14 Codex drafts into one PR (#294); held back #244, #247, #253, #269 and the road/loading access stacks |
| 7–9 Oct | Codex | Dozens of small hardening, audit, coverage and evidence-doc PRs (#225–#292) |
| Up to 4 Oct | Claude (Opus and Sonnet) | Big feature work: flight model, casino, dealership, story chapters, dedicated server |

The open roadmap has ten items. Most are completion work on systems that already exist: action previews, menus, stations, site access, roads and bridges, interiors, NPCs and period art. New features are deferred until the release gates pass.

## Claude Code's lane

Give Claude Code the work where one wrong change breaks something three systems away. It's the better whole-codebase reasoner, it runs locally where it can open the editor and the tools/shots screenshot scripts, and it's already been doing the integration.

| Work | Roadmap item | Why Claude Code |
| --- | --- | --- |
| Session layers, RNG streams, switch registry, parity and golden fixtures | Any new system | One stray random draw shifts every golden; needs the whole layer chain in view |
| Truck and squad migration to checked routes, with paired-seed measurements | 9, plus the logistics baseline (re-run the audit first; #294 changed the blocked count) | Touches sim, roads and balance at once; results need interpreting, not just passing |
| Placement, site access, roads, bridges, interiors | 6, 7, 8 | Geometry, physics, rendering and sim interact; needs screenshots and the editor |
| Flight model, pilot bot, balance runs | #244 (held back because it changes balance) | 200-seed runs need judgement on what the numbers mean |
| Integrating and rebasing drafts | Held-back road/loading access and employed-opening stacks | Already doing this well in #294 |
| Visual and performance review | #247, #269, the fixed-route frame-time comparisons | Needs real rendering and reading screenshots |
| Story and dialogue writing | .dialogue files, chapter briefings | Prose quality; the existing chapters were written this way |

Rule of thumb: if a task touches scripts/sim/session_*.gd, adds a random draw, or needs a golden regenerated, it's Claude Code's.

## Codex's lane

Give Codex work where the pattern already exists and just needs applying many times, each piece checkable with tools/test.sh headless. It runs tasks in parallel in cloud sandboxes and is cheaper per task, but it can't open the editor or see a render.

| Work | Roadmap item | Why Codex |
| --- | --- | --- |
| Action previews and Cancel-first reviews on the remaining screens | 3 | The pattern exists; one task per screen |
| Menu focus, scrolling, disabled reasons, palette refresh | 4 (logistics and rackets, then the rest) | Same fix repeated across screens, all testable through the modal-input tests |
| Issue triage pass | The open issues (#80 onwards) | One task per issue: check it against the code, then propose close or fix |
| Entry-path and per-system test coverage | #97 | Mechanical, parallel, one test file per system |
| Benchmarks and tooling | Route search, coastal and fixed-route frame-time scripts | Self-contained scripts with clear outputs |
| CI, export filters, Docker and server scripts | Maintenance | Isolated from game logic |

Codex shouldn't touch the Session layer chain, add random draws, or regenerate goldens. If a task turns out to need any of those, it should stop and say so in the PR, and Claude Code picks it up.

In between sits a middle tier: bounded gameplay or UI changes behind a stable interface, such as a new phone call source or a single station screen. Either agent can take those, with the other one reviewing. What decides the lane is the risk to the invariants, not which model is "better".

### Codex environment setup

Without this, Codex can't run the suite and hands back untested PRs. Put it in the environment's setup script, which runs with network access before the agent starts:

```
set -euo pipefail
GODOT=$(./tools/get_godot.sh)   # pinned 4.7.2 into .tools/, skipped if already there
"$GODOT" --headless --import
```

This keeps everything inside the repo's own .tools/ folder, with no system paths touched. tools/test.sh calls plain godot unless GODOT is set, so the test command goes in AGENTS.md as GODOT=$(./tools/get_godot.sh) ./tools/test.sh (see Fix 1). The import can take several minutes on a cold checkout because of the art packs, and pre-running it means the agent's own test runs start warm.

## What neither agent can do

The remaining release gates need a person, real hardware or a decision, and no amount of agent work closes them. This is where my own time goes furthest:

- ☐ Exported Windows build walkthrough, start to finish
- ☐ Physical controller pass (gamepad, and yoke and pedals if I've got them)
- ☐ Read-aloud and visible-focus check
- ☐ Visual pass at 1024x768, 1280x720, 1920x1080 and 2560x1080, in both palettes
- ☐ Walk and drive every bridge and functional entrance on Costa Brava
- ☐ Two-machine multiplayer session: seats, actions and voice
- ☐ Human macOS walkthrough
- ☐ Decide on the bundled radio recordings' redistribution rights (#175)
The agents can still help around these. Claude Code can turn each one into a short test script beforehand, and a Codex task can turn my notes afterwards into issues.

## Fix 1: one rules file for both agents

Codex reads AGENTS.md and Claude Code reads CLAUDE.md, and the repo only has CLAUDE.md. [OpenAI's docs](https://learn.chatgpt.com/docs/agent-configuration/agents-md.md) say Codex looks for AGENTS.override.md, then AGENTS.md, then only the names listed in project_doc_fallback_filenames, and ignores everything else. So unless my Codex config lists CLAUDE.md, or I've been pasting the rules into prompts, it hasn't seen warnings-as-errors, the RNG stream rule, the switch registry or the fixture rules. The docs only cover the CLI, though, so Codex cloud needs checking after the change (below).

The fix is to make AGENTS.md the real file and have CLAUDE.md import it. Claude Code follows @ imports in CLAUDE.md, so both agents read the same text.

```
git checkout -b chore/agents-md
git mv CLAUDE.md AGENTS.md
sed -i '1s/.*/# Skyrunner: notes for coding agents (Claude Code and Codex)/' AGENTS.md
printf '@AGENTS.md\n' > CLAUDE.md
sed -i 's/\[CLAUDE.md\](CLAUDE.md)/[AGENTS.md](AGENTS.md)/' README.md
sed -i 's/`CLAUDE.md`: commands/`AGENTS.md`: commands/' HANDOFF.md
git add AGENTS.md CLAUDE.md README.md HANDOFF.md
git commit -m "docs: make AGENTS.md the shared agent rules file"
```

Then add this lane rule to the end of AGENTS.md's Conventions list, so each agent knows where its boundary is:

```
- **Agent lanes.** Changes to `scripts/sim/session_*.gd`, new random draws, new `ENABLED` switches
  and golden regeneration are done in a local Claude Code session. Codex tasks that discover they need
  any of these stop and say so in the PR instead of making the change.
- **Evidence goes in the PR body**, not in new dated files under `docs/`.
- **Running the suite:** `GODOT=$(./tools/get_godot.sh) ./tools/test.sh`. The script reuses the pinned
  binary in `.tools/` once it's downloaded; plain `godot` may not be on PATH.
```

Notes:

- Don't symlink AGENTS.md instead. On a Windows checkout with core.symlinks off, git writes the link as a one-line text file and both agents lose the rules.
- tests/test_docs.gd checks README's links. CLAUDE.md still exists, so the old link wouldn't fail, but pointing it at AGENTS.md keeps it honest.
- assets/radio/README.md and the older parts of HANDOFF.md mention "the CLAUDE.md rule". That still reads fine through the import, so I'd leave them.
Check it took. After merging, ask each agent to list the instruction files it loaded and to quote the warnings-as-errors rule back. For the Codex CLI that's codex --ask-for-approval never "List the instruction sources you loaded."; for Codex cloud, run the same question as a throwaway task. If cloud doesn't pick up AGENTS.md, that's worth knowing before handing it real work.

## Fix 2: trim ROADMAP.md back to a queue

The current ROADMAP.md is 210 lines, and most of it is merged PR numbers, test counts and CI run IDs. Both agents read it at the start of a session, so that history costs context every time. 210 of the last 352 commits touch docs/, which is a lot of agent effort going into paperwork.

The history already lives in ROADMAP_HISTORY_2026-10.md and PROJECT_STATUS.md, so nothing is lost. Below is a replacement that keeps only what's left to do, plus a lane for each item. I wrote the "what's left" column from the current file. Worth a skim before committing, because I may have compressed a nuance you care about.

```
# Roadmap

What's left to do, in order. One feature branch and PR per slice; evidence goes in the PR body.
Verified state: [PROJECT_STATUS.md](PROJECT_STATUS.md). History: [ROADMAP_HISTORY_2026-10.md](ROADMAP_HISTORY_2026-10.md).
Lane: **C** = Claude Code (local), **X** = Codex (cloud), **H** = human.

## Queue

| # | Item | What's left | Lane |
|---|---|---|---|
| 1 | Baseline | Human release evidence for the merged overhaul (see gates) | H |
| 2 | Dialogue | Physical controller, read-aloud and visual passes; two-machine delayed-result check | H |
| 3 | Contextual actions | Descriptions for the remaining committing dialogue and menu actions; unsupported previews stay explicit | X |
| 4 | Menus/settings | Preview adoption and remote outcome display on logistics/rackets, then remaining screens | X |
| 5 | Stations/maps/feed | Dialogue commitment review; remaining seat-specific refinements | X, C reviews |
| 6 | Placement/access | All-entrance walkthrough; connector validation beyond the 120 m local search; approach steps; end-to-end physics checks | C |
| 7 | Roads/bridges | Site connectors, Costa Brava bridge approaches, exported walk/drive validation; measured migration off the legacy route API. Keep La Selva roadless; no incidental map rebake | C |
| 8 | Interiors | Remaining hangar/HQ/casino fixes; terrain-specific placement; exported walkthroughs | C, then H |
| 9 | NPCs | Checked pedestrian/vehicle access, identity/task display, body lifecycle; truck/squad connector migration with paired seeds. Re-run `tools/logistics_routes.gd` for the current blocked count | C |
| 10 | Period art | Validate one coastal reference area, then reuse; keep ASSET_PROVENANCE.md current | C |

Held back from #294: #244 (balance), #247 and #269 (visual/perf review), #253 (video size),
the road/loading access and employed-opening stacks (need rebasing). All C.

Issue pass: check each open issue against the code (X), one task per issue. Issues needing playtests,
controllers, rights decisions or two machines stay open until that evidence exists.

## Completion gates

- Real input; long, empty and stale content; pending, refused and unknown remote outcomes.
- Both palettes at 1024x768, 1280x720, 1920x1080 and 2560x1080; visible focus and read-aloud.
- Walk and drive every bridge and functional entrance; wall occlusion and thresholds.
- Costa Brava plus representative generated maps; runway clearance preserved.
- Classic island retired from player entry; classic saves rejected without rewriting.
- Worker assignment, arrival, jail/death, save/load and human/AI handoff.
- Full sharded tests, parity/goldens, export filters and build smoke.
- Fixed-route frame-time and memory comparisons; investigate regressions over 10%.
- Paired-seed balance measurements for travel changes; no arbitrary retuning.
- Exported Windows walkthrough and a real two-machine seat/action/voice session.

## Deferred

New chapters, hidden-informant gameplay, arrival-gated payroll, new combat mechanics, UDP prediction,
multiplayer racing, more aircraft and cloud deployment wait until the gates pass.
```

Also worth a one-line rule in AGENTS.md (it's in Fix 1): no new dated docs/*_2026-10-xx.md reports. The 15 that exist can be moved under docs/history/ in a Codex task; check tests/test_docs.gd and cross-links first.

## Fix 3: how work moves between the two

#294 had to integrate 14 drafts at once and hold back several more that needed rebasing. That's what stacking costs. Here's the flow I'd run instead:

1. Claude Code sets the pattern first. For roadmap items 3 and 4, it does the first screen properly, with tests, and merges it. That screen becomes the reference Codex copies.
1. Codex gets one task per screen or issue, each branched from current main, never from another draft. The task prompt names the reference PR and the files it may touch.
1. Start with three open Codex PRs. Go up to five only if rebases stay painless. Beyond that, rebasing and integration cost more than the parallelism saves.
1. Each Codex PR must pass tools/test.sh in its sandbox before it's opened. CI is the second check, not the first.
1. Claude Code reviews Codex PRs, and Codex reviews Claude's. Different models miss different things, and cross-review is cheap.
1. Merge small and often. Squash-merge each PR on its own green CI, rather than batching them into an integration PR.
1. Anything that crosses a lane goes back. If a Codex task finds it needs a Session-layer change or a new random draw, it stops and writes up what it found, and Claude Code does that part.

On cost: published token ratios between the two are shaky, so I'll measure my own. Over the first two weeks, track cost and rework per merged PR for each agent, then revisit the split with real numbers.

## Caveats and assumptions

- Read-only look. I read the repo at fceffaa and the last 400 commits, but I haven't run the test suite or the game, and I can't see open PRs, issues or CI runs.
- Who did what is inferred from commit style, co-author lines and the #294 message. 25 commits credit Codex and about 220 credit Claude, but squash merges hide some of that.
- The AGENTS.md finding assumes Codex wasn't getting the rules some other way, such as pasted prompts or a custom Codex config.
- The logistics count has moved. #294 merged authored loading endpoints (#235, #237), so the 99-blocked baseline on main is out of date. Re-run the audit before planning item 9.
- The Codex setup script stays inside the repo's .tools/ folder, but it still needs curl, unzip and network access during setup.
- Benchmarks and token ratios come from third-party comparisons, and they move with every model release. The lane split is based on how the tasks differ, not on those numbers.

# Engineering review and additions — 11 October 2026

This review supplements Claude’s snapshot at commit fceffaa. Repo state, issue counts, model costs and CI outcomes must be rechecked before applying its plan.


## Corrections and qualifications

Use risk, reproducibility and tool access to route work, not categorical claims about which model is better. Codex capabilities depend on environment configuration; the statement that it never sees CLAUDE.md should be treated as a hypothesis verified by testing, not a certainty. Headless tests do not replace visual, hardware, performance or multiplayer acceptance. Avoid the unverified 4x token-cost ratio; measure actual cost per accepted change. The original setup script assumed system write access; Claude subsequently revised it to use the repo-local .tools/ directory and the pinned Godot 4.7.2 downloader.

Claude's note: Mostly agree, and the doc's been updated. I checked OpenAI's AGENTS.md docs: the Codex CLI reads AGENTS.md and only the fallback names listed in its config, so it ignores CLAUDE.md by default. Codex cloud isn't covered there, so Fix 1 now has a check step. The 4x token figure is gone, replaced with measuring my own cost per merged PR. The setup script no longer touches /usr/local/bin, and Godot was already pinned to 4.7.2 by tools/get_godot.sh.


## Risk-based task routing

Tier A (high risk): Session invariants, RNG and deterministic replays, save compatibility, network authority, simulation and map geometry. Require an integration owner, design note, paired-seed tests and human approval. Tier B: bounded UI/gameplay changes with stable interfaces; either agent may implement with independent cross-review. Tier C: mechanical documentation, repeated UI patterns and isolated tests; delegate when acceptance can be automated. Escalate immediately if files outside the agreed scope, dependency changes, goldens, save formats or undocumented invariants become necessary.

Claude's note: Agree. The tiers map onto the lanes: Tier A is Claude Code, Tier B is either agent with the other reviewing (now added to Codex's lane), and Tier C is Codex. Where I'd push back is a separate design note for every Tier A change. That's more of the paperwork Fix 2 is trying to remove, and a paragraph in the PR body does the same job. "Human approval" just means I review before merging, which already happens.


## Required pull-request contract

Every task specifies player-facing goal, base SHA, allowed/forbidden files, reference implementation, observable acceptance criteria, exact test commands, required human checks and rollback. Every PR records test results and tests not run, UI before/after evidence where relevant, limitations and risks. Definition of Done includes reviewed scoped diff, passing CI, relevant headless tests, save/determinism checks if affected, and separately recorded manual gates. Golden updates require a behavioural explanation and diff review; a changed snapshot is never automatically proof of correctness.

Claude's note: Partly agree. Worth keeping: allowed and forbidden files, the reference PR, the exact test command, and a list of tests not run. Too heavy for a solo game: a rollback plan for every PR (it's git revert), and before/after evidence outside UI changes. Golden updates needing an explanation is already a repo rule ("say so in the commit").


## Parallelism and integration

Begin with at most three independent Codex PRs; increase toward five only if rebase conflict rates and review latency remain low. Branch from current main, avoid overlapping files, merge individually after green CI, and rerun affected tests after rebasing. Track an issue, owner, branch, base SHA, CI state, human gate and blockers for each draft. Cross-model review supplements accountable human ownership rather than replacing it.

Claude's note: Agree on starting at three; I've changed the summary and Fix 3. A separate tracker for each draft's branch, SHA and CI state isn't needed, because the GitHub PR list already shows all of that.


## Validation and release evidence

Every PR: syntax/import, headless suite, docs-link validation, scope check and CI. Session/RNG/save/network: paired-seed replay parity and compatibility checks. UI: screenshot comparisons across the specified four resolutions and both palettes, keyboard focus and read-aloud. Routes/world: collision, entrances, seeded traversal and performance deltas. Before release: exported Windows/macOS walkthroughs, physical controller, two-machine seat/action/voice tests and radio redistribution-rights decision. Maintain a gate register with scenario, platform, build SHA, tester, date, pass/fail/blocked, evidence URL, linked defect and retest owner. Unknown manual evidence is not a pass.

Claude's note: Agree on the checks. The gate register is worth having, but with five columns (gate, build SHA, date, result, notes) and kept in PROJECT_STATUS.md, which already tracks the human gates; there's a starter version at the end of the doc. For the four-resolution screenshots, CI already renders one frame with llvmpipe, and extending that job to all four resolutions and both palettes is a good Codex task.


## Suggested first implementation cycle

1. Confirm current main, active issues/PRs, Godot version and baseline CI. 2. Introduce AGENTS.md and a CLAUDE.md import, then verify both agents actually apply rules in a small test; inspect Windows behaviour and links. 3. Archive completed roadmap evidence before shortening the live queue; retain issue details. 4. Have the integration owner implement one reference action-preview/menu screen, including tests and screenshot baseline. 5. Delegate up to three independent matching screens. 6. Execute a Windows build, a real controller session and a two-machine multiplayer session; log bugs and retest blockers before adding features.

Claude's note: Agree, and it matches the doc's order. One change: the human tests in step 6 don't depend on steps 4 and 5, so they can run in parallel instead of waiting.


## Metrics and open decisions

Review weekly: median PR lead time, stale drafts, rebase conflicts, reverted changes, escaped bugs, review time, test coverage by risk, release gates completed and cost per merged accepted task. Revisit the lane split after two weeks using comparable tasks. Confirm actual tool access for both agents, pinned engine version, CI requirements, responsible human release owner and location of the evidence register. These points cannot be settled from Claude’s document alone.

Claude's note: Disagree on scale. Nine weekly metrics is a team dashboard, and one person won't keep it up. I'd track three: open Codex PRs, rebase conflicts, and cost and rework per merged PR. The open decisions mostly have answers already: I'm the release owner, the gate register lives in PROJECT_STATUS.md, and the check step in Fix 1 confirms what each agent actually loads.


## Reusable task handoff template

- Issue / desired player outcome:
- Base commit and branch:
- Risk tier and owner:
- Files allowed / forbidden:
- Reference implementation:
- Invariants (Session, RNG, save, networking):
- Acceptance tests and commands:
- Human/visual/hardware gates outstanding:
- Rollback and blockers:
- Escalation trigger:
Claude's note: I've cut this to nine fields in the trimmed template at the end of the doc. Rollback for a solo project is git revert, so it doesn't need its own field, and the invariants are covered by the "must not touch" line.

## Trimmed handoff template

This goes at the top of every Codex task, and any Claude Code task that isn't obvious. In the PR body, the agent lists the tests it ran, the ones it didn't, and anything it wasn't sure about.

```
Goal (what the player sees):
Base: main @ <sha>
Lane: Claude Code / Codex / either
May touch:
Must not touch: scripts/sim/session_*.gd, goldens, save format (unless the lane is Claude Code)
Reference PR:
Done when: <test filter and command>
Not covered (human checks still needed):
Stop and hand back if:
```

## Gate register

One row per run, kept in PROJECT_STATUS.md once it's in use. A gate only counts as passed with a build SHA beside it.

| Gate | Build SHA | Date | Result | Notes / bug |
| --- | --- | --- | --- | --- |
| Exported Windows walkthrough |  |  | Not run |  |
| Physical controller pass |  |  | Not run |  |
| Read-aloud and focus |  |  | Not run |  |
| Four resolutions, both palettes |  |  | Not run |  |
| Bridges and entrances, walk and drive |  |  | Not run |  |
| Two-machine seats, actions, voice |  |  | Not run |  |
| macOS walkthrough |  |  | Not run |  |
| Radio rights decision (#175) |  |  | Not run |  |



OPERATING DECISIONS — consolidated (11 October 2026)

This section is the actionable interpretation of the preceding Claude/Codex discussion. Earlier review and reply sections are historical rationale, not additional requirements. Task assignments are proposals based on Claude's commit fceffaa snapshot, not verified current GitHub status. The linked ownership tracker is the operational queue; update it against current main before starting work.


Ownership and handoffs

Claude Code: primary implementer/integrator of Tier A changes affecting Session, RNG, goldens, saves, simulation, world/bridge/access geometry, flight physics and balance; establishes reference patterns and reviews Codex PRs. Codex (ChatGPT): primary implementer of bounded Tier C work—AGENTS.md and documentation alignment, issue triage, repeated contextual-action/menu screens, isolated automated tests, CI/screenshot tooling and evidence clean-up—plus independent review of Claude PRs. Tier B tasks may move either way after a scope and risk check. The human developer owns shipped-game acceptance, licence decisions, exported builds and hardware/multiplayer walkthroughs. These lanes do not grant either agent authority to mark a manual release gate passed.


Hard merge rules

Every delegated task needs a baseline SHA, file scope, explicit exclusions, acceptance test command, expected user-visible effect, and a stop/escalate condition. New RNG draws, changed fixtures/goldens, save format or Session interfaces are Tier A; Codex must stop rather than silently cross the boundary. PR description must include tests run/not run and reviewer-visible changes. Cross-model review is useful but does not substitute for passing CI or human release sign-off. If agents disagree about a deterministic or compatibility change, treat the PR as blocked pending human decision. Record manual gates in PROJECT_STATUS.md with build SHA, date, result and bug/evidence reference. 'Not run' is not 'Passed'.


Workflow and priorities

First: reconcile main, open PRs and test baseline. Second: land shared agent rules and verify instruction loading. Third: simplify ROADMAP.md after preserving outstanding issue detail and project history. Fourth: select one proven menu/action-preview pattern and delegate up to three non-overlapping Codex tasks from current main. In parallel, execute exported Windows/controller/two-machine validation as hardware allows. Continue by triaging the held-back #244, #247, #253, #269 and road/loading stacks against fresh main—not assuming the October 11 notes are current. One PR per slice; merge only after scoped tests and independent review.


Lean metrics and decisions

Track open Codex PR count, integration/rebase conflicts, and cost-plus-rework per accepted PR. Additionally track the count of genuinely passed versus blocked human release gates in PROJECT_STATUS.md. No separate nine-metric dashboard or duplicate PR metadata register. GitHub is the source for branches, PR status and CI; PROJECT_STATUS.md is the source for human gates; ROADMAP.md is the prioritised queue.


Quality dimensions

Automated correctness: deterministic replay, save/load, headless tests, export smoke, performance comparisons and regressions. Player-facing quality: visual legibility, focus/read-aloud, controller ergonomics, bridge/entrance traversal, balance and multiplayer session behaviour. They are independent: CI passing never closes a human visual/gameplay gate. The radio recordings (#175) must not be redistributed until rights are established or material is replaced/removed.


Execution status

The assignments above and the new tracker are planning artefacts only. No repository branch, CI run, PR or code change is implied by editing this document. Mark individual tasks 'In progress' only once work has actually begun, and 'Done' only with a linked merged PR or completed manual evidence.


LIVE REPOSITORY CHECK — 11 October 2026

GitHub repository: https://github.com/jawaman14/skyrunner, default branch main. Checked through connected GitHub access, not a local checkout. The repository currently has 20 open PRs. Main has CLAUDE.md but no AGENTS.md. Important correction to the initial sequence: draft PR #293 already adds AGENTS.md, updates CLAUDE.md/HANDOFF.md and revises ROADMAP/DESIGN; do not duplicate that work. On PR #293, AGENTS.md points to CLAUDE.md instead of making AGENTS.md canonical. This can work if the Codex environment actually follows its explicit link, but the instruction-loading check is still required.

PR #297 contains an important autopilot waypoint-preservation fix, a radar intelligence-boundary fix and a staffed-role demand fix; it was open and draft when checked. GitHub Actions reports completed successful 'Skyrunner beta builds' runs for #293 head d276eefa and #297 head c7acd304. A green workflow does not establish a real flown approach or human build acceptance. PR #297 specifically says a 6-DOF flight-model approach was not verified; treat that as a follow-up gate, not an automatic blocker to all progress. Draft PR #296 covers the employed pilot opening and remains a separate review decision. All status statements here are snapshots, not automatic live updates.

The linked Google Sheet now marks P01–P03 'In review' rather than 'Done'. Keep PR #293 as the implementation candidate for shared instructions and roadmap integration. Prioritize review of #297's P1 route issue, while preserving human merge control. Do not launch overlapping branches for P02/P03.
