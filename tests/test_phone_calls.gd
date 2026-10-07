extends TestCase
const PhoneCalls = preload("res://scripts/sim/phone_calls.gd")
var _session: Session
var _menu: PhoneMenu


func after_each() -> void:
	if is_instance_valid(_menu):
		_menu.free()
	if _session != null:
		_session.dispose()
	_menu = null
	_session = null
	World.use_map(0)


func _live() -> Session:
	_session = Session.new({"seed": 17, "map_seed": MapCity.SEED, "location": "HAR", "family": true, "humans": {Roles.BOSS: "Owner"}})
	_session.police.frozen = true
	return _session

func test_pending_call_is_deduplicated_and_can_be_answered() -> void:
	var q := PhoneCalls.new()
	var first := q.enqueue("buyers", "Benny Ruiz", 10.0)
	var duplicate := q.enqueue("buyers", "Benny Ruiz", 11.0)
	check_eq(duplicate.id, first.id)
	check_eq(q.pending().size(), 1)
	var result := q.answer(int(first.id))
	check(result.ok)
	check_eq(result.call.state, "answered")
	check_eq(q.pending().size(), 0)

func test_calls_expire_as_missed_and_cannot_be_replayed() -> void:
	var q := PhoneCalls.new()
	var call := q.enqueue("lawyer", "Your lawyer", 20.0, 5.0)
	q.tick(25.0)
	var result := q.answer(int(call.id))
	check(not result.ok)
	check_eq(result.reason, "call-missed")

func test_save_load_preserves_queue_and_ids() -> void:
	var q := PhoneCalls.new()
	q.enqueue("crew", "Manny Ortega", 1.0)
	var snap := q.capture()
	var restored: RefCounted = PhoneCalls.new()
	restored.restore(snap)
	check_eq(restored.pending().size(), 1)
	var next: Dictionary = restored.enqueue("dealer", "Dealership", 2.0)
	check(int(next.id) > 1)


func test_offer_creates_one_call_and_answer_does_not_accept_the_offer() -> void:
	var s := _live()
	var offer: Dictionary = s.family.offer("loan")
	check(not offer.is_empty())
	var call: Dictionary = s.phone_calls.pending()[0]
	check_eq(call.source, "family:" + str(offer.id))
	var money: int = s.money
	check(not s.command(Roles.CONTROLLER, "phone_answer", {"id": call.id})[0])
	check_eq(s.phone_calls.pending().size(), 1, "law cannot answer runner calls")
	check(not Snapshot.build(s, Roles.CONTROLLER).has("phone_calls"), "no enemy phone intelligence")
	check_eq(Snapshot.build(s, Roles.PILOT).phone_calls.size(), 1)
	check(s.command(Roles.PILOT, "phone_answer", {"id": call.id})[0])
	check(not s.command(Roles.PILOT, "phone_answer", {"id": call.id})[0], "cannot answer twice")
	check_eq(s.money, money)
	check(s.family.get_offer(str(offer.id)) != null, "answering opens a conversation, not a commitment")


func test_session_save_round_trip_retains_terminal_call_and_deduplicates_source() -> void:
	var s := _live()
	var offer: Dictionary = s.family.offer("loan")
	var call: Dictionary = s.phone_calls.pending()[0]
	check(s.command(Roles.PILOT, "phone_decline", {"id": call.id})[0])
	var saved: Dictionary = JSON.parse_string(JSON.stringify(StrategicSave.capture(s)))
	s.phone_calls.restore({})
	StrategicSave.restore(s, saved)
	var repeated := s.phone_calls.enqueue("family", "The Family", s.time, 20.0, "family:" + str(offer.id))
	check_eq(repeated.state, "declined")
	check(s.phone_calls.pending().is_empty(), "loading must not ring the declined source again")
	check(s.family.get_offer(str(offer.id)) != null, "declining a call preserves offer availability")
	var old: Dictionary = saved.duplicate(true)
	old.erase("phone_calls")
	StrategicSave.restore(s, old)
	check(s.phone_calls.history().is_empty(), "old saves have an empty queue")


func test_expired_or_removed_offer_cannot_be_answered() -> void:
	var s := _live()
	s.family.offer("loan")
	var call: Dictionary = s.phone_calls.pending()[0]
	s.time = float(call.expires)
	check(not s.command(Roles.PILOT, "phone_answer", {"id": call.id})[0])
	check_eq(s.phone_calls.history()[0].state, "missed")
	s.phone_calls.restore({})
	var offer: Dictionary = s.family.offer("loan")
	if offer.is_empty():
		offer = s.family.offers[0]
	call = s.phone_calls.enqueue("family", "The Family", s.time, 20.0, "family:" + str(offer.id))
	s.family.offers.clear()
	check(not s.command(Roles.PILOT, "phone_answer", {"id": call.id})[0])


func test_phone_input_answers_once_and_refresh_preserves_contact_identity() -> void:
	var s := _live()
	_menu = PhoneMenu.new()
	Engine.get_main_loop().root.add_child(_menu)
	_menu.setup(s)
	_menu.open()
	var ids: Array = _menu.rows.map(PhoneMenu._row_id)
	_menu.list.select(ids.find("contact:family"))
	s.family.offer("loan")
	_menu.refresh()
	check_eq(PhoneMenu._row_id(_menu.rows[_menu.list.selected_row()]), "contact:family", "incoming row does not shift selected contact")
	_menu.list.select(0)
	var answered: Array = []
	_menu.called.connect(func(action): answered.append(action))
	for frame in 3: await Engine.get_main_loop().process_frame
	_menu.list.grab_focus()
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	_menu.get_viewport().push_input(event)
	event = event.duplicate()
	event.echo = true
	_menu.get_viewport().push_input(event)
	event = event.duplicate()
	event.pressed = false
	event.echo = false
	_menu.get_viewport().push_input(event)
	check_eq(answered, ["family"], "native Enter plus held key routes the existing conversation once")
	check(s.phone_calls.pending().is_empty())
