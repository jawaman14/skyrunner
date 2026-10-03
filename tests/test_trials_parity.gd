extends TestCase
## Seeded tactical and feasibility trials (the flight model, the pilot bot,
## police, boats and both RNG streams together) against the golden runs in
## tests/fixtures/flight_golden.json (tools/regen_flight_golden.gd). The trial
## inputs are the Python fixture's (tests/fixtures/trials_ref.json); the
## flying is the game's own, so the numbers are Godot golden, bit for bit.


func before_each() -> void:
	Switches.parity_off()  # the Godot-only rules off: replaying the Python game


func after_each() -> void:
	Switches.parity_on()


func _match(got: Dictionary, want: Dictionary, what: String) -> void:
	for k in want:
		if want[k] is float:
			# JSON round trip: good to ~1e-15
			check_near(float(got[k]), want[k], 1e-9 * maxf(1.0, absf(want[k])), "%s.%s" % [what, k])
		else:
			check_eq(got[k], want[k], "%s.%s" % [what, k])


func test_tactical_trials_match_golden() -> void:
	Tactical.PYTHON = true
	for w in T.golden().trials.tactical:
		Jobs._next_id = 1
		_match(Tactical.run_trial(w.zone, w.law, w.tactic, int(w.seed)), w, "%s/%s/%s" % [w.zone, w.law, w.tactic])
	Tactical.PYTHON = false


func test_feasibility_trials_match_golden() -> void:
	for w in T.golden().trials.feasibility:
		Jobs._next_id = 1
		var got := Feasibility.run_job([w.test, w.aircraft, w.field, w.load])
		_match(got, w, "%s %s %s %s" % [w.test, w.aircraft, w.field, w.load])
