extends "res://tools/live_balance.gd"
## Fixed #244 comparison: verify source first, then reuse the canonical stand-in.
## -- variant --check, or -- variant output.json. No corrections are applied here.
const BASE := "a3f66fba1cb723f1b0dab3ef35b2cedc2adfb910"
const GROUND_SHA := {"baseline": "54ca6beb8a4f5e8f34d949321eee6b2050b7e28345f0055f8fb4d1f9f04c1c76", "escort-only": "5292a4af68b8281175f43fbebbf508e641139a61f7cad076077ef0add51d5a7d", "stakeout-only": "7a5edcad3931b2ecd9fc2b2422f22653497e71e85672c0504fe948e996d916f8", "combined": "6d152e9a366a3e3bab9ece721fef2a100ddb1777348352e5090e33969f67dbc8"}
const CANONICAL_SHA := "772a2e0682fe324866bdb007cd33cfe12d1a8be9a19b4df02c1444c190c62f36"
func validate(label: String) -> bool:
	if not GROUND_SHA.has(label): return false
	var info := Engine.get_version_info()
	if [int(info.major), int(info.minor), int(info.patch)] != [4, 7, 2]: return false
	var ground := FileAccess.get_file_as_string("res://scripts/sim/ground.gd").replace("\r\n", "\n")
	var canonical := FileAccess.get_file_as_string("res://tools/live_balance.gd").replace("\r\n", "\n")
	if ground.sha256_text() != GROUND_SHA[label] or canonical.sha256_text() != CANONICAL_SHA: return false
	var output := []
	return OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "diff", "--quiet", BASE, "--", "scripts", "assets", "data", "project.godot", "tools/live_balance.gd", ":(exclude)scripts/sim/ground.gd"], output, true, false) == 0

func _initialize() -> void:
	call_deferred("measure")
func measure() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or not validate(args[0]):
		printerr("Usage: variant output.json|--check; engine/source must match the recorded base and variant patch.")
		quit(2)
		return
	if args[1] == "--check":
		print("ISOLATION SOURCE VERIFIED: ", args[0])
		quit()
		return
	var start := Time.get_ticks_msec()
	var file := FileAccess.open(args[1], FileAccess.WRITE)
	if file == null:
		printerr("Cannot write the requested evidence file: ", error_string(FileAccess.get_open_error()))
		quit(2)
		return
	hours = 3.0
	var config := {"family": true, "island": true, "agency": true, "chronicle": true, "payroll": true, "trade": true, "career": true, "renown": true, "ground_war": true, "rackets": true}
	var rows := []
	for seed in range(1, 41):
		rows.append(_run(seed, config))
		if seed % 5 == 0: print("%s: seed %d/40" % [args[0], seed])
	var result := {"variant": args[0], "base": "a3f66fba1cb723f1b0dab3ef35b2cedc2adfb910", "hours": hours, "seeds": range(1, 41), "rows": rows, "summary": _summary(rows), "seconds": (Time.get_ticks_msec() - start) / 1000.0}
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	print("BALANCE COMPLETE: ", args[0])
	quit()
