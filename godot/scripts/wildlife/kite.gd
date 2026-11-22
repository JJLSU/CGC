class_name Kite
extends Node3D
## kite.js: a paper kite, a patchwork diamond of barn red, cream and blue on two cross-sticks with a tail of little
## paper bows, flown on a twine string from the farmer's hand. G lets it up: it climbs with a springy rise, then
## rides high and out to the side (toward the lens, so it stays in view), bobbing and rocking. G reels it in; a
## shower brings it down. Crows won't come near the garden while it's up over it.

const DIAMOND := [[0, 0.95], [0.6, 0.18], [0, -0.85], [-0.6, 0.18]]
const BOW := [[-0.16, 0.07], [0, 0.02], [0.16, 0.07], [0.16, -0.07], [0, -0.02], [-0.16, -0.07]]
const BOWS := 6

var kite: MeshInstance3D
var bows := MultiMesh.new()
var bows_mi := MultiMeshInstance3D.new()
var line := MeshInstance3D.new()
var line_mesh := ImmediateMesh.new()
var flying := false
var t := 0.0
var up := 0.0
var pos := Vector3.ZERO
var hand := Vector3.ZERO

func _init() -> void:
	kite = Town.card(DIAMOND, "res://assets/baked/wildlife/kite", 0.02, 0.0); kite.visible = false; add_child(kite)
	var bow := Town.card(BOW, "res://assets/baked/wildlife/kite_bow", 0.01, 0.0)
	bows.transform_format = MultiMesh.TRANSFORM_3D; bows.use_colors = true; bows.mesh = bow.mesh; bows.instance_count = BOWS
	for i in BOWS: bows.set_instance_color(i, Color.hex(([0xd9a441, 0xb5473a, 0x4f6f96][i % 3] << 8) | 0xff))
	bows_mi.multimesh = bows; bows_mi.material_override = bow.material_override; bows_mi.visible = false
	bows_mi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 400, 2e5)); add_child(bows_mi)
	# the twine: a sagging line from the hand to the kite
	var lm := StandardMaterial3D.new(); lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; lm.albedo_color = Color.hex(0x8a7050ff)
	line.mesh = line_mesh; line.material_override = lm; line.visible = false; line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(line)

func toggle(on := not flying) -> void:
	flying = on; up = 0.0 if on else up
	for o in [kite, bows_mi, line]: o.visible = on

## Returns "rain" the moment a shower brings it down.
func update(dt: float, player: Player, camera: Camera3D, rain: float) -> String:
	if not flying: return ""
	if rain > 0.3: toggle(false); return "rain"
	t += dt; up = minf(2.0, up + dt * 0.6)
	var k := Props.spring_rise(up)
	hand = Vector3(player.pos.x + sin(player.facing) * 0.4, player.pos.y + 1.6, player.pos.z + cos(player.facing) * 0.4)
	var gust := sin(t * 0.21) * 0.5 + sin(t * 0.83) * 0.3
	# like a diorama, the wind always carries it out to the side and a little toward the lens
	var cp := camera.global_position
	var tc := Vector3(cp.x - hand.x, 0, cp.z - hand.z).normalized(); var right := Vector3(tc.z, 0, -tc.x)
	var goal := Vector3(hand.x + (right.x * 2.6 + tc.x * 1.2) * k + sin(t * 0.4) * 1.2, hand.y + 6.5 * k + gust, hand.z + (right.z * 2.6 + tc.z * 1.2) * k + cos(t * 0.33) * 1.2)
	if up < 0.05: pos = hand
	pos = pos.lerp(goal, minf(1.0, dt * 2.5))
	kite.position = pos
	# face back toward the farmer, nose up, rocking side to side
	if pos.distance_to(hand) > 0.01: kite.look_at(hand, Vector3.UP, true)
	kite.rotate_object_local(Vector3.BACK, sin(t * 1.7) * 0.25 + sin(t * 3.1) * 0.08)
	kite.scale = Vector3.ONE * 1.3
	# the tail of bows trails below and downwind, snaking
	for i in BOWS:
		var s := (i + 1.0) / BOWS
		var p := Vector3(pos.x + right.x * s * 1.4 + sin(t * 3 + i * 0.9) * 0.25 * s, pos.y - 1.1 - s * 2.0, pos.z + right.z * s * 1.4 + cos(t * 2.5 + i) * 0.2 * s)
		var b := Basis.from_euler(Vector3(0, atan2(cp.x - p.x, cp.z - p.z), sin(t * 4 + i) * 0.5), EULER_ORDER_XYZ).scaled(Vector3.ONE * 1.2)
		bows.set_instance_transform(i, Transform3D(b, p))
	# the string: sags a little in the middle
	line_mesh.clear_surfaces(); line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in 17:
		var s := i / 16.0
		line_mesh.surface_add_vertex(Vector3(hand.x + (pos.x - hand.x) * s, hand.y + (pos.y - 1.0 - hand.y) * s - sin(s * PI) * 1.2, hand.z + (pos.z - hand.z) * s))
	line_mesh.surface_end()
	return ""
