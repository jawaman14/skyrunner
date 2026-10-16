extends TestCase


func test_lobby_has_no_classic_map_and_lessons_use_the_coast() -> void:
	var lobby := Lobby.new()
	Engine.get_main_loop().root.add_child(lobby)
	check_eq(lobby.map_ob.item_count, 2)
	check_eq(lobby._opts().map, MapCity.SEED)
	lobby.mode_ob.select(1)
	check_eq(lobby._opts().mode, "campaign")
	check_eq(lobby._opts().map, MapCity.SEED)
	lobby.map_ob.select(1)
	lobby.map_box.value = 42
	check_eq(lobby._opts().map, 42, "generated option index remains correct")
	lobby.queue_free()


func test_retired_map_and_saves_are_explicitly_rejected() -> void:
	check(PlayableMaps.error(0) != "")
	check(PlayableMaps.error(-1, {"map_seed": 0, "money": 123}) != "")
	check(PlayableMaps.error(MapCity.SEED, {"money": 123}) != "", "old saves without a map were classic")
	check_eq(PlayableMaps.error(-1, {"map_seed": MapCity.SEED}), "")
	check_eq(PlayableMaps.error(-1, {"map_seed": 42}), "")
	check(DedicatedServer.parse(["--map", "0"]).error != "")
	var server := DedicatedServer.new({"map": 0, "save": "user://no_classic_test_save.json"})
	check(server.start() != "")
	check(server.sess == null and server.srv == null, "rejected before world construction or sockets")
