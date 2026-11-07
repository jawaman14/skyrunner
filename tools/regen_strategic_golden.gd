extends SceneTree
## Regenerate tests/fixtures/strategic_golden.json: the HQ season simulator's own values (the seasons, the win matrix, its
## equilibrium, dominance, summary and action values, and the calibration from the tactical sample), computed by the game.
## It replaced the Python parity fixture `strategic_ref.json` (F-6, D-74: the Python fixtures retire one subsystem at a time,
## replaced by Godot goldens). The first golden was written from a build that still matched Python exactly, so it carries
## those numbers forward. A determinism check: regenerate only for a deliberate change to the season rules, and say so.
##
##   godot --headless --script tools/regen_strategic_golden.gd

const OUT := "res://tests/fixtures/strategic_golden.json"
## The seasons pinned: [runner policy, law policy, seed, rule overrides or null, calibrated?, orders disabled].
const SEASONS := [
	["smart", "adaptive", 17, null, false, []],
	["cautious", "investigator", 1017, null, true, []],
	["random", "random", 2017, null, true, ["recruit"]],
	["greedy", "random", 3017, null, false, ["comeback"]],
	["random", "balanced", 4017, {"nights": 8}, true, ["bribe", "wiretap"]],
]


func _init() -> void:
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(build(), " ", false, true) + "\n")  # keys in insertion order: the summary's reasons are compared in order
	f.close()
	print("wrote ", OUT)
	quit()


static func calibration() -> HQ.Calibration:
	var tac = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/tactical_sample.json"))
	return Tactical.calibrate(tac)


static func build() -> Dictionary:
	var cal := calibration()
	var seasons := []
	for a in SEASONS:
		var rules := HQ.PYTHON_RULES.duplicate()  # the season rules the golden pins (no rival cartel)
		if a[3] is Dictionary:
			rules.merge(a[3])
		seasons.append({"args": a, "result": Strategic.play_season(a[0], a[1], int(a[2]), rules, cal if a[4] else null, a[5])})
	var res := Strategic.run_matrix(3, HQ.PYTHON_RULES, cal)
	var mx := Strategic.matrix(res)
	var eq := Strategic.equilibrium(mx[2])
	var matrix := {"results": res.map(func(r): return {"runner": r.runner, "law": r.law, "seed": r.seed, "winner": r.winner,
			"reason": r.reason, "nights": r.nights, "halftime": r.halftime, "margin": r.margin}),
		"runners": mx[0], "laws": mx[1], "m": mx[2], "p": eq[0], "q": eq[1], "v": eq[2],
		"dominance": Strategic.dominance(mx[2], mx[0], mx[1]), "summary": Strategic.summary(res),
		"action_values": {"runner": Strategic.action_values(res, "runner"), "law": Strategic.action_values(res, "law")}}
	return {"cal": cal.to_dict(), "seasons": seasons, "matrix": matrix, "calibrate_tactical": cal.to_dict()}
