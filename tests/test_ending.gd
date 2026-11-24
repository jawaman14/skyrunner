extends TestCase
## The ending choice and the sandbox (DESIGN 104; D-70, D-83): once the last chapter is done the player chooses how it ends (walk
## away, go straight, keep the crown); it is recorded in the journal, applied once, never a game over; the years then go on, 1989
## and one a YEAR_S of play; saved; off, no choice.


func after_each() -> void:
	World.use_map(0)
	Story.ENDINGS = true


func _told() -> Session:
	var s := Session.new({"seed": 5, "map_seed": MapCity.SEED, "fog": true, "career": true, "renown": true, "trade": true})
	var st := Story.new(Story.CHAPTERS.size() - 1)
	st.attach(s)
	s.police.frozen = true
	s.story.advance()  # the last chapter closes: the story is told
	return s


func test_the_choice_opens_when_the_story_is_told() -> void:
	var s := Session.new({"seed": 5, "map_seed": MapCity.SEED, "fog": true, "career": true})
	Story.new(3).attach(s)
	check(not s.story.ending_choice_ready(), "not while the chapters run")
	s.dispose()
	var t := _told()
	check(t.story.completed_all and t.story.ending_choice_ready(), "the last chapter done: choose")
	check(t.story.journal_text().contains("Choose how it ends."), "the journal asks")
	check(not t.story.choose_ending("retire to the moon"), "one of the three")
	t.dispose()


func test_each_ending_does_what_it_says_and_play_goes_on() -> void:
	for choice in ["out", "straight", "crown"]:
		var s := _told()
		s.renown.score = 100.0
		var c = s.police.case("runner")
		c.suspicion = 60.0
		check(s.story.choose_ending(choice), "%s chosen" % choice)
		check(not s.story.ending_choice_ready() and not s.story.choose_ending("out"), "%s: chosen once" % choice)
		match choice:
			"out":
				check(is_equal_approx(c.suspicion, 30.0) and is_equal_approx(s.renown.score, 50.0), "walk away: the case cools, the name fades")
			"straight":
				check(is_equal_approx(c.suspicion, 30.0) and is_equal_approx(s.renown.score, 75.0), "go straight: less to look at, a quieter name")
				check(s.trade.trust.own.family >= 50.0, "and the Morettis warm to it")
			"crown":
				check(is_equal_approx(s.renown.score, 250.0) and is_equal_approx(float(s.trade.trust.own.rival), 0.0), "keep the crown: a bigger name, Los Cuervos at war")
		check(s.story.history[-1].title.begins_with("The ending: "), "%s: recorded in the journal" % choice)
		check(s.phase != "busted" and s.story.completed_all, "%s: never a game over" % choice)
		s.dispose()


func test_the_years_go_on_and_are_saved() -> void:
	var s := _told()
	check_eq(s.story.year(), 1989, "1989 when it is told")
	s.story.choose_ending("crown")
	s.time += Story.YEAR_S * 2.5
	check_eq(s.story.year(), 1991, "two years of sandbox later")
	check(s.story.journal_text().contains("1991. The sandbox: the story is told (Keep the crown)"), "the journal says so")
	var d: Dictionary = s.story.to_dict()
	var r := Story.from_dict(JSON.parse_string(JSON.stringify(d)))
	check(r.ending == "crown" and is_equal_approx(r.ended_at, s.story.ended_at), "saved")
	s.dispose()
	Story.ENDINGS = false
	var o := _told()
	check(not o.story.ending_choice_ready(), "off: no choice")
	o.dispose()
