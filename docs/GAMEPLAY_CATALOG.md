# Game feature, mechanic, and function catalog

This catalog covers the current `codex/turf-war-expansion` working tree. It combines a map of player-facing systems with a searchable index of every top-level GDScript function in `scripts/`. Gameplay behavior and design rationale are detailed in [FEATURES.md](FEATURES.md), [DESIGN.md](DESIGN.md), and [GUIDE.md](GUIDE.md).

## Features and mechanics

| System | What the game simulates | Main code areas |
|---|---|---|
| Campaign and story | Chapter progression from early smuggling into the 1980s cartel, faction unlocks, milestones, endings, and open play. | `scripts/sim/`, `scripts/game/`, `scripts/ui/` |
| Aircraft and flying | Data-driven aircraft; a six degree of freedom flight model; loading, fuel, weather, wind, runway and strip suitability, damage and gear wear; jobs, landings and crashes. | `scripts/sim/flight/`, `scripts/sim/airframe.gd`, `scripts/game/`, `scripts/bots/` |
| Islands and city | Classic, generated and Costa Brava maps; terrain, strips, roads, city districts, buildings, vegetation, collision and interiors. | `scripts/sim/map_*.gd`, `scripts/util/terrain.gd`, `scripts/render/`, `data/maps/` |
| Jobs, trade and economy | Contracts, cargo, drugs, guns, buyers, markets, supply and demand, pricing, cash, upgrades, payroll and competing organizations. | `scripts/sim/economy.gd`, `trade.gd`, `market.gd`, `payroll.gd`, `scripts/station/` |
| Logistics and stashes | Physical stock and cash at stash sites; trucks with drivers, road routes, fuel, stops, escorts, checkpoints, raids, transfers and multi-stop rounds. | `scripts/sim/logistics.gd`, `stashes.gd`, `agent.gd`, `pathfinding.gd`, `scripts/ui/logistics_menu.gd` |
| Turf war and combat | Region and district control, faction presence, squad orders, patrols, ambushes, raids, arrests, cover, morale, weapons, ammunition, casualties and territory-aware decisions. | `scripts/sim/ground.gd`, `territories.gd`, `rackets.gd`, `arsenal.gd`, `scripts/game/ground*.gd` |
| NPCs and crew | Hiring, roles, pay, loyalty, skill, task queues, drivers, soldiers, pilots, lookouts, dealers, arrests and AI management when a seat is empty. | `scripts/sim/agent.gd`, `payroll.gd`, `crew.gd`, `scripts/bots/` |
| Law, intelligence and court | Radar and radio detection, patrols, checkpoints, informants, undercover work, investigations, busts, evidence, charges, bail, lawyers, trials and sentences. | `scripts/sim/police.gd`, `radar.gd`, `case.gd`, `court.gd`, `analyst.gd` |
| Factions and narrative | Los Cuervos, the task force, the Family, the Agency and island factions; diplomacy, favors, news, negotiations and consequences. | `scripts/sim/`, `scripts/ui/talk*.gd`, `scripts/station/` |
| Player roles and multiplayer | Pilot, co-pilot, spotter, boat, boss, lieutenant, controller, police pilot, chief and patrol seats; AI seat handoff, LAN and network sessions, reconnects and chat. | `scripts/net/`, `scripts/sim/roles.gd`, `scripts/station/`, `scripts/game/` |
| On foot and vehicles | First-person walking, interaction, inventory, weapons, cars, boats, taxis, physical NPCs, driving and vehicle condition. | `scripts/game/walker.gd`, `car*.gd`, `foot*.gd`, `scripts/sim/ground.gd` |
| Presentation and accessibility | HUD and station interfaces, controls, tutorials, sound, radio, lighting, weather effects, visuals, colour-safe palette and screen filters. | `scripts/ui/`, `scripts/render/`, `scripts/audio/`, `scripts/game/` |
| Saves and deterministic simulation | Campaign and strategic saves, migrations, replayable random streams, parity fixtures, feature switches, balance simulations and test tooling. | `scripts/sim/strategic_save.gd`, `switches.gd`, `scripts/util/`, `scripts/balance/`, `tests/` |

## Function index

The index contains 180 GDScript files and 2701 top-level functions.


Each entry is the exact top-level function declaration and source line in the current tree. Static functions are included. Nested lambdas are not separate functions. Use this index to find behavior; use the linked design docs for explanations of the mechanics.

### `scripts/balance/air_risk.gd`

- L27: `static func table() -> Dictionary:`
- L52: `static func posture(s) -> String:`
- L63: `static func odds(s) -> Dictionary:`

### `scripts/balance/cli.gd`

- L19: `func _init() -> void:`
- L54: `func _abs(p: String) -> String:`
- L58: `func _save(name: String, data) -> void:`
- L66: `func _load(name: String):`
- L71: `func _secs(t0: int) -> float:`
- L75: `func cmd_crew() -> void:`
- L86: `func cmd_feasibility() -> void:`
- L94: `func cmd_tactical() -> void:`
- L103: `func cmd_strategic() -> void:`
- L149: `func cmd_tune() -> void:`
- L184: `func cmd_report() -> void:`

### `scripts/balance/crew_sim.gd`

- L17: `static func jobs(seeds := 10, tactics := ["low", "high"]) -> Array:`
- L26: `static func run_job(j: Array) -> Dictionary:`
- L30: `static func run_trial(crew: String, tactic: String, seed: int) -> Dictionary:`
- L81: `static func sweep(seeds := 10, workers := 4) -> Array:`
- L89: `static func loading_times(seed := 5) -> Dictionary:`
- L109: `static func table(results: Array) -> Array:`

### `scripts/balance/feasibility.gd`

- L13: `static func _trial(aircraft: String, field: String, load: String, test: String, ok: bool, outcome: String,`
- L19: `static func _session(key: String, code: String, seed := 11) -> Session:`
- L28: `static func load_aircraft(sess: Session, fuel_frac: float, payload_frac: float) -> void:`
- L47: `static func takeoff_trial(key: String, code: String, load: String) -> Dictionary:`
- L71: `static func landing_trial(key: String, code: String, load: String) -> Dictionary:`
- L94: `static func run_job(j: Array) -> Dictionary:`
- L100: `static func jobs(aircraft = null, fields = null, loads = null) -> Array:`
- L110: `static func sweep(workers := 4, aircraft = null, fields = null, loads = null) -> Array:`
- L117: `static func _mark(r) -> String:`
- L124: `static func table(results: Array) -> String:`

### `scripts/balance/report.gd`

- L166: `static func _load(dir: String, name: String):`
- L171: `static func _pct(v) -> String:`
- L175: `static func _signed(x: float, n: int) -> String:`
- L181: `static func _repr(v) -> String:`
- L192: `static func cal_repr(cal: HQ.Calibration) -> String:`
- L200: `static func write_report(results_dir: String, out_path: String) -> String:`

### `scripts/balance/strategic.gd`

- L25: `static func play_season(runner: String, law: String, seed: int, rules = null, cal: HQ.Calibration = null,`
- L80: `static func _entropy(zones: Array) -> float:`
- L92: `static func realism_summary(results: Array) -> Dictionary:`
- L132: `static func _disable(ss: HQ.Season, name: String) -> void:`
- L141: `static func run_job(j: Array) -> Dictionary:`
- L146: `static func jobs(n := 200, rules = null, cal: HQ.Calibration = null, disable: Array = [], runners = null,`
- L159: `static func run_matrix(n := 200, rules = null, cal: HQ.Calibration = null, disable: Array = [], runners = null,`
- L168: `static func matrix(results: Array) -> Array:`
- L192: `static func _dot(a: Array, b: Array) -> float:`
- L199: `static func _scaled(v: Array) -> Array:`
- L207: `static func equilibrium(m: Array, iters := 20000) -> Array:`
- L252: `static func dominance(m: Array, names_r: Array, names_l: Array) -> Array:`
- L280: `static func summary(results: Array) -> Dictionary:`
- L312: `static func rival_summary(results: Array) -> Dictionary:`
- L327: `static func endings(results: Array) -> Dictionary:`
- L337: `static func action_values(results: Array, side: String) -> Dictionary:`

### `scripts/balance/tactical.gd`

- L41: `static func _trial(zone: String, law: String, tactic: String, aircraft: String, seed: int) -> Dictionary:`
- L47: `static func _contraband_job(origin: String, dest: String, rng: PyRandom) -> Jobs.Job:`
- L57: `static func run_trial(zone: String, law: String, tactic: String, seed: int, aircraft := "c172p", trace = null) -> Dictionary:`
- L109: `static func setup_trial(zone: String, law: String, tactic: String, seed: int, aircraft := "c172p"):`
- L180: `static func _picket_point(zone: String, rng: PyRandom) -> Array:`
- L186: `static func run_job(j: Array) -> Dictionary:`
- L190: `static func jobs(seeds := 4, zones = null, laws = null, tactics = null, aircraft := "c172p") -> Array:`
- L200: `static func sweep(seeds := 4, workers := 4, zones = null, laws = null, tactics = null, aircraft := "c172p") -> Array:`
- L207: `static func _b(v) -> float:`
- L211: `static func rates(results: Array, where := {}) -> Dictionary:`
- L237: `static func unit_returns(results: Array) -> Dictionary:`
- L248: `static func posture_hazard(results: Array, law: String):`
- L257: `static func calibrate(results: Array, postures := ["standard"]) -> HQ.Calibration:`

### `scripts/balance/worker_pool.gd`

- L14: `static func run_one(kind: String, job: Array) -> Dictionary:`
- L30: `static func _tmp_dir() -> String:`
- L36: `static func map(kind: String, jobs: Array, workers: int) -> Array:`
- L94: `static func serve(kind: String, inp: String, outp: String) -> void:`

### `scripts/bots/autorun.gd`

- L19: `func _init(s: Session, prefer_hot_ := true) -> void:`
- L24: `func _pick():`
- L38: `func step(dt: float) -> FlightModel.Controls:`

### `scripts/bots/hq_bots.gd`

- L26: `static func _launder_all(ss: HQ.Season) -> void:`
- L30: `static func _pick_route(ss: HQ.Season, rng: PyRandom, mem: Dictionary, avoid = null) -> void:`
- L53: `static func _grow(ss: HQ.Season, rng: PyRandom) -> void:`
- L67: `static func _cartel(ss: HQ.Season, rng: PyRandom, mem: Dictionary) -> void:`
- L98: `static func _rival_route_weights(ss: HQ.Season, base: Array) -> PackedFloat64Array:`
- L106: `static func _last(ss: HQ.Season) -> HQ.NightReport:`
- L112: `static func runner_greedy(ss: HQ.Season, rng: PyRandom, mem: Dictionary) -> void:`
- L121: `static func runner_cautious(ss: HQ.Season, rng: PyRandom, mem: Dictionary) -> void:`
- L142: `static func runner_corrupt(ss: HQ.Season, rng: PyRandom, mem: Dictionary) -> void:`
- L156: `static func runner_shadow(ss: HQ.Season, rng: PyRandom, mem: Dictionary) -> void:`
- L173: `static func runner_launderer(ss: HQ.Season, rng: PyRandom, mem: Dictionary) -> void:`
- L186: `static func runner_adaptive(ss: HQ.Season, rng: PyRandom, mem: Dictionary) -> void:`
- L223: `static func runner_smart(ss: HQ.Season, rng: PyRandom, mem: Dictionary) -> void:`
- L260: `static func runner_random(ss: HQ.Season, rng: PyRandom, mem: Dictionary) -> void:`
- L288: `static func _predict_zone(ss: HQ.Season, rng: PyRandom, mem: Dictionary) -> String:`
- L304: `static func _balloon_weather(ss: HQ.Season) -> bool:`
- L308: `static func _fund_units(ss: HQ.Season, heli: int, interceptor: int, cutter: int) -> void:`
- L316: `static func law_interdiction(ss: HQ.Season, rng: PyRandom, mem: Dictionary) -> void:`
- L326: `static func law_investigator(ss: HQ.Season, rng: PyRandom, mem: Dictionary) -> void:`
- L340: `static func law_balanced(ss: HQ.Season, rng: PyRandom, mem: Dictionary) -> void:`
- L356: `static func law_adaptive(ss: HQ.Season, rng: PyRandom, mem: Dictionary) -> void:`
- L392: `static func law_random(ss: HQ.Season, rng: PyRandom, mem: Dictionary) -> void:`

### `scripts/bots/pilot.gd`

- L27: `static func _clamp(v: float, lo: float, hi: float) -> float:`
- L31: `static func bearing(x0: float, y0: float, x1: float, y1: float) -> float:`
- L42: `func _init(kind_: String, x_: float, y_: float, code_ = null) -> void:`
- L57: `func _init(af_: Airfield, hdg_: float, aim_: Array, elev_: float, gamma_: float, clear_: float) -> void:`
- L66: `func along_across(x: float, y: float) -> Array:`
- L74: `func point(dist: float) -> Array:`
- L78: `func path_alt(dist: float) -> float:`
- L86: `static func plan_approach(world: World, af: Airfield, gear_h: float, roll_m := 180.0) -> Approach:`
- L119: `static func plan_departure(world: World, af: Airfield, roll_m: float, prefer = null) -> Array:`
- L154: `static func make(d := {}) -> BotStyle:`
- L196: `func _init(sess_: Session, legs_: Array, style_: BotStyle = null, role_ := Roles.PILOT) -> void:`
- L208: `func leg() -> Leg:`
- L212: `func _set_phase(p: String) -> void:`
- L218: `func _attitude(c: FlightModel.Controls, s: FlightModel.FlightState, dt: float, bank_t: float, pitch_t: float) -> void:`
- L234: `func _bank_for(s: FlightModel.FlightState, hdg_t: float, limit = null) -> float:`
- L239: `func _pitch_for_vs(s: FlightModel.FlightState, dt: float, vs_t: float, min_ias: float) -> float:`
- L252: `func _throttle_for(s: FlightModel.FlightState, dt: float, ias_t: float, vs_t = null) -> float:`
- L260: `func _ground_along(x0: float, y0: float, vx: float, vy: float, ts: PackedFloat64Array) -> PackedFloat64Array:`
- L274: `static func _arange(stop: float, step: float) -> PackedFloat64Array:`
- L285: `func _terrain_ahead(s: FlightModel.FlightState, secs := 25.0) -> float:`
- L321: `func _need_along(s: FlightModel.FlightState, hdg: float, horizon := 75.0) -> float:`
- L345: `func _safe_heading(s: FlightModel.FlightState, desired: float) -> float:`
- L368: `func _threat(s: FlightModel.FlightState) -> Array:`
- L386: `func step(dt: float) -> FlightModel.Controls:`
- L400: `func _p_wait_load(c: FlightModel.Controls, s: FlightModel.FlightState, dt: float) -> void:`
- L409: `func _begin_departure(s: FlightModel.FlightState) -> void:`
- L430: `func _p_taxi(c: FlightModel.Controls, s: FlightModel.FlightState, dt: float) -> void:`
- L470: `func _p_takeoff(c: FlightModel.Controls, s: FlightModel.FlightState, dt: float) -> void:`
- L498: `func _p_climb(c: FlightModel.Controls, s: FlightModel.FlightState, dt: float) -> void:`
- L517: `func _route_to(s: FlightModel.FlightState, lg: Leg) -> void:`
- L535: `func _p_enroute(c: FlightModel.Controls, s: FlightModel.FlightState, dt: float) -> void:`
- L597: `func _p_drop(c: FlightModel.Controls, s: FlightModel.FlightState, dt: float) -> void:`
- L631: `static func _if_dist(ap: Approach) -> float:`
- L635: `func _p_approach(c: FlightModel.Controls, s: FlightModel.FlightState, dt: float) -> void:`
- L694: `func _final_len(ap: Approach) -> float:`
- L699: `func _track_centreline(s: FlightModel.FlightState, ap: Approach, across: float, v_max: float) -> float:`
- L705: `func _p_flare(c: FlightModel.Controls, s: FlightModel.FlightState, dt: float) -> void:`
- L723: `func _p_rollout(c: FlightModel.Controls, s: FlightModel.FlightState, dt: float) -> void:`
- L744: `func _go_around(why: String) -> void:`
- L755: `func _fail(why: String) -> void:`
- L763: `static func plan_fuel_lb(s: Session, lgs: Array, reserve_h := 0.6) -> float:`
- L778: `static func sess_hot(s: Session) -> bool:`
- L784: `static func mission_for(s: Session, job: Jobs.Job, home = null) -> Array:`
- L795: `static func fly(s: Session, bot: PilotBot, max_time := 1800.0, dt := 1.0 / 30, on_frame = null) -> String:`

### `scripts/bots/route.gd`

- L15: `static func _grid(world: World) -> Array:`
- L53: `static func _cell(x: float, y: float, n: int) -> Array:`
- L66: `static func _less(a: Array, b: Array) -> bool:`
- L74: `static func _push(heap: Array, item: Array) -> void:`
- L88: `static func _pop(heap: Array) -> Array:`
- L113: `static func plan_route(world: World, start: Array, goal: Array, climb_weight := 6.0, height_weight := 1.5,`

### `scripts/game/beta.gd`

- L11: `static func version() -> String:`
- L15: `static func label() -> String:`
- L20: `static func system_info() -> Dictionary:`
- L38: `static func session_info(s: Session) -> Dictionary:`
- L55: `static func feedback_bundle(s: Session, viewport: Viewport = null, note := "") -> String:`
- L75: `static func _add(zip: ZIPPacker, name: String, data: PackedByteArray) -> void:`
- L82: `static func report(s: Session, viewport: Viewport) -> String:`

### `scripts/game/car.gd`

- L63: `func setup(w: World, faction := "org") -> Car:`
- L115: `func apply_spec(sp: Dictionary) -> void:`
- L131: `func place(x: float, y: float, heading_deg: float) -> void:`
- L146: `func game_xy() -> Vector2:`
- L150: `func heading_deg() -> float:`
- L154: `func on_road() -> bool:`
- L159: `func top_speed() -> float:`
- L163: `func _physics_process(dt: float) -> void:`
- L181: `func _drive(throttle: float, steer: float, handbrake: bool, dt: float) -> void:`
- L264: `func _gearbox(cap: float, pedal: float) -> void:`
- L284: `func _body_springs(dt: float) -> void:`
- L307: `func _process(dt: float) -> void:`
- L313: `func _camera(dt: float) -> void:`

### `scripts/game/car_radio.gd`

- L46: `func air(t: float) -> Dictionary:`
- L50: `func phase() -> float:`
- L53: `func dial() -> String:`
- L70: `func setup(app_) -> CarRadio:`
- L94: `static func air_position(durs: Array, gap: float, t: float) -> Dictionary:`
- L112: `func clock() -> float:`
- L120: `func scan(user_dir := USER_DIR) -> void:`
- L134: `static func _key(st: Station) -> String:`
- L139: `static func _json(path: String) -> Variant:`
- L145: `func _read_shipped(id: String) -> Station:`
- L162: `static func _station_from(id: String, m: Dictionary, user: bool) -> Station:`
- L177: `static func _read_user(dir: String) -> Array:`
- L200: `static func _audio_in(dir: String) -> Array:`
- L223: `static func load_stream(path: String) -> AudioStream:`
- L239: `static func wav_from_bytes(b: PackedByteArray) -> AudioStreamWAV:`
- L271: `func station() -> Station:`
- L275: `func power(v: bool) -> void:`
- L286: `func tune(step: int) -> void:`
- L296: `func _save() -> void:`
- L305: `func now_playing() -> Dictionary:`
- L323: `func line() -> String:`
- L335: `func _process(dt: float) -> void:`
- L365: `func _stream_of(clip: Clip) -> AudioStream:`

### `scripts/game/controls_config.gd`

- L51: `static func names() -> Array:`
- L55: `static func action(n: String) -> String:`
- L60: `static func ensure() -> void:`
- L70: `static func _add_defaults(n: String) -> void:`
- L90: `static func helper() -> Node:`
- L101: `static func describe(n: String) -> String:`
- L112: `static func rebind(n: String, ev: InputEvent) -> void:`
- L133: `static func reset() -> void:`
- L141: `static func save_file(path := PATH) -> void:`
- L152: `static func load_file(path := PATH) -> bool:`
- L172: `static func settings() -> Dictionary:`
- L181: `static func save_setting(key: String, value) -> void:`

### `scripts/game/flight_axes.gd`

- L33: `func to_dict() -> Dictionary:`
- L36: `static func make(d: Dictionary) -> Binding:`
- L52: `func _init() -> void:`
- L60: `func to_dict() -> Dictionary:`
- L67: `static func from_dict(d: Dictionary) -> FlightAxes:`
- L76: `static func shape(v: float, b: Binding, lever: bool) -> float:`
- L90: `func device_index(b: Binding) -> int:`
- L103: `func value(control: String):`
- L116: `func read(inp: ControlMapper.InputFrame) -> void:`
- L137: `func capture_begin() -> void:`
- L145: `func capture_poll(control: String):`
- L171: `func clear(control: String) -> void:`
- L175: `func describe(control: String) -> String:`

### `scripts/game/gunplay.gd`

- L33: `func setup(sess_: Session, walker_: Walker, squads_: SquadRender, ui: Node) -> Gunplay:`
- L71: `func teardown() -> void:`
- L81: `func key(k: String) -> bool:`
- L101: `func _refresh_viewmodel() -> void:`
- L120: `static func _box_gun(t: String) -> Node3D:`
- L136: `func _process(dt: float) -> void:`
- L160: `func trigger() -> String:`
- L204: `func aim(origin: Vector3, dir: Vector3, range: float) -> Array:`
- L217: `static func _ray_capsule(o: Vector3, d: Vector3, a: Vector3, b: Vector3, r: float) -> float:`
- L239: `func _tracer(a: Vector3, b: Vector3) -> void:`

### `scripts/game/nerves.gd`

- L30: `func setup() -> Nerves:`
- L49: `static func target(s: Session) -> float:`
- L82: `func update(s: Session, dt: float) -> void:`
- L107: `static func heartbeat_wav() -> AudioStreamWAV:`

### `scripts/game/pilot_app.gd`

- L141: `func setup(sess: Session, graphics := "high", bot_ = null, server_ = null) -> PilotApp:`
- L232: `func _overlay(text: String, col: Color) -> Label:`
- L245: `func _help_overlay(text: String, col: Color) -> Control:`
- L263: `func _build_glareshield() -> Control:`
- L287: `func _build_player() -> void:`
- L301: `func _sync_beacons() -> void:`
- L333: `func _active_menu() -> GameMenu:`
- L340: `func _unhandled_input(ev: InputEvent) -> void:`
- L554: `func open_talk(name: String, title := "start") -> TalkBalloon:`
- L566: `func _talk_cues() -> void:`
- L586: `func cycle_debug_menu() -> void:`
- L601: `func _flight_press(ev: InputEvent) -> bool:`
- L610: `func toggle_logistics() -> void:`
- L624: `func toggle_pack() -> void:`
- L643: `func toggle_controls() -> void:`
- L660: `func open_pause() -> void:`
- L677: `func close_pause() -> void:`
- L686: `func _on_pause_choice(action: String) -> void:`
- L708: `func _unhandled_key_input(_ev: InputEvent) -> void:`
- L712: `func _input(ev: InputEvent) -> void:`
- L719: `func _map_toggle() -> void:`
- L728: `func _map_open() -> bool:`
- L733: `func _waypoint_picked(p: Vector2) -> void:`
- L763: `func _map_tick() -> void:`
- L782: `func _menu_closed() -> void:`
- L789: `func _toggle_on_foot() -> void:`
- L856: `func _phone_call(action: String) -> void:`
- L875: `func _talk_standing(name: String) -> void:`
- L885: `func _sit_casino(game: String) -> void:`
- L902: `func _dealer_sync() -> void:`
- L916: `func _casino_state() -> void:`
- L931: `func taxi_stops() -> Array:`
- L963: `func _find_areas(node: Node, action: String, out: Array) -> Array:`
- L973: `func _taxi_go(i: int) -> void:`
- L998: `func _taxi_tick(inp, bc) -> void:`
- L1022: `func _ensure_car(st: FlightModel.FlightState) -> void:`
- L1036: `func _enter_car() -> void:`
- L1058: `func _car_checkpoints() -> void:`
- L1076: `func _field_order(what: String) -> void:`
- L1084: `func _car_race() -> void:`
- L1090: `func _radio_key(what: String) -> void:`
- L1109: `func _exit_car() -> void:`
- L1133: `func _on_use(action: String, area: Area3D) -> void:`
- L1160: `func _open(key: String) -> void:`
- L1169: `func _toggle_menu(k: String) -> void:`
- L1184: `func _gather_input() -> ControlMapper.InputFrame:`
- L1206: `func _poll_stick(inp: ControlMapper.InputFrame) -> void:`
- L1212: `func _phone_watch() -> void:`
- L1225: `func _process(delta: float) -> void:`
- L1295: `func _car_lights() -> void:`
- L1302: `func _shake_camera() -> void:`
- L1318: `func _pilot_seat() -> void:`
- L1330: `func toggle_ai_pilot() -> void:`
- L1339: `func _foot_down() -> void:`
- L1353: `func _foot_input() -> ControlMapper.InputFrame:`
- L1361: `func _foot_hud() -> void:`
- L1389: `static func _basis(heading: float, pitch := 0.0, roll := 0.0) -> Basis:`
- L1393: `func _sync_scene(dt: float) -> void:`
- L1430: `func _sync_maritime() -> void:`
- L1499: `func _sync_effects(dt: float) -> void:`
- L1531: `func _sync_pursuers(dt: float) -> void:`
- L1565: `func _make_squads() -> void:`
- L1571: `func _sync_squads(dt: float) -> void:`
- L1582: `func _update_camera(st: FlightModel.FlightState, dt: float) -> void:`

### `scripts/game/race_markers.gd`

- L15: `func setup(sess: Session) -> RaceMarkers:`
- L41: `func _ring(c: Color, energy: float) -> MeshInstance3D:`
- L59: `func _place(ring: MeshInstance3D, c, i: int) -> void:`
- L73: `func _process(_dt: float) -> void:`

### `scripts/game/sound.gd`

- L44: `func setup(app_) -> Soundscape:`
- L61: `func _player(stream: AudioStream, db: float) -> AudioStreamPlayer:`
- L75: `func _ready() -> void:`
- L83: `static func wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:`
- L100: `static func _cached(key: String, fn: Callable) -> AudioStreamWAV:`
- L108: `static func engine_loop() -> AudioStreamWAV:`
- L128: `static func noise_loop(key: String, k: float, seconds := 2.0) -> AudioStreamWAV:`
- L148: `static func horn_loop() -> AudioStreamWAV:`
- L161: `static func surf_loop() -> AudioStreamWAV:`
- L178: `static func shot(tier: String) -> AudioStreamWAV:`
- L198: `static func squelch() -> AudioStreamWAV:`
- L213: `static func thunder() -> AudioStreamWAV:`
- L229: `static func rotor_loop() -> AudioStreamWAV:`
- L246: `static func siren_loop() -> AudioStreamWAV:`
- L261: `static func outboard_loop() -> AudioStreamWAV:`
- L277: `static func casino_band() -> AudioStreamWAV:`
- L326: `static func casino_room() -> AudioStreamWAV:`
- L331: `static func slot_win(big: bool) -> AudioStreamWAV:`
- L356: `static func chips() -> AudioStreamWAV:`
- L375: `func click(kind := "click") -> void:`
- L385: `func play_at(stream: AudioStream, pos: Vector3, db := 0.0) -> void:`
- L397: `func _loop3d(key: String, stream: AudioStream, pos: Vector3, db: float, unit := 60.0, reach := 4000.0) -> void:`
- L412: `static func _db(x: float) -> float:`
- L416: `func _process(dt: float) -> void:`
- L466: `func _radio(s, flying: bool) -> void:`
- L479: `func _world_sounds(s) -> void:`
- L508: `func _casino_sounds(s) -> void:`
- L525: `func on_lightning() -> void:`

### `scripts/game/speech.gd`

- L24: `static func available() -> bool:`
- L30: `static func set_enabled(on: bool) -> void:`
- L37: `static func say(text: String, interrupt := false) -> void:`
- L52: `static func line(who: String, text: String, answers: Array) -> void:`

### `scripts/game/talk.gd`

- L22: `static func manager() -> Node:`
- L32: `static func resource(name: String) -> DialogueResource:`
- L55: `static func open(parent: Node, name: String, title: String, link) -> TalkBalloon:`
- L226: `func _init(snap_fn_: Callable, cmd_fn_: Callable) -> void:`
- L231: `func refresh() -> void:`
- L398: `func _do(name: String, args := {}) -> bool:`
- L404: `func money_s(v: int) -> String:`
- L408: `func take() -> bool:`
- L411: `func refuse() -> bool:`
- L414: `func press() -> bool:`
- L417: `func pay() -> bool:`
- L420: `func stall() -> bool:`
- L424: `func buy_passage() -> bool:`
- L427: `func mules() -> bool:`
- L430: `func container() -> bool:`
- L434: `func barter_best() -> bool:`
- L437: `func barter_hundred() -> bool:`
- L440: `func sell_acid() -> bool:`
- L443: `func toggle_acid_auto() -> bool:`
- L447: `func dl_price(id: String) -> int:`
- L450: `func dl_can(id: String) -> bool:`
- L453: `func buy_vehicle(id: String) -> bool:`
- L456: `func sell_car() -> bool:`
- L459: `func sell_truck() -> bool:`
- L462: `func toggle_fleet_auto() -> bool:`
- L466: `func buy_stake() -> bool:`
- L469: `func collect() -> bool:`
- L472: `func launder() -> bool:`
- L475: `func pay_general() -> bool:`
- L478: `func buy_out() -> bool:`
- L481: `func evacuate() -> bool:`
- L484: `func wiretap() -> bool:`
- L487: `func audit() -> bool:`
- L490: `func raid() -> bool:`
- L494: `func has_cand(i: int) -> bool:`
- L497: `func cand_line(i: int) -> String:`
- L505: `func take_on(i: int) -> bool:`
- L508: `func crew_bonus() -> bool:`
- L511: `func jailed_name() -> String:`
- L514: `func lawyer_for_jailed() -> bool:`
- L519: `func roster_text() -> String:`
- L531: `func _have(good: String) -> int:`
- L534: `func can_sell(buyer: String, good: String) -> bool:`
- L538: `func quote_line(buyer: String, good: String) -> String:`
- L545: `func sell(buyer: String, good: String) -> bool:`
- L548: `func corners_line() -> String:`
- L557: `func has_filed(kind: String) -> bool:`
- L560: `func post_bail(how: String) -> bool:`
- L563: `func hire(tier: String) -> bool:`
- L566: `func move(kind: String) -> bool:`
- L569: `func lean_on_witness() -> bool:`
- L572: `func pay_judge() -> bool:`
- L575: `func plead() -> bool:`
- L578: `func cooperate() -> bool:`
- L581: `func appeal() -> bool:`
- L584: `func wait() -> bool:`

### `scripts/game/walker.gd`

- L30: `func setup(w: World) -> Walker:`
- L68: `static func ground_body(w: World) -> StaticBody3D:`
- L92: `func place(x: float, y: float, heading_deg: float) -> void:`
- L100: `func game_xy() -> Array:`
- L104: `func _unhandled_input(ev: InputEvent) -> void:`
- L112: `func _physics_process(dt: float) -> void:`
- L150: `func _step_up(dir: Vector3) -> void:`
- L165: `func _update_focus() -> void:`
- L182: `func use() -> void:`
- L187: `func toggle_torch() -> void:`

### `scripts/main.gd`

- L31: `func _ready() -> void:`
- L60: `func show_lobby() -> void:`
- L75: `func _host_extras(server) -> void:`
- L86: `func _open_room() -> void:`
- L112: `func _unhandled_key_input(ev: InputEvent) -> void:`
- L118: `func open_mp() -> MultiplayerMenu:`
- L144: `func _mp_join(address: String, role: String, player_name: String) -> void:`
- L158: `func _leave(to: String) -> void:`
- L175: `func start() -> void:`
- L278: `func _join() -> void:`
- L309: `func _enter_game(link: NetClient, role: String) -> void:`
- L321: `func _seat(link: NetClient, role: String) -> void:`
- L335: `func _smoke(sess: Session) -> void:`
- L343: `func _shoot(app: PilotApp) -> void:`

### `scripts/net/dedicated.gd`

- L19: `func _init() -> void:`
- L44: `func _process(delta: float) -> bool:`
- L53: `func _notification(what: int) -> void:`

### `scripts/net/dedicated_server.gd`

- L42: `static func parse(args: Array, env := {}) -> Dictionary:`
- L79: `static func _coerce(like: Variant, v: String) -> Variant:`
- L89: `func _init(cfg_: Dictionary) -> void:`
- L95: `func session_options() -> Dictionary:`
- L116: `func start() -> String:`
- L143: `func note(text: String) -> void:`
- L154: `func step(delta: float) -> bool:`
- L182: `func _pilot_seat() -> void:`
- L192: `func players() -> int:`
- L196: `func _autosave(delta: float) -> void:`
- L205: `func save() -> void:`
- L212: `func shutdown() -> void:`

### `scripts/net/host_desk.gd`

- L14: `func setup(sess_: Session, server_: HostServer, role_: String) -> HostDesk:`
- L26: `func _process(dt: float) -> void:`
- L36: `func _pilot_seat() -> void:`

### `scripts/net/host_server.gd`

- L76: `func start(port_ := DEFAULT_PORT, mode_ := Roles.COOP, bind := "*", seed := 7):`
- L92: `func stop() -> void:`
- L100: `func _exit_tree() -> void:`
- L104: `static func line(msg: Dictionary) -> PackedByteArray:`
- L109: `static func read_lines(peer: StreamPeerTCP, buf: PackedByteArray) -> Array:`
- L127: `func _process(_dt: float) -> void:`
- L161: `func attach(sess_) -> void:`
- L167: `func start_room(port_ := DEFAULT_PORT, mode_ := Roles.COOP, bind := "*", seed := 7, host_name_ := "host"):`
- L173: `func _room_message(c: Conn, msg: Dictionary) -> void:`
- L192: `func _broadcast_room() -> void:`
- L201: `func host_claim(role: String) -> String:`
- L206: `func begin(sess_: Session) -> void:`
- L232: `func _log(text: String) -> void:`
- L238: `func status() -> Dictionary:`
- L243: `func _hello(c: Conn, hello: Dictionary) -> void:`
- L311: `func _message(c: Conn, msg: Dictionary) -> void:`
- L373: `func _drop(c: Conn) -> void:`
- L390: `func chat(from: String, role: String, text: String, to := "all") -> void:`
- L411: `static func public_id(token: String) -> String:`
- L415: `func relay_voice(from_id: String, from_name: String, from_role: String, ch: String, seq: int, d: String, end: bool) -> void:`
- L450: `func host_voice(ch: String, seq: int, d: String, end: bool) -> void:`
- L455: `func kick(token: String, ban := true) -> bool:`
- L467: `func roster() -> Array:`
- L475: `func _broadcast_seats() -> void:`
- L484: `func _send(role: String, msg: Dictionary) -> void:`
- L492: `func pump(sess_: Session) -> void:`
- L508: `func publish(sess: Session, force := false) -> void:`

### `scripts/net/lan_discovery.gd`

- L17: `static func beacon(name: String, port: int, mode: String, players: int, locked := false) -> PackedByteArray:`
- L23: `static func parse(bytes: PackedByteArray, from_ip: String) -> Dictionary:`
- L40: `static func local_addresses() -> PackedStringArray:`
- L57: `func start(info_: Callable, dest_ := "255.255.255.255", dest_port_ := PORT) -> Announcer:`
- L66: `func _process(dt: float) -> void:`
- L72: `func send_now() -> void:`
- L80: `func _exit_tree() -> void:`
- L91: `func start(port := PORT) -> Finder:`
- L96: `func _process(_dt: float) -> void:`
- L102: `func ingest(bytes: PackedByteArray, from_ip: String, now := -1.0) -> void:`
- L110: `func list(now := -1.0) -> Array:`
- L121: `func _exit_tree() -> void:`

### `scripts/net/local_link.gd`

- L15: `func _init(s: Session, role_: String, ticks_ := true) -> void:`
- L21: `func send_command(cmd: String, args := {}) -> int:`
- L28: `func snapshot():`
- L33: `func send_input(roll: float, pitch: float, throttle: float) -> void:`
- L37: `func tick(dt: float) -> void:`
- L42: `func alive() -> bool:`
- L46: `func close() -> void:`

### `scripts/net/net_client.gd`

- L34: `func open(host_: String, port_: int, player_name: String, role_: String) -> NetClient:`
- L46: `func _process(_dt: float) -> void:`
- L50: `func poll() -> void:`
- L114: `func room_claim(role_: String) -> void:`
- L118: `func room_release() -> void:`
- L122: `func set_ready(on: bool) -> void:`
- L127: `func claim(role_: String) -> void:`
- L131: `func release() -> void:`
- L136: `func send_voice(ch: String, seq: int, d: String, end := false) -> void:`
- L141: `func say(text: String, to := "all") -> void:`
- L146: `func reconnect() -> void:`
- L159: `func _put(msg: Dictionary) -> void:`
- L164: `func send_command(cmd: String, args := {}) -> int:`
- L172: `func send_input(roll: float, pitch: float, throttle: float, rudder := 0.0, brake := 0.0) -> void:`
- L178: `func snapshot():`
- L182: `func tick(_dt: float) -> void:`
- L186: `func alive() -> bool:`
- L190: `func close() -> void:`

### `scripts/net/radio_voice.gd`

- L36: `static func make(kind: String, fc: float, rate: float, q := 0.707) -> Biquad:`
- L54: `func copy_from(o: Biquad) -> void:`
- L61: `func run(x: float) -> float:`
- L68: `func _init(seed_ := 1) -> void:`
- L75: `func process(frame: PackedFloat32Array, q: float, scrambled := false) -> PackedFloat32Array:`
- L106: `func squelch_open() -> PackedFloat32Array:`
- L117: `func squelch_close() -> PackedFloat32Array:`
- L128: `static func rms(frame: PackedFloat32Array) -> float:`

### `scripts/net/room.gd`

- L22: `func _init(mode_ := Roles.COOP, host_name := "host", host_role := Roles.PILOT) -> void:`
- L28: `func available(role: String) -> bool:`
- L38: `func add(id: String, name: String) -> void:`
- L46: `func remove(id: String) -> void:`
- L51: `func holder(role: String) -> String:`
- L59: `func claim(id: String, role: String) -> String:`
- L78: `func release(id: String) -> void:`
- L84: `func set_ready(id: String, on: bool) -> void:`
- L91: `func can_start() -> String:`
- L104: `func seats() -> Array:`
- L115: `func to_dict() -> Dictionary:`
- L123: `func host_role() -> String:`

### `scripts/net/snapshot.gd`

- L13: `static func _r(v, nd := 1) -> float:`
- L20: `static func build(sess: Session, role: String, seq := 0) -> Dictionary:`
- L43: `static func _xy(p: Array) -> Dictionary:`
- L47: `static func _pose(x, y, z, heading, pitch := 0.0, roll := 0.0) -> Dictionary:`
- L51: `static func _with(d: Dictionary, extra: Dictionary) -> Dictionary:`
- L57: `static func _police_pilot(sess: Session, role: String) -> Dictionary:`
- L86: `static func _runner(sess: Session, role: String) -> Dictionary:`
- L188: `static func _track(ps: PoliceSystem, t: SensorNet.Track, now: float) -> Dictionary:`
- L198: `static func _loadout(sess: Session) -> Dictionary:`
- L226: `static func _job(sess: Session, j: Jobs.Job) -> Dictionary:`
- L235: `static func _law(sess: Session) -> Dictionary:`

### `scripts/net/station_link.gd`

- L18: `static func missing(link: Object) -> Array:`

### `scripts/net/voice_capture.gd`

- L12: `func push(mono: PackedFloat32Array, rate: float) -> Array:`
- L27: `func reset() -> void:`

### `scripts/net/voice_chat.gd`

- L45: `func attach_host(srv: HostServer) -> VoiceChat:`
- L52: `func attach_client(l) -> VoiceChat:`
- L59: `func _start() -> void:`
- L69: `func _open_mic() -> void:`
- L87: `func has_mic() -> bool:`
- L92: `static func devices() -> PackedStringArray:`
- L96: `func use_device(d: String) -> void:`
- L103: `func _now() -> float:`
- L107: `func _process(_dt: float) -> void:`
- L113: `func ptt_down() -> bool:`
- L118: `func _tick_capture() -> void:`
- L141: `func _emit_frame(f: PackedFloat32Array) -> void:`
- L148: `func _send(d: String, end: bool) -> void:`
- L158: `func hear(msg: Dictionary) -> void:`
- L184: `func _speaker(id: String) -> Speaker:`
- L203: `func _loopback_speaker() -> Speaker:`
- L210: `func _play(sp: Speaker, frame: PackedFloat32Array, q: float, scrambled: bool) -> void:`
- L216: `func _push(sp: Speaker, samples: PackedFloat32Array, rate: float) -> void:`
- L226: `func _close(sp: Speaker) -> void:`
- L233: `func _tick_speakers() -> void:`
- L247: `func talkers() -> Array:`
- L258: `func set_loopback(on: bool) -> void:`
- L265: `func level() -> float:`

### `scripts/net/voice_codec.gd`

- L18: `static func enc(x: float) -> int:`
- L26: `static func dec(b: int) -> float:`
- L33: `static func encode(samples: PackedFloat32Array) -> PackedByteArray:`
- L41: `static func decode(bytes: PackedByteArray) -> PackedFloat32Array:`
- L50: `static func pack(samples: PackedFloat32Array) -> String:`
- L54: `static func unpack(b64: String) -> PackedFloat32Array:`
- L62: `static func resample(src: PackedFloat32Array, from_rate: float, to_rate: float) -> PackedFloat32Array:`
- L89: `static func to_mono(frames: PackedVector2Array) -> PackedFloat32Array:`
- L98: `static func to_stereo(samples: PackedFloat32Array, gain := 1.0) -> PackedVector2Array:`
- L108: `static func level(samples: PackedFloat32Array) -> float:`

### `scripts/net/voice_router.gd`

- L25: `static func route(sess, from_id: String, from_role: String, channel: String, listeners: Array) -> Array:`
- L37: `static func hear(sess, from_role: String, channel: String, to_role: String) -> Array:`
- L59: `static func link(sess, a_role: String, b_role: String) -> float:`

### `scripts/net/voice_settings.gd`

- L18: `static func load_from(path := PATH) -> VoiceSettings:`
- L36: `func save(path := PATH) -> void:`
- L48: `func is_muted(id: String) -> bool:`
- L52: `func set_muted(id: String, on: bool) -> void:`
- L60: `func key_name() -> String:`

### `scripts/render/buildings.gd`

- L18: `static func mat(key: String) -> StandardMaterial3D:`
- L71: `static func set_night(night: float) -> void:`
- L83: `func _init(name_: String) -> void:`
- L90: `func _tool(key: String) -> SurfaceTool:`
- L97: `func _quad(t: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:`
- L107: `func prop(file: String, at: Vector3, yaw := 0.0, scale := 2.4, collide := true) -> AABB:`
- L128: `func vehicle(file: String, length: float, at: Vector3, yaw := 0.0) -> void:`
- L146: `func box(c: Vector3, s: Vector3, key: String, collide := true) -> void:`
- L166: `func wall(x0: float, z0: float, x1: float, z1: float, y0: float, height: float, thick: float, key: String, door := 0.0, door_h := 2.4) -> void:`
- L181: `func _seg(a: Vector2, b: Vector2, y0: float, h: float, thick: float, key: String) -> void:`
- L213: `func gable(c: Vector3, w: float, d: float, rise: float, key: String, overhang := 0.6) -> void:`
- L231: `func arch(c: Vector3, w: float, d: float, key: String, seg := 12) -> void:`
- L247: `func cylinder(c: Vector3, r: float, h: float, key: String, seg := 12, collide := true) -> void:`
- L269: `func interact(p: Vector3, action: String, label: String, radius := 2.0) -> void:`
- L286: `func lamp(p: Vector3, energy := 1.4, reach := 9.0) -> void:`
- L301: `func finish() -> Node3D:`
- L314: `static func _windows(k: Kit, x0: float, x1: float, z: float, y: float, n: int, facing := -1.0) -> void:`
- L321: `static func showroom(k: Kit, c: Vector3, w := 14.0, d := 9.0) -> void:`
- L357: `static func hangar(k: Kit, c: Vector3, w := 18.0, d := 20.0, with_board := true) -> void:`
- L371: `static func tower(k: Kit, c: Vector3, h := 14.0) -> void:`
- L378: `static func fuel_pump(k: Kit, c: Vector3) -> void:`
- L385: `static func drums(k: Kit, c: Vector3, n := 5) -> void:`
- L391: `static func shed(k: Kit, c: Vector3, w := 7.0, d := 5.0, key := "wood") -> void:`
- L402: `static func terminal(k: Kit, c: Vector3, w := 36.0, d := 14.0) -> void:`
- L419: `static func airfield_site(world: World, af: Airfield) -> Node3D:`
- L461: `static func hq(world: World, spec: Dictionary) -> Node3D:`
- L497: `static func _villa(k: Kit) -> void:`
- L545: `static func _task_force(k: Kit) -> void:`
- L573: `static func _compound(k: Kit) -> void:`
- L601: `static func _nightclub(k: Kit) -> void:`
- L665: `static func _customs(k: Kit) -> void:`
- L678: `static func _hacienda(k: Kit) -> void:`

### `scripts/render/casino_building.gd`

- L39: `static func site() -> Dictionary:`
- L44: `static func build(world: World) -> Node3D:`
- L73: `static func ground(world: World) -> StaticBody3D:`
- L102: `static func world_point(world: World, lx: float, ly: float, lz: float) -> Vector3:`
- L109: `static func set_open(node: Node3D, open: bool) -> void:`
- L132: `static func _figure(_k: Buildings.Kit, x: float, y: float, z: float, coat := "black") -> void:`
- L136: `static func _stool(k: Buildings.Kit, x: float, z: float) -> void:`
- L140: `static func _palm(k: Buildings.Kit, x: float, z: float) -> void:`
- L146: `static func _table(k: Buildings.Kit, x: float, z: float, size: Vector3, action: String, label: String, stools := 3) -> void:`
- L156: `static func _forecourt(k: Buildings.Kit) -> void:`
- L178: `static func _signs(node: Node3D) -> void:`
- L201: `static func _label(text: String, size: int, color: Color) -> Label3D:`
- L216: `static func _boards() -> Node3D:`
- L238: `static func _shell(k: Buildings.Kit) -> void:`
- L268: `static func _tower(k: Buildings.Kit) -> void:`
- L283: `static func _lobby(k: Buildings.Kit) -> void:`
- L308: `static func _mezzanine(k: Buildings.Kit) -> void:`
- L326: `static func _gaming_floor(k: Buildings.Kit) -> void:`
- L349: `static func _slot_bank(k: Buildings.Kit, side: float, z0: float) -> void:`
- L361: `static func _cage(k: Buildings.Kit) -> void:`
- L379: `static func _salon(k: Buildings.Kit) -> void:`
- L394: `static func _patio(k: Buildings.Kit) -> void:`

### `scripts/render/casino_crowd.gd`

- L57: `static func make(people: Array, seed_ := 1959) -> CasinoCrowd:`
- L64: `func _setup(people: Array, seed_: int) -> void:`
- L95: `static func _mat(key: String) -> Material:`
- L101: `static func _skin(c: Color) -> StandardMaterial3D:`
- L111: `static func _box(size: Vector3) -> BoxMesh:`
- L121: `static func _figure(coat: String, skin: Color) -> Dictionary:`
- L148: `func _place(f: Dictionary) -> void:`
- L153: `func _route(from: String, to: String) -> Array:`
- L174: `func _process(dt: float) -> void:`
- L186: `func _walk(f: Dictionary, dt: float) -> void:`

### `scripts/render/city.gd`

- L18: `static func city_material() -> ShaderMaterial:`
- L27: `static func set_wet(w: float) -> void:`
- L33: `static func set_night(n: float) -> void:`
- L41: `static func build(world: World, q: Quality) -> Node3D:`
- L68: `static func box_layer(boxes: Array, q: Quality, idx := []) -> MultiMeshInstance3D:`
- L103: `static func _crane(b: Dictionary) -> Node3D:`
- L120: `static func _roads(world: World, roads: Array) -> MeshInstance3D:`
- L164: `static func _samples(world: World, r: Array) -> Array:`
- L185: `static func _strip(st: SurfaceTool, s0: Array, s1: Array, lo: float, hi: float, up: float, col: Color) -> void:`
- L203: `static func _road_details(world: World, roads: Array) -> Node3D:`
- L267: `static func _lerp_sample(a: Array, b: Array, t: float) -> Array:`
- L271: `static func _edge_pt(s: Array, lateral: float, up: float) -> Vector3:`
- L279: `static func deck_z(world: World, p: Vector2, side: Vector2) -> float:`
- L286: `static func _bridges(world: World, roads: Array, bridges: Array) -> MeshInstance3D:`
- L338: `static func kit_mesh(part: String) -> Mesh:`
- L353: `static func _mm_of(mesh: Mesh, xfs: Array, name_: String, range_end: float) -> MultiMeshInstance3D:`
- L370: `static func _lamps(world: World, roads: Array) -> Node3D:`
- L426: `static func _props(world: World, roads: Array) -> Node3D:`
- L491: `static func _prop_xf(world: World, p: Vector2, yaw: float, k: float) -> Transform3D:`
- L496: `static func _palms(world: World, roads: Array, q: Quality) -> MultiMeshInstance3D:`
- L557: `static func stash_house(world: World, st: Dictionary) -> Node3D:`

### `scripts/render/city_dress.gd`

- L57: `static func draw_range(q: Quality) -> float:`
- L67: `static func model(role: String, i := 0) -> Variant:`
- L72: `static func _load(spec: Array) -> Variant:`
- L103: `static func material(kit: String) -> ShaderMaterial:`
- L113: `static func set_night(n: float) -> void:`
- L121: `static func street_yaw(x: float, y: float) -> float:`
- L137: `static func lots(b: Dictionary, i: int) -> Array:`
- L177: `static func _role(style: String, h: float, rng: RandomNumberGenerator) -> String:`
- L190: `static func _pick(role: String, cw: float, cd: float, target_h: float, rng: RandomNumberGenerator) -> Variant:`
- L211: `static func chunk_of(b: Dictionary) -> Vector2i:`
- L217: `static func colliders(boxes: Array) -> StaticBody3D:`
- L232: `static func build(boxes: Array, q: Quality) -> Node3D:`

### `scripts/render/downtown_dress.gd`

- L30: `static func pick(boxes: Array) -> Dictionary:`
- L49: `static func available() -> bool:`
- L53: `static func _scene(name: String) -> PackedScene:`
- L60: `static func build(boxes: Array, q: Quality) -> Node3D:`

### `scripts/render/fx.gd`

- L40: `static func mat(sprite: String, add: bool, boost := 1.0) -> StandardMaterial3D:`
- L57: `static func _emitter(sprite: String, add: bool, amount: int, life: float, size: float, boost := 1.0) -> CPUParticles3D:`
- L71: `static func _ramp(cols: Array) -> Gradient:`
- L78: `static func _grow(a: float, b: float) -> Curve:`
- L87: `static func flames(size := 3.0) -> CPUParticles3D:`
- L129: `static func column(size := 4.0, dark := true, wind := Vector3.ZERO) -> CPUParticles3D:`
- L153: `static func _once(p: CPUParticles3D) -> CPUParticles3D:`
- L161: `func burn(key: String, pos: Vector3, size := 3.0) -> Node3D:`
- L184: `func smoke(key: String, pos: Vector3, size := 5.0) -> Node3D:`
- L197: `func sweep() -> void:`
- L206: `func blast(pos: Vector3, size := 4.0) -> Node3D:`
- L324: `static func scorch(diameter: float) -> MeshInstance3D:`
- L345: `func impact(pos: Vector3, normal := Vector3.UP) -> Node3D:`
- L380: `func shake_at(at: Vector3) -> float:`
- L391: `func _process(dt: float) -> void:`
- L407: `func throw_debris(pos: Vector3, n: int, size := 4.0) -> int:`
- L446: `func _expire_debris(debris_ref: WeakRef) -> void:`
- L453: `static func _debris_mat() -> StandardMaterial3D:`
- L461: `func splash(pos: Vector3, size := 2.0) -> Node3D:`
- L495: `func puff(pos: Vector3, size := 2.0) -> CPUParticles3D:`

### `scripts/render/island_render.gd`

- L11: `static func build(world: World, q: Quality) -> Node3D:`
- L26: `static func _ground() -> MeshInstance3D:`
- L67: `static func _tint(h: float, up: float, x: float, y: float) -> Color:`
- L81: `static func _palms(q: Quality) -> Node3D:`
- L116: `static func _town() -> Node3D:`

### `scripts/render/mesh_builder.gd`

- L14: `static func to_godot(p) -> Vector3:`
- L18: `func tri(a, b, cc, color) -> void:`
- L34: `func quad(a, b, cc, d, color) -> void:`
- L40: `func hexa(p: Array, color) -> void:`
- L49: `func box(cx: float, cy: float, cz: float, sx: float, sy: float, sz: float, color) -> void:`
- L54: `func frustum(y0: float, y1: float, s0: Array, s1: Array, color) -> void:`
- L61: `func cone(x: float, y: float, z0: float, radius: float, height: float, color, segments := 6) -> void:`
- L69: `func cylinder(x: float, y: float, z0: float, radius: float, height: float, color, segments := 10) -> void:`
- L78: `func is_empty() -> bool:`
- L82: `func mesh() -> ArrayMesh:`
- L96: `func node(name := "mesh", material: Material = null) -> MeshInstance3D:`

### `scripts/render/model_lib.gd`

- L41: `static func scene(path: String) -> PackedScene:`
- L53: `static func bounds(n: Node) -> AABB:`
- L59: `static func _bounds(n: Node, xf: Transform3D, acc: Array) -> void:`
- L69: `static func wrapped(path: String, s: float, yaw := PI, centre := true) -> Node3D:`
- L87: `static func fit_scale(path: String, length: float) -> float:`
- L99: `static func character(faction: String, variant := 0) -> Node3D:`
- L119: `static func arm(man: Node3D, tier: String) -> Node3D:`
- L138: `static func weapon(tier: String, mul := 1.0) -> Node3D:`
- L144: `static func car(faction: String, kind: String) -> Node3D:`
- L151: `static func vehicle(file: String, length: float) -> Node3D:`
- L157: `static func boat(kind: String) -> Node3D:`
- L169: `static func merged_mesh(root: Node3D) -> ArrayMesh:`
- L197: `static func palm_mesh(variant: int, height: float) -> Array:`

### `scripts/render/models.gd`

- L14: `static func vertex_material() -> StandardMaterial3D:`
- L23: `static func emissive(color: Color, energy := 2.0) -> StandardMaterial3D:`
- L42: `static func terrain_colors(world: World, step := 1) -> PackedColorArray:`
- L98: `static func designator(heading_deg: float) -> String:`
- L105: `static func build_airfield(world: World, af: Airfield, q: Quality) -> Node3D:`
- L198: `static func build_beacon(height := 260.0, radius := 6.0, color := Color(0.2, 1.0, 0.3, 0.35)) -> MeshInstance3D:`
- L213: `static func minimap_image(world: World, size := 256) -> Image:`
- L248: `static func _c(col: Color) -> Array:`
- L254: `static func build_aircraft(v: Aircraft.Visual, gear_height_m: float, q: Quality = null) -> Array:`
- L367: `static func build_pursuer(kind: String, q: Quality = null) -> Array:`
- L439: `static func build_boat(kind: String) -> Array:`
- L482: `static func build_bale() -> MeshInstance3D:`
- L490: `static func build_aerostat() -> MeshInstance3D:`

### `scripts/render/ocean.gd`

- L15: `func setup(world: World, q: Quality) -> Ocean:`
- L48: `func set_sky(col: Color) -> void:`
- L53: `func _process(_dt: float) -> void:`

### `scripts/render/port_dress.gd`

- L21: `static func _roll(i: int, salt: int) -> float:`
- L28: `static func shore_y(world: World, x: float) -> float:`
- L38: `static func piers(world: World) -> Array:`
- L51: `static func build(world: World, q: Quality) -> Node3D:`

### `scripts/render/quality.gd`

- L32: `static func make(n: String, d: Dictionary) -> Quality:`
- L53: `static func get_preset(n) -> Quality:`

### `scripts/render/scenery.gd`

- L33: `static func stone() -> StandardMaterial3D:`
- L41: `static func _mesh(model: String) -> Variant:`
- L57: `static func _roll(ix: int, iy: int, salt: int) -> float:`
- L65: `static func scatter(world: World) -> Array:`
- L110: `static func build(world: World, q: Quality) -> Node3D:`

### `scripts/render/screen_filter.gd`

- L25: `func _init() -> void:`
- L34: `func material_for(m: String) -> ShaderMaterial:`
- L58: `func set_mode(m: String) -> void:`
- L65: `func cycle() -> String:`
- L70: `func _process(_dt: float) -> void:`
- L75: `func _resize() -> void:`

### `scripts/render/squads.gd`

- L52: `func setup(world_: World, quality: String) -> void:`
- L87: `func _mmi(mesh: Mesh, name_: String) -> MultiMeshInstance3D:`
- L104: `static func _body_mesh(f: String, tinted := false) -> ArrayMesh:`
- L124: `static func _head_mesh() -> SphereMesh:`
- L137: `static func _box(st: SurfaceTool, c: Vector3, s: Vector3, col: Color) -> void:`
- L154: `static func vehicle(faction: String, kind: String) -> Node3D:`
- L162: `static func box_vehicle(faction: String, kind: String) -> Node3D:`
- L212: `func sync(squads: Array, fights: Array, cam: Vector3, now: float, dt: float, people := []) -> void:`
- L391: `static func _guns(loadout: Dictionary, men: int) -> Array:`
- L402: `func _actor(key: String, look: String, variant: int, xf: Transform3D, anim: String, tier: String) -> void:`
- L422: `func near_drawn() -> int:`
- L426: `func _hide_vehicle(id: String) -> void:`
- L431: `func _fill(n: MultiMeshInstance3D, xf: Array) -> void:`
- L440: `func drawn() -> int:`

### `scripts/render/street_lights.gd`

- L17: `func setup(lamps: Node, n: int) -> StreetLights:`
- L36: `static func nearest(all: PackedVector3Array, at: Vector3, k: int) -> Array:`
- L48: `func place(at: Vector3) -> void:`
- L61: `func _process(dt: float) -> void:`

### `scripts/render/terrain_mesh.gd`

- L11: `static func _weights(world: World, step: int) -> PackedColorArray:`
- L49: `static func landuse_texture(world: World) -> ImageTexture:`
- L61: `static func build(world: World, q: Quality) -> Node3D:`

### `scripts/render/texgen.gd`

- L18: `static func _noise(kind: int, freq: float, seed: int, fractal := FastNoiseLite.FRACTAL_FBM, octaves := 4) -> FastNoiseLite:`
- L28: `static func noise_pack() -> ImageTexture:`
- L48: `static func _cellular() -> FastNoiseLite:`
- L54: `static func normal_pack() -> ImageTexture:`
- L72: `static func heightmap(world: World) -> ImageTexture:`

### `scripts/render/vegetation.gd`

- L13: `static func _palm(seg := 6) -> ArrayMesh:`
- L48: `static func _broadleaf() -> ArrayMesh:`
- L58: `static func _conifer() -> ArrayMesh:`
- L67: `static func _mangrove() -> ArrayMesh:`
- L83: `static func _bush() -> ArrayMesh:`
- L91: `static func _blob(mb: MeshBuilder, x: float, y: float, z: float, r: float, col: Array) -> void:`
- L111: `static func _building_index(buildings: Array) -> Callable:`
- L127: `static func build(world: World, q: Quality) -> Node3D:`

### `scripts/render/weather_fx.gd`

- L29: `func setup(scene_: WorldScene) -> WeatherFX:`
- L64: `func apply(w: Dictionary) -> void:`
- L104: `func set_wet(w: float) -> void:`
- L115: `func light_scale() -> float:`
- L119: `func _process(dt: float) -> void:`

### `scripts/render/world_scene.gd`

- L33: `func setup(world_: World, q: Quality) -> WorldScene:`
- L73: `func _build_environment() -> void:`
- L146: `static func sun_elevation(h: float) -> float:`
- L150: `func set_hour(h: float) -> void:`
- L193: `func set_weather(w: Dictionary) -> void:`
- L198: `func _process(dt: float) -> void:`
- L203: `func show_aerostat(up: bool) -> void:`
- L210: `static func make_dust() -> GPUParticles3D:`
- L239: `static func make_wake() -> GPUParticles3D:`

### `scripts/sim/agency.gd`

- L107: `func _init(sess_, rng_: PyRandom, drng_: PyRandom = null) -> void:`
- L113: `func active() -> bool:`
- L118: `func job_from(origin: Airfield, airfields: Array):`
- L148: `func _return_leg(origin: Airfield, airfields: Array):`
- L166: `func carrying() -> bool:`
- L170: `func protecting() -> bool:`
- L174: `func _stung_aboard() -> bool:`
- L179: `func quash(how: String) -> bool:`
- L193: `func waves_through(r: PyRandom) -> bool:`
- L198: `func flight_done(job) -> bool:`
- L228: `func investigate() -> String:`
- L241: `func _check_exposed() -> void:`
- L256: `func update(dt: float) -> void:`
- L286: `func _double_game(step: float) -> void:`
- L328: `func _pipeline(step: float) -> void:`
- L369: `func view(side: String) -> Dictionary:`

### `scripts/sim/agent.gd`

- L33: `func _init(kind_: String, at_: Vector2, dur_ := 0.0, route_ := PackedVector2Array()) -> void:`
- L54: `func _init(id_: String, kind_: String, x_: float, y_: float) -> void:`
- L61: `func pos() -> Vector2:`
- L65: `func idle() -> bool:`
- L69: `func speed_ms() -> float:`
- L74: `func current() -> Task:`
- L79: `func working_s() -> float:`
- L84: `func left_m() -> float:`
- L89: `func remaining_route() -> PackedVector2Array:`
- L107: `func queue(task: Task) -> void:`
- L113: `func clear() -> void:`
- L123: `func hold(seconds: float) -> void:`
- L128: `func reroute(route_to_goal: PackedVector2Array) -> bool:`
- L160: `func _route_to(task: Task, graph: RoadGraph = null) -> void:`
- L173: `func update(dt: float, graph: RoadGraph = null) -> String:`

### `scripts/sim/ai_smuggler.gd`

- L33: `func _init(id_: String, x_: float, y_: float, z_: float, heading_: float, drop_point_: Array, exit_point_: Array,`
- L47: `func active() -> bool:`
- L51: `func signature(world: World) -> SensorNet.Signature:`
- L56: `func update(dt: float, world: World, threats: Array, drop_fn: Callable) -> String:`
- L130: `static func entry_and_exit(rng: PyRandom) -> Array:`
- L157: `func _init(rng_: PyRandom = null) -> void:`
- L160: `func due(now: float, active: int) -> bool:`
- L163: `func schedule_next(now: float) -> void:`

### `scripts/sim/aircraft.gd`

- L22: `func _init(p_name: String, x: float, y: float, z: float, max_lb_: float, kind_: String) -> void:`
- L30: `func accepts(item_kind: String) -> bool:`
- L47: `func _init(wing_: String, engines_: int, length_: float, span_: float, color_: Color, stripe_: Color, tricycle_ := true) -> void:`
- L74: `func _init(d: Dictionary) -> void:`
- L79: `func est_landing_roll(weight_lb: float, elev_m: float) -> float:`
- L82: `func pilot_station() -> int:`
- L88: `func seat_count() -> int:`
- L96: `static func _pairs(prefix: String, x: float, y: float, z: float, max_lb: float, kind: String) -> Array:`
- L100: `static func _stations(parts: Array) -> Array:`
- L113: `static func spec(key: String) -> Spec:`
- L117: `static func _roster() -> Dictionary:`

### `scripts/sim/airfield.gd`

- L25: `func _init(p_code: String, p_name: String, p_x: float, p_y: float, p_heading: float, p_length: float,`
- L44: `func dir() -> Array:`
- L49: `func to_local(px: float, py: float) -> Array:`
- L55: `func contains(px: float, py: float, margin := 0.0) -> bool:`
- L62: `func threshold(end: int) -> Array:`
- L67: `func to_dict() -> Dictionary:`

### `scripts/sim/airframe.gd`

- L53: `func _init(sess_) -> void:`
- L59: `func active() -> bool:`
- L63: `func of(key := "") -> Dictionary:`
- L70: `func engine() -> float:`
- L74: `func airframe() -> float:`
- L79: `func power_scale() -> float:`
- L91: `func gear_factor() -> float:`
- L100: `func rough() -> bool:`
- L104: `func engine_out() -> bool:`
- L109: `func limit(c: FlightModel.Controls) -> FlightModel.Controls:`
- L123: `func touchdown(fpm: float, limit_fpm: float, af) -> void:`
- L138: `func update(dt: float, s) -> void:`
- L162: `func place() -> String:`
- L170: `func terms() -> Array:`
- L178: `func price(part: String) -> float:`
- L183: `func repair(parts: Array, to := 100.0) -> String:`
- L204: `func stop(why := "") -> void:`
- L212: `func _work(dt: float) -> void:`
- L236: `func auto_service() -> void:`
- L251: `static func band_of(v: float) -> String:`
- L255: `func band() -> Dictionary:`
- L260: `func view(exact: bool) -> Dictionary:`

### `scripts/sim/analyst.gd`

- L32: `func _init(sess_) -> void:`
- L38: `func active() -> bool:`
- L43: `static func source_of(text: String) -> String:`
- L51: `func intake(x: float, y: float, radius: float, text: String, squawk: String, target, truth: bool) -> void:`
- L61: `func find(id: String):`
- L68: `func update(_dt: float) -> void:`
- L82: `func verify(id: String) -> String:`
- L94: `func forward(id: String) -> String:`
- L103: `func discard(id: String) -> String:`
- L115: `func release_all() -> void:`
- L121: `func _forward(e: Dictionary, why: String) -> void:`
- L134: `func view() -> Dictionary:`

### `scripts/sim/arsenal.gd`

- L42: `func _init(side_ := "", start := true) -> void:`
- L51: `func add(tier: String, n: int) -> void:`
- L57: `func add_all(weapons: Dictionary) -> void:`
- L63: `func take(tier: String, n: int) -> int:`
- L71: `func count() -> int:`
- L78: `func is_empty() -> bool:`
- L84: `func issue(n_men: int) -> Dictionary:`
- L98: `func give_back(loadout: Dictionary) -> void:`
- L105: `static func power(loadout: Dictionary, men: int) -> float:`
- L120: `static func guns(loadout: Dictionary, men: int) -> Array:`
- L132: `static func anti_vehicle(loadout: Dictionary) -> bool:`
- L137: `func value(mult := 1.0) -> int:`
- L144: `static func worth(weapons: Dictionary, mult := 1.0) -> int:`
- L152: `func seize_into(other: Arsenal) -> Dictionary:`
- L166: `func take_seized(weapons: Dictionary) -> int:`
- L178: `static func describe(weapons: Dictionary) -> String:`
- L186: `func to_dict() -> Dictionary:`
- L191: `static func from_dict(d: Dictionary) -> Arsenal:`
- L208: `static func gun_run(origin: Airfield, airfields: Array, stash_net, rng: PyRandom, price_mult := 1.0):`
- L251: `static func weapons_of(job: Jobs.Job) -> Dictionary:`

### `scripts/sim/autopilot.gd`

- L41: `func engage(s: FlightModel.FlightState, elevator_now := 0.0) -> void:`
- L55: `func engage_route(s: FlightModel.FlightState, wps: Array, alt_m: float, elevator_now := 0.0) -> void:`
- L63: `func disengage() -> void:`
- L67: `func update(dt: float, s: FlightModel.FlightState, c: FlightModel.Controls) -> FlightModel.Controls:`
- L118: `static func _along_across(x: float, y: float, aim: Array, hdg_deg: float) -> Array:`

### `scripts/sim/campaign.gd`

- L18: `func _init(k: String, t: String, target_ := 1.0) -> void:`
- L35: `func _init(num_: int, year_: int, title_: String, briefing_: String, runner_: Array, law_: Array,`
- L48: `static func _manny_job(sess) -> void:`
- L61: `static func _kickers_setup(sess) -> void:`
- L72: `static func _long_legs_setup(sess) -> void:`
- L100: `static func _chapters() -> Array:`
- L139: `func _init(index_ := 0, progress_ = null) -> void:`
- L149: `func to_dict() -> Dictionary:`
- L153: `static func from_dict(d) -> Campaign:`
- L160: `func attach(s) -> void:`
- L167: `func apply(s, run_setup := true) -> void:`
- L186: `func objective_lines() -> Array:`
- L199: `func _bump(key: String, amount := 1.0) -> void:`
- L204: `func _on_event(ev: EventBus.Event) -> void:`
- L220: `func tick(s) -> void:`

### `scripts/sim/casino.gd`

- L90: `func _init(sess_) -> void:`
- L98: `func active() -> bool:`
- L103: `func trading() -> bool:`
- L107: `func skim() -> float:`
- L112: `func tourism() -> float:`
- L117: `func gross_per_hour() -> float:`
- L125: `func share_per_hour() -> float:`
- L129: `func cage_left() -> int:`
- L138: `func update(dt: float) -> void:`
- L163: `func _events(dt: float) -> void:`
- L190: `func _law_ai(dt: float) -> void:`
- L206: `func why_not() -> String:`
- L220: `func buy_stake() -> String:`
- L237: `func collect() -> String:`
- L252: `func launder(stash_id: String, amount: int) -> String:`
- L284: `func pay_general() -> String:`
- L298: `func buy_out_rival() -> String:`
- L314: `func evacuate() -> String:`
- L330: `func at_tables() -> String:`
- L342: `func _house(net: int) -> void:`
- L349: `func _settle(game: String, net: int, text: String, extra := {}) -> void:`
- L357: `func _stake_ok(amount: int) -> String:`
- L366: `func play(game: String, a: Dictionary) -> String:`
- L412: `func _blackjack(a: Dictionary) -> String:`
- L445: `func _craps(a: Dictionary) -> String:`
- L477: `static func _won(net: int) -> String:`
- L482: `func case_action(kind: String) -> String:`
- L523: `func _uprising() -> void:`
- L535: `func _fall() -> void:`
- L543: `func _seize(out: bool) -> void:`
- L552: `func view(side: String) -> Dictionary:`

### `scripts/sim/casino_games.gd`

- L25: `static func spin(rng: PyRandom) -> int:`
- L29: `static func covers(bet: Dictionary) -> Array:`
- L81: `static func _adjacent(a: int, b: int) -> bool:`
- L91: `static func net(bet: Dictionary, result: int) -> int:`
- L97: `static func valid(bet: Dictionary) -> bool:`
- L101: `static func play(bets: Array, rng: PyRandom) -> Dictionary:`
- L125: `func _init(rng_: PyRandom) -> void:`
- L129: `func _shuffle() -> void:`
- L137: `func _draw() -> int:`
- L143: `static func value(hand: Array) -> Array:`
- L156: `static func is_blackjack(hand: Array) -> bool:`
- L159: `func deal(amount: int) -> String:`
- L188: `func hit() -> String:`
- L196: `func stand() -> String:`
- L202: `func double() -> String:`
- L215: `func _dealer_plays() -> void:`
- L228: `func _finish(res: String, n: int) -> void:`
- L234: `func advice() -> String:`
- L276: `func _init(rng_: PyRandom) -> void:`
- L279: `func place(kind: String, amount: int) -> String:`
- L297: `func add_odds(amount: int) -> String:`
- L306: `static func pass_odds_pays(point_: int, amount: int) -> int:`
- L315: `static func dont_odds_pays(point_: int, amount: int) -> int:`
- L325: `func roll() -> Dictionary:`
- L373: `func _init(rng_: PyRandom) -> void:`
- L377: `func _shuffle() -> void:`
- L385: `func _draw() -> int:`
- L390: `static func total(hand: Array) -> int:`
- L397: `func deal(on: String, amount: int) -> Dictionary:`
- L454: `static func pays(a: String, b: String, c: String) -> int:`
- L464: `static func rtp() -> float:`
- L472: `static func pull(amount: int, rng: PyRandom) -> Dictionary:`

### `scripts/sim/chronicle.gd`

- L136: `func _init(sess_, rng_: PyRandom) -> void:`
- L143: `func _interval() -> float:`
- L147: `func update(dt: float) -> void:`
- L167: `func random_event() -> String:`
- L185: `func _live_stash():`
- L192: `func _hottest_stash():`
- L198: `func _squads(f: String) -> Array:`
- L202: `func _can(id: String) -> bool:`
- L224: `func fire(id: String) -> String:`
- L354: `func _rival_turf(zone: String, d: float) -> void:`
- L364: `func _news(side: String, good: bool, public: bool, text: String) -> void:`
- L380: `func history(i: int) -> String:`
- L450: `func _milestones() -> void:`
- L480: `func _check(id: String, cond: bool, vars := {}) -> void:`
- L511: `func view(side: String) -> Dictionary:`

### `scripts/sim/comms.gd`

- L48: `func _init(s: String, x_: float, y_: float, d: float) -> void:`
- L61: `func _init(b: Array, f) -> void:`
- L66: `static func intersect(b1: Bearing, b2: Bearing):`
- L92: `func _init(rng_: PyRandom = null) -> void:`
- L96: `func transmit(t: float, channel: String, sender: String, text: String, pos = null, dur := -1.0) -> RadioMsg:`
- L125: `func can_hear(tx: Array, rx: Array) -> bool:`
- L136: `func _pos(m: RadioMsg) -> Array:`
- L142: `func scanner_at(since: float, rx: Array, channels: Array) -> Array:`
- L160: `func scanner(since: float) -> Array:`
- L169: `func channel(name: String, since := -1.0) -> Array:`
- L177: `func direction_find(msg: RadioMsg, mobile: Array = []) -> DFResult:`
- L201: `func _df_real(msg: RadioMsg, mobile: Array) -> DFResult:`

### `scripts/sim/controls.gd`

- L56: `static func _approach(cur: float, target: float, rate: float, dt: float) -> float:`
- L63: `static func _b(d: Dictionary, k: String) -> int:`
- L67: `func reset(throttle := 0.0) -> void:`
- L74: `func update(dt: float, inp: InputFrame, st: FlightModel.FlightState = null) -> FlightModel.Controls:`
- L140: `func _assisted(c: FlightModel.Controls, h: Dictionary, st: FlightModel.FlightState) -> FlightModel.Controls:`

### `scripts/sim/court.gd`

- L79: `func _init(sess_, rng_: PyRandom) -> void:`
- L84: `func open() -> bool:`
- L88: `func stage() -> String:`
- L93: `func holding() -> bool:`
- L98: `func arrest(how: String) -> void:`
- L164: `func _hot_charges(hot_lb: float, armed: bool) -> void:`
- L173: `func _charge(id: String) -> void:`
- L178: `func charge_names() -> String:`
- L182: `func _weight() -> int:`
- L189: `func flight_risk() -> bool:`
- L194: `func _bail_amount() -> int:`
- L199: `func lawyer() -> Dictionary:`
- L203: `func _say(runner: String, law: String) -> void:`
- L212: `func post_bail(how: String) -> String:`
- L236: `func hire(tier: String) -> String:`
- L257: `func motion(kind: String) -> String:`
- L293: `func strength() -> String:`
- L299: `func tamper() -> String:`
- L329: `func bribe_judge() -> String:`
- L354: `func plead() -> String:`
- L365: `func cooperate() -> String:`
- L392: `func appeal() -> String:`
- L410: `func no_bail() -> String:`
- L424: `func immunity() -> String:`
- L439: `func forfeiture() -> String:`
- L456: `func add_conspiracy() -> String:`
- L472: `func offer_plea(lenient := false) -> String:`
- L486: `func _prosecutor_opening() -> void:`
- L498: `func _expected_years() -> float:`
- L509: `func conviction_odds() -> float:`
- L514: `func _trial_x(noise: float) -> float:`
- L522: `func _trial() -> void:`
- L552: `func _sentence(how: String, years: float, fine: int) -> void:`
- L574: `func _close(verdict: String) -> void:`
- L583: `func update(dt: float) -> void:`
- L608: `func view(side: String) -> Dictionary:`

### `scripts/sim/dealership.gd`

- L70: `func _init(s) -> void:`
- L77: `static func spec(id: String) -> Dictionary:`
- L85: `func why_not(id: String, by_ai := false) -> String:`
- L100: `func buy(id: String, by_ai := false) -> String:`
- L118: `func sell(serial: int) -> String:`
- L142: `func use_car(serial: int) -> String:`
- L157: `func set_auto(on: bool) -> String:`
- L164: `func _find(serial: int) -> int:`
- L172: `func drive_spec() -> Dictionary:`
- L179: `func haulers() -> Array:`
- L189: `func fleet() -> Dictionary:`
- L205: `func apply() -> void:`
- L216: `func gets_past(job_id: int, squad_id: String) -> bool:`
- L231: `func insurance_hour() -> int:`
- L238: `func update(dt: float) -> void:`
- L255: `func _auto_buy() -> void:`
- L275: `func view_lite() -> Dictionary:`
- L297: `func view() -> Dictionary:`

### `scripts/sim/economy.gd`

- L86: `func _init(rng_: PyRandom) -> void:`
- L102: `static func market_of(code: String) -> String:`
- L111: `static func centre(m: String) -> Array:`
- L118: `static func good_of(job: Jobs.Job) -> String:`
- L127: `static func job_market(job: Jobs.Job) -> String:`
- L132: `func fuel_mult() -> float:`
- L143: `func mult(good: String, m: String) -> float:`
- L165: `func wholesale(good: String) -> float:`
- L170: `func restock_mult(good: String) -> float:`
- L174: `func attach_market(m: Market) -> void:`
- L179: `func job_mult(job: Jobs.Job) -> float:`
- L184: `func record_delivery(good: String, m: String) -> void:`
- L189: `func record_seizure(good: String, m: String) -> void:`
- L198: `func update(dt: float, now: float, police: Array, rivals: Array, turf: Dictionary, ground = null) -> void:`
- L233: `func board() -> Dictionary:`

### `scripts/sim/events.gd`

- L17: `func _init(kind_: String, t_: float, data_: Dictionary, audience_: Array, text_: String) -> void:`
- L30: `func subscribe(kind: String, fn: Callable) -> void:`
- L36: `func emit(kind: String, t: float, text := "", audience := ["runner", "law"], data := {}) -> Event:`
- L46: `func since(t: float, side = null) -> Array:`

### `scripts/sim/family.gd`

- L108: `func _init(sess_, rng_: PyRandom) -> void:`
- L114: `func active() -> bool:`
- L120: `func honesty() -> float:`
- L125: `func _can_offer(kind: String) -> bool:`
- L143: `func offer(kind := ""):`
- L185: `func get_offer(id: String):`
- L190: `func accept(id: String) -> String:`
- L273: `func probe(id: String) -> String:`
- L290: `func stall() -> String:`
- L302: `func decline(id: String) -> String:`
- L312: `func _did(text: String) -> void:`
- L317: `func _con(text: String) -> void:`
- L327: `func lawyer_bust(how: String) -> bool:`
- L352: `func seize_factor() -> float:`
- L359: `func raid_escape() -> float:`
- L363: `func pay_tribute() -> String:`
- L379: `func rico_case() -> String:`
- L391: `func _check_trial() -> void:`
- L414: `func _flip() -> void:`
- L421: `func update(dt: float) -> void:`
- L495: `func ai_wants(o: Dictionary) -> bool:`
- L515: `func _collect() -> void:`
- L539: `func _torch() -> void:`
- L551: `func _break_something() -> String:`
- L568: `func _business() -> void:`
- L592: `func _rat_tip() -> void:`
- L602: `func view(side: String) -> Dictionary:`

### `scripts/sim/fdm.gd`

- L29: `static func make(d := {}) -> Controls:`
- L35: `func copy() -> Controls:`
- L88: `func _init(spec_: Aircraft.Spec, root: String, mass_: MassData) -> void:`
- L104: `func has(prop: String) -> bool:`
- L108: `func apply_loadout(lo: Loadout) -> void:`
- L118: `func spawn(x: float, y: float, heading_deg: float, terrain_m: float, loadout: Loadout,`
- L131: `func start_engines() -> void:`
- L138: `func _controls() -> Dictionary:`
- L162: `func step(frame_dt: float, terrain_at: Callable) -> FlightState:`
- L188: `func position_xy() -> Array:`
- L192: `func wow_count() -> int:`
- L196: `func fuel_lb() -> float:`
- L200: `func fuel_flow_pph() -> float:`
- L208: `func add_fuel(lb: float) -> float:`
- L223: `func wing_fuel_room() -> float:`
- L230: `func state() -> FlightState:`

### `scripts/sim/flight/fdm_func.gd`

- L21: `static func compile(n: MassData.XNode) -> Array:`
- L49: `static func eval(e: Array, p: Dictionary) -> float:`
- L83: `static func table(n: MassData.XNode) -> Dictionary:`
- L108: `static func _grid(text: String) -> Dictionary:`
- L134: `static func _seg(bps: PackedFloat64Array, x: float) -> Array:`
- L151: `static func _grid_at(g: Dictionary, x: float, y: float) -> float:`
- L177: `static func lookup(t: Dictionary, p: Dictionary) -> float:`
- L196: `static func named_table(root: MassData.XNode, name: String) -> Dictionary:`
- L204: `static func at(t: Dictionary, x: float, y := 0.0) -> float:`

### `scripts/sim/flight/flight_dynamics.gd`

- L74: `func _init() -> void:`
- L79: `func load_model(data_root: String, name: String) -> bool:`
- L131: `static func _steer(c: MassData.XNode) -> float:`
- L136: `static func _txt(n: MassData.XNode, tag: String, default := "") -> String:`
- L141: `static func _f(n: MassData.XNode, tag: String, default := 0.0) -> float:`
- L150: `static func _num(n: MassData.XNode, want: String) -> float:`
- L161: `static func _loc(n: MassData.XNode) -> Vector3:`
- L174: `func _body(loc: Vector3) -> Vector3:`
- L178: `func _load_aero(a: MassData.XNode) -> void:`
- L190: `func _engine_file(data_root: String, dir: String, name: String) -> MassData.XNode:`
- L198: `func _load_engines(tree: MassData.XNode, data_root: String, dir: String) -> void:`
- L237: `static func _default_out(name: String) -> String:`
- L241: `func _load_fcs(root: MassData.XNode) -> void:`
- L279: `func _in(name: String) -> float:`
- L285: `func _run_fcs(step: float) -> void:`
- L327: `func set_state(n_ft: float, e_ft: float, h_ft: float, psi: float, theta: float, phi: float, u_fps: float) -> void:`
- L342: `static func _euler_to_quat(phi: float, theta: float, psi: float) -> Quaternion:`
- L352: `func euler() -> Vector3:  ## (phi, theta, psi) rad`
- L360: `func v_ned() -> Vector3:`
- L365: `func _update_mass() -> void:`
- L387: `static func _point(r: Vector3, m: float) -> Basis:`
- L393: `static func _shift(i0: Basis, r: Vector3, m: float) -> Basis:`
- L397: `static func _add(a: Basis, b: Basis) -> Basis:`
- L401: `func fuel_total() -> float:`
- L409: `func _atmosphere(alt_ft: float) -> Array:  ## [rho slug/ft3, P psf, a fps, T R]`
- L416: `func run(controls: Dictionary) -> void:`
- L523: `func _axis(name: String) -> float:`
- L531: `func _propulsion(u_air: float, atm: Array) -> void:`
- L580: `func _burn(lb: float) -> void:`
- L588: `func _gear(rb: Basis, rt: Basis) -> Array:`
- L630: `func wow_count() -> int:`
- L641: `func set_property(path: String, v: float) -> void:`
- L666: `func get_property(path: String) -> float:`
- L684: `func has_property(path: String) -> bool:`

### `scripts/sim/foot_combat.gd`

- L60: `func _init(sess_, rng_: PyRandom) -> void:`
- L65: `func enter(x_: float, y_: float) -> void:`
- L75: `func leave() -> void:`
- L89: `func weight() -> float:`
- L99: `func speed_factor() -> float:`
- L105: `func pack_add(item: String, n := 1) -> String:`
- L129: `func pack_drop(item: String, n := 1) -> String:`
- L145: `func use_medkit() -> String:`
- L155: `func move(x_: float, y_: float, moving_ := false) -> void:`
- L161: `func armoury():`
- L168: `func draw(t: String) -> String:`
- L202: `func holster() -> void:`
- L212: `func reload() -> bool:`
- L222: `func fire() -> bool:`
- L231: `func hit(squad_id: String, dist: float) -> String:`
- L278: `func hostile(q) -> bool:`
- L292: `func live_squads() -> Array:`
- L298: `func update(dt: float) -> void:`
- L357: `func _down(how: String) -> void:`
- L377: `func dict() -> Dictionary:`

### `scripts/sim/fuel.gd`

- L31: `static func price(sess, kind := "ground") -> float:`
- L37: `static func trend(sess) -> float:`
- L42: `static func pay(sess, o: String, amount: float) -> void:`
- L54: `static func truck(sess, t, km: float) -> String:`
- L89: `static func pilot_ready(sess, o: String, w: Dictionary, delay: Array) -> bool:`
- L104: `static func boat(sess, km: float) -> float:`

### `scripts/sim/ground.gd`

- L116: `func pos() -> Vector2:`
- L120: `func rank() -> int:`
- L129: `func rank_name() -> String:`
- L133: `func vet() -> float:`
- L137: `func men_at() -> Array:`
- L140: `func speed() -> float:`
- L144: `func dict() -> Dictionary:`
- L204: `func _init(sess_, rng_: PyRandom, frng_: PyRandom) -> void:`
- L233: `func hq(f: String) -> Vector2:`
- L239: `func arsenal(f: String):`
- L244: `func get_squad(id: String):`
- L251: `func of(f: String) -> Array:`
- L255: `func territory_at(position: Vector2) -> Dictionary:`
- L259: `func territory_key_at(position: Vector2) -> String:`
- L264: `func territory_share(id: String, faction: String) -> float:`
- L273: `func seed_territories_from_markets() -> void:`
- L288: `func _territories_by_market() -> Dictionary:`
- L298: `func adjust_territories(market: String, faction: String, multiplier: float) -> void:`
- L307: `func decision_odds(a: Squad, b: Squad) -> float:`
- L321: `static func market_at(x: float, y: float) -> String:`
- L344: `func cover(q: Squad) -> float:`
- L360: `static func eff(d: float, r: float) -> float:`
- L371: `static func best_range(q: Squad) -> float:`
- L380: `static func want_m(q: Squad) -> float:`
- L387: `func fire_at(q: Squad, enemy: Squad) -> float:`
- L411: `func safe_zone(q: Squad) -> bool:`
- L416: `func fire(q: Squad) -> float:`
- L424: `func strength(q: Squad) -> float:`
- L429: `func odds(a: Squad, b: Squad) -> float:`
- L435: `func can_see(viewer: String, q: Squad) -> bool:`
- L450: `func visible_to(viewer: String) -> Array:`
- L454: `func _say(side: String, text: String) -> void:`
- L461: `func recruit(f: String, kind: String, at = null, pay := true):`
- L512: `func disband(q: Squad) -> void:`
- L524: `func route(f: String, a: Vector2, b: Vector2) -> PackedVector2Array:`
- L530: `func route_cost(f: String, path: PackedVector2Array) -> float:`
- L543: `func _penalty(f: String) -> Callable:`
- L563: `func go(q: Squad, to: Vector2) -> void:`
- L574: `func order(q: Squad, o: Dictionary) -> String:`
- L606: `func field_order(f: String, at: Vector2, what: String) -> Array:`
- L648: `func _target_xy(o: Dictionary):`
- L675: `func _beat(m: String) -> Vector2:`
- L687: `func _territory_beat(id: String) -> Vector2:`
- L700: `func _nearest_cover(from: Vector2) -> Vector2:`
- L721: `func update(dt: float) -> void:`
- L759: `func _deploy() -> void:`
- L767: `func _move(dt: float) -> void:`
- L807: `func _sync_members() -> void:`
- L847: `func _close_in(dt: float) -> void:`
- L867: `func _arrived(q: Squad) -> void:`
- L877: `func _hostile(a: Squad, b: Squad) -> bool:`
- L886: `func _truce() -> bool:`
- L894: `func _contacts() -> void:`
- L929: `func _will_fight(perp: Squad, cop: Squad) -> bool:`
- L937: `func _surrender(perp: Squad, cop: Squad) -> void:`
- L943: `func _open(a: Squad, b: Squad) -> void:`
- L972: `func place_name(x: float, y: float) -> String:`
- L984: `func _rounds(step: float) -> void:`
- L1026: `func _losses(shooter: Squad, target: Squad, f: Fight) -> int:`
- L1046: `func _drop_weapons(q: Squad, lost: int, enemy: Squad) -> void:`
- L1067: `func _break_off(q: Squad, f: Fight, why: String) -> void:`
- L1085: `func _learn(q: Squad, points: float) -> void:`
- L1098: `func _rout(q: Squad, f: Fight) -> void:`
- L1145: `func _arrest(q: Squad, cop: Squad, n: int) -> void:`
- L1168: `func _gone(q: Squad) -> void:`
- L1179: `func _end(f: Fight) -> void:`
- L1191: `func _breach(q: Squad) -> void:`
- L1216: `func truck_contacts() -> Array:`
- L1282: `func _patrol_stops(q: Squad, t) -> bool:`
- L1294: `func _should_tail(q: Squad, t) -> bool:`
- L1299: `func _trucks(dt: float) -> void:`
- L1357: `func _informants(dt: float) -> void:`
- L1374: `func _control(dt: float) -> void:`
- L1391: `func rival_share(m: String) -> float:`
- L1397: `func org_share(m: String) -> float:`
- L1404: `func turf(base: Dictionary) -> Dictionary:`
- L1415: `func turf_delta(zone: String) -> float:`
- L1423: `func _upkeep(dt: float) -> void:`
- L1440: `func positions(f: String) -> Array:`
- L1445: `func _free(f: String) -> Array:`
- L1452: `func _think_org() -> void:`
- L1525: `func _think_rival() -> void:`
- L1564: `func _think_police() -> void:`
- L1629: `func _recruit_ai(f: String, rich: bool, kind := "") -> void:`
- L1656: `func _contested(f: String) -> String:`
- L1671: `func _contested_territory(f: String, from: Vector2) -> Dictionary:`
- L1692: `func _patrol_order(f: String, from: Vector2) -> Dictionary:`
- L1700: `func _pick(arr: Array, score: Callable):`
- L1711: `func _log(f: String, text: String) -> void:`
- L1721: `func snapshot(viewer: String) -> Dictionary:`

### `scripts/sim/hq.gd`

- L149: `func capacity() -> int:`
- L155: `func payout_mult() -> float:`
- L158: `func to_dict() -> Dictionary:`
- L193: `func band() -> String:`
- L196: `func to_dict() -> Dictionary:`
- L203: `func reputation() -> String:`
- L234: `func to_dict() -> Dictionary:`
- L255: `func _init(kind_: String, zone_: String, opts := {}) -> void:`
- L269: `func _init(night_: int, runs_: Array) -> void:`
- L299: `func _init(rng_: PyRandom = null, rules_ := {}) -> void:`
- L321: `func on(rule: String) -> bool:`
- L325: `func moon(n := -1) -> float:`
- L329: `func _draw_weather() -> Dictionary:`
- L342: `func pattern_exposure() -> Dictionary:`
- L351: `func leak_zone():`
- L355: `func _begin_planning() -> void:`
- L403: `func runner_cmd(name: String, a := {}):`
- L416: `func law_cmd(name: String, a := {}):`
- L431: `func _r_launder(a: Dictionary):`
- L447: `func _r_buy_front(a: Dictionary):`
- L461: `func _r_bribe(a: Dictionary):`
- L473: `func _r_drop_bribe(a: Dictionary):`
- L477: `func _r_loyalty(a: Dictionary):`
- L485: `func _r_lawyer(a: Dictionary):`
- L489: `func _r_opsec(a: Dictionary):`
- L497: `func _r_counterintel(a: Dictionary):`
- L505: `func _r_crews(a: Dictionary):`
- L515: `func _r_decoys(a: Dictionary):`
- L525: `func _r_route(a: Dictionary):`
- L532: `func _r_lie_low(a: Dictionary):`
- L536: `func _r_upgrade(a: Dictionary):`
- L549: `func _r_gear(a: Dictionary):`
- L560: `func _r_ready(a: Dictionary):`
- L567: `func _r_hit_rival(a: Dictionary):`
- L589: `func _r_truce(a: Dictionary):`
- L613: `func _r_tip_off(a: Dictionary):`
- L628: `func _spend(k: float):`
- L634: `func _l_fund(a: Dictionary):`
- L648: `func _l_patrol(a: Dictionary):`
- L657: `func _l_aerostat(a: Dictionary):`
- L663: `func _l_recruit(a: Dictionary):`
- L679: `func _l_wiretap(a: Dictionary):`
- L687: `func _l_audit(a: Dictionary):`
- L693: `func _l_ia_sweep(a: Dictionary):`
- L699: `func _l_encryption(a: Dictionary):`
- L707: `func _l_press(a: Dictionary):`
- L720: `func _l_gang_unit(a: Dictionary):`
- L733: `func _l_canary(a: Dictionary):`
- L749: `func _l_ready(a: Dictionary):`
- L755: `func start_operation() -> Dictionary:`
- L804: `func _plan_rival() -> void:`
- L860: `func informant_tip() -> bool:`
- L871: `func finish_night(runs: Array, live := false) -> NightReport:`
- L1014: `func _rival_run(r: RunResult, rep: NightReport) -> void:`
- L1035: `func _rival_drift(takings: int, rep: NightReport) -> void:`
- L1050: `func snapshot_numbers() -> Dictionary:`
- L1057: `func runner_progress() -> float:`
- L1060: `func law_progress() -> float:`
- L1063: `func _check_end() -> void:`
- L1092: `func _end(who: String, why: String) -> void:`
- L1097: `func next_night() -> void:`
- L1105: `func view(side: String) -> Dictionary:`
- L1161: `static func from_dict(d: Dictionary) -> Calibration:`
- L1167: `func to_dict() -> Dictionary:`
- L1174: `static func resolve_abstract(season: Season, plan: Dictionary, rng: PyRandom, cal: Calibration = null) -> Array:`
- L1271: `static func _resolve_rivals(season: Season, plan: Dictionary, runs: Array, cal: Calibration) -> void:`

### `scripts/sim/island.gd`

- L81: `func _init(sess_, rng_: PyRandom) -> void:`
- L89: `static func airfield() -> Airfield:`
- L99: `static func height(x: float, y: float) -> float:`
- L115: `static func in_airspace(x: float, y: float) -> bool:`
- L119: `func open() -> bool:`
- L123: `func runner_has(id: String) -> bool:`
- L127: `func law_has(id: String) -> bool:`
- L133: `func mule_odds() -> Array:`
- L153: `func ship_odds() -> Array:`
- L184: `func ship(method: String, amount: int) -> String:`
- L230: `func _resolve(sh: Dictionary) -> void:`
- L302: `func _land(lb: float, near: Vector2) -> String:`
- L314: `func buy_passage() -> String:`
- L328: `func passage_cost() -> int:`
- L332: `func has_passage() -> bool:`
- L337: `func on_arrive() -> void:`
- L353: `func sovereign(y: float) -> bool:`
- L359: `func board(af: Airfield) -> Array:`
- L389: `func defected(job) -> void:`
- L396: `func purge() -> void:`
- L407: `func _event() -> void:`
- L445: `func _rival_trade() -> void:`
- L470: `func _patrol(step: float) -> void:`
- L490: `func update(dt: float) -> void:`
- L523: `func view(side: String) -> Dictionary:`

### `scripts/sim/jobs.gd`

- L26: `static func new_id() -> int:`
- L58: `func _init(id_: int, title_: String, kind_: String, origin_: String, dest_: String, items_: Array, payout_: int, opts := {}) -> void:`
- L69: `func is_airdrop() -> bool:`
- L72: `func target_xy() -> Array:`
- L78: `func dest_label() -> String:`
- L81: `func hot() -> bool:`
- L87: `func weight_lb() -> float:`
- L93: `func time_left(now: float):`
- L99: `static func item(label: String, kind: String, kg: float, job_id: int, opts := {}) -> Loadout.Item:`
- L103: `static func _dist_km(a: Airfield, b: Airfield) -> float:`
- L108: `static func _difficulty(dest: Airfield) -> float:`
- L119: `static func airdrop_job(origin: Airfield, drop_point: Array, rng: PyRandom, bales := 0) -> Job:`
- L133: `static func generate(origin: Airfield, airfields: Array, rng: PyRandom, n := 6, features = null, drop_point_fn = null) -> Array:`

### `scripts/sim/layers.gd`

- L33: `static func features_for(level: int) -> Dictionary:`
- L45: `func _init(r: String, h: bool) -> void:`
- L49: `func _to_string() -> String:`
- L60: `func _init(p: int, m: String, l: int) -> void:`
- L65: `func features() -> Dictionary:`
- L68: `func humans(side: String) -> Array:`
- L75: `func describe() -> String:`
- L85: `static func plan_match(players: int, versus := true, layer := 0) -> MatchPlan:`

### `scripts/sim/loadout.gd`

- L25: `func _init(id_: int, label_: String, kind_: String, weight_lb_: float, job_id_: int, opts := {}) -> void:`
- L34: `func set_fuel(lb: float) -> void:`
- L48: `func ok() -> bool:`
- L52: `static func ferry_tank(item_id: int, capacity_lb: float) -> Item:`
- L57: `static func load_time_s(item: Item) -> float:`
- L61: `static func point_in_polygon(x: float, y: float, poly: Array) -> bool:`
- L77: `static func cg_limits_at(weight: float, poly: Array) -> Array:`
- L101: `func _init(spec_: Aircraft.Spec, mass_: MassData, fuel_lb_: float, copilot_aboard_ := false) -> void:`
- L109: `func station_weights(planned := false) -> Array:`
- L124: `func copilot_station() -> int:`
- L132: `func ferry_capacity() -> float:`
- L140: `func ferry_tanks() -> Array:`
- L148: `func ferry_fuel_lb() -> float:`
- L155: `func queue_move(item: Item) -> void:`
- L160: `func work(dt: float, crew: int) -> Array:`
- L171: `func tank_fuel() -> Array:`
- L180: `func compute(fuel_override = null, planned := true) -> WBResult:`
- L210: `func add(item: Item) -> void:`
- L214: `func remove_job(job_id: int) -> Array:`
- L224: `func remove_item(item_id: int) -> Item:`
- L232: `func unassigned() -> Array:`
- L240: `func valid_stations(item: Item) -> Array:`
- L248: `func seat_taken(st_idx: int, except_item := -1) -> bool:`
- L257: `func can_place(item: Item, st_idx: int) -> bool:`
- L271: `func cycle(item: Item, direction := 1) -> void:`
- L287: `func all_loaded() -> bool:`
- L292: `func busy() -> bool:`
- L299: `func auto_balance() -> bool:`
- L329: `func requeue_changed(before: Dictionary) -> void:`

### `scripts/sim/logistics.gd`

- L54: `func _init(sess_) -> void:`
- L67: `func hq_pos() -> Vector2:`
- L73: `func hq_strip() -> String:`
- L87: `func nearest_stash(p: Vector2) -> String:`
- L94: `func pos(site: String) -> Vector2:`
- L110: `func meet_pos(to: String, from: String) -> Vector2:`
- L126: `func name_of(site: String) -> String:`
- L135: `func market_of(site: String) -> String:`
- L143: `func site_at(code: String) -> String:`
- L151: `func total(g: String) -> float:`
- L159: `func cash_out() -> float:`
- L168: `func sync() -> void:`
- L173: `func add(site: String, g: String, lb: float) -> void:`
- L181: `func in_market(g: String, m: String) -> float:`
- L191: `func take_market(g: String, m: String, lb: float) -> Array:`
- L206: `func add_cash(site: String, amount: float) -> void:`
- L220: `func checkpoint_on(a: Vector2, b: Vector2) -> String:`
- L236: `func send(from: String, to: String, what: String, amount: float, careful := false) -> String:`
- L298: `func _undo(c: Dictionary) -> void:`
- L311: `func _describe(c: Dictionary) -> String:`
- L323: `func _value(c: Dictionary) -> int:`
- L336: `func plan_order(stops: Array, end: Vector2) -> Array:`
- L358: `func _check_stops(stops: Array) -> String:`
- L377: `func cash_round(stops: Array, to: String, careful := false) -> String:`
- L414: `func goods() -> Array:`
- L419: `func ensure_acid() -> void:`
- L426: `func price_of(g: String) -> float:`
- L434: `func goods_round(from: String, stops: Array, good: String, lb_each: float, careful := false) -> String:`
- L477: `func _unique(a: Array) -> Array:`
- L487: `func _dispatch_multi(c: Dictionary, points: Array) -> void:`
- L535: `func _stop_reached(t, site: String) -> void:`
- L561: `func armoury_site() -> String:`
- L568: `func send_guns(to: String, weapons: Dictionary, careful := false) -> String:`
- L619: `func _dispatch(c: Dictionary, a: Vector2, b: Vector2) -> void:`
- L660: `func _pull_over(dt: float) -> void:`
- L693: `func _near_route(r: PackedVector2Array, p: Vector2) -> bool:`
- L702: `func truck_info(t) -> Dictionary:`
- L716: `func route_risk(t) -> float:`
- L723: `func owns(t) -> bool:`
- L728: `func arrived(t, outcome: String, why: String) -> void:`
- L793: `func _settle(c: Dictionary) -> void:`
- L826: `func _spirit_away(site: String, saved: Dictionary, saved_cash: float) -> void:`
- L848: `func _raided(site: String) -> void:`
- L885: `func load_cash(amount: float) -> String:`
- L908: `func unload_cash() -> String:`
- L924: `func pay_seller(cost: int) -> String:`
- L934: `func seize_aboard() -> void:`
- L945: `func _bags() -> void:`
- L961: `func update(dt: float) -> void:`
- L1028: `func _refresh_routes() -> void:`
- L1051: `func view() -> Dictionary:`

### `scripts/sim/map_city.gd`

- L69: `static func load_roads() -> Dictionary:`
- L77: `static func base_terrain() -> Terrain:`
- L100: `static func _params() -> Dictionary:`
- L117: `static func _strip_specs() -> Array:`
- L140: `static func generate() -> MapLayout:`
- L209: `static func _xy(i: int, j: int) -> Vector2:`
- L213: `static func _ell(p: Vector2, c: Vector2, r: Vector2) -> float:`
- L219: `static func _hash(ix: int, iy: int) -> float:`
- L226: `static func _vn(x: float, y: float, s: float) -> float:`
- L242: `static func noise(x: float, y: float) -> float:`
- L262: `static func field_shade(x: float, y: float) -> float:`
- L267: `static func _eln(p: Vector2, c: Vector2, r: Vector2, amt := 0.3) -> float:`
- L278: `static func river_course() -> PackedVector2Array:`
- L306: `static func _river_field() -> void:`
- L337: `static func _river(p: Vector2) -> Array:`
- L353: `static func _free(p: Vector2, fields: Array) -> float:`
- L370: `static func _shape(h: PackedFloat32Array, fields: Array) -> void:`
- L417: `static func classify(h: PackedFloat32Array, fields: Array) -> PackedByteArray:`
- L459: `static func at(lu: PackedByteArray, x: float, y: float) -> int:`
- L466: `static func road_dist(roads: Array, x: float, y: float) -> float:`
- L485: `func _init(roads: Array, reach: float) -> void:`
- L500: `func dist(p: Vector2) -> float:`
- L517: `static func road_mask(roads: Array) -> PackedByteArray:`
- L537: `static func on_road(mask: PackedByteArray, x: float, y: float) -> bool:`
- L547: `static func post(t: Terrain, l: MapLayout) -> void:`
- L573: `static func _plant(t: Terrain, native: PackedFloat32Array, l: MapLayout) -> PackedFloat32Array:`
- L619: `static func _city(t: Terrain, l: MapLayout) -> Array:`
- L697: `static func site_hqs(w: World, l: MapLayout) -> Dictionary:`

### `scripts/sim/map_gen.gd`

- L30: `static func _clear_approach(t: Terrain, x: float, y: float, ux: float, uy: float, length: float, elev: float) -> bool:`
- L46: `static func _rate(t: Terrain, x: float, y: float, length: float, width: float, setting: String, min_elev: float,`
- L77: `static func _polar(cx: float, cy: float, ang_deg: float, r: float) -> Array:`
- L82: `static func _site(t: Terrain, rng: PyRandom, placed: Array, centre: Array, sector: Array, radius: Array,`
- L98: `static func _params(rng: PyRandom) -> Dictionary:`
- L128: `static func generate(map_seed: int) -> MapLayout:`
- L203: `static func _pad(w: World, near: Array, r_min: float, r_max: float, elev_min := 4.0, avoid: Array = []) -> Array:`
- L231: `static func site_hqs(w: World, l: MapLayout) -> Dictionary:`

### `scripts/sim/map_layout.gd`

- L31: `static func classic() -> MapLayout:`
- L51: `func airfield(code: String) -> Airfield:`
- L58: `func describe() -> String:`

### `scripts/sim/maritime.gd`

- L22: `static func is_sea(world: World, x: float, y: float, depth := -1.5) -> bool:`
- L27: `static func cove_point(world: World) -> Array:`
- L40: `static func random_drop_point(world: World, rng: PyRandom, near = null) -> Array:`
- L76: `func update(dt: float, world: World) -> String:`
- L125: `func _init(id_: String, kind_: String, x_: float, y_: float, opts := {}) -> void:`
- L133: `func side() -> String:`
- L136: `func max_speed() -> float:`
- L140: `func steer(dt: float, world: World, goal_: Array, speed_frac := 1.0) -> float:`
- L196: `func _init(world_: World, rng_: PyRandom = null) -> void:`
- L213: `func new_gofast(rendezvous: Array, job_id: int) -> Boat:`
- L222: `func new_cutter(goal = null, at = null) -> Boat:`
- L233: `func drop_bale(job_id: int, x: float, y: float, z: float, vx: float, vy: float, vz: float, weight_lb: float) -> Bale:`
- L249: `func boat(boat_id) -> Boat:`
- L253: `func gofast_for(job_id: int) -> Boat:`
- L258: `func update(dt: float, law_goals: Array = []) -> void:`
- L276: `func _gofast(b: Boat, dt: float, floating: Array) -> void:`
- L328: `func _deliver(b: Boat) -> void:`
- L333: `func _cutter(c: Boat, dt: float, floating: Array, law_goals: Array) -> void:`

### `scripts/sim/market.gd`

- L69: `func _init(rng_: PyRandom) -> void:`
- L85: `func factor(g: String, m: String) -> float:`
- L92: `func wholesale(g: String) -> float:`
- L97: `func restock_mult(g: String) -> float:`
- L102: `func _markets(m: String) -> Array:`
- L106: `func _goods(g: String) -> Array:`
- L111: `func flow(g: String, m: String, amount: float, reason := "") -> void:`
- L121: `func disrupt(m: String, amount: float, reason := "", headline := "") -> void:`
- L133: `func source_shock(g: String, amount: float, headline := "") -> void:`
- L141: `func demand_shock(g: String, m: String, mult: float, minutes: float, headline := "") -> void:`
- L147: `func _headline(key: String, text: String) -> void:`
- L157: `func update(step: float, now: float, ground) -> void:`
- L186: `func _fighting(ground, step: float) -> void:`
- L210: `static func _name(m: String) -> String:`
- L216: `func hook(sess) -> void:`
- L260: `func _island_status(e) -> void:`
- L272: `func _org_markets(sess) -> Array:`
- L281: `func _rival_market(sess) -> String:`
- L293: `func _org_hit(sess, dis: float, cut: float, reason: String, headline: String) -> void:`
- L301: `func _rival_hit(sess, dis: float, cut: float, reason: String, headline: String) -> void:`
- L309: `func _stash_flow(sess, e, g: String, amount: float, reason: String) -> void:`
- L315: `func view() -> Dictionary:`

### `scripts/sim/mass_data.gd`

- L19: `func fuel_capacity_lb() -> float:`
- L33: `func find(t: String) -> XNode:`
- L39: `func find_where(t: String, attr: String, value: String) -> XNode:`
- L45: `func iter(t: String, out: Array[XNode] = []) -> Array[XNode]:`
- L52: `func attr(k: String, default := "") -> String:`
- L56: `static func parse_xml(path: String) -> XNode:`
- L84: `static func _loc_in(el: XNode, axis: String) -> float:`
- L89: `static func read(model: String, root := DATA_ROOT) -> MassData:`
- L118: `static func patched_root() -> String:`

### `scripts/sim/nights.gd`

- L16: `static func zone_of(job: Jobs.Job) -> String:`
- L39: `func _init(sess_, runner_ai_ = "adaptive", law_ai_ = "adaptive", rules := {}) -> void:`
- L56: `func _pull() -> void:`
- L68: `func _push() -> void:`
- L76: `func order(side: String, name: String, args := {}):`
- L87: `func _run_ai() -> void:`
- L98: `func tick(dt: float) -> void:`
- L119: `func _begin() -> void:`
- L190: `func _spawn_run(decoy: bool) -> AISmuggler:`
- L204: `func _track() -> void:`
- L212: `func _close_main() -> void:`
- L225: `func _finish() -> void:`
- L277: `func _show_forecast() -> void:`
- L286: `func view(side: String) -> Dictionary:`

### `scripts/sim/payroll.gd`

- L82: `func _init(sess_, rng_: PyRandom) -> void:`
- L90: `func has_outfit(o: String) -> bool:`
- L94: `func cash(o: String) -> float:`
- L98: `func spend(o: String, k: float) -> void:`
- L105: `func earn(o: String, k: float) -> void:`
- L109: `func say(o: String, text: String) -> void:`
- L116: `func _person(o: String, role: String, street := false) -> Dictionary:`
- L131: `func _refresh(o: String) -> void:`
- L139: `func hire(o: String, id: String) -> String:`
- L157: `func fire(o: String, id: String) -> String:`
- L170: `func get_worker(id: String):`
- L174: `func of(o: String, role := "", status := "") -> Array:`
- L178: `func wage_bill(o: String) -> int:`
- L186: `func loyalty(o: String) -> float:`
- L194: `func bonus(o: String) -> String:`
- L211: `func take(o: String, role: String, n: int, job: String, street := true) -> Array:`
- L236: `func release(ids: Array) -> void:`
- L249: `func mean_skill(ids: Array) -> float:`
- L257: `func lose(id: String, how: String, where := "") -> void:`
- L277: `func enlist(o: String, men: int, squad_id: String) -> String:`
- L286: `func _reconcile_squads() -> void:`
- L306: `func driver_for(job_id: String) -> Array:`
- L315: `func mules_for(o: String, n: int, run_id: String) -> Array:`
- L320: `func lookout_warns(stash_id: String) -> bool:`
- L329: `func post_lookout(id: String, stash_id: String) -> String:`
- L342: `func _payday() -> void:`
- L366: `func _accountant(o: String) -> void:`
- L379: `func _disloyal(o: String, w: Dictionary) -> void:`
- L394: `func _tip(o: String, w: Dictionary, who: String) -> void:`
- L407: `func _rival_hit(weight: float, why: String) -> void:`
- L422: `func pay_lawyer(o: String, id: String) -> String:`
- L443: `func offer_deal(id := "") -> String:`
- L457: `func flip_chance(j: Dictionary) -> float:`
- L464: `func _trials() -> void:`
- L490: `func _pilot_runs() -> void:`
- L519: `func needs(o: String) -> Dictionary:`
- L540: `func _think(o: String) -> void:`
- L577: `func update(dt: float) -> void:`
- L606: `func doing(w: Dictionary) -> String:`
- L638: `func view(side: String) -> Dictionary:`

### `scripts/sim/people.gd`

- L23: `func _init(sess_) -> void:`
- L28: `func post_of(w: Dictionary) -> Variant:`
- L49: `func _hq(o: String) -> Vector2:`
- L56: `func _base(o: String) -> Vector2:`
- L61: `func _street(p: Vector2) -> Vector2:`
- L71: `func _spot(p: Vector2, w: Dictionary, gap: float) -> Vector2:`
- L86: `func update(dt: float) -> void:`
- L119: `func _send(body: Agent, at: Vector2, graph: RoadGraph) -> void:`
- L130: `func left_m(id: String) -> float:`
- L136: `func draw_list() -> Array:`

### `scripts/sim/police.gd`

- L43: `static func _z(obj) -> float:`
- L72: `func _init(kind_: String, x_: float, y_: float, z_: float, heading_: float, home_: Array, opts := {}) -> void:`
- L82: `func spec() -> Array:`
- L85: `func faction() -> String:`
- L88: `func dist_to(s) -> float:`
- L93: `func update(dt: float, target, world: World, goal_ = null) -> void:`
- L160: `func _fly_manual(dt: float, world: World) -> void:`
- L210: `func _init(sig_: SensorNet.Signature, hot_ := false, value_ := 0, label_ := "") -> void:`
- L236: `func _init(tid: String, opts := {}) -> void:`
- L250: `func _init(t_: float, x_: float, y_: float, radius_: float, text_: String, squawk_ := "") -> void:`
- L299: `func _init(world_: World, rng_: PyRandom = null, radio_: RadioNet = null, controller_ := "ai", features_ = null) -> void:`
- L320: `func alias(target_id):`
- L330: `func resolve(name):`
- L337: `func case(tid := "runner") -> Case:`
- L369: `func painters(tid := "runner") -> Array:`
- L374: `func detector(tid := "runner") -> String:`
- L379: `func reset(keep_wanted := false, tid := "runner") -> void:`
- L397: `func _say(sender: String, text: String, pos = null) -> void:`
- L408: `func police_bases() -> Array:`
- L413: `func launch(kind: String, base_code = null, target_id = null, goal = null, near = null, flank := false):`
- L437: `func _spawn_now(kind: String, base_code: String, target_id, goal, flank := false) -> Pursuer:`
- L461: `func patrol_spares(zones: Array, reserve := 1) -> Array:`
- L475: `func spawn_rival(near: Array, target_id: String) -> Pursuer:`
- L486: `func dispatch(unit_id: String, target_id = null, point = null):`
- L497: `func recall(unit_id: String):`
- L508: `func set_encryption(on: bool):`
- L516: `func set_aerostat(on: bool):`
- L531: `func add_tip(x: float, y: float, radius: float, text: String, squawk := "", target_id = null, truth := true) -> void:`
- L541: `func release_tip(x: float, y: float, radius: float, text: String, squawk := "", target_id = null) -> void:`
- L553: `func _ai_escalate(c: Case, level: int, sig: SensorNet.Signature) -> void:`
- L606: `func predict_destination(sig: SensorNet.Signature, origin = null):`
- L638: `func tick(dt: float, now_: float, targets: Array) -> Dictionary:`
- L809: `static func _append(d: Dictionary, k: String, v) -> void:`
- L815: `func _close_case(tid: String, hot: bool) -> void:`
- L829: `func _can_see(u: Pursuer, sig: SensorNet.Signature) -> bool:`
- L837: `func _classify(t: Target, dt: float) -> void:`
- L922: `func _squawk_code(c: Case, sig: SensorNet.Signature) -> void:`
- L947: `func _inbound_from_sea(sig: SensorNet.Signature) -> bool:`
- L958: `func landing_check(s, field_: Airfield, carrying_hot: bool, tid := "runner") -> bool:`

### `scripts/sim/psychedelics.gd`

- L83: `func _init(s) -> void:`
- L89: `func active() -> bool:`
- L94: `func why_not() -> String:`
- L103: `func mood() -> float:`
- L108: `func rate() -> float:`
- L117: `func price() -> float:`
- L122: `func acid_at(stash: String) -> float:`
- L129: `func held_total() -> float:`
- L139: `func fullest_stash() -> Array:`
- L151: `func _grass_at(stash: String) -> float:`
- L157: `func _take_grass(stash: String, lb: float) -> void:`
- L165: `func barter(stash: String, lb: float) -> String:`
- L203: `func sell(sheets: float, stash := "") -> String:`
- L236: `func set_auto(on: bool) -> String:`
- L243: `func update(dt: float) -> void:`
- L289: `func _raid() -> void:`
- L300: `func _auto() -> void:`
- L321: `func view(_side := "runner") -> Dictionary:`
- L330: `func _stash_acid() -> Array:`
- L342: `func _stash_grass() -> Array:`

### `scripts/sim/races.gd`

- L50: `func dict() -> Dictionary:`
- L64: `func _init(sess_) -> void:`
- L70: `func courses_here() -> Array:`
- L89: `func course(id: String) -> Course:`
- L96: `func _street(af: Airfield) -> Course:`
- L127: `func _loop(here: Vector2, waypoints: Array) -> PackedVector2Array:`
- L141: `static func _along(path: PackedVector2Array, step: float) -> Array:`
- L162: `func _circuit(af: Airfield) -> Course:`
- L188: `func active() -> bool:`
- L193: `func cooldown(id: String) -> float:`
- L200: `func enter(id: String, bet := 0, on := "win") -> String:`
- L224: `func abort(why: String) -> void:`
- L233: `func feed(kind: String, xy: Vector2, alt: float) -> void:`
- L255: `func update(dt: float) -> void:`
- L272: `func hud_line() -> String:`
- L285: `func _clock(t: float) -> String:`
- L290: `func field(c: Course) -> Array:`
- L300: `func _finish(c: Course) -> void:`
- L338: `func view() -> Dictionary:`

### `scripts/sim/rackets.gd`

- L48: `func _init(sess_) -> void:`
- L54: `func update(dt: float) -> void:`
- L71: `func expected(m: String) -> int:`
- L86: `func collect() -> int:`
- L117: `func set_policy(m: String, p: String) -> String:`
- L128: `func capture(loser) -> int:`
- L140: `func ransom() -> String:`
- L160: `func turn() -> String:`
- L175: `func _recruit(p) -> Dictionary:`
- L185: `func release() -> String:`
- L197: `func view() -> Dictionary:`

### `scripts/sim/renown.gd`

- L49: `func _init(sess_) -> void:`
- L60: `func _on_gain(ev) -> void:`
- L65: `func _on_loss(ev) -> void:`
- L71: `func _on_sale(ev) -> void:`
- L77: `func _on_flip(ev) -> void:`
- L83: `func add(points: float, what: String) -> void:`
- L99: `func apply() -> void:`
- L105: `static func tier_of(points: float) -> int:`
- L113: `func tier() -> int:`
- L117: `func title() -> String:`
- L122: `func next_at() -> float:`
- L128: `func price_mult() -> float:`
- L133: `func skill_bonus() -> float:`
- L137: `func loyalty_bonus() -> float:`
- L142: `func heat_mult() -> float:`
- L146: `static func effects_text(t: int) -> String:`
- L152: `func view() -> Dictionary:`

### `scripts/sim/road_graph.gd`

- L22: `func _init(roads: Array, places: Array = []) -> void:`
- L50: `static func tracks(points: Array) -> RoadGraph:`
- L67: `func _node(p: Vector2) -> int:`
- L76: `func _linked(a: int, b: int) -> bool:`
- L83: `func _link(a: int, b: int) -> void:`
- L90: `func stub(p: Vector2) -> int:`
- L100: `func nearest(p: Vector2, roads_only := true) -> int:`
- L115: `func path(a: int, b: int, penalty := Callable()) -> Array:`
- L151: `func route(from: Vector2, to: Vector2, penalty := Callable()) -> PackedVector2Array:`
- L168: `static func seg_distance(a: Vector2, b: Vector2, p: Vector2) -> float:`
- L175: `static func length(pts: PackedVector2Array) -> float:`
- L183: `static func along(pts: PackedVector2Array, dist: float) -> Vector2:`
- L197: `func chokepoint(pts: PackedVector2Array, min_d := 800.0) -> Vector2:`
- L208: `func connected(a: Vector2, b: Vector2) -> bool:`

### `scripts/sim/road_planner.gd`

- L40: `func _init(height: Callable, passable: Callable, half_m := 16000.0) -> void:`
- L55: `func centre(i: int, j: int) -> Vector2:`
- L59: `func cell_of(p: Vector2) -> int:`
- L66: `func snap(p: Vector2) -> int:`
- L88: `func _step_cost(a: int, b: int, run: float) -> float:`
- L107: `func route(start: int, goal := -1) -> PackedInt32Array:`
- L156: `func _push(hk: PackedFloat32Array, hv: PackedInt32Array, k: float, v: int) -> void:`
- L173: `func _pop(hk: PackedFloat32Array, hv: PackedInt32Array) -> Array:`
- L204: `func detour_route(a: int, b: int) -> PackedInt32Array:`
- L249: `func _add_path(path: PackedInt32Array) -> void:`
- L263: `func plan(places: Array, extra := [], rings := []) -> Dictionary:`
- L334: `func _chains() -> Array:`
- L375: `func _smooth(pts: PackedVector2Array) -> Array:`
- L398: `static func measure(road: Array, height: Callable, is_water: Callable, window := 40.0) -> Dictionary:`
- L442: `static func straighten_bridges(road: Array, is_water: Callable, pad := 15.0) -> Array:`
- L508: `static func _at(pts: PackedVector2Array, cum: PackedFloat32Array, dist: float) -> Vector2:`

### `scripts/sim/roles.gd`

- L81: `static func side(role: String) -> String:`
- L85: `static func allowed(role: String, command: String) -> bool:`
- L89: `static func valid(role: String) -> bool:`

### `scripts/sim/save_vars.gd`

- L18: `static func capture(obj: Object, keys: Array) -> Dictionary:`
- L25: `static func restore(obj: Object, d: Dictionary, keys: Array, ints: Array = []) -> void:`
- L43: `static func encode(v: Variant) -> Variant:`
- L62: `static func decode(v: Variant, ints: Array = []) -> Variant:`
- L85: `static func through_json(d: Variant) -> Variant:`

### `scripts/sim/seats.gd`

- L21: `func _init(sess_, local := {}) -> void:`
- L34: `func who(role: String) -> String:`
- L38: `func human(role: String) -> bool:`
- L44: `func open(token := "") -> Array:`
- L49: `func claim(role: String, name: String, token: String) -> String:`
- L72: `func release(role: String, hold := false) -> void:`
- L87: `func held_for(token: String) -> String:`
- L97: `func tick(now: float) -> void:`
- L107: `func roster() -> Array:`

### `scripts/sim/sensors.gd`

- L51: `func _init(id_: String, x_: float, y_: float, z_: float, agl_: float, vx_ := 0.0, vy_ := 0.0, kind_ := "air",`
- L64: `func speed_kts() -> float:`
- L83: `func _init(code_: String, name_: String, x_: float, y_: float, mast_z_: float, range_m_: float, opts := {}) -> void:`
- L93: `func floor_at(dist_m: float) -> float:`
- L97: `func check(world: World, sig: Signature) -> Array:`
- L110: `func beam(t: float) -> float:`
- L114: `static func horizon_drop(d: float) -> float:`
- L118: `func check_real(world: World, sig: Signature, wx: Dictionary, mti_min := MTI_MIN_MS) -> Array:`
- L159: `func age(now: float) -> float:`
- L162: `func predicted(now: float, max_s := 20.0) -> Array:`
- L173: `func detector_level() -> String:`
- L181: `static func default_sites(world: World) -> Array:`
- L202: `func _init(world_: World, rng_: PyRandom = null) -> void:`
- L220: `func add_site(st: RadarSite) -> void:`
- L226: `func site(code: String) -> RadarSite:`
- L233: `func sweep(sigs: Array, now: float) -> Dictionary:`
- L255: `func _sweep_real(sigs: Array, now: float) -> Dictionary:`
- L291: `func report(sig: Signature, now: float, source: String, sigma := 0.0) -> Track:`
- L317: `func add_fix(target_id: String, x: float, y: float, now: float, source: String) -> Track:`
- L340: `func coverage(code: String, agl: float, n := 48) -> PackedByteArray:`
- L359: `func expire(now: float) -> void:`

### `scripts/sim/session.gd`

- L15: `func _init(opts := {}) -> void:`
- L131: `func dispose() -> void:`
- L176: `static func load_or_new(path: String, opts := {}) -> Session:`

### `scripts/sim/session_commands.gd`

- L7: `func command(role: String, name: String, args := {}) -> Array:`
- L25: `static func _num(args: Dictionary, k: String, default = null):`
- L34: `static func _point(args: Dictionary):`
- L40: `func _cmd_accept_job(role: String, a: Dictionary):`
- L45: `func _cmd_drop_job(role: String, a: Dictionary):`
- L53: `func _cmd_move_item(role: String, a: Dictionary):`
- L68: `func _cmd_loadmaster(role: String, a: Dictionary):`
- L72: `func _cmd_set_fuel(role: String, a: Dictionary):`
- L79: `func _cmd_fill_ferry(role: String, a: Dictionary):`
- L83: `func _cmd_buy_aircraft(role: String, a: Dictionary):`
- L89: `func _cmd_buy_gear(role: String, a: Dictionary):`
- L93: `func _cmd_hire_spotter(role: String, a: Dictionary):`
- L98: `func _cmd_spotter_move(role: String, a: Dictionary):`
- L111: `func _cmd_squawk(role: String, a: Dictionary):`
- L120: `func _cmd_upgrade(role: String, a: Dictionary):`
- L125: `func _cmd_jam(role: String, a: Dictionary):`
- L137: `func _cmd_transponder(role: String, a: Dictionary):`
- L145: `func _cmd_turn_around(role: String, a: Dictionary):`
- L153: `func _cmd_autopilot(role: String, a: Dictionary):`
- L190: `func _autopilot_navigate() -> void:`
- L226: `func _approach_route(af: Airfield) -> Array:`
- L257: `func _autopilot_target() -> Airfield:`
- L280: `func _cmd_kick(role: String, a: Dictionary):`
- L284: `func _cmd_auto_kick(role: String, a: Dictionary):`
- L290: `func _cmd_pump(role: String, a: Dictionary):`
- L299: `func _cmd_call_boat(role: String, a: Dictionary):`
- L305: `func seat_driver(role: String, human: bool) -> void:`
- L369: `func remote_controls() -> FlightModel.Controls:`
- L377: `func _cmd_cutter_goto(role: String, a: Dictionary):`
- L394: `func _cmd_boat_goto(role: String, a: Dictionary):`
- L406: `func _cmd_confirm(role: String, a: Dictionary):`
- L414: `func _cmd_hq(role: String, a: Dictionary):`
- L429: `func role_position(role: String):`
- L445: `func voice_transmitted(role: String, dur: float) -> void:`
- L450: `func _cmd_chat(role: String, a: Dictionary):`
- L466: `func _cmd_radio_channel(role: String, a: Dictionary):`
- L475: `func _cmd_launch(role: String, a: Dictionary):`
- L490: `func _cmd_dispatch(role: String, a: Dictionary):`
- L506: `func _cmd_recall(role: String, a: Dictionary):`
- L516: `func _cmd_claim_unit(role: String, a: Dictionary):`
- L539: `func _cmd_release_unit(role: String, a: Dictionary):`
- L547: `func set_pilot_input(role: String, roll: float, pitch: float, throttle: float) -> void:`
- L551: `func _cmd_encrypt(role: String, a: Dictionary):`
- L555: `func _cmd_aerostat(role: String, a: Dictionary):`
- L559: `func _cmd_gun_mode(role: String, a: Dictionary):`
- L576: `func _cmd_sell_weapons(role: String, a: Dictionary):`
- L595: `func _cmd_buy_weapons(role: String, a: Dictionary):`
- L613: `func _cmd_set_cache(role: String, a: Dictionary):`
- L624: `func _cmd_squad_order(role: String, a: Dictionary):`
- L644: `func _cmd_field_order(role: String, a: Dictionary):`
- L655: `func _cmd_rackets(role: String, a: Dictionary):`
- L674: `func _cmd_stash_works(role: String, a: Dictionary):`
- L680: `func _cmd_analyst(role: String, a: Dictionary):`
- L697: `func _cmd_casino(role: String, a: Dictionary):`
- L719: `func _cmd_acid_barter(role: String, a: Dictionary):`
- L726: `func _cmd_acid_sell(role: String, a: Dictionary):`
- L733: `func _cmd_acid_auto(role: String, a: Dictionary):`
- L740: `func _cmd_buy_vehicle(role: String, a: Dictionary):`
- L747: `func _cmd_sell_vehicle(role: String, a: Dictionary):`
- L754: `func _cmd_use_vehicle(role: String, a: Dictionary):`
- L761: `func _cmd_fleet_auto(role: String, a: Dictionary):`
- L768: `func _cmd_casino_play(role: String, a: Dictionary):`
- L775: `func _cmd_casino_case(role: String, a: Dictionary):`
- L782: `func _cmd_service(role: String, a: Dictionary):`
- L791: `func _cmd_stop_work(role: String, a: Dictionary):`
- L798: `func _cmd_inspect(role: String, a: Dictionary):`
- L807: `func _cmd_plant_beacon(role: String, a: Dictionary):`
- L814: `func _cmd_race_enter(role: String, a: Dictionary):`
- L821: `func _cmd_recruit_squad(role: String, a: Dictionary):`
- L835: `func _cmd_disband_squad(role: String, a: Dictionary):`
- L847: `func _cmd_investigate_agency(role: String, a: Dictionary):`
- L854: `func _cmd_island_ship(role: String, a: Dictionary):`
- L861: `func _cmd_buy_passage(role: String, a: Dictionary):`
- L868: `func _cmd_airport_crackdown(role: String, a: Dictionary):`
- L879: `func _cmd_port_inspections(role: String, a: Dictionary):`
- L890: `func _cmd_court_bail(role: String, a: Dictionary):`
- L894: `func _cmd_court_hire(role: String, a: Dictionary):`
- L898: `func _cmd_court_motion(role: String, a: Dictionary):`
- L902: `func _cmd_court_tamper(role: String, a: Dictionary):`
- L906: `func _cmd_court_bribe(role: String, a: Dictionary):`
- L910: `func _cmd_court_plea(role: String, a: Dictionary):`
- L914: `func _cmd_court_cooperate(role: String, a: Dictionary):`
- L918: `func _cmd_court_appeal(role: String, a: Dictionary):`
- L923: `func _cmd_court_wait(role: String, a: Dictionary):`
- L934: `func _cmd_court_no_bail(role: String, a: Dictionary):`
- L938: `func _cmd_court_immunity(role: String, a: Dictionary):`
- L942: `func _cmd_court_forfeiture(role: String, a: Dictionary):`
- L946: `func _cmd_court_charge(role: String, a: Dictionary):`
- L950: `func _cmd_court_offer_plea(role: String, a: Dictionary):`
- L954: `func _cmd_sell_product(role: String, a: Dictionary):`
- L965: `func _cmd_move_goods(role: String, a: Dictionary):`
- L976: `func _cmd_move_cash(role: String, a: Dictionary):`
- L985: `func _cmd_cash_round(role: String, a: Dictionary):`
- L999: `func _cmd_goods_round(role: String, a: Dictionary):`
- L1011: `func _cmd_escort_truck(role: String, a: Dictionary):`
- L1033: `func _cmd_tutorial(role: String, a: Dictionary):`
- L1054: `func _cmd_move_armoury(role: String, a: Dictionary):`
- L1061: `func _cmd_load_cash(role: String, a: Dictionary):`
- L1068: `func _cmd_unload_cash(role: String, a: Dictionary):`
- L1075: `func _cmd_street_sweep(role: String, a: Dictionary):`
- L1082: `func _cmd_trace_money(role: String, a: Dictionary):`
- L1089: `func _cmd_hire_worker(role: String, a: Dictionary):`
- L1093: `func _cmd_fire_worker(role: String, a: Dictionary):`
- L1097: `func _cmd_pay_bonus(role: String, a: Dictionary):`
- L1101: `func _cmd_pay_worker_lawyer(role: String, a: Dictionary):`
- L1105: `func _cmd_post_lookout(role: String, a: Dictionary):`
- L1109: `func _cmd_offer_worker_deal(role: String, a: Dictionary):`
- L1113: `func _cmd_family_accept(role: String, a: Dictionary):`
- L1120: `func _cmd_family_decline(role: String, a: Dictionary):`
- L1127: `func _cmd_family_probe(role: String, a: Dictionary):`
- L1134: `func _cmd_family_stall(role: String, a: Dictionary):`
- L1141: `func _cmd_pay_tribute(role: String, a: Dictionary):`
- L1148: `func _cmd_rico_case(role: String, a: Dictionary):`
- L1155: `func _cmd_raid_stash(role: String, a: Dictionary):`

### `scripts/sim/session_ops.gd`

- L7: `func accept_job(job: Jobs.Job):`
- L48: `func _informant_roll(job: Jobs.Job) -> void:`
- L65: `func _spy_roll(job: Jobs.Job) -> void:`
- L79: `func _ramp_load(job: Jobs.Job) -> void:`
- L91: `func drop_job(job: Jobs.Job) -> void:`
- L111: `func hire_loadmaster() -> bool:`
- L123: `func cycle_item(item_id: int, direction := 1) -> void:`
- L131: `func place_item(item_id: int, station: int):`
- L154: `func fuel_source() -> Array:`
- L168: `func _draw_fuel(want_lb: float) -> float:`
- L181: `func set_fuel(target_lb: float) -> void:`
- L195: `func fill_ferry(lb: float):`
- L216: `func has_upgrade(id: String) -> bool:`
- L222: `func buy_upgrade(side: String, id: String):`
- L251: `func apply_upgrades() -> void:`
- L285: `func _update_upgrades(dt: float) -> void:`
- L303: `func buy_gear(name: String):`
- L334: `func hire_spotter(code):`
- L348: `func set_copilot(who) -> void:`
- L354: `func buy_or_switch(key: String):`
- L372: `func respawn() -> void:`
- L389: `func turn_around():`
- L400: `func _finish_turnaround() -> void:`
- L410: `func request_kick(role: String, count := 1):`
- L428: `func _droppables() -> Array:`
- L433: `func _crew_work(dt: float, s: FlightModel.FlightState) -> void:`
- L475: `func _kick_one(s: FlightModel.FlightState) -> void:`
- L494: `func _df_on(msg: RadioNet.RadioMsg) -> void:`
- L522: `func call_boat(brief := false):`

### `scripts/sim/session_rules.gd`

- L6: `func _crash(reason: String) -> void:`
- L16: `func _bust(how: String) -> void:`
- L49: `func _rules(dt: float, s: FlightModel.FlightState) -> void:`
- L121: `func _on_shoulder(x: float, y: float) -> bool:`
- L128: `func _arrive(af: Airfield, s: FlightModel.FlightState) -> void:`
- L163: `func _truck_out(job: Jobs.Job, af: Airfield) -> void:`
- L187: `func _update_stashes(dt: float) -> void:`
- L246: `func _update_economy(dt: float) -> void:`
- L273: `func _raid(id: String):`
- L307: `func _faction_of(role: String) -> String:`
- L311: `func _court(fn: Callable):`
- L318: `func _pay(fn: Callable):`
- L325: `func _complete_delivery(job: Jobs.Job, af: Airfield) -> void:`
- L365: `func _delivered(job: Jobs.Job, pay: int, af: Airfield, hot: bool) -> Dictionary:`
- L376: `func _unload_tick(dt: float) -> void:`
- L401: `func _grade(job: Jobs.Job) -> Array:`

### `scripts/sim/session_state.gd`

- L49: `func _init(touchdowns_seen_ := 0) -> void:`
- L59: `func _init(code_: String) -> void:`
- L242: `static func set_of(items) -> Dictionary:`
- L251: `static func _rng(s: int) -> PyRandom:`
- L257: `func runner_active() -> bool:`
- L261: `func say(text: String) -> void:`
- L266: `func law_say(text: String) -> void:`
- L271: `func carrying_hot() -> bool:`
- L278: `func hot_value() -> int:`
- L286: `func job_xy(job: Jobs.Job) -> Array:`
- L290: `func find_job(job_id: int) -> Jobs.Job:`
- L301: `func crew_count() -> int:`
- L310: `func range_estimate() -> Array:`
- L319: `func _switch_aircraft(key: String, fuel_frac = null) -> void:`
- L328: `func spawn_at(code: String) -> void:`
- L344: `func spawn_airborne(x: float, y: float, heading: float, alt_agl: float, speed_kts: float) -> void:`
- L354: `func _after_spawn() -> void:`
- L368: `func set_weather(w: Dictionary) -> void:`
- L394: `func _apply_wind() -> void:`
- L409: `func enable_system(key: String, career := false) -> bool:`
- L479: `func unlocked(key: String) -> bool:`
- L483: `func refresh_board(code: String) -> void:`
- L516: `func _seize_weapons(weapons: Dictionary, where: String) -> void:`
- L525: `func _stock_weapons(weapons: Dictionary, stash_id: String) -> void:`
- L534: `func weapon_price(tier: String, buying: bool) -> int:`
- L539: `func save() -> void:`
- L571: `func save_location() -> String:`
- L575: `static func read_save(path: String) -> Dictionary:`

### `scripts/sim/session_tick.gd`

- L6: `func update(dt: float, inp: ControlMapper.InputFrame = null, bot_controls: FlightModel.Controls = null) -> void:`
- L23: `func _update_runner(dt: float, inp: ControlMapper.InputFrame, bot_controls: FlightModel.Controls) -> void:`
- L83: `static func _any_held(inp: ControlMapper.InputFrame, keys: Array) -> bool:`
- L90: `func runner_signature() -> SensorNet.Signature:`
- L104: `func _update_world(dt: float) -> void:`
- L204: `func _spawn_ai_run() -> void:`
- L217: `func _police_outcome(what: String) -> void:`
- L234: `func _maritime_event(kind: String, data: Dictionary) -> void:`
- L273: `func _resolve_job(job: Jobs.Job, text: String) -> void:`
- L280: `func _update_intel(dt: float) -> void:`

### `scripts/sim/stash_works.gd`

- L22: `static func level(st: Dictionary, what: String) -> int:`
- L29: `static func raid_keep(st: Dictionary) -> float:`
- L34: `static func heat_in(st: Dictionary) -> float:`
- L39: `static func heat_out(st: Dictionary) -> float:`
- L44: `static func next_cost(st: Dictionary, what: String) -> int:`
- L50: `static func build(sess, id: String, what: String) -> String:`

### `scripts/sim/stashes.gd`

- L55: `func lead_s() -> float:`
- L58: `func frac(now: float) -> float:`
- L65: `func start_agent() -> void:`
- L83: `func sync(now: float) -> void:`
- L100: `func hold(seconds: float) -> void:`
- L107: `func left_m() -> float:`
- L116: `func reroute(path: PackedVector2Array) -> bool:`
- L123: `func remaining_route() -> PackedVector2Array:`
- L128: `func pos(now: float) -> Array:`
- L147: `func _init(map_stashes: Array, rng_: PyRandom) -> void:`
- L157: `func get_stash(id: String):`
- L164: `func live() -> Array:`
- L169: `static func suspicion(st: Dictionary) -> float:`
- L173: `func known() -> Array:`
- L179: `func job_from(origin: Airfield, jobs_rng: PyRandom, price_mult := 1.0):`
- L201: `func dispatch(job: Jobs.Job, af: Airfield, now: float, pay: int, risk := 0.0) -> Truck:`
- L227: `func update(dt: float, now: float, police_units: Array) -> Array:`
- L265: `func raid(id: String) -> String:`
- L278: `func trucks_to(id: String) -> Array:`

### `scripts/sim/story.gd`

- L138: `func _init(index_ := 0, progress_ = null) -> void:`
- L158: `func to_dict() -> Dictionary:`
- L162: `static func from_dict(d) -> Story:`
- L177: `static func index_of(title: String) -> int:`
- L184: `func is_unlocked(key: String) -> bool:`
- L189: `static func opens_through(n: int) -> Array:`
- L199: `func attach(s) -> void:`
- L216: `func _open(i: int, announce: bool) -> void:`
- L239: `func objective_lines() -> Array:`
- L258: `func _bump(key: String, amount := 1.0) -> void:`
- L263: `func _put(key: String, v: float) -> void:`
- L268: `func _on_event(ev: EventBus.Event) -> void:`
- L308: `func _blotter_ends() -> void:`
- L319: `func tick(s) -> void:`
- L385: `func advance() -> void:`

### `scripts/sim/strategic_save.gd`

- L61: `static func capture(s: Session) -> Dictionary:`
- L101: `static func _capture_world(s: Session, d: Dictionary) -> void:`
- L135: `static func _capture_nights(n: NightDirector) -> Dictionary:`
- L153: `static func _capture_war(g: GroundWar) -> Dictionary:`
- L168: `static func _payroll(s: Session) -> Dictionary:`
- L191: `static func restore(s: Session, d: Dictionary) -> void:`
- L260: `static func _restore_nights(n: NightDirector, d: Dictionary) -> void:`
- L299: `static func _restore_world(s: Session, d: Dictionary) -> void:`
- L337: `static func _restore_war(g: GroundWar, d: Dictionary) -> void:`
- L358: `static func _restore_payroll(p: Payroll, d: Dictionary) -> void:`
- L383: `static func _restore_squads(s: Session, d: Dictionary) -> void:`
- L420: `static func _ints(d: Dictionary) -> Dictionary:`

### `scripts/sim/switches.gd`

- L30: `static func parity_off() -> void:`
- L41: `static func parity_on() -> void:`

### `scripts/sim/territories.gd`

- L8: `static func records(layout: MapLayout) -> Array:`
- L26: `static func at(layout: MapLayout, position: Vector2) -> Dictionary:`
- L60: `static func get_area(layout: MapLayout, id: String) -> Dictionary:`
- L70: `static func key(layout: MapLayout, id: String) -> String:`
- L76: `static func local_id(id: String) -> String:`
- L81: `static func center_of(area: Dictionary) -> Vector2:`
- L90: `static func territory_ids(layout: MapLayout) -> Array:`
- L97: `static func validate(layout: MapLayout) -> String:`

### `scripts/sim/trade.gd`

- L77: `func _init(sess_, rng_: PyRandom, career_ := false) -> void:`
- L102: `func street_price(g: String, m: String) -> float:`
- L107: `func stock_value() -> float:`
- L114: `func available(buyer: String) -> String:`
- L135: `func quote(buyer: String, good: String, tier := "rifle") -> Dictionary:`
- L157: `func sell(buyer: String, good: String, qty: float, tier := "rifle", from := "", careful := false) -> String:`
- L188: `func settle(buyer: String, good: String, qty: float, tier := "rifle") -> int:`
- L207: `func _effects(buyer: String, good: String, qty: float, pay: int) -> void:`
- L246: `func board_offer(origin: Airfield, jobs_rng: PyRandom):`
- L275: `func delivered(job) -> void:`
- L292: `func dealers(o: String, m := "") -> Array:`
- L299: `func _corners(o: String) -> Array:`
- L315: `func dealers_wanted(o: String) -> int:`
- L324: `func update(dt: float) -> void:`
- L349: `func _ai_bulk() -> void:`
- L366: `func _post_dealers() -> void:`
- L377: `func _sell_street(o: String, step: float) -> void:`
- L423: `func _street_war(step: float) -> void:`
- L453: `func _check_connection() -> void:`
- L465: `func sweep(m: String) -> String:`
- L485: `func trace() -> String:`
- L517: `func view(side: String) -> Dictionary:`

### `scripts/sim/tutorial.gd`

- L158: `func _init(state = null) -> void:`
- L173: `func attach(s) -> Tutorial:`
- L183: `func to_dict() -> Dictionary:`
- L191: `func _needs_ok(needs: String) -> bool:`
- L221: `func current() -> Variant:`
- L231: `func progress() -> Array:`
- L237: `func complete(id: String) -> void:`
- L249: `func _title(id: String) -> String:`
- L256: `func skip() -> void:`
- L262: `func set_enabled(on: bool) -> void:`
- L268: `func note(what: String) -> void:`
- L272: `func _on_event(ev: EventBus.Event) -> void:`
- L300: `func tick(s) -> void:`
- L360: `func _show(id: String) -> void:`
- L369: `func view() -> Dictionary:`
- L380: `func desk_current(role: String) -> Variant:`
- L391: `func command_done(role: String, name: String) -> void:`
- L410: `func desk_skip(role: String) -> void:`
- L418: `func desk_view(role: String) -> Dictionary:`

### `scripts/sim/undercover.gd`

- L36: `func _init(sess_) -> void:`
- L42: `func active() -> bool:`
- L46: `func update(dt: float) -> void:`
- L52: `func odds() -> float:`
- L63: `func why_not() -> String:`
- L75: `func beacon_live() -> bool:`
- L79: `func plant() -> String:`
- L103: `func view() -> Dictionary:`

### `scripts/sim/upgrades.gd`

- L121: `static func node(side: String, id: String) -> Dictionary:`
- L129: `static func side_of(id: String) -> String:`
- L137: `static func blocker(side: String, id: String, owned: Dictionary, funds: int) -> String:`
- L152: `static func ai_pick(owned: Dictionary, funds: int) -> String:`

### `scripts/sim/world.gd`

- L22: `static func _initial_layout() -> MapLayout:`
- L36: `static func use_layout(l: MapLayout) -> void:`
- L46: `static func _validate_layout(l: MapLayout) -> void:`
- L53: `static func use_map(map_seed: int) -> MapLayout:`
- L63: `static func _by_code() -> Dictionary:`
- L72: `static func airfield(code: String) -> Airfield:`
- L76: `func _init(p_seed := 7) -> void:`
- L103: `func height(x: float, y: float) -> float:`
- L110: `func ground(x: float, y: float) -> float:`
- L122: `func is_water(x: float, y: float) -> bool:`
- L128: `func airfield_at(x: float, y: float, margin := 0.0) -> Airfield:`
- L138: `func airfield_elev(af: Airfield) -> float:`
- L143: `func nearest_airfield(x: float, y: float) -> Array:`
- L154: `func tree_hit(x: float, y: float, z: float, radius := 5.0) -> bool:`
- L159: `func obstacle_top(x: float, y: float, radius := 30.0) -> float:`
- L163: `func heights_many(xs: PackedFloat64Array, ys: PackedFloat64Array) -> PackedFloat64Array:`
- L167: `func line_of_sight(a: Array, b: Array, step := 200.0) -> bool:`
- L171: `func tree_count() -> int:`

### `scripts/station/hq_orders.gd`

- L17: `func _init(side_: String) -> void:`
- L21: `static func _money(v) -> String:`
- L27: `static func realism_lines(ss: Dictionary, side: String) -> Array:`
- L48: `func rows(ss: Dictionary) -> Array:`
- L52: `func _pick(key: String, n: int, default := 0) -> int:`
- L56: `func _runner_rows(ss: Dictionary) -> Array:`
- L118: `func _law_rows(ss: Dictionary) -> Array:`
- L162: `func adjust(row: Dictionary, d: int, ss: Dictionary) -> void:`
- L172: `func _current(k: String, ss: Dictionary) -> int:`

### `scripts/station/remote_seat.gd`

- L36: `func setup(link_, role_: String, graphics := "medium", world: World = null) -> RemoteSeat:`
- L110: `static func _lerp_angle(a: float, b: float, t: float) -> float:`
- L114: `func _push(snap) -> void:`
- L125: `func pose(extract: Callable):`
- L154: `func _unhandled_input(ev: InputEvent) -> void:`
- L177: `func _axis(neg: Array, pos: Array) -> float:`
- L190: `func _process(delta: float) -> void:`
- L218: `func _node(key: String, factory: Callable) -> Node3D:`
- L226: `func _place(n: Node3D, p: Dictionary) -> void:`
- L231: `func _pursuer(kind: String) -> Node3D:`
- L235: `func _aircraft(key: String) -> Node3D:`
- L240: `func _sync(snap: Dictionary) -> Node3D:`
- L305: `func _camera(me: Node3D) -> void:`
- L321: `func _hud(snap: Dictionary) -> void:`

### `scripts/station/station_app.gd`

- L62: `func setup(link_, role_: String, world_: World = null, vertical := false) -> StationApp:`
- L189: `func _build_runner_tiles() -> void:`
- L208: `func _hints() -> Array:`
- L258: `func _btn(text: String, fn: Callable) -> void:`
- L267: `func _build_buttons() -> void:`
- L280: `func _cmd(name: String, args := {}) -> void:`
- L289: `func _check_acks() -> void:`
- L300: `func _unhandled_key_input(ev: InputEvent) -> void:`
- L345: `func _key(k: String) -> void:`
- L396: `func _family_key(k: String, snap: Dictionary) -> bool:`
- L436: `func open_logistics() -> void:`
- L449: `func open_talk(name: String, title := "start") -> TalkBalloon:`
- L461: `func _island_key(k: String, snap: Dictionary) -> bool:`
- L489: `static func island_lines(isl: Dictionary) -> Array:`
- L503: `static func _jail_law_line(p: Dictionary) -> String:`
- L512: `static func court_lines(c: Dictionary) -> Array:`
- L526: `static func _court_law_line(c: Dictionary) -> String:`
- L535: `func _trade_key(k: String, snap: Dictionary) -> bool:`
- L556: `static func trade_lines(t: Dictionary) -> Array:`
- L575: `static func _trade_law_line(t: Dictionary) -> String:`
- L587: `static func _island_law_line(isl: Dictionary) -> String:`
- L597: `static func family_lines(fam: Dictionary, ag: Dictionary) -> Array:`
- L623: `static func _family_law_line(fam: Dictionary) -> String:`
- L632: `func _runner_key(k: String, snap: Dictionary) -> void:`
- L669: `func _hq_key(k: String, snap: Dictionary) -> void:`
- L723: `func _law_key(k: String, snap: Dictionary) -> void:`
- L788: `func _on_map_click(button: int, p: Vector2) -> void:`
- L824: `func commands_squads(snap: Dictionary) -> bool:`
- L829: `func _own() -> String:`
- L833: `func _my_squads(snap: Dictionary) -> Array:`
- L837: `func _squad_key(k: String, snap: Dictionary) -> bool:`
- L872: `func _squad_click(button: int, p: Vector2, snap: Dictionary) -> void:`
- L897: `func strip_at(p: Vector2):`
- L903: `func _process(delta: float) -> void:`
- L947: `func _set_list(kind: String, keys: Array, cells: Array, colors := {}, defs := []) -> void:`
- L969: `func _runner_tiles(ac, snap: Dictionary) -> void:`
- L1008: `func _draw_analyst(snap: Dictionary) -> void:`
- L1033: `func _draw_fixer(snap: Dictionary) -> void:`
- L1067: `func _fixer_key(k: String, snap: Dictionary) -> void:`
- L1087: `func _draw_mechanic(snap: Dictionary) -> void:`
- L1116: `func _mechanic_key(k: String, snap: Dictionary) -> void:`
- L1136: `func _draw_undercover(snap: Dictionary) -> void:`
- L1156: `func _analyst_key(k: String) -> bool:`
- L1178: `func _draw_runner(snap: Dictionary) -> void:`
- L1257: `func _flight_states(ac, snap: Dictionary) -> Dictionary:`
- L1273: `func _draw_hq(snap: Dictionary) -> void:`
- L1292: `func _draw_squads(snap: Dictionary) -> void:`
- L1353: `static func _agency_line(ag: Dictionary) -> String:`
- L1362: `func _draw_law(snap: Dictionary) -> void:`

### `scripts/station/station_map.gd`

- L20: `func setup(world_: World) -> StationMap:`
- L28: `func side() -> float:`
- L33: `func origin() -> Vector2:`
- L37: `func w2m(x: float, y: float) -> Vector2:`
- L42: `func m2w(p: Vector2) -> Vector2:`
- L48: `func _on_map(p: Vector2) -> bool:`
- L53: `func _gui_input(ev: InputEvent) -> void:`
- L59: `func mouse_world():`
- L66: `func _process(_dt: float) -> void:`
- L70: `func _circle(x: float, y: float, r: float, col: Color, w := 1.5) -> void:`
- L74: `func _arrow(x: float, y: float, hdg: float, col: Color, size_px := 12.0) -> void:`
- L83: `func _cross(x: float, y: float, col: Color, s := 6.0) -> void:`
- L89: `func _text(x: float, y: float, t: String, col: Color) -> void:`
- L93: `func _draw() -> void:`
- L126: `func _draw_runner() -> void:`
- L169: `func _draw_ground() -> void:`
- L212: `func _draw_coverage() -> void:`
- L236: `func _draw_law() -> void:`

### `scripts/ui/casino_menu.gd`

- L34: `func _build() -> void:`
- L51: `func sit(which: String) -> void:`
- L59: `func stake() -> int:`
- L63: `func _casino() -> Casino:`
- L67: `func refresh() -> void:`
- L97: `func _hints() -> Array:`
- L120: `static func suit_of(rank: int, place: int) -> int:`
- L125: `static func card_node(rank: int, place: int, down := false, baccarat := false) -> Control:`
- L140: `static func die_node(n: int) -> Control:`
- L153: `static func reel_node(sym: String) -> Control:`
- L167: `static func pocket_node(n: int, colour: String) -> Control:`
- L180: `func _row(caption: String, nodes: Array, total := "") -> void:`
- L197: `func _fill_stage(play: Dictionary) -> void:`
- L238: `static func card(r: int) -> String:`
- L242: `static func hand(cards: Array) -> String:`
- L249: `func _spot_name() -> String:`
- L254: `func _roulette(play: Dictionary) -> String:`
- L269: `func _blackjack(play: Dictionary) -> String:`
- L279: `func _craps(play: Dictionary) -> String:`
- L288: `func _baccarat(play: Dictionary) -> String:`
- L296: `func _slots(play: Dictionary) -> String:`
- L302: `func key(k: String) -> void:`

### `scripts/ui/cg_chart.gd`

- L13: `func _init() -> void:`
- L18: `func set_data(spec_: Aircraft.Spec, tow_: Vector2, zfw_: Vector2, ok_: bool) -> void:`
- L26: `func _draw() -> void:`

### `scripts/ui/controls_menu.gd`

- L22: `func _ready() -> void:`
- L107: `func _btn(text: String, cb: Callable, right := Callable()) -> Button:`
- L121: `func _refresh() -> void:`
- L132: `func _rebind(n: String) -> void:`
- L139: `func _capture(c: String) -> void:`
- L148: `func _tweak(c: String, what: String, dir: int) -> void:`
- L160: `func _toggle_palette() -> void:`
- L167: `func _toggle_speech() -> void:`
- L178: `func _input(ev: InputEvent) -> void:`
- L212: `func _process(_dt: float) -> void:`
- L226: `func close() -> void:`

### `scripts/ui/dealer_menu.gd`

- L20: `func _build() -> void:`
- L43: `func browse() -> void:`
- L49: `static func stats(sp: Dictionary) -> String:`
- L55: `func refresh() -> void:`
- L91: `func key(k: String) -> void:`

### `scripts/ui/game_menu.gd`

- L19: `func setup(sess: Session) -> GameMenu:`
- L67: `func _build() -> void:`
- L71: `func open() -> void:`
- L76: `func close() -> void:`
- L81: `func refresh() -> void:`
- L85: `func key(_k: String) -> void:`
- L90: `static func make_table(columns: Array) -> DataTable:`
- L95: `static func list_move(l, d: int) -> void:`
- L112: `static func selected(l) -> int:`

### `scripts/ui/hangar_menu.gd`

- L15: `func _build() -> void:`
- L39: `func _rows() -> Array:`
- L55: `func refresh() -> void:`
- L109: `func _detail() -> void:`
- L126: `func key(k: String) -> void:`

### `scripts/ui/hq_menu.gd`

- L30: `func _build() -> void:`
- L62: `func _view():`
- L69: `func _process(_dt: float) -> void:`
- L80: `func open() -> void:`
- L87: `func close() -> void:`
- L97: `func _notification(what: int) -> void:`
- L102: `func refresh() -> void:`
- L138: `func _intel(ss: Dictionary, head: String) -> void:`
- L167: `func _detail() -> void:`
- L171: `func key(k: String) -> void:`
- L214: `func _enter_squad_mode() -> void:`
- L225: `func _leave_squad_mode() -> void:`
- L233: `func _my_squads() -> Array:`
- L237: `func _squad_detail() -> void:`
- L246: `func _squad_key(k: String) -> void:`
- L267: `func _on_map_click(button: int, p: Vector2) -> void:`

### `scripts/ui/hud.gd`

- L48: `func setup(sess: Session) -> Hud:`
- L102: `func _anchor(c: Control, a: Vector4, o := Vector4.ZERO) -> void:`
- L113: `func _centered(l: Label, y_frac: float) -> Label:`
- L121: `func _panel(bg := Color(0.02, 0.03, 0.05, 0.62)) -> PanelContainer:`
- L128: `func _build_chips() -> void:`
- L141: `func _build_wanted() -> void:`
- L158: `func _bar(col: Color) -> ProgressBar:`
- L170: `func _build_status() -> void:`
- L190: `func _build_flight() -> void:`
- L248: `func show_banner(text: String, sub := "", color := UIStyle.PINK) -> void:`
- L256: `func refresh() -> void:`
- L307: `func _flight(st: FlightModel.FlightState, c: FlightModel.Controls, lo: Loadout) -> void:`
- L330: `func _chip_row(st: FlightModel.FlightState, c: FlightModel.Controls) -> void:`
- L374: `func _painter_text(st: FlightModel.FlightState) -> String:`
- L387: `func _wanted() -> void:`
- L399: `func _status(st: FlightModel.FlightState, lo: Loadout) -> void:`
- L430: `func _crew(lo: Loadout) -> void:`
- L447: `func _warnings(st: FlightModel.FlightState, c: FlightModel.Controls) -> void:`
- L462: `func _papi(st: FlightModel.FlightState) -> void:`

### `scripts/ui/job_menu.gd`

- L18: `func _build() -> void:`
- L57: `static func _pct(m: float) -> Array:`
- L62: `func _market() -> void:`
- L111: `func refresh() -> void:`
- L143: `func _sep(text: String) -> void:`
- L148: `func _row(kind: String, j: Jobs.Job, af: Airfield, est_w: float) -> void:`
- L170: `func _show_detail() -> void:`
- L193: `func key(k: String) -> void:`

### `scripts/ui/load_menu.gd`

- L29: `func _build() -> void:`
- L127: `func _items() -> Array:`
- L131: `func refresh() -> void:`
- L142: `func _refresh_stations() -> void:`
- L163: `func _refresh_items() -> void:`
- L204: `func _picked(iid: int, station: int) -> void:`
- L213: `func _cruise() -> Array:`
- L217: `func _refresh_fuel_and_wb() -> void:`
- L265: `func _route_need():`
- L280: `func _preview_fuel(v: float) -> void:`
- L285: `func _set_fuel(v: float) -> void:`
- L290: `func _route_fuel() -> void:`
- L298: `func key(k: String) -> void:`

### `scripts/ui/lobby.gd`

- L36: `func _ready() -> void:`
- L171: `func _unhandled_key_input(ev: InputEvent) -> void:`
- L177: `func _row(g: GridContainer, text: String, c: Control) -> void:`
- L183: `func _plan() -> void:`
- L192: `func _opts() -> Dictionary:`
- L199: `func _go() -> void:`
- L205: `func _join() -> void:`

### `scripts/ui/logistics_menu.gd`

- L34: `func _ready() -> void:`
- L129: `func _build_works(what: String) -> void:`
- L135: `func refresh() -> void:`
- L204: `func _send() -> void:`
- L227: `func _all_home() -> void:`
- L246: `func _round_text() -> String:`
- L252: `func _round_add() -> void:`
- L263: `func _round_clear() -> void:`
- L269: `func _round_cash() -> void:`
- L280: `func _round_goods() -> void:`
- L294: `func _act(r: Array) -> void:`
- L299: `func _process(_dt: float) -> void:`
- L304: `func _input(ev: InputEvent) -> void:`
- L318: `func close() -> void:`

### `scripts/ui/minimap.gd`

- L42: `func setup(sess: Session) -> Minimap:`
- L50: `func _scale() -> float:`
- L55: `func _want() -> Vector2:`
- L63: `func _layout() -> void:`
- L73: `func toggle() -> void:`
- L79: `func zoom(step: int) -> void:`
- L84: `func _chart_px() -> float:`
- L88: `func range_km() -> float:`
- L92: `func _process(dt: float) -> void:`
- L104: `func _focus() -> Dictionary:`
- L111: `func _rows() -> int:`
- L116: `func _row_at(p: Vector2) -> int:`
- L128: `func _panel(font: Font) -> void:`
- L161: `static func _km_text(m: float) -> String:`
- L166: `func _gui_input(ev: InputEvent) -> void:`
- L198: `func _frame() -> void:`
- L215: `func to_screen(x: float, y: float) -> Vector2:`
- L222: `func _world_of(p: Vector2) -> Vector2:`
- L229: `func _inside(p: Vector2, pad := 0.0) -> bool:`
- L236: `func _label(font: Font, p: Vector2, text: String, fs: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:`
- L241: `func _cross(p: Vector2, col: Color, r := 4.0) -> void:`
- L246: `func _diamond(p: Vector2, col: Color, r := 5.0) -> void:`
- L251: `func _ring_world(wx: float, wy: float, m: float, col: Color, w: float) -> void:`
- L267: `func _pointer(p: Vector2, col: Color, text: String, font: Font) -> void:`
- L276: `func _draw() -> void:`
- L300: `func _terrain() -> void:`
- L317: `func _rim(font: Font) -> void:`
- L333: `func _caption(font: Font) -> void:`
- L339: `func _world_marks(font: Font) -> void:`
- L423: `func _waypoint(font: Font) -> void:`
- L444: `func _me() -> void:`

### `scripts/ui/multiplayer_menu.gd`

- L53: `func setup(server_ = null, link_ = null, voice_ = null, finder_ = null) -> MultiplayerMenu:`
- L100: `func close() -> void:`
- L107: `func _unhandled_key_input(ev: InputEvent) -> void:`
- L123: `func _process(dt: float) -> void:`
- L133: `func _page(title: String) -> VBoxContainer:`
- L145: `func _build_games() -> void:`
- L205: `func _build_table() -> void:`
- L250: `func _build_voice() -> void:`
- L325: `func _slider(v: VBoxContainer, text: String, lo: float, hi: float, val: float, set_fn: Callable) -> void:`
- L344: `func _refresh_key_btn() -> void:`
- L350: `func _join_game(i: int) -> void:`
- L357: `func _join_address() -> void:`
- L365: `func _name() -> String:`
- L369: `func _say(text: String) -> void:`
- L382: `func set_muted(id: String, on: bool) -> void:`
- L390: `func kick(id: String) -> bool:`
- L396: `func roster() -> Array:`
- L415: `func refresh() -> void:`
- L440: `func _refresh_roster() -> void:`
- L477: `func _refresh_chat() -> void:`
- L491: `func _refresh_seats() -> void:`

### `scripts/ui/pack_menu.gd`

- L18: `func _ready() -> void:`
- L51: `func refresh() -> void:`
- L90: `func _act(err: String) -> void:`
- L95: `func _input(ev: InputEvent) -> void:`
- L104: `func close() -> void:`

### `scripts/ui/pause_menu.gd`

- L29: `func setup(offer: Dictionary, note := "Paused") -> PauseMenu:`
- L87: `func _add(v: VBoxContainer, text: String, cb: Callable) -> Button:`
- L97: `func _ask(action: String, text: String, yes: String) -> void:`
- L104: `func say(text: String) -> void:`
- L108: `func _refresh() -> void:`
- L119: `func _step_graphics(dir: int) -> void:`
- L126: `func _toggle_assist() -> void:`
- L134: `func _step_volume(dir: int) -> void:`
- L146: `func _toggle_palette() -> void:`
- L154: `static func apply_volume(vol: float) -> void:`
- L159: `func _input(ev: InputEvent) -> void:`
- L182: `func close() -> void:`

### `scripts/ui/phone_menu.gd`

- L16: `func _build() -> void:`
- L26: `func contacts() -> Array:`
- L56: `func refresh() -> void:`
- L73: `func key(k: String) -> void:`

### `scripts/ui/places.gd`

- L13: `static func list(s: Session) -> Array:`
- L54: `static func _opens(chapter: String) -> String:`
- L59: `static func _locked(kind: String, name: String, note: String, s: Session) -> Dictionary:`
- L64: `static func markers(places: Array) -> Array:`
- L68: `static func color_of(p: Dictionary) -> Color:`
- L89: `static func ordered(places: Array) -> Array:`

### `scripts/ui/race_menu.gd`

- L12: `func _build() -> void:`
- L25: `func refresh() -> void:`
- L49: `static func _clock(t: float) -> String:`
- L53: `func key(k: String) -> void:`

### `scripts/ui/rackets_menu.gd`

- L10: `func _build() -> void:`
- L21: `func refresh() -> void:`
- L37: `func _go(what: String, extra := {}) -> void:`
- L46: `func key(k: String) -> void:`

### `scripts/ui/room_screen.gd`

- L30: `func setup(server_ = null, link_ = null) -> RoomScreen:`
- L117: `func _process(dt: float) -> void:`
- L130: `func view() -> Dictionary:`
- L138: `func _me() -> String:`
- L146: `func refresh() -> void:`
- L166: `func _draw_seats(d: Dictionary) -> void:`
- L219: `func _draw_players(d: Dictionary) -> void:`
- L242: `func _draw_status(d: Dictionary) -> void:`
- L263: `func _draw_chat() -> void:`
- L278: `func _take(role: String) -> void:`
- L288: `func _say(text: String) -> void:`
- L299: `func _start() -> void:`
- L304: `func _cancel() -> void:`

### `scripts/ui/seat_picker.gd`

- L20: `func setup(link_: NetClient) -> SeatPicker:`
- L68: `func _process(_dt: float) -> void:`
- L95: `func claim_selected() -> void:`
- L101: `func key(k: String) -> void:`
- L113: `func _unhandled_key_input(ev: InputEvent) -> void:`

### `scripts/ui/talk_balloon.gd`

- L23: `func _ready() -> void:`
- L55: `func start(resource_: DialogueResource, title: String, state_: Talk.State) -> void:`
- L61: `func _next(id: String) -> void:`
- L89: `func choose(i: int) -> void:`
- L99: `func advance() -> void:`
- L105: `func _close() -> void:`
- L111: `func _input(ev: InputEvent) -> void:`

### `scripts/ui/taxi_menu.gd`

- L15: `func _build() -> void:`
- L26: `func refresh() -> void:`
- L40: `func key(k: String) -> void:`

### `scripts/ui/tutorial_panel.gd`

- L13: `func _ready() -> void:`
- L38: `func dock_left() -> void:`
- L50: `func show_view(tv: Dictionary) -> void:`

### `scripts/ui/ui_style.gd`

- L43: `static func set_palette(name: String) -> void:`
- L56: `static func script() -> Font:`
- L63: `static func neon() -> Font:`
- L70: `static func title(text := "", size := 30, color := PINK) -> Label:`
- L77: `static func glow(l: Label, color: Color) -> void:`
- L85: `static func mono() -> Font:`
- L92: `static func label(text := "", size := 16, color := WHITE, font: Font = null) -> Label:`
- L106: `static func panel_box(color := PANEL) -> StyleBoxFlat:`
- L117: `static func box(bg: Color, radius := 5, border := Color(0, 0, 0, 0), bw := 0, margin := Vector4(10, 6, 10, 6)) -> StyleBoxFlat:`
- L133: `static func theme() -> Theme:`
- L212: `static func caption(text: String) -> Label:`
- L219: `static func bearing_to(x0: float, y0: float, x1: float, y1: float) -> float:`
- L224: `static func papi(alt: float, dist_m: float, field_elev: float) -> String:`

### `scripts/ui/widgets/attitude.gd`

- L17: `func _init() -> void:`
- L22: `func set_data(pitch_: float, roll_: float) -> void:`
- L29: `static func down_vector(roll_deg: float) -> Vector2:`
- L34: `func _draw() -> void:`

### `scripts/ui/widgets/car_dash.gd`

- L32: `func _init() -> void:`
- L38: `static func dial_max(cap_ms: float) -> float:`
- L42: `static func gear_text(g: int) -> String:`
- L47: `static func dial_point(c: Vector2, r: float, f: float) -> Vector2:`
- L52: `func set_data(car: Car, radio_: CarRadio, night: bool, waypoint = null) -> void:`
- L80: `func _dial(c: Vector2, r: float, v: float, vmax_: float, major: float, minor: float, label_div: float, red_from: float, col: Color) -> void:`
- L108: `func _draw() -> void:`
- L150: `func _waypoint_arrow(font: Font) -> void:`
- L164: `func _bar(p: Vector2, w: float, h: float, v: float, col: Color) -> void:`
- L172: `func _radio_panel(font: Font) -> void:`

### `scripts/ui/widgets/chip.gd`

- L12: `func setup(text := "") -> Chip:`
- L21: `func set_state(text: String, color: Color, on: bool) -> void:`
- L36: `func text() -> String:`
- L40: `func is_on() -> bool:`

### `scripts/ui/widgets/confirm_box.gd`

- L12: `func setup(text: String, yes_text := "Leave", no_text := "Stay") -> ConfirmBox:`
- L48: `func ask() -> void:`
- L53: `func key(k: String) -> bool:`

### `scripts/ui/widgets/data_table.gd`

- L20: `func setup(columns_: Array) -> DataTable:`
- L36: `func configure(columns_: Array) -> void:`
- L53: `static func _align(d: Dictionary) -> HorizontalAlignment:`
- L57: `func clear_rows() -> void:`
- L64: `func row_count() -> int:`
- L69: `func add_row(cells: Array, opts := {}) -> int:`
- L90: `func section(text: String) -> int:`
- L106: `func set_cell(row: int, col: int, text: String, color = null) -> void:`
- L114: `func set_row_color(row: int, color: Color) -> void:`
- L121: `func cell(row: int, col: int) -> String:`
- L125: `func selectable(row: int) -> bool:`
- L129: `func selected_row() -> int:`
- L134: `func select(row: int) -> void:`
- L142: `func move(d: int) -> void:`
- L156: `func select_near(row: int) -> void:`

### `scripts/ui/widgets/hq_board.gd`

- L18: `func setup(side_: String, show_news := true) -> HQBoard:`
- L56: `static func _k(v: float) -> String:`
- L60: `func update(ss: Dictionary) -> void:`
- L107: `func _conditions(ss: Dictionary) -> void:`
- L148: `func _detail() -> void:`
- L153: `func selected() -> Dictionary:`
- L159: `func adjust(d: int, ss: Dictionary) -> void:`
- L166: `func command_args() -> Dictionary:`

### `scripts/ui/widgets/key_hints.gd`

- L14: `func _init() -> void:`
- L20: `func set_hints(hints: Array) -> void:`
- L31: `func actions() -> Array:`
- L35: `func press(action: String) -> void:`
- L39: `func _chip(key: String, text: String, action: String) -> Control:`

### `scripts/ui/widgets/stat_tile.gd`

- L13: `func setup(caption_: String, with_bar := false, value_size := 22) -> StatTile:`
- L45: `func set_value(text: String, color := UIStyle.WHITE, frac := -1.0, subtext := "") -> void:`

### `scripts/ui/widgets/toast_feed.gd`

- L14: `func _init() -> void:`
- L20: `func push(text: String, now: float, color := UIStyle.WHITE) -> void:`
- L39: `static func tone(text: String) -> Color:`
- L49: `func sync(messages: Array, now: float) -> void:`
- L68: `func fade(now: float) -> void:`
- L78: `func lines() -> Array:`

### `scripts/ui/widgets/upgrade_tree.gd`

- L22: `func setup(side_: String) -> UpgradeTree:`
- L43: `static func depth(side_: String, id: String) -> int:`
- L50: `func update(owned_: Variant, funds_: int) -> void:`
- L73: `func selected_id() -> String:`
- L78: `func move(d: int) -> void:`
- L83: `func activate() -> void:`
- L89: `func _detail() -> void:`

### `scripts/util/big_nat.gd`

- L15: `static func of(v: int) -> BigNat:`
- L23: `func copy() -> BigNat:`
- L29: `func _trim() -> void:`
- L34: `func is_zero() -> bool:`
- L38: `func bit_length() -> int:`
- L50: `func to_int() -> int:`
- L57: `func mul_small(k: int) -> BigNat:  # k < 2^30`
- L69: `func add_small(k: int) -> BigNat:  # k < 2^24`
- L82: `func mul_pow10(k: int) -> BigNat:`
- L91: `func shl(s: int) -> BigNat:`
- L113: `static func cmp(a: BigNat, b: BigNat) -> int:`
- L123: `func sub(b: BigNat) -> BigNat:`
- L134: `static func divmod(a: BigNat, b: BigNat) -> Array:`
- L154: `func _shr1() -> void:`
- L164: `func shr_sticky(s: int) -> bool:`
- L188: `func div_pow10_sticky(k: int) -> bool:`
- L199: `func div_small(k: int) -> int:`
- L209: `func to_decimal() -> String:`

### `scripts/util/np_random.gd`

- L27: `static func _mul32(a: int, b: int) -> int:`
- L31: `static func _hashmix(value: int, hc: Array) -> int:`
- L39: `static func _mix(x: int, y: int) -> int:`
- L46: `func _step() -> void:`
- L62: `static func _limbs_from_u64(hi: int, lo: int) -> Array:`
- L70: `func seed(n: int) -> void:`
- L122: `func next_u64() -> int:`
- L133: `func random() -> float:`
- L137: `func uniform(lo: float, hi: float) -> float:`
- L141: `func random_array(n: int) -> PackedFloat64Array:`
- L149: `func uniform_array(n: int, lo: float, hi: float) -> PackedFloat64Array:`

### `scripts/util/py.gd`

- L10: `static func sorted_by(items: Array, key: Callable, reverse := false) -> Array:`
- L21: `static func _merge_sort(a: Array, reverse: bool) -> Array:`
- L49: `static func min_by(items: Array, key: Callable, default = null):`
- L63: `static func max_by(items: Array, key: Callable, default = null):`
- L76: `static func any(items: Array, pred: Callable) -> bool:`
- L83: `static func all(items: Array, pred: Callable) -> bool:`
- L90: `static func count(items: Array, pred: Callable) -> int:`
- L98: `static func sum_by(items: Array, f: Callable) -> float:`
- L105: `static func first(items: Array, pred: Callable, default = null):`
- L112: `static func filter(items: Array, pred: Callable) -> Array:`
- L121: `static func fmod(a: float, b: float) -> float:`
- L126: `static func imod(a: int, b: int) -> int:`
- L131: `static func idiv(a: int, b: int) -> int:`
- L138: `static func wrap180(a: float) -> float:`
- L142: `static func clamp(v: float, lo: float, hi: float) -> float:`
- L146: `static func hypot(x: float, y: float) -> float:`
- L150: `static func dist2(a: Array, b: Array) -> float:`
- L154: `static func round_n(x: float, n: int) -> float:`
- L159: `static func round_int(x: float) -> int:`
- L164: `static func f(x: float, n := 0) -> String:`
- L169: `static func money(x, n := 0) -> String:`
- L174: `static func f0(x: float, width: int) -> String:`
- L181: `static func degrees(r: float) -> float:`
- L185: `static func radians(d: float) -> float:`
- L190: `static func keep_last(lst: Array, n: int) -> void:`
- L198: `static func truthy(x) -> bool:`
- L217: `static func float_repr(v: float) -> String:`
- L227: `static func json(v) -> String:`

### `scripts/util/py_math.gd`

- L19: `static func _two_prod(a: float, b: float) -> Array:`
- L31: `static func frexp(x: float) -> Array:`
- L43: `static func _vector_norm(vec: Array, mx: float, found_nan: bool) -> float:`
- L73: `static func hypot(x: float, y: float) -> float:`
- L79: `static func hypot3(x: float, y: float, z: float) -> float:`
- L88: `static func log1p(x: float) -> float:`
- L162: `static func _hi(x: float) -> int:`
- L170: `static func _with_hi(x: float, hi: int) -> float:`
- L178: `static func _s32(v: int) -> int:`
- L185: `static func _decompose(x: float) -> Array:`
- L193: `static func _round_2_10(n: BigNat, a: int, b: int) -> BigNat:`
- L205: `static func _scaled_round_exact(x: float, k: int) -> BigNat:`
- L220: `static func _scaled_round(x: float, n: int) -> BigNat:`
- L231: `static func _to_double(n: BigNat, b: int) -> float:`
- L254: `static func _nearbyint(v: float) -> float:`
- L264: `static func round_n(x: float, ndigits: int) -> float:`
- L279: `static func round_int(x: float) -> int:`
- L283: `static func _neg(x: float) -> bool:`
- L288: `static func fmt(x: float, decimals: int) -> String:`
- L303: `static func fmt_thousands(x: float, decimals: int) -> String:`
- L320: `static func _sig_digits(x: float, prec: int) -> Array:`
- L337: `static func repr(x: float) -> String:`
- L364: `static func _format_g(digits: String, e10: int, prec: int) -> String:`
- L383: `static func parse(text: String) -> float:`

### `scripts/util/py_random.gd`

- L25: `func _init() -> void:`
- L30: `static func _mul32(a: int, b: int) -> int:`
- L35: `func _init_genrand(s: int) -> void:`
- L43: `func _init_by_array(key: Array) -> void:`
- L73: `func _seed_u64(n: int) -> void:`
- L85: `func seed(n: int) -> void:`
- L90: `func seed_float(x: float) -> void:`
- L94: `func genrand() -> int:`
- L115: `func random() -> float:`
- L121: `func uniform(a: float, b: float) -> float:`
- L125: `func getrandbits(k: int) -> int:`
- L143: `static func _bit_length(v: int) -> int:`
- L151: `func randbelow(n: int) -> int:`
- L161: `func randint(a: int, b: int) -> int:`
- L165: `func gauss(mu: float, sigma: float) -> float:`
- L180: `func shuffle(items: Array) -> Array:`
- L191: `func choice(items: Array) -> Variant:`
- L198: `func choices_index(weights: PackedFloat64Array, k: int) -> PackedInt32Array:`
- L225: `func choices_uniform_index(n: int, k: int) -> PackedInt32Array:`
- L232: `func get_state() -> Array:`
- L242: `func set_state(s: Array) -> void:`
- L253: `static func _py_hash_double(v: float) -> int:`

### `scripts/util/terrain.gd`

- L42: `static func _f32(x: float) -> float:`
- L47: `static func _clip(v: float, lo: float, hi: float) -> float:`
- L52: `static func _smoothstep(e0: float, e1: float, x: float) -> float:`
- L58: `static func _value_noise(rng: NpRandom, n: int, cells: int) -> PackedFloat64Array:`
- L90: `static func _fbm(rng: NpRandom, n: int, base_cells: int, octaves: int) -> PackedFloat64Array:`
- L109: `static func _normalise(v: PackedFloat64Array) -> void:`
- L119: `static func _cv() -> PackedFloat64Array:`
- L128: `static func _contains(af: Dictionary, px: float, py: float, margin: float) -> bool:`
- L136: `func _parse_fields(airfields: Array) -> void:`
- L148: `static func _sample64(h: PackedFloat64Array, x: float, y: float) -> float:`
- L159: `func generate(p_seed: int, airfields: Array) -> void:`
- L167: `func generate_custom(p_seed: int, params: Dictionary, airfields: Array) -> void:`
- L175: `static func _cache_key(what: Array) -> String:`
- L181: `func _load_cached(key: String, airfields: Array) -> bool:`
- L204: `func _save_cached(key: String) -> void:`
- L214: `func _generate(p_seed: int, airfields: Array) -> void:`
- L245: `func _shape_fields(h: PackedFloat64Array, p_seed := 0) -> void:`
- L307: `func _plant_trees(p_seed: int) -> void:`
- L354: `func _generate_custom(p_seed: int, params: Dictionary, airfields: Array) -> void:`
- L408: `static func _at(v: PackedFloat64Array, fx: float, fy: float) -> float:`
- L424: `func _naturalise(h: PackedFloat64Array, p_seed: int) -> void:`
- L496: `func set_data(heights: PackedFloat32Array, trees: PackedFloat32Array, airfields: Array) -> void:`
- L503: `static func _bucket_key(bi: int, bj: int) -> int:`
- L507: `static func _floordiv_f32(x: float) -> int:`
- L512: `func _bucket_trees() -> void:`
- L521: `func get_heights() -> PackedFloat32Array:`
- L525: `func get_trees() -> PackedFloat32Array:`
- L529: `func get_field_elev() -> Dictionary:`
- L533: `func tree_count() -> int:`
- L538: `func height(x: float, y: float) -> float:`
- L559: `func height64(x: float, y: float) -> float:`
- L571: `func _heights_many_one(x: float, y: float) -> float:`
- L583: `func heights_many(xs: PackedFloat64Array, ys: PackedFloat64Array) -> PackedFloat64Array:`
- L592: `func line_of_sight(ax: float, ay: float, az: float, bx: float, by: float, bz: float, step: float) -> bool:`
- L603: `func tree_hit(x: float, y: float, z: float, radius: float) -> bool:`
- L625: `func tree_top(x: float, y: float, radius: float, p_floor: float) -> float:`

