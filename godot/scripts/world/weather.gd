class_name Weather
extends Node3D
## weather.js: passing showers. Every few minutes the clouds roll in and a soft rain of thin paper slivers (or fat
## tumbling paper flakes, about one time in three) falls round the farmer for a minute or two; one rain in four is a
## thunderstorm that lingers. Snow lies on the land while it falls and melts slowly after. One MultiMesh of at most
## 420 crossed slivers in a 34 m box round the focus; none fall under a roof (covered(x, z)).

const MAX := 420
const BOX := 34.0
const TOP := 16.0
const FALL := 13.0

var rain := 0.0           ## 0..1, eased (rain or snow falling)
var kind := "rain"        ## "rain" | "snow"
var snow := 0.0           ## 0..1, snow lying on the ground
var target := 0
var next := 200.0 + randf() * 160.0
var next_kind := "snow" if randf() < 0.35 else "rain"
var next_storm := false
var storm := false
var left := 0.0
var on_start: Callable
var on_end: Callable
var mm: MultiMesh
var drops: Array = []

func _ready() -> void:
	next_storm = next_kind == "rain" and randf() < 0.28
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for rot in [0.0, PI / 2.0]: # two crossed slivers, 3.5 cm x 60 cm
		var b := Basis(Vector3.UP, rot)
		var w := 0.0175; var h := 0.3
		var q := [Vector3(-w, -h, 0), Vector3(w, -h, 0), Vector3(w, h, 0), Vector3(-w, h, 0)]
		for i in [0, 2, 1, 0, 3, 2]:
			st.set_normal(b * Vector3(0, 0, 1)); st.add_vertex(b * q[i])
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = st.commit()
	mm.instance_count = MAX
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm
	mmi.material_override = PaperMats.paper(Color.hex(0xdfe8ecff), false)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 400, 2e5))
	add_child(mmi)
	for i in MAX: drops.append({"x": 0.0, "y": -1.0, "z": 0.0, "s": 0.8 + randf() * 0.5, "ground": -1e9, "off": false})

func start(seconds := -1.0, k := "") -> void:
	if target == 1: return
	if seconds < 0.0: seconds = 60.0 + randf() * 60.0
	if k == "": k = next_kind
	target = 1; left = seconds; kind = k
	storm = k == "rain" and next_storm
	if storm: left += 40.0
	if on_start.is_valid(): on_start.call()

func update(dt: float, focus: Vector3, covered = null) -> void:
	if target == 0:
		next -= dt
		if next <= 0.0: start()
	else:
		left -= dt
		if left <= 0.0:
			target = 0; next = 240.0 + randf() * 300.0; next_kind = "snow" if randf() < 0.35 else "rain"; next_storm = next_kind == "rain" and randf() < 0.28
			if on_end.is_valid(): on_end.call()
	rain += (target - rain) * minf(1.0, dt * 0.35)
	if kind == "snow" and target == 1: snow = minf(1.0, snow + dt / 60.0)
	else: snow = maxf(0.0, snow - dt / 150.0)
	if rain < 0.01:
		mm.visible_instance_count = 0
		return
	var n := floori(MAX * minf(1.0, rain * 1.1))
	var snowy := kind == "snow"
	for i in n:
		var d: Dictionary = drops[i]
		d.y -= (1.6 if snowy else FALL) * d.s * dt
		d.x += (sin(d.y * 1.7 + i) * 0.8 if snowy else 1.6) * dt # rain slants with the breeze; flakes drift and sway
		if d.y < d.ground or absf(d.x - focus.x) > BOX / 2.0 or absf(d.z - focus.z) > BOX / 2.0:
			d.x = focus.x + (randf() - 0.5) * BOX
			d.z = focus.z + (randf() - 0.5) * BOX
			d.ground = Terrain.get_height(d.x, d.z)
			d.y = d.ground + randf() * TOP + (0.0 if d.y < 0.0 else 2.0)
			d.off = covered.call(d.x, d.z) if covered is Callable and covered.is_valid() else false
		var b: Basis
		if d.off: b = Basis.from_scale(Vector3.ZERO)
		elif snowy: b = Basis(Vector3.UP, d.y * 2.0 + i) * Basis.from_scale(Vector3(2.6, 0.12, 2.6)) # a little paper square, tumbling
		else: b = Basis(Vector3.BACK, -0.12)
		mm.set_instance_transform(i, Transform3D(b, Vector3(d.x, d.y, d.z)))
	mm.visible_instance_count = n
