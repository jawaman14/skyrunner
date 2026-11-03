extends TestCase
## Bad-luck protection (StreakGuard, D-94): after each catastrophe in a row the next one's chance halves, down to an eighth; a clean
## pass resets it. The same draws in the same order: it can only turn a catch into a pass, never the other way.


func after_each() -> void:
	StreakGuard.ENABLED = true
	World.use_map(0)


func test_the_factor_halves_per_catastrophe_and_stops_at_an_eighth() -> void:
	check_eq(StreakGuard.factor(0), 1.0, "no streak, the full chance")
	check_eq(StreakGuard.factor(1), 0.5, "one in a row halves it")
	check_eq(StreakGuard.factor(3), 0.125, "three: an eighth")
	check_eq(StreakGuard.factor(9), 0.125, "and no lower")
	StreakGuard.ENABLED = false
	check_eq(StreakGuard.factor(3), 1.0, "off for the parity replays")


## The same seed, on and off: every catch with the guard is a catch without it, the guard catches fewer, and two in a row get rarer.
func test_customs_catches_in_a_row_get_rarer_and_a_pass_resets_them() -> void:
	var har := World.airfield("HAR")
	var runs := {}
	for on in [false, true]:
		StreakGuard.ENABLED = on
		var s := Session.new({"seed": 31, "location": "HAR"})
		var seq := []
		for i in 600:
			seq.append(s.police.landing_check(s.state, har, true, "runner", 0.0))
			if not seq.back():
				check_eq(s.police.customs_streak, 0, "a pass resets the streak")
		runs[on] = seq
		s.dispose()
	var off: Array = runs[false]
	var guarded: Array = runs[true]
	var only_on := 0
	for i in off.size():
		if guarded[i] and not off[i]:
			only_on += 1
	check_eq(only_on, 0, "the guard never makes a catch the plain roll would not")
	var twice := func(seq: Array) -> int:
		var n := 0
		for i in range(1, seq.size()):
			if seq[i] and seq[i - 1]:
				n += 1
		return n
	check(guarded.count(true) < off.count(true), "fewer catches (%d against %d)" % [guarded.count(true), off.count(true)])
	check(twice.call(guarded) * 2 < twice.call(off), "two in a row at most half as often (%d against %d)" % [twice.call(guarded), twice.call(off)])


func test_the_streaks_survive_a_save() -> void:
	var s := Session.new({"seed": 5, "location": "HAR", "map_seed": MapCity.SEED})
	s.police.customs_streak = 2
	s.stash_net.truck_streak = 3
	check(s.stash_net != null, "the city map has stashes")
	var d: Dictionary = SaveVars.through_json(StrategicSave.capture(s))
	var s2 := Session.new({"seed": 6, "location": "HAR", "map_seed": MapCity.SEED})
	StrategicSave.restore(s2, d)
	check_eq(s2.police.customs_streak, 2, "the customs streak comes back")
	check_eq(s2.stash_net.truck_streak, 3, "and the trucks'")
	s.dispose()
	s2.dispose()
