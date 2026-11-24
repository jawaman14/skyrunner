extends TestCase
## What the people wear (DESIGN 103, D-108): every faction's looks paint over the kit's sheet, keeping the head (face, hair,
## skin) and repainting the body; a character comes out in its faction's clothes with its animations; cached; off, the kit's own.


func after_each() -> void:
	Wardrobe.ENABLED = true
	ModelLib.ENABLED = true


func _base(letter: String) -> Image:
	var img: Image = (load("res://assets/models/kenney/characters/Textures/texture-%s.png" % letter) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	return img


## Colours stored at 8 bits a channel: the same within a step.
func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


func test_every_look_keeps_the_head_and_dresses_the_body() -> void:
	for faction in Wardrobe.LOOKS:
		for v in (Wardrobe.LOOKS[faction] as Array).size():
			var img := _base("q")
			var head := img.get_pixel(190, 200)
			var o := Wardrobe.look(faction, v)
			Wardrobe.paint(img, o)
			check(_same(img.get_pixel(190, 200), head), "%s %d: the face is the kit's" % [faction, v])
			var outer: Color = Wardrobe.C[str(o.get("jacket", o.shirt))]
			check(_same(img.get_pixel(10, 820), outer) or str(o.get("print", "")) != "" or str(o.get("jacket_print", "")) != "",
				"%s %d: the side of the torso is the outer layer" % [faction, v])
			check(_same(img.get_pixel(600, 1015), Wardrobe.C[str(o.shoes)]), "%s %d: the shoes" % [faction, v])
			check(_same(img.get_pixel(600, 760), img.get_pixel(190, 340)), "%s %d: the hand is the face's skin" % [faction, v])


func test_the_factions_look_different() -> void:
	var colours := {}
	for faction in ["org", "rival", "family", "police"]:
		var o := Wardrobe.look(faction, 0)
		colours[faction] = str(o.get("jacket", o.shirt)) + "/" + str(o.trousers)
	check_eq(colours.values().size(), 4, "four factions")
	var seen := {}
	for k in colours:
		check(not seen.has(colours[k]), "%s has its own colours" % k)
		seen[colours[k]] = true
	check(Wardrobe.look("rival", 0).get("print") == "tropical" and Wardrobe.look("family", 0).get("jacket_print") == "pinstripe" and Wardrobe.look("org", 0).sleeves == "pushed",
		"Los Cuervos in tropical prints, the Morettis in pinstripes, our crew with the sleeves pushed up")


func test_a_character_wears_it_and_keeps_its_animations() -> void:
	var man := ModelLib.character("rival", 0)
	if man == null:
		check(false, "the kit loads")
		return
	check_eq(str(man.get_meta("outfit", "")), "rival:0", "dressed as Los Cuervos")
	var dressed := false
	for mi in man.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i) as StandardMaterial3D
			if m != null and m.albedo_texture == Wardrobe.skin(str(man.get_meta("look")), "rival", 0):
				dressed = true
	check(dressed, "the painted sheet is on the body")
	var ap: AnimationPlayer = man.get_meta("anim")
	check(ap != null and ap.has_animation("walk"), "and it still walks")
	check(Wardrobe.skin("m", "rival", 0) == Wardrobe.skin("m", "rival", 0), "one sheet per look, cached")
	man.free()
	Wardrobe.ENABLED = false
	var plain := ModelLib.character("rival", 0)
	check(not plain.has_meta("outfit"), "off: the kit's own clothes")
	plain.free()
