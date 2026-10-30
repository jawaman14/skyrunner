class_name CoverCargo
extends RefCounted
## Loop idea 2 (docs/LOOP_IDEAS.md): a legitimate load packed beside a hot one. Customs at a police airport work through the
## manifest, not every crate, so the more honest cargo and passengers there are against the contraband, the less likely the hot
## load is the one they open. It costs payload and balance, which is the point: a real use of the load planner.
##
## It changes no random draw: the customs roll is the same one, only its threshold moves. Off for the Python replays
## (Switches.PARITY), whose landings never had it.

static var ENABLED := true

const MAX_COVER := 0.6  ## the most cover can take off the customs chance (60%)
const PER_RATIO := 0.4  ## cover for each pound of legitimate load per pound of hot: 1.5 lb honest for every 1 lb hot is the most


## 0..MAX_COVER: how much of the customs chance the legitimate load takes away. `items`: Loadout.Item (or anything with
## hot, kind and weight_lb). Ferry tanks and the aircraft's own kit are not cover.
static func factor(items: Array) -> float:
	if not ENABLED:
		return 0.0
	var hot := 0.0
	var legit := 0.0
	for i in items:
		if i.hot:
			hot += float(i.weight_lb)
		elif str(i.kind) in ["cargo", "passenger"]:
			legit += float(i.weight_lb)
	if hot <= 0.0:
		return 0.0
	return clampf(legit / hot * PER_RATIO, 0.0, MAX_COVER)
