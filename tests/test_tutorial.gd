extends TestCase
## The optional tutorial: lessons finish when you do the thing; a system's
## lesson waits until the system is in the game; tips come once; F10 skips,
## off hides it; progress rides in the save.


func after_each() -> void:
	World.use_map(0)


func _sess(opts := {}) -> Session:
	var o := {"seed": 4, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES}
	o.merge(opts, true)
	var s := Session.new(o)
	s.police.frozen = true
	Tutorial.new().attach(s)
	return s


func _ids(s: Session) -> String:
	var c = s.tutorial.current()
	return c[0] if c != null else ""


func test_takeoff_lesson_stays_visible_during_the_ground_roll() -> void:
	var s := _sess()
	s.tutorial.done["welcome"] = true
	s.tutorial.done["jobs"] = true
	check_eq(_ids(s), "takeoff", "take-off lesson is shown while parked")
	s.state.gs_kts = 5.0
	check_eq(_ids(s), "takeoff", "ground roll keeps the take-off instructions visible")
	s.dispose()


func test_the_basics_follow_what_you_do() -> void:
	var s := _sess()
	check_eq(_ids(s), "welcome")
	s.time += 13.0
	s.tutorial.tick(s)
	check_eq(_ids(s), "jobs", "the welcome goes by itself")
	s.refresh_board("HAR")
	var j = Py.first(s.boards["HAR"], func(x): return not x.hot())
	check(s.accept_job(j) == null, "took a legal job")
	check_eq(_ids(s), "takeoff", "taking a job moves to the take-off phase")
	s.tutorial.note("menu_l")
	s.tutorial.tick(s)
	check(not s.tutorial.done.has("second_flight_load"), "the load lesson waits until the first landing")
	s.bus.emit("job_delivered", s.time, "", ["runner"], {"job_id": j.id, "pay": 100, "hot": false})
	check(s.tutorial.done.has("deliver"), "a delivery counts even out of order")
	s.dispose()


func test_a_preflight_load_menu_does_not_skip_the_next_flight_lesson() -> void:
	var s := _sess()
	for id in ["welcome", "jobs", "takeoff", "flight", "landing"]:
		s.tutorial.done[id] = true
	s.tutorial.note("menu_l")  # opened before the first landing
	s.bus.emit("landed", s.time, "", ["runner"], {"code": "HAR"})
	s.tutorial.tick(s)
	check(not s.tutorial.done.has("second_flight_load"), "the old preflight menu open does not satisfy the next-flight lesson")
	s.tutorial.note("menu_l")  # reopened after the first landing
	s.tutorial.tick(s)
	check(s.tutorial.done.has("second_flight_load"), "opening the load planner after landing completes the lesson")
	s.dispose()


func test_flight_lesson_timer_waits_until_the_lesson_is_current() -> void:
	var s := _sess()
	s.tutorial.done["welcome"] = true
	s.tutorial.done["takeoff"] = true
	s.state.on_ground = false
	s.state.agl = 1000.0
	s.phase = "flying"
	s.location = null
	check_eq(_ids(s), "jobs", "an unseen jobs lesson remains current in flight")
	s.tutorial.tick(s)
	s.time += Tutorial.FLIGHT_LESSON_S + 1.0
	s.tutorial.tick(s)
	check(not s.tutorial.done.has("flight"), "flight time does not count before the card can be seen")
	s.tutorial.done["jobs"] = true
	check_eq(_ids(s), "flight", "the flight card becomes current after jobs")
	s.tutorial.tick(s)
	s.time += Tutorial.FLIGHT_LESSON_S
	s.tutorial.tick(s)
	check(s.tutorial.done.has("flight"), "flight time counts while its card is current")
	s.dispose()


func test_flight_lessons_follow_the_phase_and_load_waits_for_the_first_landing() -> void:
	var s := _sess()
	s.tutorial.done["load"] = true  # a previous save may have completed the old load card
	s.tutorial.done["welcome"] = true
	s.tutorial.done["jobs"] = true
	check_eq(_ids(s), "takeoff", "take-off is the first flight lesson on the ground")
	s.tutorial.done["takeoff"] = true
	s.state.on_ground = false
	s.state.agl = 1000.0
	s.phase = "flying"
	s.location = null
	check_eq(_ids(s), "flight", "the in-flight lesson waits until airborne")
	s.tutorial.tick(s)
	s.time += Tutorial.FLIGHT_LESSON_S
	s.tutorial.tick(s)
	check_eq(_ids(s), "landing", "landing follows the in-flight lesson during flight")
	s.tutorial.view()
	s.state.on_ground = true
	s.phase = "parked"
	s.location = "HAR"
	s.bus.emit("landed", s.time, "", ["runner"], {"code": "HAR"})
	check(s.tutorial.done.has("first_landing"), "first landing unlocks the next-flight load lesson")
	check(s.tutorial.done.has("landing"), "the landing lesson completes on touchdown")
	check_eq(_ids(s), "second_flight_load", "load and fuel appears after the first flight")
	s.tutorial.note("menu_l")
	s.tutorial.tick(s)
	check(s.tutorial.done.has("second_flight_load"), "opening the load planner completes the second-flight lesson")
	s.dispose()


## The bot's P2 on #372: the migration is for saves from before the landing lessons only. A current save that skipped take-off while parked has not landed.
func test_a_current_save_that_skipped_takeoff_has_not_landed() -> void:
	var s := Session.new({"seed": 4, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES})
	var t := Tutorial.new({"on": true, "done": ["welcome", "jobs", "takeoff"], "landing_v": 1}).attach(s)
	check(not t.done.has("first_landing"), "a current save is not migrated: skipping take-off does not count as a landing")
	check(bool(t.to_dict().get("landing_v", 0)), "and every save now says it has the landing lessons")
	s.dispose()


func test_older_save_with_takeoff_complete_unlocks_the_new_load_lesson() -> void:
	var s := Session.new({"seed": 4, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES})
	var t := Tutorial.new({"on": true, "done": ["welcome", "jobs", "takeoff", "flight", "landing", "load"]}).attach(s)
	check(t.done.has("first_landing"), "completed take-off in an older parked save implies a first landing")
	check_eq(t.current()[0], "second_flight_load", "the new lesson survives the old load-card progress")
	s.dispose()


func test_a_systems_lesson_waits_for_its_system() -> void:
	var s := _sess({"trade": true})
	for id in ["welcome", "jobs", "load", "second_flight_load", "takeoff", "flight", "landing", "deliver", "transponder", "grass"]:
		s.tutorial.done[id] = true
	check_eq(_ids(s), "buyers", "no payroll or logistics yet: their lessons wait")
	s.enable_system("payroll")
	check_eq(_ids(s), "org_crew", "the hiring hall opens: its lesson is next")
	var p: Array = s.tutorial.progress()
	check(p[1] >= 8, "the count grows with the game (%d)" % p[1])
	s.dispose()


## Owner, 14 Oct: there is no way to learn how to avoid radar and being seen. The first time suspicion builds in the air, the radar tip says how.
func test_the_radar_tip_comes_once_when_the_police_first_notice_you() -> void:
	var s := _sess()
	s.tutorial.tick(s)
	check(not s.tutorial.tips_shown.has("radar"), "no tip while nobody is watching")
	s.phase = "flying"
	s.police.suspicion = 12.0
	s.tutorial.tick(s)
	check(s.tutorial.view().tip.begins_with("The police have noticed you"), "the radar tip: %s" % s.tutorial.view().tip)
	check(s.tutorial.view().tip.contains("45 m") and s.tutorial.view().tip.contains("behind hills"), "and it gives the radar floor and the terrain cover")
	var n := s.messages.filter(func(m): return "TIP" in str(m[1])).size()
	s.tutorial.tick(s)
	check_eq(s.messages.filter(func(m): return "TIP" in str(m[1])).size(), n, "and comes once")
	s.dispose()


func test_tips_come_once() -> void:
	var s := _sess()
	s.police.case("runner").wanted = 1
	s.tutorial.tick(s)
	check(s.tutorial.view().tip.begins_with("You're WANTED"), "the wanted tip")
	var n := s.messages.filter(func(m): return "TIP" in str(m[1])).size()
	s.tutorial.tick(s)
	s.tutorial.tick(s)
	check_eq(s.messages.filter(func(m): return "TIP" in str(m[1])).size(), n, "once")
	s.time += 30.0
	s.tutorial.tick(s)
	check_eq(s.tutorial.view().tip, "", "and it fades")
	s.dispose()


func test_runway_push_around_explanation_appears_for_the_first_three_uses() -> void:
	var s := _sess()
	for n in 3:
		s.turnaround_t = 5.0
		s.tutorial.tick(s)
		check(s.tutorial.view().tip.contains("press I"), "push-around %d explains the runway-end turn" % (n + 1))
		s.turnaround_t = 0.0
		s.tutorial.tick(s)
	s.turnaround_t = 5.0
	s.tutorial.tick(s)
	check(s.tutorial.tips_shown.has("turnaround_3"), "three explanations are saved")
	check_eq(s.messages.filter(func(m): return str(m[1]).contains("At a short runway")).size(), 3, "later push-arounds do not repeat the tip")
	s.dispose()


func test_skip_and_off() -> void:
	var s := _sess()
	s.tutorial.skip()
	check_eq(_ids(s), "jobs", "F10 skips")
	s.tutorial.set_enabled(false)
	check(s.tutorial.current() == null, "off: nothing on screen")
	s.police.case("runner").wanted = 1
	s.tutorial.tick(s)
	check_eq(s.tutorial.view().tip, "", "and no tips")
	s.dispose()


func test_progress_is_saved() -> void:
	var s := _sess()
	s.tutorial.done["jobs"] = true
	s.tutorial.tips_shown["fog"] = true
	var t := Tutorial.new(s.tutorial.to_dict())
	check(t.done.has("jobs") and t.tips_shown.has("fog") and t.enabled, "round trip")
	s.save_path = OS.get_temp_dir().path_join("skyrunner-tutorial-save.json")
	s.save()
	check(Session.read_save(s.save_path).has("tutorial"), "in the save file")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(s.save_path))
	s.dispose()


func test_every_lesson_can_finish() -> void:
	# each lesson id is completed somewhere (an event, a note or the state)
	var src := FileAccess.get_file_as_string("res://scripts/sim/tutorial.gd")
	for l in Tutorial.LESSONS:
		check(src.count('complete("%s")' % l[0]) >= 1, "a way to finish '%s'" % l[0])


func test_the_desks_learn_by_doing() -> void:
	var s := _sess()
	check_eq(s.tutorial.desk_view(Roles.CONTROLLER).id, "c_launch", "the controller starts with launching")
	var r: Array = s.command(Roles.CONTROLLER, "launch", {"kind": "heli"})
	if r[0]:
		check_eq(s.tutorial.desk_view(Roles.CONTROLLER).id, "c_raid", "a launch finishes the lesson")
	else:
		s.tutorial.command_done(Roles.CONTROLLER, "launch")  # no heli free on this map: the hook alone
		check_eq(s.tutorial.desk_view(Roles.CONTROLLER).id, "c_raid")
	check_eq(s.tutorial.desk_view(Roles.PILOT).id, "", "the pilot has no desk lessons")
	check_eq(_ids(s), "welcome", "and the pilot's own lessons are untouched")
	s.dispose()


func test_a_remote_desk_skips_through_the_link() -> void:
	var s := _sess()
	var link := LocalLink.new(s, Roles.BOSS)
	var snap = link.snapshot()
	check(snap is Dictionary and snap.tutorial.id == "b_orders", "the boss's desk shows its lesson")
	link.send_command("tutorial", {"do": "skip"})
	check_eq(s.tutorial.desk_view(Roles.BOSS).id, "", "skipped (the rest need systems not in this game)")
	link.send_command("tutorial", {"do": "off"})
	check(not s.tutorial.enabled, "SHIFT+F10 from a desk turns it off for the game")
	s.dispose()


func test_desk_progress_is_saved() -> void:
	var s := _sess()
	s.tutorial.command_done(Roles.LIEUTENANT, "squad_order")
	var t := Tutorial.new(s.tutorial.to_dict())
	check(t.desk_done.get(Roles.LIEUTENANT, {}).has("l_squads"), "round trip")
	s.dispose()


func test_the_papi_tip_fires_when_the_hud_sees_it() -> void:
	var s := _sess()
	s.tutorial.tick(s)
	check_eq(s.tutorial.view().tip, "", "nothing to see yet: no HUD, no note")
	s.tutorial.note("papi_seen")  # what Hud._papi() calls the moment the four squares light up
	s.tutorial.tick(s)
	check(s.tutorial.view().tip.begins_with("Those four squares are the PAPI"), "the tip explains them")
	s.dispose()


func test_the_ai_hiring_lesson_fires_when_the_ai_actually_hires() -> void:
	var s := _sess({"payroll": true, "ground_war": true})
	for id in ["welcome", "jobs", "load", "second_flight_load", "takeoff", "flight", "landing", "deliver", "transponder"]:
		s.tutorial.done[id] = true
	check_eq(_ids(s), "org_crew", "the lesson is up: the organisation runs itself")
	s.money = 80000
	s.payroll.ai["org"] = true
	for i in 12:
		s.payroll._refresh("org")
		s.payroll._think("org")
		s.tutorial.tick(s)
	check(s.tutorial.done.has("org_crew"), "the AI hired somebody, so the lesson finished itself")
	s.dispose()


func _all_systems() -> Session:
	var s := _sess({"ground_war": true, "trade": true, "payroll": true, "logistics": true, "renown": true, "rackets": true, "races": true})
	s.tutorial.done = {}
	return s


func _finish_until(s: Session, id: String) -> void:
	# everything before `id` is done, so `id` is the lesson on screen
	for l in Tutorial.LESSONS:
		if l[0] == id:
			break
		s.tutorial.done[l[0]] = true


func test_the_new_systems_have_lessons_that_wait_for_them() -> void:
	var bare := _sess()
	var ids: Array = Tutorial.LESSONS.map(func(l): return l[0])
	for want in ["phone", "car", "car_radio", "squad_orders", "renown", "rackets", "works", "round", "arena"]:
		check(want in ids, "there is a '%s' lesson" % want)
	var avail: Array = Tutorial.LESSONS.filter(func(l): return bare.tutorial._needs_ok(l[1])).map(func(l): return l[0])
	for gone in ["phone", "car", "renown", "rackets", "works", "round", "arena"]:
		check(not (gone in avail), "'%s' is not taught without its system" % gone)
	bare.dispose()
	var s := _all_systems()
	var av: Array = Tutorial.LESSONS.filter(func(l): return s.tutorial._needs_ok(l[1])).map(func(l): return l[0])
	for here in ["phone", "car", "car_radio", "squad_orders", "renown", "rackets", "works", "round", "arena"]:
		check(here in av, "'%s' is taught when its system is in" % here)
	s.dispose()


func test_each_new_lesson_finishes_on_the_thing_itself() -> void:
	var s := _all_systems()
	var t: Tutorial = s.tutorial
	for pair in [["phone", "menu_phone"], ["car", "driving"], ["car_radio", "radio_on"], ["rackets", "menu_rackets"]]:
		_finish_until(s, pair[0])
		check_eq(_ids(s), pair[0], "%s is on screen" % pair[0])
		t.note(pair[1])
		t.tick(s)
		check(t.done.has(pair[0]), "%s finishes on %s" % [pair[0], pair[1]])
	for pair in [["squad_orders", "field_order"], ["works", "stash_works"], ["round", "cash_round"], ["arena", "race_enter"]]:
		t.done.erase(pair[0])
		t.command_done("pilot", pair[1])
		check(t.done.has(pair[0]), "%s finishes on the %s command" % [pair[0], pair[1]])
	t.done.erase("round")
	t.command_done("boss", "goods_round")
	check(t.done.has("round"), "a delivery round counts too")
	t.done.erase("arena")
	s.bus.emit("race_run", s.time, "", ["runner"], {"id": "car-HAR", "place": 2})
	check(t.done.has("arena"), "and finishing a race")
	t.done.erase("renown")
	s.renown.add(45.0, "test")
	t.tick(s)
	check(t.done.has("renown"), "a name of 40 points finishes the renown lesson")
	s.dispose()


func test_prisoners_get_a_tip_once() -> void:
	var s := _all_systems()
	s.rackets.held = 3
	s.tutorial.tick(s)
	check(s.tutorial.tips_shown.has("prisoners"), "holding prisoners shows the tip")
	check(s.tutorial.tip.contains("ransom"), "and says what to do: %s" % s.tutorial.tip)
	s.tutorial.tip = ""
	s.tutorial.tick(s)
	check_eq(s.tutorial.tip, "", "once only")
	s.dispose()


func test_finishing_the_last_lesson_shows_the_closing_card_for_a_while() -> void:
	var s := _sess()
	for l in Tutorial.LESSONS:
		if s.tutorial._needs_ok(l[1]):
			s.tutorial.done[l[0]] = true
	check_eq(_ids(s), "", "nothing left to teach")
	check_eq(s.tutorial.view().id, "", "and no card before it was finished just now")
	s.tutorial.done.erase("jobs")
	s.tutorial.complete("jobs")
	var v: Dictionary = s.tutorial.view()
	check_eq(v.id, "complete", "the closing card: %s" % [v])
	check_eq(v.step, v.of, "all of them")
	check(s.messages.any(func(m): return str(m[1]).contains("everything for now")), "and it is said")
	s.time += Tutorial.GRADUATION_S + 1.0
	check_eq(s.tutorial.view().id, "", "it goes away after a while")
	s.tutorial.set_enabled(false)
	s.time = s.tutorial.graduated_at + 1.0
	check_eq(s.tutorial.view().on, false, "and is not shown when the tutorial is off")
	s.dispose()

