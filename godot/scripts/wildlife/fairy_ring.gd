class_name FairyRing
extends Node3D
## fairyring.js: the morning after a rainy night, a ring of nine red-capped toadstools comes up in a meadow 25-50 m
## off, hinging up out of the grass one by one round the ring. E in the middle gathers them (and now and then the
## luck folks talk about). Gone by evening if nobody finds it.

const N := 9
const DIRS := ["east", "north-east", "north", "north-west", "west", "south-west", "south", "south-east"]
const PTS := [[-0.05, 0], [0.05, 0], [0.045, 0.14], [0.08, 0.15], [0.05, 0.17], [0.05, 0.21], [0.19, 0.22], [0.17, 0.29], [0.1, 0.35], [0, 0.37], [-0.1, 0.35], [-0.17, 0.29], [-0.19, 0.22], [-0.05, 0.21], [-0.05, 0.17], [-0.08, 0.15], [-0.045, 0.14]]

var mm := MultiMesh.new()
var at := Vector3.ZERO
var day := -1
var state := "none"
var t := 0.0
var R := 1.7

func _init() -> void:
	# one plump toadstool: two crossed cards
	var card := Town.card(PTS, "res://assets/baked/wildlife/toadstool", 0.02, 0.0)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(card.mesh, 0, Transform3D.IDENTITY); st.append_from(card.mesh, 0, Transform3D(Basis(Vector3.UP, PI / 2), Vector3.ZERO))
	mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = st.commit(); mm.instance_count = N; mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; mi.material_override = card.material_override
	mi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 400, 2e5)); add_child(mi)

func near(p: Vector3) -> bool: return state == "up" and Vector2(p.x - at.x, p.z - at.z).length() < R + 0.6

## Morning after a wet night: a ring comes up 25-50 m off. Returns the direction word, or "".
func sprout(d: int, from: Vector3) -> String:
	for tries in 30:
		var a := randf() * TAU; var dd := 25.0 + randf() * 25.0
		var x := from.x + cos(a) * dd; var z := from.z + sin(a) * dd
		if Terrain.is_water(x, z) or Terrain.region_at(x, z) != "meadow": continue
		at = Vector3(x, Terrain.get_height(x, z), z); day = d; state = "up"; t = 0.0
		return DIRS[posmod(roundi(atan2(-(z - from.z), x - from.x) / (PI / 4)), 8)]
	return ""

func gather() -> void: state = "none"; mm.visible_instance_count = 0

func update(dt: float, sky: DaySky) -> void:
	if state != "up": return
	if sky.day != day or sky.time > 0.8: gather(); return # (gone by evening)
	t += dt
	for i in N:
		var a := float(i) / N * TAU
		var x := at.x + cos(a) * R; var z := at.z + sin(a) * R
		var k := Props.spring_rise(maxf(0.0, t * 1.2 - i * 0.12)) # (hinging up one by one, round the ring)
		var b := Basis.from_euler(Vector3(-(1.0 - k) * PI / 2, a * 1.7, 0), EULER_ORDER_XYZ).scaled_local(Vector3.ONE * (1.5 + ((i * 7) % 5) * 0.12))
		mm.set_instance_transform(i, Transform3D(b, Vector3(x, Terrain.get_height(x, z), z)))
	mm.visible_instance_count = N
