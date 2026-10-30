class_name Banter
extends RefCounted
## Rafa and Benny react to what the pilot just did (owner, 30 Oct: make the first chapters less bare): the first butter landing, the
## first hard one, the first night landing, the first hot job, the first radar interest, a crash or a bust, the first money from the
## corners... Each line plays once a game (not saved: a reload may hear one again). Presentation only: it reads the event bus and the
## session, and pushes phone banners; the simulation is untouched.

const RAFA := "Rafa Quintero"
const BENNY := "Benny Ruiz"
## key -> [who, line]
const LINES := {
	"butter": [RAFA, "Smooth. Not a cup spilled. That's how you keep a customer."],
	"hard": [BENNY, "Easy on Rafa's airplane, kid. Gear legs cost more than you do."],
	"night": [RAFA, "First landing after dark? Good. The money flies at night in this business."],
	"first_delivery": [RAFA, "Delivered and paid. Keep this up and you'll own a plane before the rains."],
	"hot_job": [BENNY, "That one's hot. Transponder off over the water, and don't land anywhere with a flag on the tower."],
	"radar": [BENNY, "Somebody at the approach centre asked about your tail number. Vary your routes for a while."],
	"crash": [RAFA, "You walked away. Airplanes can be fixed. Take an easy job, get your nerve back."],
	"busted": [BENNY, "They got the load. Not you, though. Lawyer's on it. Start small again, nobody's counting."],
	"corners": [BENNY, "The corners are selling. Bring the money home before it walks off on its own."],
	"connection": [RAFA, "The Colombians called. Everything changes now. Fly carefully."],
	"order": [BENNY, "A buyer wants something by a time. Check the phone: Work, then the orders. Hit the time, they pay more."],
	"upgrade": [RAFA, "New kit in the airplane. Use it, don't just admire it."],
	"windfall": [BENNY, "Heard you're short. There's honest work on the board for you. Take it, no shame."],
}

var s
var notify  ## PhoneNotify (or anything with push(sender, body, kind))
var said := {}
var hour_fn: Callable  ## () -> the hour of day 0..24 (the pilot app's sky)
var _corners_seen := 0.0


func _init(sess, notify_, hour_fn_ := Callable()) -> void:
	s = sess
	notify = notify_
	hour_fn = hour_fn_
	s.bus.subscribe("*", _on_event)


func say(key: String) -> bool:
	if said.has(key) or not LINES.has(key) or notify == null:
		return false
	said[key] = true
	notify.push(str(LINES[key][0]), str(LINES[key][1]), "phone")
	return true


func _on_event(ev) -> void:
	var d: Dictionary = ev.data if ev.data is Dictionary else {}
	match str(ev.kind):
		"landed":
			if d.has("seconds"):
				var fpm := float(d.get("touchdown_fpm", 0.0))
				if fpm > 0.0 and fpm < 150.0:
					say("butter")
				elif fpm > 400.0:
					say("hard")
				if hour_fn.is_valid():
					var h := float(hour_fn.call())
					if h >= 20.0 or h < 5.0:
						say("night")
		"job_delivered":
			say("first_delivery")
		"job_accepted":
			if bool(d.get("hot", false)):
				say("hot_job")
		"crashed":
			say("crash")
		"busted":
			say("busted")
		"connection":
			say("connection")
		"order_posted":
			say("order")
		"upgrade":
			say("upgrade")


## Called about once a second: what has no event of its own (radar interest, the corners' first money, a windfall on the board).
func tick() -> void:
	if s.police != null and float(s.police.case("runner").suspicion) >= 20.0:
		say("radar")
	if s.trade != null and float(s.trade.earned) > 0.0:
		say("corners")
	if s.location != null and s.boards.get(s.location, []).any(func(j): return str(j.title).begins_with("Windfall")):
		say("windfall")
