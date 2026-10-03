class_name HostDesk
extends Node
## A host who took a desk (not the pilot's seat) in the waiting room: the game is run here, with the 2D station for that seat
## on screen, the host's own session loop (no PilotApp, so no 3D world to draw), and the aircraft flown by the AI until a guest
## takes the pilot's seat (the same hand-over PilotApp makes). It serves the guests exactly as a hosting PilotApp does.

var sess: Session
var server: HostServer
var station: StationApp
var bot: AutoRunner = null
var role := ""


func setup(sess_: Session, server_: HostServer, role_: String) -> HostDesk:
	sess = sess_
	server = server_
	role = role_
	name = "HostDesk"
	server.attach(sess)
	station = StationApp.new()
	add_child(station)
	station.setup(LocalLink.new(sess, role, false), role, sess.world)  # (ticks false: the loop below runs the session)
	return self


func _process(dt: float) -> void:
	server.pump(sess)
	_pilot_seat()
	var remote: bool = sess.seats.human(Roles.PILOT) and sess.seats.seats[Roles.PILOT].token != ""
	var bc = bot.step(dt) if bot != null else (sess.remote_controls() if remote else null)
	sess.update(minf(dt, 0.1), null, bc)
	server.publish(sess)


## The AI flies whenever nobody holds the pilot's seat; a guest who takes it flies from their own machine.
func _pilot_seat() -> void:
	var who := sess.seats.who(Roles.PILOT)
	if who == "ai" and bot == null:
		bot = AutoRunner.new(sess)
	elif who != "ai" and bot != null:
		bot = null
