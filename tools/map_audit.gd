extends SceneTree
## The map audit, L1 (the strips): prints each gate's findings for data/maps/costa_brava/ and exits non-zero if there are any.
##
##   godot --headless --path . --script res://tools/map_audit.gd
##
## Later layers add their gates here (docs/MAP_REDESIGN.md section 4). Runs on the authored data: nothing is generated.


func _initialize() -> void:
	var strips := MapAudit.load_strips()
	var findings := MapAudit.strips_gate(strips, World.HALF)
	print("L1 strips: %d strips, %d findings" % [strips.size(), findings.size()])
	for f in findings:
		print("  ", f)
	quit(1 if not findings.is_empty() else 0)
