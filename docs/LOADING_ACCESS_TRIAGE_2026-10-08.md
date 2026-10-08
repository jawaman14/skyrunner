# Loading-access triage — 8 October 2026

The road-junction correction in #275 leaves the fixed loading matrix at 26/99
reachable. Of the 73 blocked journeys, 43 report disconnected travel networks,
28 lack nearby checked vehicle access and two encounter EGL/QRY shed footprints.
These are checked failures, not grounds for relaxing grade or connector limits.

The component diagnostic now derives its endpoint list from the same live stashes
and meeting registry as the route matrix, instead of a hand-maintained subset.
It retains unavailable endpoints and includes authored site IDs and coordinates.
Existing component/index/reason fields remain compatible. It issues no orders.

The main component includes HQ, barn, docks, lock-up, shack and Family. Camp,
villa, quarry and the FRM Company meeting occupy distinct components. Boathouse
and rival HQ have authored loading areas but no nearby checked connector.
Company meeting selection is source-dependent: this component report uses HQ;
the 99-pair matrix remains authoritative for other source/meeting combinations.

Next physical work must reproduce the two building intersections and inspect
the road boundaries of the separate components. Preserve deliberate remote
locations and cay access; do not invent public roads or flatten terrain to make
every endpoint reachable. Truck/squad migration remains gated on validated
access and explicit refusal before dispatch spends money or removes goods.

Validation: the updated diagnostic completed with exit zero, no script/parse
errors, and all twelve registered endpoints represented. Graph nodes, components
and blocked-edge classifications match the previous junction report exactly.
Godot shutdown resource/PagedAllocator diagnostics remain separate cleanup
limitations. This is source evidence, not a human driving walkthrough.

Evidence: [complete endpoints](../sim-results/loading-endpoint-components-2026-10-08.json)
and [fixed route matrix](../sim-results/junction-loading-access-2026-10-08.json).
