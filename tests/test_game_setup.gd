extends TestCase
## GameSetup (scripts/net/game_setup.gd): the one builder of a game's session options, used by the pilot app and the dedicated server. These pin the
## dictionaries the two used to build by hand, so the refactor changes nothing.

const OLD_OPEN := {"ai_law_upgrades": true, "ground_war": true, "chronicle": true, "agency": true, "family": true, "island": true, "court": true, "payroll": true,
	"trade": true, "logistics": true, "renown": true, "rackets": true, "races": true, "airframe": true, "casino": true, "dealership": true, "psychedelics": true,
	"fog": true}


func test_an_open_game_is_every_system_on_with_a_float() -> void:
	var o := GameSetup.options("solo", 7, false)
	var expect := OLD_OPEN.duplicate()
	expect["seed"] = 7
	expect["mode"] = "solo"
	expect["money"] = Session.OPEN_FLOAT
	check_eq(o, expect, "exactly the dictionary the pilot app and the dedicated server built by hand")


func test_a_story_game_leaves_the_systems_to_the_chapters() -> void:
	var o := GameSetup.options("coop", 3, true)
	check(o.has("career") and not o.has("money"), "career, no float")
	for k in Session.SYSTEMS:
		check(not o.has(k), "%s is opened by a chapter, not set here" % k)
	check(o.has("fog") and o.has("ai_law_upgrades"), "the non-system options stay")


func test_a_campaign_gets_no_float() -> void:
	var o := GameSetup.options(Roles.CAMPAIGN, 3, false)
	check(not o.has("money"), "its chapters do the setup")


func test_the_police_table_is_every_system_with_a_float() -> void:
	var p := GameSetup.police(5, -1)
	check_eq(p.mode, Roles.POLICE)
	check_eq(p.map_seed, MapCity.SEED, "no map argument: the city coast")
	check(p.has("career") and p.has("money") and p.has("fog"), "career, float and fog")
	for k in GameSetup.OPEN_SYSTEMS:
		check(p.get(k, false), k)
	check_eq(GameSetup.police(5, 9).map_seed, 9, "a map argument wins")


func test_the_map_seed_rules() -> void:
	check_eq(GameSetup.map_seed(4, false), 4, "an argument wins")
	check_eq(GameSetup.map_seed(4, true), 4, "even over a save")
	check_eq(GameSetup.map_seed(-1, false), MapCity.SEED, "a new game starts on the city coast")
	check_eq(GameSetup.map_seed(-1, true), -1, "an old save keeps its island (option left out)")
