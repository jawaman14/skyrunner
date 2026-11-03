class_name Pacing
extends RefCounted
## Pacing targets, measured (owner, 4 November 2026, D-94: the World of Warcraft study, DESIGN §55). WoW was tuned so that something
## finished every few minutes: a quest handed in, a level, a drop. This listens to a session the way a tester would and reports the
## gaps between finished things against the targets below, so a change that leaves the player with nothing to show for twenty
## minutes is visible in `tools/playtest.gd`'s digest. Read-only: it subscribes to the event bus and reads the story; no draws.

## A finished thing the player sees: the event kinds that end a piece of work (heard by the runner).
const BEATS := ["job_delivered", "bales_delivered", "bulk_sale", "order_filled", "cash_home", "strip_found", "island_shipment",
	"raid_foiled", "race_run", "acquitted", "quashed", "casino_laundered"]
## The targets: the typical gap between finished things, the longest dry spell, and the longest wait for a story goal.
const TARGETS := {"median_gap_s": 300.0, "longest_gap_s": 900.0, "goal_gap_s": 1800.0}

var start := 0.0
var beats: Array = []  ## [[time, what]]
var goals: Array = []  ## times a story goal (required or side) or a chapter was finished
var _done := {}  ## the story goals already counted ("chapter:key", "chapter N", "employer stage N"): each counts once
var _primed := false


func _init(s) -> void:
	start = float(s.time)
	s.bus.subscribe("*", func(ev): _on_event(ev))
	poll(s)


func _on_event(ev) -> void:
	if not BEATS.has(ev.kind) or not ev.audience.has("runner"):
		return
	if ev.kind == "island_shipment" and float(ev.data.get("delivered_lb", 0.0)) <= 0.0:
		return  # customs took it all: nothing got through
	beats.append([float(ev.t), str(ev.kind)])


## Call now and then (the playtest calls it once a simulated second): notices a story goal, an employer's stage or a chapter
## finishing. Each counts once, so a goal that is met, lost and met again (money in the bank) is not a second beat.
func poll(s) -> void:
	var fresh := 0
	for id in done_ids(s):
		if not _done.has(id):
			_done[id] = true
			fresh += 1
	if _primed and fresh > 0:
		goals.append(float(s.time))
		beats.append([float(s.time), "story goal"])
	_primed = true  # what was already done when the session started is not a beat


## The story goals met so far, by identity: this chapter's met objectives, every chapter before it, and the employed
## opening's finished stages.
static func done_ids(s) -> Array:
	if s.story == null:
		return []
	var st = s.story
	var out := []
	for i in int(st.index):
		out.append("chapter %d" % (i + 1))
	for o in st.chapter.objectives:
		if st.outcomes.has(o.key) or float(st.progress.get(o.key, 0.0)) >= float(o.target):
			out.append("%d:%s" % [int(st.chapter.num), str(o.key)])
	if st.get("employment") != null:
		for i in int(st.employment.stage):
			out.append("employer stage %d" % (i + 1))
	return out


## The gaps between start, each finished thing and now, in seconds.
static func gaps(times: Array, from: float, now: float) -> Array:
	var out := []
	var last := from
	var sorted := times.duplicate()
	sorted.sort()
	for t in sorted:
		out.append(float(t) - last)
		last = float(t)
	out.append(now - last)
	return out


static func median(xs: Array) -> float:
	if xs.is_empty():
		return 0.0
	var v := xs.duplicate()
	v.sort()
	var m := v.size() / 2
	return float(v[m]) if v.size() % 2 == 1 else (float(v[m - 1]) + float(v[m])) / 2.0


func report(now: float) -> Dictionary:
	var g := gaps(beats.map(func(b): return b[0]), start, now)
	var gg := gaps(goals, start, now)
	var r := {
		"beats": beats.size(),
		"median_gap_s": snappedf(median(g), 1.0),
		"longest_gap_s": snappedf(g.max(), 1.0),
		"goals": goals.size(),
		"goal_gap_s": snappedf(gg.max(), 1.0),
		"by_kind": {},
	}
	for b in beats:
		r.by_kind[b[1]] = int(r.by_kind.get(b[1], 0)) + 1
	var missed := []
	for k in TARGETS:
		if float(r[k]) > float(TARGETS[k]):
			missed.append("%s %.0f > %.0f" % [k, float(r[k]), float(TARGETS[k])])
	r["targets"] = TARGETS
	r["missed"] = missed
	return r
