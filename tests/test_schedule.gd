extends TestCase
## The scheduler and the daily books (F-6, docs/EMPIRE_SIMULATION_SPEC.md section 5).


func test_entries_come_due_in_time_then_serial_order() -> void:
	var sc := Schedule.new()
	sc.at(50.0, "b")
	var first := sc.at(10.0, "a")
	sc.at(50.0, "c")
	sc.at(30.0, "d")
	var gone := sc.at(20.0, "x")
	check(sc.cancel(gone), "a cancelled entry")
	var got: Array = sc.due(60.0).map(func(e): return e[2])
	check_eq(got, ["a", "d", "b", "c"], "earliest first; a tie goes in the order it was set; the cancelled one never comes")
	check(first > 0 and sc.heap.is_empty(), "everything due is handed back once")
	check_eq(sc.due(100.0), [], "and not again")


func test_the_heap_survives_a_save_in_any_order() -> void:
	var sc := Schedule.new()
	for t in [90.0, 10.0, 70.0, 30.0, 50.0]:
		sc.at(t, "k%d" % int(t))
	var d: Dictionary = SaveVars.through_json(sc.capture())
	d.heap.reverse()  # the save is a list; any order must come back a heap
	var back := Schedule.new()
	back.restore(d)
	check_eq(back.due(1000.0).map(func(e): return e[2]), ["k10", "k30", "k50", "k70", "k90"], "same order after the load")
	check(back.at(5.0, "new") > 5, "serials carry on")


func test_the_books_close_at_six_and_sum_one_orgs_day_from_the_ledger() -> void:
	check_eq(Books.next_close(0.0), 6.0 * 3600.0, "from midnight: 06:00 the same day")
	check_eq(Books.next_close(6.0 * 3600.0), 86400.0 + 6.0 * 3600.0, "at 06:00 exactly: the next day's")
	var s := Session.new({"seed": 2, "location": "FRM"})
	check(s.schedule != null and s.schedule.has_kind("books"), "a session sets its first books")
	var seen := []
	s.bus.subscribe("books", func(e): seen.append(e))
	s.move_money(-400, "outside:market", "fuel")
	s.move_money(2500, "outside:buyers", "delivery")
	s.time = Books.next_close(s.time) - 0.5
	s.update(1.0)
	check_eq(seen.size(), 1, "the books close once at 06:00")
	if not seen.is_empty():
		var org: Array = seen[0].data.rows.filter(func(r): return r.org == "org")
		check(not org.is_empty(), "the organisation's day is in it")
		if not org.is_empty():
			check_near(float(org[0].in.get("delivery", 0.0)), 2500.0, 0.01, "in: the delivery")
			check_near(float(org[0].out.get("fuel", 0.0)), 400.0, 0.01, "out: the fuel")
			check_near(float(org[0].net), 2100.0, 0.01, "net for the day")
			check_near(float(org[0].ends), float(s.money), 1.0, "and the balance it ends on is the safe")
	check(s.schedule.has_kind("books"), "and the next day's books are set")
	s.dispose()


func test_the_books_and_the_schedule_survive_a_save() -> void:
	var s := Session.new({"seed": 2, "location": "FRM"})
	s.move_money(1000, "outside:buyers", "delivery")
	s.time = Books.next_close(s.time) + 1.0
	s.update(1.0)
	var d: Dictionary = SaveVars.through_json(StrategicSave.capture(s))
	var t := Session.new({"seed": 3, "location": "FRM"})
	StrategicSave.restore(t, d)
	check_eq(t.books.closed.size(), s.books.closed.size(), "the closed days come back")
	check_near(t.schedule.next_t(), s.schedule.next_t(), 0.01, "and when the next books fall")
	s.dispose()
	t.dispose()


## Codex on #511: the ledger folds its oldest rows away past LOG_MAX, and a war day books more than that before 06:00. The books
## count each transfer as it is booked, so a day busier than the log still sums to every dollar.
func test_a_day_busier_than_the_ledger_log_keeps_every_dollar() -> void:
	var s := Session.new({"seed": 2, "location": "FRM"})
	var n := Ledger.LOG_MAX + 2 * Ledger.TRIM
	for i in n:
		s.ledger.transfer("outside:street", "rival:safe", 1.0, "sales", "system", s.time)
	check(s.ledger.log.size() < n, "the ledger did trim (%d rows kept of %d)" % [s.ledger.log.size(), n])
	var rows: Array = s.books.close(Books.next_close(s.time)).filter(func(r): return r.org == "rival")
	check(not rows.is_empty(), "the rivals' day is in the books")
	if not rows.is_empty():
		check_near(float(rows[0].in.get("sales", 0.0)), float(n), 0.01, "every sale counted, trimmed rows included")
	s.dispose()


func test_a_save_mid_day_keeps_the_day_under_way() -> void:
	var s := Session.new({"seed": 2, "location": "FRM"})
	s.move_money(700, "outside:buyers", "delivery")
	var d: Dictionary = SaveVars.through_json(StrategicSave.capture(s))
	var t := Session.new({"seed": 3, "location": "FRM"})
	StrategicSave.restore(t, d)
	t.move_money(300, "outside:buyers", "delivery")
	var rows: Array = t.books.close(Books.next_close(t.time)).filter(func(r): return r.org == "org")
	check(not rows.is_empty() and is_equal_approx(float(rows[0].in.get("delivery", 0.0)), 1000.0),
		"the day's deliveries before and after the load: %s" % [rows])
	s.dispose()
	t.dispose()


func test_off_for_the_replays() -> void:
	Schedule.ENABLED = false
	var s := Session.new({"seed": 2, "location": "FRM"})
	check(s.schedule == null and s.books == null, "no scheduler with the switch off")
	s.dispose()
	Schedule.ENABLED = true
