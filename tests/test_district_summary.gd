extends TestCase
const Summary = preload("res://scripts/ui/widgets/district_summary.gd")

func test_old_peer_and_uncertain_threats_are_explicit() -> void:
	check("unavailable" in Summary.describe([]), "old peer is explicit")
	var text := Summary.describe([{"market": "town", "share": -1.0, "own_people": 4, "own_squads": 1, "upkeep_per_minute": 8.0, "observed_enemies": 0}])
	check("unestablished" in text, "no control history does not imply secure ownership")
	check("currently reported" in text, "no sightings is not no enemy presence")
	check("$8.00/min" in text, "own upkeep is readable")

func test_collection_estimate_is_not_guaranteed() -> void:
	var text := Summary.describe([{"market": "west", "share": 0.6, "trend": "rising", "policy": "squeeze", "expected_collection": 70, "last_collection": 20, "next_collection": 180}])
	for value in ["60%", "rising", "squeeze", "expected $70", "last $20", "3 min", "not guaranteed", "suspicion"]:
		check(value in text, "explains " + value)
