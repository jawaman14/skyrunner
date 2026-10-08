# Road graph construction review — 8 October 2026

The #247 rebuild increased graph-construction cost and #258 improved A* search
only. Index legacy junction candidates in spatial bins, retaining the earliest
matching insertion exactly (including when it is farther than another match).
The 60 m merge rule, speculative T links, stub rules, node indices, adjacency
ordering, checked authored-edge membership and public route APIs stay unchanged.
The existing exact-coordinate checked-network index is untouched.

Seventeen road tests pass. A historical linear-node constructor verifies every
node and adjacency entry on Costa Brava; negative bin boundaries, first-match
choice and subsequent stub insertion are covered. Existing path tie/penalty,
geometry, villa and FRM compatibility checks also pass.

An isolated seven-pair construction benchmark on the current 1950-node physical
map graph records **167.849 ms mean linear versus 28.662 ms indexed**. All seven
complete graphs match exactly; 100 paired A* queries have zero path mismatches.
The existing linear/heap search means are 2.141/1.845 ms in this run. Raw evidence
is `sim-results/road-node-index-2026-10-08.json`; the reproducible tool is
`tools/route_search_benchmark.gd`.

This resolves the reproduced construction hot spot without removing streets or
tuning travel. It is a machine-specific headless microbenchmark, not gameplay
frame-time, dense-combat or human map acceptance. Paired simulation and full
regression evidence are recorded in the completion review. Earlier AI/map
balance shifts and the 78 blocked loading pairs remain separate open gates.
