# BLACKFILE — MKULTRA and Declassified Operations Expansion
**Research revision:** 22 October 2026. Separate game proposal; no engine or story integration in this PR. Detailed offline research pack available in the corresponding ChatGPT handoff.

## Scope and historical limit
Historical, playable CIA archive anthology expanding BLACKFILE's 1979–89 station/field campaign with 1950s–70s investigations and later post-1989 dossiers. Documents must carry stable publisher/URL, dated original event, document date, release date (if known), and tags D=established, A=allegation, P=proposal, C=contested, U=unknown, F=fictional. **An archived claim does not automatically mean it happened**. The full corpus is millions of pages and many original records were destroyed; this is curated research, **not** an exhaustive review of all released files.

## MKULTRA primary findings (Senate, 3 August 1977)
- CIA director Stansfield Turner described MKULTRA's umbrella programme as 1953–64. Predecessors BLUEBIRD / ARTICHOKE and follow-on MKSEARCH require separate dating.
- Surviving record groups: **149** MKULTRA subprojects, two boxes miscellaneous financial/administrative papers, and **33 additional** different-purpose subprojects. Don't describe all as unwitting human tests.
- **Seven boxes** of financial records recovered in 1977 survived destruction of major programme records in 1973; expense vouchers alone rarely prove experiments' substance or outcomes.
- Hearing references **185 researchers/assistants** and **80 institutions** with both witting and unwitting involvement.
- Hearing's broad 15 research categories distinguish: drug/alcohol studies (17 probably no human tests; 14 confirmed volunteer tests; 19 probably volunteer; six documented unwitting-subject subprojects), hypnosis, acquisitions, magicians' arts, sleep/psychotherapy, conferences, motivation/assessment, polygraph, external finance, drugs/biologicals, unknown projects, Fort Detrick/MKNAOMI-related spending, specialised studies, biological research, and three cancelled projects.
- Specific case modules: George Hunter White's safehouses, Frank Olson, Ewen Cameron/Allan Memorial Institute, Gorman Annex financing and research, records destruction/recovery, later MKSEARCH grants, and victim/oversight inquiries. Do not turn abusive experiments into procedural player minigames.
- Note: the CIA's 1963 inspector-general concerns and the 1975–77 inquiries establish abuses; claims of successful mind-control programming or unresolved individual death theories are **not** established by these records.

## Case mission plan
1. **Seven Boxes** — 1977 archive/FOIA inventory; source puzzle and oversight brief.
2. **The Ledger** — reconcile grant and voucher trails without presuming experiments occurred.
3. **Subjects** — informed consent, witness privacy, independent verification.
4. **Safehouse** — retrospective records and testimony investigation.
5. **Montreal** — medical institute financing, survivor accounts, accountability.
6. **Gorman Annex** — donation and proposed hospital use vs proven activity.
7. **Olson File** — qualified chronology, contested explanations not auto-resolved.
8. **The Missing Index** — document destruction and unknowns.
9. **MKSEARCH** — successors, financial gaps, non-equivalence assumptions.
10. **Public Hearing** — evidence integrity and privacy-protective release.

The MK-01 -> MK-02 -> MK-10 chain is the first evidence-only prototype. One fictional records office, 3+ legitimate endings, no fictional material misrepresented as a historical source.

## Broader CIA anthology research queue
- **Domestic/oversight**: CIA CHAOS/MHCHAOS (domestic surveillance), HTLINGUAL (mail opening), 1973 Family Jewels, Church Committee foreign-leader plot investigations.
- **Foreign covert operations**: Iran TPAJAX (1953); Guatemala PBSUCCESS (1954); Bay of Pigs and Mongoose (1961–63); Chile covert programmes and Track II (1970–73); Afghanistan/Pakistan covert aid in the 1980s; Iran-Contra (1980s).
- **Technical and extraction**: Berlin Tunnel, U-2, CORONA, A-12, Project AZORIAN (Glomar) and ARGO.
- **Future oversight**: 2001–09 CIA detention/interrogation documented by 2014 Senate study; archive investigation only.
- **Attribution filters**: FBI COINTELPRO is not CIA; Operation Northwoods was a JCS proposal, not executed CIA action; ambiguous 'Mockingbird' usage requires specific records; Operation Condor needs nation/agency-by-agency attribution; court claims and contested testimony retain explicit uncertainty.

## Core game systems
- Evidence graph with supports/contradicts/proposes/allegations/unknowns; real document links remain distinct from fictional mission events.
- Deterministic investigation commands, provenance-based decisions, civilian/oversight consequences, budgets and informed-actor visibility.
- Isolated BLACKFILE data first, then Godot UI. Later SkyRunner flight/radio/vehicles and the eventual common actor/org/ledger/clock interfaces can be reused when stable.
- Preservation of SkyRunner's empire pivot, save schema and multiplayer regression lanes.

## Source anchors
- Senate hearing (1977): https://www.intelligence.senate.gov/sites/default/files/hearings/95mkultra.pdf
- CIA MKSEARCH testimony: https://www.cia.gov/readingroom/document/cia-rdp99-00498r000300020007-3
- MKULTRA archival overview (2024): https://nsarchive.gwu.edu/briefing-book/dnsa-intelligence/2024-12-23/cia-behavior-control-experiments-focus-new-scholarly
- Archival uncertainties (2026): https://nsarchive.gwu.edu/briefing-book/intelligence/2026-06-29/mkultra-declassification-task-force-should-focus-real-secrets
- CIA oversight institutional history: https://www.cia.gov/resources/csi/static/The-Agency-and-Hill.pdf
- Church Committee index: https://www.intelligence.senate.gov/resources/intelligence-related-commissions/
- Guatemala: https://history.state.gov/historicaldocuments/frus1952-54Guat/d287
- Chile: https://history.state.gov/historicaldocuments/frus1969-76ve16/d38
- Bay of Pigs: https://history.state.gov/historicaldocuments/frus1961-63v10-12mSupp/summary-x
- AZORIAN: https://www.cia.gov/stories/story/the-exposing-of-project-azorian/
- Afghanistan finding: https://history.state.gov/historicaldocuments/frus1977-80v19/d450
- Senate detention study: https://www.intelligence.senate.gov/2014/12/09/press-committee-releases-study-cias-detention-and-interrogation-program/

**No production code changed or tested by this documentation-only update.**