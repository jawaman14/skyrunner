# Dialogue, menus, buildings, roads and NPC review

Review date: 7 October 2026 (Sydney). Baseline: the integrated work following
PRs #178–#181, plus the fuel-cache art follow-on. These are proposed changes,
not an assertion that the entire interface/world has been playtested.

## What I would change first

1. Make dialogue commands wait for host acknowledgement and display real failures.
2. Give dialogue a scrolling, keyboard-navigable choice list and explicit confirmation
   for irreversible decisions. Handle more than nine choices.
3. Finish a common menu shell: useful initial focus, consistent Close/Back, retained
   feedback, readable unavailable reasons, and layouts that fit smaller screens.
4. Extend authoritative action previews to purchases, sales, bulk transfers and squad
   disbanding. Show where money/items go, what is charged, and what continues afterward.
5. Validate physical access to each building and the rendered/physical road network
   before expanding environmental dressing.
6. Add obstacle-aware NPC access routes and clearer identity/state presentation,
   preserving payroll authority and existing simulation balance.

Priority P1 means correctness/accessibility or a costly ambiguous action; P2 means
clarity/layout/world consistency; P3 means polish. **Confirmed** below describes
source behavior. **Risk** needs a targeted reproduction. **Design** is a proposal.

## Shared interface and dialogue findings

| ID | Priority / evidence | Finding and proposed change | Completion check |
|---|---|---|---|
| D1 | P1, confirmed | `Talk.open` returns `[true, ""]` immediately for a remote link. `Talk.State._do` consequently treats a sent command as success. Use sequence-correlated pending/result handling, with the host's acknowledgement before following a success branch. | A denied remote transaction shows the denial, changes no money and never displays success; delayed/duplicate acknowledgements cannot execute twice. |
| D2 | P1, confirmed | Several dialogue mutations lack result checks: crew bonuses/lawyers, Family tribute/stall, dealer/Collective automation, and lawyer plea/cooperation/wait branches. Add explicit success, refusal and pending paths; preserve character voice around factual feedback. | Force an invalid/stale state for every command-bearing choice and verify accurate text and state. |
| D3 | P1, confirmed | `TalkBalloon` filters out unavailable responses and numbers the rest; `_input` supports only 1–9. The lawyer's options can offer eleven entries. Provide Up/Down/Enter selection, scrolling and a visible Back/Leave action, with number shortcuts as a convenience. | Every choice remains reachable by keyboard and controller at 1024x768, including choices 10/11. |
| D4 | P1, risk | Balloon height is `150 + 38 * answer count`, independent of wrapped line/choice height; there is no scroll container and responses are plain single-line buttons. Fit content to the viewport, wrap responses and prevent double selection while `_next` awaits. | Long Collective introductions, lawyer options and resized windows keep speaker, response and exit reachable. Rapid clicks produce one command. |
| D5 | P1, design | A conversational answer may immediately sell a vehicle, trade all stock, plead guilty, sign cooperation or evacuate. Add an in-character review step that states exact affected assets/cost/consequence and offers a neutral cancel choice. | Cancel causes no mutation; confirmation rechecks the host's current state. Do not add confirmations to ordinary reading or cheap reversible choices. |
| M1 | P1, risk | `GameMenu.open` focuses Close. Native Enter on a focused Button may close a panel instead of performing its selected row action; tests often call `key()` directly. Focus the relevant row/action and return focus to the opener on close. | Test real dispatched keyboard events and mouse activation, not only direct method calls. |
| M2 | P2, confirmed | Ground menus use `GameMenu`, while logistics, pack, controls, pause, multiplayer and dialogue build separate shells; many actions use `FOCUS_NONE`. Reuse spacing/heading/exit/feedback primitives while retaining appropriate screen-specific layouts. | All primary actions and exits work with mouse, keyboard and controller, with visible focus. |
| M3 | P2, design | Brush/neon headlines fit the identity, but dense operational content needs calmer surfaces and a clear primary action. Keep the display font for titles; use readable text, tab labels and restrained accent colour below them. | Check both palettes, long text and four screen sizes; colour never carries state alone. |
| M4 | P1, confirmed | Some menus use `Session.command`; others call simulation mutators directly. Use shared, read-only availability/consequence descriptors and command execution consistently, including remote seats. | UI previews do not spend, accept jobs, move cargo or change RNG; stale execution is rejected by the host. |
| M5 | P2, confirmed | Local failures often live only in toasts, a reused footer, or an empty success note. Keep contextual outcome text distinct from help and a chronological event feed. | A rejection survives refresh; success identifies what changed and any partial completion. |

Sources: `scripts/game/talk.gd`, `scripts/ui/talk_balloon.gd`,
`scripts/ui/game_menu.gd`, `scripts/ui/widgets/confirm_box.gd`,
`scripts/station/station_app.gd::_cmd/_check_acks`, and the nine dialogue files.
Station acknowledgements are a useful existing pattern, though successful results
are not currently retained there as contextual confirmations.

## Every authored dialogue

Keep the characters' distinct voices. Move repeatable numeric business detail into
a compact transaction/status card rather than deleting it or making every character
speak like the same system menu. All game-world people remain fictional.

| File / conversation | Proposed changes |
|---|---|
| `family.dialogue` / Sal | Keep the uncertain offer read clearly attributed to the adviser. Show cost, debt/obligation and expiry beside Take; identify the respect consequence of pressing. Check results for tribute/stall and distinguish walking away from refusing the offer. |
| `general.dialogue` / Ibarra | Show passage duration and affected route, shipment source/quantity/cost and risk per mule versus per container. Keep island news separate from transaction choices. Replace the accidental “Havana — in the capital” place-name correction with the fictional location. |
| `lawyer.dialogue` | Split Representation, Motions, Plea/Cooperation and Case status into navigable groups. Keep refundable bail versus nonrefundable bond explicit. Confirm plea/cooperation and show their actual results; paginate/scroll the long options list. |
| `crew.dialogue` / Manny | Give each candidate a card with role, skill, wage frequency and attributed reliability hint. Separate recurring wage obligation from immediate cost. Show the specific jailed worker, check bonus/lawyer outcomes, and distinguish hired from arrived/assigned. |
| `buyers.dialogue` / Benny | Review exact quantity, source, unit price, proceeds destination and relationship/turf consequences before selling. Keep buyer commentary after confirmed execution. Explain unavailable buyers/goods rather than leaving the player to infer why options vanished. |
| `psych.dialogue` / Nico | Shorten the first explanation into steps with an optional “How does this work?” branch. Replace “everything” with an explicit quantity/source review. Show exchange estimate, destination of sheets/cash, circuit capacity and automation state. Check toggles' results. |
| `dealer.dialogue` / Marty | Let the player choose the vehicle being sold rather than only the newest car/truck. Review resale value, active-car replacement, fleet impact and ongoing insurance. Make automation changes explicit and acknowledged. |
| `casino.dialogue` / Lenny | Separate ownership, income, laundering, island protection and emergency evacuation. Show gross versus net share, source/destination of cash, payoff duration and evacuation assets/deadline in a compact card. Confirm costly/irreversible choices. |
| `casino_file.dialogue` / task force | Show case threshold, available funds, current surveillance/audit effects and raid consequences. Preserve unavailable actions with reasons, including insufficient evidence; acknowledge host results. |

## Menu inventory and proposed changes

This covers every `*menu.gd` screen, the lobby and shared modal/widgets. Ground
screens already inherit the visible Close control. Do not undo the completed job
confirmation or read-only fuel-preview work.

| Screen | Priority | Proposed next change |
|---|---|---|
| Lobby (`lobby.gd`) | P2 | Separate Play/Continue, Host and Join. Put board/map seeds and AI-watch under Advanced. Explain player count versus seats/layers in product language. Offer visible save identity/date rather than “New game (ignore save)” alone. Replace password-in-address UI with a separate masked field. |
| Shared shell (`game_menu.gd`) | P1 | Correct initial focus/Enter routing, return focus on close, unify header/action/outcome/footer structure, and make scroll regions explicit. |
| Job board (`job_menu.gd`) | P2 | Preserve previews and confirmation; add visible Jobs/Market tabs and selected-action mouse controls for gun disposition. Show run cost, cargo feasibility and delivery pay as distinct values. Carry equivalent behavior to copilot/fixer jobs. |
| Load planner (`load_menu.gd`) | P2 | Preserve read-only preview; identify planned versus physically loaded cargo and estimated endurance. Add authoritative affordability/availability previews for loadmaster/ferry actions. Clarify free private cache versus posted field price. Validate real slider drag/cancel and controller operation. |
| Hangar (`hangar_menu.gd`) | P1 | Separate Aircraft, Gear, Crew, Service and Upgrades with visible tabs. Show aircraft comparison and switching consequences, repair duration/flight lockout and purchase reasons. Route direct buy/hire/toggle/upgrade calls through commands and retain outcomes. |
| Vehicle dealer (`dealer_menu.gd`) | P1 | Make Lot/Owned focus visually clear. Add vehicle preview silhouette, total purchase/insurance cost and selected-item action buttons. Confirm sales with value and fleet impact; acknowledge purchases and automation changes. |
| HQ / map table (`hq_menu.gd`) | P1 | Make Orders/Intel/Squads explicit modes. Show human/AI command ownership and selected squad. Confirm Disband, report Hold/Melt/right-click order outcomes, and show an order preview before issuing. The overridden `open` should preserve shared focus/feedback behavior. |
| Logistics (`logistics_menu.gd`) | P1 | Replace formatted monospace rows with sortable tables; separate Stock, Transfers, Rounds and Improvements. Replace hidden `0 = all` with an explicit All choice and units. Preview quantity, source, destination, truck availability and route. Bulk-cash action should report each failed/partial transfer, not flatten failures to “No cash.” Add scroll regions. |
| Phone (`phone_menu.gd`) | P2 | Keep NEW contacts, group by business/task, give a selected-contact preview and show unavailable services with reasons where useful. Return from conversations to the selected contact rather than losing context. |
| Taxi (`taxi_menu.gd`) | P2 | Preview destination, fare, time advancement and affordability before departure. Explain why a stop is unavailable and retain a failed ride's reason instead of closing first. |
| Track (`race_menu.gd`) | P2 | Show total entry plus stake, win/place selection, required vehicle and cooldown in a selected-race card; provide visible controls and retain failure/success feedback. |
| Collectors (`rackets_menu.gd`) | P1 | Separate market policy from prisoner actions. Identify which/all prisoners an action affects, show ransom/payroll/release consequences and confirm irreversible bulk release. Preview the next policy rather than silently cycling it. |
| Casino tables (`casino_menu.gd`) | P2 | Keep existing card/dice/reel visuals. Put state-specific buttons on the felt, show total committed stake and net result separately, explain unavailable moves and distinguish prepared bets from charged bets. Avoid stale visual state when a table becomes unavailable. |
| Pack (`pack_menu.gd`) | P2 | Reflow fixed-width rows; label source rack and actual moved quantity. Make purchase/weight/stock reasons visible before action; add focusable controls and a Close button. Preserve separate on-foot inventory authority. |
| Controls (`controls_menu.gd`) | P2 | Replace the nine-column axis grid with responsive per-axis cards. Show binding conflicts, connected device, current capture and cancellation clearly. Distinguish immediate settings from settings requiring reload; add a visible exit and defaults recovery. |
| Pause (`pause_menu.gd`) | P2 | Separate session actions from Audio, Visuals, Controls and Accessibility. Show last-save metadata and explicit save outcome. Preserve existing load/quit confirmations and multiplayer “game continues” note; restore focus to the invoking button after cancellation. |
| Multiplayer (`multiplayer_menu.gd`) | P1 | Show joining/connected/refused/disconnected state and actionable connection errors. Improve seat descriptions and host permissions. Confirm kicking a named player, keep voice loopback/mute indicators visible and preserve tab/focus during roster refresh. |
| Confirmation (`widgets/confirm_box.gd`) | P1 | Wrap/bound message width, focus the neutral choice, restore invoking focus, and prevent the event that opened the modal from confirming it. Label the actual action and consequence; keep Esc cancellation. |
| Tutorial (`tutorial_panel.gd`) | P2 | Make steps dismissible/reviewable, respect remapped keys, and reserve screen space rather than covering warnings. Test long tips alongside ground menus and station maps. |
| Upgrade/HQ boards, tables/key hints | P2 | Reuse authoritative blockers, show selected action and dependency reason, maintain stable selection on refresh, and do not treat every shortcut as an equally prominent action. |

## Station dashboards

All roles share `station_app.gd`; redesign by task rather than duplicating a whole
UI implementation per seat. Keep filtered snapshots and command permissions.

| Seats | Proposed changes |
|---|---|
| Copilot | Flight/Load/Jobs tabs with pilot-equivalent action previews, drop confirmation and physical loading progress. |
| Spotter / Analyst / Undercover | Distinguish report, source, age, confidence, verification progress and confirmed observation. Put Verify/Forward/Discard or beacon actions next to the selected record. |
| Mechanic | Prioritize selected defect, expected cost/time, work in progress and aircraft availability; explain blocked repair/refuel. |
| Fixer | Group procurement, contacts and logistics; reduce the long shortcut strip and retain accepted/rejected outcomes. |
| Boat | Clear destination/order preview, pickup/rendezvous status, cargo/fuel and order acknowledgement. |
| Controller | Separate Tracks, Units, Coverage and Operations; selected unit/target and current order stay visible. Show capability/evidence/cost reasons for deployment and enforcement. |
| Boss / Chief | Separate planning, active orders and results; make cash/funds and order consequences unambiguous. |
| Lieutenant / Patrol | Selected squad, movement/engagement state, order preview and Disband confirmation; keyboard alternatives for map orders. |
| Interceptor / Cutter | Clear assigned contact, last-known position versus live sighting, return/fuel status and control ownership. |

## Buildings, placement and access

Reviewed the builders and placement pipeline: `buildings.gd`, `city.gd`,
`city_dress.gd`, `downtown_dress.gd`, `port_dress.gd`, `island_render.gd`,
`casino_building.gd`, `map_city.gd` and world/walker integration. This is a source
and regression review, not a building-by-building walk-through of every seed.

| Area | Evidence / proposed change |
|---|---|
| Airfields | Hub/regional sites use fixed local terminal, tower, hangar, pump and showroom offsets; rural sites use sheds/drums. Build a placement manifest with footprint, entrance, approach and runway clearance. Validate it after runway siting/rotation and terrain levelling. Keep the same interactions available at all quality presets. |
| HQs | Check organisation office stairs/desk, customs/task-force entrance and rival sites with walkable paths from the road. Label physical entrance and service identity. Preserve the existing stair and squad-seat release tests. |
| Stashes | Review all eight kinds: barn, mangrove shack, docks warehouse, lock-up, jungle camp, quarry shed, cay boathouse and villa. Many are solid silhouette buildings with decorative doors, not enterable interiors. Decide which should be enterable; do not imply a usable door where there is none. Add a clear loading/interaction apron and align it to a safe access route. |
| City lots | Building footprints avoid roads in generation and have chunked box colliders. `CityDress`'s introduction incorrectly says there is no collision: update that comment. Near models are split into lots while collision covers the original entire footprint; decorative gaps/alleys may look passable but are solid. Compare visible envelopes and walkable gaps before adding detailed interiors. |
| Facade orientation | `CityDress.street_yaw` uses the original 110 m city-grid arithmetic. It does not inspect the actual planned road polyline. For changed/non-grid roads, orient entrances to an actual accessible nearest road segment; maintain deterministic choices. |
| Downtown landmarks | Preserve footprint/obstacle authority while checking model scaling, base sink, skyline repetition and LOD transitions. Give landmarks recognisable period silhouettes rather than only varied tints. |
| Docks / offshore town | Check quay/pier/jetty heights, water access, collisions and connection to roads; preserve port navigation space. Prioritize a complete functional loading dock over decorative density. |
| Hotel Cielo | Review airfield offset, forecourt, entrance, manager stairs, cage and table access, then closed/uprising/seized variants. Its crowd is intentionally cosmetic. Keep the separate offshore ground collider and validate it at its edges. |
| Period coherence | Replace modern-looking showroom vehicles, signage and road furniture after a visual inventory; names alone do not prove an asset is wrong. Use the restrained airfield prop palette for utilitarian surfaces, with neon concentrated in nightlife/signage. |
| Interactions | `Walker._update_focus` scores nearby facing Areas without a line-of-sight raycast. **Confirmed implementation, reproduction pending:** an interaction behind a wall may be selectable. Check occlusion, reach, labels and duplicate/overlapping areas before changing detection. |
| Terrain / foundations | Building groups generally use a single placement elevation; inspect footprint corners on slopes, door thresholds, buried floors and floating props. Do not regenerate terrain/flight fixtures as an incidental art change. |

## Road placement and physical travel

Existing strengths: offline terrain-aware planning, grade penalties, bridge metadata,
alternative routes round checkpoints, tree clearing and committed deterministic
road data. Existing tests cover key-place connectivity, grades/water, runway
avoidance and checkpoint bypass. Preserve them.

| ID | Evidence / proposed change |
|---|---|
| R1 | **Confirmed:** `RoadGraph.route` uses a direct line when no graph path exists or endpoints are under 400 m apart. That can bypass barriers/water/buildings; nearest-node stubs and loose-end links also lack obstacle checks. Return a reachable/access-route result, with explicit failure rather than an invisible straight-road fiction. Reproduce blocked/offshore cases first. |
| R2 | **Confirmed code gap:** city roads/bridges are rendered meshes; the bridge builder adds no collision, while walker ground is a heightmap and water recovery uses terrain height. Validate actual drive/walk bridge crossing, then add deck collision and consistent surface queries if needed. A correct graph route alone does not prove a car can cross. |
| R3 | Review crossings, T-junctions, cul-de-sacs and bridge ends against the rendered polyline and graph. Graph merging within 60 m and loose-end joining within 450 m can create connections without a visible/access-safe junction. Do not infer every geometric crossing is a usable junction. |
| R4 | Add robust empty/all-blocked input handling to offline `RoadPlanner.plan`; its initial seed search assumes a passable place exists. Revalidate smoothed/resampled roads against passability and grade constraints. These are tool robustness proposals, not evidence that the committed city network is broken. |
| R5 | Reconcile the rendered road width (about 9 m) with `Car.ROAD_M = 7 m` surface classification. Inspect edges/sidewalk speed and transitions; do not change driving balance without measurements. |
| R6 | Check road connectors to each strip apron, HQ entrance and stash loading area, plus safe turn radius/grade/clearance for trucks. Compare fallback classic/generated tracks with the city rather than assuming equivalent physical infrastructure. |

Suggested diagnostic output: map/seed, road/segment ID, graph component, minimum
runway/building clearance, sampled grade, bridge span/deck height and inaccessible
destinations. A readable map overlay should expose these results for review.

## NPC code and presentation

Reviewed physical worker lifecycle (`people.gd`/`agent.gd`/payroll), squad routing
and simulation ownership (`ground.gd`), police pursuit, on-foot combat and
`squads.gd`/`casino_crowd.gd` rendering. This does not claim a complete balance or
security audit of every AI decision branch.

| Area | Evidence / proposed change |
|---|---|
| Worker ownership | Preserve payroll as authority. `People.post_of` excludes truck drivers, squad members and away pilots/mules so they are not duplicated. Add transition checks for reassignment, incarceration, death, disappearance and save/load. |
| Movement / access | **Confirmed:** foot agents travel directly; car agents use road routes, with the graph's direct-line fallback. Worker `_spot` selects a nearest road node and lateral offsets, not a checked pedestrian space. Add obstacle-aware entrance/sidewalk paths and dry/reachable destination validation. |
| Physical versus effective work | A posted lookout affects gameplay before the body arrives by explicit design. Show “travelling to post” separately from the assignment/effect. Making work start only on arrival would be a deliberate balance change, not a graphical fix. |
| Saved-worker placement | Bodies first seen over 600 seconds after hiring appear settled. Test loaded-in-transit/reassigned workers; preserve body-route continuity if the design calls for it. Do not call the current simplification a proven save bug without a reproduction. |
| Identity / roles | `draw_list` exposes ID, faction, position, moving and car, but not occupation/name. Add permission-appropriate name/role/current-task presentation, distinguish a hired worker from squad soldiers and cosmetic patrons, and avoid leaking enemy payroll through UI labels. |
| Travel visuals | Worker rendering interpolates position and changes a moving car into a foot figure when stopped. Add arrival/parking/exit transitions and display travel progress; keep interpolation separate from authoritative arrival. |
| Squad / police AI | Preserve command-seat ownership, hidden/intel rules, road penalties and independent RNG streams. Add diagnostics for current order, route, stuck reason and engagement state. Test human-to-AI handoff and failed orders before adjusting tactics. |
| Combat visibility | On-foot combat and squad simulation use game-frame positions/ranges; inspect line-of-sight/cover against physical building walls. Treat stronger collision-aware cover as a measured mechanics change, with regression cases, not cosmetic polish. |
| Casino crowd | Separate cosmetic crowd already has its own seeded RNG and aisle graph, with no colliders/simulation authority. Improve idle variety, overlap/queue spacing and closed-house presentation without turning patrons into fake payroll agents. |
| Cost / determinism | Preserve near-character limits, far MultiMeshes, material reuse and deterministic simulation streams. Measure dense payroll/squad/casino scenes before adding per-person collision or expensive navigation updates. |

## Implementation sequence and validation

1. Dialogue acknowledgement/result correctness, then long-choice navigation and focus.
2. Common menu shell and transaction previews: hangar/dealer, logistics/collectors,
   then remaining menus and role-specific station flows.
3. Building access manifest and diagnostic map; reproduce bridge/interaction-occlusion
   and graph-shortcut problems before moving structures or roads.
4. Pedestrian/vehicle access paths and NPC identity/state, then arrival animation and
   period asset replacements around functional locations.

For each slice: meaningful command/state tests, real input/focus checks, long/empty
and stale-state content, both palettes, 1024x768/1280x720/1920x1080/2560x1080,
local and remote seats, saved/in-progress states, and exported-build playtesting.
Road/world/NPC checks must include walk/drive access and obstruction, not only a
successful graph search. Preserve current road, walker, people, agent, map,
dialogue and simulation parity tests. Report new failures and existing cleanup
diagnostics separately.

The audit intentionally makes no menu, dialogue, road, building-layout or NPC
behavior changes. Findings needing reproduction remain marked as such.
