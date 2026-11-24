class_name Wardrobe
extends RefCounted
## What the people wear (owner, 24 November 2026, D-108; docs/DESIGN.md section 103): a 1980s Miami-crime look by faction, the
## owner's reference being Vice City-style NPCs, in our own palettes until the owner's faction style guide arrives.
##
## The characters are the kit's animated bodies; their clothes are painted on a shared 1024 px skin sheet (head, a torso cross,
## sleeve and leg strips with the hands and shoes at their ends). A look keeps the kit's head (face, hair, skin) and repaints the
## body: shirt or T-shirt, an optional jacket with lapels, sleeves long, short or pushed up, a print (tropical, pinstripe, stripes),
## a tie, a gold chain, a badge, trousers or shorts, shoes. Painted once per look and cached; every animation still plays.
## Drawn only: no switch on the sim, no draws (a man's outfit is picked by his variant, as his look always was).

static var ENABLED := true

const PX := 1024.0  ## the sheet the regions below are measured on
## The torso cross: the top face, the band round the body (left side, front, right side, back), the bottom face.
const TORSO_TOP := Rect2i(96, 688, 128, 96)
const TORSO_BAND := Rect2i(0, 784, 448, 144)
const TORSO_FRONT := Rect2i(96, 784, 128, 144)
const TORSO_BOTTOM := Rect2i(96, 928, 128, 96)
## Sleeves and legs: x of the left and right strips; the strip is 256 px wide.
const LIMB_X := [480, 768]
const ARM_CAP := 534  ## the shoulder cap and the hand cap (64 px each), then the sleeve from ARM_TOP
const ARM_TOP := 598
const ARM_END := 768
const LEG_CAP := 800
const LEG_TOP := 864
const LEG_END := 1024
const SLEEVE := {"long": 704, "cuffed": 704, "short": 650, "pushed": 690, "vest": 606}
const SHOE := 984

## Colours.
const C := {
	"white": Color(0.95, 0.94, 0.90), "cream": Color(0.92, 0.88, 0.76), "pink": Color(0.97, 0.66, 0.72),
	"salmon": Color(0.96, 0.58, 0.50), "mint": Color(0.62, 0.90, 0.78), "aqua": Color(0.36, 0.80, 0.82),
	"teal": Color(0.10, 0.55, 0.58), "powder": Color(0.62, 0.78, 0.95), "lilac": Color(0.76, 0.66, 0.92),
	"lemon": Color(0.98, 0.90, 0.50), "peach": Color(0.98, 0.76, 0.58), "sky": Color(0.55, 0.75, 0.92),
	"red": Color(0.80, 0.14, 0.16), "scarlet": Color(0.92, 0.22, 0.18), "black": Color(0.08, 0.08, 0.09),
	"charcoal": Color(0.20, 0.20, 0.23), "navy": Color(0.11, 0.15, 0.30), "denim": Color(0.22, 0.32, 0.52),
	"khaki": Color(0.72, 0.64, 0.46), "tan": Color(0.66, 0.50, 0.34), "olive": Color(0.36, 0.40, 0.22),
	"green": Color(0.16, 0.52, 0.30), "yellow": Color(0.98, 0.78, 0.12), "orange": Color(0.96, 0.52, 0.14),
	"gold": Color(0.92, 0.74, 0.24), "grey": Color(0.55, 0.56, 0.58), "brown": Color(0.36, 0.22, 0.14),
	"leaf": Color(0.10, 0.44, 0.24), "silver": Color(0.80, 0.82, 0.84),
}

## The looks by faction. Keys: shirt; print (none, tropical, stripes, pinstripe) and its colours; jacket (or none) and its print;
## sleeves; tie; chain; badge; trousers; shorts; shoes.
const LOOKS := {
	# Our crew: pastel linen suits over T-shirts, sleeves pushed up, white loafers.
	"org": [
		{"shirt": "aqua", "jacket": "white", "sleeves": "pushed", "trousers": "white", "shoes": "white"},
		{"shirt": "white", "jacket": "pink", "sleeves": "pushed", "trousers": "cream", "shoes": "white"},
		{"shirt": "lilac", "jacket": "mint", "sleeves": "pushed", "trousers": "white", "shoes": "cream"},
		{"shirt": "lemon", "jacket": "powder", "sleeves": "pushed", "trousers": "powder", "shoes": "white", "chain": true},
		{"shirt": "pink", "print": "tropical", "prints": ["white", "aqua"], "sleeves": "short", "trousers": "white", "shoes": "white"},
	],
	# Los Cuervos: loud tropical shirts open at the neck, gold chains, dark jeans and boots.
	"rival": [
		{"shirt": "red", "print": "tropical", "prints": ["yellow", "black"], "sleeves": "short", "chain": true, "trousers": "black", "shoes": "brown"},
		{"shirt": "black", "print": "tropical", "prints": ["scarlet", "gold"], "sleeves": "short", "chain": true, "trousers": "denim", "shoes": "black"},
		{"shirt": "yellow", "print": "tropical", "prints": ["green", "red"], "sleeves": "short", "trousers": "khaki", "shoes": "brown"},
		{"shirt": "white", "sleeves": "vest", "chain": true, "trousers": "denim", "shoes": "white"},
	],
	# The Morettis: dark pinstripe suits, white or black shirts, a tie, polished shoes.
	"family": [
		{"shirt": "white", "jacket": "charcoal", "jacket_print": "pinstripe", "sleeves": "cuffed", "tie": "scarlet", "trousers": "charcoal", "shoes": "black"},
		{"shirt": "black", "jacket": "navy", "jacket_print": "pinstripe", "sleeves": "cuffed", "tie": "silver", "trousers": "navy", "shoes": "black"},
	],
	# The task force: light-blue short-sleeved uniform shirts, navy trousers, the badge; a detective in a tan sport coat.
	"police": [
		{"shirt": "sky", "sleeves": "short", "badge": true, "tie": "navy", "trousers": "navy", "shoes": "black", "belt": true},
		{"shirt": "powder", "jacket": "tan", "sleeves": "long", "tie": "teal", "trousers": "brown", "shoes": "brown", "badge": true},
	],
	"swat": [
		{"shirt": "navy", "jacket": "charcoal", "sleeves": "long", "trousers": "navy", "shoes": "black", "badge": true, "belt": true},
	],
	# Everyone else on the coast: beach shirts, tank tops, shorts.
	"civilian": [
		{"shirt": "peach", "print": "tropical", "prints": ["teal", "white"], "sleeves": "short", "trousers": "khaki", "shorts": true, "shoes": "white"},
		{"shirt": "white", "print": "stripes", "prints": ["aqua"], "sleeves": "vest", "trousers": "denim", "shorts": true, "shoes": "white"},
		{"shirt": "lemon", "sleeves": "short", "trousers": "white", "shoes": "tan"},
	],
}

static var _skins := {}  ## "letter|faction|i" -> ImageTexture


## The look for a faction's man by his variant.
static func look(faction: String, variant: int) -> Dictionary:
	var set_: Array = LOOKS.get(faction, LOOKS.civilian)
	return set_[posmod(variant, set_.size())]


## The painted skin for the kit's letter in `faction`'s look `variant` (cached). null if the base sheet won't load.
static func skin(letter: String, faction: String, variant: int) -> Texture2D:
	var set_: Array = LOOKS.get(faction, LOOKS.civilian)
	var key := "%s|%s|%d" % [letter, faction, posmod(variant, set_.size())]
	if _skins.has(key):
		return _skins[key]
	var base: Texture2D = load("res://assets/models/kenney/characters/Textures/texture-%s.png" % letter)
	if base == null:
		return null
	var img := base.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	paint(img, look(faction, variant))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_skins[key] = tex
	return tex


static func _c(name) -> Color:
	return C.get(str(name), C.white) if not (name is Color) else name


## Repaint the body of a kit skin `img` in look `o`; the head (face, hair, skin) is kept.
static func paint(img: Image, o: Dictionary) -> void:
	var s := float(img.get_width()) / PX
	var R := func(r: Rect2i) -> Rect2i: return Rect2i(int(r.position.x * s), int(r.position.y * s), maxi(1, int(r.size.x * s)), maxi(1, int(r.size.y * s)))
	var skin_c := img.get_pixel(int(190 * s), int(340 * s))  # the neck, under the face
	var shirt := _c(o.get("shirt", "white"))
	var jacket = o.get("jacket")
	var outer := _c(jacket) if jacket != null else shirt
	var trousers := _c(o.get("trousers", "denim"))
	var shoes := _c(o.get("shoes", "black"))
	# The torso: the outer layer all round, then the front: an open jacket shows the shirt between the lapels.
	for r in [TORSO_TOP, TORSO_BAND, TORSO_BOTTOM]:
		img.fill_rect(R.call(r), outer)
	if jacket != null and str(o.get("jacket_print", "")) == "pinstripe":
		_stripes(img, R.call(TORSO_BAND), outer.lightened(0.28), 10, 1)
	var f: Rect2i = R.call(TORSO_FRONT)
	var mid := Rect2i(f.position.x + int(f.size.x * 0.3), f.position.y, int(f.size.x * 0.4), f.size.y)
	if jacket != null:
		img.fill_rect(mid, shirt)
		for side in [0, 1]:  # the lapels, a darker fold either side of the opening
			var lx := mid.position.x - int(6 * s) if side == 0 else mid.end.x
			img.fill_rect(Rect2i(lx, f.position.y, int(6 * s), int(f.size.y * 0.55)), outer.darkened(0.25))
	_print(img, R.call(TORSO_BAND) if jacket == null else mid, o)
	if jacket == null and str(o.get("sleeves", "")) != "vest" and o.has("print"):
		# an open collar: a V of skin at the neck
		for i in 5:
			var w := int((24 - i * 5) * s)
			img.fill_rect(Rect2i(f.get_center().x - w / 2, f.position.y + int(i * 6 * s), maxi(1, w), int(6 * s)), skin_c)
	if o.has("tie"):
		var tc := _c(o.tie)
		img.fill_rect(Rect2i(f.get_center().x - int(5 * s), f.position.y + int(4 * s), int(10 * s), int(f.size.y * 0.7)), tc)
		img.fill_rect(Rect2i(f.get_center().x - int(7 * s), f.position.y + int(2 * s), int(14 * s), int(10 * s)), tc.darkened(0.2))
	if bool(o.get("chain", false)):
		for i in 7:
			img.fill_rect(Rect2i(f.get_center().x - int((18 - i * 2) * s), f.position.y + int((10 + i * 4) * s), int(8 * s), int(3 * s)), C.gold)
	if bool(o.get("badge", false)):
		img.fill_rect(Rect2i(f.position.x + int(f.size.x * 0.72), f.position.y + int(30 * s), int(14 * s), int(16 * s)), C.gold)
	if bool(o.get("belt", false)) or jacket == null:
		var band: Rect2i = R.call(TORSO_BAND)
		img.fill_rect(Rect2i(band.position.x, band.end.y - int(14 * s), band.size.x, int(10 * s)), C.black if bool(o.get("belt", false)) else trousers)
	# The sleeves: the outer layer to its end, a cuff for a shirt under a jacket, then the skin of the forearm and hand.
	var sleeve_end: int = SLEEVE.get(str(o.get("sleeves", "long")), 704)
	for x0 in LIMB_X:
		img.fill_rect(R.call(Rect2i(x0, ARM_CAP, 64, 64)), outer)  # the shoulder cap
		img.fill_rect(R.call(Rect2i(x0 + 64, ARM_CAP, 64, 64)), skin_c)  # the hand's end
		img.fill_rect(R.call(Rect2i(x0, ARM_TOP, 256, sleeve_end - ARM_TOP)), outer)
		if jacket == null:
			_print(img, R.call(Rect2i(x0, ARM_TOP, 256, sleeve_end - ARM_TOP)), o)
		var bare := sleeve_end
		if str(o.get("sleeves", "")) == "cuffed":
			img.fill_rect(R.call(Rect2i(x0, sleeve_end, 256, 18)), shirt)
			bare = sleeve_end + 18
		elif str(o.get("sleeves", "")) == "pushed":
			img.fill_rect(R.call(Rect2i(x0, sleeve_end - 10, 256, 10)), outer.darkened(0.18))  # the rolled fold
		img.fill_rect(R.call(Rect2i(x0, bare, 256, ARM_END - bare)), skin_c)
		# The legs: trousers (or shorts and bare knees), then the shoe.
		img.fill_rect(R.call(Rect2i(x0, LEG_CAP, 64, 64)), trousers)
		img.fill_rect(R.call(Rect2i(x0 + 64, LEG_CAP, 64, 64)), shoes.darkened(0.3))
		var leg_end := 920 if bool(o.get("shorts", false)) else SHOE
		img.fill_rect(R.call(Rect2i(x0, LEG_TOP, 256, leg_end - LEG_TOP)), trousers)
		if jacket != null and str(o.get("jacket_print", "")) == "pinstripe":
			_stripes(img, R.call(Rect2i(x0, LEG_TOP, 256, leg_end - LEG_TOP)), trousers.lightened(0.28), 10, 1)
		if leg_end < SHOE:
			img.fill_rect(R.call(Rect2i(x0, leg_end, 256, SHOE - leg_end)), skin_c)
		img.fill_rect(R.call(Rect2i(x0, SHOE, 256, LEG_END - SHOE)), shoes)
		img.fill_rect(R.call(Rect2i(x0, LEG_END - 6, 256, 6)), shoes.darkened(0.35))
		# The dark gutters either side of a strip bleed into it once the sheet is mipmapped: give them the strip's own colours.
		for gx in [x0 - 32, x0 + 256]:
			if gx < 0 or gx + 32 > int(PX):
				continue
			img.fill_rect(R.call(Rect2i(gx, ARM_TOP, 32, sleeve_end - ARM_TOP)), outer)
			img.fill_rect(R.call(Rect2i(gx, sleeve_end, 32, ARM_END - sleeve_end)), skin_c)
			img.fill_rect(R.call(Rect2i(gx, LEG_TOP, 32, SHOE - LEG_TOP)), trousers)
			img.fill_rect(R.call(Rect2i(gx, SHOE, 32, LEG_END - SHOE)), shoes)


## The look's print over `r`: tropical leaves and flowers, or stripes.
static func _print(img: Image, r: Rect2i, o: Dictionary) -> void:
	var p := str(o.get("print", "none"))
	var cols: Array = o.get("prints", ["white"])
	if p == "stripes":
		_stripes(img, r, _c(cols[0]), 16, 6)
	elif p == "tropical":
		var s := float(img.get_width()) / PX
		# A fixed scatter (no random draws): leaves as clusters of blocks, flowers as a dot and four petals.
		var step := int(36 * s)
		var i := 0
		for y in range(r.position.y, r.end.y - int(8 * s), step):
			for x in range(r.position.x + ((i % 2) * step / 2), r.end.x - int(8 * s), step):
				var c := _c(cols[(i + x / maxi(1, step)) % cols.size()])
				var k := int(4 * s)
				if (i + x / maxi(1, step)) % 3 == 0:
					img.fill_rect(Rect2i(x + k, y, k * 2, k * 2), c)
					img.fill_rect(Rect2i(x, y + k, k * 2, k * 2), c)
					img.fill_rect(Rect2i(x + k * 2, y + k, k * 2, k * 2), c)
					img.fill_rect(Rect2i(x + k, y + k * 2, k * 2, k * 2), c)
					img.fill_rect(Rect2i(x + k + k / 2, y + k + k / 2, k, k), C.yellow)
				else:
					img.fill_rect(Rect2i(x, y + k * 2, k * 4, k), c)
					img.fill_rect(Rect2i(x + k, y + k, k * 3, k), c)
					img.fill_rect(Rect2i(x + k * 2, y, k * 2, k), c)
			i += 1


static func _stripes(img: Image, r: Rect2i, c: Color, every: int, width: int) -> void:
	var s := float(img.get_width()) / PX
	var e := maxi(2, int(every * s))
	for x in range(r.position.x, r.end.x, e):
		img.fill_rect(Rect2i(x, r.position.y, maxi(1, int(width * s)), r.size.y), c)
