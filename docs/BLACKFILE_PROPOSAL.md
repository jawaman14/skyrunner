# BLACKFILE — intelligence-game proposal (concept only)

**Date:** 22 October 2026  
**Scope:** Separate historical intelligence-operations game based on reusable SkyRunner engine systems, **not** a change to the current empire-pivot plan. This branch contains research and design groundwork only; it does **not** claim a playable implementation or a passing Godot test.

## Pitch
A 1979–1989 Cold War intelligence simulator: analyse contradictory released records, brief a fictional station, investigate in explorable districts, drive or fly field missions, manage an organisation with constrained budgets, and watch rival institutions react to partial information. A post-1989 alternate-history sandbox continues indefinitely; 1950s–1970s are playable later as clearly labelled historical archives/flashbacks.

**Two equally weighted experiences:** on-foot/car/aircraft field play and strategic station management. Intelligence case files are the content engine. A document being declassified proves its existence, **not** the accuracy of every claim in it. Every mission must distinguish documented facts, disputed interpretation and dramatic fiction.

## Existing systems to reuse
- Pure GDScript/Godot 4.7.2, existing flight/vehicle/walking, radar, radio and fictional Costa Brava/San Telmo.
- `Session.command`, `Roles.allowed`, `CommandDomains` as the future integration gate; new case commands eventually require **actor, organisation and authority**, never direct simulation mutation from UI.
- `Agency`, `Investigation`, `Chronicle`, player/rival/task-force positions and the headless dedicated-server design as inspiration.
- Empire pivot's planned common clock, bounded accounts, deterministic RNG streams, event logs and equal rival rules, **after** their contracts stabilise.

**Do not alter now:** `project.godot`, active scenes, role permissions, existing saves, simulated money balances, multiplayer paths or SkyRunner narrative. The 19 October pivot documents already identify risks from faction hard-coding, unattributed cash and save-version handling.

## Initial vertical slice — The Second Cable
**Backdrop:** July 1979, fictional San Telmo. Inspired by a real U.S. policy meeting regarding Nicaragua. **All characters, cables and actions in this mission are invented.**

Loop: receive two contradictory cables -> verify disputed evidence -> optional drive/walk investigation -> obtain legal/oversight review -> recommend correction, confidential brief or stand-down -> see rival/press reaction and persistent results. Completion: one meaningful 20–30 minute play loop with three outcomes, replayable same-seed results, functional save/restore, historical source citation and no false implication that the invented incident occurred.

**Minimal world:** one living district, embassy/office interior, newspaper office, municipal records desk, airport exterior, rival institution with bounded resources. This should build on the stable SkyRunner district, not initiate a premature multi-city rebuild.

## Core mechanics
1. Evidence graph: each claim has source ID, date, support/contradiction, confidence, redactions, document link and factual/fictional status.
2. Source triangulation and brief-making: lack of corroboration may warrant a refusal; wrong confidently asserted information carries consequences.
3. Character field missions: on foot, in vehicles, optionally a flight; **direct and delegated actions must produce the same ledger effects**.
4. Station simulation: people, hierarchy, schedules, accountable orders, finance, institutional pressure, civilian impact.
5. Abstract information environment: public credibility, corrective communication, rival narrative pressure and unintended consequences. **Not operational instructions or current-population persuasion tools.**
6. Historical archive mode: authentic documentary outcome kept separate from alternate-history saves.

## Candidate anthology (provenance first)
- **1979–1980 Central America:** FRUS Nicaragua SCC meeting, July 17 1979; April 3 1980 NSC memo (first playable arc).
- **1980 National Deception Operations:** a released February 28 1980 official memorandum (document/authority puzzle).
- **1984–1986 Iran-Contra:** declassified meeting records and 1986 exposure (budgets, approval and document-puzzle campaign).
- **1953 Iran / 1954 Guatemala:** archival reconstructions with carefully labelled fictional scenes.
- **1970s oversight:** Church Committee and the CIA's Family Jewels (retrospective casework).

## Archival sourcing
The CIA said in 2017 that CREST comprised more than 12 million pages; **'all released files' is not a tractable initial game-content set**. Start with curated and attributable cases, later add metadata ingestion and human fact-checking. Never invent missing text behind redactions, conflate FBI COINTELPRO with CIA actions or treat clipped allegations as proven.

- CIA CREST: https://www.cia.gov/readingroom/collection/crest-25-year-program-archive
- NARA RG 263: https://www.archives.gov/research/intelligence/cia
- FRUS July 1979 Nicaragua: https://history.state.gov/historicaldocuments/frus1977-80v15/d286
- FRUS April 1980 Central America: https://history.state.gov/historicaldocuments/frus1977-80v15/d489
- 1980 CIA National Deception memo, CIA-RDP84B00049R001403610012-9: https://www.cia.gov/readingroom/document/cia-rdp84b00049r001403610012-9
- Iran-Contra documents: https://nsarchive.gwu.edu/briefing-book/iran/2016-11-25/iran-contra-affair-30-years-later-milestone-post-truth-politics
- FRUS Iran: https://history.state.gov/historicaldocuments/frus1951-54Iran
- Church Committee: https://www.intelligence.senate.gov/resources/intelligence-related-commissions/

## Recommended PR gates
- G0: source metadata + case data + isolated deterministic Godot simulation and smoke tests; engine changes zero.
- G1: dossier/claim UI and 3-way case resolution.
- G2: first real explorable field task and optional delegated alternative.
- G3: shared economy/clock, bounded institutional competition, save migration and regression tests.
- G4: historical review, full story arc, cities only after one living district succeeds.

**Proposed agent split:** Claude — story, historical corpus and UX; Codex — rules engine, tests, safe adapters, migration and CI. Follow SkyRunner's existing review and merge policy.

**Definition of done for this document:** proposal exists on a separate review branch; no production source, roadmap or owner-decision files changed.