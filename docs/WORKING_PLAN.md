# Working plan: Claude and Codex, from where we are

A proposal from Claude on 11 October 2026, for Codex to correct and the owner to decide. It sits beside, not over,
`docs/ROADMAP.md` (the queue and gates), `docs/POLISH_PLAN.md` (the owner's product order: the first hour, the menus, the
world) and `HANDOFF.md` (the baton). Where a claim comes from a keyword scan or a single run it says so; "verified" means
read in the source or measured. Nothing here authorizes a merge, a closure or a gate.

## 1. Where we stand

- **Built and merged on main (`e01feb4`):** the employed opening, the phone handset, startup entry-path coverage (#97: direct,
  implicit, room, join, leave, picker) and the per-end strip trials harness (#311).
- **Pending, not merged:** the regenerated strips report (#319; main's `STRIPS.md` is still the older audit), the autopilot
  approach-end fix (#318, awaiting Codex's exact-head review), the collaboration tools (#317), the score policy (#315, approved by
  the owner as the final rules), the server pin (#316), this plan (#320), and the server's compact inbox (#3), tally (#4) and log
  digest (#5). Each tool's benefit stays pending until the other agent shows a before and after. Also a tail of older held-back
  branches (#244 and #247 to #276) that need a merge-or-close decision.
- **What blocks calling it a release (all human, none of it ours to mark):** an exported Windows walkthrough, controller and
  read-aloud checks at four resolutions in both palettes, two-machine multiplayer with voice (#89), a macOS walkthrough, and the
  radio recordings' rights (#175, the assets are not CC0). `docs/PROJECT_STATUS.md` keeps the evidence.

## 2. What I think should be worked on, in order

Each item says who, why, and what done means. Order is by risk to the player first, then by what unblocks other work.

0. **Immediate, before anything new.** *Codex:* exact-head reviews of #317 and #318, then the refresh of #300 (its CI artifact
   exists; conflicts with current main remain). *Me:* answer review findings and keep my open PRs current. Human-gate scripts
   (item 1) proceed in parallel and need no flight decision.

1. **Make the human gates cheap for the human.** *Codex (Tier C), me to review.* A written script per gate that names the exact
   exported build and platform, the prerequisites, the actions, the expected observations and the captures needed, and ends in a
   pass, fail or blocked row for the register in `docs/PROJECT_STATUS.md`. Separate scripts for the Windows walkthrough, the
   controller, read-aloud and four-resolution visual matrix, two-device voice, and macOS. The radio rights decision (#175) is
   documentary owner work, not a gameplay walkthrough. Bounded claim: new file `docs/HUMAN_GATE_SCRIPTS.md`, base current `main`,
   checks `./tools/test.sh docs` (links resolve) and `project_status.gd --check`; the generated status section is not edited.
   Done = a reviewed, usable script. The gates themselves stay pending until a human runs them. The screenshot matrix (#300) is
   the machine half.
2. **Jobs the game can create but the aircraft cannot fly (verified in part).** *Me (Tier A).* The strip trials show QRY and PNR
   are light-load, one-way strips and EGL takes off at light load only; the Cessna 182 at max load fails the landing on every
   field. The first story chapter asks for 300 lb of cargo from bush strips, which is more than the light case. *To verify:* which
   strips and loads the job generator actually offers in chapters 1 and 2, then either gate the generator or make the strips
   fairer. The choice is the owner's (#88); the measurement is ours. The strip trials are harness evidence (one calm run per cell, a
   held runway line), not proof that every offered mission is impossible: before changing generation or geometry, cross-reference
   the generator's strip and load constraints, the aircraft configuration, seed, terrain and the automation's limits.
3. **The hub's approach on the shipped terrain.** *Me, with the owner.* On the natural terrain HAR runway end 0 has about 22 m
   more hill 1.2 km out, which puts a 3-degree final 13 m into it, so the autopilot now joins from end 1. The natural pass was
   meant to leave approaches alone. Decide: restore the approaches, or accept and document. Done = a test that pins the choice.
4. **The bot's low-altitude turn (verified).** *Me.* `PilotBot._safe_heading` turns about 40 degrees toward the lowest terrain
   ahead below 80 m, even over flat ground. It likely affects ordinary bot departures and so the balance numbers; a fix needs a
   paired-seed comparison. Done = departures hold the runway line, with the balance delta reported.
5. **Crew and economy depth (#81, #84).** *Me (Tier A), Codex audits.* Driver and mule demand are fixed numbers; lookouts count
   from posting, not arrival, because the balance contract says so. Both change outcomes, so each needs paired-seed evidence first.
6. **Incoming calls beyond the Family (#83).** *Either, Tier B.* The queue exists and the Family is its only producer. Pick the
   next deterministic source (a buyer, the lawyer, a crew member) and add it behind the existing queue.
7. **Entry paths left in #97.** *Codex.* The controller B-button cancel, and any path the audit finds that has no test.
8. **The held-back branches.** *Codex triages, the owner decides.* For each of #244, #247, #253, #265 to #269, #272 to #276: still
   needed on current main, superseded, or stale, as a one-line source-and-CI verdict. No merge, no close, nothing scored by task
   count. Batched after the immediate reviews and #300, unless one blocks them.
9. **Later, as the roadmap already says:** setup-driven automation, faction competition, the multiplayer modes. New chapters,
   the hidden informant, arrival-gated payroll and cloud deployment stay deferred until the gates pass.

## 3. Story and gameplay cohesion: questions, not findings

- In the chapters I read (1979 to 1983), goals are about cargo, cash and mechanics (stash, dealers, trucks); none asks for a landing, a strip or an approach,
  yet the early game is flown in a Cessna into bush strips. Is flight skill meant to be part of the story, or only the way
  to the next goal? (Item 2 is the concrete case.)
- The tutorial (four flying chapters), the story (twelve chapters) and the sandbox are three entries. After the employed opening,
  where does a player who skipped the tutorial learn the one-way strips?
- Each chapter unlocks a mechanic, so a chapter is a feature gate as much as a story beat. Does each unlock arrive with a first use
  the player can finish in that chapter (a stash needs product, the dealership needs cash)? A cheap audit: for each chapter, can a
  new save reach each of its goals without the next chapter's mechanics? *Codex is well placed to run it from the source:* audit
  all twelve chapters from a fresh-save state, as one table (chapter, unlocks, prerequisite, goal, evidence), separating
  what the source makes reachable from what a player has been seen to complete. The absence of landing goals is a product
  question, not a defect by itself; no new story feature until the table exists.

## 4. Tools, for each other, that save tokens without losing quality

Built: `tools/collab` (shared-file sync, a locked runner for worktrees, a board status view, a doorbell, pending in #317); Codex's
compact inbox, tally and log digest (pending in the server repository). None has earned recipient-benefit credit yet. In order:

- **First, fix the log digest's observed defect** (143 empty summaries made its output larger than the log) before building another
  diagnostic tool. *Codex's tool, my real-use evidence is on its PR.*
- **For me:** a changed-files-to-test-filter map, **advisory only**: it never replaces full CI and does not claim complete dependency
  coverage. A mutation-check helper (apply one textual change, run a filter, show it fails; I did this by hand for #318) that
  restores the change even on failure and runs only in an isolated, claimed worktree. A probe script for approach and departure
  scenarios kept in the repo.
- **For Codex:** a one-call review packet for an exact head (changed files, diff, the tests that cover them, CI and open threads,
  bounded); a claim guard that warns when a staged file is claimed by someone else; the doorbell's `once` as a silent scheduled
  check. Unattended wake or scheduling needs the owner's explicit scope. Codex acts when prompted: that is a session limit, not a choice.
- **Both:** unit-cap validation in the tally, built only together with tests for linked adjustments.

## 5. What would make each of us better at the jobs

- **Me:** measure before changing (the strip and approach work paid off because the harness came first); keep test-first for
  Tier A; stop at the edge of a claim; read less by using the packet and digest tools; report limits as I find them.
- **Codex:** it finds what I overstate (the corridor wording, the scoring flaws) and audits against source. It would be helped by
  a wake path (it only acts when prompted), by worktree-rooted tools, and by smaller outputs.
- **Together:** workflows by task type: spike then build for bugs, test-first for Tier A, fan-out for audits and matrices, a
  pipeline for pull requests with one merge owner, both drafting for rules and design. Revisit the split after three comparable
  completed units, as the score policy says.

## 6. Decisions only the owner can make

1. Item 2: gate the job generator by strip and load, or make the strips fairer?
2. Item 3: restore HAR's approach on the natural terrain, or accept the hill?
3. Whether flight skill belongs in the story's goals (section 3).
4. Which held-back branches to close (item 8).
5. Whether to let Codex's scheduled check start its own turn (`notify.py --wake-cmd`), which spends its quota.
