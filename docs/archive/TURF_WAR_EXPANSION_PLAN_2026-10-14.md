# Turf War Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add local turf districts to the existing maps and make combat and logistics NPC decisions adapt to territory pressure and changing danger.

**Architecture:** `MapLayout` owns stable region and territory definitions. `GroundWar` resolves positions to local areas while keeping the existing four economy markets as compatible aggregates. Its deterministic AI uses local tactical estimates; `Logistics` asks the faction-aware ground route planner to refresh exposed trucks without resetting driver progress.

**Tech Stack:** Godot 4.7.2, pure GDScript, existing `MapLayout`, `RoadGraph`, `GroundWar`, `Logistics`, `StashNet.Truck` and `Agent` systems.

**Spec:** `docs/archive/TURF_WAR_EXPANSION_DESIGN_2026-10-14.md`

## Global Constraints

- Pure GDScript on Godot 4.7.2; no new dependencies.
- Warnings are errors; type Variant-derived locals explicitly.
- Preserve deterministic simulation and existing RNG streams.
- Preserve `Economy.MARKETS`, legacy save fields and public market methods.
- Do not merge or publish this work without a separate user request.
- The user explicitly authorized verification after implementation. The existing full suite, import, smoke run and live-war balance sample were run; no test files were added. Results and engine-log caveats are recorded in `HANDOFF.md`.

## Review Focus

- Map points outside authored boundaries still resolve to a valid territory: use an edge/fallback case in the owned territory lookup.
- Legacy saves have only market totals: verify the migration path does not erase or duplicate control.
- A territory belongs to a valid economy market and region: validate on catalog construction and reject malformed records safely.
- A truck route changes after partial progress: preserve its current position, driver task and remaining trip accounting.
- Human-directed squads are not overridden by AI: retain the `human` command guard while adding decisions.

---

### Task 1: Add map-owned territory data

**Files:**
- Modify: `scripts/sim/map_layout.gd`
- Modify: `scripts/sim/map_city.gd`
- Modify: `scripts/sim/map_gen.gd`
- Modify: `scripts/sim/switches.gd`
- Create: `scripts/sim/territories.gd`

**Interfaces:**
- `MapLayout` provides a stable `region_id` and `territories` array.
- `Territories.at(layout, position)` returns the matching territory record or deterministic nearest-area fallback.
- `Territories.territory_ids(layout)` returns stable qualified IDs; records carry `id`, `name`, `market`, `center`, `bounds`, `neighbors` and `tags`.

- [x] Define the territory record shape and validation/fallback rules in `Territories`.
- [x] Give the classic layout broad areas that preserve its current west/north/sea assignment.
- [x] Add the ten Costa Brava districts and authored adjacency/parent-market data.
- [x] Register a territory feature switch without changing the parity defaults.
- [x] Update the design reference with stable ID and compatibility rules.

### Task 2: Track local control with market-compatible rollups

**Files:**
- Modify: `scripts/sim/ground.gd`
- Modify: `scripts/sim/strategic_save.gd`
- Modify: `scripts/sim/chronicle.gd`
- Modify: `scripts/sim/payroll.gd`
- Modify: `scripts/sim/rackets.gd`

**Interfaces:**
- `GroundWar.territory_at(position)` resolves against `sess.world.map`.
- `GroundWar.territory_share(id, faction)` reports local share.
- Existing `market_at`, `org_share`, `rival_share`, `control` and `turf` remain compatible.
- Snapshot/save data gains optional region-qualified territory values; older data defaults safely.

- [x] Initialize per-territory control for the active map, seeded from legacy market distribution.
- [x] Update local presence and parent-market totals from the same squad/fight events while retaining their separate storage contracts.
- [x] Expose local areas in the war snapshot and preserve save round-trips/migration.
- [x] Keep economy prices, trade and tribute policies at their current market granularity; their existing market APIs remain the rollup boundary.

### Task 3: Make squad AI territory-aware and tactically responsive

**Files:**
- Modify: `scripts/sim/ground.gd`

**Interfaces:**
- A deterministic tactical score consumes squad/enemy range, morale, cover, nearby support and local territory importance.
- Existing `order`, field orders and the combat resolver remain the command and outcome authorities.

- [x] Score territory objectives using local control pressure, strategic tags and travel distance.
- [x] Compare range-adjusted attack pressure and morale before choosing to commit, hold or withdraw.
- [x] Keep human-owned orders and hidden-target rules intact.
- [x] Resolve retreat points from safe cover/friendly territory through the existing route system.

### Task 4: Replan threatened logistics routes and focus escorts

**Files:**
- Modify: `scripts/sim/logistics.gd`
- Modify: `scripts/sim/ground.gd`
- Modify: `scripts/sim/agent.gd`
- Modify: `scripts/sim/stashes.gd`

**Interfaces:**
- Route refresh consumes a truck's current position, destination, faction and known threat costs; it updates only the remaining driver route.
- Existing `GroundWar.route` remains the single source for faction-aware road costs.

- [x] Preserve current route progress and time when refreshing a truck route.
- [x] Trigger a rate-limited refresh when checkpoints or recent hot spots affect a live route.
- [x] Score cargo value and route exposure when assigning escorts.
- [x] Place police checkpoints, tails and rival ambushes using the current remaining route.
- [x] Keep existing seizure/hijack outcomes as-is when the route has no viable alternative.

### Task 5: Close the documentation and migration contract

**Files:**
- Modify: `docs/DESIGN.md`
- Modify: `docs/ROADMAP.md`
- Modify: `HANDOFF.md`

- [x] Document region packages, territory keys, control rollups, save migration and the NPC route/tactical rules.
- [x] Record that additional authored playable regions can supply their own territory arrays.
- [x] Record outstanding verification and balance work clearly; do not report tests as run.

## Execution note

Implement with small edits and inspect every diff. Do not run tests in this session unless the user explicitly requests verification. Before any later PR or integration, request authorization, then run the project's required focused and full verification in an available memory-safe window.

