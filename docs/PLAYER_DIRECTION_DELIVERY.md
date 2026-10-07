# Discussion-to-delivery audit — 8 October 2026

[PLAYER_DIRECTION.md](PLAYER_DIRECTION.md) is the approved target. Existing PRs cover foundations, not all of these new choices. This register prevents documentation from being mistaken for completed gameplay.

| Work | Existing coverage | Remaining slice / acceptance |
|---|---|---|
| Employed-pilot opening | Four flight tutorials and twelve story chapters; chapter one starts already smuggling | New-game opening in employer aircraft with accurate ownership; legitimate work, suspicious requests, then unavoidable story smuggling. Preserve old saves/chapter indices. |
| First aircraft purchase | Hangar purchases, previews and validation; starter Cessna is free | Separate loan/use rights from ownership; explain purchase cost; no free ownership after reload. |
| Optional campaign progression | Open sandbox enables systems immediately | Money/reputation/activity unlocks with campaign alternatives; explain requirements and preserve existing save modes. |
| Configured automation | Existing payroll assignments and selected automatic trading | Explicit instructions, budgets, repeated conditions and multi-step tasks; no invented assignments during player recovery. Manual work stays available. |
| Loss/recovery | Existing crash/bust/respawn/court systems | Context-dependent hospital losses; permanent worker death/injury continuity; configurable terminal outcomes; rebuilding with survivors. |
| Impound recovery | Existing confiscation/court mechanics | Multiple validated recovery approaches with costs/eligibility and no inventory duplication. |
| Rival economy/diplomacy | #244 fixes AI commitments; existing factions/economy | Distinct starting strengths, earned growth, expansion-driven reactions; do not auto-match player level. |
| Civilian economy | Existing market/events; decorative civilians | Jobs/supplies, demand, disruption/trade and neighbourhood prosperity; deterministic authoritative effects, bounded performance. |
| Territory | #238–#240 targeting, district cards and own-unit accounts | Validate combined influence/negotiation/disruption/combat/site control; preserve existing rules until measured migration. |
| Visible organisation upgrades | #227/#228 assets and #247 settlement foundation | Stock/activity-driven property development, functional interiors, stylised period cinema; no invented stock or arrival. |
| Co-op/competitive modes, 2–16 players | Existing modes, seats, permissions and AI handoff | Organisation/rival/police role completeness and seat limits; owner-assigned responsibility. Capacity and real-peer acceptance remain unverified. |
| Leader leaves: halt session | Current handoff generally replaces vacant seats with AI | Define leader identity, stop authoritative simulation/mutations on departure, safe resume/reconnect and non-leader continuity; no automatic leader AI replacement. |
| Reports/uncertainty | #234 privacy, #239 district summary, #240/#245 battle account lifecycle | Operational debriefs and attributed information; do not repeat completed cards or leak enemy state. |
| Controls | #248 navigation/calibration/F8 | Context-aware conflicts/remapping, custom-binding prompts and physical input acceptance. |
| Physical world | #241 plan and #247 partial rebuild | 86/99 loading pairs blocked; route cost increase, connector corrections and safe movement migration remain gates. |

## Product order

1. Employed opening and first ownership milestone.
2. Player-configured automation.
3. Faction competition and interconnected civilian economy.
4. Multiplayer teamwork/competition with leader-halt rule.

Reliability and presentation are prerequisites within each phase. Recovery, impound and campaign-independent progression support the first phase; their exact mechanical rules require reviewable follow-ups. Network ownership contracts should be specified early without moving multiplayer delivery ahead of the chosen order.

## Current PR record

#249 records the decisions; it implements no mechanics. #248 improves controls and has focused input tests. #247 is a partial map foundation with balance/performance/access blockers. #241–#243 are older planning PRs; read them alongside this approved revision rather than treating them as implementations. #245's stale validation description was corrected during this review. #250 implements the first employed-opening/loan-ownership slice; its 1,039-test desktop suite and startup smoke pass, with first-criminal-route review and human pacing still required.

Do not create empty feature PRs merely to represent every row. Create narrow implementation branches when code or concrete specifications are ready. Keep drafts and unperformed human/export/controller/two-machine gates explicit.
