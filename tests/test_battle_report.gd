extends TestCase
const Report = preload("res://scripts/ui/widgets/battle_report.gd")

func after_each() -> void:
	World.use_map(0)

func test_battle_report_save_restores_optional_history() -> void:
	var s := Session.new({"seed": 12, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "ground_war": true})
	s.ground.battle_reports = [{"faction": "org", "unit": "test-unit", "remaining_people": 3, "time": 120}]
	var data: Dictionary = SaveVars.through_json(StrategicSave._capture_war(s.ground))
	s.ground.battle_reports = []
	StrategicSave._restore_war(s.ground, data)
	check_eq(s.ground.battle_history("org")[0].unit, "test-unit", "completed accounts survive JSON save restoration")
	check_eq(s.ground.battle_history("police").size(), 0, "restoration preserves privacy")
	s.ground.battle_reports = []
	data.erase("battle_reports")
	StrategicSave._restore_war(s.ground, data)
	check_eq(s.ground.battle_reports, [], "older saves leave history empty")
	s.dispose()

func test_battle_report_formatter_explains_limits() -> void:
	check("Older peers" in Report.describe([]), "unsupported peer is explicit")
	var text := Report.describe([{"unit": "own", "place": "at dock", "starting_people": 4, "remaining_people": 2, "losses": 1, "starting_ammo": 90, "remaining_ammo": 20}])
	for value in ["People 4 to 2", "Ammo 90 to 20", "wounded", "custody", "not inferred"]:
		check(value in text, "explains " + value)
