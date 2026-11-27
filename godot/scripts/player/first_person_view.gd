class_name FirstPersonView
extends Node3D
## The tool in hand as seen through the farmer's own eyes (the first-person camera option): its own copy of the made
## model (Avatar.MADE) on the camera, low at the right. A gun points ahead, comes up to the middle while you aim and
## kicks when it fires; an axe, pick or spear rides with its haft forward, head up, and chops down across the view when
## you swing. A slight bob as you walk. No shadow of its own (his body casts the real one).

var models := {}           ## MADE key -> Node3D holder
var shown := ""
var t := 0.0
var aim_k := 0.0           ## 0 at rest, 1 raised to aim
## (the grip held just below the frame: only the business end shows, the player's ask; no hand drawn)
const REST := Vector3(0.25, -0.29, -0.46)
const AIM := Vector3(0.0, -0.215, -0.42)
const TOOL_REST := Vector3(0.3, -0.42, -0.42)

func _holder(key: String) -> Node3D:
	if models.has(key): return models[key]
	models[key] = null
	var spec: Array = Avatar.MADE.get(key, [])
	if spec.is_empty(): return null
	var path := "res://assets/models/props/%s.glb" % spec[0]
	if not ResourceLoader.exists(path): return null
	var m := (load(path) as PackedScene).instantiate() as Node3D
	PaperMats.paperize(m, false)
	for c in m.find_children("*", "GeometryInstance3D", true, false): (c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var k: float = float(spec[1]) / 1.9
	var holder := Node3D.new(); var pivot := Node3D.new(); holder.add_child(pivot); pivot.add_child(m)
	if key in ["revolver", "rifle", "rifle_lever", "shotgun"]:
		# along the view, muzzle ahead: model -x to the camera's -z (its x to +z), y up; the grip at the pivot
		m.transform = Transform3D(Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0)) * k, Vector3(0, -0.04, -float(spec[2]) * k + (0.25 if key != "revolver" else 0.0)))
	else:
		# a haft: its foot at the pivot, the handle (model y) reaching forward and up, the head's blade (model +x) leading
		var b := Basis(Vector3.RIGHT, -1.05) * Basis(Vector3.UP, PI / 2.0)
		m.transform = Transform3D(b * k, b * Vector3(0, -float(spec[2]) * 0.0, 0) * k)
		pivot.position = Vector3(0, 0, 0.1)
	add_child(holder); holder.visible = false
	models[key] = holder
	return holder

## A box-built tool (the old hatchet, hammer, fishing pole, bow: Avatar.tools_by) copied for the camera: a haft forward
## and up as the made tools; the bow stood upright by its longest side, held out to the left.
func _box_holder(id: String, src: Node3D) -> Node3D:
	var key := "box:" + id
	if models.has(key): return models[key]
	var c := src.duplicate() as Node3D
	c.visible = true; c.transform = Transform3D.IDENTITY
	for gi in c.find_children("*", "GeometryInstance3D", true, false):
		(gi as VisualInstance3D).layers = 1; (gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var holder := Node3D.new(); var pivot := Node3D.new(); holder.add_child(pivot); pivot.add_child(c)
	if id == "bow":
		var bb := PaperMats._aabb(c, Transform3D.IDENTITY)
		var ax := 0 if bb.size.x >= bb.size.y and bb.size.x >= bb.size.z else (1 if bb.size.y >= bb.size.z else 2)
		c.basis = [Basis(Vector3.BACK, PI / 2.0), Basis(), Basis(Vector3.RIGHT, -PI / 2.0)][ax] # (its long side up)
		var mid := c.basis * bb.get_center(); c.position = -mid # (held at its middle)
	else:
		c.basis = Basis(Vector3.RIGHT, 0.5) * Basis(Vector3.UP, PI) # (the haft, along its +z, forward and a little up)
	add_child(holder); holder.visible = false
	models[key] = holder
	return holder

## His right hand on the grip (the player: only the weapon showed, no hand): a fist of skin-toned card closed round
## the handle at the pivot (knuckles proud, the thumb across), the bare forearm (his sleeves are rolled) and the rolled
## red cuff and sleeve running back and down out of the frame. Rides the pivot, so it chops and kicks with the tool.
const SKIN := Color("d9a07a")
const SKIN_D := Color("c48660")
const SHIRT := Color("b8402e")
const CUFF := Color("d86a4e")
static func _part(mesh: Mesh, col: Color, xf: Transform3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = PaperMats.paper(col, false); mi.transform = xf
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
static func _box(x: float, y: float, z: float) -> BoxMesh: var b := BoxMesh.new(); b.size = Vector3(x, y, z); return b
static func _cap(r: float, h: float) -> CapsuleMesh: var c := CapsuleMesh.new(); c.radius = r; c.height = h; c.radial_segments = 10; c.rings = 3; return c
static func _cyl(r0: float, r1: float, h: float) -> CylinderMesh: var c := CylinderMesh.new(); c.top_radius = r0; c.bottom_radius = r1; c.height = h; c.radial_segments = 10; return c
## A limb from a to b (pivot space): mesh along its own y, centred between.
static func _along(mesh: Mesh, col: Color, a: Vector3, b: Vector3) -> MeshInstance3D:
	var d := b - a; var y := d.normalized(); var x := y.cross(Vector3.FORWARD).normalized() if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var z := x.cross(y)
	return _part(mesh, col, Transform3D(Basis(x, y, z), (a + b) / 2.0))
static func make_hand() -> Node3D:
	var g := Node3D.new()
	g.add_child(_part(_box(0.06, 0.085, 0.05), SKIN, Transform3D(Basis(), Vector3(0.012, -0.005, 0.035)))) # (the back of the hand)
	for i in 4: # (four fingers curled round the grip, stacked, the little one shorter)
		var fy := 0.032 - i * 0.022; var ln := 0.075 - (0.012 if i == 3 else 0.0)
		g.add_child(_along(_cap(0.0125, ln), SKIN if i % 2 == 0 else SKIN_D, Vector3(0.04, fy, 0.0), Vector3(-0.025, fy - 0.003, -0.012)))
	g.add_child(_along(_cap(0.014, 0.075), SKIN, Vector3(-0.03, 0.0, 0.045), Vector3(-0.022, 0.042, -0.005))) # (the thumb up over the top)
	var wrist := Vector3(0.01, -0.03, 0.07); var elbow := Vector3(0.09, -0.2, 0.42)
	g.add_child(_along(_cap(0.036, 0.34), SKIN, wrist, wrist.lerp(elbow, 0.75))) # (the bare forearm)
	g.add_child(_along(_cyl(0.052, 0.05, 0.05), CUFF, wrist.lerp(elbow, 0.7), wrist.lerp(elbow, 0.82))) # (the rolled cuff)
	g.add_child(_along(_cyl(0.06, 0.055, 0.3), SHIRT, wrist.lerp(elbow, 0.8), elbow + (elbow - wrist) * 0.5)) # (the sleeve, out of the frame)
	return g

## Each frame through his eyes: key the held made tool ("" for none), aiming (a gun raised), swing (0..1 through a
## chop, < 0 none), casting (> 0 just after a shot), speed (walking pace).
func update(dt: float, key: String, aiming: bool, swing: float, casting: float, speed: float, box_id := "", box: Node3D = null) -> void:
	t += dt
	if key == "" and box != null: key = "box:" + box_id
	var h: Node3D = (_box_holder(box_id, box) if key.begins_with("box:") else _holder(key)) if key != "" else null
	if shown != key:
		if models.get(shown) != null: (models[shown] as Node3D).visible = false
		shown = key
	if h == null: return
	h.visible = true
	var gun: bool = key in ["revolver", "rifle", "rifle_lever", "shotgun"]
	var bow: bool = key == "box:bow"
	aim_k = move_toward(aim_k, 1.0 if aiming and (gun or bow) else 0.0, dt * 6.0)
	var bob := sin(t * 9.0) * 0.012 * clampf(speed / 6.0, 0.0, 1.0) * (1.0 - aim_k)
	var rest := Vector3(-0.3, -0.42, -0.6) if bow else (REST if gun else TOOL_REST); var aim := Vector3(-0.2, -0.36, -0.6) if bow else AIM
	h.position = rest.lerp(aim, aim_k) + Vector3(bob * 0.5, absf(bob), 0)
	if bow: h.rotation = Vector3(0, 0, 0.25 * (1.0 - aim_k)) # (canted at rest, upright when drawn)
	var pivot := h.get_child(0) as Node3D
	if gun: pivot.rotation = Vector3(casting * 0.5, 0.0, 0.0) # (the kick)
	else: pivot.rotation = Vector3(-sin(clampf(swing, 0.0, 1.0) * PI) * 1.2 if swing >= 0.0 else 0.0, 0.0, 0.0) # (the chop)

## The bow's hand: the fist round its grip, the forearm reaching back and down to the left (it's held out at arm's length).
static func _bow_hand() -> Node3D:
	var g := make_hand(); g.scale = Vector3(-1, 1, 1) # (his left hand, mirrored)
	return g

func hide_all() -> void:
	for k in models: if models[k] != null: (models[k] as Node3D).visible = false
	shown = ""
