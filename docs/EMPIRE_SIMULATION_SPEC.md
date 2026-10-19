# Empire simulation spec (Living District, P0)

Draft for review, 19 October 2026, against `main` @ 34fd7f2. The decisions it rests on are D-62 to D-77 in [DECISIONS.md](DECISIONS.md); the plan and PR order are in [EMPIRE_PIVOT.md](EMPIRE_PIVOT.md).

This is the contract for the first milestone: one district where the player's organisation and two rivals run businesses on the
same rules. It covers what P0 needs and reserves interfaces for what comes later (more cities, detail levels, co-op). It doesn't
design those later parts. Facts about the current code are marked **[repo]** and were checked by reading the source. Nothing was
run.

## 0. Summary

- **One clock.** Settlement happens on scheduled ticks; the HQ "nights" become a nightly report. (Decided 19 Oct.)
- **One ledger.** Every dollar and every pound of product moves between accounts by an explicit transfer, for every
  organisation. The world outside the map is an explicit account.
- **One command gate.** It's extended from "which role" to "which actor in which organisation".
- **Same rules for every organisation.** Rivals get no money from nowhere.
- **Python parity fixtures retire one subsystem at a time** as each moves to the new model. (Decided 19 Oct.)
- **Multiplayer keeps working.** Every PR keeps the sockets lane green; no new multiplayer features. (Decided 19 Oct.)

The migration is wrap first, then move. The first PR of each foundation changes no behaviour, so the parity and golden tests
prove it. Later PRs move call sites one domain at a time.

## 1. What exists to build on [repo]

| Need | What's there | Gap |
|---|---|---|
| Command gate | `Session.command(role, name, args)`: every non-flight action, from local menus, network clients and AI crews, passes `Roles.allowed` (`session_commands.gd`, `roles.gd`) | It knows the *role*, not the organisation or the person. There's one organisation per side. |
| Clock | `Session.time`, advanced in `session_tick.gd` | No sim-side time acceleration (`world_scene.time_scale` only moves the sky). The pilot app steps the sim per frame; D-12 (a fixed 30 Hz step) is planned, not built. |
| Strategic layer | `HQ.Season` and `NightDirector`: planning, operation and wrap-up per night. Actions: launder, buy_front, bribe, lawyer, opsec... | A night's operation starts when the pilot takes off with something hot (`nights.gd`), so it's tied to the pilot. The balance sims (`scripts/balance/strategic.gd`) are built on nights. |
| Money | `Session.money` (the player's), `ground.commanders.rival.cash` (Los Cuervos'), stash cash in logistics | **88 assignments to `money` in 28 files**, plus **43 `+=`/`-=` on stash cash and stock**. No ledger. |
| Rival economy | Los Cuervos have one cash float, start on $20k, and pay for squads | **Injected from nowhere:** `chronicle.gd` (+8k, +6k), `agency.gd` (+4k), `family.gd` (+2k), and `ground.gd` pays them half a truck's value. That breaks "same rules" (D-62). |
| Factions | `"org"`, `"rival"` and `"police"` as string keys | `"org"` appears **236 times in 31 sim files**, `"rival"` 132 in 23. `ground.gd` hard-codes `CAP`, `HOSTILE` and `DOCTRINE` per key. |
| Businesses | HQ `fronts` (laundromat), the casino, the dealership | No business entity: nothing with its own books, staff and stock. |
| Districts | 18 entries in `map_city.gd`, each with id, name, market zone, bounds, neighbours and tags. San Telmo Centro is `city, commercial`. | No ownership, businesses or per-district state. |
| Workers | `Payroll`: outfit, role, skill, loyalty, wage, status, assignment | No schedules or budgets; one assignment string per worker. |
| Saves | `StrategicSave`, `VERSION := 1` | **On a version mismatch, `restore()` returns without loading the sim block**, so a version bump silently drops old saves' state. That needs a migration chain before anything else touches saves. |
| Determinism | Every system has its own RNG stream (seed + offset). New rules sit behind switches registered in `switches.gd`. | Fine as is; new systems follow it. |

### What the parity lane actually covers [repo]

The parity tests are `test_core_parity`, `test_session_parity`, `test_strategic` (`strategic_ref.json`), `test_bots_parity`,
`test_trials_parity` and `test_police`.

`Switches.PARITY` turns off `GroundWar`, `Chronicle`, `Agency`, `Economy.REALISM`, `Fuel`, `Orders` and `Investigation` in
those runs. So **Los Cuervos' cash and every injection above is already outside parity** and can change without retiring a
fixture. The fixtures that the pivot will actually retire are:
- `strategic_ref.json`, when nights stop being the strategic model (F-6);
- the money and jobs parts of `session_ref.json` and `core_ref.json`, if and when the shared delivery and pay rules change (L-2).

The ledger wrap (F-2) changes no values and keeps all of them green.

## 2. Entities and IDs

Every entity has a stable string id, unique in the save, from a per-kind serial (the pattern `Payroll._serial` already uses).
No ids come from RNG.

| Entity | Key fields | Notes |
|---|---|---|
| `Org` | `id`, `name`, `kind` (`player`, `rival`, `law`), `leader` (person id), `relations{org_id: float}` | `"org"`, `"rival"` and `"police"` stay as the first three ids, so old code keeps working. New code takes an org id as data. |
| `Account` | `id` = `org:place`, e.g. `org:safe`, `rival:safe`, `org:stash-docks`, `biz-12:till`, `outside:growers` | Money only. A balance is derived from transfers and cached. |
| `Business` | `id`, `kind`, `district`, `site` (x, y), `owner` (org id), `staff[]`, `till` (account), `stock` (inventory location), `costs{rent, utilities}`, `price_policy`, `open_hours` | P0 kinds below. |
| `Site` | `id`, `district`, `kind` (`stash`, `shop`, `warehouse`, `strip`), `owner` | Wraps today's stash and airfield records. |
| `Lot` | `id`, `good`, `lb`, `origin`, `quality`, `heat` | Product moves as lots, and a lot can split. |
| `Person` | `id`, `org`, `role`, `skill`, `loyalty`, `wage`, `boss` (person id), `schedule`, `assignment` | Extends Payroll's worker. `boss` gives the hierarchy. |
| `Order` | `id`, `org`, `issuer` (person or actor), `assignee`, `kind`, `args`, `condition`, `status`, `blocked_reason` | Explicit and conditional orders. Workers only run orders; they never make one up (§0). |
| `District` | `id` (from `map_city.gd`), `control{org_id: float}`, `demand{good: float}`, `prosperity` | It wraps the existing table; it doesn't replace it. |

## 3. The ledger (money)

**Shape.** Every transfer is `{id, t, from, to, amount, reason, actor, ref}`, with `amount > 0` and `from != to`. That's
double-entry by construction (one debit, one credit) without a chart of accounts. Balances are cached per account and rebuilt
from the log in tests.

**The outside.** Money enters or leaves the map only through `outside:*` accounts: `outside:growers`, `outside:buyers`,
`outside:company`, `outside:family`, `outside:state` (fines, seizures, taxes) and `outside:market` (legit wholesale). These are
the only accounts allowed to go negative. A report shows the net flow across this boundary, so injections can be seen.

**Invariants** (checked in tests and, in debug builds, after every tick):
1. Conservation: the sum of all balances, `outside:*` included, is zero.
2. No account except `outside:*` goes below zero. A command that would overdraw fails with a reason instead.
3. Every transfer has a reason from a closed list, plus an actor (who caused it).
4. Rebuilding balances from the log equals the cache.

**Migration** (wrap, then move):
- **F-2 (no behaviour change).** `Ledger` exists. `Session.money` becomes a property whose setter records an `adjust`
  transfer against `outside:unattributed` for the difference. Rival cash gets the same treatment. Every value stays bit-identical,
  so parity stays green. We now get a log of every unattributed adjustment, which is the to-do list for F-3.
- **F-3 (one domain per PR).** Replace the adjustments with named transfers: `cmds_air`, `cmds_crew`, `cmds_ground`,
  `cmds_trade`, `cmds_court`, `cmds_org`, then `logistics`, `payroll`, `chronicle`, `family`, `agency` and `casino`. The PR that
  removes `outside:unattributed` adds a test that it's never written.
- **Rival injections.** Each one either becomes a named outside source with a reason (the Company really pays Los Cuervos, say)
  or is removed. Removing any changes balance, so each needs a `cli.gd -- report` entry. None touches parity (§1).

## 4. Inventory

The same pattern for goods: `move(lot_or_lb, good, from_location, to_location, reason, actor)`, with locations such as
`org:stash-docks`, `truck-7`, `aircraft:N123`, `biz-12:stock` and `outside:growers`.

Invariants:
- no negative stock;
- conservation per good, except through `outside:*`, seizures (`outside:state`) and consumption (`outside:street`);
- a lot is in exactly one location.

Migration is the same as money: F-4 wraps stash stock, then call sites move by domain. The aircraft load (`Loadout`) becomes a
location, so a flown delivery and a trucked one are the same `move`. That's what makes direct and delegated deliveries equal (D-63).

## 5. The clock

One authoritative `Session.time` (decided 19 Oct). Three things hang off it:

- **Continuous rules**, every tick, as now: flight, squads, trucks and police.
- **The scheduler.** `Schedule.at(t, kind, payload)`, a min-heap ordered by `(t, serial)` so ties resolve the same way every
  time. It runs:
  - **The books**, once per game day at 06:00: wages, rent, utilities and debt service per org. A business that can't pay
    goes into arrears with a blocked reason; it doesn't stop silently.
  - **Production and restock**, per business on its own period.
  - **Org AI decisions**, per org on its own period (§7).
- **Nights retire as a model, but stay as a report.**
  - `NightDirector` moves behind a switch, `Nights.ENABLED`, in `OPT_IN`.
  - A "night" becomes the window between two books ticks.
  - The nightly debrief (dirty money, seizures, evidence, heat) is generated from the ledger and the event log for that window.
  - HQ actions (launder, buy_front, bribe, lawyer, opsec) become ordinary commands that run any time and cost through the ledger.
  - The strategic balance sim stays on the old path until a new headless "N days" sim replaces it. `strategic_ref` parity
    retires in the same PR.

**Time acceleration** (new; needs D-12's fixed step first):
- The desk can run ×1, ×4, ×16 or ×60 by stepping the sim N fixed steps per frame.
- It's capped at ×1 while the local player is flying or on foot in a hostile area. The flight model must never take a
  variable step.
- In multiplayer, only the host or leader can accelerate, and only when every human seat is parked.
- The cap rule lives in one function, so it's tested once.

**Historical time.** 1979–1989 is campaign time, measured on the same clock. Chapter years stay labels on chapters, not a
calendar the sim depends on. The calendar needed for 1989 and the sandbox is reserved, not designed here.

## 6. Commands, actors and events

**Actor.** `{org, role, person}`. The existing `command(role, name, args)` stays as a shim that fills `org` from the role's
side (`Roles` already knows it) and `person` from the seat. New code calls `command_as(actor, name, args)`. Permission order:
1. `Roles.allowed(role, name)`, as now;
2. the org owns the target (business, site, worker);
3. the person's authority. In P0 that means the boss can do everything and a manager only what their budget and orders allow.

**Results.** These are unchanged: `[ok, message]`, and the preview gate still applies. A refused command always gives a reason
the UI can show (D-66).

**Events.** Every event on the bus gains `org` and `actor`. `job_delivered` gains `by` (person id) and `mode` (`flown`,
`trucked`, `boat`, `mule`). Story goals count by org, not by who flew. This fixes the gap in EMPIRE_PIVOT: today's payload has
good, pounds, hot and origin but no "who flew".

**Multiplayer.** No change to protocol v3 in P0. Commands already cross the wire by role; `command_as` maps onto that with
`person` set by the seat. The sockets CI lane must stay green on every PR (decided 19 Oct).

## 7. Organisation AI (rivals and your own staff)

There are three layers, and the same code runs for every org. Players use the top layer by hand. Rivals and delegated managers
run it on a policy.

| Layer | Decides | Runs on | P0 version |
|---|---|---|---|
| Strategy | Expand, defend or consolidate; the target district; budget split | Org AI tick (daily) | A scored choice between 3 to 5 moves (buy a business, open a corner, raise prices, hire, attack a site), with a seeded tie-break on the org's own stream |
| Policy | Prices, restock thresholds, hiring when understaffed, laundering limits | Business tick | Fixed rules with parameters per org personality |
| Execution | Run the orders: drive, carry, sell, guard | Continuous | Existing bots, trucks, dealers and squads |

Rules:
- **Equal rules.** The AI may only act through `command_as`. It can't write balances or stock, and it has no privileged
  information: it sees what a human in its seat would see (D-36).
- **Equal rules, unequal brains.** Rivals may plan more simply than a player. That's allowed (Codex §4.6).
- **Every refused or blocked order is logged with its reason,** and the desk shows it.
- **Trust, competence, loyalty and ambition** only enter where a test shows a consequence. P0 keeps Payroll's loyalty and skill
  as they are; D-11 trust comes in Phase 2.

RNG: one new stream per org for strategy (seed + 1201 + org index) and one for business policy (seed + 1301). Both get
registered in DESIGN's stream table.

## 8. Detail levels (reserved, not built)

P0 has one detailed district: San Telmo Centro, recommended in §10. Everything else runs exactly as today. The one hook P0 adds:
- every business and org exposes `tick_full(dt)` and `tick_aggregate(window)`;
- P0 calls `tick_full` everywhere, because there's only one district;
- a test checks that a single business run for 24 hours with `tick_full` ends within tolerance of `tick_aggregate(24h)`.

That keeps the door open for detail levels (D-65) without building materialisation or reconciliation before the district has
proved itself.

## 9. Saves

1. **F-1 first.** `StrategicSave` gets a migration chain: `MIGRATIONS = {1: _v1_to_v2, ...}`, applied in order. `restore()`
   never drops a block on a version mismatch. A test loads a frozen v1 save fixture and checks that every block survives.
2. The ledger, inventory, businesses, orgs and orders save under `sim.empire`. An older save gets them built from its state:
   - `money` becomes the opening balance of `org:safe`;
   - stash cash and stock become their accounts and locations;
   - the opening entries come from `outside:opening`.
3. The story's own `v: 6` migration (chapter reorder) stays separate and lands in Phase 3.

## 10. The Living District (P0 content)

**Where:** San Telmo Centro (`city, commercial`). Its neighbours, The Docks (Warehouse 7, the port) and Barrio Chino (the
lock-up, a stash corridor), are its supply edges. They're simulated as today, plus aggregate business ticks. This uses today's
map; the map redesign is paused (decided 19 Oct).

**Organisations** (proposed):

| Org | Who | Why |
|---|---|---|
| `org` | The player (Rafa's outfit, then the nephew's) | |
| `rival` | Los Cuervos | Already have squads, turf and cash |
| `moretti` | The Morettis' local businesses | The Family already has state (respect, greed, loans, the docks) in `family.gd`. Making them an org that owns the restaurant and the laundromat chain gives a third competitor on economic rules rather than violence. The owner may prefer a new legit competitor; see open question O-4. |

**Businesses** (proposed: 8 in the district, 2 in each neighbour):

| Business | Chain | Starting owner |
|---|---|---|
| Corner spots ×3 | Product: strip → stash → corner | 1 org, 1 rival, 1 free |
| Laundromat | Laundering front | moretti |
| Bar / the club | Front and product | org |
| Restaurant | Front (legit wholesale in) | moretti |
| Import-export warehouse (Docks) | Legit: `outside:market` → warehouse → retail | free |
| Bodega | Legit retail; it's where the import chain sells | rival |
| Car dealership | Exists (`dealership.gd`); joins the ledger | outside, unowned |

That's two supply chains: **product** (exists, re-plumbed onto the ledger and inventory) and **legit import to retail** (new,
small).

**Size:** 25–35 people across the three orgs.

**Acceptance.** Codex's nine tests, plus the invariants:

| # | Test | How it's checked |
|---|---|---|
| A1 | Player buys or starts a business and reads its books | Headless command plus a desk screenshot |
| A2 | Staff get budget, shift and orders | Order and schedule state after 1 day |
| A3 | A supply chain flows without duplication | Inventory invariants over 7 days |
| A4 | Rivals buy, sell, recruit and expand on the same rules | No transfer from a rival that isn't `command_as`; their outside boundary is reported |
| A5 | A flown and a delegated delivery give equal state changes | Same seed, two runs, diff the ledger and inventory |
| A6 | Wages, costs, revenue and losses settle over several cycles | 14 days, conservation holds |
| A7 | Negotiate, compete or fight, and the consequences persist | Relations and control saved and restored |
| A8 | Operations continue when the player leaves the district | Player parked out of district for 2 days; books still settle |
| A9 | Save and load reproduce everything | Round-trip equality of `sim.empire` |
| P1 | Performance scales | Headless days per second at 1×, 2× and 4× the district's entities, recorded in the PR |
| G1 | Gameplay gate | Owner playtest: it's interesting without story missions |

## 11. Open questions (not blocking P0)

- **O-1 City access.** Must every city become fully explorable, or can secondary ones stay strategic? Codex recommends fully
  playable priority cities and abstract secondary ones. It's needed before Phase 4, not P0.
- **O-2 Failure and succession.** Death, arrest and bankruptcy: does play end, or does control pass to someone else? The
  `Org.leader` field is the hook. Needed before Phase 3's takeover is final.
- **O-3 Endgame and the sandbox.** Rule, Retire and Fall are narrative outcomes, then the sandbox continues (Codex §2). This needs
  rules for whether a retired boss's org keeps running under a successor, which ties to O-2.
- **O-4 Third org.** The Morettis as a business org, or a new legit competitor?
- **O-5 Acceleration caps.** Are the ×1/×4/×16/×60 steps and the "flying means ×1" rule right?
