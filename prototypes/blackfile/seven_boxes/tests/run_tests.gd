extends SceneTree
## Run: godot --headless --path prototypes/blackfile/seven_boxes --script res://tests/run_tests.gd

const Engine = preload("res://case_engine.gd")
const CASE := "res://data/seven_boxes.json"
var failures := 0

func _initialize() -> void:
	var source = JSON.parse_string(FileAccess.get_file_as_string(CASE))
	assert_true(source is Dictionary, "case JSON parses")
	if not (source is Dictionary):
		quit(1)
		return
	var e = Engine.new()
	assert_true(e.configure(source), "case schema validates")
	assert_true(e.balances_conserved(), "initial double-entry balances conserved")
	assert_true(not e.command("analyst", "field", "qualified_brief", "Oversight Room")["ok"], "ungrounded brief denied")
	assert_true(e.audit.is_empty(), "denial produces no transaction or event")
	assert_true(not e.command("analyst", "field", "reconcile_vouchers", "Finance Desk")["ok"], "dependencies enforced")
	assert_true(not e.command("bogus", "field", "inspect_inventory", "Archive Annex")["ok"], "roles checked")
	assert_true(not e.command("analyst", "field", "inspect_inventory", "Finance Desk")["ok"], "field location checked")
	assert_true(e.command("analyst", "field", "inspect_inventory", "Archive Annex")["ok"], "inventory accepted")
	assert_true(not e.command("analyst", "field", "inspect_inventory", "Archive Annex")["ok"], "duplicate inventory denied")
	assert_true(e.command("analyst", "field", "reconcile_vouchers", "Finance Desk")["ok"], "voucher comparison accepted")
	assert_true(e.command("analyst", "field", "protect_redactions", "Archive Annex")["ok"], "privacy review accepted")
	assert_true(e.command("analyst", "field", "request_oversight", "Oversight Room")["ok"], "oversight accepted")
	assert_true(e.command("analyst", "field", "qualified_brief", "Oversight Room")["ok"], "qualified briefing submitted")
	assert_true(e.state["ending"] == "qualified_brief_submitted", "brief ending")
	assert_true(e.balances_conserved(), "ledger conserved after ending")
	assert_true(not e.command("analyst", "field", "interview_archivist", "Loading Bay")["ok"], "no action after ending")
	var snapshot: Dictionary = e.snapshot()
	var restored = Engine.new()
	assert_true(restored.restore(source, snapshot), "saved action log replays")
	assert_true(restored.state == e.state, "saved game round-trip equals original")
	var fake = snapshot.duplicate(true)
	fake["schema_version"] = 99
	assert_true(not restored.restore(source, fake), "unknown save version rejected")
	assert_true(restored.state == e.state, "failed load preserves active case")
	var forged = snapshot.duplicate(true)
	forged["state"]["balances"]["case_fund"] = 99999
	assert_true(not restored.restore(source, forged), "modified money without a matching event rejected")

	var field = Engine.new()
	var delegated = Engine.new()
	field.configure(source)
	delegated.configure(source)
	for action in ["inspect_inventory", "reconcile_vouchers", "protect_redactions", "request_oversight", "qualified_brief"]:
		var loc: String = field.action_info(action)["room"]
		assert_true(field.command("analyst", "field", action, loc)["ok"], "field route: " + action)
		assert_true(delegated.command("analyst", "delegated", action)["ok"], "delegated route: " + action)
		assert_true(field.world_snapshot() == delegated.world_snapshot(), "field/delegate economy parity: " + action)

	for pair in [["preserve_archive", ["inspect_inventory", "protect_redactions"]], ["withdraw_claim", ["inspect_inventory", "reconcile_vouchers"]], ["defer_finding", []]]:
		var alt = Engine.new()
		alt.configure(source)
		for action in pair[1]:
			assert_true(alt.command("analyst", "delegated", action)["ok"], "alternate setup " + action)
		assert_true(alt.command("analyst", "delegated", pair[0])["ok"], "alternate ending: " + pair[0])
		assert_true(alt.balances_conserved(), "alternate ledger invariant")

	var unfounded = source.duplicate(true)
	unfounded["claims"][0]["source_ids"] = ["fake-source"]
	var invalid = Engine.new()
	assert_true(not invalid.configure(unfounded), "untraceable citation rejected")
	unfounded = source.duplicate(true)
	unfounded["claims"][3]["status"] = "D"
	unfounded["claims"][3]["source_ids"] = []
	assert_true(not invalid.configure(unfounded), "unsupported historical claim rejected")

	if failures == 0:
		print("BLACKFILE Seven Boxes: ALL TESTS PASSED")
	else:
		push_error("BLACKFILE Seven Boxes: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func assert_true(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + description)
	else:
		print("PASS: " + description)
