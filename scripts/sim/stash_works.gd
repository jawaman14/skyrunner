class_name StashWorks
extends RefCounted
## What can be built at a stash house (Mount & Blade's village improvements): two works, two levels each, paid
## from the safe. The state is on the stash itself (its `works` dictionary), so the stash net, the logistics and
## the save all see it without a new system.
##
##   vault   a hidden compartment: a raid carries off 35% less of what is inside, a level (the rest is spirited
##           away to another house)
##   guard   a lookout post and a dog: the traffic warms the house 20% less, and the heat cools 25% faster, a level
##
## Off for the replays (StashWorks.ENABLED = false).

static var ENABLED := true

const MAX_LEVEL := 2
const WORKS := {
	"vault": {"name": "Hidden vault", "cost": [2500, 6000], "blurb": "a raid carries off 35% less, a level"},
	"guard": {"name": "Guard post", "cost": [2000, 5000], "blurb": "the house warms 20% less and cools 25% faster, a level"},
}


static func level(st: Dictionary, what: String) -> int:
	if not ENABLED:
		return 0
	return int(st.get("works", {}).get(what, 0))


## The share of a stash's contents that survives a raid.
static func raid_keep(st: Dictionary) -> float:
	return 0.35 * level(st, "vault")


## What arriving traffic adds to the heat, as a multiple.
static func heat_in(st: Dictionary) -> float:
	return 1.0 - 0.2 * level(st, "guard")


## How fast the heat cools, as a multiple.
static func heat_out(st: Dictionary) -> float:
	return 1.0 + 0.25 * level(st, "guard")


## The price of the next level of `what` here, or -1 at the top.
static func next_cost(st: Dictionary, what: String) -> int:
	var l := level(st, what)
	return -1 if l >= MAX_LEVEL else int(WORKS[what].cost[l])


## Build (or improve) `what` at stash `id`, paid from the safe. Returns "" or why not.
static func build(sess, id: String, what: String) -> String:
	if not ENABLED or sess.stash_net == null:
		return "Nothing can be built here."
	if not WORKS.has(what):
		return "Build a vault or a guard post."
	var st = sess.stash_net.get_stash(id)
	if st == null or st.burned:
		return "No such house (or it is burned)."
	var cost := next_cost(st, what)
	if cost < 0:
		return "The %s here is as good as it gets." % str(WORKS[what].name).to_lower()
	if sess.money < cost:
		return "Need $%s." % Py.money(cost)
	sess.money -= cost
	if not st.has("works"):
		st["works"] = {}
	st.works[what] = level(st, what) + 1
	sess.say("WORKS - %s at %s, level %d: $%s." % [WORKS[what].name, st.name, st.works[what], Py.money(cost)])
	return ""
