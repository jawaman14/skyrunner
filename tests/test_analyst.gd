extends TestCase
## The analyst's desk: with a human in the seat, tips wait for her; without one, dispatch gets them at once.

var _sess: Session


func after_each() -> void:
	Analyst.ENABLED = true
	if _sess != null:
		_sess.dispose()
		_sess = null
	World.use_map(0)


func _session(held := true) -> Session:
	var o := {"seed": 7, "mode": Roles.POLICE, "map_seed": MapCity.SEED}
	if held:
		o["humans"] = {Roles.ANALYST: "Ada"}
	_sess = Session.new(o)
	_sess.police.frozen = true
	_sess.update(1.0 / 30)
	return _sess


func _tip(s: Session, text := "informant: load moving tonight", truth := true) -> void:
	s.police.add_tip(1000.0, 2000.0, 3000.0, text, "N123", null, truth)


func test_without_a_human_a_tip_goes_straight_to_dispatch() -> void:
	var s := _session(false)
	var n: int = s.police.tips.size()
	_tip(s)
	check_eq(s.police.tips.size(), n + 1, "dispatch has it")
	check(s.analyst.desk.is_empty(), "nothing waits on a desk")


func test_with_a_human_a_tip_waits_until_it_is_forwarded() -> void:
	var s := _session()
	var n: int = s.police.tips.size()
	_tip(s)
	check_eq(s.police.tips.size(), n, "dispatch has not seen it")
	check_eq(s.analyst.desk.size(), 1, "it is on the desk")
	var id: String = s.analyst.desk[0].id
	check_eq(s.analyst.desk[0].source, "informant", "from an informant")
	check(s.command(Roles.ANALYST, "analyst", {"do": "forward", "id": id})[0], "forwarded")
	check_eq(s.police.tips.size(), n + 1, "now dispatch has it")
	check(s.analyst.desk.is_empty(), "and the desk is clear")
	check_eq(s.analyst.forwarded, 1, "counted")
	check_eq(s.analyst.wasted, 0, "a real lead costs nothing")


func test_a_false_lead_followed_up_costs_the_sortie() -> void:
	var s := _session()
	_tip(s, "informant: a load lands at Old Quarry tonight", false)
	var funds: float = s.law_funds
	s.analyst.forward(s.analyst.desk[0].id)
	check_eq(s.law_funds, funds - float(Analyst.BAD_SORTIE), "$1,000 off the task force's funds")
	check_eq(s.analyst.wasted, 1, "counted as wasted")


func test_binning_a_real_lead_is_a_miss_and_a_false_one_is_not() -> void:
	var s := _session()
	_tip(s, "informant: real", true)
	_tip(s, "informant: plant", false)
	s.analyst.discard(s.analyst.desk[0].id)
	check_eq(s.analyst.missed, 1, "a real lead binned")
	s.analyst.discard(s.analyst.desk[0].id)
	check_eq(s.analyst.missed, 1, "a false one is no loss")
	check_eq(s.police.tips.size(), 0, "and dispatch never saw either")


func test_verifying_takes_time_and_is_mostly_right() -> void:
	var s := _session()
	_tip(s)
	var id: String = s.analyst.desk[0].id
	check_eq(s.analyst.verify(id), "", "the check starts")
	check(s.analyst.verify(id) != "", "and cannot be started twice")
	s.time += Analyst.VERIFY_S - 1.0
	s.analyst.update(1.0)
	check_eq(s.analyst.desk[0].checked, "", "not done a second early")
	s.time += 2.0
	s.analyst.update(1.0)
	check(s.analyst.desk[0].checked in ["good", "bad"], "then it has an answer")
	check(s.analyst.verify(id) != "", "and is not checked again")
	# the accuracy over many: about 85% of verdicts match the truth
	var right := 0
	var n := 300
	for i in n:
		var truth := i % 2 == 0
		_tip(s, "informant: t%d" % i, truth)
		var e: Dictionary = s.analyst.desk.back()
		s.analyst.verify(e.id)
		s.time += Analyst.VERIFY_S + 1.0
		s.analyst.update(1.0)
		var got: bool = e.checked == "good"
		if got == truth:
			right += 1
		s.analyst.discard(e.id)
	var rate := float(right) / float(n)
	check(rate > 0.78 and rate < 0.92, "right %.0f%% of the time" % (rate * 100.0))


func test_a_tip_nobody_touches_goes_to_dispatch_and_a_full_desk_pushes_the_oldest_out() -> void:
	var s := _session()
	_tip(s)
	var n: int = s.police.tips.size()
	s.time += Analyst.STALE_S + 1.0
	s.analyst.update(1.0)
	check_eq(s.police.tips.size(), n + 1, "after %d s dispatch acts on it as it is" % int(Analyst.STALE_S))
	check(s.analyst.desk.is_empty(), "off the desk")
	for i in Analyst.MAX_DESK + 2:
		_tip(s, "informant: %d" % i)
	check_eq(s.analyst.desk.size(), Analyst.MAX_DESK, "the desk holds %d" % Analyst.MAX_DESK)
	check_eq(s.police.tips.size(), n + 1 + 2, "the two oldest went to dispatch")


func test_the_seat_follows_the_player_and_hands_everything_back() -> void:
	var s := _session(false)
	check(not s.analyst.held, "no one at the desk")
	s.seat_driver(Roles.ANALYST, true)
	check(s.analyst.held, "a player sits down")
	_tip(s)
	var n: int = s.police.tips.size()
	s.seat_driver(Roles.ANALYST, false)
	check(not s.analyst.held, "and gets up")
	check_eq(s.police.tips.size(), n + 1, "what was waiting goes to dispatch")


func test_the_command_has_its_limits() -> void:
	var s := _session()
	_tip(s)
	check(not s.command(Roles.ANALYST, "analyst", {"do": "verify", "id": "nope"})[0], "no such tip")
	check(not s.command(Roles.ANALYST, "analyst", {"do": "shred", "id": "T1"})[0], "no such action")
	check(not s.command(Roles.CONTROLLER, "analyst", {"do": "forward", "id": "T1"})[0], "the controller cannot do the analyst's job")
	Analyst.ENABLED = false
	check(not s.command(Roles.ANALYST, "analyst", {"do": "forward", "id": "T1"})[0], "and it is off when the switch is")


func test_a_double_agents_plant_is_a_false_lead() -> void:
	var s := _session()
	s.upgrades["runner"]["double_agent"] = true
	var jid := Jobs.new_id()
	var j := Jobs.Job.new(jid, "a load", "contraband", "HAR", "FRM", [Jobs.item("Unmarked crate", "cargo", 200.0, jid, {"hot": true})], 5000)
	s._spy_roll(j)
	check(not s.analyst.desk.is_empty(), "the plant reached the desk")
	check(s.analyst.desk.all(func(e): return not bool(e.truth)), "and the sim knows it is false")


func test_the_snapshot_shows_the_desk_without_the_truth() -> void:
	var s := _session()
	_tip(s, "fuel desk: N123 bought ferry fuel at Eagle's Nest")
	var snap := Snapshot.build(s, Roles.ANALYST)
	check(snap.has("analyst") and snap.analyst.desk.size() == 1, "the analyst's snapshot has the desk")
	var row: Dictionary = snap.analyst.desk[0]
	check_eq(row.source, "fuel desk", "the fuel desk's note")
	check_eq(row.squawk, "N123", "with the tail number")
	check(not row.has("truth"), "and no truth in it")
	check(not Snapshot.build(s, Roles.CONTROLLER).has("analyst"), "the controller does not get it")
	check(JSON.stringify(snap).length() > 0, "it is plain JSON")


func test_the_desk_draws_and_its_keys_send_commands() -> void:
	var s := _session()
	_tip(s)
	var link := LocalLink.new(s, Roles.ANALYST)
	var app := StationApp.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	app.setup(link, Roles.ANALYST, s.world)
	app._process(0.016)
	check_eq(app.title.text, "ANALYST", "the desk's title")
	check_eq(app.list.row_count(), 1, "one tip in the table")
	app._key("v")
	check(float(s.analyst.desk[0].verify_until) >= 0.0, "V starts the check")
	app._key("f")
	check(s.analyst.desk.is_empty(), "F forwards it")
	app._process(0.016)
	check_eq(app.list.row_count(), 0, "and the table empties")
	check("85%" in app.info.text, "empty desk explains verification accuracy without a format error")
	app.queue_free()
