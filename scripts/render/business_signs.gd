class_name BusinessSigns
extends Node3D
## The Living District's twelve businesses in the 3D world (DESIGN 98; ROADMAP "Empire pivot", L-1's "placing the businesses in
## the 3D world"). Each gets a post at its site with its name and who owns it, in that org's colour, read from the sim every refresh:
## a business bought or lost changes its sign. Close up only (SHOW_M), so the street isn't a wall of labels from the air.
## Drawn only; it reads Businesses and changes nothing.

const SHOW_M := 140.0
const POST_H := 4.5
const COLOURS := {"org": Color(0.45, 0.95, 0.55), "rival": Color(0.95, 0.35, 0.3), "moretti": Color(0.95, 0.8, 0.35),
	"": Color(0.8, 0.85, 0.9), "outside": Color(0.6, 0.6, 0.62)}

var sess
var signs := {}  ## business id -> Label3D


func _init(sess_) -> void:
	sess = sess_
	name = "BusinessSigns"


func _ready() -> void:
	build()


## One post and label per business in the catalog, at its site on the ground.
func build() -> void:
	if sess == null or sess.businesses == null:
		return
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.25, 0.24, 0.22)
	for b in sess.businesses.catalog:
		var x := float(b.site[0])
		var y := float(b.site[1])
		var base: Vector3 = MeshBuilder.to_godot([x, y, maxf(0.0, sess.world.ground(x, y))])
		var post := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.15, POST_H, 0.15)
		post.mesh = bm
		post.material_override = post_mat
		post.position = base + Vector3(0, POST_H / 2.0, 0)
		post.name = "post-" + str(b.id)
		add_child(post)
		var label := Label3D.new()
		label.name = "sign-" + str(b.id)
		label.font_size = 64
		label.outline_size = 14
		label.pixel_size = 0.016
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = base + Vector3(0, POST_H + 1.0, 0)
		add_child(label)
		signs[str(b.id)] = label
	refresh()


## The sign's two lines: the name, then whose it is (or its price, for sale).
static func text_for(b: Dictionary, owner: String) -> String:
	var whose := ""
	match owner:
		"org":
			whose = "ours"
		"":
			whose = "for sale: $%s" % Py.money(int(b.get("price", 0))) if int(b.get("price", 0)) > 0 else "nobody's"
		"outside":
			whose = "not for sale"
		_:
			whose = str(Businesses.ORG_NAMES.get(owner, owner))
	return "%s\n%s - %s" % [str(b.name), str(b.kind), whose]


## Names and colours from the sim; shown only near the camera.
func refresh(cam := Vector3.INF) -> void:
	if sess == null or sess.businesses == null:
		return
	for b in sess.businesses.catalog:
		var label: Label3D = signs.get(str(b.id))
		if label == null:
			continue
		var owner := str(sess.businesses.owner.get(str(b.id), ""))
		label.text = text_for(b, owner)
		label.modulate = COLOURS.get(owner, COLOURS[""])
		if cam != Vector3.INF:
			label.visible = label.position.distance_to(cam) < SHOW_M
