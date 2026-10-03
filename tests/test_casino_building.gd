extends TestCase
## The Hotel Cielo as a place: the building has a table for every game, a cage and an office to talk at, the lights follow the house,
## it stands on the island's flat beside the runway, the island gives the walker ground, and the table screen plays the real games.

var _sess: Session
var _nodes: Array = []


func after_each() -> void:
	CasinoBuilding.ENABLED = true
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes = []
	if _sess != null:
		_sess.dispose()
		_sess = null
	World.use_map(0)


func _session() -> Session:
	_sess = Session.new({"seed": 52, "map_seed": MapCity.SEED, "location": Island.CODE, "features": Session.SANDBOX_FEATURES, "family": true, "island": true, "casino": true, "money": 5000})
	_sess.police.frozen = true
	_sess.update(1.0 / 30)
	return _sess


func _actions(n: Node, out := {}) -> Dictionary:
	if n is Area3D and n.has_meta("action"):
		out[n.get_meta("action")] = int(out.get(n.get_meta("action"), 0)) + 1
	for c in n.get_children():
		_actions(c, out)
	return out


func _building() -> Node3D:
	var s := _session()
	var n := CasinoBuilding.build(s.world)
	_nodes.append(n)
	return n


func test_there_is_a_table_for_every_game_and_a_desk_for_the_manager() -> void:
	var a := _actions(_building())
	check_eq(a.get("casino_roulette", 0), 3, "three wheels")
	check_eq(a.get("casino_blackjack", 0), 4, "four blackjack tables")
	check_eq(a.get("casino_craps", 0), 2, "two craps tables")
	check_eq(a.get("casino_baccarat", 0), 1, "the baccarat salon")
	check_eq(a.get("casino_slots", 0), 5, "five banks of slot machines")
	check_eq(a.get("casino_cage", 0), 1, "the cage")
	check_eq(a.get("casino_office", 0), 1, "the manager's office")


func test_the_building_is_solid_and_lit() -> void:
	var n := _building()
	var body := n.find_child("collision", true, false)
	check(body != null and body.get_child_count() > 100, "colliders for the walls, tables and machines")
	check(n.find_children("*", "OmniLight3D", true, false).size() >= 15, "lamps through the lobby, floor, cage, salon and courtyard")
	check(n.find_children("*", "Label3D", true, false).size() >= 4, "the signs")


func test_the_lights_go_out_and_the_door_is_boarded_when_the_house_is_shut() -> void:
	var n := _building()
	var hotel := n.find_child("hotel-cielo", true, false)
	var boards := hotel.find_child("boards", true, false)
	check(not boards.visible, "the door is open")
	CasinoBuilding.set_open(hotel, false)
	check(boards.visible, "boarded up")
	var lamp: OmniLight3D = hotel.find_children("*", "OmniLight3D", true, false)[0]
	check(not lamp.visible, "the lamps are out")
	var sign3: Label3D = hotel.find_children("*", "Label3D", true, false)[0]
	check(not sign3.visible, "the neon is dark")
	CasinoBuilding.set_open(hotel, true)
	check(not boards.visible and lamp.visible and sign3.visible, "and lit again")


func test_it_can_be_switched_off() -> void:
	CasinoBuilding.ENABLED = false
	var n := _building()
	check_eq(n.get_child_count(), 0, "nothing is built")


func test_it_stands_on_the_flat_of_the_airfield_facing_the_runway() -> void:
	var s := _session()
	var af := Island.airfield()
	var at := CasinoBuilding.site()
	var l: Array = af.to_local(at.x, at.y)
	check_near(absf(l[1]), CasinoBuilding.ACROSS, 0.5, "75 m from the runway's centreline")
	check_near(l[0], CasinoBuilding.ALONG, 0.5, "150 m along it")
	var g0: float = s.world.ground(at.x, at.y)
	var back := Vector2(at.x, at.y) + Vector2(af.uy, -af.ux) * (CasinoBuilding.D + 30.0)
	check_near(s.world.ground(back.x, back.y), g0, 0.5, "flat from the front door to the courtyard's wall")
	var n := CasinoBuilding.build(s.world)
	_nodes.append(n)
	var hotel := n.get_child(0)
	var local_front := Vector3(0, 0, -10)  # ten metres out from the door, in the building's frame
	var out: Vector3 = hotel.transform * local_front
	check(Vector2(out.x, -out.z).distance_to(Vector2(af.x, af.y)) < Vector2(at.x, at.y).distance_to(Vector2(af.x, af.y)) + 1.0, "its front faces the runway side")


func test_the_island_gives_the_walker_ground() -> void:
	var s := _session()
	var body := CasinoBuilding.ground(s.world)
	_nodes.append(body)
	var cs: CollisionShape3D = body.get_child(0)
	var shape: HeightMapShape3D = cs.shape
	check(shape.map_width > 300 and shape.map_depth > 100, "it spans the strip: %d x %d" % [shape.map_width, shape.map_depth])
	var lo := 1e9
	var hi := -1e9
	for h in shape.map_data:
		lo = minf(lo, h)
		hi = maxf(hi, h)
	check(lo >= -0.01 and hi < 40.0, "the island's own heights: %.2f to %.2f" % [lo, hi])


func test_the_island_render_builds_the_hotel_and_its_ground() -> void:
	var s := _session()
	var isl := IslandRender.build(s.world, Quality.get_preset("low"))
	_nodes.append(isl)
	check(isl.find_child("hotel-cielo", true, false) != null, "the hotel is on the island")
	check(isl.find_child("island-ground", true, false) != null, "and the ground under the walker")


# ------------------------------------------------------------------ the table screen
func _menu(s: Session) -> CasinoMenu:
	var m := CasinoMenu.new()
	m.setup(s)
	_nodes.append(m)
	return m


func test_the_slot_screen_pulls_the_handle_for_the_stake() -> void:
	var s := _session()
	var m := _menu(s)
	m.sit("slots")
	check_eq(m.stake(), 25, "the usual stake")
	m.key("+")
	check_eq(m.stake(), 50, "stakes step up")
	m.key("enter")
	check_eq(s.casino.played, 1, "one pull")
	check(str(s.casino.last_play.get("game", "")) == "slots", "slots")
	check(m.felt.text.contains("["), "the reels are shown")


func test_the_roulette_screen_lays_bets_and_spins() -> void:
	var s := _session()
	var m := _menu(s)
	m.sit("roulette")
	m.key("enter")  # red, $25
	m.key("right")
	m.key("enter")  # black, $25
	check_eq(m.layout.size(), 2, "two bets laid")
	var before: int = s.money
	m.key("s")
	check_eq(s.casino.played, 1, "spun")
	check(m.layout.is_empty(), "the dealer clears the layout")
	var ball := int(s.casino.last_play.n)
	check_eq(s.money, before - 50 if ball == 0 else before, "red against black nets nothing, but zero takes both")
	m.key("c")
	m.key("s")
	check(m.note.contains("bet"), "no bets, no spin: %s" % m.note)


func test_the_blackjack_screen_deals_hits_and_stands() -> void:
	var s := _session()
	var m := _menu(s)
	m.sit("blackjack")
	m.key("enter")
	check_eq(str(s.casino.last_play.get("game", "")), "blackjack", "dealt")
	var live := not bool(s.casino.last_play.get("done", true))
	if live:
		m.key("s")
	check(bool(s.casino.last_play.get("done", false)), "the hand is played out")
	check(m.felt.text.contains("Dealer"), "the felt shows both hands")


func test_the_tables_are_closed_to_the_screen_when_you_are_not_there() -> void:
	var s := _session()
	var m := _menu(s)
	s.location = "HAR"
	m.sit("craps")
	check(m.felt.text.contains("not at the Hotel"), m.felt.text)
	m.key("enter")
	check_eq(s.casino.played, 0, "nothing was played")
