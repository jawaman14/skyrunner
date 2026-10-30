extends TestCase
## Loop idea 2: cover cargo. A legitimate load beside a hot one lowers the customs check at a police airport.


class _It:
	var hot: bool
	var kind: String
	var weight_lb: float
	func _init(h: bool, k: String, w: float) -> void:
		hot = h
		kind = k
		weight_lb = w


func after_each() -> void:
	CoverCargo.ENABLED = true
	World.use_map(0)


func test_cover_grows_with_honest_cargo_and_is_capped() -> void:
	check_eq(CoverCargo.factor([_It.new(false, "cargo", 300.0)]), 0.0, "nothing hot, nothing to cover")
	check_eq(CoverCargo.factor([_It.new(true, "cargo", 100.0)]), 0.0, "a bare hot load")
	check_near(CoverCargo.factor([_It.new(true, "cargo", 100.0), _It.new(false, "cargo", 100.0)]), 0.4, 1e-6, "one for one")
	check_near(CoverCargo.factor([_It.new(true, "cargo", 100.0), _It.new(false, "passenger", 170.0)]), 0.6, 1e-6, "passengers count, capped")
	check_eq(CoverCargo.factor([_It.new(true, "cargo", 100.0), _It.new(false, "tank", 400.0)]), 0.0, "a ferry tank is not cover")
	CoverCargo.ENABLED = false
	check_eq(CoverCargo.factor([_It.new(true, "cargo", 100.0), _It.new(false, "cargo", 100.0)]), 0.0, "off for the parity replays")


## The same customs rolls, with and without cover: cover can only turn an inspection into a pass, never the other way.
func test_customs_open_fewer_hot_loads_with_cover() -> void:
	var a := Session.new({"seed": 31, "location": "HAR"})
	var b := Session.new({"seed": 31, "location": "HAR"})
	var har := World.airfield("HAR")
	var bare := 0
	var covered := 0
	for i in 400:
		if a.police.landing_check(a.state, har, true, "runner", 0.0):
			bare += 1
		if b.police.landing_check(b.state, har, true, "runner", 0.6):
			covered += 1
	check(bare > 100 and bare < 180, "about 35%% opened bare (%d of 400)" % bare)
	check(covered < bare * 0.6, "cover 60%% opens far fewer (%d against %d)" % [covered, bare])
	check(b.police.events.any(func(e): return "waved the honest cargo through" in str(e)), "the pass is announced")
	a.dispose()
	b.dispose()
