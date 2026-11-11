class_name Grades
extends RefCounted
## Stock grades and age at the till (docs/DESIGN.md section 51.3, ROADMAP "Stock, ownership and the money loop" slice 2's first
## call sites). A lot's grade (0 to 1, the inventory's `quality`) is set where it enters the map, and the street pays for what
## the dealers actually sold: the street price times (0.5 + grade), halved every half-life the lot has aged (grass dries; the
## other goods keep). Grade 0.5 and a fresh lot pay the street price as before.
##
## Where a grade comes from (drafts for the owner's G1):
## - our own loads: each strip grows or cuts its own, a fixed grade per strip (OWN), so a good strip is worth the detour; the home
##   farm's grass is par, so the early game pays as before; a strip not in the table is par;
## - the island's cocaine (ISLAND); anything else that arrives from outside (the Collective's sheets, a buyer's leftovers, a cheat)
##   and anything the old code put in a stash without naming it: 0.5.
##
## No random draws: no stream. The grades live on the inventory's lots, which the save already carries. Behind ENABLED (in the
## parity set): off, every lot is 0.5 and sales pay the street price.

static var ENABLED := true
static var BULK := true  ## the bulk buyers pay for the grade and age of what the truck brought, as the street does (DESIGN 81)

const BASE := 0.5
## the strips our own loads come from (Trade.OWN's bush and shady kinds, both maps), by code
const OWN := {"FRM": 0.5, "PNR": 0.6, "EGL": 0.45, "COV": 0.6, "QRY": 0.4, "MGR": 0.55}
const ISLAND := 0.6  ## the island's product is cut less than the street's
const SOURCES := {"island": ISLAND, "agency": 0.65}  ## the Company's cocaine (a pickup, DESIGN 75) is the purest on the coast
const HALF_LIFE_S := {"marijuana": 10.0 * 86400.0}  ## grass dries; cocaine and acid keep (acid's degrading is a later slice)


## The grade of our own load from strip `code`: fixed per strip, so a player can learn where the good grass grows.
static func own(code: String) -> float:
	if not ENABLED:
		return BASE
	return float(OWN.get(code, BASE))


## The grade of a lot arriving from outside:<source>.
static func source(src: String) -> float:
	return float(SOURCES.get(src, BASE)) if ENABLED else BASE


## What a lot fetches against the street price: (0.5 + grade), times what's left after its age.
static func lot_mult(good: String, quality: float, age_s: float) -> float:
	if not ENABLED:
		return 1.0
	return StockValue.value(1.0, 1.0, quality, age_s, float(HALF_LIFE_S.get(good, 0.0)))


## The pound-weighted multiplier of the lots an Inventory.transfer just moved (`moved`: [{lb, quality, born}]), over `lb` pounds in
## all: pounds the inventory had no lot for count at 1.0.
static func mult(good: String, moved: Array, lb: float, now: float) -> float:
	if not ENABLED or lb <= 0.0001:
		return 1.0
	var w := 0.0
	var got := 0.0
	for m in moved:
		w += float(m.lb) * lot_mult(good, float(m.quality), maxf(0.0, now - float(m.born)))
		got += float(m.lb)
	return (w + maxf(0.0, lb - got)) / maxf(lb, got)
