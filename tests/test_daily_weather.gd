extends TestCase
## The story game's weather spells (owner, 30 Oct: make the first chapters less bare).


func after_each() -> void:
	DailyWeather.ENABLED = true
	World.use_map(0)


func _story() -> Session:
	var s := Session.new({"seed": 6, "location": "HAR", "career": true})
	Story.new(0).attach(s)
	return s


func test_calm_first_then_a_forecast_then_the_change() -> void:
	var s := _story()
	s.daily_weather.update(1.0)
	check(s.weather.is_empty(), "the first spell stays calm")
	var change := s.daily_weather.next_t
	s.time = change - DailyWeather.FORECAST_LEAD_S + 1.0
	s.daily_weather.update(1.0)
	check(s.econ.news.any(func(n): return str(n[1]).begins_with("Weather:")), "forecast in the News ahead of time")
	check(s.weather.is_empty(), "not yet")
	s.time = change + 1.0
	s.daily_weather.update(1.0)
	check(not s.weather.is_empty() and HQ.SKIES.has(str(s.weather.sky)), "the weather turns: %s" % [s.weather])
	check(int(s.weather.wind_dir) >= 60 and int(s.weather.wind_dir) <= 120, "a trade wind from the east")
	check_near(s.daily_weather.next_t, change + DailyWeather.EVERY_S, 0.01, "the next spell is two hours on")
	s.dispose()


func test_spells_are_mostly_fair() -> void:
	var s := _story()
	var counts := {"clear": 0, "cloud": 0, "storm": 0}
	for i in 300:
		counts[str(s.daily_weather._pick().sky)] += 1
	check(counts.clear > counts.cloud and counts.cloud > counts.storm and counts.storm > 0, "%s" % [counts])
	s.dispose()


func test_only_the_story_game_and_never_over_an_hq_season() -> void:
	var s := Session.new({"seed": 6, "location": "HAR"})
	for i in 10:
		s.time += DailyWeather.EVERY_S
		s.daily_weather.update(1.0)
	check(s.weather.is_empty(), "no story: left alone")
	s.dispose()
	var t := _story()
	DailyWeather.ENABLED = false
	for i in 10:
		t.time += DailyWeather.EVERY_S
		t.daily_weather.update(1.0)
	check(t.weather.is_empty(), "switched off")
	t.dispose()
