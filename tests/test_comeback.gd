extends TestCase
## Loop idea 8: comeback valves. The windfall: a nearly broke pilot with no job gets one honest, well-paid run on the next board.


func after_each() -> void:
	Comeback.ENABLED = true
	World.use_map(0)


func _windfalls(s: Session, code: String) -> Array:
	return s.boards.get(code, []).filter(func(j): return j.title.begins_with("Windfall"))


func test_a_broke_pilot_gets_one_windfall_per_stretch() -> void:
	var s := Session.new({"seed": 12, "location": "HAR"})
	s.money = 400
	s.refresh_board("HAR")
	var w := _windfalls(s, "HAR")
	check_eq(w.size(), 1, "one windfall on the board")
	if w.size() == 1:
		check(not w[0].hot() and w[0].payout >= Comeback.WINDFALL_BASE, "honest and well paid: $%d" % w[0].payout)
		check(World.airfield(w[0].dest).length >= 500.0, "to a sound strip")
	s.refresh_board("HAR")
	check(_windfalls(s, "HAR").is_empty(), "not again straight away")
	s.time += Comeback.WINDFALL_EVERY_S
	s.refresh_board("HAR")
	check_eq(_windfalls(s, "HAR").size(), 1, "again after the interval while still broke")
	s.dispose()


func test_no_windfall_with_money_a_job_on_or_the_switch_off() -> void:
	var s := Session.new({"seed": 12, "location": "HAR"})
	s.money = 5000
	s.refresh_board("HAR")
	check(_windfalls(s, "HAR").is_empty(), "not when there is money")
	s.money = 400
	s.refresh_board("VAL")
	var job: Jobs.Job = s.boards["HAR"][0]
	s.accept_job(job)
	s.windfall_at = -1e9
	s.refresh_board("HAR")
	check(_windfalls(s, "HAR").is_empty(), "not with a job already on")
	s.drop_job(job)
	Comeback.ENABLED = false
	s.refresh_board("HAR")
	check(_windfalls(s, "HAR").is_empty(), "off for the parity replays")
	s.dispose()
