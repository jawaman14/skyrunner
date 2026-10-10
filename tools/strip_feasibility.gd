extends SceneTree
## Per-runway-end strip feasibility trials for #88 (scripts/balance/strip_trials.gd), with provenance.
##
##   godot --headless --path . --script res://tools/strip_feasibility.gd -- [--map city|N] [--terrain natural|classic]
##       [--aircraft c172p,c182] [--fields QRY,PNR,EGL,HAR] [--loads light,half,max] [--ends 0,1] [--tests takeoff,landing]
##       [--out DIR]
##
## Defaults: the city map with the natural terrain pass (what a new game flies), every listed aircraft, field, load,
## end and test, one deterministic calm-weather run per cell (session seed 11). Writes strip_feasibility.json and
## strip_feasibility.md to --out (default user://strip_feasibility, outside the repository) and prints the table.
## It never writes docs/ or sim-results/. Exit code is 0; the report is the result.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var map_seed := MapCity.SEED
	var natural := true
	var filters := {"aircraft": null, "fields": null, "loads": null, "ends": null, "tests": null}
	var out := "user://strip_feasibility"
	var i := 0
	while i < args.size():
		var a: String = args[i]
		var v: String = args[i + 1] if i + 1 < args.size() else ""
		match a:
			"--map":
				map_seed = MapCity.SEED if v == "city" else int(v)
			"--terrain":
				if not v in ["natural", "classic"]:
					printerr("--terrain is natural or classic")
					quit(2)
					return
				natural = v == "natural"
			"--aircraft", "--fields", "--loads", "--tests":
				filters[a.substr(2)] = Array(v.split(","))
			"--ends":
				filters["ends"] = Array(v.split(",")).map(func(e): return int(e))
			"--out":
				out = v
			_:
				printerr("unknown argument " + a)
				quit(2)
				return
		i += 2
	StripTrials.use_map(map_seed, natural)
	var js := StripTrials.jobs(filters.aircraft, filters.fields, filters.loads, filters.ends, filters.tests)
	var t0 := Time.get_ticks_msec()
	var results := []
	for j in js:
		var r := StripTrials.run_job(j)
		results.append(r)
		print("%s %s %s %s end %d: %s (%s)" % [r.test, r.aircraft, r.field, r.load, r.end, r.status, r.outcome])
	var prov := _provenance(map_seed, natural, filters, js.size(), (Time.get_ticks_msec() - t0) / 1000.0)
	var md := "\n".join(["# Strip feasibility trials", "", _provenance_md(prov), "", StripTrials.table(results), ""])
	print(md)
	var dir := out if out.is_absolute_path() or out.begins_with("user://") else ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_write(dir.path_join("strip_feasibility.json"), JSON.stringify({"provenance": prov, "results": results}, "  "))
	_write(dir.path_join("strip_feasibility.md"), md)
	quit()


func _provenance(map_seed: int, natural: bool, filters: Dictionary, n: int, seconds: float) -> Dictionary:
	var root := ProjectSettings.globalize_path("res://")
	var head := []
	OS.execute("git", ["-C", root, "rev-parse", "HEAD"], head)
	var dirty := []
	OS.execute("git", ["-C", root, "status", "--porcelain", "--untracked-files=no"], dirty)
	return {"commit": str(head[0]).strip_edges() if not head.is_empty() else "unknown",
		"tracked_changes": not dirty.is_empty() and str(dirty[0]).strip_edges() != "",
		"godot": Engine.get_version_info().string, "map_seed": map_seed, "terrain": "natural" if natural else "classic",
		"weather": "calm and clear (Session default)", "session_seed": 11, "dt": StripTrials.DT,
		"takeoff_goal_m": StripTrials.TAKEOFF_GOAL_M, "takeoff_max_s": StripTrials.TAKEOFF_MAX_S,
		"landing_max_s": StripTrials.LANDING_MAX_S, "clear_radius_m": StripTrials.CLEAR_RADIUS_M,
		"corridor_half_m": StripTrials.CORRIDOR_HALF_M, "corridor_splay": StripTrials.CORRIDOR_SPLAY,
		"loads": Feasibility.LOADS, "filters": filters, "trials": n, "wall_seconds": seconds,
		"run_at": Time.get_datetime_string_from_system(true)}


func _provenance_md(p: Dictionary) -> String:
	return "Commit `%s`%s, Godot %s, map seed %d, %s terrain, %s, session seed %d, dt %.4f s. Takeoff passes at %.0f m along the runway line from the start of the run inside a corridor %.0f m either side widening by %.3f of the distance (inconclusive if the bot leaves it; stops at a crash, the bot giving up, or %.0f s); landing passes when parked on the strip (%.0f s limit). Loads [fuel, payload] fractions: %s. Filters: %s. %d trials, %.0f s wall clock, run %s UTC." % [
		p.commit, " (with uncommitted tracked changes)" if p.tracked_changes else "", p.godot, p.map_seed, p.terrain, p.weather,
		p.session_seed, p.dt, p.takeoff_goal_m, p.corridor_half_m, p.corridor_splay, p.takeoff_max_s, p.landing_max_s, JSON.stringify(p.loads),
		JSON.stringify(p.filters), p.trials, p.wall_seconds, p.run_at]


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("could not write ", path)
		return
	f.store_string(text)
	print("wrote ", ProjectSettings.globalize_path(path))
