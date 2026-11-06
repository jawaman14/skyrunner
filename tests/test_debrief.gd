extends TestCase
## The day's debrief (F-6b): built at the 06:00 books from the ledger day and the day's events, saved with the day under way.


func _close(s: Session) -> Dictionary:
	s.books.close(Books.next_close(s.time))
	return s.books.debriefs[-1]


func test_a_day_is_read_out_from_the_books_and_the_events() -> void:
	var s := Session.new({"seed": 2, "location": "FRM"})
	var said := []
	s.bus.subscribe("debrief", func(e): said.append(e))
	s.move_money(2500, "outside:buyers", "delivery")
	s.move_money(-400, "outside:market", "fuel")
	s.bus.emit("job_delivered", s.time, "", ["runner"], {})
	s.bus.emit("job_delivered", s.time, "", ["runner"], {})
	s.bus.emit("truck_seized", s.time, "", ["runner"], {})
	s.bus.emit("news", s.time, "", ["runner"], {})  # not counted
	var d := _close(s)
	check_near(float(d["in"]), 2500.0, 0.01, "in: the delivery")
	check_near(float(d.out), 400.0, 0.01, "out: the fuel")
	check_near(float(d.net), 2100.0, 0.01, "the net")
	check_eq(int(d.counts.get("job_delivered", 0)), 2, "two loads")
	check_eq(int(d.counts.get("truck_seized", 0)), 1, "one truck lost")
	check(not d.counts.has("news"), "only what the debrief counts")
	check_eq(said.size(), 1, "one debrief a day, on the bus")
	var line := Debrief.line(d)
	check(line.contains("$2,500 in") and line.contains("2 loads delivered") and line.contains("1 truck seized"), "read out: %s" % line)
	check(s.messages.any(func(m): return str(m[1]).begins_with("Day ")), "and said")
	var d2 := _close(s)
	check(d2.counts.is_empty() and float(d2["in"]) == 0.0, "the next day starts empty")
	s.dispose()


func test_the_heat_and_its_change_are_in_the_debrief() -> void:
	var s := Session.new({"seed": 2, "location": "FRM"})
	var case_ = s.police.case("runner")
	case_.suspicion = 20.0
	_close(s)
	case_.suspicion = 31.0
	var d := _close(s)
	check_near(float(d.heat), 31.0, 0.01, "the heat at the close")
	check_near(float(d.heat_change), 11.0, 0.01, "up 11 on the day")
	check(Debrief.line(d).contains("heat 31 (+11)"), Debrief.line(d))
	s.dispose()


func test_a_save_mid_day_gives_the_same_debrief() -> void:
	var s := Session.new({"seed": 2, "location": "FRM"})
	_close(s)
	s.move_money(900, "outside:buyers", "delivery")
	s.bus.emit("job_delivered", s.time, "", ["runner"], {})
	var d: Dictionary = SaveVars.through_json(StrategicSave.capture(s))
	var t := Session.new({"seed": 3, "location": "FRM"})
	StrategicSave.restore(t, d)
	check_eq(t.books.debriefs.size(), 1, "the closed debrief comes back")
	t.bus.emit("job_delivered", t.time, "", ["runner"], {})
	var got := _close(t)
	check_eq(int(got.counts.get("job_delivered", 0)), 2, "the loads before and after the load count")
	check_near(float(got["in"]), 900.0, 0.01, "and the money before it")
	s.dispose()
	t.dispose()


func test_the_line_names_one_and_many_and_leaves_out_the_empty() -> void:
	var d := Debrief.build(3, 0.0, {"in": {"delivery": 1000.0}, "out": {}, "net": 1000.0, "ends": 5000.0},
		{"stash_raided": 1, "busted": 2}, -1.0, -1.0, 0.0)
	var line := Debrief.line(d)
	check(line.begins_with("Day 3's books: $1,000 in, $0 out (+$1,000)"), line)
	check(line.contains("2 busts") and line.contains("1 stash raided"), line)
	check(not line.contains("heat") and not line.contains("stashes."), "no police, no heat; no street cash, no line: %s" % line)
	check(line.find("busts") < line.find("stash raided"), "in the debrief's order")


## Codex on #515: three fixes. Rival workers' losses are not ours; a quiet day keeps its balance; an older save's first day shows no
## spurious change in heat.
func test_only_our_workers_count() -> void:
	var s := Session.new({"seed": 2, "location": "FRM"})
	s.bus.emit("worker_arrested", s.time, "", ["law"], {"outfit": "rival", "role": "dealer"})
	s.bus.emit("worker_flipped", s.time, "", ["law"], {"outfit": "rival", "role": "dealer"})
	s.bus.emit("worker_arrested", s.time, "", ["law"], {"outfit": "org", "role": "driver"})
	var d := _close(s)
	check_eq(int(d.counts.get("worker_arrested", 0)), 1, "our driver, not their dealer")
	check(not d.counts.has("worker_flipped"), "their flip is not ours")
	s.bus.actor = {"org": "police", "role": "chief"}  # a raid the chief ordered
	s.bus.emit("stash_raided", s.time, "", ["runner", "law"], {"stash": "x"})
	s.bus.actor = {}
	check_eq(int(_close(s).counts.get("stash_raided", 0)), 1, "is still our loss")
	s.dispose()


func test_a_quiet_day_keeps_its_closing_balance() -> void:
	var s := Session.new({"seed": 2, "location": "FRM"})
	s.move_money(1500, "outside:buyers", "delivery")
	_close(s)
	var d := _close(s)  # nothing moved
	check_near(float(d.ends), float(s.money), 1.0, "the safe, not zero")
	s.dispose()


func test_an_older_save_without_a_heat_baseline_reports_no_jump() -> void:
	var s := Session.new({"seed": 2, "location": "FRM"})
	s.police.case("runner").suspicion = 40.0
	var d: Dictionary = SaveVars.through_json(StrategicSave.capture(s))
	(d.books as Dictionary).erase("heat_open")
	(d.books as Dictionary).erase("tally")
	var t := Session.new({"seed": 3, "location": "FRM"})
	StrategicSave.restore(t, d)
	var got := _close(t)
	check_near(float(got.heat_change), 0.0, 0.01, "no +40 from a missing baseline")
	s.dispose()
	t.dispose()
