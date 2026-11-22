class_name FallingStars
extends Node3D
## fallingstar.js: now and then on a clear night a paper star breaks loose and streaks down trailing a gold paper
## ribbon, and comes to rest in a meadow 22-40 m off, standing up from the grass and glowing (a warm point light).
## update() returns the direction it fell ("north-east"...) for the note; take() when you pick it up (E, with the
## gifts in STAR_GIFTS: the interaction lives with the gathering step). Unfound stars fade at first light.

const DIRS := ["east", "north-east", "north", "north-west", "west", "south-west", "south", "south-east"]
const STAR_GIFTS := [[{"honey": 2}, "a jar of honey that tastes faintly of summer"], [{"iron": 2}, "two bars of star-iron, still warm"],
	[{"rope": 2, "wool": 2}, "a skein of silver-grey wool and two coils of rope"], [{"fish": 2, "egg": 2}, "a breakfast: two trout and two eggs, somehow"],
	[{"apples": 4, "berries": 4}, "a pocketful of apples and berries"], [{"honeycake": 1}, "a honey cake, wrapped in a scrap of sky"]]
var star: MeshInstance3D
var tail: MeshInstance3D
var light: OmniLight3D
var mat: ShaderMaterial
var state := "none"
var next := 70.0 + randf() * 90.0
var t := 0.0
var at := Vector3.ZERO
var from := Vector3.ZERO
var to := Vector3.ZERO

func _ready() -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := PI / 2.0 + (k * PI) / 5.0; var r := 0.42 if k % 2 else 1.0
		pts.append(Vector2(cos(a) * r, 0.95 + sin(a) * r))
	mat = ShaderMaterial.new(); mat.shader = preload("res://shaders/glow_card.gdshader")
	mat.set_shader_parameter("map", load("res://assets/baked/sky/fallingstar.png")); mat.set_shader_parameter("glow", 1.6)
	star = MeshInstance3D.new(); star.mesh = CardMesh.build(pts, 0.05); star.material_override = mat
	star.visible = false; star.extra_cull_margin = 200.0; star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(star)
	var qm := QuadMesh.new(); qm.size = Vector2(1, 1); qm.center_offset = Vector3(0.5, 0, 0)
	var tm := StandardMaterial3D.new(); tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.albedo_color = Color(Color.hex(0xf0c868ff), 0.85); tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.cull_mode = BaseMaterial3D.CULL_DISABLED; tm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	tail = MeshInstance3D.new(); tail.mesh = qm; tail.material_override = tm; tail.visible = false; tail.extra_cull_margin = 200.0
	add_child(tail)
	light = OmniLight3D.new(); light.light_color = Color.hex(0xffd890ff).srgb_to_linear(); light.light_energy = 0.0; light.omni_range = 9.0; light.omni_attenuation = 1.4
	add_child(light)

func near(pos: Vector3, r := 1.8) -> bool: return state == "landed" and t > 0.6 and Vector2(pos.x - at.x, pos.z - at.z).length() < r

func launch(player_pos: Vector3) -> String:
	for tries in 12:
		var a := randf() * PI * 2.0; var d := 22.0 + randf() * 18.0
		var x := player_pos.x + cos(a) * d; var z := player_pos.z + sin(a) * d
		if Terrain.is_water(x, z): continue
		at = Vector3(x, Terrain.get_height(x, z), z)
		from = Vector3(x - cos(a) * 60.0, at.y + 70.0, z - sin(a) * 60.0)
		to = at
		state = "falling"; t = 0.0
		var ang := atan2(-(z - player_pos.z), x - player_pos.x) # (north is -z)
		return DIRS[posmod(roundi(ang / (PI / 4.0)), 8)]
	return ""

func take() -> void:
	state = "none"; star.visible = false; light.light_energy = 0.0; next = 120.0 + randf() * 150.0

## Returns the direction word the moment a star falls, else "".
func update(dt: float, player_pos: Vector3, camera: Camera3D, night: float, rain: float) -> String:
	t += dt
	var fell := ""
	if state == "none":
		if night > 0.75 and rain < 0.1:
			next -= dt
			if next <= 0.0: fell = launch(player_pos)
		if fell == "" and next <= 0.0: next = 30.0
	elif state == "falling":
		var k := minf(1.0, t / 1.8)
		var e := k * k
		star.visible = true; tail.visible = true
		star.position = from.lerp(to, e)
		star.look_at(camera.global_position, Vector3.UP, true)
		star.rotate_object_local(Vector3.BACK, sin(t * 7.0) * 0.3)
		star.scale = Vector3.ONE * 1.4
		var head := star.position + Vector3(0, 0.95 * 1.4, 0)
		var xa := (from - head).normalized()
		var to_cam := (camera.global_position - head).normalized()
		var za := (to_cam - xa * to_cam.dot(xa)).normalized()
		var ya := za.cross(xa)
		var length := 6.0 + k * 10.0
		tail.transform = Transform3D(Basis(xa, ya, za) * Basis.from_scale(Vector3(length, 0.35, 1)), head)
		light.position = star.position; light.light_energy = 3.0 / PI
		if k >= 1.0: state = "landed"; t = 0.0; tail.visible = false
	elif state == "landed":
		var rise := Props.spring_rise(t * 1.4)
		star.position = at
		star.rotation = Vector3(-(1.0 - rise) * PI / 2.0, t * 0.6, 0)
		star.scale = Vector3.ONE * 0.55
		mat.set_shader_parameter("glow", 1.3 + sin(t * 3.0) * 0.25)
		light.position = at + Vector3(0, 0.8, 0)
		light.light_energy = (2.2 + sin(t * 3.0) * 0.4) / PI
		if night < 0.2: take()
	return fell
