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


func test_the_staff_work_and_the_patrons_stroll_the_aisles() -> void:
	var n := _building()
	var crowd: CasinoCrowd = n.find_child("crowd", true, false)
	check(crowd != null, "the crowd is in the hotel")
	check(crowd.staff.size() >= 15, "dealers, cashiers, a barman and a band: %d" % crowd.staff.size())
	check_eq(crowd.patrons.size(), CasinoCrowd.PATRONS, "and the guests")
	var before := []
	for f in crowd.patrons:
		before.append(f.pos)
	for i in 600:
		crowd._process(0.1)  # a minute of the evening
	var moved := 0
	for i in crowd.patrons.size():
		if crowd.patrons[i].pos != before[i]:
			moved += 1
	check(moved >= crowd.patrons.size() / 2, "most of them have walked somewhere: %d" % moved)
	for f in crowd.patrons:
		check(CasinoCrowd.NODES.has(f.node), "always on the aisles")
	CasinoBuilding.set_open(n.find_child("hotel-cielo", true, false), false)
	check(not crowd.visible, "and they go home when the house is shut")


func test_the_house_has_its_sounds() -> void:
	var band := Soundscape.casino_band()
	check_eq(band.loop_mode, AudioStreamWAV.LOOP_FORWARD, "the band loops")
	var secs := float(band.data.size()) / 2.0 / float(Soundscape.RATE)
	check_near(secs, 8.0 * 4.0 * 60.0 / 124.0, 0.01, "eight whole bars of 124 BPM")
	var peak := 0
	for i in range(0, band.data.size() - 1, 2):
		peak = maxi(peak, absi(band.data.decode_s16(i)))
	check(peak > 3000 and peak < 32000, "audible and not clipped: %d" % peak)
	check_eq(Soundscape.casino_room().loop_mode, AudioStreamWAV.LOOP_FORWARD, "the room murmurs on")
	check(Soundscape.slot_win(true).data.size() > Soundscape.slot_win(false).data.size(), "a jackpot rings longer than a win")
	check(Soundscape.chips().data.size() > 1000, "chips")


func test_the_hotels_points_are_in_the_world() -> void:
	var s := _session()
	var stage := CasinoBuilding.world_point(s.world, 26.0, 2.5, 66.0)
	var front := CasinoBuilding.world_point(s.world, 0.0, 0.0, 0.0)
	var at := CasinoBuilding.site()
	check_near(front.x, float(at.x), 0.01, "the front door is at the site")
	check_near(-front.z, float(at.y), 0.01, "in game metres")
	check(stage.distance_to(front) > 60.0, "the stage is a long way behind it: %.0f m" % stage.distance_to(front))


func test_every_aisle_connects_to_the_others() -> void:
	var crowd := CasinoCrowd.make([], 1)
	var seen := {"lobby_c": true}
	var queue := ["lobby_c"]
	while not queue.is_empty():
		var nm: String = queue.pop_front()
		for m in crowd._adj.get(nm, []):
			if not seen.has(m):
				seen[m] = true
				queue.append(m)
	for nm in CasinoCrowd.NODES:
		check(seen.has(nm), "%s can be reached from the lobby" % nm)
	for e in CasinoCrowd.EDGES:
		check(CasinoCrowd.NODES.has(e[0]) and CasinoCrowd.NODES.has(e[1]), "edge %s-%s names real nodes" % [e[0], e[1]])
	crowd.free()


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
	check_eq(m.stage.get_child_count(), 1, "the reels are shown")


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


func test_the_felt_shows_the_cards_dice_reels_and_ball_as_pictures() -> void:
	var s := _session()
	var m := _menu(s)
	m.sit("slots")
	m.key("enter")
	check_eq(m.stage.get_child_count(), 1, "the reels are on the felt")
	var reels: Array = m.stage.get_child(0).get_children().filter(func(n): return n.has_meta("sym"))
	check_eq(reels.size(), 3, "three of them")
	check_eq(str(reels[0].get_meta("sym")), str(s.casino.last_play.reels[0]), "showing what came up")
	m.sit("blackjack")
	m.key("enter")
	var rows := m.stage.get_child_count()
	check(rows >= 2, "the dealer's cards and yours: %d rows" % rows)
	var cards: Array = []
	for r in m.stage.get_children():
		cards += r.get_children().filter(func(n): return n.has_meta("rank"))
	check(cards.size() >= 4, "at least four cards on the felt: %d" % cards.size())
	if not bool(s.casino.last_play.get("done", true)):
		check(cards.any(func(c): return int(c.get_meta("rank")) == -1), "the dealer's hole card is face down")
	check_eq(CasinoMenu.suit_of(7, 2), CasinoMenu.suit_of(7, 2), "a card keeps its suit")
	m.sit("craps")
	m.key("p")
	m.key("r")
	if s.casino.last_play.has("dice"):
		check(m.stage.get_child_count() >= 1 and m.stage.get_child(0).get_children().filter(func(n): return n.has_meta("die")).size() == 2, "two dice")
	m.sit("roulette")
	m.key("enter")
	m.key("s")
	check(m.stage.get_child_count() == 1 and m.stage.get_child(0).get_children().any(func(n): return n.has_meta("pocket")), "the ball in its pocket")
	m.sit("baccarat")
	m.key("enter")
	check_eq(m.stage.get_child_count(), 2, "the player's hand and the banker's")


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
	check(m.stage.get_child_count() >= 2, "the felt shows both hands")


func test_the_tables_are_closed_to_the_screen_when_you_are_not_there() -> void:
	var s := _session()
	var m := _menu(s)
	s.location = "HAR"
	m.sit("craps")
	check(m.felt.text.contains("not at the Hotel"), m.felt.text)
	m.key("enter")
	check_eq(s.casino.played, 0, "nothing was played")
