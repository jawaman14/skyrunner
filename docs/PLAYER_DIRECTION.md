# Player-approved game direction

Recorded 8 October 2026 from the owner's answers to the gameplay questionnaire. This is a design target, not a claim that these features are implemented. It refines [EMPIRE_MILESTONE.md](EMPIRE_MILESTONE.md) and takes precedence over conflicting earlier recommendations. Outstanding scope questions remain below.

## Core experience

Build an empire from nothing. Warband is the principal reference: progressively take on greater complexity, combining personal action, recruitment, trade, relationships, conquest, command and emergent stories. Schedule I contributes hands-on work, business setup and automation. Cities: Skylines contributes interconnected systems and diagnosing/managing them; decorative city design is not a gameplay priority.

Avoid forcing the player into only one activity. A solo player can delegate to AI; co-op participants can specialise in the aspect they enjoy and contribute to the organisation. A mature organisation can eventually operate across all business areas. No fixed percentage of flying, management or combat is prescribed. Start employed by someone else, earning enough to buy the first aircraft; ownership is an earned milestone rather than a starting gift.

## Economy and workers

- Use an interconnected economy. Civilian businesses provide jobs and supplies, residents create demand, disruption reduces trade, and neighbourhood prosperity changes opportunities. Exact calculations remain to be designed.
- Manual operation remains available. Automation becomes achievable through sufficient workers/resources and player setup.
- Eventually support both repeatable conditional orders (for example stock thresholds) and configured multi-step task sequences. Deliver basic explicit assignments before advanced automation.
- Workers follow explicit instructions. Delegation is configured by the player; competence does not mean autonomous strategic spending or expansion.
- Poor planning is the preferred basis for delegation failure. Do not silently treat other suggested failure causes as equally approved.
- Money chiefly unlocks convenience. Organisation properties visibly develop as the business expands.

## Turf, factions and access

Territory supports income, safer routes, recruiting, services, influence and physical occupation. Control can change through a combination of presence, negotiation, economic disruption, battles and important sites; exact rules are undecided.

Turf war emerges mainly later, or earlier if the player deliberately pursues it. Rival organisations have recognisable leaders and goals and grow alongside the player. Rivals earn expansion through the economy, with different starting strengths. Do not use automatic player-level matching or unearned catch-up resources as the default.

Diplomacy changes as expansion threatens and displaces other factions. Combat can be led personally, nearby or remotely. Valuable experienced crew should make retreat a meaningful decision.

Police response escalates. Pressure can be addressed through laying low, routes, legitimate business, legal measures or sacrificing operations. Travel remains relevant; upgrades, bribery and relationships with factions such as the CIA and Mob can improve access/security. Specific faction services and costs require definition.

## Loss and recovery

The player survives death through respawn or hospital recovery; it does not end the game. Recovery can cost a situation-dependent combination of time, money, carried goods and equipment. The organisation continues only the last instructions the player gave; recovery does not grant AI permission to invent new assignments. Workers may be injured or permanently killed. After defeat, rebuild with surviving crew.

Aircraft/vehicles may be lost, impounded, or destroyed in severe cases. Provide several impound recovery approaches, potentially fees, legal/faction assistance and physical retrieval; precise eligibility, costs and legal consequences require design. Bankruptcy/imprisonment terminal consequences should be configurable. Property seizure and permanent loss of major story contacts were not separately answered.

Some risk is discovered through experience and reports. Preserve intelligence boundaries and distinguish facts from uncertainty.

## World and campaign

Compact Costa Brava. Build interiors when they serve gameplay. Stylised period cinema is the visual target; update the earlier weathered-period direction within that style. Functional structures and traffic take priority over ornamental city-building.

Campaign participation is up to the player. Completing the campaign leaves the sandbox running. Preserve existing four tutorial and twelve story chapters. Business access unlocks through money, reputation and demonstrated activity; campaign missions provide an alternative route to the same unlocks. Avoid campaign-only gates for essential sandbox systems.

## Multiplayer

Both cooperative and competitive play are part of the intended initial experience. Players can play organisation, rival-faction or police roles. One person owns an organisation and assigns responsibility. Offer separate cooperative and competitive modes for 2–16 players. In multiplayer, a leader leaving halts the session; a lower-rank player leaving does not halt it. Do not automatically hand an absent leader’s authority to AI or a deputy. Resume/reconnection rules, what qualifies as a leader and empty-seat handling remain to be specified.

This supersedes any earlier recommendation to defer all competitive play. It does not by itself approve every competitive mode: multiplayer racing and hidden-informant mechanics remain separate proposals. Existing authority, permissions, handoff, acknowledgements and two-machine evidence gates still apply.

## Delivery implications

Owner-selected product order:

1. **Early rise from nothing:** work for an employer, understand jobs and their consequences, earn and buy the first aircraft. Establish independent progression and campaign-equivalent unlocks.
2. **Setup-driven automation:** basic explicit assignments, then repeatable conditional orders and multi-step task sequences; retain manual operation and existing instructions during recovery.
3. **Faction competition:** distinct starting strengths, earned economic growth, civilian economic effects, expansion-driven diplomacy and late-game or deliberately pursued turf war.
4. **Multiplayer teamwork:** separate co-op/competitive modes, organisation/rival/police roles, 2–16 players, leader-disconnect session halt and non-leader continuity.

Physical reliability, command clarity and current regression gates are prerequisites within these slices. Define ownership and network contracts early to avoid rework, without moving multiplayer feature delivery ahead of the owner-selected sequence. This order supersedes the previous unspecified priority list.

Do not silently change current payroll, aircraft performance, combat authority or balance to satisfy these goals. Proposed mechanical changes need explicit rules, compatibility and validation evidence. Automated tests cannot establish enjoyment.

## Questions still open

- Employer identity, first assignments, starting transport and pay/first-aircraft price.
- Situation-specific recovery costs, recovery time, inventory handling and property seizure.
- Impound approach eligibility and consequences.
- Automation budgets, conditional-rule syntax, task sequencing and permission limits.
- What counts as a leader in each mode, whether any leader departure halts the entire session, and reconnect/resume/abandonment handling. Until clarified, retain the literal session-halt rule rather than silently substituting a faction-only pause.
- Exact civilian supply/demand and district-control calculations.
- Unanswered preferences: tone, personal skills, favourite locations and non-pilot flight tasks.
