# Physical access and movement implementation package

Status: proposed remaining implementation, 8 October 2026. This document adds no
roads, dispatch migration or combat changes. Depends on the implementation stack
through #240; #235 and #237 already provide endpoint lookup and local detours.

## Evidence and priority

The dated Costa Brava audit covers 99 directed logistics pairs: 7 reachable,
92 blocked. Failure categories are 16 grade, 17 footprint, 9 unauthored meeting,
24 disconnected network and 26 without nearby access. These are route-query
results, not a human walkthrough. See LOGISTICS_ROUTE_BASELINE.md and the raw
sim-results/loading-access-2026-10-07.json report. Do not solve failures by raising
connector limits or restoring straight-line fallback.

## Reviewable implementation slices

1. Reproduce HAR, Warehouse 7, HQ and dock access in the developer overlay. Record
   site IDs, entrance/loading coordinates, road node, obstruction and intended
   travel mode. Verify shared site data against render geometry and collision.
   Correct misplaced loading points only when the physical yard supports them.
2. Resolve grade/footprint failures with narrow authored approach corrections.
   Validate both directions, bridge approaches, foundations, interaction occlusion,
   runway clearance, water and building exclusion. Preserve terrain and La Selva's
   deliberate lack of a public road. Distinguish remote boat/foot destinations
   from missing vehicle access instead of promising vehicle reach everywhere.
3. Author the Family meeting/loading record at the actual functional location.
   Keep permission/availability checks and closed states. No substitute market
   centre. Reaudit all 99 pairs, publishing before/after lengths and reasons.
4. Migrate logistics dispatch only for validated intended vehicle endpoints.
   Reject unreachable orders before money or stock leaves its source. Persist
   blocked reason and last valid travelling state; do not duplicate cargo on
   reroute, save/load or cancellation. Keep legacy route API for unmigrated callers.
5. Migrate squad access separately after truck evidence. Check destination and
   access legs before changing an order. Preserve worker identity across truck,
   foot, squad, jail, away and death; animation must not decide arrival.
6. Only after movement acceptance, measure issue #85's member-contact migration.
   Compare legacy and proposed contact/loss accounting on paired seeds. Preserve
   authoritative combat, morale/court/economy effects and parity switches. No
   speculative weapon, speed, payroll or payout compensation.

## Acceptance record required per implementation PR

- Focused checked-route, refusal-without-mutation, blocked journey and lifecycle tests.
- Fixed site/seed route report with original and corrected coordinates/lengths.
- Human walk and drive in both directions at every touched entrance/loading point.
- All graphics presets: visible passage agrees with collision and interaction reach.
- Save/load and human-to-AI handoff preserve units, goods and money exactly once.
- Paired travel/balance seeds; full shards, smoke, save/parity and export checks.

Use one codex branch/draft PR per implementation slice above. Link evidence in the
PR; leave unperformed physical checks pending. This package must not close #85 or
enable wholesale migration merely because a route query succeeds.
