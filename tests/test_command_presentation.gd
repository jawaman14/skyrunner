extends TestCase

class Peer extends RefCounted:
	var role := Roles.BOSS
	var acks := {}
	var connected := true
	var sent := 0
	var snap := {"seq": 1}
	func snapshot(): return snap
	func alive() -> bool: return connected
	func send_command(_name: String, _args: Dictionary) -> int:
		sent += 1
		return sent

func test_ack_is_not_a_refreshed_transaction_and_pending_duplicates_are_suppressed() -> void:
	var peer := Peer.new()
	var ui := CommandPresentation.new(peer)
	var seq := ui.send("move_cash", {"from": "a", "to": "hq"})
	check_eq(ui.send("move_cash", {"from": "a", "to": "hq"}), seq)
	check_eq(peer.sent, 1)
	peer.acks[seq] = [true, "ok"]
	ui.poll(0.1)
	check_eq(ui.get_record(seq).state, "acknowledged")
	ui.poll(0.1)
	check_eq(ui.get_record(seq).state, "acknowledged", "cached snapshot is not completion")
	peer.snap.seq = 2
	ui.poll(0.1)
	check_eq(ui.get_record(seq).state, "refreshed")
	check("Acknowledged" in CommandPresentation.text(ui.get_record(seq)))

func test_refusal_disconnect_timeout_and_seat_change_never_resend() -> void:
	for cause in ["refused", "disconnect", "timeout", "seat"]:
		var peer := Peer.new()
		var ui := CommandPresentation.new(peer)
		var seq := ui.send("rackets", {"what": "release"})
		match cause:
			"refused": peer.acks[seq] = [false, "No prisoners"]
			"disconnect": peer.connected = false
			"seat": peer.role = Roles.CHIEF
		ui.poll(16.0 if cause == "timeout" else 0.1)
		check_eq(ui.get_record(seq).state, "refused" if cause == "refused" else "unknown")
		check_eq(peer.sent, 1)
		ui.poll(20.0)
		check_eq(peer.sent, 1, "no automatic mutation retry")

func test_local_command_outcome_retains_authoritative_refusal() -> void:
	var s := Session.new({"seed": 31, "map_seed": MapCity.SEED})
	var link := LocalLink.new(s, Roles.PILOT, false)
	var ui := CommandPresentation.new(link)
	var seq := ui.send("buy_vehicle", {"id": "missing"})
	check_eq(ui.get_record(seq).state, "refused")
	check(not ui.get_record(seq).message.is_empty())
	s.dispose()
	World.use_map(0)


func test_feed_filters_audience_deduplicates_and_never_exports_private_data() -> void:
	var s := Session.new({"seed": 31, "map_seed": MapCity.SEED})
	s.bus.emit("busted", s.time, "Only the law knows", ["law"], {"secret_position": [123, 456]})
	s.bus.emit("note", s.time, "Runner report", ["runner"], {"hidden": "enemy cash"})
	s.bus.emit("note", s.time, "Runner report", ["runner"])
	var feed := Snapshot.event_feed(s, "runner")
	check_eq(feed.size(), 1)
	check_eq(feed[0].text, "Runner report")
	check(not "secret_position" in JSON.stringify(feed) and not "enemy cash" in JSON.stringify(feed))
	s.time = 70.0
	check(Snapshot.event_feed(s, "runner").is_empty(), "ordinary reports expire")
	var law := Snapshot.event_feed(s, "law")
	check_eq(law.size(), 1, "critical reports persist longer")
	check_eq(law[0].severity, "critical")
	s.dispose()
	World.use_map(0)
