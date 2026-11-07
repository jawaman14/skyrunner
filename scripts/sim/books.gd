class_name Books
extends RefCounted
## The daily books (F-6, docs/EMPIRE_SIMULATION_SPEC.md section 5): once a game day at 06:00 each org's day is closed from the
## ledger: what came in and what went out, by reason, and the balance it ends on. Read-only on the money; the scheduler calls it.
## Wages, rent and debt service move onto this tick with the businesses (L-1, L-4); a business that can't pay goes into arrears
## with a blocked reason there. Saved: the closed days, and from F-6b the day's debrief (Debrief) that replaces the nights' report.

const DAY_S := 86400.0
const HOUR := 6.0  ## the books close at 06:00
const KEEP := 14  ## closed days kept
const ORGS := ["org", "police", "rival", "family", "moretti"]

var sess
var closed: Array = []  ## [{day, t, org, in: {reason: $}, out: {reason: $}, net, ends}]
var _since := 0.0  ## when the day being kept began
## The day being kept, per org: {in: {reason: $}, out: {reason: $}}. Summed as each transfer is booked, because the ledger folds
## its oldest rows away (Ledger.LOG_MAX) and a busy war day books more than that before 06:00 (Codex on #511). Saved.
var _open := {}
## F-6b: the debriefs, one per closed day (Debrief.build), and the day under way's event tally (kind -> count) and the heat it
## began on. Saved, so a load mid-day gives the same debrief as playing straight through.
var debriefs: Array = []
var _tally := {}
var _heat_open := -1.0


func _init(sess_) -> void:
	sess = sess_
	_since = float(sess.time)
	sess.ledger.on_transfer = _note
	sess.bus.subscribe("*", _on_event)
	_heat_open = Debrief.heat_of(sess)


func _on_event(e) -> void:
	if Debrief.TALLY.has(e.kind) and Debrief.ours(e):
		_tally[e.kind] = int(_tally.get(e.kind, 0)) + 1


## The ledger's hook: count a transfer into the day it falls in. A row stamped at or after the close lands in the next day.
func _note(from: String, to: String, amount: float, reason: String, _t: float) -> void:
	if reason == "open":
		return  # an opening balance is not a day's takings; `ends` carries it
	for o in ORGS:
		var pre: String = o + ":"
		var a_in := to.begins_with(pre)
		var a_out := from.begins_with(pre)
		if a_in == a_out:
			continue  # not this org's, or between its own accounts
		if not _open.has(o):
			_open[o] = {"in": {}, "out": {}}
		var bucket: Dictionary = _open[o]["in" if a_in else "out"]
		bucket[reason] = float(bucket.get(reason, 0.0)) + amount


## The next 06:00 strictly after `t`.
static func next_close(t: float) -> float:
	var at := floorf(t / DAY_S) * DAY_S + HOUR * 3600.0
	return at if at > t else at + DAY_S


## Close the day ending `t`: one row per org that had any money move. Emits "books" with the rows.
func close(t: float) -> Array:
	var rows := []
	for o in ORGS:
		var r := _row(o, t)
		if not r.in.is_empty() or not r.out.is_empty():
			rows.append(r)
	var org_row := _row("org", t)  # even on a day with no outside money: its balance still ends somewhere (Codex on #515)
	var heat := Debrief.heat_of(sess)
	var d := Debrief.build(int(t / DAY_S), t, org_row, _tally, heat, _heat_open, Debrief.street_cash_of(sess))
	debriefs.append(d)
	while debriefs.size() > KEEP:
		debriefs.pop_front()
	_tally = {}
	_heat_open = heat
	_open = {}
	closed.append_array(rows)
	while closed.size() > KEEP * ORGS.size():
		closed.pop_front()
	_since = t
	sess.bus.emit("books", t, "", ["runner", "law"], {"rows": rows, "day": int(t / DAY_S)})
	sess.bus.emit("debrief", t, Debrief.line(d), ["runner"], d)  # the night's report, from the books (F-6b)
	sess.say(Debrief.line(d))
	return rows


## One org's closing row from the day kept so far.
func _row(o: String, to: float) -> Dictionary:
	var day: Dictionary = _open.get(o, {"in": {}, "out": {}})
	return _summed(o, to, (day.in as Dictionary).duplicate(), (day.out as Dictionary).duplicate())


func _summed(o: String, to: float, into: Dictionary, out: Dictionary) -> Dictionary:
	var pre := o + ":"
	var net := 0.0
	for k in into:
		net += float(into[k])
	for k in out:
		net -= float(out[k])
	var ends := 0.0
	for acct in sess.ledger.balances:
		if str(acct).begins_with(pre):
			ends += float(sess.ledger.balances[acct])
	return {"day": int(to / DAY_S), "t": to, "org": o, "in": into, "out": out, "net": net, "ends": ends}


## One org's money in [`from`, `to`), read back from the ledger's log: rows that cross the org's accounts (its own transfers
## between its accounts are neither in nor out). Only what the log still holds; the close uses the running day instead.
func day_of(o: String, from: float, to: float) -> Dictionary:
	var pre := o + ":"
	var into := {}
	var out := {}
	for row in sess.ledger.log:
		var t := float(row.t)
		if t < from or t >= to:  # a day is [its start, the next 06:00): a row at 06:00 exactly is the new day's
			continue
		if str(row.reason) == "open":
			continue  # an opening balance is not a day's takings; `ends` carries it
		var a_in: bool = str(row.to).begins_with(pre)
		var a_out: bool = str(row.from).begins_with(pre)
		if a_in == a_out:
			continue
		var bucket: Dictionary = into if a_in else out
		bucket[str(row.reason)] = float(bucket.get(str(row.reason), 0.0)) + float(row.amount)
	return _summed(o, to, into, out)


func capture() -> Dictionary:
	return {"closed": closed.duplicate(true), "since": _since, "open": _open.duplicate(true), "debriefs": debriefs.duplicate(true),
		"tally": _tally.duplicate(), "heat_open": _heat_open}


func restore(d: Dictionary) -> void:
	closed = (d.get("closed", []) as Array).duplicate(true)
	_since = float(d.get("since", _since))
	_open = (d.get("open", {}) as Dictionary).duplicate(true)  # the day under way (an older save: counted from the load on)
	debriefs = (d.get("debriefs", []) as Array).duplicate(true)
	_tally = {}
	for k in d.get("tally", {}):
		_tally[str(k)] = int(d.tally[k])  # (JSON brings the counts back as floats)
	_heat_open = float(d.get("heat_open", -1.0))  # an older save has no baseline: no change is reported for its first day, rather
	# than the whole saved heat (the police case is restored after the books, so the session's heat here is not the save's)
