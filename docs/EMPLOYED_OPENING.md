# Employed-pilot opening — 8 October 2026

## Implemented scope

Fresh story games (desktop and dedicated story startup) begin with Costa Brava Air Services. You immediately fly the employer's Cessna, with no aircraft in your owned fleet. The existing twelve story chapters follow an opening sequence; the four flight lessons are unchanged.

1. **On the payroll:** two ordinary supply deliveries, primarily HAR–VAL. Fuel/loading/payment remain the existing systems.
2. **An unusual customer:** one sealed-case request. The briefing establishes financial pressure and suspicious customer behaviour; this cargo has no contraband flag.
3. **No more pretending:** one disclosed marijuana delivery. Police consequences apply; postponing is possible, but this story cannot progress through a permanent legitimate-only branch.

After those four flights, Square Grouper opens trade/payroll as before. Opening stages are retained in guidance/history. Dropped jobs, stale-stage jobs and repeated delivery events do not advance progress. The criminal load uses the existing contraband handling rather than a cosmetic criminal label.

## Ownership and pricing

The hangar distinguishes employer use from ownership. Purchasing the loaned Cessna costs a provisional **$18,000 in this new career path only**; other modes and old saves retain their original prices. Buying another aircraft returns the loan and does not make the Cessna free to reacquire. The shared preview and authoritative handler compute the same cost and recheck funds, dealer access and active jobs.

This is a first implementation price, not calibrated balance. Starting money and existing cargo/contraband payment formulas are retained. Job payout is currently the player's earnings; employer commission, wages and employer-funded fuel/maintenance are not implemented. Fuel/loading costs and risks are disclosed rather than claiming company-funded operation. Human pacing must decide whether this structure needs a separate employment contract.

## Compatibility

Only explicit fresh story startup opts in. Story.new and historical Story.from_dict saves retain their current chapters. Optional employment fields preserve opening stage, completed-delivery serial and loan rights. Empty ownership is valid when the saved employer loan remains active. Neither loading nor completing the opening grants free ownership.

The existing save system does not persist active flight jobs/cargo; a saved unfinished employer flight is re-offered after loading rather than restored as an in-flight contract. Opening progress remains saved. This slice does not claim to fix full flight-contract persistence.

CLI chapter skipping explicitly skips the opening before advancing existing numbered chapters. Open sandbox and flying lessons retain their existing behaviour. Campaign-independent money/reputation/activity unlocks, broader automation, recovery/impound choices and leader-disconnect multiplayer rules remain follow-ups.

## Acceptance evidence

Five focused employment tests cover staged command/delivery integration, duplicate events, stale work, dropped work, read-only cost previews, denied purchases without mutation, first ownership, save/reload before and after the opening, old-save chapter compatibility and returning the company aircraft. Legacy story (17) and job-action (3) tests pass. Final desktop regression at code head `c29945c`: **1,039 passed, 0 failed** (329 / 361 / 349), with no script/parse failures. The initial run exposed a stale dedicated-server chapter expectation; the updated assertion and explicit opening skip passed in the complete rerun. Isolated startup smoke with real Enter input: **SMOKE OK**, 1,800 frames, simulation time 12.2 seconds. Native diff checks pass; export/save/parity checks are included in the suite. Existing ObjectDB/resource shutdown diagnostics are separate from script/parse failures.

Unperformed: human opening walkthrough, first-purchase pacing, multi-resolution visual/controller/read-aloud acceptance, exported builds and real two-machine delivery. Keep draft.

## Follow-up route review

The initial criminal employer route uses HAR/VAL, both police airports. Existing customs checks give a hot arrival a 35% inspection chance before pursuit consequences. Author a suitable non-police destination for the first criminal contract and validate arrival/unloading before treating the opening as ready for human acceptance. Do not disable police rules to make the introduction succeed.

Route follow-up: the first criminal contract now chooses the nearest non-police bush/shady strip with at least 400 m of runway. Costa Brava selects Finca Morales on the normal opening path. Actual arrival starts existing timed hot unloading; chapter progress waits for unloading completion. Police/customs authority remains unchanged. Focused coverage also checks representative generated seeds 1, 7 and 42. The parent’s 1,039-test suite is prior evidence; record follow-up validation separately.

Follow-up validation: **7 passed, 0 failed** in 79.5 seconds, with no script/parse failures. Includes real arrival/unloading, unchanged police/customs enforcement and generated seeds 1/7/42. The full suite was not rerun on this route-only follow-up; parent full-suite evidence remains 1,039 passes. Full integration and human/export/two-machine gates remain pending.

Latest combined CI at `be22895`: [run 37655944895](https://github.com/jawaman14/skyrunner/actions/runs/37655944895) passed all three shards (**1,041 tests: 329 / 361 / 351**), hygiene, dedicated-server checks, exports and Linux/Windows/macOS smoke jobs. These exported automated checks supersede the local export limitation; human exported-build, controller and two-machine acceptance remain unperformed. The earlier `c29945c` run reported aggregate failure despite its five listed jobs succeeding; the latest complete eight-job run is the current integration evidence.

## First-ownership presentation follow-up

### Explicit chapter correction, 8 October 2026

The earlier CLI skip claim missed chapter 1: it still entered the employment
prelude. PR #255 fixes the startup entry point through shared chapter selection.
Nine employment tests now cover chapters 1, 2 and 12, default startup and the
existing opening/ownership/save behavior. The combined corrective gameplay
stack at `54db9d7` passes 1,050 desktop tests and isolated startup smoke. This
is unmerged-stack evidence; human pacing and exported walkthrough remain pending.

The first successful aircraft purchase in the employed career records the aircraft and actual price in the existing saved story journal. Failed purchases and later switches add no milestone. Opening guidance changes from the loan/purchase explanation to the owned aircraft and current savings. No prices, unlocks or aircraft behavior change. Eight employment tests and seventeen legacy story tests pass (25 total), with no script/parse failures. This presentation follow-up has focused validation; the previous head’s 1,041-test CI is prior evidence, not a full run of this follow-up.
