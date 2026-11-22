class_name FarmExtras
extends Node3D
## The homestead's extras, each baked from the web at the farm centre (assets/baked/homestead/<name>.glb + .json, with
## their moving parts named from the web objects' own fields) and run here as the web runs them:
##  coop.js      the nesting box (eggs each morning, two to four, up to four; laying mash adds two) + the hen house
##  cellar.js    the root cellar: a surveyor's stake ($20) until dug, then the mound with apples and a loaf a day
##  bunkhouse.js the bunkhouse: a stake ($40), then the log house, its windows lit after dark, the supper fire
##  laundry.js   the washing on the line, swinging in the breeze, hanging heavy in the rain
##  weathervane.js the copper rooster on the barn: west wind most days, swinging east ahead of a shower
##  porch.js     the rocking chair: sit and the day drifts by 24 times faster
##  woodpile.js  the logs stacked on your woodpiles; giantpumpkin.js the prize pumpkins on your patches

const CELLAR_COST := 20
const BUNK_COST := 40
const WARP := 24.0
var C := Vector3.ZERO
var parts := {}       ## name -> {root, info}
# coop
var eggs := 3
var laid_day := 1
var extra_eggs := 0
var coop_pos := Vector3.ZERO
var roost_at := Vector3.ZERO
# cellar / bunkhouse
var cellar_built := false
var cellar_day := -1
var cellar_pos := Vector3.ZERO
var bunk_built := false
var bunk_pos := Vector3.ZERO
var bunk_lit := false
var bunk_door := Vector3.ZERO
var fire_at := Vector3.ZERO
var world_ref: World
# laundry / vane / porch
var laundry_t := 0.0
var wet := 0.0
var vane_angle := PI
var vane_vel := 0.0
var vane_t := 0.0
var vane_warned := false
var seat := Vector3.ZERO
var seat_facing := 0.0
var sitting := false
var rock_t := 0.0
# woodpiles / giant pumpkins
var logs_mm: MultiMesh
var logs_sig := ""
var pumpkin_mm: MultiMesh
var pumpkin_sig := ""
var pumpkin_t := 0.0
var grown_at := -9.0

## Registers every extra's exclusions and colliders with the world (before any chunk is built).
func _init(world: World, center: Vector3) -> void:
	world_ref = world
	C = Vector3(center.x, 0, center.z)
	for n in ["coop", "cellar", "bunkhouse", "laundry", "vane", "porch"]:
		var info: Dictionary = JSON.parse_string(FileAccess.open("res://assets/baked/homestead/%s.json" % n, FileAccess.READ).get_as_text())
		for e in info.exclusions: world.exclusions.append({"x": C.x + e.x, "z": C.z + e.z, "r": e.r})
		for e in info.colliders: world.colliders.append({"x": C.x + e.x, "z": C.z + e.z, "r": e.r})
		parts[n] = {"info": info}
	coop_pos = C + _v(parts.coop.info.vecs.pos); roost_at = C + _v(parts.coop.info.vecs.get("roostAt", [0, 0, 0]))
	cellar_pos = C + _v(parts.cellar.info.vecs.pos)
	bunk_pos = C + _v(parts.bunkhouse.info.vecs.pos); bunk_door = C + _v(parts.bunkhouse.info.vecs.door); fire_at = C + _v(parts.bunkhouse.info.vecs.fireAt)
	seat = C + _v(parts.porch.info.vecs.seat); seat_facing = parts.porch.info.vecs.facing

static func _v(a) -> Vector3: return Vector3(a[0], a[1], a[2])

func _ready() -> void:
	position = C
	for n in parts:
		var root := (load("res://assets/baked/homestead/%s.glb" % n) as PackedScene).instantiate() as Node3D
		add_child(root)
		_skin(root)
		for m in parts[n].info.models:
			var scene: PackedScene = load("res://assets/models/props/%s.glb" % m.model)
			if scene == null: continue
			var inst := scene.instantiate()
			PaperMats.paperize(inst)
			var meshes := PaperMats._meshes(inst)
			if meshes.size() > int(m.mesh):
				var src: MeshInstance3D = meshes[int(m.mesh)]
				var mi := MeshInstance3D.new(); mi.mesh = src.mesh; mi.transform = Homestead._m(m.m)
				for s in src.mesh.get_surface_count(): mi.set_surface_override_material(s, src.get_surface_override_material(s))
				add_child(mi)
			inst.free()
		parts[n].root = root
	_show("cellar", "group", false); _show("bunkhouse", "group", false); _show("bunkhouse", "fire", false)
	_refresh_eggs()
	# the woodpiles' logs: bark-brown rounds with printed end grain (one MultiMesh)
	var cyl := CylinderMesh.new(); cyl.top_radius = 0.11; cyl.bottom_radius = 0.12; cyl.height = 0.62; cyl.radial_segments = 10
	logs_mm = MultiMesh.new(); logs_mm.transform_format = MultiMesh.TRANSFORM_3D; logs_mm.use_colors = true; logs_mm.mesh = cyl
	logs_mm.instance_count = 4 * 24; logs_mm.visible_instance_count = 0
	for i in 96: logs_mm.set_instance_color(i, NightSky._hsl(0.08, 0.3, 0.8 + ((i * 37) % 10) / 50.0))
	var lmi := MultiMeshInstance3D.new(); lmi.multimesh = logs_mm; lmi.material_override = PaperMats.paper(Color.hex(0x7a5636ff))
	lmi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 400, 2e5)); lmi.top_level = true
	add_child(lmi)
	# the prize pumpkins: the garden's own crossed pumpkin cards
	var k = PropKinds.get_kind("pumpkin")
	pumpkin_mm = MultiMesh.new(); pumpkin_mm.transform_format = MultiMesh.TRANSFORM_3D; pumpkin_mm.use_colors = true; pumpkin_mm.mesh = k.mesh
	pumpkin_mm.instance_count = 4; pumpkin_mm.visible_instance_count = 0
	for i in 4: pumpkin_mm.set_instance_color(i, Color.WHITE)
	var pmi := MultiMeshInstance3D.new(); pmi.multimesh = pumpkin_mm; pmi.material_override = k.material
	pmi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 400, 2e5)); pmi.top_level = true
	add_child(pmi)

func _skin(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var src := mi.get_active_material(s) as BaseMaterial3D
			if src == null: continue
			var mat: ShaderMaterial = PaperMats.card(src.albedo_texture, {"albedo": src.albedo_color}) if src.albedo_texture else PaperMats.paper(src.albedo_color)
			if src.resource_name.begins_with("glow_window") and src.albedo_texture: mat.set_shader_parameter("night_glow", Vector3(1.0, 0.62, 0.28) * 3.2)
			mi.set_surface_override_material(s, mat)
	for c in n.get_children(): _skin(c)

func node(part: String, nm: String) -> Node3D:
	return (parts[part].root as Node).find_child(nm, true, false) as Node3D
func _show(part: String, nm: String, v: bool) -> void:
	var n := node(part, nm)
	if n: n.visible = v

# ------------------------------------------------------------------ coop
func _refresh_eggs() -> void:
	for i in 4:
		var e := node("coop", "eggMeshes%d" % i)
		if e: e.visible = i < eggs
func coop_near(pos: Vector3, r := 2.4) -> bool: return Vector2(pos.x - coop_pos.x, pos.z - coop_pos.z).length() < r and absf(pos.y - coop_pos.y) < 1.5
## Each morning (from 06:00) the hens lay two to four eggs, up to four; a scoop of laying mash and two more.
func coop_update(day: int, time: float, inv: Dictionary) -> void:
	if day != laid_day and time >= 0.25 and time < 0.8:
		laid_day = day
		if inv.get("mash", 0) > 0: inv.mash -= 1; extra_eggs += 2
		eggs = mini(4, eggs + 2 + randi() % 3)
		_refresh_eggs()
func coop_collect() -> int:
	var n := eggs + extra_eggs; eggs = 0; extra_eggs = 0; _refresh_eggs(); return n

# ------------------------------------------------------------------ cellar, bunkhouse
func cellar_near(pos: Vector3, r := 2.4) -> bool: return Vector2(pos.x - cellar_pos.x, pos.z - cellar_pos.z).length() < r
func cellar_stocked(day: int) -> bool: return cellar_built and cellar_day != day
func build_cellar() -> void:
	if cellar_built: return
	cellar_built = true; _show("cellar", "stake", false); _show("cellar", "group", true)
	world_ref.colliders.append({"x": cellar_pos.x, "z": cellar_pos.z, "r": 1.3})
## bunkhouse.js: where hired hand i beds down (in rows before the door), and the log seat i round the supper fire.
func bunk_face() -> float: return atan2(C.x - bunk_pos.x, C.z - bunk_pos.z) # (the door toward the farmyard)
func home_for(i: int) -> Vector3: return bunk_pos + Vector3(-2.0 + (i % 4) * 1.35, 0, 4.4 + floori(i / 4.0) * 1.3).rotated(Vector3.UP, bunk_face())
func fire_spot(i: int) -> Vector3:
	var a := (i % 4) / 4.0 * TAU + 0.4 + floori(i / 4.0) * 0.35
	return Vector3(fire_at.x + cos(a) * 1.4, 0, fire_at.z + sin(a) * 1.4)
func bunk_near(pos: Vector3, r := 2.6) -> bool: return Vector2(pos.x - bunk_pos.x, pos.z - bunk_pos.z).length() < r
func build_bunk() -> void:
	if bunk_built: return
	bunk_built = true; _show("bunkhouse", "stake", false); _show("bunkhouse", "group", true)
	var g := node("bunkhouse", "group")
	for d in [-2.0, 0.0, 2.0]:
		var p := Vector3(d, 0, 0).rotated(Vector3.UP, g.rotation.y) + bunk_pos
		world_ref.colliders.append({"x": p.x, "z": p.z, "r": 2.0})
## The fire is laid once the bunkhouse stands; the flames are lit only while supper is on.
func bunk_supper(on: bool) -> void:
	if not bunk_built: return
	_show("bunkhouse", "fire", true); _show("bunkhouse", "flame", on)
func bunk_update(night: float) -> void:
	if not bunk_built: return
	var on := night > 0.45
	if on == bunk_lit: return
	bunk_lit = on
	var i := 0
	while true:
		var p := node("bunkhouse", "panes%d" % i)
		if p == null: break
		for mi in PaperMats._meshes(p):
			(mi as MeshInstance3D).set_surface_override_material(0, PaperMats.paper(Color.hex((0xffb860 if on else 0x3e4a50) << 8 | 0xff)))
		i += 1

# ------------------------------------------------------------------ laundry, weathervane, porch
## The washing swings on the line with the wind; rain soaks it so it hangs heavy and nearly still.
func laundry_update(dt: float, player_pos: Vector3, rain: float) -> void:
	var g := node("laundry", "group")
	var gp := g.global_position
	var far := Vector2(player_pos.x - gp.x - 2.4, player_pos.z - gp.z).length() > 70.0
	g.visible = not far
	if far: return
	laundry_t += dt
	wet += ((1.0 if rain > 0.2 else 0.0) - wet) * minf(1.0, dt * (0.25 if rain > 0.2 else 0.04))
	var t := laundry_t
	var gust := 0.65 + 0.25 * sin(t * 0.21) + 0.2 * sin(t * 0.57 + 1.3)
	var amp := (0.06 + 0.16 * gust) * (1.0 - wet * 0.8)
	for i in 6:
		var piv := node("laundry", "items%d" % i)
		if piv == null: continue
		var ph := i * 1.7
		var heavy := 0.75 if i == 2 else 1.0 # (the quilt: the one with the long outline hangs heavier)
		var s := sin(t * 1.1 + ph) + 0.35 * sin(t * 2.7 + ph * 2.0)
		piv.rotation.x = -amp * heavy * (0.6 + 0.4 * s) - 0.03
		piv.rotation.y = 0.05 * sin(t * 0.7 + ph) * (1.0 - wet)

## The rooster: west wind most days; swings round east about 45 s before a shower. Returns the coming kind once.
func vane_update(dt: float, weather: Weather) -> String:
	vane_t += dt
	var t := vane_t
	var coming := weather.target == 0 and weather.next < 45.0
	var goal := 0.15 * sin(t * 0.13) if (coming or weather.target == 1) else PI + 0.35 * sin(t * 0.021) + 0.12 * sin(t * 0.17)
	var d := goal - vane_angle; d = atan2(sin(d), cos(d))
	vane_vel += (d * 2.2 - vane_vel * 1.6) * dt
	vane_vel += sin(t * 2.3) * sin(t * 0.7) * 0.25 * dt
	vane_angle += vane_vel * dt
	var turn := node("vane", "turn")
	if turn: turn.rotation.y = vane_angle
	var said := ""
	if coming and not vane_warned: vane_warned = true; said = weather.next_kind
	if not coming and weather.target == 0: vane_warned = false
	return said

func porch_near(pos: Vector3) -> bool: return Vector2(pos.x - seat.x, pos.z - seat.z).length() < 1.6
## While sitting: the chair rocks and the farmer sits in it (his sit clip), time running WARP times faster.
func porch_update(dt: float, player: Player) -> void:
	rock_t += dt
	var g := node("porch", "group")
	var rock := sin(rock_t * 1.6) * 0.09 if sitting else g.rotation.x * 0.9
	g.rotation_order = EULER_ORDER_YXZ
	g.rotation = Vector3(rock, seat_facing, 0)
	if not sitting: return
	player.pos = seat; player.vel = Vector3.ZERO; player.facing = seat_facing
	var a := player.avatar
	a.root.position = seat - Vector3(0, 0.32, 0)
	a.root.rotation_order = EULER_ORDER_YXZ
	a.root.rotation = Vector3(rock * 0.8, seat_facing, 0)

# ------------------------------------------------------------------ woodpiles and giant pumpkins
func piles_update(pieces: Array, center: Vector3) -> void:
	var piles := []
	for p in pieces: if p.type == "woodpile": piles.append(p)
	piles.sort_custom(func(a, b): return Vector2(a.x - center.x, a.z - center.z).length_squared() < Vector2(b.x - center.x, b.z - center.z).length_squared())
	piles = piles.slice(0, 4)
	var sig := ""
	for p in piles: sig += "%.1f,%.1f,%d,%d,%d|" % [p.x, p.z, p.rot, p.stock if p.stock != null else 0, 1 if p.risen else 0]
	if sig == logs_sig: return
	logs_sig = sig
	var n := 0
	for p in piles:
		if not p.risen: continue
		var stock: int = mini(24, p.stock if p.stock != null else 0)
		var a: float = p.rot * PI / 2.0; var cs := cos(a); var sn := sin(a)
		for k in stock:
			var row := k / 6; var col := k % 6
			var lz := (col - 2.5) * 0.23 + (row % 2) * 0.11 - 0.05; var ly := 0.13 + row * 0.2
			var pos := Vector3(p.x + lz * sn, p.y + ly, p.z + lz * cs)
			var b := Basis(Vector3.UP, a + ((k * 13) % 7 - 3) * 0.02) * Basis(Vector3.BACK, PI / 2.0) # (a log lying along x)
			logs_mm.set_instance_transform(n, Transform3D(b, pos)); n += 1
	logs_mm.visible_instance_count = n

const SIZE := [0.5, 0.9, 1.4, 2.0, 2.7, 3.4]
func pumpkins_update(dt: float, pieces: Array, center: Vector3) -> void:
	pumpkin_t += dt
	var patches := []
	for p in pieces: if p.type == "patch" and p.risen: patches.append(p)
	patches.sort_custom(func(a, b): return Vector2(a.x - center.x, a.z - center.z).length_squared() < Vector2(b.x - center.x, b.z - center.z).length_squared())
	patches = patches.slice(0, 4)
	var sig := ""
	for p in patches: sig += "%.1f,%.1f,%d|" % [p.x, p.z, p.stage if p.stage != null else 0]
	if sig != pumpkin_sig: pumpkin_sig = sig; grown_at = pumpkin_t
	var k := minf(1.0, (pumpkin_t - grown_at) / 0.9); var pop := 1.0 + sin(k * PI) * 0.08 * (1.0 - k)
	var n := 0
	for p in patches:
		var s: float = SIZE[mini(5, p.stage if p.stage != null else 0)] * pop
		pumpkin_mm.set_instance_transform(n, Transform3D(Basis(Vector3.UP, p.rot * PI / 2.0 + 0.4) * Basis.from_scale(Vector3(s, s * 0.92, s)), Vector3(p.x, p.y + 0.05, p.z)))
		n += 1
	pumpkin_mm.visible_instance_count = n
