class_name Avatar
extends RefCounted
## avatar.js: you, from the reference art (Big Jim in the brick-red shirt and braces, or the weathered homesteader).
## Plays walk/idle/work by speed and swing, flags a footfall each half stride, and reports the moment a tool swing
## connects. The tools are held in the closed fist (placed each frame from the hand bone), the guns ride at the
## hand in the body's frame, the quiver across his back once he has a bow, and the lightning-bug jar in his left hand.

var fig: ModelFigure
var root: Node3D
var swing := -1.0          ## < 0 idle, else 0..1 through a swing
var swinging := false
var casting := 0.0
var stepped := false
var riding := false
var seated := false
var tool := "axe"

func _init() -> void:
	var me := "folk_jim" if ModelFigure.has_folk("folk_jim") else "folk_player"
	fig = ModelFigure.new(me)
	fig.borrow_clip("run", "folk_native_warrior") # (a run for his sprint: his own model has only walk)
	root = fig.root
	_build_tools()

## A cast of the line (or a shot loosed): an arm-out flick on the model; never a blow.
func start_cast() -> void:
	casting = 0.7; fig.current = ""

## Start a swing (false if one is already under way).
func start_swing() -> bool:
	if swing >= 0.0: return false
	swing = 0.0
	return true

func update(dt: float, speed: float, air: bool, swim: bool) -> bool:
	var prev_step := floori(fig.phase / PI)
	if swing >= 0.0 and not swinging and fig.player and fig.player.has_animation("work"):
		fig.current = "" # (each swing plays the work clip from the top)
	swinging = swing >= 0.0
	casting = maxf(0.0, casting - dt)
	var pose = "sit" if (riding or seated) else ("cast" if casting > 0.0 else ("swing" if swing >= 0.0 else null))
	fig.update(dt, 0.0 if (riding or seated) else speed, pose)
	_show_tools(swim)
	if floori(fig.phase / PI) != prev_step and speed > 0.8 and not air and not swim: stepped = true
	var connected := false
	if swing >= 0.0:
		var prev := swing
		swing += dt / 0.5
		if prev < 0.52 and swing >= 0.52: connected = true
		if swing >= 1.0: swing = -1.0
	return connected

# ------------------------------------------------------------------ the tools in his fist (avatar.js)
var tools_by := {}        ## id -> Node3D (axe, pick, hammer, spear, rod, bow, revolver, rifle)
var grip := Node3D.new()
var grip_along := 0.035  ## the fist's middle, this far down the hand bone from the wrist (was 0.06: the handle sat past his fingertips)
var grip_palm := 0.035   ## and this far across it, toward the palm (was -0.025, on the back of the hand)
var fist: MeshInstance3D
var quiver := Node3D.new()
var has_bow := false
var aiming := false
var jar := Node3D.new()
var jar_core_mat: StandardMaterial3D
var jar_light := OmniLight3D.new()
var jar_t := 0.0
var _hand_i := -1
var _fore_i := -1
var _spine_i := -1
static var _mats := {}

static func _mat(hex: int) -> Material:
	if not _mats.has(hex): _mats[hex] = PaperMats.paper(Color.hex((hex << 8) | 0xff))
	return _mats[hex]

static func _cyl(rt: float, rb: float, h: float, seg: int) -> CylinderMesh:
	var c := CylinderMesh.new(); c.top_radius = rt; c.bottom_radius = rb; c.height = h; c.radial_segments = seg; c.rings = 1; return c
static func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new(); b.size = Vector3(x, y, z); return b
static func _rx(a: float) -> Basis: return Basis(Vector3.RIGHT, a)

## A piece: mesh, placed by xf (three's geometry rotate-then-translate), in paper of colour hex.
static func _piece(mesh: Mesh, xf: Transform3D, hex: int) -> MeshInstance3D:
	var m := MeshInstance3D.new(); m.mesh = mesh; m.transform = xf; m.material_override = _mat(hex); return m
## A thin rod from a to b (the bow stave, a bent run of them).
static func _rod(a: Vector3, b: Vector3, r: float, hex: int) -> MeshInstance3D:
	var d := b - a; var y := d.normalized(); var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized(); var z := x.cross(y)
	return _piece(_cyl(r, r, d.length(), 5), Transform3D(Basis(x, y, z), (a + b) / 2.0), hex)

func _tool(id: String, parts: Array) -> Node3D:
	var g := Node3D.new(); g.visible = false
	for p in parts: g.add_child(p)
	tools_by[id] = g
	return g

func _handle(len: float, r := 0.03) -> MeshInstance3D: return _piece(_cyl(r, r * 1.15, len, 6), Transform3D(_rx(PI / 2), Vector3(0, 0, len / 2 - 0.12)), 0x8a6038)

func _build_tools() -> void:
	fig.root.add_child(grip)
	# a felling axe, a pickaxe, a claw hammer, the ash spear and the willow fishing pole
	grip.add_child(_tool("axe", [_handle(0.85), _piece(_box(0.035, 0.26, 0.17), Transform3D(Basis(), Vector3(0, 0.08, 0.66)), 0xb9bec4), _piece(_box(0.04, 0.05, 0.08), Transform3D(Basis(), Vector3(0, -0.06, 0.66)), 0x8e9294)]))
	grip.add_child(_tool("pick", [_handle(0.85), _piece(_cyl(0.032, 0.032, 0.56, 5), Transform3D(Basis(Vector3.UP, PI / 2) * Basis(Vector3.BACK, PI / 2), Vector3(0, 0.05, 0.66)), 0x9a9da2)]))
	grip.add_child(_tool("hammer", [_handle(0.62), _piece(_box(0.1, 0.2, 0.1), Transform3D(Basis(), Vector3(0, 0.02, 0.46)), 0x6e5a48)]))
	var sp := _piece(_cyl(0.028, 0.028 * 1.15, 1.5, 6), Transform3D(_rx(PI / 2), Vector3(0, 0, 0.75 - 0.12)), 0x9a7448)
	grip.add_child(_tool("spear", [sp, _piece(_box(0.06, 0.05, 0.12), Transform3D(Basis(), Vector3(0, 0, 1.1)), 0x5a3a20), _piece(_cyl(0.0, 0.07, 0.28, 4), Transform3D(_rx(PI / 2), Vector3(0, 0, 1.3)), 0x8e8a80)]))
	grip.add_child(_tool("rod", [_piece(_cyl(0.014, 0.03, 1.9, 5), Transform3D(_rx(PI / 2 - 0.5), Vector3(0, 0.42, 0.75)), 0xa88a50), _piece(_box(0.07, 0.07, 0.07), Transform3D(Basis(), Vector3(0, 0.02, 0.08)), 0xb5473a)]))
	# the hunting bow: a hickory stave curved like a drawn brow, through the fist, with a cream string tip to tip
	var R := 0.9; var half := 0.62
	var T := Transform3D(_rx(-PI / 2)) * Transform3D(Basis(Vector3.UP, PI / 2)) * Transform3D(Basis(), Vector3(0, -R, 0)) * Transform3D(Basis(Vector3.BACK, PI / 2 - half))
	var bow_parts := []
	for i in 14:
		var a0 := 2.0 * half * i / 14.0; var a1 := 2.0 * half * (i + 1) / 14.0
		bow_parts.append(_rod(T * Vector3(R * cos(a0), R * sin(a0), 0), T * Vector3(R * cos(a1), R * sin(a1), 0), 0.022, 0x9a6a3c))
	var sT := Transform3D(_rx(-PI / 2)) * Transform3D(Basis(), Vector3(0, R * cos(half) - R, 0)) * Transform3D(_rx(PI / 2))
	bow_parts.append(_piece(_cyl(0.005, 0.005, 2.0 * R * sin(half), 3), sT, 0xefe2c4))
	bow_parts.append(_piece(_box(0.05, 0.06, 0.1), Transform3D.IDENTITY, 0x5a3a20))
	grip.add_child(_tool("bow", bow_parts))
	# the six-shooter and the buffalo rifle ride in the body's own frame at the hand, barrel along the way he faces
	root.add_child(_tool("revolver", [_piece(_box(0.045, 0.13, 0.06), Transform3D(_rx(0.3), Vector3(0, -0.06, -0.01)), 0x6a4428), _piece(_cyl(0.042, 0.042, 0.08, 8), Transform3D(_rx(PI / 2), Vector3(0, 0.025, 0.04)), 0x5a5a60), _piece(_cyl(0.017, 0.017, 0.24, 6), Transform3D(_rx(PI / 2), Vector3(0, 0.035, 0.19)), 0x3e3e44)]))
	root.add_child(_tool("rifle", [_piece(_box(0.06, 0.11, 0.42), Transform3D(Basis(), Vector3(0, -0.03, -0.24)), 0x7a4a26), _piece(_box(0.05, 0.05, 0.42), Transform3D(Basis(), Vector3(0, 0, 0.18)), 0x8a5a30), _piece(_cyl(0.02, 0.022, 1.0, 8), Transform3D(_rx(PI / 2), Vector3(0, 0.035, 0.45)), 0x3e3e44)]))
	# his curled fingers round the haft, in his skin tone
	fist = _piece(_cyl(0.042, 0.04, 0.095, 7), Transform3D(_rx(PI / 2), Vector3.ZERO), 0xd49a76); grip.add_child(fist)
	# the quiver across his back once he has a bow: a stitched leather tube with three arrows' fletchings peeping out
	var tube := _cyl(0.08, 0.068, 0.62, 10); tube.cap_top = false
	quiver.add_child(_piece(tube, Transform3D.IDENTITY, 0x7a4a26))
	for y in [-0.31, 0.2, 0.29]: quiver.add_child(_piece(_cyl(0.085, 0.085, 0.035, 10), Transform3D(Basis(), Vector3(0, y, 0)), 0x5a3418 if y < 0 else 0xc89a5a))
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fl := [Vector3(0, 0, 0), Vector3(0.05, 0.03, 0), Vector3(0.045, 0.15, 0), Vector3(0, 0.13, 0)]
	for tri in [[0, 2, 1], [0, 3, 2], [0, 1, 2], [0, 2, 3]]:
		for k in tri: st.add_vertex(fl[k])
	st.generate_normals(); var flm := st.commit()
	var specs := [[0.025, 0.02, 0.38], [-0.03, 0.015, 0.42], [0.005, -0.03, 0.35]]
	for i in 3:
		var x: float = specs[i][0]; var z: float = specs[i][1]; var h: float = specs[i][2]
		var arrow := Node3D.new(); arrow.position = Vector3(x, 0.31, z); arrow.rotation = Vector3(z * 4, i * 1.9, -x * 4)
		arrow.add_child(_piece(_cyl(0.009, 0.009, h, 4), Transform3D(Basis(), Vector3(0, h / 2 - 0.15, 0)), 0xc8a46e))
		for k in 2: arrow.add_child(_piece(flm, Transform3D(Basis(Vector3.UP, k * PI / 2), Vector3(0, h - 0.3, 0)), 0xefe2c4 if (i + k) % 2 else 0xa8352a))
		quiver.add_child(arrow)
	quiver.visible = false; root.add_child(quiver)
	# the lightning-bug jar, hanging by its twine from his left hand (glowing brighter with each bug caught)
	var glass := StandardMaterial3D.new(); glass.albedo_color = Color(0xcf / 255.0, 0xe0 / 255.0, 0xd4 / 255.0, 0.55); glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; glass.roughness = 1.0
	var body := MeshInstance3D.new(); body.mesh = _cyl(0.1, 0.09, 0.22, 10); body.material_override = glass; body.position.y = -0.12; jar.add_child(body)
	jar.add_child(_piece(_cyl(0.085, 0.085, 0.04, 10), Transform3D(Basis(), Vector3(0, 0.01, 0)), 0xb08a4a))
	var tw := TorusMesh.new(); tw.inner_radius = 0.062; tw.outer_radius = 0.078; tw.rings = 10; tw.ring_segments = 4
	jar.add_child(_piece(tw, Transform3D(_rx(PI / 2), Vector3(0, 0.06, 0)), 0xd9c49a))
	jar_core_mat = StandardMaterial3D.new(); jar_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; jar_core_mat.albedo_color = Color.BLACK
	var core := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.065; sm.height = 0.13; sm.radial_segments = 8; sm.rings = 6; core.mesh = sm; core.material_override = jar_core_mat; core.position.y = -0.12; jar.add_child(core)
	jar_light.light_color = Color.hex(0xffd27aff).srgb_to_linear(); jar_light.light_energy = 0.0; jar_light.omni_range = 7.0; jar_light.omni_attenuation = 1.4; jar_light.position.y = -0.12; jar.add_child(jar_light)
	for c in jar.get_children(): if c is GeometryInstance3D: (c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	jar.visible = false; root.add_child(jar)
	if fig.skeleton:
		_hand_i = fig.skeleton.find_bone("RightHand"); _fore_i = fig.skeleton.get_bone_parent(_hand_i) if _hand_i >= 0 else -1
		_spine_i = fig.skeleton.find_bone("Spine02")
		if _spine_i < 0: _spine_i = fig.skeleton.find_bone("Spine01")

func _bone_xf(i: int) -> Transform3D: return fig.skeleton.global_transform * fig.skeleton.get_bone_global_pose(i)

## The grip: the hand bone runs wrist to fingertips along its +y; the middle of the closed fist is a little down it,
## and a handle held there runs square across the fingers, pointing as near his forward as it can.
func _hold_tools() -> void:
	var hb: Node3D = fig.hands[1].get_parent()
	var q := hb.global_basis.orthonormalized(); var p := hb.global_position
	var y := q.y
	var z := root.global_basis.z.normalized(); z = z - y * z.dot(y)
	if z.length_squared() < 1e-4: z = root.global_basis.y
	z = z.normalized(); var x := y.cross(z).normalized(); var yy := z.cross(x)
	p += y * grip_along + q.z * grip_palm # (in the palm)
	grip.global_transform = Transform3D(Basis(x, yy, z), p)

## The quiver rides the upper spine, set back by the depth of his back, slung on the slant, its mouth over his right shoulder.
func _wear_quiver() -> void:
	if _spine_i < 0: return
	var p := _bone_xf(_spine_i).origin; var rb := root.global_basis.orthonormalized()
	p += -rb.z * 0.2 + Vector3(0, 0.06, 0)
	quiver.global_transform = Transform3D(rb * Basis(Vector3.BACK, 0.55) * Basis(Vector3.RIGHT, -0.18), p)

## The gun in hand rides at the hand in the body's own frame: carried pointing ahead and down, raised level while aiming.
func _aim_guns() -> void:
	var gun: Node3D = tools_by.revolver if tools_by.revolver.visible else (tools_by.rifle if tools_by.rifle.visible else null)
	if gun == null or _hand_i < 0: return
	var gp := _bone_xf(_hand_i).origin
	if _fore_i >= 0: gp += (gp - _bone_xf(_fore_i).origin).normalized() * (0.04 if aiming else 0.045) # (the grip in his palm, not out past the fingers)
	gun.position = root.to_local(gp); gun.rotation = Vector3(-0.05 if aiming else 0.55, 0, 0)

func _show_tools(swim: bool) -> void:
	var any := false
	for id in tools_by:
		var on: bool = not swim and not seated and tool == id
		tools_by[id].visible = on; any = any or on
	fist.visible = any
	if any and _hand_i >= 0: _hold_tools()
	_aim_guns()
	quiver.visible = has_bow and not swim
	if quiver.visible: _wear_quiver()

## The jar: shown once you own it; glowing with the catch, flickering softly as the bugs blink.
func jar_update(dt: float, owned: bool, count: int, night: float) -> void:
	jar_t += dt
	jar.visible = owned
	if not owned: jar_light.light_energy = 0.0; return
	var lh: Node3D = fig.hands[0].get_parent()
	jar.global_position = lh.global_position + Vector3(0, -0.2, 0); jar.rotation = Vector3.ZERO # (by its twine, below the fingers)
	var k := count / 6.0
	var flicker := 0.85 + 0.15 * sin(jar_t * 7.3) * sin(jar_t * 3.1 + 1.2)
	var glow := (0.25 + k * 0.75) * flicker if count else 0.0
	jar_core_mat.albedo_color = Color(minf(1.0, 1.5 * glow), 1.05 * glow, 0.28 * glow)
	jar_light.light_energy = k * 2.6 * flicker * maxf(0.3, night) / PI # (three's lights land on a Lambert surface divided by pi, as every light here)
