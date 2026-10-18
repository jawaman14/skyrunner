extends TestCase
## The airfield props (AirfieldDress, from assets/models/airfield): the models keep the game's conventions, each
## field gets its windsock and apron props in the same place every time, and everything falls back cleanly.

const MODELS := ["windsock", "beacon_tower", "fuel_bowser", "wheel_chocks", "tie_down_anchor", "ground_power_cart",
	"runway_edge_light_blue", "runway_edge_light_white"]


func after_each() -> void:
	AirfieldDress.ENABLED = true
	ModelLib.ENABLED = true
	World.use_map(0)


func _world() -> World:
	World.use_map(MapCity.SEED)
	return World.new()


func _mesh_of(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var m := _mesh_of(c)
		if m != null:
			return m
	return null


func test_every_model_is_in_the_game_conventions() -> void:
	for name in MODELS:
		var ps := AirfieldDress.scene(name)
		check(ps != null, "%s loads" % name)
		if ps == null:
			continue
		var inst: Node3D = ps.instantiate()
		var mi := _mesh_of(inst)
		check(mi != null, "%s has a mesh" % name)
		if mi != null:
			var a := mi.get_aabb()
			check_eq(mi.mesh.get_surface_count(), 1, "%s has one surface (one palette material)" % name)
			check(mi.mesh.surface_get_array_index_len(0) / 3 <= 700, "%s is low poly" % name)
			check(absf(a.position.y) < 0.03, "%s stands on the ground (origin at the base)" % name)
			check(a.size.y > 0.08 and a.size.y < 10.0, "%s is a believable height in metres (%.2f)" % [name, a.size.y])
			if name == "windsock":
				check(a.position.z < -1.5, "the windsock streams toward -Z, the model's forward")
		inst.free()


func test_each_field_gets_its_props_where_the_layout_says() -> void:
	var w := _world()
	check(w.airfields.size() > 0, "the map has airfields")
	for af in w.airfields:
		var n := AirfieldDress.build(w, af, Quality.get_preset("high"))
		var layout := AirfieldDress.apron_layout(af)
		check(n.get_child_count() == 2, "%s: a windsock and an apron" % af.code)
		var spot := AirfieldDress.windsock_spot(af)
		var ws: Node3D = n.get_node("windsock")
		check(absf(ws.position.x - spot[0]) < 0.001 and absf(ws.position.z + spot[1]) < 0.001, "%s: the windsock is at its spot" % af.code)
		var apron: Node3D = n.get_node("apron")
		check_eq(apron.get_child_count(), layout.size(), "%s: every apron prop is placed" % af.code)
		check_eq(AirfieldDress.apron_layout(af), layout, "%s: the same layout every time" % af.code)
		for item in layout:
			check(MODELS.has(item[0]), "%s is a shipped model" % item[0])
		n.free()


func test_hubs_get_the_full_set_and_bush_strips_a_few() -> void:
	var w := _world()
	var seen := {}
	for af in w.airfields:
		var names := []
		for item in AirfieldDress.apron_layout(af):
			names.append(item[0])
		seen[af.kind] = names
	for kind in seen:
		if kind in ["hub", "regional"]:
			for need in ["fuel_bowser", "ground_power_cart", "beacon_tower", "tie_down_anchor", "wheel_chocks", "runway_edge_light_blue", "runway_edge_light_white"]:
				check(need in seen[kind], "%s fields have a %s" % [kind, need])
		else:
			check(seen[kind].size() <= 4, "%s strips stay sparse" % kind)
			check(not ("beacon_tower" in seen[kind]), "%s strips have no beacon tower" % kind)


func test_it_is_off_when_asked_and_the_old_windsock_comes_back() -> void:
	var w := _world()
	var af: Airfield = w.airfields[0]
	var q := Quality.get_preset("high")
	check(AirfieldDress.has_windsock(), "the windsock model is there")
	var with_model := Models.build_airfield(w, af, q)
	var verts_with := _vertices(with_model.get_node("field"))
	with_model.free()
	AirfieldDress.ENABLED = false
	var off := AirfieldDress.build(w, af, q)
	check_eq(off.get_child_count(), 0, "nothing when switched off")
	off.free()
	check(not AirfieldDress.has_windsock(), "no model means the procedural pole is wanted")
	var without := Models.build_airfield(w, af, q)
	check(_vertices(without.get_node("field")) > verts_with, "the procedural windsock is drawn again")
	without.free()
	AirfieldDress.ENABLED = true
	ModelLib.ENABLED = false
	var no_models := AirfieldDress.build(w, af, q)
	check_eq(no_models.get_child_count(), 0, "and nothing while ModelLib is off")
	no_models.free()


func test_the_lowest_preset_keeps_only_the_windsock() -> void:
	var w := _world()
	var n := AirfieldDress.build(w, w.airfields[0], Quality.get_preset("low"))
	check_eq(n.get_child_count(), 1, "just the windsock")
	n.free()


func _vertices(body: MeshInstance3D) -> int:
	var total := 0
	for s in body.mesh.get_surface_count():
		total += body.mesh.surface_get_array_len(s)
	return total
