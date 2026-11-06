class_name Actor
extends RefCounted
## Who does a thing (F-5, docs/EMPIRE_SIMULATION_SPEC.md section 6): {org, role, person}. The old `command(role, ...)` is a shim
## that builds one from the role; new code (and the rival and Moretti AIs, later) calls `Session.command_as(actor, ...)`.
## `Roles.side()` gives sides, not org ids, so the side-to-org map is explicit here.

const ORG_OF_SIDE := {"runner": "org", "law": "police"}


static func of(org: String, role: String, person := "") -> Dictionary:
	return {"org": org, "role": role, "person": person}


## The actor a seat is: its side's org, its role, and the seat as the person ("seat:pilot") until seats carry people (P0).
static func for_role(role: String) -> Dictionary:
	return of(org_of(role), role, "seat:" + role)


static func org_of(role: String) -> String:
	return str(ORG_OF_SIDE.get(Roles.side(role), ""))


## Why `actor` can't act, or "" when it can. P0 order (spec section 6): a well-formed actor, the role allowed the command,
## the role's org is the actor's org. The target-ownership and manager-budget checks join with businesses (L-1) and
## managers (L-4); in P0 the org's people have the boss's authority.
static func refusal(actor: Dictionary, command: String) -> String:
	var role := str(actor.get("role", ""))
	if not Roles.valid(role):
		return "Unknown role %s." % role
	if str(actor.get("org", "")) == "":
		return "Nobody's acting: the actor has no organisation."
	if str(actor.org) != org_of(role):
		return "%s can't act as %s." % [str(actor.org), role]
	if not Roles.allowed(role, command):
		return "%s can't do '%s'." % [role, command]
	return ""
