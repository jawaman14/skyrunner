class_name StationLink
extends RefCounted
## The contract every link to a Session keeps. A desk, a 3D seat and the host's own desk are handed either a
## LocalLink (the session is in this process) or a NetClient (it is on a host across the network) and must
## not care which. GDScript has no interfaces and the two cannot share a base (one is a RefCounted, the other a
## Node that polls its socket), so the contract is written down here and tests/test_station_link.gd checks
## that both keep it.

## Methods both links have, as the desks call them.
const METHODS := ["send_command", "send_input", "snapshot", "tick", "alive", "close"]

## Properties both links have: the seat this link plays, the last error (null when fine) and the commands it has
## sent that are waiting on, or have had, an answer.
const PROPERTIES := ["role", "error", "acks"]


## What `link` lacks of the contract (an empty list: it keeps it).
static func missing(link: Object) -> Array:
	var out := []
	for m in METHODS:
		if not link.has_method(m):
			out.append(m + "()")
	var props := []
	for p in link.get_property_list():
		props.append(p.name)
	for p in PROPERTIES:
		if not props.has(p):
			out.append(p)
	return out


## Optional read-only preview extension. New links expose request_preview(name,
## args) -> sequence and previews[sequence] -> action descriptor. Hosts advertise
## action_previews in welcome.capabilities; older peers retain command operation.
