# Issue #94 coverage matrix — 9 October 2026

This maps requested entry points to representative existing checks. It does not equate source coverage with human acceptance. Vegetation coverage was integrated through #281; this slice fills the remaining taxi action gap without duplicating established tests.

| Requested system | Representative evidence |
|---|---|
| NightDirector | test_nights: planning, rejected in-operation orders, hot-run completion and recorded next night |
| AISmuggler | test_ai_smuggler: seeded entry/exit, drops, escape, terrain crash and pursuit response |
| Autopilot | test_autopilot_unit: engagement, attitude response, airspeed preservation, leg arrival once |
| LogisticsMenu | test_action_review: read-only preview, cancel without stock mutation and capped authoritative transfer; test_modal_menu_input: pending/refused remote order |
| Lobby | test_playable_maps: Costa Brava/default and generated selections; test_room_screen: waiting-room options |
| HQOrders / HQBoard | test_frontend::test_boss_and_chief_order_menus_issue_orders: runner route and police funding through shared command surface with authoritative assertions |
| HangarMenu | test_airframe::test_the_hud_the_hangar_and_the_desk_show_it plus shared menu focus/input checks |
| Minimap | test_frontend: delayed contacts hidden, report source/age retained, waypoint click/clear and places availability |
| Vegetation | test_vegetation: all presets, tall-obstacle retention, stable resources and empty input |
| Rackets menu | test_game_menus::test_enter_in_the_collectors_cycles_a_markets_terms: review without mutation then confirmed policy change |
| Race menu | test_game_menus: stable course selection and persistent authoritative refusal; test_races: race simulation outcomes |
| Taxi menu | test_taxi_menu: displayed fare, selection through PilotApp's authoritative ride, single charge, elapsed time, arrival/walking restored; cancellation, empty list, stale unaffordable fare and invalid index leave state unchanged |
| FlightDynamics | test_flight_dynamics: nine envelope/control/fuel/crash/determinism scenarios; test_core_parity and test_bots_parity retain flight golden checks |

Taxi checks use the smallest useful pilot/walker and Session fixture rather than building the rendered city. Objects are freed before Session disposal and world selection is restored. No simulation, gameplay, routes, payouts or fixtures change. The test is explicitly in the presentation lane; every other existing lane assignment remains intact.

Focused desktop taxi result: two passed, zero failed, no script/parse failures. Existing systems were exercised in the recorded full baseline and passing main CI. The new slice still requires current-head complete CI before integration and closure of #94. Hardware, exported walkthrough and real multiplayer gates remain separate.
