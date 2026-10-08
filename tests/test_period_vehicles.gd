extends TestCase
func after_each() -> void: ModelLib.ENABLED = true

func test_period_bodies_preserve_existing_envelopes_and_lod_budgets() -> void:
	for spec in Dealership.CATALOGUE:
		var path := "cars/" + str(spec.model)
		var old := ModelLib.wrapped(path,ModelLib.fit_scale(path,float(spec.len)))
		var expected := ModelLib.bounds(old)
		var model := ModelLib.vehicle(str(spec.model),float(spec.len))
		check(model != null and model.has_meta("period_asset"), str(spec.id)+" uses period geometry")
		var actual := ModelLib.bounds(model)
		check(actual.size.is_equal_approx(expected.size), str(spec.id)+" retains width, height and length")
		check_near(actual.position.y,0,0.001,"wheels rest at the model origin")
		var counts := []
		for i in 3:
			var mi := model.get_node("LOD%d" % i) as MeshInstance3D
			counts.append(mi.mesh.get_faces().size()/3)
			check_eq(mi.mesh.get_surface_count(),1,"one shared material/surface per LOD")
			check(mi.mesh.get_faces().size()/3 < (5000 if i == 0 else 1500),"Asset Bible triangle ceiling")
		check(counts[0] > counts[1] and counts[1] > counts[2],"distant meshes reduce geometry")
		check_eq(model.find_children("*","CollisionObject3D",true,false).size(),0,"asset never introduces gameplay collision")
		model.free()
		old.free()

func test_cached_geometry_and_optional_model_behavior() -> void:
	var first := ModelLib.car("police","car")
	var second := ModelLib.car("police","car")
	check_eq(first.get_node("LOD0").mesh,second.get_node("LOD0").mesh,"instances share cached meshes")
	check_eq(first.get_node("LOD0").material_override,second.get_node("LOD1").material_override,"one cached palette material")
	check_eq(first.get_node("LOD0").visibility_range_end,second.get_node("LOD1").visibility_range_begin,"LOD ranges meet")
	first.free()
	second.free()
	ModelLib.ENABLED = false
	check(ModelLib.vehicle("van",5.2) == null,"existing disabled-model fallback stays intact")
