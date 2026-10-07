class_name ActionReview
extends CanvasLayer
## Capability-advertised read-only previews. Only explicit approval emits a command.
signal finished(approved: bool, message: String)
signal status_changed(message: String)
const TIMEOUT := 10.0
const COMMANDS := ActionDescriptions.SUPPORTED + ["accept_job", "drop_job"]
var link
var command := ""
var args := {}
var role := ""
var box: ConfirmBox
var state := "loading"
var action := {}
var sequence := 0
var age := 0.0
var supported := false

func setup(link_, name: String, arguments: Dictionary) -> ActionReview:
	link = link_
	command = name
	args = arguments.duplicate(true)
	role = str(link.role)
	return self

func _ready() -> void:
	layer = 90
	box = ConfirmBox.new().setup("", "Confirm", "Cancel")
	add_child(box)
	box.answered.connect(_answered)
	for property in link.get_property_list():
		if property.name == "capabilities":
			supported = link.has_method("request_preview") and link.capabilities.has("action_previews")
	if supported:
		_request(false)
	else:
		state = "unavailable"
		_show("Preview unavailable on this host.\n\n" + command.replace("_", " ").capitalize() + "\n\nThe host will still validate permissions and current state. Confirm sends this action once.", true)

func _show(message: String, enabled: bool) -> void:
	box.msg.text = message
	box.yes_btn.disabled = not enabled
	if not box.visible:
		box.ask()
	else:
		box._select(false)
		box._armed_frame = Engine.get_process_frames() + 1
	status_changed.emit(message)

func _request(rechecking: bool) -> void:
	state = "rechecking" if rechecking else "loading"
	age = 0.0
	sequence = int(link.request_preview(command, args))
	_show("Rechecking current consequences…" if rechecking else "Requesting current consequences…", false)
	poll(0.0)

func _answered(approved: bool) -> void:
	if approved and (str(link.role) != role or not link.alive()):
		_done(false, "Seat changed or disconnected. No command was sent.")
		return
	if not approved:
		_done(false, "Cancelled. No command was sent.")
	elif state == "unavailable":
		_done(true, "Preview unavailable; sending the confirmed action.")
	elif state == "ready":
		_request(true)

func poll(dt: float) -> void:
	if state == "closed": return
	if str(link.role) != role:
		_done(false, "Seat changed. Review cancelled; no command was sent.")
		return
	if not link.alive():
		_done(false, "Disconnected. No command was sent.")
		return
	if state not in ["loading", "rechecking"]: return
	age += maxf(0.0, dt)
	if link.previews.has(sequence):
		var fresh: Dictionary = link.previews[sequence].duplicate(true)
		link.previews.erase(sequence)
		sequence = 0
		if not bool(fresh.get("enabled", false)):
			state = "rejected"
			_show(str(fresh.get("disabled_reason", "Preview unavailable.")), false)
		elif state == "rechecking" and fresh.get("label") == action.get("label") and fresh.get("preview") == action.get("preview") and fresh.get("args") == action.get("args"):
			_done(true, "Consequences rechecked; sending the confirmed action.")
		else:
			var changed := state == "rechecking"
			action = fresh
			state = "ready"
			_show(("State changed. Review again before confirming.\n\n" if changed else "") + str(action.get("label", command)) + "\n\n" + str(action.get("preview", "")), true)
	elif age >= TIMEOUT:
		_done(false, "Preview unanswered. No command was sent.")

func _done(approved: bool, message: String) -> void:
	if state == "closed": return
	state = "closed"
	if box != null and box.visible:
		box._answer(false)
	finished.emit(approved, message)
	queue_free()

func _process(dt: float) -> void:
	poll(dt)

func _exit_tree() -> void:
	state = "closed"
	if sequence > 0 and link.has_method("cancel_preview"):
		link.cancel_preview(sequence)
