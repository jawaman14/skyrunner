# Story chapters: can a fresh save reach each goal?

A source audit, 11 October 2026, of the twelve Story chapters (`Story.CHAPTERS` in `scripts/sim/story.gd`, printed from the running
table, not retyped). It answers one question: with only the mechanics unlocked up to and including a chapter, does the source make
each of its goals reachable? It is **not** a playthrough. Nobody has been seen completing these chapters; the last column says what
kind of evidence each row has. Done for Codex's queue (#329) while Codex was out of tokens.

Unlocks are cumulative. Chapters 9 to 11 unlock nothing: they are goals only (a "no unlock" row is normal, not an error).

| # | Year, title | Unlocks | Goals (target) | Needs beyond what is unlocked? | Evidence |
|---|---|---|---|---|---|
| 0 | 1979 Square Grouper | trade, payroll, chronicle | fly 300 lb of marijuana into the stashes; put a street dealer on a corner; earn $4,000 from the trade | no (dealers via the phone contact, payroll) | source only |
| 1 | 1980 The Connection | logistics, dealership | truck or fly $3,000 home; get the call from the connection; buy a vehicle | the call needs `trade.connected` (1,200 lb of grass sold, or 2,400 lb landed in the stashes, or $25,000 earned in the trade; `Trade._check_connection`): far above chapter 0's own goals, so the player must keep trading | source only |
| 2 | 1980 Blotter | psychedelics | trade 150 lb of grass for acid; sell 20 sheets | grass in stock from chapter 0 trade | source only |
| 3 | 1981 Cocaine Cowboys | ground_war, guns, role_soldier | fly 60 lb of cocaine home; stock 8 weapons; run a truck with cover or steel | cocaine is offered at shady strips only after `connected` (chapter 1); cover needs a dealership truck (chapter 1) | source only |
| 4 | 1982 Family Business | family | do business with the Morettis; have $30,000 | none; waived if the family is convicted first | source only |
| 5 | 1983 The Task Force | court | deliver 3 hot loads; keep the case under 60% | hot loads are contraband jobs (enabled by default) | source only |
| 6 | 1984 Isla Soberana | island, role_mule | bring a load home from the island | an aircraft that reaches the island strip | source only |
| 7 | 1984 The House | casino | buy the Hotel Cielo stake; launder $15,000; win $2,000; get out when the government falls | the exit is event-driven; if the house falls and the player misses it the goal is waived ("evacuation was missed") | source only |
| 8 | 1985 The Company | agency | fly a job for the Company; sell it 4 guns | guns from chapter 3; waived if the agency is no longer active | source only |
| 9 | 1986 Kingpin | none | be worth $65,000 | none | source only |
| 10 | 1987 The Hearings | none | keep the case under 50% for half an hour; have $40,000 | none | source only |
| 11 | 1988 Last Flight | none | be worth $90,000; stay clear of the law for 20 minutes | none | source only |

## What the source does guarantee

- Every goal's mechanic is unlocked by its own chapter or an earlier one. No goal asks for a mechanic from a later chapter.
- Goals that the world can make impossible are waived, not left to soft-lock: the Morettis convicted (`family_deal`), the house falling
  with the evacuation missed (`casino_out`), the agency ending (`agency_jobs`, `guns_to_company`) all call `_waive` in `Story.tick`.

## What it does not show, and findings

1. **No goal asks for flying skill** (a landing, an approach, a short strip). The early chapters are flown into bush strips, but
   success is measured in pounds delivered and cash, never in how the aircraft arrived. Whether flight skill belongs in the goals is
   an open product question, listed in #326, not a defect.
2. **The cargo goals meet the strip measurements** (`docs/STRIPS.md`, `STRIPS_PAYLOAD.json`, PR #323). Chapter 0 needs 300 lb of grass
   and the generator offers 176 to 512 lb loads at bush strips; the Cessna 172 lifts 609 lb from FRM end 0, 438 lb from PNR end 0, but
   **19 lb from EGL** at either end. Chapter 3's 60 lb of cocaine is within the 76 lb the C172 lifts from QRY end 0, but loads of up to
   175 lb are offered there. Only HAR, FRM, EGL, PNR and QRY were measured; the other shady strips have not been.
3. **Pacing between chapters 0 and 1 is unmeasured.** The connection's thresholds are several times chapter 0's goals, so the player has
   to trade well past the chapter's own goals. A human pacing walkthrough would show whether that feels like a wall.
4. **No automated play of the story exists to confirm any row.** `scripts/balance/` measures economy and tactics, not chapter
   completion. A bot that plays Story and reports the chapter it reaches would turn this table's "source only" into evidence; that is
   open work (#328).

Nothing here changes the game, ticks a gate or closes a decision.
