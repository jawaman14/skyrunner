class_name PeriodVehicles
extends RefCounted
## Original 1979–1982-inspired bodies, not replicas of branded vehicles.
## Normalized envelopes preserve ModelLib dimensions; collision belongs to callers.
const TYPES := {"sedan":"sedan", "sedan-sports":"coupe", "hatchback-sports":"compact",
	"suv":"utility", "suv-luxury":"wagon", "police":"sedan", "taxi":"sedan",
	"van":"van", "delivery":"box", "ambulance":"box", "truck":"box", "truck-flat":"pickup"}
const PAINT := {"org":Color(0.77,0.73,0.60), "rival":Color(0.43,0.23,0.16),
	"police":Color(0.78,0.79,0.73), "family":Color(0.23,0.29,0.23), "civilian":Color(0.44,0.57,0.60)}
const TYRE := Color(0.075,0.07,0.065)
const STEEL := Color(0.49,0.49,0.44)
const GLASS := Color(0.12,0.21,0.23)
static var _cache := {}
static var _material: StandardMaterial3D

static func supports(file: String) -> bool: return TYPES.has(file)

static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.78
	return _material

static func build(file: String, envelope: Vector3, faction := "civilian") -> Node3D:
	var root := Node3D.new()
	root.name = file
	root.scale = envelope
	root.set_meta("period_asset", file)
	for lod in 3:
		var key := "%s/%s/%d/%.5f" % [file,faction,lod,envelope.y/envelope.z]
		if not _cache.has(key): _cache[key] = _mesh(file,faction,lod,envelope.y/envelope.z)
		var mi := MeshInstance3D.new()
		mi.name = "LOD%d" % lod
		mi.mesh = _cache[key]
		mi.material_override = material()
		mi.visibility_range_begin = [0.0,55.0,180.0][lod]
		mi.visibility_range_end = [55.0,180.0,2500.0][lod]
		if lod > 0: mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	return root

static func _box(b: MeshBuilder, p: Vector3, size: Vector3, color: Color) -> void:
	b.box(p.x,-p.z,p.y,size.x,size.z,size.y,[color.r,color.g,color.b])

static func _cabin(b: MeshBuilder, front: float, rear: float, top: float, paint: Color) -> void:
	var points := []
	for p in [Vector3(-.42,.49,rear),Vector3(.42,.49,rear),Vector3(.42,.49,front),Vector3(-.42,.49,front),
		Vector3(-.35,top,rear-.05),Vector3(.35,top,rear-.05),Vector3(.35,top,front+.08),Vector3(-.35,top,front+.08)]:
		points.append([p.x,-p.z,p.y])
	b.hexa(points,[GLASS.r,GLASS.g,GLASS.b])
	_box(b,Vector3(0,top+.025,(front+rear+.03)/2),Vector3(.74,.05,rear-front-.10),paint)

static func _wheel(b: MeshBuilder, x: float, z: float, segments: int, ratio: float, hub := true) -> void:
	var radius := .16
	for i in segments:
		var a := TAU*i/segments
		var c := TAU*(i+1)/segments
		var points := []
		for xx in [x-.055,x+.055]:
			for angle in [a,c]: points.append([xx,-z-radius*ratio*sin(angle),radius+radius*cos(angle)])
		b.quad(points[0],points[1],points[3],points[2],[TYRE.r,TYRE.g,TYRE.b])
		for side in [0,1]:
			var xx: float = x + (-.055 if side == 0 else .055)
			b.tri([xx,-z,radius],points[side*2+(1 if side == 0 else 0)],points[side*2+(0 if side == 0 else 1)],[TYRE.r,TYRE.g,TYRE.b])
	if hub: _box(b,Vector3(signf(x)*.4975,radius,z),Vector3(.005,.17,.17*ratio),STEEL)

static func _mesh(file: String, faction: String, lod: int, ratio: float) -> ArrayMesh:
	var b := MeshBuilder.new()
	var paint: Color = PAINT.get(faction,PAINT.civilian)
	if file == "police": paint = PAINT.police
	if file == "taxi": paint = Color(.72,.57,.22)
	if file == "ambulance": paint = Color(.82,.79,.65)
	if file == "truck": paint = Color(.37,.39,.35)
	var kind: String = TYPES[file]
	var police := faction == "police" or file == "police"
	_box(b,Vector3(0,.37,0),Vector3(.87,.30,.94),paint)
	if kind in ["van","box"]:
		var roof := .92 if police else 1.0
		_box(b,Vector3(0,(roof+.25)/2,.14),Vector3(.88,roof-.25,.65),paint)
		_cabin(b,-.40,-.10,.79,paint)
	elif kind == "pickup":
		_cabin(b,-.29,.03,.95,paint)
		_box(b,Vector3(0,.48,.25),Vector3(.85,.08,.44),Color(.27,.23,.18))
		for side in [-1,1]: _box(b,Vector3(side*.41,.62,.25),Vector3(.05,.27,.44),paint)
		_box(b,Vector3(0,.62,.45),Vector3(.85,.27,.04),paint)
	elif kind in ["utility","wagon"]:
		_cabin(b,-.27,.43,.95,paint)
	else:
		var top := .95 if not police else .85
		var front := -.22 if kind == "compact" else -.15
		var rear := .36 if kind == "compact" else .25
		_cabin(b,front,rear,top,paint)
	# Chrome bumpers end exactly at the old longitudinal envelope.
	for end in [-1,1]:
		_box(b,Vector3(0,.30,end*.487),Vector3(.93,.055,.026),STEEL)
		for side in [-1,1]:
			_box(b,Vector3(side*.31,.43,end*.476),Vector3(.16,.09,.018),Color(.92,.86,.65) if end < 0 else Color(.46,.13,.10))
	for z in [-.31,.31]:
		for side in [-1,1]: _wheel(b,side*.445,z,[12,8,4][lod],ratio,lod < 2)
	if police:
		_box(b,Vector3(0,.91,.04),Vector3(.65,.04,.11),STEEL)
		for side in [-1,1]:
			_box(b,Vector3(side*.21,.97,.04),Vector3(.19,.06,.10),Color(.65,.16,.12) if side < 0 else Color(.18,.30,.48))
			_box(b,Vector3(side*.437,.40,.05),Vector3(.008,.23,.25),Color(.15,.20,.23))
	elif file == "taxi": _box(b,Vector3(0,.99,.04),Vector3(.28,.02,.13),Color(.75,.64,.35))
	if lod == 0:
		# Grille slats, handles, rub strips and fixed wear; no RNG/state mutation.
		for slat in 9: _box(b,Vector3(-.25+slat*.0625,.43,-.48),Vector3(.025,.09,.02),STEEL)
		for side in [-1,1]:
			_box(b,Vector3(side*.436,.34,0),Vector3(.006,.025,.74),TYRE)
			for z in [-.03,.22]:
				_box(b,Vector3(side*.435,.49,z),Vector3(.008,.014,.05),STEEL)
				_box(b,Vector3(side*.437,.27,z+.04),Vector3(.006,.035,.07),Color(.39,.28,.18))
			if kind not in ["van","box","pickup"]:
				_box(b,Vector3(side*.395,.70,.07),Vector3(.023,.35,.025),paint)
		if kind in ["van","box"]:
			for seam in [-.12,.14,.40]: _box(b,Vector3(.443,.65,seam),Vector3(.004,.59,.009),STEEL)
		if file == "ambulance":
			for side in [-1,1]:
				_box(b,Vector3(side*.445,.64,.2),Vector3(.004,.06,.20),Color(.57,.16,.12))
				_box(b,Vector3(side*.447,.64,.2),Vector3(.004,.24,.05),Color(.57,.16,.12))
		if police: _box(b,Vector3(.23,.88,.25),Vector3(.005,.12,.005),TYRE)
	return b.mesh()
