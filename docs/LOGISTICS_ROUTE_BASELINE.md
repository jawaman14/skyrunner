# Costa Brava logistics route baseline — 7 October 2026

Run the read-only audit with Godot 4.7.2:

```
godot --headless --path . --script res://tools/logistics_routes.gd -- route-report.json
```

The seed-12 sandbox compares legacy organisation routes with SiteAccess checked
vehicle routes using the same faction penalty hook. It enumerates every directed
HQ/live-stash origin to HQ/live-stash/buyer destination, excluding self trips and
buyer origins. Company delivery uses its existing source-dependent airfield meet.
No dispatch, inventory, money or gameplay rules change.

Result: **99 pairs, 99 unreachable** under checked access. Reasons: 62 obstructed
access legs; 37 without nearby checked vehicle access. The legacy API produces
routes for these same pairs. The audit exits successfully when it completes;
unreachable routes are findings, not a tool failure.

These coordinates are current simulation destinations, often building centres.
They must not be mistaken for validated loading areas. The next migration must
map destinations to authoritative loading/meet connectors, verify their access
legs, then compare reachable route lengths and paired-seed travel outcomes.
Do not bypass obstruction checks or widen connection limits merely to make this
report pass. Preserve La Selva's intentional isolation and the legacy API while
the callers migrate. Already travelling trucks need a last-valid-position and
blocked-state policy; new dispatch must reject before removing stock or money.

The strategic live-balance tool models broader systems and is not a substitute
for this physical endpoint audit. Human bridge/loading walkthroughs and measured
travel balance remain pending.

## Loading-area comparison, 7 October 2026

The read-only `Logistics.loading_endpoint` maps HQs, live stashes and the
Company's source-specific strip to shared authored loading points. It never
substitutes a market/building centre for a missing meeting area. `available`
means an authored candidate exists, not that its access or full route is valid.
The route audit now compares both endpoint sets without changing dispatch.

Same seed 12 and 99 directed pairs: legacy-centre checked routes remain 99/99
unreachable. Loading-area routes have 2 reachable, 97 unreachable: 53 obstructed
access legs, 31 without nearby checked access, 9 without an authored destination
(the Family social club) and 4 without a connected travel network.

Loading-area mapping alone is insufficient. Correct the remaining authored
connectors, physical route validation and meeting records before migrating
trucks. No inventory, money, route timings or balance rules changed in this audit.

## Validated local detours

Checked vehicle access now uses the same footprint detours as the site validator
and selects the nearest usable authored road node, with deterministic ties.
Both endpoint distance and actual local detour length remain bounded by 120m;
water, grades, runways, building footprints and network edges are still checked.
This does not create roads or enable live logistics dispatch migration.

The paired 99-route audit improves from 2 to 7 reachable loading routes. The two
HQ/docks routes retain identical lengths (1341.66m). Five newly valid routes are
docks/shack in both directions (11740.96m), HQ/shack in both directions (11860.83m)
and shack/Company strip (1560.32m). 92 remain blocked: 16 grade, 17 footprint,
9 unauthored meeting, 24 disconnected network and 26 no nearby access.
[Raw checked-route report](../sim-results/loading-access-2026-10-07.json).

Payroll physical vehicle travel already consumes this API; its focused movement,
blocking/lifecycle/save tests pass. Payroll effectiveness is not arrival-gated.
Broader strategic paired-seed measurements and human physical walkthrough remain
pending before integration; do not treat the route audit as an economic playtest.
