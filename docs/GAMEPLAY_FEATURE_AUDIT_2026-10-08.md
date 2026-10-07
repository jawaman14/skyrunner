# Jobs, gameplay and multiplayer audit — 8 October 2026

## Scope and evidence

Source audit of the integrated draft worktree at `529b4a8`, including faction AI PR #244 and battle finalization PR #245. This is ahead of merged main. It is not a fresh human walkthrough, controller test or two-machine acceptance session. Earlier main-only status entries are historical baselines.

Fresh targeted desktop runs used the canonical TestCase runner with restricted file lists: jobs/economy/progression 98 passed; mechanics 151 passed; multiplayer/interface 115 passed. Total **364 passed, zero failed**, with no script or parse errors. The same code previously passed the full 1,027-test suite and smoke. ObjectDB leaks, resources retained at shutdown and PagedAllocator cleanup diagnostics remain; passing assertions do not resolve those diagnostics.

## Jobs and their consequences

| Work | Implemented loop | Consequences and checks |
|---|---|---|
| Passenger charters | Carry passengers and luggage between airfields | Seat capacity; occasional VIP comfort requirement; excessive bank or hard landing reduces pay |
| Ordinary cargo | Mail, tools, fuel drums, generators, food, glass and lab samples | Weight, station limits and CG matter; glass/samples are fragile |
| Medical transport | Urgent fragile load to a bush destination | Deadline and touchdown quality; distinguish urgency from ordinary delivery |
| Contraband | Hot loads between permitted destinations | Unlock/permission checks, suspicion, detection, informants and police exposure |
| Fugitive transport | Move wanted passengers | Capacity and elevated suspicion; present legal exposure before acceptance |
| Airdrops | Drop bales for maritime collection | Payment depends on landed bales; boats, fuel and cutters connect air and sea systems |
| Fuel-cache deliveries | Ferry drums to remote strips | Existing feature gate and physical cargo; supports later operations |
| Purchased stock | Buy and fly own marijuana/cocaine loads | Up-front cash, source stock, destination sale and money outside HQ |
| Arms flights | Arsenal and agency-related consignments | Stock versus sale purpose, unlocks and political/legal risk |
| Offshore work | Paid flights, defectors and related island shipments | Customs, weather, interception and distinct political systems; offshore gameplay is separate from the retired classic map |

Acceptance rechecks location, parking, permissions, capacity and payment. Load placement can leave a dangerous aircraft; acceptance is not a guarantee of safe weight/CG. Late delivery pays 40%; fragile hard landings halve pay; VIP discomfort applies another reduction; very soft touchdown can add 10%. Hot-job pricing also follows the current economic multiplier. These effects can combine.

Dropping a job requires parking, removes its load and related boat, and gives no pay. Up-front payment is not refunded; the existing preview says so. Dropping at the origin returns the job to the board. Verify that repeat acceptance cost is understandable during human play rather than silently changing this policy.

Main source anchors: `jobs.gd`, `session_ops.gd`, `session_rules.gd`, `loadout.gd`, `trade.gd`, `arsenal.gd`, `island.gd`, `agency.gd` under `scripts/sim`.

## Gameplay feature inventory

| System | Current implementation | Remaining validation or polish |
|---|---|---|
| Flying | Fleet-specific dynamics, mass/CG, loading stations, fuel, weather, stalls, flaps, autopilot, repairs and condition | Human accessibility, aircraft handling and cockpit readability; preserve performance |
| Detection and pursuit | Radar tracks, uncertainty, terrain/weather/clutter, transponder, scanner, radio encryption, direction finding, police aircraft | Explain what is observed versus inferred; police aircraft use bounded kinematic pursuit |
| On-foot and vehicles | Walking, interaction occlusion, weapons, personal vehicles, boats, road surfaces and bridges | Walk/drive every functional entrance and crossing; verify collisions and loading transitions |
| Trade and logistics | Eight stashes, stock, cash at sites, trucks, aircraft cash, bulk buyers, loading endpoints and fuel supply | Checked connector coverage remains the critical dependency; do not equate legacy successful dispatch with physically verified travel |
| People and payroll | Hiring, roles, wages, loyalty, assignments, pilots/drivers/lookouts/soldiers, jail/death and worker identity | Assignment transitions, parking/disembarking, duplicate-body prevention and comprehensible blocked travel |
| Turf war | Foot/car/truck squads, orders, ammo, morale, veterans, ambush, retreat, policing, arrests and equipment losses | Hybrid timed squad combat remains; rendered bodies are not yet the sole combat authority |
| Territory and rackets | Four market regions, accumulated presence/decay, collection policies, squeeze tradeoff and prisoner actions | Explain income, hold trend, upkeep and uncertainty before adding more districts |
| Economy and reputation | Supply/demand, disruption, prices, fronts, renown and progression benefits | Debrief why finances changed; distinguish live operations from abstract strategic policies |
| Court | Bail/bonds, lawyers, motions, pleas/cooperation, jury, retrials, sentence, forfeiture and appeals | Human comprehension and legal consequences; game times are deliberately compressed |
| Casino | Hotel Cielo ownership, cage, laundering, skim and political obligations; roulette, blackjack, craps, baccarat and slots | Access/availability and money explanations; stale source comments are not acceptance evidence |
| Criminal partners | Family loans/tribute/services; agency trust/protection/arms; collective grass-to-acid barter/production; offshore shipments | Continuing obligations, political exposure and source/stock/cash clarity across menus |
| Equipment | Aircraft upgrades, electronics/countermeasures, arsenal stock, weapons and dealership drive/fleet purchases | Distinguish personal vehicle purchases from fleet-wide simulation benefits |
| Races | Air and street gates, fees, prizes, betting, cooldown and renown | Rival results are simulated times, not live multiplayer opponents; keep that distinction visible |
| Campaign | Four flying lessons, twelve story chapters, contextual tutorial and staged unlocks | Recorded human progression session needed; completion stand-ins do not measure enjoyment |
| Presentation | Shared previews, confirmation, dialogue focus/scrolling, acknowledgement, maps/feed, period props, interiors and effects | Consistent consequences and durable failures; moving-route/dense-combat profiling and coastal walkthrough |
| Persistence | Strategic save/load, compatibility and deterministic simulation switches | Preserve existing fixtures; test interrupted operations and identity transitions |

The original loading-endpoint audit failed all 99 directed pairs. Subsequent loading/detour work makes a small subset valid; the recorded follow-up still leaves 92 blocked. Check the latest route audit rather than treating the old 99/99 record as current. Trucks/squads retain legacy routing until connectors can support a measured migration. Payroll effectiveness must remain independent of cosmetic arrival.

## Multiplayer feature inventory

Fifteen roles exist: Pilot, Copilot, Spotter, Boat, Boss, Lieutenant, Fixer, Mechanic, Controller, Interceptor, Cutter, Chief, Patrol, Analyst and Undercover. Solo, police, cooperative, versus and campaign configurations layer available systems; an existing seat does not guarantee an equally busy or enjoyable role.

| Feature | Current implementation | Limit |
|---|---|---|
| Authority | Host owns simulation; role permissions and command handlers validate mutations | Preserve `Session.command` returning `[ok, message]`; previews never grant permission |
| Transport | TCP newline JSON, protocol v3 with legacy v2 handling; nominal 20 Hz snapshots | UDP prediction is deferred; no evidence of internet-scale latency suitability |
| Lobby | Room/seat claiming, host controls, password, kick/ban/lock, LAN discovery | LAN discovery is not NAT traversal or public matchmaking |
| Handoff | AI substitution, seat claim/release and a reconnect reservation window | Human-to-AI continuity still needs real disconnect/rejoin testing |
| Controls | Remote pilot inputs and specialised role controls | End-to-end physical controller and latency checks outstanding |
| Actions | Sequence-correlated acknowledgements; durable pending/result-unknown presentation | No automatic resend of unanswered mutations; acknowledgement is separate from refreshed snapshot |
| Previews | Capability-advertised read-only request/reply | Older peers keep commands and explicitly lack previews; execution revalidates stale state |
| Intelligence | Role/side-filtered snapshots, ground visibility, selected cards, map layers and feed | Continue distant-fight/hidden-unit tests; richer cards must not bypass filtering |
| Voice | 8 kHz mu-law frames over TCP; channel routing, range/terrain effects, encryption/interception and server throttling | Codec/router tests do not prove microphone, speaker, firewall or two-machine operation |
| Dedicated hosting | Headless entry point, status/configuration and save/idle policies | CI tests do not replace a hosted human session |

### Concrete source findings to address

1. **Command sequences correlate results but do not deduplicate execution.** `HostServer._message` appends each received command to `inbox`, and execution acknowledges its sequence. Repeated sequence packets can be queued twice. UI duplicate guards help ordinary interaction but are not host idempotence. Add a connection/session-scoped policy, cached acknowledgement and bounded history, then test repeatable purchases/orders and reconnect semantics.
2. **The message-size limit checks only the remaining buffer.** `read_lines` extracts complete lines before `_process` checks `MAX_LINE`. A complete oversized line therefore bypasses that check. Enforce limits during extraction and bound work/queued commands per peer; test both fragmented and newline-terminated oversized input.
3. **Remote input freshness is not an explicit safety contract.** Latest controls remain active while a connection remains present. Define and test neutral/AI behaviour when a connected client stops sending input, without changing aircraft performance.
4. **AI knowledge policy needs a separate review.** Police/rival decisions can inspect broader simulation records than a human role sees, including opposing guards/trucks/checkpoints. This is not proof of a client snapshot leak. Decide intended AI knowledge before replacing it or using balance comparisons to justify it.

These findings are source-verified paths, not reproduced network exploits or measured human usability failures. This audit does not alter their behaviour.

## Recommended work order and release gates

1. Correct physical loading/meeting connectors and measure truck/squad migration. Preserve unreachable order reasons before stock/cash is removed.
2. Harden command deduplication, framing and stale-input handling with focused transport tests.
3. Finish district/squad dashboards and operational/battle debriefs using authoritative recorded outcomes and permission-filtered observations.
4. Record one campaign-to-empire human session: first jobs, investment, hiring, delegation, expansion, police pressure and recovery. Record confusion/travel repetition separately from strategic mistakes.
5. Finish and walk the HAR–coastal road–Warehouse 7–harbour corridor; then people/vehicles and event feedback. Profile a moving route and dense squads before/after assets.
6. Review faction AI commitments and knowledge. PR #244 changed ten paired war seeds materially (arrests/burned stashes/combat losses rose); broader balance evidence is required, not arbitrary compensation.
7. Measure physical-member combat before migrating authority. Retain issue #85 until compatibility and outcomes are demonstrated.

Outstanding human gates: supported resolutions/palettes, keyboard/mouse/controller, all functional sites and bridges, a Windows exported walkthrough, real two-machine actions/seat handoff/voice/disconnects, campaign pacing and audio redistribution rights. Passing source tests cannot close them. Defer additional aircraft, chapters, multiplayer racing and larger new combat systems until these integration gates pass.
