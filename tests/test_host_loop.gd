extends TestCase
## HostLoop (scripts/net/host_loop.gd): the fixed 30 Hz step the host desk and the dedicated server share.


func test_it_runs_one_step_per_thirtieth_of_a_second_and_carries_the_rest() -> void:
	var loop := HostLoop.new()
	var seen := []
	var step := func(dt: float): seen.append(dt)
	check_eq(loop.advance(0.1, step), 3, "0.1 s is three steps")
	check_near(seen[0], HostLoop.DT, 1e-9, "each step is exactly 1/30 s")
	check_eq(loop.advance(0.01, step), 0, "a short frame runs nothing")
	check_eq(loop.advance(0.03, step), 1, "but the leftover adds up: 0.01 + 0.03 is another step")
	check_eq(seen.size(), 4)


func test_a_slow_frame_drops_time_instead_of_spiralling() -> void:
	var loop := HostLoop.new()
	var n := []  # (a lambda captures an int by value: count in an array)
	var step := func(_dt: float): n.append(1)
	check_eq(loop.advance(10.0, step), HostLoop.MAX_STEPS, "at most five steps")
	check_eq(loop.advance(0.0, step), 0, "and the backlog is gone, not paid back later")
	check_eq(n.size(), HostLoop.MAX_STEPS)


func test_the_ai_flies_when_nobody_holds_the_pilots_seat() -> void:
	var s := Session.new({"seed": 5, "map_seed": MapCity.SEED, "location": "HAR", "ground_war": false})
	check(HostLoop.ai_pilot(s, null) == null, "the local player holds the seat: no AI")
	s.seats.release(Roles.PILOT)
	var bot = HostLoop.ai_pilot(s, null)
	check(bot != null, "nobody in the seat: the AI takes it")
	check(HostLoop.ai_pilot(s, bot) == bot, "and keeps it")
	s.seats.claim(Roles.PILOT, "host", "")
	check(HostLoop.ai_pilot(s, bot) == null, "a player who takes the seat sends the AI home")
	s.dispose()
