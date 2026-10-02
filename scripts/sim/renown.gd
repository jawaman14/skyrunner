class_name Renown
extends RefCounted
## Renown: how big your name is on the street, in the style of Mount & Blade's renown. It is made of what the
## organisation DOES - loads delivered, deals done, a raid foiled, a jury that let the pilot walk - and unmade, at
## about half weight, by what goes wrong: a bust, a crash, a stash raided, a man who took the government's deal.
## It never goes below nothing, and nothing is lost for idling.
##
## It is read off the event bus (no clock, no random draws), so it cannot disturb any other system's stream.
##
## What a name is worth (tier 0 "Nobody" ... 4 "A legend"):
##   * the hiring hall: candidates are a little better (+3 points of skill and +2 of loyalty per tier)
##   * the bulk buyers pay +1.5% a tier
##   * and the task force watches the famous: suspicion cools 6% slower a tier
## Off for the replays (Renown.ENABLED = false); a session asks for it with `renown: true`.

static var ENABLED := true

const TIERS := [0.0, 40.0, 120.0, 300.0, 650.0]
const NAMES := ["Nobody", "A name on the street", "Known", "Feared", "A legend"]
const LOSS_SHARE := 0.5  ## a setback costs this much of what the same success would earn
const KEEP := 12  ## the last few changes, for the panel

## event kind -> [points, what to call it]. A gain is a success; a loss is paid out at LOSS_SHARE.
const GAINS := {
	"job_delivered": [3.0, "a load delivered"],
	"bales_delivered": [2.0, "bales delivered"],
	"island_shipment": [3.0, "a container through the island's customs"],
	"raid_foiled": [3.0, "a raid foiled"],
	"acquitted": [6.0, "the jury let the pilot walk"],
	"quashed": [4.0, "the case dropped from above"],
	"cash_home": [0.3, "the money home"],
}
const LOSSES := {
	"busted": [6.0, "the pilot busted"],
	"crashed": [3.0, "a crash"],
	"sentenced": [8.0, "the pilot sentenced"],
	"stash_raided": [4.0, "a stash raided"],
	"truck_hijacked": [3.0, "a truck hijacked"],
	"truck_seized": [2.0, "a truck seized"],
	"hijacked": [2.0, "a flight hijacked"],
	"boat_seized": [3.0, "a boat seized"],
}

var sess
var score := 0.0
var recent: Array = []  ## [[time, points, what]], newest last


func _init(sess_) -> void:
	sess = sess_
	for kind in GAINS:
		sess.bus.subscribe(kind, _on_gain)
	for kind in LOSSES:
		sess.bus.subscribe(kind, _on_loss)
	sess.bus.subscribe("bulk_sale", _on_sale)
	sess.bus.subscribe("worker_flipped", _on_flip)


# ------------------------------------------------------------------ the bus
func _on_gain(ev) -> void:
	var g: Array = GAINS[ev.kind]
	add(float(g[0]), str(g[1]))


func _on_loss(ev) -> void:
	var l: Array = LOSSES[ev.kind]
	add(-float(l[0]) * LOSS_SHARE, str(l[1]))


## A bigger sale is a bigger name: 1 point and one more for every 40 lb (or 40 guns), up to 5.
func _on_sale(ev) -> void:
	var qty: float = float(ev.data.get("qty", 0.0))
	add(1.0 + minf(qty / 40.0, 4.0), "a sale to %s" % str(ev.data.get("buyer", "a buyer")))


## Our own man talking is a loss; the rival's is none of our business.
func _on_flip(ev) -> void:
	if str(ev.data.get("outfit", "")) == "org":
		add(-4.0 * LOSS_SHARE, "a man took the government's deal")


## Change the score (never below nothing). The tier going up or down is said.
func add(points: float, what: String) -> void:
	if points == 0.0:
		return
	var before := tier()
	score = maxf(0.0, score + points)
	recent.append([sess.time, points, what])
	Py.keep_last(recent, KEEP)
	var after := tier()
	apply()
	if after > before:
		sess.say("RENOWN - %s. %s" % [NAMES[after], effects_text(after)])
	elif after < before:
		sess.say("RENOWN - the name has slipped: %s." % NAMES[after])


## Put the name's effect on the task force where the police system reads it.
func apply() -> void:
	if sess.police != null:
		sess.police.decay_mult = heat_mult()


# ------------------------------------------------------------------ what a name is worth
static func tier_of(points: float) -> int:
	var t := 0
	for i in TIERS.size():
		if points >= TIERS[i]:
			t = i
	return t


func tier() -> int:
	return tier_of(score)


func title() -> String:
	return NAMES[tier()]


## The next tier's threshold, or -1 at the top.
func next_at() -> float:
	var t := tier()
	return TIERS[t + 1] if t + 1 < TIERS.size() else -1.0


## What the bulk buyers pay, as a multiple.
func price_mult() -> float:
	return 1.0 + 0.015 * tier()


## The hiring hall: skill and loyalty added to every candidate.
func skill_bonus() -> float:
	return 0.03 * tier()


func loyalty_bonus() -> float:
	return 0.02 * tier()


## How fast the task force's suspicion cools, as a multiple (the famous are watched).
func heat_mult() -> float:
	return 1.0 - 0.06 * tier()


static func effects_text(t: int) -> String:
	if t <= 0:
		return "Nobody knows you yet."
	return "Better recruits (+%d skill), buyers pay +%.1f%%, and the task force cools %d%% slower." % [3 * t, 1.5 * t, 6 * t]


func view() -> Dictionary:
	var t := tier()
	return {"score": score, "tier": t, "title": NAMES[t], "next": next_at(), "effects": effects_text(t),
		"recent": recent.map(func(r): return {"t": r[0], "points": r[1], "what": r[2]})}
