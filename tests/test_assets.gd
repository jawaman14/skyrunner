extends TestCase
## The vendored art (assets/models, assets/ui): each pack is all there, carries its licence, and a sample of
## its models and sprites imports and loads (the import itself fails loudly in `--import`; this catches a
## pack that was truncated or half-copied).

const MODEL_PACKS := {
	"res://assets/models/kenney/cars": [50, "glb"],
	"res://assets/models/kenney/characters": [18, "glb"],
	"res://assets/models/kenney/nature": [329, "glb"],
	"res://assets/models/kenney/boats": [46, "glb"],
	"res://assets/models/kenney/weapons": [37, "glb"],
	"res://assets/models/kenney/city_commercial": [41, "glb"],
	"res://assets/models/kenney/city_industrial": [25, "glb"],
	"res://assets/models/kenney/city_suburban": [40, "glb"],
	"res://assets/models/kenney/furniture": [140, "glb"],
	"res://assets/models/kenney/pirate": [72, "glb"],
	"res://assets/models/kaykit/city": [41, "gltf"],
	"res://assets/models/quaternius/downtown_city": [153, "gltf"],
}
const SPRITE_PACKS := {
	"res://assets/ui/input_prompts": 500,
	"res://assets/ui/cursors": 200,
	"res://assets/ui/flags": 400,
}


## Every file with extension `ext` under `dir`, recursively.
func _files(dir: String, ext: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.get_extension().to_lower() == ext:
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_files(dir.path_join(sub), ext))
	out.sort()
	return out


func _meshes(n: Node) -> int:
	var c := 1 if n is MeshInstance3D else 0
	for k in n.get_children():
		c += _meshes(k)
	return c


func test_every_model_pack_is_all_there_and_loads() -> void:
	for dir in MODEL_PACKS:
		var want: int = MODEL_PACKS[dir][0]
		var ext: String = MODEL_PACKS[dir][1]
		var files := _files(dir, ext)
		check(files.size() >= want, "%s: %d %s files (want %d)" % [dir, files.size(), ext, want])
		if files.is_empty():
			continue
		for i in [0, files.size() / 2, files.size() - 1]:
			var scene = load(files[i])
			check(scene is PackedScene, "%s loads as a scene" % files[i])
			if scene is PackedScene:
				var inst: Node = (scene as PackedScene).instantiate()
				check(_meshes(inst) > 0, "%s has geometry" % files[i])
				inst.free()


func test_every_model_pack_says_where_it_came_from_and_its_licence() -> void:
	for p in ["res://assets/models/kenney/LICENSE.txt", "res://assets/models/kenney/UPSTREAM.txt", "res://assets/models/kaykit/city/LICENSE.txt",
			"res://assets/models/kaykit/city/UPSTREAM.txt", "res://assets/models/quaternius/README.txt", "res://assets/ui/README.txt"]:
		check(FileAccess.file_exists(p), "%s exists" % p)
	var q := FileAccess.get_file_as_string("res://assets/models/quaternius/README.txt")
	check("CC0" in q, "the Quaternius packs are marked CC0")
	for dir in ["downtown_city"]:
		check(FileAccess.file_exists("res://assets/models/quaternius/%s/LICENSE.txt" % dir), "%s keeps its licence file" % dir)


func test_the_sprite_packs_are_all_there_and_load() -> void:
	for dir in SPRITE_PACKS:
		var files := _files(dir, "png")
		check(files.size() >= int(SPRITE_PACKS[dir]), "%s: %d sprites (want %d)" % [dir, files.size(), int(SPRITE_PACKS[dir])])
		if files.is_empty():
			continue
		for i in [0, files.size() - 1]:
			check(load(files[i]) is Texture2D, "%s loads as a texture" % files[i])
