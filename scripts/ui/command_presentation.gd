class_name CommandPresentation
extends RefCounted
## UI-only sequence-correlated outcomes. Acknowledgement and refreshed state are
## separate facts. Unknown results are retained and mutations are never resent.
const TIMEOUT := 15.0
var link
var records: Array = []

func _init(link_) -> void:
	link = link_

func send(name: String, args := {}) -> int:
	for record in records:
		if record.state in ["pending", "acknowledged"] and record.command == name and record.args == args:
			return record.seq
	var seq: int = link.send_command(name, args)
	records.append({"seq": seq, "command": name, "args": args.duplicate(true), "role": str(link.role),
		"state": "pending", "age": 0.0, "ok": false, "message": "Awaiting acknowledgement", "ack_snapshot": -1})
	while records.size() > 40 and records[0].state not in ["pending", "acknowledged"]:
		records.pop_front()
	poll(0.0)
	return seq

func poll(dt: float) -> void:
	var snap = link.snapshot()
	var revision: int = int(snap.get("seq", -1)) if snap is Dictionary else -1
	for record in records:
		if record.state not in ["pending", "acknowledged"]:
			continue
		record.age += maxf(0.0, dt)
		if str(link.role) != record.role:
			record.state = "unknown"
			record.message = "Seat changed; result unknown. Do not automatically repeat the order."
			continue
		if record.state == "pending" and link.acks.has(record.seq):
			var result: Array = link.acks[record.seq]
			link.acks.erase(record.seq)
			record.ok = bool(result[0])
			record.message = str(result[1])
			record.state = "acknowledged" if record.ok else "refused"
			record.ack_snapshot = revision
			if link is LocalLink and record.ok:
				record.state = "refreshed"
		elif record.state == "acknowledged" and revision > record.ack_snapshot:
			record.state = "refreshed"
		if record.state in ["pending", "acknowledged"] and (not link.alive() or record.age >= TIMEOUT):
			record.state = "unknown" if record.state == "pending" else "acknowledged_stale"
			record.message = "Result unknown; do not automatically resend." if not record.ok else "Host acknowledged; refreshed state unavailable."

func get_record(seq: int) -> Dictionary:
	for record in records:
		if record.seq == seq:
			return record.duplicate(true)
	return {}

static func text(record: Dictionary) -> String:
	var prefix: String = {"pending": "Pending", "acknowledged": "Acknowledged; waiting for state", "refreshed": "Acknowledged; state refreshed",
		"refused": "Refused", "unknown": "Result unknown", "acknowledged_stale": "Acknowledged; state unavailable"}.get(record.state, "")
	return "#%d %s — %s: %s" % [record.seq, str(record.command).replace("_", " "), prefix, record.message]
