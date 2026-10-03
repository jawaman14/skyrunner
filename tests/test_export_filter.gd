extends TestCase
## The export presets leave out the art the game does not use (the vendored packs that no script loads yet),
## so the Linux, Windows and macOS builds do not carry 100 MB of it. When a pack starts being used, take it out of
## exclude_filter in export_presets.cfg; this test fails both ways round (a used pack that is excluded would
## draw nothing in a build; an unused one that is not would ship for nothing).

const PACK_ROOTS := ["res://assets/models/kenney", "res://assets/models/kaykit", "res://assets/models/quaternius", "res://assets/ui"]


func _packs() -> Array:
	var out := []
	for root in PACK_ROOTS:
		var d := DirAccess.open(root)
		if d == null:
			continue
		for sub in d.get_directories():
			if root.ends_with("kaykit") or root.ends_with("quaternius") or root.ends_with("/ui"):
				if root.ends_with("kaykit"):
					for s2 in DirAccess.open(root + "/" + sub).get_directories():
						out.append(root + "/" + sub + "/" + s2)
					continue
			out.append(root + "/" + sub)
	return out


## All the script, shader and scene text, as one string.
func _code() -> String:
	var out := ""
	for dir in ["res://scripts", "res://shaders", "res://scenes", "res://dialogue"]:
		out += _read_all(dir)
	return out


func _read_all(dir: String) -> String:
	var d := DirAccess.open(dir)
	if d == null:
		return ""
	var s := ""
	for f in d.get_files():
		if f.get_extension() in ["gd", "gdshader", "tscn", "tres", "dialogue"]:
			s += FileAccess.get_file_as_string(dir + "/" + f)
	for sub in d.get_directories():
		s += _read_all(dir + "/" + sub)
	return s


func _used(pack: String, code: String) -> bool:
	var rel := pack.trim_prefix("res://")  # assets/models/kenney/cars
	if rel in code or pack in code:
		return true
	# ModelLib names the Kenney kits it was first written for relative to its root
	if pack.begins_with("res://assets/models/kenney/"):
		var kit := pack.get_file()
		return FileAccess.get_file_as_string("res://scripts/render/model_lib.gd").contains("\"%s/" % kit)
	return false


func _excludes() -> Array:
	var cf := ConfigFile.new()
	var out := []
	if cf.load("res://export_presets.cfg") != OK:
		return out
	for sec in cf.get_sections():
		if sec.begins_with("preset.") and not sec.ends_with(".options"):
			var pats: Array = []
			for p in str(cf.get_value(sec, "exclude_filter", "")).split(","):
				pats.append(p.strip_edges())
			out.append([str(cf.get_value(sec, "name", sec)), pats])
	return out


func _excluded(pack: String, pats: Array) -> bool:
	var probe := pack.trim_prefix("res://") + "/some_file.glb"
	for p in pats:
		if p != "" and probe.match(p):
			return true
	return false


func test_the_export_presets_leave_out_exactly_the_art_nothing_uses() -> void:
	var code := _code()
	var presets := _excludes()
	check(presets.size() >= 3, "the Linux, Windows and macOS presets are there (%d)" % presets.size())
	var packs := _packs()
	check(packs.size() > 10, "the vendored packs are found (%d)" % packs.size())
	for pack in packs:
		var used := _used(pack, code)
		for pr in presets:
			var ex := _excluded(pack, pr[1])
			if used:
				check(not ex, "%s is used by the game, so %s must ship it" % [pack, pr[0]])
			else:
				check(ex, "%s is not used by anything yet, so %s should leave it out" % [pack, pr[0]])
