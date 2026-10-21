extends RefCounted
## Standalone Seven Boxes simulator, no SkyRunner state mutation.
## Facts are source-labelled; gameplay records are fictional. Deterministic and no global RNG.

const VERSION := 1
const ROLES := ["archivist", "analyst", "reviewer"]
const ROUTES := ["field", "delegated"]

var case_data: Dictionary = {}
var state: Dictionary = {}
var audit: Array = []
var last_error := ""

func configure(record: Dictionary) -> bool:
	last_error = ""
	if not _validate_case(record):
		return false
	case_data = record.duplicate(true)
	var balances: Dictionary = case_data["opening_balances"].duplicate(true)
	state = {
		"case_id": str(record["id"]),
		"balances": balances,
		"metrics": case_data["starting_metrics"].duplicate(true),
		"taken": [],
		"unlocked_docs": [],
		"finished": false,
		"ending": ""
	}
	audit = []
	return true

func _validate_case(record: Dictionary) -> bool:
	if int(record.get("schema_version", -1)) != VERSION:
		return _fail("Unsupported mission schema")
	for key in ["id", "claims", "sources", "documents", "actions", "rooms", "opening_balances", "starting_metrics"]:
		if not record.has(key):
			return _fail("Missing mission field: " + key)
	if not (record["actions"] is Array and record["claims"] is Array and record["sources"] is Array):
		return _fail("Invalid mission collections")
	if not (record["opening_balances"] is Dictionary and record["starting_metrics"] is Dictionary):
		return _fail("Invalid mission balances/metrics")
	if not record["opening_balances"].has("case_fund") or not record["opening_balances"].has("outside_services"):
		return _fail("Missing ledger accounts")
	if int(record["opening_balances"]["case_fund"]) + int(record["opening_balances"]["outside_services"]) != 0:
		return _fail("Opening balances must sum to zero")
	var source_ids := []
	for source in record["sources"]:
		if not (source is Dictionary) or str(source.get("id", "")).is_empty():
			return _fail("Invalid source entry")
		source_ids.append(source["id"])
	for claim in record["claims"]:
		if not (claim.get("status", "") in ["D", "A", "P", "C", "U", "F"]):
			return _fail("Invalid historical-evidence status")
		for sid in claim.get("source_ids", []):
			if not (sid in source_ids):
				return _fail("Claim cites a non-existent source")
		if claim.get("status") != "F" and claim.get("source_ids", []).is_empty():
			return _fail("Non-fictional claim requires a source")
	var action_ids := []
	for action in record["actions"]:
		if str(action.get("id", "")).is_empty() or action["id"] in action_ids:
			return _fail("Missing or duplicate action id")
		if not action.get("room", "") in record["rooms"]:
			return _fail("Invalid action location")
		if int(action.get("cost", -1)) < 0:
			return _fail("Invalid action cost")
		action_ids.append(action["id"])
	for action in record["actions"]:
		for prerequisite in action.get("require", []):
			if not (prerequisite in action_ids):
				return _fail("Action prerequisite missing")
	return true

func action_info(action_id: String) -> Dictionary:
	for action in case_data.get("actions", []):
		if str(action.get("id", "")) == action_id:
			return action
	return {}

func available(action_id: String, route: String, room: String) -> String:
	if case_data.is_empty():
		return "Case not configured"
	if bool(state.get("finished", false)):
		return "The case has closed"
	if not (route in ROUTES):
		return "Unknown route"
	var action := action_info(action_id)
	if action.is_empty():
		return "Unknown action"
	if route == "field" and room != action["room"]:
		return "Travel to: " + str(action["room"])
	if action_id in state["taken"]:
		return "Already completed"
	for prerequisite in action.get("require", []):
		if not (prerequisite in state["taken"]):
			return "Requires: " + str(prerequisite).replace("_", " ")
	for key in action.get("thresholds", {}).keys():
		if int(state["metrics"].get(key, 0)) < int(action["thresholds"][key]):
			return "Insufficient " + str(key) + " rating"
	if int(state["balances"]["case_fund"]) < int(action["cost"]):
		return "Insufficient case budget"
	return ""

func command(actor: String, route: String, action_id: String, room: String = "") -> Dictionary:
	if not (actor in ROLES):
		return {"ok": false, "message": "Unknown actor role"}
	var reason := available(action_id, route, room)
	if not reason.is_empty():
		return {"ok": false, "message": reason}
	var action := action_info(action_id)
	var cost := int(action["cost"])
	state["balances"]["case_fund"] = int(state["balances"]["case_fund"]) - cost
	state["balances"]["outside_services"] = int(state["balances"]["outside_services"]) + cost
	for key in ["evidence", "oversight", "preservation", "privacy", "days"]:
		if action.has(key):
			state["metrics"][key] = clampi(int(state["metrics"].get(key, 0)) + int(action[key]), 0, 999 if key == "days" else 100)
	state["taken"].append(action_id)
	for doc_id in action.get("unlock", []):
		if not (doc_id in state["unlocked_docs"]):
			state["unlocked_docs"].append(doc_id)
	if action.has("ending"):
		state["finished"] = true
		state["ending"] = str(action["ending"])
	audit.append({"sequence": audit.size() + 1, "day": int(state["metrics"]["days"]), "actor": actor, "route": route, "action": action_id, "cost": cost, "ending": str(state["ending"]), "report": str(action.get("report", ""))})
	if not balances_conserved():
		push_error("BLACKFILE ledger invariant broken")
	return {"ok": true, "message": str(action.get("report", "Action completed")), "ending": str(state["ending"])}

func balances_conserved() -> bool:
	if state.is_empty():
		return false
	return int(state["balances"]["case_fund"]) + int(state["balances"]["outside_services"]) == 0 and int(state["balances"]["case_fund"]) >= 0

func world_snapshot() -> Dictionary:
	## For route equivalence: ignore only audit fields identifying the human/delegated executor.
	return state.duplicate(true)

func snapshot() -> Dictionary:
	return {"schema_version": VERSION, "case_id": str(case_data.get("id", "")), "state": state.duplicate(true), "audit": audit.duplicate(true)}

func restore(record: Dictionary, saved: Dictionary) -> bool:
	## Validate before committing; unknown versions and malformed saves cannot erase a running case.
	last_error = ""
	if int(saved.get("schema_version", -1)) != VERSION:
		return _fail("Unsupported save version; original save remains unchanged")
	if str(saved.get("case_id", "")) != str(record.get("id", "")):
		return _fail("Save belongs to another mission")
	var candidate = saved.get("state")
	var events = saved.get("audit")
	if not (candidate is Dictionary and events is Array):
		return _fail("Invalid save structure")
	for key in ["case_id", "balances", "metrics", "taken", "unlocked_docs", "finished", "ending"]:
		if not candidate.has(key):
			return _fail("Save missing " + key)
	if not (candidate["balances"] is Dictionary and candidate["metrics"] is Dictionary and candidate["taken"] is Array and candidate["unlocked_docs"] is Array):
		return _fail("Invalid save field types")
	if not candidate["balances"].has("case_fund") or not candidate["balances"].has("outside_services"):
		return _fail("Invalid ledger in save")
	if int(candidate["balances"]["case_fund"]) < 0 or int(candidate["balances"]["case_fund"]) + int(candidate["balances"]["outside_services"]) != 0:
		return _fail("Broken ledger in save")
	var check := get_script().new()
	if not check.configure(record):
		return _fail("Invalid mission document")
	for e in events:
		if not (e is Dictionary):
			return _fail("Invalid audit event")
		if int(e.get("sequence", -1)) != check.audit.size() + 1:
			return _fail("Out-of-order audit event")
		var result: Dictionary = check.command(str(e.get("actor", "")), str(e.get("route", "")), str(e.get("action", "")), str(check.action_info(str(e.get("action", ""))).get("room", "")))
		if not bool(result.get("ok", false)):
			return _fail("Save event failed replay: " + str(result.get("message", "")))
		if check.audit[-1] != e:
			return _fail("Audit event inconsistent")
	if check.state != candidate:
		return _fail("Save state does not match replayed actions")
	case_data = check.case_data.duplicate(true)
	state = check.state.duplicate(true)
	audit = check.audit.duplicate(true)
	return true

func _fail(message: String) -> bool:
	last_error = message
	return false
