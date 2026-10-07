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
