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

Five focused employment tests cover staged command/delivery integration, duplicate events, stale work, dropped work, read-only cost previews, denied purchases without mutation, first ownership, save/reload before and after the opening, old-save chapter compatibility and returning the company aircraft. Legacy story (17) and job-action (3) tests pass. Full regression and isolated desktop smoke are in progress; record final results before integration. Existing ObjectDB/resource shutdown diagnostics are separate from script/parse failures.

Unperformed: human opening walkthrough, first-purchase pacing, multi-resolution visual/controller/read-aloud acceptance, exported builds and real two-machine delivery. Keep draft.
