class_name PilotApp
extends Node3D
## The pilot's seat: world scene, aircraft, cameras, keyboard/mouse/joystick
## input, HUD and ground menus (port of render/app.py SkyrunnerApp).
##
## A bot (AutoRunner) can fly instead of the keyboard (--watch). A HostServer,
## if given, is pumped before and published after each session update.

const CAM_MODES := ["chase", "cockpit", "tower"]

## The pause menu's way out: "load" (the last save), "lobby" or "desktop". Main
## acts on it; with nobody listening, "desktop" quits here and the rest do too.
signal leave(to: String)

## The flight keys are rebindable actions (ControlsConfig: F8), the analogue axes FlightAxes.
const CREW_KEYS := {KEY_N: "transponder", KEY_U: "autopilot", KEY_K: "kick", KEY_O: "call_boat", KEY_V: "pump", KEY_I: "turn_around"}
const PRESS_KEYS := {KEY_ENTER: "confirm", KEY_KP_ENTER: "confirm"}
const TAXI_MS := 13.0  ## m/s the cab averages
const TAXI_ROAD := 1.3  ## roads wind: this much longer than the crow flies
const TAXI_BASE := 15  ## $ flag-fall
const TAXI_PER_M := 250.0  ## ... and a dollar a quarter-kilometre
const TAXI_STEPS_PER_FRAME := 30  ## sim seconds run per frame during a ride
const MENU_KEYS := {KEY_UP: "up", KEY_DOWN: "down", KEY_LEFT: "left", KEY_RIGHT: "right", KEY_ENTER: "enter",
	KEY_KP_ENTER: "enter", KEY_A: "a", KEY_PLUS: "+", KEY_EQUAL: "+", KEY_KP_ADD: "+", KEY_MINUS: "-", KEY_KP_SUBTRACT: "-", KEY_F: "f", KEY_G: "g", KEY_Q: "q"}

const HELP_TEXT := """SKYRUNNER - controls

Flight   W/S or UP/DOWN pitch     A/D or LEFT/RIGHT roll     Q/E rudder / nosewheel
         Flight assist (ESC menu): with no key held the wings level and the pitch holds; taps are gentle
         R/F or PGUP/PGDN throttle (hold; a tap is a few %)   Z ramp to full   X ramp to idle   (Z Z / X X: instant)
         G flaps down   T flaps up   [ / ] pitch trim   B or SPACE brakes
         Y toggle mouse yoke (mouse position = stick)   joystick / gamepad work too
         F8 controls: rebind any flight key or button; bind a yoke, throttle quadrant, pedals and
            toe brakes (several devices) with invert, deadzone and expo; the colour-safe palette
View     C cycle camera (chase / cockpit / tower)    M big map    P pause   F2 time of day
Seats    F3 hand the aircraft to the AI (take another seat from a station) / take it back
Debug    F6 performance overlay: FPS, frame times, graphs (Debug Menu add-on, MIT)
Radio    F7 Radio Costa 88: synth music out of 1985
Learn    F10 skip a tutorial step   SHIFT+F10 tutorial on / off (the lobby's Tutorial box, or --tutorial)
Screen   F9 filter: off / VHS / colour-blindness simulations (protan, deutan, tritan, mono)
Beta     F12 feedback bundle: a zip of what happened (build, machine, flight, log, screenshot) to send back
On foot  TAB get out (parked) / back in    WASD walk  SHIFT run  SPACE jump  mouse look
         Guns (with a ground war): 1-4 pistol / rifle / machine gun / RPG from the armoury  H holster  R reload  LMB fire
         CAR  a parked car stands beside the aircraft: E at it to get in, W / S throttle and brake, A / D steer,
            SPACE handbrake, E to get out (the road is fast, anywhere else a crawl)
         E use (job board, fuel, hangar, the boss's desk)   F torch   T the phone: crew, buyers, lawyer,
            the Family, the General, the desk, dispatch - and a taxi (fare up front) to the aircraft, the desk,
            the job board, the hangar or a stash house
         At the boss's desk (with a ground war): Q swaps the orders for squad command - CLICK a squad,
            RIGHT-CLICK the map to send it, buttons for melt away / hold / disband / raise one. Q again
            or ESC hands the squads straight back to the AI, the same as leaving the lieutenant's seat.
         I your pack: spare guns, rounds, medkits (24 kg; over 12 kg you slow down)   5 medkit
Ground   J job board   L load planner & fuel   H hangar, gear, crew (LEFT/RIGHT: upgrade trees)
Crew     N transponder on/off   7 squawk code (1200 VFR / 7700 / 7600 / 7500)
         U autopilot: holds course, U again routes you to an airfield (low with a hot load, direct
            at cruise otherwise - squawking either way unless there's already heat on you), U again off
         K kick a bale   O call the boat (SHIFT+O: the 1 s codeword - harder to DF)
         V ferry fuel pump   I push aircraft round (stopped)   ENTER continue   ESC close menu / pause menu
Family   SHIFT+F sit down with Sal Moretti: hear the offer, your man's read on it, press him for
         another, take it or leave it; pay or stall the tribute (1-4 answer, ENTER go on, ESC leave)
         SHIFT+Y / SHIFT+N take or turn down the newest offer without the talk, SHIFT+P pay the tribute
Trade    SHIFT+B Benny Ruiz and the buyers: sell cocaine, grass or rifles in bulk to the Morettis, the Company
         or (guns only) Los Cuervos. Our own loads (grass at the bush strips; cocaine once the Colombians call)
         go into the stash; dealers (hire them from Manny) sell it on the corners
Haul     SHIFT+H logistics: product and cash sit in the stashes - truck them (to the club, a buyer, the corners) or fly cash bags (C load, U unload)
Court    arrested (with a court): SHIFT+L your lawyer - bail or a bond, a better lawyer, motions to
         suppress / discovery / more time, the plea, the witness, the judge, a deal; the appeal inside
Crew     SHIFT+W Manny Ortega's hiring hall: hire soldiers, drivers, mules, lookouts, an accountant,
         contract pilots; bonuses; lawyers for the jailed. Payday every 10 min - pay them or else
Island   Isla Soberana is over the southern horizon (SOB): cheap loads, the General's MiGs, and the
         task force can't follow you past the line. SHIFT+G the General's aide on the radio:
         passage, the island's news, mules and containers with customs' odds. SHIFT+U four mules
         SHIFT+I a container (quick orders). Land there and the aide meets you on the ramp.
Radar    fly across a radar's beam or slow and the MTI loses you; low over rough sea or in rain the
         clutter hides you; the detector shows who's painting you and from where

Goal: haul passengers & cargo between strips for money. Balance the load:
too heavy = long roll & weak climb, CG too far aft = pitch-up / stall,
too far forward = can't flare. Short strips pay more.
Hot jobs pay big. Squawking looks legit; flying dark (transponder off) is
invisible only below the radar floor - and a squawk that vanishes on radar
is a red flag. Airdrops: fly low and slow over the boat, K to kick
(solo: autopilot first). Police within 350 m for a few seconds = busted."""

var nerves: Nerves
var _weather_rev := -1
var s: Session
var quality: Quality
var bot = null  ## AutoRunner
var server = null  ## HostServer
var scene: WorldScene
var cam: Camera3D
var player: Node3D
var props: Array = []
var ac_lights := {}
var dust: GPUParticles3D
var _player_key := ""
var hud: Hud
var menus := {}
var help: Control
var briefing: Label
var glareshield: Control
var ui: CanvasLayer
var cam_mode := "chase"
var mouse_yoke := false
var paused := false
var _pressed := {}
var _cam_pos = null
var pursuer_nodes := {}  ## Pursuer (instance id) -> [node, spinners, lights]
var tutorial_panel: TutorialPanel = null  ## the tutorial's lesson and tips (Tutorial)
var logistics_menu: LogisticsMenu = null  ## SHIFT+H
var squads: SquadRender = null  ## the ground war's men and vehicles (sessions with one)
var _graphics := "high"
var boat_nodes := {}
var bale_nodes := {}
var beacons: Array = []  ## [key, [nodes]]
var _frame := 0
var on_foot := false
var car: Car = null  ## the starter car (made the first time you step out of the aircraft)
var driving: Car = null  ## the car you are in, if you are
var _blown := {}  ## police squad id -> sim time you last ran its checkpoint
const CHECKPOINT_RUN_M := 45.0  ## closer than this to a police checkpoint ...
const CHECKPOINT_RUN_MS := 6.0  ## ... faster than this is running it
const CHECKPOINT_HEAT := 6.0  ## suspicion for running one
const CHECKPOINT_AGAIN_S := 120.0
var taxi_left := 0.0  ## sim seconds of a taxi ride still to go: the world runs ahead of the clock while it does
var _taxi_to: Dictionary = {}
var taxi_label: Label
var walker: Walker = null
var gun: Gunplay = null
var _auto_bot := false  ## the AI took the stick because nobody's in the pilot seat  ## the walker's gun (sessions with a ground war)
var ground_body: StaticBody3D = null
var foot_prompt: Label
var aircraft_body: StaticBody3D = null


func setup(sess: Session, graphics := "high", bot_ = null, server_ = null) -> PilotApp:
	s = sess
	quality = Quality.get_preset(graphics)
	bot = bot_
	server = server_
	if server != null:
		server.attach(sess)
	name = "PilotApp"
	scene = WorldScene.new().setup(sess.world, quality)
	add_child(scene)
	_graphics = graphics
	if sess.ground != null:
		_make_squads()
	nerves = Nerves.new().setup()
	nerves.layer = 0  # over the 3D view, under the HUD (layer 1) and menus
	add_child(nerves)
	sound = Soundscape.new().setup(self)  # engine, wind, radio, the world, the music
	add_child(sound)
	effects = FX.new()
	effects.name = "effects"
	add_child(effects)
	ControlsConfig.ensure()  # the flight keys as actions, with the player's saved bindings
	var look := ControlsConfig.settings()
	s.keyboard_assist = bool(look.assist)
	UIStyle.set_palette(look.palette)
	Speech.set_enabled(bool(look.speak))
	screen_filter = ScreenFilter.new()
	add_child(screen_filter)
	screen_filter.set_mode(look.filter)
	cam = Camera3D.new()
	cam.near = 0.5
	cam.far = 60000.0
	cam.fov = 70
	add_child(cam)
	cam.current = true
	_build_player()
	ui = CanvasLayer.new()
	add_child(ui)
	glareshield = _build_glareshield()
	ui.add_child(glareshield)
	hud = Hud.new().setup(sess)
	ui.add_child(hud)
	for k in [["j", JobMenu], ["l", LoadMenu], ["h", HangarMenu], ["hq", HQMenu], ["intel", HQMenu], ["phone", PhoneMenu], ["taxi", TaxiMenu]]:
		var m: GameMenu = k[1].new()
		ui.add_child(m)
		if k[0] == "intel":
			m.intel = true
		if k[0] == "phone":
			m.called.connect(_phone_call)
		if k[0] == "taxi":
			m.stops_fn = taxi_stops
			m.chosen.connect(_taxi_go)
		m.setup(sess)
		m.closed.connect(_menu_closed)
		menus[k[0]] = m
	foot_prompt = UIStyle.label("", 20, UIStyle.WHITE)
	foot_prompt.add_theme_stylebox_override("normal", UIStyle.panel_box(Color(0, 0, 0, 0.55)))
	foot_prompt.set_anchors_preset(Control.PRESET_CENTER)
	foot_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	foot_prompt.position += Vector2(0, 70)
	foot_prompt.visible = false
	ui.add_child(foot_prompt)
	help = _help_overlay(HELP_TEXT, UIStyle.WHITE)
	var ver := UIStyle.label(Beta.label() + "   F12 feedback", 12, UIStyle.DIM)
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ver.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ver.position -= Vector2(8, 4)
	ver.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(ver)
	briefing = _overlay("", Color(1, 0.85, 0.5))
	sess.say("F1 for controls. [J] to see the job board.")
	return self


func _overlay(text: String, col: Color) -> Label:
	var l := UIStyle.label(text, 16, col, UIStyle.mono())
	l.add_theme_stylebox_override("normal", UIStyle.panel_box(Color(0, 0, 0, 0.82)))
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BOTH
	l.visible = false
	ui.add_child(l)
	return l


## F1's controls screen: long enough to run off a 720p window, so it scrolls (mouse wheel, or drag the
## bar) instead of being cropped. Same panel proportions as ControlsMenu (F8), so the two screens match.
func _help_overlay(text: String, col: Color) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel_box(Color(0, 0, 0, 0.88)))
	panel.anchor_left = 0.08
	panel.anchor_right = 0.92
	panel.anchor_top = 0.05
	panel.anchor_bottom = 0.95
	panel.visible = false
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	scroll.add_child(UIStyle.label(text, 16, col, UIStyle.mono()))
	ui.add_child(panel)
	return panel


## Cockpit view: a dark glareshield along the bottom and a waterline marker
## showing where the nose points (the 3D airframe is hidden in this view).
func _build_glareshield() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dash := ColorRect.new()
	dash.color = Color(0.08, 0.08, 0.09)
	dash.anchor_left = 0
	dash.anchor_right = 1
	dash.anchor_top = 0.81
	dash.anchor_bottom = 1
	dash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dash)
	var mark := Line2D.new()
	mark.width = 3
	mark.default_color = Color(1, 0.8, 0.2)
	mark.points = PackedVector2Array([Vector2(-80, 0), Vector2(-33, 0), Vector2(-17, 20), Vector2(0, 0), Vector2(17, 20),
		Vector2(33, 0), Vector2(80, 0)])
	root.add_child(mark)
	root.resized.connect(func(): mark.position = root.size / 2)
	root.visible = false
	return root


# ------------------------------------------------------------ scene
func _build_player() -> void:
	if player != null:
		player.queue_free()
	var r := Models.build_aircraft(s.spec.visual, s.fm.mass.gear_height_ft * 0.3048, quality)
	player = r[0]
	props = r[1]
	ac_lights = r[2]
	dust = WorldScene.make_dust()
	dust.position = Vector3(0, -s.fm.mass.gear_height_ft * 0.3048, 1.5)
	player.add_child(dust)
	add_child(player)
	_player_key = s.spec.key


func _sync_beacons() -> void:
	var want := []
	for j in s.active_jobs:
		var key := [j.dest, j.drop_point]
		if not want.has(key):
			want.append(key)
	want.sort_custom(func(a, b): return str(a) < str(b))
	if want == beacons.map(func(b): return b[0]):
		return
	for b in beacons:
		for n in b[1]:
			n.queue_free()
	beacons.clear()
	for key in want:
		var nodes := []
		if key[1] != null:  # rendezvous at sea: one tall blue marker
			var b := Models.build_beacon(400, 10, Color(0.3, 0.6, 1.0, 0.35))
			b.position = MeshBuilder.to_godot([key[1][0], key[1][1], 0.0])
			add_child(b)
			nodes.append(b)
		else:
			var af := World.airfield(key[0])
			for end in [0, 1]:
				var t: Array = af.threshold(end)
				var b := Models.build_beacon()
				b.position = MeshBuilder.to_godot([t[0], t[1], s.world.airfield_elev(af)])
				add_child(b)
				nodes.append(b)
		beacons.append([key, nodes])


# ------------------------------------------------------------ input
func _active_menu() -> GameMenu:
	for m in menus.values():
		if m.visible:
			return m
	return null


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventJoypadButton and ev.pressed and _active_menu() == null and not on_foot:
		_flight_press(ev)
		return
	if ev is InputEventKey and ev.pressed:
		var k: int = ev.physical_keycode if ev.physical_keycode else ev.keycode
		var m := _active_menu()
		if m != null:
			if k == KEY_ESCAPE:
				m.close()
			elif MENU_KEYS.has(k):
				m.key(MENU_KEYS[k])
			elif k in [KEY_J, KEY_L, KEY_H]:
				_toggle_menu(OS.get_keycode_string(k).to_lower())
			get_viewport().set_input_as_handled()
			return
		if ev.echo:
			return
		if k == KEY_TAB:
			_toggle_on_foot()
			get_viewport().set_input_as_handled()
			return
		if on_foot and driving != null:
			match k:
				KEY_E:
					_exit_car()
				KEY_ESCAPE:
					open_pause()
				KEY_M:
					hud.minimap.toggle()
				KEY_F1:
					help.visible = not help.visible
			get_viewport().set_input_as_handled()
			return
		if on_foot:
			if gun != null:
				var gk := OS.get_keycode_string(k).to_lower()
				if gk in ["1", "2", "3", "4", "h", "r"] and gun.key(gk):
					get_viewport().set_input_as_handled()
					return
			if s.foot != null and k == KEY_5:
				var err: String = s.foot.use_medkit()
				s.say(err if err != "" else "Patched up: %d health." % int(s.foot.hp))
				get_viewport().set_input_as_handled()
				return
			if s.foot != null and k == KEY_I:
				toggle_pack()
				get_viewport().set_input_as_handled()
				return
			match k:
				KEY_E:
					walker.use()
				KEY_F:
					walker.toggle_torch()
				KEY_T:
					_open("phone")  # the phone: the crew, the buyers, the lawyer, the desk without the walk
				KEY_ESCAPE:
					if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
						Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
					else:
						open_pause()
				KEY_M:
					hud.minimap.toggle()
				KEY_F1:
					help.visible = not help.visible
				KEY_F2:
					scene.set_hour(scene.hour + 3.0)
			get_viewport().set_input_as_handled()
			return
		if ev.shift_pressed and k == KEY_W and s.payroll != null:
			open_talk("crew")  # Manny Ortega's hiring hall
		elif ev.shift_pressed and k == KEY_F10:
			if s.tutorial == null:
				Tutorial.new().attach(s)
				s.say("Tutorial on.")
			else:
				s.tutorial.set_enabled(not s.tutorial.enabled)
		elif ev.shift_pressed and k == KEY_H and s.logistics != null:
			toggle_logistics()  # where the product and the cash are; trucks; cash bags
		elif ev.shift_pressed and k == KEY_B and s.trade != null:
			open_talk("buyers")  # Benny Ruiz: who's buying, and at what
		elif ev.shift_pressed and k == KEY_L and s.court != null:
			open_talk("lawyer")  # your lawyer: bail, motions, the plea, a deal, the appeal
		elif ev.shift_pressed and k == KEY_F and s.family != null:
			open_talk("family")  # a sit-down with the Family
		elif ev.shift_pressed and k == KEY_G and s.island != null:
			open_talk("general")  # the General's aide on the island frequency
		elif ev.shift_pressed and k in [KEY_U, KEY_I] and s.island != null:
			# Isla Soberana quick orders: Shift+U four mules, Shift+I a container
			var r: Array = s.command(Roles.PILOT, "island_ship", {"method": "mules" if k == KEY_U else "ship", "amount": 4 if k == KEY_U else 500})
			if not r[0]:
				s.say(r[1])
		elif ev.shift_pressed and k in [KEY_Y, KEY_N, KEY_P] and s.family != null:
			# the Family's newest offer: Shift+Y take it, Shift+N turn it down; Shift+P pay the tribute
			var r: Array
			if k == KEY_P:
				r = s.command(Roles.PILOT, "pay_tribute", {})
			elif s.family.offers.is_empty():
				r = [false, "The Family has nothing on the table."]
			else:
				r = s.command(Roles.PILOT, "family_accept" if k == KEY_Y else "family_decline", {"id": s.family.offers.back().id})
			if not r[0]:
				s.say(r[1])
		elif _flight_press(ev):
			pass
		elif PRESS_KEYS.has(k):
			_pressed[PRESS_KEYS[k]] = true
		elif k == KEY_O and ev.shift_pressed:
			var r: Array = s.command(Roles.PILOT, "call_boat", {"brief": true})  # the codeword burst
			if not r[0]:
				s.say(r[1])
		elif CREW_KEYS.has(k):
			var r: Array = s.command(Roles.PILOT, CREW_KEYS[k], {})
			if not r[0]:
				s.say(r[1])
		elif k == KEY_7:
			# cycle the Mode A code: VFR, then the three emergency codes
			var codes := ["1200", "7700", "7600", "7500"]
			var r: Array = s.command(Roles.PILOT, "squawk", {"code": codes[(codes.find(s.squawk_code) + 1) % codes.size()]})
			if not r[0]:
				s.say(r[1])
		elif k in [KEY_J, KEY_L, KEY_H]:
			_toggle_menu(OS.get_keycode_string(k).to_lower())
		elif k == KEY_ESCAPE:
			if help.visible:
				help.visible = false
			else:
				open_pause()
		elif k == KEY_C:
			cam_mode = CAM_MODES[(CAM_MODES.find(cam_mode) + 1) % CAM_MODES.size()]
			_cam_pos = null
		elif k == KEY_M:
			hud.minimap.toggle()
		elif k == KEY_Y:
			mouse_yoke = not mouse_yoke
			s.say("Mouse yoke %s" % ("ON - mouse position is the stick" if mouse_yoke else "OFF"))
		elif k == KEY_P:
			paused = not paused
		elif k == KEY_F10 and s.tutorial != null and s.tutorial.enabled:
			s.tutorial.skip()
		elif k == KEY_F1:
			help.visible = not help.visible
		elif k == KEY_F2:
			scene.set_hour(scene.hour + 3.0)
			s.say("Time %02d:00" % int(scene.hour))
		elif k == KEY_F3:
			toggle_ai_pilot()
		elif k == KEY_F6:
			cycle_debug_menu()
		elif k == KEY_F8:
			toggle_controls()
		elif k == KEY_F9:
			var mode := screen_filter.cycle()
			ControlsConfig.save_setting("filter", mode)
			s.say("Screen: %s" % ScreenFilter.LABELS[mode])
		elif k == KEY_F12:
			var path := Beta.report(s, get_viewport())
			s.say("Feedback bundle saved: %s" % ProjectSettings.globalize_path(path) if path != "" else "Couldn't write the feedback bundle.")
		elif k == KEY_F7 and sound != null:
			s.say("Radio Costa 88: %s" % ("on - hits from 1985" if sound.toggle_music() else "off"))


var debug_menu: CanvasLayer = null
var effects: FX = null  ## fire, smoke, explosions, splashes
var _bale_state := {}
var screen_filter: ScreenFilter = null
var controls_menu: ControlsMenu = null
var pack_menu: PackMenu = null
var sound: Soundscape = null
var talk: TalkBalloon = null  ## a conversation on screen (the Family, the General's aide)
var _offers_seen := {}
var _was_on_island := false
var _court_stage := ""


## Open a conversation (dialogue/<name>.dialogue) from the pilot's seat.
func open_talk(name: String, title := "start") -> TalkBalloon:
	if talk != null and is_instance_valid(talk):
		return talk
	talk = Talk.open(self, name, title, LocalLink.new(s, Roles.PILOT, false))
	if s.tutorial != null:
		s.tutorial.note("talk_" + name)
	if talk != null:
		talk.finished.connect(func(): talk = null)
	return talk


## Word that someone wants to talk, and the aide on the ramp when you land on the island.
func _talk_cues() -> void:
	if s.family != null:
		for o in s.family.offers:
			if not _offers_seen.has(o.id):
				_offers_seen[o.id] = true
				s.say("%s wants a word. SHIFT+F to sit down with him." % Talk.CAPO)
	if s.court != null:
		# the lawyer is there at the bail hearing and when the sentence comes down
		var st := s.court.stage()
		if st != _court_stage and st in ["bail", "prison"]:
			open_talk("lawyer")
		_court_stage = st
	var on_island: bool = s.island != null and s.parked and s.location == Island.CODE
	if on_island and not _was_on_island:
		open_talk("general", "landing")
	_was_on_island = on_island


## F6: the performance overlay (Calinou's Debug Menu, MIT, addons/debug_menu):
## off -> FPS and frame time -> the full graphs and hardware.
func cycle_debug_menu() -> void:
	if DisplayServer.get_name() == "headless":
		return  # nothing to draw on (and its hardware query thread never returns without a GPU)
	if debug_menu == null:
		if not InputMap.has_action("cycle_debug_menu"):
			InputMap.add_action("cycle_debug_menu")  # its own key would be F3, the AI pilot's
		var scn := load("res://addons/debug_menu/debug_menu.tscn") as PackedScene
		if scn == null:
			return
		debug_menu = scn.instantiate()
		add_child(debug_menu)
	debug_menu.style = wrapi(int(debug_menu.style) + 1, 0, 3)  # hidden, compact, detailed


## The one-shot flight actions (flaps, throttle cut/full) from whatever they're bound to.
func _flight_press(ev: InputEvent) -> bool:
	for n in ControlsConfig.PRESSED:
		if ev.is_action_pressed(ControlsConfig.action(n)):
			_pressed[n] = true
			return true
	return false


## SHIFT+H: logistics - the stashes' product and cash, the trucks, cash bags on and off.
func toggle_logistics() -> void:
	if logistics_menu != null and is_instance_valid(logistics_menu):
		logistics_menu.close()
		return
	logistics_menu = LogisticsMenu.new()
	logistics_menu.pilot = true
	logistics_menu.view_fn = func() -> Dictionary: return s.logistics.view() if s.logistics != null else {}
	logistics_menu.cmd_fn = func(n: String, a: Dictionary) -> Array: return s.command(Roles.PILOT, n, a)
	logistics_menu.closed.connect(func(): Input.mouse_mode = Input.MOUSE_MODE_VISIBLE)
	ui.add_child(logistics_menu)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## I on foot: the pack - what you carry, its weight, and trading with the armoury.
func toggle_pack() -> void:
	if pack_menu != null and is_instance_valid(pack_menu):
		pack_menu.close()
		return
	pack_menu = PackMenu.new()
	pack_menu.foot = s.foot
	pack_menu.near_aircraft = func() -> bool: return walker != null and walker.global_position.distance_to(player.global_position) < 15.0
	ui.add_child(pack_menu)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if walker != null:
		walker.look_enabled = false
	pack_menu.closed.connect(func():
		pack_menu = null
		if gun != null:
			gun._refresh_viewmodel()
		_menu_closed())


## F8: the controls panel (keys, buttons, axes, the palette).
func toggle_controls() -> void:
	if controls_menu != null and is_instance_valid(controls_menu):
		controls_menu.close()
		return
	controls_menu = ControlsMenu.new()
	ui.add_child(controls_menu)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	controls_menu.closed.connect(func():
		controls_menu = null
		_menu_closed())


var pause_menu: PauseMenu = null
var _paused_before := false  ## P had paused the game before the menu opened


## ESC: the pause menu. The game stops under it, unless friends are flying in it.
func open_pause() -> void:
	if pause_menu != null and is_instance_valid(pause_menu):
		return
	var hosting := server != null
	pause_menu = PauseMenu.new().setup({"save": s.save_path != "", "load": s.save_path != "" and not hosting,
		"graphics": true, "controls": true, "lobby": true, "assist": true},
		"The game runs on: remote seats are live." if hosting else "Paused")
	ui.add_child(pause_menu)
	pause_menu.chosen.connect(_on_pause_choice)
	_paused_before = paused
	if not hosting:
		paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if walker != null:
		walker.look_enabled = false


func close_pause() -> void:
	if pause_menu == null or not is_instance_valid(pause_menu):
		return
	pause_menu.close()
	pause_menu = null
	paused = _paused_before
	_menu_closed()


func _on_pause_choice(action: String) -> void:
	match action:
		"resume":
			close_pause()
		"assist":
			s.keyboard_assist = bool(ControlsConfig.settings().assist)
		"save":
			s.save()
			pause_menu.say("Saved." if s.parked else "Saved: in the air, so you'll start again at %s." % World.airfield(s.save_location()).name)
		"controls":
			close_pause()
			toggle_controls()
		"load", "lobby", "desktop":
			if action != "load":
				s.save()
			close_pause()
			if leave.get_connections().is_empty():
				get_tree().quit()
			else:
				leave.emit(action)


func _unhandled_key_input(_ev: InputEvent) -> void:
	pass


func _input(ev: InputEvent) -> void:
	# click to grab the mouse again while walking
	if on_foot and ev is InputEventMouseButton and ev.pressed and _active_menu() == null and pause_menu == null and controls_menu == null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _menu_closed() -> void:
	if on_foot and pause_menu == null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		walker.look_enabled = true


# ------------------------------------------------------------ on foot
func _toggle_on_foot() -> void:
	if driving != null:
		s.say("Get out of the car first (E).")
		return
	_sync_scene(0.0)  # the aircraft node may not have been placed yet this frame
	if on_foot:
		var st: FlightModel.FlightState = s.state
		var d := walker.global_position.distance_to(player.global_position)
		if d > 9.0:
			s.say("Walk back to the aircraft to climb in (%.0f m away)." % d)
			return
		on_foot = false
		if gun != null:
			gun.teardown()
			gun.queue_free()
			gun = null
		walker.queue_free()
		walker = null
		if aircraft_body != null:
			aircraft_body.queue_free()
			aircraft_body = null
		cam.current = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		foot_prompt.visible = false
		s.say("Back in the %s." % s.spec.name)
		return
	if not s.parked:
		s.say("Stop at an airfield first.")
		return
	var st: FlightModel.FlightState = s.state
	if ground_body == null:
		ground_body = Walker.ground_body(s.world)
		add_child(ground_body)
	# the parked aircraft is solid
	aircraft_body = StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	var v := s.spec.visual
	bs.size = Vector3(v.span_m * 0.9, 2.2, v.length_m * 0.8)
	cs.shape = bs
	aircraft_body.add_child(cs)
	player.add_child(aircraft_body)
	walker = Walker.new().setup(s.world)
	add_child(walker)
	walker.used.connect(_on_use)
	_ensure_car(st)
	# out of the left door, a couple of metres clear of the wing root
	var h := deg_to_rad(st.heading)
	var lx := -cos(h)
	var ly := sin(h)
	walker.place(st.x + lx * (v.span_m * 0.5 + 1.2), st.y + ly * (v.span_m * 0.5 + 1.2), st.heading)
	walker.cam.current = true
	on_foot = true
	if s.tutorial != null:
		s.tutorial.note("on_foot")
	if s.foot != null:
		gun = Gunplay.new().setup(s, walker, squads, ui)
		gun.fx = effects
		add_child(gun)
	for m in menus.values():
		m.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	s.say("On foot. TAB to climb back in, E to use things, F for the torch%s." % (", 1-4 for a gun" if s.foot != null else ""))


## A number picked from the phone: the same call the Shift keys make from the cockpit, and the
## desk and dispatch without walking to them.
func _phone_call(action: String) -> void:
	match action:
		"desk":
			_open("hq")
		"logistics":
			toggle_logistics()
		"taxi":
			_open("taxi")
		_:
			var tk := open_talk(action)
			if tk != null and on_foot and walker != null:
				walker.look_enabled = false  # stand and talk
				tk.finished.connect(func():
					if on_foot and walker != null:
						walker.look_enabled = true)


## Where a taxi will take you: the aircraft, whatever this airfield has (the boss's desk, the job board,
## the load planner, the hangar) and each stash house still standing - with the distance, the ride and
## the fare.
func taxi_stops() -> Array:
	var out := []
	if walker == null:
		return out
	var here := Vector2(walker.global_position.x, -walker.global_position.z)
	var st: FlightModel.FlightState = s.state
	var h := deg_to_rad(st.heading)
	var half: float = s.spec.visual.span_m * 0.5 + 1.2
	out.append({"name": "The %s" % s.spec.name, "at": Vector2(st.x - cos(h) * half, st.y + sin(h) * half), "heading": st.heading})
	for pair in [["hq_org", "The boss's desk"], ["jobs", "The job board"], ["load", "The load planner"], ["hangar", "The hangar"]]:
		for a in _find_areas(scene, pair[0], []):
			if pair[0] != "hq_org" and a.get_meta("field", s.location) != s.location:
				continue
			var p: Vector3 = a.global_position
			var back: Vector3 = a.get_parent().global_transform.basis.z.normalized()  # buildings face local -z
			var spot: Vector3 = p - back * 1.2
			out.append({"name": pair[1], "at": Vector2(spot.x, -spot.z), "heading": rad_to_deg(atan2(p.x - spot.x, -(p.z - spot.z)))})
			break
	if s.stash_net != null:
		for stash in s.stash_net.live():
			var at := Vector2(stash.x, stash.y)
			if s.ground != null and s.ground.graph.road_nodes > 0:
				at = s.ground.graph.nodes[s.ground.graph.nearest(at)]  # the street outside
			out.append({"name": "%s (stash house)" % stash.name, "at": at, "heading": 0.0})
	for r in out:
		var d: float = here.distance_to(r.at)
		r["dist"] = d
		r["secs"] = maxf(20.0, d * TAXI_ROAD / TAXI_MS)
		r["fare"] = TAXI_BASE + int(d / TAXI_PER_M)
	return out


func _find_areas(node: Node, action: String, out: Array) -> Array:
	if node is Area3D and node.get_meta("action", "") == action:
		out.append(node)
	for c in node.get_children():
		_find_areas(c, action, out)
	return out


## The taxi leaves: the fare is paid, the clock runs ahead (TAXI_STEPS_PER_FRAME sim seconds a frame)
## until the ride is over, and then the walker is put down at the other end.
func _taxi_go(i: int) -> void:
	var stops := taxi_stops()
	if i < 0 or i >= stops.size() or walker == null:
		return
	var stop: Dictionary = stops[i]
	if s.money < int(stop.fare):
		s.say("The driver wants $%d up front." % int(stop.fare))
		return
	s.money -= int(stop.fare)
	_taxi_to = stop
	taxi_left = float(stop.secs)
	walker.process_mode = Node.PROCESS_MODE_DISABLED
	walker.look_enabled = false
	if taxi_label == null:
		taxi_label = UIStyle.label("", 22, UIStyle.WHITE)
		taxi_label.add_theme_stylebox_override("normal", UIStyle.panel_box(Color(0, 0, 0, 0.6)))
		taxi_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		taxi_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		taxi_label.position += Vector2(0, 60)
		ui.add_child(taxi_label)
	taxi_label.visible = true
	s.say("To %s: about %d min, $%d." % [stop.name, int(ceil(float(stop.secs) / 60.0)), int(stop.fare)])


## While a ride is on, run the world ahead (parked and on foot, so whole-second steps are fine).
func _taxi_tick(inp, bc) -> void:
	if taxi_left <= 0.0:
		return
	var n := 0
	while taxi_left > 0.0 and n < TAXI_STEPS_PER_FRAME:
		var step := minf(taxi_left, 1.0)
		s.update(step, inp, bc)
		taxi_left -= step
		n += 1
	if taxi_label != null:
		taxi_label.text = "  In the taxi to %s ...  %d min to go  " % [_taxi_to.name, int(ceil(maxf(0.0, taxi_left) / 60.0))]
	if taxi_left <= 0.0:
		taxi_left = 0.0
		if walker != null:
			walker.process_mode = Node.PROCESS_MODE_INHERIT
			walker.look_enabled = true
			var at: Vector2 = _taxi_to.at
			walker.place(at.x, at.y, float(_taxi_to.heading))
		if taxi_label != null:
			taxi_label.visible = false
		s.say("Here you are: %s." % _taxi_to.name)


## The starter car: a parked car beside the aircraft's right wing, made the first time you step out.
func _ensure_car(st: FlightModel.FlightState) -> void:
	if car != null:
		return
	car = Car.new().setup(s.world, "org")
	add_child(car)
	var h := deg_to_rad(st.heading)
	var off: float = s.spec.visual.span_m * 0.5 + 9.0
	car.place(st.x + cos(h) * off, st.y - sin(h) * off, st.heading + 90.0)


## E at the car: get in (it takes the walker's place; the walker is parked, hidden, inside it).
func _enter_car() -> void:
	if car == null or walker == null or driving != null:
		return
	if walker.global_position.distance_to(car.global_position) > 6.0:
		s.say("The car is too far away.")
		return
	driving = car
	car.driven = true
	car.speed = 0.0
	walker.process_mode = Node.PROCESS_MODE_DISABLED
	walker.visible = false
	walker.look_enabled = false
	car.cam.current = true
	s.say("Driving: W / S throttle and brake, A / D steer, SPACE handbrake, E to get out.")


## Driving through a police checkpoint without slowing is noticed: suspicion on the runner's case, once per checkpoint
## every CHECKPOINT_AGAIN_S. Slowing down (under CHECKPOINT_RUN_MS) is a wave-through.
func _car_checkpoints() -> void:
	if driving == null or s.ground == null:
		return
	var here := driving.game_xy()
	for q: GroundWar.Squad in s.ground.of("police"):
		if q.tactic != "checkpoint" or q.pos().distance_to(here) > CHECKPOINT_RUN_M:
			continue
		if absf(driving.speed) < CHECKPOINT_RUN_MS:
			continue
		if s.time - float(_blown.get(q.id, -1e9)) < CHECKPOINT_AGAIN_S:
			continue
		_blown[q.id] = s.time
		var c = s.police.case("runner")
		c.suspicion = minf(100.0, c.suspicion + CHECKPOINT_HEAT)
		s.say("You ran the police checkpoint at %s." % s.ground.place_name(q.x, q.y))


## E again: get out on the driver's side, if it has all but stopped.
func _exit_car() -> void:
	if driving == null:
		return
	if absf(driving.speed) > 4.0:
		s.say("Slow down first.")
		return
	var out := driving.global_position - driving.global_transform.basis.x * 2.6
	walker.process_mode = Node.PROCESS_MODE_INHERIT
	walker.visible = true
	walker.look_enabled = true
	walker.place(out.x, -out.z, driving.heading_deg())
	walker.cam.current = true
	driving.driven = false
	driving.speed = 0.0
	driving = null


func _on_use(action: String, area: Area3D) -> void:
	match action:
		"car":
			_enter_car()
		"jobs", "load", "hangar":
			var field: String = area.get_meta("field", s.location)
			if field != s.location:
				s.say("That's %s's %s - your aircraft is at %s." % [World.airfield(field).name, area.get_meta("label"), World.airfield(s.location).name])
				return
			_open({"jobs": "j", "load": "l", "hangar": "h"}[action])
		"hq_org":
			_open("hq")
		"hq_rival":
			_open("intel")
		"hq_law":
			s.say("Task Force HQ: restricted. (Play the task force from the lobby, or --police.)")


func _open(key: String) -> void:
	for other in menus.values():
		other.visible = false
	menus[key].open()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if walker != null:
		walker.look_enabled = false


func _toggle_menu(k: String) -> void:
	var m: GameMenu = menus[k]
	if m.visible:
		m.close()
		return
	if not s.parked:
		s.say("Come to a full stop at an airfield first.")
		return
	for other in menus.values():
		other.visible = false
	m.open()
	if s.tutorial != null:
		s.tutorial.note("menu_" + k)


func _gather_input() -> ControlMapper.InputFrame:
	var inp := ControlMapper.InputFrame.new()
	inp.pressed = _pressed
	_pressed = {}
	var menu_open := _active_menu() != null or controls_menu != null or pause_menu != null
	if not menu_open:
		for action in ControlsConfig.HELD:
			if Input.is_action_pressed(ControlsConfig.action(action)):
				inp.held[action] = true
	else:
		inp.pressed.erase("confirm")
	if mouse_yoke and not menu_open:
		var vp := get_viewport()
		var m := vp.get_mouse_position() / vp.get_visible_rect().size * 2.0 - Vector2.ONE
		var dz := func(v: float) -> float: return 0.0 if absf(v) < 0.04 else v
		inp.stick = [clampf(dz.call(m.x) * 1.3, -1, 1), clampf(dz.call(m.y) * 1.3, -1, 1)]
	if not menu_open:
		_poll_stick(inp)
	return inp


## The joypads' axes: a yoke, a throttle quadrant, pedals, toe brakes (F8 to bind them).
func _poll_stick(inp: ControlMapper.InputFrame) -> void:
	ControlsConfig.axes.read(inp)


# ------------------------------------------------------------ loop
func _process(delta: float) -> void:
	var dt := minf(delta, 0.1)
	_frame += 1
	if _frame % 10 == 0:
		if s.tutorial != null and tutorial_panel == null:
			tutorial_panel = TutorialPanel.new()
			ui.add_child(tutorial_panel)
		if tutorial_panel != null:
			tutorial_panel.show_view(s.tutorial.view() if s.tutorial != null else {})
	var camp = s.narrative
	if camp != null and camp.show_briefing:
		var ch: Campaign.Chapter = camp.chapter
		briefing.text = "CHAPTER %d  -  %d  -  %s\n\n%s\n\n%s\n\nPress ENTER" % [ch.num, ch.year, ch.title, ch.briefing,
			"\n".join(camp.objective_lines())]
		briefing.visible = true
		if _pressed.has("confirm"):
			camp.show_briefing = false
			briefing.visible = false
		_pressed.clear()
	elif not paused:
		if _player_key != s.aircraft_key:
			_build_player()
		if server != null:
			server.pump(s)
		_pilot_seat()
		var inp := _gather_input() if not on_foot else _foot_input()
		var remote: bool = s.seats.human(Roles.PILOT) and s.seats.seats[Roles.PILOT].token != ""
		var bc = bot.step(dt) if bot != null and not on_foot else (s.remote_controls() if remote else null)
		s.update(dt, inp, bc)
		_taxi_tick(inp, bc)
		nerves.update(s, dt)
		if _frame % 15 == 0:
			_talk_cues()
		if server != null:
			server.publish(s)
	if _weather_rev != s.weather_rev:
		_weather_rev = s.weather_rev
		scene.set_weather(s.weather)
	_sync_scene(dt)
	hud.pulse = nerves.bpm if nerves.stress > 0.3 else 0.0
	hud.cam_mode = cam_mode
	hud.mouse_yoke = mouse_yoke
	var m := _active_menu()
	hud.visible = m == null and not on_foot
	if on_foot and s.foot != null and s.foot.down != "":
		_foot_down()
	if on_foot:
		_foot_hud()
		_car_checkpoints()
	if m == null:
		hud.refresh()
	elif not s.parked:
		m.close()
	elif _frame % 10 == 0:
		m.refresh()


## Who flies: the host, a remote pilot, or (nobody in the seat) the AI.
func _pilot_seat() -> void:
	var who := s.seats.who(Roles.PILOT)
	if who == "ai" and bot == null:
		bot = AutoRunner.new(s)
		_auto_bot = true
		s.say("The AI has the controls. [F3] to take them back.")
	elif who != "ai" and _auto_bot:
		bot = null
		_auto_bot = false


## F3: hand the aircraft to the AI (so you can take another seat's job), or take it back.
func toggle_ai_pilot() -> void:
	if s.seats.who(Roles.PILOT) == "ai":
		s.seats.claim(Roles.PILOT, "host", "")
		s.say("You have the controls.")
	elif s.seats.human(Roles.PILOT) and s.seats.seats[Roles.PILOT].token == "":
		s.seats.release(Roles.PILOT)


## Down on foot: arrested (the bust takes over) or back at the aircraft.
func _foot_down() -> void:
	var how := s.foot.down
	s.foot.down = ""
	if how == "arrested":
		walker.global_position = player.global_position + Vector3(2, 0, 2)
		_toggle_on_foot()
		return
	var st: FlightModel.FlightState = s.state
	var h := deg_to_rad(st.heading)
	walker.place(st.x - cos(h) * (s.spec.visual.span_m * 0.5 + 1.2), st.y + sin(h) * (s.spec.visual.span_m * 0.5 + 1.2), st.heading)
	gun._refresh_viewmodel()


## While walking the aircraft just sits: parking brake on, nothing else.
func _foot_input() -> ControlMapper.InputFrame:
	var inp := ControlMapper.InputFrame.new()
	inp.held["brake"] = true
	inp.pressed = _pressed
	_pressed = {}
	return inp


func _foot_hud() -> void:
	if driving != null:
		walker.global_position = driving.global_position + Vector3(0, 1.0, 0)  # the walker rides along: the phone, the taxi and the sim see where you are
		var ml2 := []
		for msg in s.messages:
			if s.time - msg[0] < 8:
				ml2.append(msg[1])
		foot_prompt.text = "\n".join(["%d km/h  -  %s   [E] get out" % [int(absf(driving.speed) * 3.6), "road" if driving.on_road() else "off-road"]] + ml2.slice(-2))
		foot_prompt.visible = _active_menu() == null
		return
	if s.foot != null:
		walker.speed_scale = s.foot.speed_factor()
	var lines := []
	if walker.focus != null:
		lines.append("[E] " + str(walker.focus.get_meta("label")))
	if walker.global_position.distance_to(player.global_position) < 9.0:
		lines.append("[TAB] Climb into the %s" % s.spec.name)
	var ml := []
	for msg in s.messages:
		if s.time - msg[0] < 8:
			ml.append(msg[1])
	foot_prompt.text = "\n".join(lines + ml.slice(-2))
	foot_prompt.visible = not foot_prompt.text.is_empty() and _active_menu() == null and pack_menu == null


static func _basis(heading: float, pitch := 0.0, roll := 0.0) -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(pitch), -deg_to_rad(heading), -deg_to_rad(roll)), EULER_ORDER_YXZ)


func _sync_scene(dt: float) -> void:
	var st: FlightModel.FlightState = s.state
	if st == null:
		return
	player.position = MeshBuilder.to_godot([st.x, st.y, st.alt])
	player.basis = _basis(st.heading, st.pitch, st.roll)
	var thr: float = s.fm.controls.throttle if st.engine_running else 0.0
	var spin := TAU * 2400 / 60 * dt * maxf(0.15, thr)
	for p in props:
		p.rotate_object_local(Vector3.FORWARD, spin)
		p.get_node("disc").visible = st.engine_running and thr > 0.35
	# night: nav lights, strobe blink, landing light below 300 m AGL
	var night := scene.night > 0.3
	for n in ac_lights["nav"]:
		n.visible = night or not st.on_ground
	ac_lights["strobe"].visible = st.engine_running and int(s.time * 1.2) % 2 == 0 and fmod(s.time * 1.2, 1.0) < 0.12
	if ac_lights["landing"] != null:
		ac_lights["landing"].visible = night and st.agl < 300
	# dust on the take-off roll and landing rollout, off pavement
	var af: Airfield = s.world.airfield_at(st.x, st.y)
	dust.emitting = st.on_ground and st.gs_kts > 15 and (af == null or af.surface != "asphalt")
	_sync_beacons()
	_sync_pursuers(dt)
	_sync_squads(dt)
	_sync_maritime()
	_sync_effects(dt)
	var aer = s.police.sensors.site("AER")
	scene.show_aerostat(aer != null and aer.active)
	if not on_foot:
		_update_camera(st, dt)
	else:
		for c in player.get_children():
			if c is MeshInstance3D:
				c.visible = true
		glareshield.visible = false


func _sync_maritime() -> void:
	var mar: Maritime = s.maritime
	var live := {}
	for b in mar.boats:
		if b.state != "delivered":
			live[b.id] = b
	for bid in boat_nodes.keys():
		if not live.has(bid) and not str(bid).begins_with("ai:"):
			boat_nodes[bid][0].queue_free()
			boat_nodes.erase(bid)
	var blink := int(s.time * 3) % 2
	for bid in live:
		var b = live[bid]
		if not boat_nodes.has(bid):
			var r := Models.build_boat(b.kind)
			if quality.shaded:
				var w := WorldScene.make_wake()
				w.position = Vector3(0, 0.2, 6)
				r[0].add_child(w)
			add_child(r[0])
			boat_nodes[bid] = r
		var node: Node3D = boat_nodes[bid][0]
		var bob := sin(s.time * 2 + hash(bid) % 7) * 0.15
		node.position = MeshBuilder.to_godot([b.x, b.y, bob])
		node.basis = _basis(b.heading, minf(8.0, b.speed * 0.25))
		for ln in boat_nodes[bid][1]:
			ln.visible = blink == 1
		var wake = node.get_node_or_null("wake")
		if wake != null:
			wake.emitting = b.speed > 2.0
	var live_bales := {}
	for bl in mar.bales:
		if bl.state in ["falling", "floating", "landed"]:
			live_bales[bl.id] = bl
	for blid in bale_nodes.keys():
		if not live_bales.has(blid):
			bale_nodes[blid].queue_free()
			bale_nodes.erase(blid)
	for blid in live_bales:
		if not bale_nodes.has(blid):
			var n := Models.build_bale()
			add_child(n)
			bale_nodes[blid] = n
		var bl = live_bales[blid]
		bale_nodes[blid].position = MeshBuilder.to_godot([bl.x, bl.y, bl.z])
		# a bale hitting the water throws up a splash; on land, a puff of dust
		if _bale_state.get(blid, "") == "falling" and bl.state != "falling" and effects != null:
			var at: Vector3 = bale_nodes[blid].position
			if bl.state == "floating":
				effects.splash(Vector3(at.x, 0.0, at.z), 1.6)
			else:
				effects.puff(at, 2.0)
		_bale_state[blid] = bl.state
	# AI runs (police-vs-AI games, rival gangs)
	for a in s.smugglers:
		var key := "ai:%s" % a.id
		if not boat_nodes.has(key) and a.active():
			var v := Aircraft.Visual.new("low", 2, 11.0, 12.5, Color(0.07, 0.07, 0.07), Color(0.6, 0.1, 0.6))
			var r := Models.build_aircraft(v, 1.2, quality)
			add_child(r[0])
			boat_nodes[key] = [r[0], []]
		if boat_nodes.has(key):
			boat_nodes[key][0].position = MeshBuilder.to_godot([a.x, a.y, a.z])
			boat_nodes[key][0].basis = _basis(a.heading)
			boat_nodes[key][0].visible = a.active()


## Fire and smoke where things burn: crashed police aircraft and cars, our own
## wreck, burned-out stash houses; RPGs going off in the ground war's fights.
func _sync_effects(dt: float) -> void:
	if effects == null:
		return
	var w: Dictionary = s.weather if s.weather != null else {}
	var toward := deg_to_rad(float(w.get("wind_dir", 250.0)) + 180.0)
	effects.wind = Vector3(sin(toward), 0, -cos(toward)) * float(w.get("wind_kt", 8.0)) * 0.514
	# the camera's never far from the aircraft or the walker
	var camp: Vector3 = walker.global_position if walker != null else MeshBuilder.to_godot([s.state.x, s.state.y, s.state.alt])
	for u in s.police.units:
		var uid: int = u.get_instance_id()
		if u.state == "crashed" and pursuer_nodes.has(uid):
			var at: Vector3 = pursuer_nodes[uid][0].position
			if at.distance_to(camp) < 8000.0:
				effects.burn("wreck-%d" % uid, at, 3.0)
	if s.phase == "crashed":
		effects.burn("player", player.position, 3.5)
	if s.stash_net != null:
		for st in s.stash_net.stashes:
			if st.burned:
				var p := Vector3(st.x, s.world.ground(st.x, st.y) + 7.0, -st.y)
				if p.distance_to(camp) < 6000.0:
					effects.smoke("stash-%s" % st.id, p, 6.0)
	effects.sweep()
	if s.ground != null:
		for f in s.ground.fights:
			if f.over or int(f.a.loadout.get("rpg", 0)) + int(f.b.loadout.get("rpg", 0)) == 0:
				continue
			var p := Vector3(f.x + randf_range(-30, 30), s.world.ground(f.x, f.y) + 1.0, -(f.y + randf_range(-30, 30)))
			if p.distance_to(camp) < 3000.0 and randf() < dt * 0.3:
				effects.blast(p, 3.0)


func _sync_pursuers(dt: float) -> void:
	var live := {}
	for u in s.police.units:
		live[u.get_instance_id()] = u
	for uid in pursuer_nodes.keys():
		if not live.has(uid):
			pursuer_nodes[uid][0].queue_free()
			pursuer_nodes.erase(uid)
	var blink := int(s.time * 4) % 2
	for uid in live:
		var u = live[uid]
		if not pursuer_nodes.has(uid):
			var r := Models.build_pursuer(u.kind, quality)
			add_child(r[0])
			pursuer_nodes[uid] = r
		var node: Node3D = pursuer_nodes[uid][0]
		node.position = MeshBuilder.to_godot([u.x, u.y, u.z])
		if u.state == "crashed":
			node.basis = _basis(u.heading, -25, 70)
			continue
		node.basis = _basis(u.heading, 0.0, u.bank)
		for sp in pursuer_nodes[uid][1]:
			if u.kind == "heli":
				sp.rotate_y(deg_to_rad(1500) * dt)
			else:
				sp.rotate_object_local(Vector3.FORWARD, deg_to_rad(2000) * dt)
		var lights: Array = pursuer_nodes[uid][2]
		for k in lights.size():
			lights[k].visible = k == blink
		var search = node.get_node_or_null("searchlight")
		if search != null:
			search.visible = scene.night > 0.3 and u.target_id != null


func _make_squads() -> void:
	squads = SquadRender.new()
	squads.setup(s.world, _graphics)
	add_child(squads)


func _sync_squads(dt: float) -> void:
	if squads == null and s.ground != null:
		_make_squads()  # the story opened the war mid-game
	if squads == null:
		return
	var g := s.ground
	squads.sync(g.squads.map(func(q): return q.dict()),
		g.fights.map(func(f): return {"x": f.x, "y": f.y, "a": f.a.id, "b": f.b.id}), cam.global_position, s.time, dt,
		s.payroll.people.draw_list() if s.payroll != null and Agent.ENABLED else [])


func _update_camera(st: FlightModel.FlightState, dt: float) -> void:
	var h := deg_to_rad(st.heading)
	var fwd := MeshBuilder.to_godot([sin(h), cos(h), 0.0])
	var L := s.spec.visual.length_m
	var cockpit := cam_mode == "cockpit"
	for c in player.get_children():
		if c is MeshInstance3D:
			c.visible = not cockpit
	glareshield.visible = cockpit
	var target := MeshBuilder.to_godot([st.x, st.y, st.alt])
	if cockpit:
		cam.global_transform = player.global_transform * Transform3D(Basis.from_euler(Vector3(deg_to_rad(-4), 0, 0)),
			MeshBuilder.to_godot([-0.3, L * 0.14, 0.25 + L * 0.085 * 0.75]))
		cam.fov = 80
		return
	if cam_mode == "tower":
		var af: Airfield = s.world.nearest_airfield(st.x, st.y)[0]
		var tower := MeshBuilder.to_godot([af.x + af.uy * (af.width / 2 + 55), af.y - af.ux * (af.width / 2 + 55),
			s.world.airfield_elev(af) + 24])
		cam.global_position = tower
		if tower.distance_to(target) > 1.0:
			cam.look_at(target, Vector3.UP)
		cam.fov = clampf(rad_to_deg(atan2(L * 3, (target - tower).length())) * 2, 8, 70)
		return
	cam.fov = 70
	var want := target - fwd * (L * 2.6 + 6) + Vector3(0, L * 0.55 + 1.5, 0)
	if _cam_pos == null or (_cam_pos - want).length() > 400:
		_cam_pos = want  # respawn / teleport: don't sweep across the map
	var k := 1 - exp(-dt * 4.0)
	_cam_pos = _cam_pos + (want - _cam_pos) * k
	var ground := s.world.ground(_cam_pos.x, -_cam_pos.z) + 1.5
	if _cam_pos.y < ground:
		_cam_pos.y = ground
	cam.global_position = _cam_pos
	cam.look_at(target + fwd * L * 1.5 + Vector3(0, 0.5, 0), Vector3.UP)
