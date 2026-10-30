extends TestCase
## The story (Costa Brava 1979-1989): chapters open the game's systems and locks
## one at a time; the open mode has all of them from the start.


func after_each() -> void:
	World.use_map(0)


func _story(index := 0) -> Session:
	var s := Session.new({"seed": 5, "map_seed": MapCity.SEED, "fog": true, "career": true})
	Story.new(index).attach(s)
	return s


func _open_session() -> Session:
	var o := {"seed": 5, "map_seed": MapCity.SEED}
	for k in Session.SYSTEMS:
		o[k] = true
	o["trade"] = true
	return Session.new(o)


func test_1979_is_grass_and_corners() -> void:
	var s := _story()
	check(s.trade != null and s.payroll != null and s.chronicle != null, "the trade, the hiring hall and the papers")
	check(not s.trade.connected, "no cocaine until the connection calls")
	for sys in [s.logistics, s.ground, s.family, s.agency, s.island, s.court]:
		check(sys == null, "the rest waits for its chapter")
	check(not s.unlocked("guns"), "no guns yet")
	check(s.unlocked("role_driver"), "roles nobody locks are open")
	check_eq(s.command(Roles.PILOT, "buy_weapons", {"tier": "rifle", "n": 1})[1], "No gun dealer will talk to us yet.")
	for w in s.payroll.candidates["org"]:
		check(not (w.role in ["soldier", "mule"]), "no soldiers or mules in the hall (%s)" % w.role)
	for af in s.world.airfields:
		if af.kind in ["shady", "bush"]:
			s.refresh_board(af.code)
			for j in s.boards[af.code]:
				check(j.weapons.is_empty(), "no gun runs on the boards")
	check(s.narrative == s.story, "the HUD shows the story's chapter")
	check_eq(s.story.chapter.year, 1979)
	s.dispose()


func test_the_goals_count_what_happens() -> void:
	var s := _story()
	for i in 2:
		s.bus.emit("job_delivered", s.time, "", ["runner"], {"job_id": "J", "pay": 0, "dest": "X", "hot": true, "good": "marijuana", "lb": 150.0})
	s.story.tick(s)
	check_near(s.story.progress["weed_lb"], 300.0, 0.01, "300 lb of grass counted")
	check(s.story.index == 0, "but no dealer yet, no money: still 1979")
	s.trade.earned = 5000
	s.story.tick(s)
	check_eq(s.story.index, 0, "still needs a dealer on a corner")
	s.dispose()


## The HUD's NEXT line asks `s.narrative` (a Story in play) for the first goal still to do.
func test_the_hud_next_line_names_the_first_goal_still_to_do() -> void:
	var s := _story()
	var first: String = ""
	for o in s.story.chapter.objectives:
		if not o.optional:
			first = o.text
			break
	check_eq(s.story.next_objective_text(), first, "starts at the chapter's first required goal")
	for o in s.story.chapter.objectives:
		if not o.optional:
			s.story.progress[o.key] = o.target
	check_eq(s.story.next_objective_text(), "", "nothing left when every required goal is met")
	s.dispose()


func test_the_company_choice_changes_faction_support_and_port_control() -> void:
	var s := _story(Story.index_of("The Company"))
	s.story.progress["agency_jobs"] = 1.0
	s.story.progress["guns_to_company"] = 4.0
	check(s.story.company_choice_ready(), "the choice opens after both Company jobs")
	var trust_before: float = s.agency.trust
	var respect_before: float = s.family.respect
	var odds_before: float = s.island.ship_odds()[0]
	check(s.story.choose_general("remove"), "the Agency order can be accepted")
	check_eq(s.story.company_decision, "remove")
	check_eq(s.island.controller, "mob", "the Morettis take the port")
	check(s.family.respect > respect_before, "the Morettis gain influence and regard us better")
	check(s.agency.trust > trust_before, "the Company rewards compliance")
	check(s.island.ship_odds()[0] < odds_before, "Mob-controlled customs makes our containers safer")
	s.money = 100000
	var expected_cost := int(100 * Island.PRICE_PER_LB * s.island.price_mult * s.econ.wholesale("cocaine")) + Island.SHIP_FREIGHT + 4000
	check_eq(s.island.ship("ship", 100), "", "the Mob-controlled port accepts a container")
	check_eq(100000 - s.money, expected_cost, "the port takes its fee")
	check_eq(Story.from_dict(s.story.to_dict()).company_decision, "remove", "the branch survives a story save")
	var island_save := StrategicSave.capture(s)
	var restored := _story(Story.index_of("The Company"))
	StrategicSave.restore(restored, island_save)
	check_eq(restored.island.controller, "mob", "island control survives a strategic save")
	s.story.tick(s)
	check(s.story.chapter.briefing.contains("Moretti-backed government"), "the next chapter reflects the island takeover")
	s.dispose()
	restored.dispose()


func test_refusing_the_company_order_costs_agency_support_and_wins_mob_support() -> void:
	var s := _story(Story.index_of("The Company"))
	s.story.progress["agency_jobs"] = 1.0
	s.story.progress["guns_to_company"] = 4.0
	var trust_before: float = s.agency.trust
	var respect_before: float = s.family.respect
	s.agency.protected_until = s.time + 1000.0
	check(s.story.choose_general("spare"), "the order can be refused")
	check_eq(s.island.controller, "general", "the General remains in power")
	check(s.family.respect > respect_before, "the Morettis value our independence")
	check(s.agency.trust < trust_before, "the Company loses trust")
	check(s.agency.protected_until <= s.time, "the Company withdraws its protection")
	check(not s.story.choose_general("spare"), "a saved choice cannot be changed")
	s.story.tick(s)
	check(s.story.chapter.briefing.contains("Company has withdrawn"), "the next chapter reflects the broken Agency tie")
	s.dispose()


## Owner, 16 Oct: the General's fate is an optional goal (the two-goal rule stays), but the chapter must not close before the order is put to the player.
func test_the_company_chapter_waits_for_the_order_and_the_player_may_walk_away() -> void:
	var s := _story(Story.index_of("The Company"))
	s.story.progress["agency_jobs"] = 1.0
	s.story.progress["guns_to_company"] = 4.0
	s.story.tick(s)
	check_eq(s.story.chapter.title, "The Company", "both required goals are done, but the chapter waits for the order")
	var trust_before: float = s.agency.trust
	check(s.story.choose_general("declined"), "the player may walk away")
	check_eq(s.agency.trust, trust_before, "walking away changes nothing else")
	check(not s.story.choose_general("remove"), "and a decision cannot be changed afterwards")
	s.story.tick(s)
	check_eq(s.story.chapter.title, "Kingpin", "the chapter closes once the order is answered")
	check(s.story.chapter.briefing.contains("turned the Company down"), "and the next chapter says so")
	check_eq(Story.from_dict(s.story.to_dict()).company_decision, "declined", "the decision survives a save")
	s.dispose()


func test_chapters_open_the_game_in_order() -> void:
	var s := _story()
	s.trade.stock.marijuana = 250.0  # grass held the 1979 way: one pool
	s.story.advance()
	check_eq(s.story.chapter.title, "The Connection")
	check(s.ground == null, "1980: still no war")
	check(s.logistics != null, "1980: logistics - product and cash have places now")
	check_near(s.logistics.total("marijuana"), 250.0, 0.01, "what we held is in a stash")
	s.story.advance()
	check_eq(s.story.chapter.title, "Blotter")
	check(s.psych != null, "1980: the Sunrise Collective")
	check(s.ground == null, "still no war")
	s.story.advance()
	check(s.trade.connected, "1981: the Colombians have called")
	check(s.ground != null and s.foot != null, "Los Cuervos and the street war")
	check(s.unlocked("guns") and s.unlocked("role_soldier"), "guns and soldiers")
	check(not s.unlocked("role_mule"), "mules wait for the island")
	s.story.advance()
	check(s.family != null, "1982: the Morettis")
	s.story.advance()
	check(s.court != null, "1983: the federal court")
	s.story.advance()
	check(s.island != null and s.unlocked("role_mule"), "1984: Isla Soberana, and mules")
	check_eq(s.police.territory_y, Island.TERRITORY_Y, "the task force stops at the island's line")
	check(s.agency == null, "no Company yet")
	s.story.advance()
	check(s.casino != null, "1984: the Family's house on the island")
	check(s.agency == null, "still no Company")
	s.story.advance()
	check(s.agency != null and s.agency.prng != null, "1985: the Company and its pipeline")
	s.story.advance()
	check_eq(s.story.chapter.title, "Kingpin")
	s.money = 300000
	s.story.tick(s)
	check_eq(s.story.chapter.title, "The Hearings", "a quarter of a million is not the end now")
	s.story.progress["case_cold"] = 30.0
	s.story.tick(s)
	check_eq(s.story.chapter.title, "Last Flight", "a cold case and $40,000 in the bank: on")
	s.story.progress["case_cold"] = 20.0
	s.story.tick(s)
	check(s.story.completed_all, "$90,000 and clear of the law: the end")
	for k in Story.LOCKS:
		check(s.unlocked(k), k + " open after the end")
	s.dispose()


func test_the_war_can_arrive_mid_game() -> void:
	var s := _story(Story.index_of("Blotter"))
	for i in 120:
		s.update(1.0, ControlMapper.InputFrame.new(), null)
	s.story.advance()
	for i in 120:
		s.update(1.0, ControlMapper.InputFrame.new(), null)
	check(s.ground.squads.size() > 0, "squads on the streets once the war opens (%d)" % s.ground.squads.size())
	s.dispose()


func test_a_saved_story_rebuilds_its_chapters() -> void:
	var d := {"index": 6, "progress": {"island_runs": 1.0}, "done": false, "v": 3}
	var s := Session.new({"seed": 5, "map_seed": MapCity.SEED, "career": true})
	var st := Story.from_dict(d)
	st.attach(s)
	check_eq(st.chapter.title, "Isla Soberana")
	check_near(st.progress["island_runs"], 1.0, 0.01, "progress kept")
	check(s.trade.connected, "the connection stays made")
	for sys in [s.trade, s.logistics, s.payroll, s.ground, s.family, s.court, s.island]:
		check(sys != null, "chapters 1-6 built")
	check(s.agency == null, "chapter 7 not yet")
	check_eq(Story.from_dict(st.to_dict()).index, 6, "round trip")
	check_eq(Story.from_dict({"index": 5, "progress": {}, "done": false}).chapter.title, "Isla Soberana", "a version 1 save's chapter 6 is still Isla Soberana")
	check_eq(Story.from_dict({"index": 1, "progress": {}, "done": false, "v": 2}).chapter.title, "The Connection", "and a version 2 save before Blotter stays put")
	check_eq(Story.from_dict({"index": 2, "progress": {}, "done": false, "v": 2}).chapter.title, "Cocaine Cowboys", "while its chapter 3 moves up one")
	s.dispose()


func test_open_mode_has_everything() -> void:
	var s := _open_session()
	check(s.story == null, "no story")
	for sys in [s.trade, s.payroll, s.ground, s.family, s.court, s.agency, s.island, s.chronicle]:
		check(sys != null, "every system from the first minute")
	for k in Story.LOCKS:
		check(s.unlocked(k), k)
	check(s.trade.connected, "cocaine from the start (no career)")
	s.dispose()


func test_the_chapter_list() -> void:
	check_eq(Story.CHAPTERS.size(), 12)
	var years := Story.CHAPTERS.map(func(c): return c[0])
	var sorted := years.duplicate()
	sorted.sort()
	check_eq(years, sorted, "in date order")
	var opened := Story.opens_through(12)
	for k in Session.SYSTEMS:
		check(k in opened, "chapter by chapter, every system opens: " + k)
	for k in Story.LOCKS:
		check(k in opened, "and every lock: " + k)


func test_no_softlocks_when_a_faction_is_gone() -> void:
	var s := _story(Story.index_of("Family Business"))
	check_eq(s.story.chapter.title, "Family Business")
	s.family.gone = true
	s.money = 70000
	s.story.tick(s)
	check_eq(s.story.chapter.title, "The Task Force", "the Morettis convicted first: the chapter still ends")
	s.story.advance()
	s.story.advance()
	s.story.advance()
	check_eq(s.story.chapter.title, "The Company")
	s.agency.hung_out = true
	s.story.tick(s)
	check_eq(s.story.chapter.title, "Kingpin", "the Company cut us loose: on to the end")
	check_eq(s.story.company_decision, "skipped", "no assassination order remains after the Company abandons us")
	s.dispose()


func test_open_mode_starts_with_a_float_and_a_save_keeps_its_money() -> void:
	var path := OS.get_user_data_dir().path_join("test_open_float.json")
	DirAccess.remove_absolute(path)
	var s := Session.load_or_new(path, {"features": Session.SANDBOX_FEATURES, "money": Session.OPEN_FLOAT})
	check_eq(s.money, Session.OPEN_FLOAT, "a new open game starts with the float")
	s.money = 4321
	s.save()
	s.dispose()
	var t := Session.load_or_new(path, {"features": Session.SANDBOX_FEATURES, "money": Session.OPEN_FLOAT})
	check_eq(t.money, 4321, "a saved game keeps its own money")
	t.dispose()
	DirAccess.remove_absolute(path)
	var u := Session.load_or_new(path, {"features": Session.SANDBOX_FEATURES})
	check_eq(u.money, Session.START_MONEY, "without a float (the story) it's the old start")
	u.dispose()
	DirAccess.remove_absolute(path)


func test_blotter_wants_the_collective_and_ends_with_the_lab_taken() -> void:
	var s := _story(Story.index_of("Blotter"))
	check(s.psych != null, "the Collective is there")
	s.bus.emit("acid_barter", s.time, "", ["runner"], {"lb": 120.0, "sheets": 3.0})
	s.bus.emit("acid_barter", s.time, "", ["runner"], {"lb": 90.0, "sheets": 2.0})
	s.bus.emit("acid_sold", s.time, "", ["runner"], {"sheets": 21.0, "pay": 5000})
	var before: float = s.police.case("runner").suspicion
	s.story.tick(s)
	check_eq(s.story.chapter.title, "Cocaine Cowboys", "210 lb traded and 21 sheets sold: on")
	check_eq(s.psych.status, "hiding", "the task force took the lab")
	check(s.psych.hide_until - s.time > 5.0 * 3600.0, "and Nico is gone for hours")
	check(s.police.case("runner").suspicion >= before + 9.9, "and the trail leads to us")
	s.dispose()


func test_side_goals_pay_once_and_are_never_needed() -> void:
	var s := _story(Story.index_of("The Connection"))
	var m: int = s.money
	s.story.progress["cash_home"] = 3000.0
	s.story.progress["connected"] = 1.0
	s.trade.connected = true
	s.story.tick(s)
	check_eq(s.story.chapter.title, "Blotter", "the required goals end the chapter without the side goal")
	var t := _story(Story.index_of("The Connection"))
	var n: int = t.money
	t.bus.emit("vehicle_bought", t.time, "", ["runner"], {"id": "coupe", "price": 6500})
	t.story.tick(t)
	check_eq(t.money, n + 2000, "the side goal paid its bonus")
	t.story.tick(t)
	check_eq(t.money, n + 2000, "once")
	check(t.story.objective_lines().any(func(l): return str(l).contains("optional before chapter ends: +$2,000")), "and the card says it is optional")
	check(m > 0, "")
	s.dispose()
	t.dispose()


func test_the_hearings_count_cold_minutes_in_a_row() -> void:
	var s := _story(Story.index_of("The Hearings"))
	s.story.tick(s)
	for i in 10:
		s.time += 60.0
		s.story.tick(s)
	check_near(s.story.progress["case_cold"], 10.0, 0.01, "ten cold minutes")
	s.police.case("runner").suspicion = 70.0
	s.time += 60.0
	s.story.tick(s)
	check_eq(s.story.progress["case_cold"], 0.0, "a hot case starts the hour again")
	s.dispose()


func test_intercepted_shipments_do_not_complete_the_island() -> void:
	var s := _story(Story.index_of("Isla Soberana"))
	s.bus.emit("island_shipment", s.time, "caught", ["runner"], {"delivered_lb": 0.0})
	s.story.tick(s)
	check_eq(s.story.chapter.title, "Isla Soberana")
	s.bus.emit("island_shipment", s.time, "partial", ["runner"], {"delivered_lb": 2.0})
	s.story.tick(s)
	check_eq(s.story.chapter.title, "The House")
	s.dispose()


func test_failed_evacuation_is_recorded_and_saved() -> void:
	var s := _story(Story.index_of("The House"))
	s.bus.emit("casino_out", s.time, "lost", ["runner"], {"evacuated": false})
	check(s.story.outcomes.has("casino_out"))
	check_eq(s.story.progress.get("casino_out", 0), 0)
	var restored := Story.from_dict(s.story.to_dict())
	check_eq(restored.outcomes, s.story.outcomes)
	check(restored.objective_lines().any(func(l): return "[missed]" in l))
	s.dispose()


func test_chapter_history_keeps_guidance_after_advancement() -> void:
	var s := _story()
	s.story.advance()
	check_eq(s.story.history.size(), 1)
	check_eq(s.story.history[0].title, "Square Grouper")
	var restored := Story.from_dict(s.story.to_dict())
	check_eq(restored.history, s.story.history)
	check("1,200" in restored.guidance())
	check("Square Grouper" in restored.journal_text())
	s.dispose()


func test_laundering_without_ownership_does_not_buy_a_stake() -> void:
	var s := _story(Story.index_of("The House"))
	s.casino.laundered = 100.0
	s.casino.stake = 0.0
	s.story.tick(s)
	check_eq(s.story.progress.get("casino_stake", 0), 0)
	s.dispose()


func test_unavailable_family_notice_is_not_repeated_while_collecting_cash() -> void:
	var s := _story(Story.index_of("Family Business"))
	s.family.gone = true
	s.money = 0
	s.story.tick(s)
	var count := s.messages.size()
	s.story.tick(s)
	check_eq(s.messages.size(), count, "waiver does not spam the event feed")
	check_eq(s.story.progress.get("family_deal", 0), 0, "no fabricated transaction")
	check(s.story.outcomes.has("family_deal"))
	s.dispose()


## The debug skip (Ctrl+F5) moves to the next chapter each time, leaves the employed opening first, and finishes the story at the end.
func test_debug_skip_walks_through_the_chapters_to_the_end() -> void:
	var s := Session.new({"seed": 5, "map_seed": MapCity.SEED, "location": "HAR", "career": true, "save_path": "user://test_debug_skip.json"})
	var st := Story.new_employed()
	st.attach(s)
	var last := 0
	var steps := 0
	while not st.completed_all and steps < 40:
		st.debug_skip_chapter()
		steps += 1
		if not st.completed_all:
			check(st.chapter.num >= last, "never goes backwards: %d after %d" % [st.chapter.num, last])
			last = st.chapter.num
	check(st.completed_all, "and the last skip finishes the story")
	check(last >= Story.CHAPTERS.size() - 1, "having passed through the chapters (reached %d)" % last)
	s.dispose()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_debug_skip.json"))


## Goal checks are forgiving at the start and sparing later (owner, 12 Oct): chapter 1 needs 150 lb and $2,500, chapter 2 $2,000 home, and from chapter 3 no chapter
## asks for more than two required goals, except The House, whose three goals are a chain (stake, laundering, then getting out).
func test_goal_checks_are_forgiving_early_and_sparing_later() -> void:
	var targets := {}
	for o in Story.CHAPTERS[0][4]:
		targets[o[0]] = o[2]
	check_eq(targets["weed_lb"], 150, "chapter 1: 150 lb")
	check_eq(targets["trade_earned"], 2500, "chapter 1: $2,500")
	var home := 0
	for o in Story.CHAPTERS[1][4]:
		if o[0] == "cash_home":
			home = o[2]
	check_eq(home, 2000, "chapter 2: $2,000 home")
	for i in range(2, Story.CHAPTERS.size()):
		var required := 0
		for o in Story.CHAPTERS[i][4]:
			if not (o.size() > 3 and o[3]):
				required += 1
		if Story.CHAPTERS[i][1] == "The House":
			check_eq(required, 3, "The House keeps exactly its three chained goals (stake, laundering, getting out)")
		else:
			check(required <= 2, "%s asks for %d required goals (limit 2)" % [Story.CHAPTERS[i][1], required])


## The early game is gentle: the police suspicion multiplier is 0.1 in chapters 1-2 (and the employed opening), 0.5 in chapter 3, 1 from chapter 4.
func test_the_police_pace_follows_the_chapter() -> void:
	check_eq(Story.early_police_scale(0), 0.1)
	check_eq(Story.early_police_scale(1), 0.1)
	check_eq(Story.early_police_scale(2), 0.5)
	check_eq(Story.early_police_scale(3), 1.0)
	check_eq(Story.early_police_scale(11), 1.0)
	var s := Session.new({"seed": 5, "map_seed": MapCity.SEED, "location": "HAR", "career": true, "save_path": "user://test_police_pace.json"})
	var st := Story.new_employed()
	st.attach(s)
	check_eq(s.police.suspicion_scale, 0.1, "the employed opening is as gentle as chapter 1")
	st.select_chapter(3)
	check_eq(s.police.suspicion_scale, 0.5, "chapter 3")
	st.select_chapter(6)
	check_eq(s.police.suspicion_scale, 1.0, "chapter 6")
	PoliceSystem.EARLY_PACE = false
	st._set_police_pace(0)
	check_eq(s.police.suspicion_scale, 1.0, "the switch off leaves full strength")
	PoliceSystem.EARLY_PACE = true
	s.dispose()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_police_pace.json"))


## What a radar sighting adds is scaled: the same dark flight in radar range gains a tenth of the suspicion in chapter 1.
func test_a_sighting_in_chapter_one_adds_a_tenth_of_the_suspicion() -> void:
	var gained := []
	for scale in [1.0, 0.1]:
		var s := Session.new({"seed": 5, "map_seed": MapCity.SEED, "location": "HAR", "ground_war": false})
		s.police.suspicion_scale = scale
		var af := World.airfield("HAR")
		s.spawn_airborne(af.x + 6000.0, af.y, 90.0, 400.0, 95.0)
		s.transponder = false
		for i in 60 * 30:
			var inp := ControlMapper.InputFrame.new()
			inp.throttle_axis = 0.8
			s.update(1.0 / 30, inp, null)
		gained.append(s.police.case("runner").suspicion)
		s.dispose()
	check(gained[0] > 5.0, "a dark minute in radar range builds suspicion at full strength: %s" % gained[0])
	check(gained[1] < gained[0] * 0.3, "and a tenth as much with the early-game scale: %s against %s" % [gained[1], gained[0]])
