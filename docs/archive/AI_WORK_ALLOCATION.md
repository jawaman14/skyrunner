# AI work allocation and release gates

Source: [Google Sheet](https://docs.google.com/spreadsheets/d/1IEaOf5spBK-FMJp5IIRZeUk1k_U7BNheWPZpUhhoZto/edit). Imported and reviewed on 11 October 2026.
Related rationale: [agent work-split document](AGENT_WORK_SPLIT.md).

The source values below are preserved as a planning snapshot. Review recommendations are separate; this import does not edit the live Google Sheet or mark any task or release gate complete.
Machine-readable copies: [work allocation CSV](AI_WORK_ALLOCATION.csv) and [summary CSV](AI_WORK_ALLOCATION_SUMMARY.csv).
CSV preserves cell values, but not Google Sheets formatting or validation.

## Review findings

1. **P15 has an inaccurate scope label.** PR [#244](https://github.com/jawaman14/skyrunner/pull/244) is “fix: retain live escorts and clear reassigned police stakeouts.” It changes faction behaviour and has balance implications, rather than being a flight-model change. Rename the task to “Faction escort/stakeout fixes and balance review (#244)” while retaining Claude's Tier A ownership and paired-seed review.
2. **P23 should begin before human tests.** Its dependency on P18–P22 makes the evidence register appear to wait for the runs it must record. Create the register after P01, then update it during each run or rights decision; completion still depends on the relevant evidence.
3. **Urgent review work needs an explicit assignment.** P01 mentions [#297](https://github.com/jawaman14/skyrunner/pull/297), but no separate row tracks its review, human merge decision or outstanding real flight-model approach. Add a bounded review task; keep real flown acceptance separately recorded.
4. **The new MCP safeguard task is absent.** Draft [#298](https://github.com/jawaman14/skyrunner/pull/298) rejects zero-test success, unknown mergeability and empty CI jobs. It depends on #293. Seven mocked regression cases, Godot import, project-status check and docs tests passed; full game suite and MCP protocol integration remain unverified. Track it as “In review,” not “Done.”
5. **P04 remains unproven for a cold cloud environment.** Local Godot 4.7.2 import and focused checks succeeded during #298, but that does not establish its stated cold-sandbox full-suite acceptance. Keep it open and distinguish local setup evidence from cloud setup evidence.
6. **Some human gates lack explicit rows.** P09 covers automated captures, while P19 covers controller/accessibility checks. Add explicit four-resolution/two-palette visual acceptance and bridge/functional-entrance walk/drive runs, each with build SHA and tester evidence. P12's exported checks partly cover traversal, but should not conceal the human run.
7. **The baseline is a snapshot.** P01's “20 open PRs” predates the new draft PRs. The connected GitHub open-PR query returned 22 PRs during this review. Refresh the count from GitHub and record when it was checked. P02/P03 remain “In review” because #293 is still an open draft.
8. **The summary is internally consistent.** There are 23 tasks: 9 Codex-led, 8 Claude-led and 6 human-led; 10 are P0 and none is marked completed. No dependency references an unknown task ID. The five Summary totals use COUNTIF formulas bounded to rows 2–24. Extend those ranges when adding tasks, or new rows will be excluded.

## Repository evidence inspected

- #293: open draft, head `d276eefa0dc98b914cd6cfd965166581e2f1a18c`; shared rules and documentation remain proposed.
- #296: open draft, head `55e624a8c7a0da23a9f411fc7d43a062ca185130`; employed opening remains a separate review decision.
- #297: open draft, head `c7acd304fd2c308883ca96cd0d7b6815d7967ca7`; fixes waypoint preservation, radar intelligence boundaries and staffed-role demand.
- #298: open draft, head `e260f8697578e11e0a5fb9915cd29ba4a6a6c294`; dependent MCP safeguards.
- #299: documentation import and this tracker review.

PR metadata and #244's scope were read through connected GitHub tools. CI was not freshly checked in this tracker review, and no manual release acceptance was performed. These observations do not authorize merges.

## Source tab: Work allocation

| ID | Task | Lead | Reviewer / support | Risk | Priority | Status | Next action / scope | Acceptance evidence | Dependency |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| P01 | Reconcile repo baseline | Codex / ChatGPT | Claude Code | C | P0 | In review | Live 11 Oct baseline: main has CLAUDE.md but no AGENTS.md; 20 open PRs. #297 is urgent P1 autopilot correction; #293 includes shared instructions. Check latest CI before marking done. | Source-linked current-state summary | — |
| P02 | Shared agent rules | Codex / ChatGPT | Claude Code | C | P0 | In review | Already implemented in Claude's draft PR #293 (AGENTS.md links CLAUDE.md and HANDOFF.md); review/merge and verify Codex actually follows those linked rules; do not open duplicate PR. | Both agents load rules; docs tests pass | P01 |
| P03 | ROADMAP cleanup | Codex / ChatGPT | Claude Code | C | P0 | In review | ROADMAP/DESIGN revisions included in draft PR #293; review against current main and preserve unresolved items; avoid conflicting separate edits. | Open tasks preserved; docs links pass | P01 |
| P04 | Codex Godot setup | Codex / ChatGPT | Claude Code | C | P0 | Planned | Pin/install Godot 4.7.2 inside repo; headless import | Cold sandbox test suite run | P02 |
| P05 | Reference action-preview screen | Claude Code | Codex / ChatGPT | B | P1 | Planned | Establish tested UI pattern and screenshot baseline | Merged reference PR, tests, human visual check | P01 |
| P06 | Remaining action previews | Codex / ChatGPT | Claude Code | C | P1 | Planned | Repeat P05 pattern in isolated screen PRs | Tests plus reviewed UI capture | P05 |
| P07 | Menu focus and remote outcomes | Codex / ChatGPT | Claude Code | B | P1 | Planned | Logistics and rackets UI from stable interface | Modal input tests; screenshots | P05 |
| P08 | Open issue audit | Codex / ChatGPT | Claude Code | C | P1 | Planned | Reproduce and classify old issues | Evidence on each triaged issue | P01 |
| P09 | Screenshot CI matrix | Codex / ChatGPT | Claude Code | C | P1 | Planned | Four resolutions × two palettes | Eight labelled captures; human review outstanding | P04 |
| P10 | Evidence and docs cleanup | Codex / ChatGPT | Claude Code | C | P2 | Planned | Archive redundant reports and validate links | Docs tests green, historical links retained | P03 |
| P11 | Determinism, Session, saves | Claude Code | Codex / ChatGPT | A | P0 | Planned | Guard replay and compatibility invariants | Paired-seed parity, save-load, reviewed diffs | P01 |
| P12 | Road, bridge and access | Claude Code | Codex / ChatGPT | A | P1 | Planned | Geometry, site connectors, route migration | Route audits and exported walk/drive evidence | P01 |
| P13 | Interior fixes and placement | Claude Code | Codex / ChatGPT | A | P1 | Planned | Hangar, HQ, casino, collisions | Representative map and walkthrough checks | P12 |
| P14 | NPC/truck/squad routes | Claude Code | Codex / ChatGPT | A | P1 | Planned | Re-run logistics blocked count; migrate | Route audit and paired-seed comparisons | P12 |
| P15 | Flight/balance (#244) | Claude Code | Codex / ChatGPT | A | P2 | Planned | Evaluate held-back balance PR | 200-seed comparison and human judgement | P01 |
| P16 | Visual/perf/video held-backs | Claude Code | Codex / ChatGPT | B | P2 | Planned | Review #247, #253, #269 on current main | Measured render, performance, export diffs | P01 |
| P17 | Art/provenance | Claude Code | Codex / ChatGPT | B | P2 | Planned | Validate coastal reference and sourcing | Human visual check; asset provenance | P12 |
| P18 | Windows exported walkthrough | Human developer | Both agents support | Human | P0 | Not run | End-to-end build test | Build SHA, date and pass/fail evidence | P01 |
| P19 | Controller and accessibility | Human developer | Both agents support | Human | P0 | Not run | Real input, focus, read aloud | Hardware and build SHA evidence | P01 |
| P20 | Two-machine multiplayer | Human developer | Both agents support | Human | P0 | Not run | Seats, actions and voice test | Two-device evidence and tracked bugs | P01 |
| P21 | macOS walkthrough | Human developer | Both agents support | Human | P1 | Not run | Test exported macOS build | Build SHA and recorded findings | P01 |
| P22 | Radio recordings rights (#175) | Human developer | Codex research support | Human | P0 | Undecided | Verify redistribution, remove or replace | Written rights decision/approved replacement | P01 |
| P23 | Release-gate register | Human developer | Codex / ChatGPT | Human | P0 | Planned | Update PROJECT_STATUS.md for actual runs | Gate, build SHA, date, outcome, issue | P18–P22 |

## Source tab: Summary

| SKYRUNNER — AI WORK ALLOCATION | 11 Oct 2026 planning baseline |
| --- | --- |
| Codex / ChatGPT-led | 9 |
| Claude Code-led | 8 |
| Human-led | 6 |
| Completed | 0 |
| Priority P0 | 10 |
| Operating principle | Task ownership is proposed; GitHub state and manual test outcomes need verification. |
| Tier A | Claude integration: deterministic simulation, saves, world geometry, flight and balance. |
| Tier B | Either agent with scope limits and independent review. |
| Tier C | Codex: docs, repetitive screens, issue triage, CI and isolated tests. |
| Human gates | Only real tested builds / hardware / rights decisions can clear release gates. |

## Summary formulas preserved

| Cell | Formula | Displayed result |
| --- | --- | --- |
| B2 | =COUNTIF('Work allocation'!C2:C24,"Codex / ChatGPT") | 9 |
| B3 | =COUNTIF('Work allocation'!C2:C24,"Claude Code") | 8 |
| B4 | =COUNTIF('Work allocation'!C2:C24,"Human developer") | 6 |
| B5 | =COUNTIF('Work allocation'!G2:G24,"Done") | 0 |
| B6 | =COUNTIF('Work allocation'!F2:F24,"P0") | 10 |
