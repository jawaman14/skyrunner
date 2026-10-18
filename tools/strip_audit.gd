extends SceneTree
## Audit every airstrip on a map: geometry, both approaches, the ground past each end, what the
## roster can use it for, and (with --bot) whether the pilot bot can take off from and land on it, end by end.
##
##   godot --headless --path . --script res://tools/strip_audit.gd -- [--map city|N] [--terrain natural|classic] [--bot]
##       [--aircraft c172p,c182] [--loads light,half,max] [--payload] [--out docs/STRIPS.md]
##
## --payload adds the heaviest payload that takes off from each end of the strips that matter for the loads the game offers
## (a bisection per cell, about 7 trials each), at 30% fuel.
##
## The terrain is the natural pass by default, the one the game flies; classic is the generator the balance numbers
## were first measured on. The bot trials are scripts/balance/strip_trials.gd (a forced runway end, a straight
## departure held on the runway line, a landing on that end's own final), not the Feasibility sweep.
##
## A strip is flagged when: it is narrower than 1.6 wingspans of the smallest aircraft that would use it,
## an approach path (3 deg, 4.5 deg for a bush strip) is pierced by terrain or trees, the ground past an
## end drops away or is water, its length can't fit an aircraft's landing roll with a 1.6 margin, or the
## bot fails a trial. Exit code is 0; the report is the result.

const APPROACH_DEG := 3.0
const BUSH_APPROACH_DEG := 4.5
const ROLL_MARGIN := 1.6
const SPAN_MARGIN := 1.6

## Only true of the canonical run (--bot, natural terrain, the default map, c172p and c182, light/half/max loads): written from that
## table, so a run with other options must not print it.
const ENVELOPE := """- **Measured envelope** (read from the table on 11 October 2026: natural terrain, map seed 100000, session seed 11, one calm
  run per cell). QRY and PNR are one-way, light-load strips: land on end 1 (end 0 has no clear final) and take off from end 0, and
  only at light load (PNR also at half load); from end 1 no takeoff passes. EGL takes off at light load only, from either end.
  The ordinary fields pass nearly everywhere; their failures are max-load cases (the Cessna 172 on the shorter strips) and the
  Cessna 182 at max load, which fails the *landing* on every field including HAR. That last one is a heavy-aircraft landing
  problem, not a strip problem, so it should be looked at on its own."""

const NOTES := """## Reading the results

- **The trial marks.** T is a takeoff from that end, L a landing on that end, flown by the pilot bot on the runway line
  (`scripts/balance/strip_trials.gd`): ✓ passed, ✗ failed, – no clear final to that end so it was not flown, ? left the
  straight-departure corridor first. A takeoff passes at 3 km along the line after a valid run (airborne inside the strip, 15 m
  up, never under an obstacle top); a landing passes if the aircraft stops on the strip. The bot holds the runway line from
  liftoff so the answer is about the aircraft and the terrain, not where the bot would choose to turn. One calm run per cell.
  Terrain matters: re-run with `--terrain classic` to compare.
@ENVELOPE@
- **One-way strips, by design.** QRY end 0 and PNR end 0 have terrain or mountain in the approach path
  (the flag says how far up it is), so land toward the open end and take off away from the high ground.
- **EGL is a mesa.** About 170 m of cliff past both ends: a short field, and an overrun is fatal.
- **Widths.** The three mountain strips were 12, 14 and 15 m for an 11 m wing; they are now 18 m
  (`MapCity._strip_specs`), and `tests/test_strips.gd` keeps every strip at 1.5 wingspans or more.
  Twin Otter-sized aircraft use 20 m strips, which is tight but real.
- **Loads the mountain strips cannot take.** The table is measured, not tuned. Where a half or max load fails on a mountain
  strip the job generator can send a load somewhere it cannot fly out of; whether to gate that is a balance decision
  (#88), not a strip defect, so it is reported here and not papered over.
- **Landing rules** now allow a graded shoulder beside the strip (`Session.SHOULDER_M`), a wingtip strike
  needs 18 degrees of bank, and the gear holds to 1.25 times its rated sink rate (a hard landing
  between 1x and 1.25x costs the fragile-cargo pay, as before)."""

var world: World
var flags: Array = []  ## [code, text]
var payload_results: Array = []  ## every max_payload result of --payload, written beside the report as JSON


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var map_seed := MapCity.SEED
	var bot := false
	var payload := false
	var keys: Array = ["c172p"]
	var loads: Array = ["light", "half", "max"]
	var natural := true
	var out := ""
	var i := 0
	while i < args.size():
		match args[i]:
			"--map":
				i += 1
				map_seed = MapCity.SEED if args[i] == "city" else int(args[i])
			"--bot":
				bot = true
			"--payload":
				payload = true
			"--aircraft":
				i += 1
				keys = Array(args[i].split(","))
			"--loads":
				i += 1
				loads = Array(args[i].split(","))
			"--terrain":
				i += 1
				if not args[i] in ["natural", "classic"]:
					printerr("--terrain is natural or classic")
					quit(2)
					return
				natural = args[i] == "natural"
			"--out":
				i += 1
				out = args[i]
		i += 1
	StripTrials.use_map(map_seed, natural)
	if bot:
		var bad := StripTrials.validate_filters(keys, null, loads)
		if bad != "":
			printerr(bad)
			quit(2)
			return
	world = World.new()
	var lines := ["# Airstrip audit", "",
		"Map seed %d, %s terrain, generated by `tools/strip_audit.gd`. Approach paths are checked against terrain and trees at %.1f deg (%.1f deg for bush strips); landing rolls use each aircraft's own estimate with a %.1fx margin." % [map_seed, "natural" if natural else "classic", APPROACH_DEG, BUSH_APPROACH_DEG, ROLL_MARGIN], ""]
	lines.append("| strip | surface | length x width | elev | kind | approach clearance (end 0 / end 1) | past the ends | aircraft it fits (landing) |")
	lines.append("|---|---|---|---|---|---|---|---|")
	for af in World.AIRFIELDS:
		lines.append(_row(af))
	lines.append("")
	if bot:
		lines.append_array(_bot_section(keys, loads))
	if payload:
		lines.append_array(_payload_section(keys, natural, map_seed))
	lines.append_array(_notes(bot, natural, map_seed, keys, loads).split("
"))
	lines.append("")
	lines.append("## Flags")
	lines.append("")
	if flags.is_empty():
		lines.append("None.")
	for f in flags:
		lines.append("- **%s**: %s" % [f[0], f[1]])
	var text := "\n".join(lines) + "\n"
	print(text)
	if out != "":
		var path := out if out.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(out)
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_string(text)
			print("wrote ", path)
		if not payload_results.is_empty():
			var jpath := path.get_basename() + "_PAYLOAD.json"
			var jf := FileAccess.open(jpath, FileAccess.WRITE)
			if jf != null:
				jf.store_string(JSON.stringify(payload_results, "  "))
				print("wrote ", jpath)
	quit()


func _row(af: Airfield) -> String:
	var elev: float = world.airfield_elev(af)
	var deg := BUSH_APPROACH_DEG if af.kind in ["bush", "shady"] else APPROACH_DEG
	var clear := []
	for end in [0, 1]:
		var c := _approach_clearance(af, end, deg)
		clear.append(c)
		if c[0] < 0.0:
			_flag(af, "approach to end %d is pierced by %s %.0f m up at %.0f m out (%.1f deg path)" % [end, c[2], -c[0], c[1], deg])
	var past := []
	for end in [0, 1]:
		var p := _past_end(af, end, elev)
		past.append(p)
		if p[0] > 12.0:
			_flag(af, "the ground drops %.0f m within 250 m past end %d" % [p[0], end])
		if p[1]:
			_flag(af, "water within 250 m past end %d" % end)
	var fits := []
	var spans := []
	for k in Aircraft.ROSTER:
		var spec: Aircraft.Spec = Aircraft.ROSTER[k]
		var w: float = spec.mtow_lb * 0.85
		var need := spec.est_landing_roll(w, elev) * ROLL_MARGIN
		if need <= af.length:
			fits.append(k)
		if af.width < spec.visual.span_m * SPAN_MARGIN and need <= af.length:
			spans.append("%s (span %.1f m)" % [k, spec.visual.span_m])
	if not spans.is_empty():
		_flag(af, "%.0f m wide is under %.1f wingspans for %s" % [af.width, SPAN_MARGIN, ", ".join(spans)])
	if fits.is_empty():
		_flag(af, "no aircraft in the roster fits %.0f m with a %.1fx margin" % [af.length, ROLL_MARGIN])
	var trees := _trees_on_strip(af)
	if trees > 0:
		_flag(af, "%d trees within the strip's width and 15 m either side of the centreline" % trees)
	return "| %s %s | %s | %.0f x %.0f m | %.0f m | %s/%s | %s / %s | %s / %s | %s |" % [af.code, af.name, af.surface, af.length, af.width,
		elev, af.kind, af.setting, _clr(clear[0]), _clr(clear[1]), _past(past[0]), _past(past[1]), ", ".join(fits)]


func _clr(c: Array) -> String:
	return "%+.0f m" % c[0]


func _past(p: Array) -> String:
	return ("water" if p[1] else "drop %.0f m" % p[0]) if (p[1] or p[0] > 1.0) else "level"


func _flag(af: Airfield, text: String) -> void:
	flags.append(["%s %s" % [af.code, af.name], text])


## Worst (path height - obstacle top) along the final approach to `end`, with where and what.
## Positive is margin; negative is the depth the terrain or a tree pierces the path.
func _approach_clearance(af: Airfield, end: int, deg: float) -> Array:
	var t: Array = af.threshold(end)
	var s := 1.0 if end == 1 else -1.0  # the approach runs outward from this end
	var elev: float = world.airfield_elev(af)
	var worst := 1e9
	var at := 0.0
	var what := "terrain"
	var d := 30.0
	while d <= 3000.0:
		var x: float = t[0] + s * af.ux * d
		var y: float = t[1] + s * af.uy * d
		var path: float = elev + 10.0 + d * tan(deg_to_rad(deg))  # 10 m over the threshold
		var g: float = world.ground(x, y)
		var top: float = world.obstacle_top(x, y, af.width * 0.5 + 12.0)
		var m := path - top
		if m < worst:
			worst = m
			at = d
			what = "trees" if top > g + 1.0 else "terrain"
		d += 30.0
	return [worst, at, what]


## [deepest drop below the strip's elevation within 250 m past the end, water there?]
func _past_end(af: Airfield, end: int, elev: float) -> Array:
	var t: Array = af.threshold(end)
	var s := -1.0 if end == 0 else 1.0
	var drop := 0.0
	var water := false
	for d in [20.0, 60.0, 120.0, 180.0, 250.0]:
		var x: float = t[0] + s * af.ux * d
		var y: float = t[1] + s * af.uy * d
		drop = maxf(drop, elev - world.terrain.height(x, y))
		water = water or world.is_water(x, y)
	return [drop, water]


func _trees_on_strip(af: Airfield) -> int:
	var n := 0
	var a := -af.length / 2.0
	while a <= af.length / 2.0:
		for lat in [-1.0, 0.0, 1.0]:
			var x: float = af.x + af.ux * a + af.uy * (lat * (af.width * 0.5 + 15.0))
			var y: float = af.y + af.uy * a - af.ux * (lat * (af.width * 0.5 + 15.0))
			if world.terrain.tree_hit(x, y, world.airfield_elev(af) + 3.0, 3.0):
				n += 1
		a += 20.0
	return n


func _bot_section(keys: Array, loads: Array) -> Array:
	var fields: Array = World.AIRFIELDS.map(func(a): return a.code)
	var results := []
	for j in StripTrials.jobs(keys, fields, loads):
		results.append(StripTrials.run_job(j))
	# a flag only where nothing flown from that end works: the table carries the rest
	for af in World.AIRFIELDS:
		for end in [0, 1]:
			for test in ["takeoff", "landing"]:
				var here := results.filter(func(r): return r.field == af.code and r.end == end and r.test == test)
				if not here.is_empty() and not Py.any(here, func(r): return r.status == "pass"):
					_flag(af, "no aircraft or load flown here %s from end %d (%s)" % ["takes off" if test == "takeoff" else "lands", end,
						"no clear final" if here[0].status == "obstructed" else str(here[0].outcome).left(60)])
	return ["## Pilot bot trials, per runway end", "",
		"Aircraft %s at %s load, one calm run per cell. Key under Reading the results." % [", ".join(keys), ", ".join(loads)], "",
		StripTrials.summary_table(results, fields, keys, loads), ""]


## The largest payload (lb) that took off from each end, from StripTrials.max_payload, next to what the game's own pickups
## weigh (Trade.OWN: a bale is lb[0..1], a load is n[0..1] of them, at the strip kinds in "at"). Each cell is a sampled lower
## bound: a 5-step bisection of the payload room, so within room/32 of the true limit, and it assumes a heavier payload never
## helps. Every sample and run is kept in the JSON beside the report so that assumption can be audited.
func _payload_section(keys: Array, natural: bool, map_seed: int) -> Array:
	var out := ["## Largest payload that took off, per runway end", "",
		"%s terrain, map seed %d, 30%% fuel. Each value is a **sampled lower bound** from a 5-step bisection of the payload room (so within room/32, about 19 lb for the Cessna 172, of the true limit; it assumes a heavier payload never helps), and the cell says the lightest payload tried that failed. Every sample and run is in `STRIPS_PAYLOAD.json` next to this report. `none` = it cannot take off even empty." % ["Natural" if natural else "Classic", map_seed], ""]
	for g in Trade.OWN:
		var o: Dictionary = Trade.OWN[g]
		out.append("- **%s** (%s, at %s strips): %.0f to %.0f lb a load." % [o.title, o.label.to_lower() + "s", ", ".join(o["at"]),
			o["n"][0] * o["lb"][0], o["n"][1] * o["lb"][1]])
	out.append("")
	var head := "| strip | end |"
	var rule := "|---|---|"
	for k in keys:
		head += " %s |" % k
		rule += "---|"
	out.append(head)
	out.append(rule)
	for code in ["HAR", "FRM", "EGL", "PNR", "QRY"]:
		var af := World.airfield(code)
		for end in [0, 1]:
			var cells := []
			for k in keys:
				var r := StripTrials.max_payload(k, code, end, 0.3, 5)
				r["terrain"] = "natural" if natural else "classic"
				r["map_seed"] = map_seed
				payload_results.append(r)
				cells.append(_payload_cell(r))
			out.append("| %s %s | %d | %s |" % [code, af.name, end, " | ".join(cells)])
	out.append("")
	return out


## "at least X lb (failed at Y lb)", "at least X lb (all the room)", or "none".
static func _payload_cell(r: Dictionary) -> String:
	if r.max_payload_lb == null:
		return "none"
	var failed := INF
	for sample in r.samples:
		if not sample[1]:
			failed = minf(failed, float(sample[0]))
	if failed == INF:
		return ">= %.0f lb (all the room)" % r.max_payload_lb
	return ">= %.0f lb (failed at %.0f)" % [r.max_payload_lb, failed * float(r.payload_room_lb)]


## The notes for this run: the envelope paragraph only for the configuration it was measured on, else a line saying it is left out.
func _notes(bot: bool, natural: bool, map_seed: int, keys: Array, loads: Array) -> String:
	var canonical := bot and natural and map_seed == MapCity.SEED and keys == ["c172p", "c182"] and loads == ["light", "half", "max"]
	if canonical:
		return NOTES.replace("@ENVELOPE@
", ENVELOPE + "
")
	return NOTES.replace("@ENVELOPE@
", "- **Measured envelope.** Left out: it describes the canonical run (`--bot` on the natural terrain, the default map, the Cessna 172 and 182, light, half and max loads), and this run used other options.
")
