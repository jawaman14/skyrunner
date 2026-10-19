# Empire pivot (revised)

Revision 2, 19 October 2026, against `main` @ 34fd7f2. Revision 1 (the same morning) was shared in chat only. This one folds in Codex's review
(SKYRUNNER_EMPIRE_PIVOT_REVIEW.md), the owner's direction in it, and the owner's four answers given today. The simulation
contract is in [EMPIRE_SIMULATION_SPEC.md](EMPIRE_SIMULATION_SPEC.md). Nothing here was run; facts about the code are from
reading it.

## Summary

The direction changed from "flying becomes optional after the takeover" to **a hybrid of open-world character play and empire
management, with equal design weight on both, on one persistent simulation.** The first gate is no longer the story. It's a
**Living District**: one district where three organisations compete on the same economic rules. The campaign rewrite waits for
that gate, except for text-only fixes that don't touch any interface.

What I checked in the code changed the plan in four places:
1. Rival money comes from nowhere today.
2. A save-version bump silently drops old saves' state.
3. The faction keys are hard-coded across 31 files.
4. Most of the scary parity risk isn't real, because the systems that would change are already outside the parity lane.

## 1. Decisions

These rows are in [DECISIONS.md](DECISIONS.md), tracked under the roadmap section `Empire pivot (owner, 19 October)`.

| ID | Decision | Status | Source |
|---|---|---|---|
| D-62 | The player and every rival organisation share one economic model; no organisation gets money or goods except through the same rules or an explicit outside account | planned | Owner (Codex §1), EP-01 |
| D-63 | Direct and delegated operations make the same ledger and inventory changes | planned | EP-02 |
| D-64 | One authoritative simulation clock with scheduled ticks (daily books); the HQ nights become a nightly report and an optional planning pause | planned | Owner, 19 Oct |
| D-65 | Simulation detail scales with proximity and relevance, needed once several cities are fully explorable (D-78); P0 only reserves the interface | planned | EP-04, EP-07 |
| D-66 | Employees follow orders and policies only, and every refused or blocked order shows its reason | planned | EP-05, DESIGN §0 |
| D-67 | The campaign runs 1979–1989, then an alternate-history sandbox continues indefinitely | planned | Owner (Codex §1) |
| D-68 | Single-player first. The existing multiplayer keeps working (the sockets lane green on every PR) and new systems go through the command gate, but no new multiplayer features until the Living District passes | planned | Owner, 19 Oct |
| D-69 | The first gameplay gate is a Living District: three organisations competing in one district | planned | Owner (Codex §1), EP-09 |
| D-70 | Story and save restructures need explicit, tested migrations; a save is never silently dropped | planned | EP-10 |
| D-71 | The Python parity fixtures retire one subsystem at a time, replaced by Godot goldens and invariant tests; the flight golden stays | planned | Owner, 19 Oct |
| D-72 | Land the open PRs and finish heat step 1, then pause the presentation layers, heat steps 2–3, the depot raid and the map redesign; the depot raid and the map redesign get redesigned on the new rival economy and district data | planned | Owner, 19 Oct |
| D-73 | Rafa is the employer and early voice and Benny his fixer; after the takeover the story is told by characters, not one narrator | planned | Owner (Codex §2) |
| D-74 | Blotter, The House and the arena become optional ventures with lasting economic and faction consequences | planned | Owner (Codex §2) |
| D-75 | The takeover stays in chapter 4, aiming at about two hours to the boss's seat, to be measured; the half-empire loss (D-35) stays, on its own RNG stream | planned | Owner (Codex §2) |
| D-76 | Walking, driving, flying and fighting stay first-class after the takeover; the boss desk and character play are two ways into one simulation | planned | Owner (Codex §1); supersedes revision 1's "boss-first" view |
| D-77 | A larger world with several cities, every one fully explorable (D-78) | planned | Owner (Codex §1) |
| D-78 | Every city is fully explorable; none stays a strategy-only abstraction | planned | Owner, 19 Oct (O-1) |
| D-79 | When the boss dies or is jailed, the next in line takes over and the player carries on as them | planned | Owner, 19 Oct (O-2) |
| D-80 | After any ending the player carries on in the sandbox; endings are recorded, not game-overs | planned | Owner, 19 Oct (O-3) |
| D-81 | The third organisation is the Morettis, on the same rules | planned | Owner, 19 Oct (O-4) |
| D-82 | Acceleration ×1, ×4, ×16, ×60; ×1 while a human flies or is on foot in danger; in multiplayer the leader only, with every seat parked | planned | Owner left it to Claude (O-5) |

D-76 partly supersedes D-58 ("flying cargo becomes part of the logistics system, not the main focus"). Delivering is still
optional after the takeover, but direct play isn't demoted. D-58's row should say so.

## 2. Where I agree and disagree with Codex's review

**Agree:**
- Validate the economy before rewriting the campaign.
- One ledger, one clock, and equal rules for rivals.
- Command and event contracts with actor identity.
- "Equal rules, not equal brains".
- Reserve detail levels and co-op rather than build them now.

**Disagree, or refine:**
1. **Not every pivot PR needs to wait for the simulation.** The narrator fix, the Manny Arce rename and wiring `rafa.dialogue`
   into the prelude and chapter 2 are text and dialogue only, touching no interface. They can land now in Codex's lane. Only
   the takeover, goal counting, the story reorder and the ending depend on the new model.
2. **Double-entry, but lightweight.** Transfers between accounts, with a conservation invariant and an explicit outside
   boundary, are double-entry by construction (spec §3). A chart of accounts would add work without catching anything more.
3. **Don't design detail levels or reconciliation yet.** Spec §8 reserves `tick_full` and `tick_aggregate`, plus one equivalence
   test. Designing materialisation for cities that don't exist would be guessing.
4. **The parity risk is smaller than it looks** (spec §1). Los Cuervos' cash, the chronicle, the Company and the ground war are
   already off in parity runs. Only the strategic season (`strategic_ref`) and, later, shared pay rules retire fixtures.
5. **The multiplayer constraint is stronger than "architect for later".** It exists, it works and it's tested, and the owner
   said to keep it working (D-68). That's a test gate on every PR, not a future design note.

## 3. Verified blockers

| # | Blocker | Where | Consequence | Fix (PR) |
|---|---|---|---|---|
| B-1 | A save-version bump silently skips the whole sim block | `strategic_save.gd` `restore()`: `if ... v != VERSION: return` | Any new field with a version bump wipes old saves' state without telling anyone | F-1 migration chain, first |
| B-2 | Rival money from nowhere | `chronicle.gd` (+8k, +6k, and two removals into nowhere), `agency.gd` (+4k), `family.gd` (+2k), `ground.gd` (half a truck's value) | Breaks D-62 | F-3, each one named or removed, with a balance entry |
| B-3 | No ledger: 88 `money` assignments in 28 files, 43 stash cash and stock edits | All over `scripts/sim` | Can't prove conservation or equal rules | F-2 wrap (no behaviour change), F-3 move by domain |
| B-4 | Factions are hard-coded keys | `"org"` 236× in 31 files, `"rival"` 132× in 23; `CAP`, `HOSTILE` and `DOCTRINE` in `ground.gd` | A third org can't join the ground war or the old systems | New code takes the org id as data; old systems stay two-faction until a PR needs them (L-3 adds `moretti` to the economy only) |
| B-5 | The nights are tied to the pilot | `nights.gd`: the operation starts when the pilot takes off hot | Conflicts with D-64 and D-76 | F-6 scheduler and nightly report; `Nights.ENABLED` opt-in |
| B-6 | No sim-side time acceleration | Only `world_scene.time_scale` (the sky) | The desk needs it to make days pass | D-12 fixed step first, then F-7 |
| B-7 | `job_delivered` doesn't say who flew | `session_rules.gd` payload | Delegated deliveries can't count for goals | F-5 adds `by` and `mode` |
| B-8 | The strategic balance sim is built on nights | `scripts/balance/strategic.gd` | Retiring nights breaks the balance tooling | F-6 keeps the old path behind the switch; L-7 adds an "N days" sim |

## 4. PR graph

Legend:
- ⚠ = risk class (AGENTS.md): needs the other agent's exact-head review.
- **C** = Claude, **X** = Codex.
- Every PR keeps the full suite, the sockets lane and CI exports green (D-68).
- Sizes are relative (S, M, L), not dates. I'd want the spec reviewed before estimating time.

### Now (independent of the simulation)

| PR | What | Owner | Size | Gate |
|---|---|---|---|---|
| N-1 | Docs: this file, the spec, the DECISIONS rows D-62–D-77, the roadmap section, D-58's note | C, X reviews the contracts | S | `test_docs` |
| N-2 | Story text: Rafa as employer and voice in the prelude and chapters 1–2, Benny his fixer; rename Manny Arce in `campaign.gd` | X | S | No goal changes; suite green |
| N-3 | Wire `rafa.dialogue` into the prelude's stage 0 and chapter 2 (not the chapter 4 news) | X | S | Talk-scene tests |
| N-4 | Stale docs from the earlier audit (read-aloud, test counts) | X | S | `test_docs` |

### Phase 1a: foundations (all C, all ⚠)

| PR | What | Depends on | Size | Gate |
|---|---|---|---|---|
| F-1 | Save migration chain; a frozen v1 fixture loads with every block | – | S | New `test_save_migration` |
| F-2 | `Ledger` and accounts; `money` and rival cash become ledger-backed properties; unattributed adjustments are logged; **no behaviour change** | F-1 | M | All parity and goldens unchanged; conservation test |
| F-3a–f | Move the money sites to named transfers, one domain per PR (`cmds_*`, logistics, payroll, chronicle/family/agency, casino) | F-2 | 6 × S | Unattributed count falls each PR; B-2 items get a BALANCE entry |
| F-4 | Inventory lots and locations; stash stock wrapped, with no behaviour change; `Loadout` becomes a location | F-1 | M | Inventory invariants |
| F-5 | `command_as(actor, ...)` with the role shim; events carry `org` and `actor`; `job_delivered` gets `by` and `mode` | – | M | Every existing command test passes through the shim; sockets lane |
| F-6 | Scheduler and the daily books tick; nights behind `Nights.ENABLED`; nightly report from the ledger; `strategic_ref` parity retired here (D-71) | F-2, F-5 | L | Replacement goldens; report test |
| F-7 | Time acceleration on the desk, with the cap rule | D-12 (its own PR), F-6 | M | Flight golden unchanged; cap tests |

### Phase 1b: the Living District (P0)

| PR | What | Owner | Depends on | Size |
|---|---|---|---|---|
| L-1 | Business entity and district state; San Telmo Centro's businesses as data | C sim, X places them in the world | F-2, F-4 | M |
| L-2 | Product chain moved onto the ledger and inventory; legit import-to-retail chain added | C ⚠ | L-1, F-3 | M |
| L-3 | `moretti` as an economic org; org AI v1 (strategy and policy layers) on new RNG streams | C ⚠ | L-1, F-5 | L |
| L-4 | Desk: business books, staff and orders, blocked reasons | X | L-1, F-5 | M |
| L-5 | Direct and delegated delivery adapters, plus the A5 equivalence test | X adapters, C test | F-4, F-5 | M |
| L-6 | Leaving the district: aggregate ticks for the neighbours, plus the equivalence test | C | L-1, F-6 | S |
| L-7 | Acceptance suite A1–A9, P1 performance, and an "N days" balance sim | C sim, X integration and perf | all of the above | M |
| **Gate** | Owner playtest (G1) | owner | L-7 | |

### Later (planned once the gate passes)

1. **Phase 2, organisation.** Hierarchy, schedules, budgets, conditional orders and sequences, trust (D-11).
2. **Phase 3, campaign.** This is revision 1's chapter plan with these changes:
   - **Story v6 migration:** Blotter and The House become ventures (D-74).
   - **The takeover on the ledger:** half the accounts and lots move to `outside:lost` or to rivals (D-35, D-75).
   - **The chapter 4 news beat.**
   - **Goals count by org.**
   - **Tutorial lessons for the desk.**
   - **Both views kept (D-76):** the desk is not the default view after the takeover. Both stay one key away.
   - **The ending choice plus the sandbox (D-67, O-3).**
3. **Phase 4.** More cities (O-1), the map redesign resumed on district data, the depot raid redesigned on rival inventories.
4. **Phase 5.** The 1989 transition and the alternate-history sandbox.
5. **Phase 6.** Co-op authority: who is boss with several players, disconnects, simultaneous orders.

## 5. Chapter plan (from revision 1, still valid, Phase 3)

These are unchanged from revision 1:
- the chapter verdicts (rework 0–2, the takeover in 4, the org goals in 5–10, Hearings merged into the ending);
- the dialogue table;
- the tutorial additions.

Two changes:
- Chapters 5–10 keep personal goals beside the org goals (D-76). For example, chapter 9 offers "run a job for the Company"
  *or* fly it yourself for a bonus, rather than replacing the personal version.
- The flying lessons stay as flight school (rename only, N-2).

## 6. The owner's answers to O-1 to O-5 (19 October)

All five are answered (D-78 to D-82; detail in the spec's §11). What they change in the plan:
- **Fully explorable cities (D-78)** turn detail levels from a reserved hook into required Phase 4 work, designed before
  the second city is built.
- **Succession (D-79)** means Phase 2's hierarchy always names a successor, and the playable character follows the org's
  leader. The takeover in chapter 4 is the first use of the same rule: Rafa dies and the nephew is next in line.
- **Endings (D-80)** need no game-over path; the ending choice just records an outcome and the sandbox carries on.
- **The Morettis (D-81)** are L-3's third org.
- **Acceleration (D-82)** is fixed as specified for F-7.

Still open, and not blocking: whether bankruptcy ends the game. It stays §0's configurable game-ender for now.
