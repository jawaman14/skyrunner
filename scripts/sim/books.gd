class_name Books
extends RefCounted
## The daily books (F-6, docs/EMPIRE_SIMULATION_SPEC.md section 5): once a game day at 06:00 each org's day is closed from the
## ledger: what came in and what went out, by reason, and the balance it ends on. Read-only on the money; the scheduler calls it.
## Wages, rent and debt service move onto this tick with the businesses (L-1, L-4); a business that can't pay goes into arrears
## with a blocked reason there. Saved: the closed days (the debriefs that replace the nights' reports, F-6b).

const DAY_S := 86400.0
const HOUR := 6.0  ## the books close at 06:00
const KEEP := 14  ## closed days kept
const ORGS := ["org", "police", "rival", "family"]

var sess
var closed: Array = []  ## [{day, t, org, in: {reason: $}, out: {reason: $}, net, ends}]
var _since := 0.0  ## when the day being kept began


func _init(sess_) -> void:
	sess = sess_
	_since = float(sess.time)


## The next 06:00 strictly after `t`.
static func next_close(t: float) -> float:
	var at := floorf(t / DAY_S) * DAY_S + HOUR * 3600.0
	return at if at > t else at + DAY_S


## Close the day ending `t`: one row per org that had any money move. Emits "books" with the rows.
func close(t: float) -> Array:
	var rows := []
	for o in ORGS:
		var r := day_of(o, _since, t)
		if not r.in.is_empty() or not r.out.is_empty():
			rows.append(r)
	closed.append_array(rows)
	while closed.size() > KEEP * ORGS.size():
		closed.pop_front()
	_since = t
	sess.bus.emit("books", t, "", ["runner", "law"], {"rows": rows, "day": int(t / DAY_S)})
	return rows


## One org's money in [`from`, `to`), from the ledger: rows that cross the org's accounts (its own transfers between its
## accounts are neither in nor out).
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


func capture() -> Dictionary:
	return {"closed": closed.duplicate(true), "since": _since}


func restore(d: Dictionary) -> void:
	closed = (d.get("closed", []) as Array).duplicate(true)
	_since = float(d.get("since", _since))
