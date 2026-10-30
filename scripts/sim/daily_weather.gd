class_name DailyWeather
extends RefCounted
## Weather for the story game (owner, 30 Oct: make the first chapters less bare). Without an HQ season nothing set the weather, so every
## career flight was calm and clear. Now the sky turns over every EVERY_S of game time: mostly clear, some cloud, now and then a storm,
## the trade wind from the east at 4 to 30 kt as HQ.SKIES gives for the sky. The first period stays calm (a gentle start), the next one is
## forecast in the News and on the screen FORECAST_LEAD_S ahead, so a run can be timed round a storm.
##
## Story sessions only, and never when an HQ season sets the weather (Nights). Own RNG stream (seed + 179). Session.set_weather does the
## rest (the flight model's wind and turbulence, what the police can see, sea fog). An opt-in switch: parity sessions have no story.

static var ENABLED := true

const EVERY_S := 7200.0  ## two game hours a spell
const FORECAST_LEAD_S := 900.0
const SKY_WEIGHTS := [["clear", 0.6], ["cloud", 0.3], ["storm", 0.1]]
const TRADE_DIR := [60, 120]  ## where the wind blows from, degrees: the trades are easterly

var sess
var rng: PyRandom
var next := {}  ## the weather coming at next_t
var next_t := -1.0
var announced := false


func _init(sess_, rng_: PyRandom) -> void:
	sess = sess_
	rng = rng_


func update(_dt: float) -> void:
	if not ENABLED or sess.story == null or sess.nights != null:
		return
	if next_t < 0.0:
		next_t = sess.time + EVERY_S * 0.5  # the first spell stays as it is: calm
		next = _pick()
		return
	if not announced and sess.time >= next_t - FORECAST_LEAD_S:
		announced = true
		var text := "Weather: %s from about %s, wind %03d at %d kt." % [_sky_words(str(next.sky)), _clock(next_t), int(next.wind_dir), int(next.wind_kt)]
		sess.say(text)
		if sess.econ != null:
			sess.econ.news.append([sess.time, text])
			Py.keep_last(sess.econ.news, 12)
	if sess.time >= next_t:
		sess.set_weather(next)
		sess.say("The weather turns: %s, wind %03d at %d kt." % [_sky_words(str(next.sky)), int(next.wind_dir), int(next.wind_kt)])
		next = _pick()
		next_t += EVERY_S
		announced = false


## For StrategicSave: the scheduler and the weather now (its fog too, so restoring draws nothing).
func capture(now_weather: Dictionary) -> Dictionary:
	return {"next_t": next_t, "next": next.duplicate(), "announced": announced, "now": now_weather.duplicate()}


func restore(d: Dictionary) -> void:
	next_t = float(d.get("next_t", -1.0))
	next = (d.get("next", {}) as Dictionary).duplicate() if d.get("next") is Dictionary else {}
	announced = bool(d.get("announced", false))
	var now = d.get("now", {})
	if now is Dictionary and not (now as Dictionary).is_empty():
		sess.set_weather(now)  # carries its fog, so no fog roll
	if next.is_empty():
		next_t = -1.0  # a damaged entry: start the schedule again


func _pick() -> Dictionary:
	var r := rng.random()
	var sky := "clear"
	var acc := 0.0
	for pair in SKY_WEIGHTS:
		acc += float(pair[1])
		if r < acc:
			sky = str(pair[0])
			break
	var wr: Array = HQ.SKIES[sky][1]
	return {"sky": sky, "wind_kt": rng.randint(int(wr[0]), int(wr[1])), "wind_dir": rng.randint(TRADE_DIR[0], TRADE_DIR[1]), "moon": 0.5}


static func _sky_words(sky: String) -> String:
	return {"clear": "clear skies", "cloud": "cloud and showers", "storm": "a storm, squalls and low cloud"}.get(sky, sky)


static func _clock(t: float) -> String:
	return "%d:%02d" % [int(t / 3600.0) % 24, int(t / 60.0) % 60]
