extends TestCase
var _sessions: Array = []

func after_each() -> void:
	for session in _sessions: session.dispose()
	_sessions.clear()
	World.use_map(0)

func test_registry_covers_role_commands_without_retaining_session_context() -> void:
	var handlers := CommandDomains.handlers()
	check_eq(handlers.size(), 105, "preserve the existing command surface")
	for role in Roles.ALL:
		for name in Roles.PERMISSIONS[role]:
			check(handlers.has(name), "registered command for " + role + ": " + name)
	for name in handlers:
		var handler: Callable = handlers[name]
		check(handler.is_valid(), "callable for " + name)
		check_eq(handler.get_bound_arguments_count(), 0, "cached handlers do not retain a Session")

func test_shared_handlers_mutate_only_the_supplied_authoritative_session() -> void:
	var first := T.sess(4)
	var second := T.sess(4)
	_sessions.assign([first, second])
	var untouched: float = second.loadout.fuel_lb
	check_eq(first.command(Roles.PILOT, "set_fuel", {"lb": 150}), [true, "ok"])
	check_eq(first.loadout.fuel_lb, 150.0)
	check_eq(second.loadout.fuel_lb, untouched, "another session is untouched")
	check_eq(second.command(Roles.PILOT, "set_fuel", {"lb": 200}), [true, "ok"])
	check_eq(second.loadout.fuel_lb, 200.0)
	check_eq(first.loadout.fuel_lb, 150.0, "registry never reuses an earlier context")

func test_authority_checks_still_precede_domain_dispatch() -> void:
	var session := T.sess(4)
	_sessions.append(session)
	var before: float = session.loadout.fuel_lb
	check_eq(session.command(Roles.ANALYST, "set_fuel", {"lb": 150}), [false, "analyst can't do 'set_fuel'."])
	check_eq(session.loadout.fuel_lb, before)
	check_eq(session.command("janitor", "chat", {"text": "hi"}), [false, "Unknown role janitor."])
