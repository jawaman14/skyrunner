# Checked connector review — 8 October 2026

Draft #237 chose each endpoint's nearest physically clear node independently.
A reproduced three-road fixture has two nearby disconnected dead ends and a
connected authored road 50 m from both endpoints. The original query incorrectly
returned no connected network.

Successful existing nearest-node routes keep their exact choice. Failed queries
now try deterministic nearby pairs in the same geometry-verified component,
checking both access legs and their actual detour lengths against the unchanged
120 m limit. A shared isolated node cannot substitute for a public-road journey.
The existing A* and live route-penalty hook still choose the network path; only
immutable geometry membership is cached. Explicit geometry invalidation clears
both edge and component caches.

Nine site-access tests pass, including the reproduced alternate connection,
determinism, unbridged-water refusal, disconnected short-network refusal,
building/runway/grade checks and live penalties. Legacy route() is unchanged.
The real Costa Brava loading audit remains 21 reachable / 78 blocked of 99:
this algorithm correction does not repair missing physical roads or meetings.
Full grouped regression and human physical acceptance are recorded separately.
Truck/squad dispatch migration remains gated; payroll vehicle travel already
uses the checked API, so its focused regression remains required.
