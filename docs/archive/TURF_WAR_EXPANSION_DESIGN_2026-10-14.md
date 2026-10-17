# Turf War Areas, Combat and Logistics Design

## Decision

Expand turf inside the existing island first, then make the same systems usable by additional playable regions. Improve NPC combat decisions and convoy logistics along with the area model. The classic map and Costa Brava are the initial region packages; Costa Brava receives finer authored districts while the classic map preserves its current four broad market areas.

## Why this slice

The game already has range-aware firefights, squad morale, field orders, checkpoint-aware path costs, truck escorts and four economy markets (`town`, `west`, `north`, `sea`). However, `GroundWar.market_at()` assigns every position to one of those markets by nearest centre. Squad presence, territory income, recruitment pressure, market prices and most strategic AI therefore see large areas as single points. Combat AI still chooses using flat squad odds, and a truck's route is not reconsidered after it leaves when a checkpoint or hot spot changes the risk.

The map layouts already provide stable map IDs, airfields, HQ zones, roads and authored Costa Brava geography. The design adds authored turf districts to those layouts and keeps their existing markets as parent/economy rollups.

## Goals

- Give Costa Brava several legible, locally contested districts that follow its port, city, estuary, farm plain, northern range and cove geography.
- Keep the classic map's current market-level behavior and preserve the public `market_at`, `org_share`, `rival_share`, economy and save contracts.
- Make territory definitions map-owned and keyed by stable IDs, so a later playable map can bring its own districts without adding another `if map == ...` chain to the simulation.
- Make combat AI consider range, local cover, morale and nearby support before choosing to hold, advance, attack or withdraw.
- Make convoy routes and escort choices respond to changing known checkpoints and recent fighting while retaining a safe fallback when no low-risk route exists.
- Keep all choices deterministic and preserve the existing Python-parity switches and RNG streams.

## Non-goals

- Building a new terrain renderer, city asset set, economy market, campaign chapter or multiplayer protocol.
- Removing or renaming the four economy markets.
- Adding arbitrary user-authored map editing or a new playable island in this slice. The layout interface must support those later.
- Changing weapon damage, recruitment budgets, tribute rates, cargo seizure rules or story balance without measured follow-up.

## Region and territory model

Each `MapLayout` owns a region ID and an array of territory records. A record has a stable local ID, display name, parent economy market, representative point, authored boundary, neighboring territory IDs, and optional strategic tags (port, city, rural, remote, airfield, stash corridor). A qualified ID is `<region_id>/<territory_id>`; IDs must not depend on array order or generated coordinates.

Costa Brava starts with ten named areas: San Telmo Centro, Barrio Chino, the Docks, Airport Coast, Rio Negro Estuary, Valle Verde, La Selva, Sierra del Aguila, Old Quarry and Smuggler's Cove. Boundaries follow the city grid, harbour, river/estuary, farm plain and ridgelines where possible. All uncovered points fall back to the nearest authored area, so procedural and offshore positions remain defined. The classic map keeps the four existing broad markets as its initial areas. Additional map layouts can provide their own authored array and region ID.

Ground control is accumulated per local territory. Existing `control[market]` and market share methods remain available as compatible rollups; economy price updates and existing save fields continue to use those market keys. New territory views expose both the local share and the parent market. The region and territory IDs are carried in views and new persistence fields; older saves derive their defaults from the active layout and keep their existing market control.

## NPC combat behavior

The existing combat resolver remains the authority for losses and arrests. Before committing a free squad to an order, the commander compares its range-adjusted fire against visible enemies, its own and nearby friendly support, morale, and cover at the likely contact area. A strong, high-morale squad may close or hold its preferred range; an even fight favors cover and support; a badly outnumbered or low-morale squad falls back toward safe terrain or friendly territory. Existing human orders continue to override the AI. Patrol and attack selection scores local territory pressure, strategic tags and distance rather than only the parent market.

The first slice uses existing `fire_at`, land-use cover and route helpers; it does not add individual weapon inventories, new damage rules or vehicle dismount choreography. Decisions use existing seeded commander state or deterministic scoring and do not consume another subsystem's random stream.

## Logistics behavior

When a live ground-war truck has a route and a new known checkpoint or recent hot spot makes that route materially more dangerous, the planner compares the remaining path with alternatives and updates the driver's remaining route while preserving progress and ETA accounting. If no safer connected path exists, the truck continues on the least-cost route and the existing encounter/seizure rules apply. The organization prioritizes escorts for valuable loads on risky routes; police choose checkpoints and tails from current truck routes; rivals choose ambush locations on the remaining exposed route. Replanning is rate-limited to avoid route churn and runs through the existing road graph and faction-specific known-threat costs.

## Compatibility and saves

- `Economy.MARKETS`, trade jobs, rackets policy names and legacy market shares remain stable.
- Existing snapshots and saves without territory fields continue loading. Legacy market control is projected into each layout's initial areas until local presence accumulates.
- New data is deterministic from the active map layout; no extra simulation RNG draws are required.
- A dedicated feature switch gates territory-specific behavior so parity and existing balance configurations can turn it off.

## Delivery stages

1. Add the region-owned territory catalog, Costa Brava districts and classic-map fallback; expose local control and market rollups.
2. Use territory pressure plus range, morale and cover in squad AI decisions and targets.
3. Replan exposed truck routes after threat changes and make escort/ambush choices use the route's local risks.
4. Document the IDs, compatibility contract, save behavior and future path for adding another map package.

## Review and acceptance

- Existing four-market outputs remain valid and unchanged in shape.
- Every map position resolves to a valid territory; every authored neighbor and parent market resolves.
- Territory IDs stay stable across reloads and save migration.
- Squad orders change in the expected direction under favorable, even and poor fight conditions, while explicit human orders remain respected.
- A new checkpoint/hot spot can cause a truck to change its remaining route when a viable alternative exists; no route alternative leaves the truck moving.
- No RNG stream outside the ground-war subsystem advances due to territory or AI scoring.

