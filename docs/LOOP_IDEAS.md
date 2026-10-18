# The product and money loop: what could make it more dynamic and fun

Written 18 October 2026 at the owner's request, from a read of `market.gd`, `trade.gd`, `logistics.gd`, `jobs.gd`, `chronicle.gd`,
`family.gd` and the design sections 18, 19 and 22. **These are proposals for the owner to choose from; nothing here is decided or
built.** The loop as it stands is on sheet 5 of the System Map: take a job, load, fly, land, the stash, trucks, dealers, cash home,
money, repeat.

## 1. Where the loop is flat today

1. **After the landing, the loop runs itself.** The AI boss collects cash after 20 minutes, sends the trucks, and the dealers
   sell (`logistics.gd`). Between flights the player rarely decides anything about money.
2. **Prices move, but the player cannot see them.** `market.gd` keeps supply and demand for each good in each market (the street
   price follows demand over supply, clamped to x0.55 to x1.9). No screen shows them; the player sees only a job's payout. So there
   is nothing to time and nothing to exploit.
3. **Risk is a roll, not a choice.** A delivery adds heat, and #402 now shows the case building. But the player never chooses how
   loud a run is (a fast hot route against a slow safe one, a cover load against a bare one).
4. **Buyers have appetite, not wants.** A buyer takes what he can until his appetite (it refills over 30 minutes) runs out. He
   never asks for anything by a time, so there is no "I need this by midnight".
5. **Events are random, not planned for.** The chronicle fires about one event every 480 seconds on a Poisson clock. A player can
   only react; nothing can be prepared for.
6. **Weight and balance is a puzzle that stands apart.** It is the game's best mechanic, and it does not touch risk or money.
7. **Money has little pressure and no comeback.** Payroll every 10 minutes and the Family's offers (one every 10 minutes) are the
   only strings. A bad hour has no valve (#165 failure fairness is the matching item).

## 2. Eight additions, in the order I would build them

Each says what the player does, what already exists to build on, and what it touches. Effort: S days, M one to two weeks.

| # | Addition | What the player does | Builds on | Effort |
|---|---|---|---|---|
| 1 | **The market board and the buyers' orders** | Reads prices by district with trend arrows, sees which buyers want what. A buyer rings (a phone call): "200 lb to the Morettis by 21:00, they pay +25%, miss it and your trust falls". Takes it, or does not | `market.gd` (data exists), `trade.gd` buyers, the phone hub (#401), `Jobs.deadline_s` (already on a few jobs), D-11 trust | M |
| 2 | **Cover cargo** | Packs a legitimate load beside the hot one: it lowers suspicion at a checkpoint or a radar check, and costs payload and balance. A true use of the load planner | `Airframe`, the load planner, `Investigation` heat (#402), the Island false-bottom factors | M |
| 3 | **Dirty money has a clock** | Street cash carries heat that grows while it sits (a "following the money" case, which the law already has as an action). Fronts and the Hotel Cielo launder it at a fee and a limit; unlaundered cash buys less and is a liability in a raid | `casino.gd` laundering, `logistics.gd` cash, heat steps 2 and 3 (D-27) | M |
| 4 | **A calendar the player can read** | The radio and the phone announce the week: a holiday weekend (demand up), the harvest (grass cheap), a police operation starting Thursday, a hurricane window. Plan around it | `chronicle.gd` (events exist, random), `market.gd` news table, radio (F7), weather | S to M |
| 5 | **The deal moves, mid-flight** | A call in the air: "they moved the drop, 8 km south, pay doubles but the cutter is out there". Take the new point or the old one | `Maritime` drop points, the radio, `AutoRunner` announcements (#391) | S |
| 6 | **Price wars and supply cuts** | Los Cuervos undercut a district, or the Company floods it; the player answers by cutting prices, raiding a depot (D-19) or holding stock for a better week | `Market` disruption and source, the depot raid design, turf (#378, #404) | M |
| 7 | **Investments with a return** | Spends on a hidden strip, a fuel depot, a safehouse, an informant: each has an upkeep and a visible payoff (a shorter run, less heat, a warning). Mount & Blade's village improvements, for the empire | Stash works (design §28), rackets, payroll | M |
| 8 | **Comeback valves** | A loan shark's offer with a rate and a collector, a windfall job when broke, a lawyer's discount after a loss: pressure with a way back, not a death spiral | The Family's offers, #165, the case-file ladder | S |

**What 1 to 3 do together.** The player reads the market (1), packs a cover load against the heat (2), flies it, and has cash that
must be cleaned before the case catches up (3). That is a decision before the flight, one during it and one after, which the loop
does not have today.

## 3. What it costs, and what to watch

- **Determinism.** Every new random draw gets its own seeded stream, and every new system sits behind a switch in
  `scripts/sim/switches.gd` that the parity tests turn off (CLAUDE.md). Orders, calendar events and price wars each need one.
- **Balance.** Each addition changes income and risk, so each needs a `cli.gd -- report` run (200 or more seeds) and a BALANCE
  entry. Addition 1 changes how much a delivery is worth, so it goes first and alone.
- **The owner's earlier decisions this must fit.** Heat steps 2 and 3 come in that order (D-27), so addition 3 waits for them;
  the depot raid (D-19) is addition 6's centre; trust per crew (D-11) is addition 1's penalty; flight-skill bonus goals (D-38) are
  optional goals and could ride on orders.
- **Lanes (D-52).** Claude takes the simulation of 1, 2, 3, 5, 6 and 8; Codex takes the screens (the market board, the order call,
  the calendar on the phone and radio, the investments menu) and the QA runs. Addition 4 is half and half.

## 4. The owner's answers (18 October)

1. **How much by hand?** After the takeover (D-35) the player organises as the boss, and delivering is optional: a crew pilot, or
   the player. Flying cargo becomes part of the logistics system, not the focus. Before the takeover the player flies the cargo and
   learns the mechanics chapter by chapter (D-58).
2. **Deadlines.** They follow demand: a night's work, or 10 to 20 minutes when the street is hungry (D-59).
3. **Which first?** "Begin however you see fit" (D-60): the market board and buyers' orders went first (design section 49).

Added the same day (D-61): ammunition as a cargo, and weapons as crates of each type with the powerful ones scarce (design section 50).

### The questions as asked

1. **How much should the player run by hand?** Today the AI boss collects and trucks by default. Should the orders and the market
   board make the player choose (more work, more depth), with the AI boss as a switch, or stay an extra for those who want it?
2. **How tight should deadlines be?** A buyer's order in game minutes (a 10 to 20 minute window) or in game hours (a night's work)?
3. **Which first?** My order is 1, then 2, then 4, with 3 after heat step 2. Say so if you want a different first slice.
