extends TestCase
const Main = preload("res://scripts/main.gd")

class Entry extends Main:
	func _ready() -> void:
		pass

func test_failed_direct_host_releases_server_and_keeps_local_game() -> void:
	var blocker := HostServer.new()
	check_eq(blocker.start(0), null)
	var entry := Entry.new()
	entry.save_dir = "user://startup-test-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(entry.save_dir))
	entry.args.merge({"new": true, "host": true, "port": blocker.port,
		"graphics": "low", "unlocks": "open", "map": MapCity.SEED}, true)
	var tree: SceneTree = Engine.get_main_loop()
	tree.root.add_child(entry)
	entry.start()
	var pilot: PilotApp = null
	for child in entry.get_children():
		check(not child is HostServer or child.is_queued_for_deletion(), "failed server is released")
		check(not child is VoiceChat, "failed host creates no voice service")
		if child is PilotApp: pilot = child
	check(pilot != null, "local fallback remains playable")
	var session: Session = pilot.s if pilot != null else null
	var save_dir: String = entry.save_dir
	tree.root.remove_child(entry)
	entry.free()
	if session != null: session.dispose()
	blocker.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_dir))
	World.use_map(0)
