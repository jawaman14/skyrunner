extends TestCase
## LocalLink and NetClient keep the one contract the desks rely on (StationLink), and the seat descriptions
## that the room, the seat picker and the menu show come from a single table (Roles.ABOUT).


func test_both_links_keep_the_contract() -> void:
	var sess := Session.new({"seed": 3, "features": Session.SANDBOX_FEATURES})
	var local := LocalLink.new(sess, Roles.PILOT)
	check_eq(StationLink.missing(local), [], "LocalLink lacks nothing")
	var net := NetClient.new()
	check_eq(StationLink.missing(net), [], "NetClient lacks nothing")
	net.free()
	sess.dispose()


func test_the_check_itself_notices_a_missing_piece() -> void:
	var plain := RefCounted.new()
	var gaps := StationLink.missing(plain)
	check(gaps.has("send_command()") and gaps.has("snapshot()") and gaps.has("role"), "a bare object lacks the methods and properties: %s" % [gaps])


func test_every_seat_has_one_description() -> void:
	for r in Roles.ALL:
		check(Roles.ABOUT.has(r) and str(Roles.ABOUT[r]) != "", "%s has a description" % r)
	var room := Room.new(Roles.COOP, "Host", Roles.PILOT)
	for s in room.seats():
		check_eq(s.about, Roles.ABOUT[s.role], "the room shows the shared text for %s" % s.role)
