# Faction AI audit and commitment fixes - 8 October 2026

Audited unmerged empire stack through #240, parent eecbe90. This is source and
headless simulation evidence, not a human war walkthrough or main release result.

## Existing policies

Organisation: escorts/decoys, hottest-stash guards, raid ambushes, checkpoint
harassment, retreat and territory patrol; reserve/cooldown recruitment.
Los Cuervos: truck ambushes, exposed-stash attacks, retreat, patrol and recruitment.
Police: suspicion-based stakeouts, buy-busts, timed checkpoints, cordon/entry raids,
shooting-hotspot saturation and procurement. Family: offer evaluation and debt,
tribute and temporary support. Payroll has separate hiring/assignment/wage AI.
Human Boss/Lieutenant seats disable organisation ground/Family/payroll AI; human
orders exclude squads from automatic planning. Strategic HQ policies are a separate
night-planning layer, not a replacement for live ground commanders.

Prior focused audit: ground 26, seats 14, Family 16, payroll 17, HQ 21, nights 5;
99 passed, zero failures and no script/parse errors. Existing shutdown cleanup
diagnostics remain. This coverage did not detect the two reproductions below.

## Reproductions and narrow changes

An active escort appeared in the next available-squad list. With one truck and
one escort, the escort requirement was already satisfied, so guard planning reused
that squad. Preserve live escort jobs after the emergency retreat pass and before
ordinary ambush/guard/decoy allocation. Completed escorts remain reusable through
the existing truck update. Human-order exclusion and retreat remain unchanged.

A police squad reassigned from stakeout to Hold still produced 1.5 intelligence
per simulated minute while near the old stash. The old registration survived
because only missing squads or unavailable stashes were removed. Require a police
squad with a current stakeout order naming that stash before accumulating intel.
Remove stale registrations so replacement surveillance can be planned.

Three new regressions cover ongoing/completed escorts, outgunned retreat, valid
surveillance and Hold/other-stash reassignment. The matching focused run passes
11 tests without script/parse errors. No speed, weapons, payouts, reserve, AI
knowledge policy or route migration changes are included.

## Remaining work

Police raid planning reads exact organisation guard strength without sight filtering.
Rival/police truck planning and road penalties also read broad simulation records.
Define observed/reported intelligence before changing these calibrated policies;
measure paired seeds rather than silently restricting or expanding knowledge.

Other existing orders can also be reused during planning; this slice establishes
only the reproduced live-escort commitment. Durable order lifecycle and explicit
AI spending boundaries remain the #242 implementation package.

#240 external-removal battle reports can record the survivor as fighting after
the engagement ends. Fix final accounting without altering combat authority in a
separate slice. Human/controller/two-machine and physical access gates remain open.

## Paired-seed findings

Ten paired seeds (1-10), three simulated hours, canonical war stand-in. Baseline
was run before edits at eecbe90; after code is 6880d41. Wrapper only retains raw
rows and redirects output. All ten rows change. Median organisation cash changes
$58,212 to $54,693; mean cash $55,308.50 to $55,706.60. Mean organisation arrests
19.5 to 23.5, combat losses 5.3 to 6.3 and burned stashes 0.2 to 0.8. Police funds
median $4,794.08 to $6,256.37. Payroll shortage rate remains zero in both runs.

This is a material behavioural change, not balance-neutral presentation. Preserving
escorts changes deployment choices; clearing stale surveillance changes subsequent
planning. Both corrections are applied together, so the comparison cannot attribute
effects separately. Ten seeds do not establish full calibration or human pacing.
Keep the PR draft for wider balance/acceptance review; do not compensate through
arbitrary speed, payout or weapon tuning. Raw paired rows and aggregates are in
[the comparison record](../sim-results/faction-ai-balance-2026-10-08.json).

Desktop smoke reports SMOKE OK; native tracked-file hygiene, export exclusions
and Git diff checks pass. At code head 6880d41, all 1,026 desktop tests pass
(369/313/344), zero failed and no script/parse errors. Save/parity/export coverage
is included. Known shutdown ObjectDB/resource/PagedAllocator diagnostics persist.
These automated passes do not clear the wider balance or human acceptance gate.
