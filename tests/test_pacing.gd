extends TestCase
## Pacing (D-94, DESIGN §55): the gaps between finished things, measured off the event bus, against the pacing targets.


func test_gaps_and_the_median() -> void:
	check_eq(Pacing.gaps([300.0, 100.0], 0.0, 1000.0), [100.0, 200.0, 700.0], "start to each beat (in time order), then to now")
	check_eq(Pacing.median([5.0, 1.0, 3.0]), 3.0, "odd count")
	check_eq(Pacing.median([1.0, 2.0, 3.0, 10.0]), 2.5, "even count")
	check_eq(Pacing.median([]), 0.0, "nothing")


func test_a_session_reports_beats_and_misses_the_targets_it_falls_short_of() -> void:
	var s := Session.new({"seed": 3, "location": "HAR"})
	var p := Pacing.new(s)
	s.bus.emit("job_delivered", 120.0, "", ["runner"], {})
	s.bus.emit("bulk_sale", 240.0, "", ["runner", "law"], {"qty": 10.0})
	s.bus.emit("busted", 300.0, "", ["runner", "law"], {})  # not a finished thing
	s.bus.emit("job_delivered", 330.0, "", ["law"], {})  # one the runner does not hear
	var r := p.report(2000.0)
	check_eq(r.beats, 2, "two finished things heard")
	check_eq(int(r.by_kind.job_delivered), 1, "by kind")
	check_eq(float(r.longest_gap_s), 1760.0, "the dry spell after the sale")
	check(r.missed.any(func(m): return str(m).begins_with("longest_gap_s")), "it says the run missed the dry-spell target: %s" % [r.missed])
	check(not r.missed.any(func(m): return str(m).begins_with("median_gap_s")), "a two-minute typical gap meets its target")
	s.dispose()
