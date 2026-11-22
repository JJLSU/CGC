class_name BarnDance
extends Node3D
## barndance.js: twice a week (the night of the County Fair, every seventh day, and a midweek dance three days after
## it) from half past five in the evening till three in the morning, the county dances in the street before the livery
## barn: a string of paper lanterns between two poles, the fiddler on a hay bale, three couples (the farmhands and the
## calico women) whirling round the floor. Stand by the floor and press E to join in. The reel is heard only near.

const DANCE_FROM := 17.5 / 24.0
const DANCE_TILL := 3.0 / 24.0
const REEL := [62, 66, 69, 66, 62, 66, 69, 74, 73, 69, 71, 73, 74, 69, 66, 69, 67, 71, 74, 71, 67, 71, 74, 76, 74, 73, 71, 69, 66, 64, 62, 62]

var at := Vector3.ZERO
var hinge := Node3D.new()
var couples: Array = []
var fiddler: ModelFigure
var lantern_mats: Array = []
var light := OmniLight3D.new()
var up := 0.0
var t := 0.0
var shown := false
var beat := 0.0
var note := 0
var on_note: Callable

static func is_dance_night(day: int) -> bool: return day % 7 == 0 or day % 7 == 3
## The day number of the dance night under way at this hour (after midnight, it's still last night's).
static func dance_night_of(day: int, time: float) -> int: return day - 1 if time < DANCE_TILL else day
static func hz(m: float) -> float: return 440.0 * pow(2.0, (m - 69.0) / 12.0)

## spot: {x, z, look} (the town's street before the livery barn).
func _init(spot: Dictionary) -> void:
	at = Vector3(spot.x, 0, spot.z); at.y = Terrain.get_height(at.x, at.z)
	position = at; rotation.y = atan2(spot.look.x - spot.x, spot.look.z - spot.z)
	add_child(hinge)
	for i in 3: # the three farmhands and three calico women from the reference art
		var pair := Node3D.new()
		var man := ModelFigure.new("folk_farmhand_0%d" % (i + 1)); var wom := ModelFigure.new("folk_calico_0%d" % (i + 1))
		man.root.position.x = -0.3; wom.root.position.x = 0.3; man.root.rotation.y = PI / 2.0; wom.root.rotation.y = -PI / 2.0
		pair.add_child(man.root); pair.add_child(wom.root); hinge.add_child(pair)
		couples.append({"pair": pair, "man": man, "wom": wom, "ph": (i / 3.0) * TAU})
	# the fiddler on a hay bale
	var cm := CylinderMesh.new(); cm.top_radius = 0.45; cm.bottom_radius = 0.45; cm.height = 0.8; cm.radial_segments = 12; cm.rings = 1
	var bale := MeshInstance3D.new(); bale.mesh = cm; bale.material_override = PaperMats.paper(Color.hex(0xd2b064ff)); bale.rotation.z = PI / 2.0; bale.position = Vector3(-2.8, 0.45, -1.2); hinge.add_child(bale)
	fiddler = ModelFigure.new("folk_fiddler"); fiddler.root.position = Vector3(-2.8, 0.42, -1.05); hinge.add_child(fiddler.root)
	# poles and a string of glowing paper lanterns
	for x in [-3.2, 3.2]:
		var b := BoxMesh.new(); b.size = Vector3(0.08, 3.0, 0.08)
		var pm := MeshInstance3D.new(); pm.mesh = b; pm.material_override = PaperMats.paper(Color.hex(0x6b4a30ff)); pm.position = Vector3(x, 1.5, 1.6); hinge.add_child(pm)
	var lg := CylinderMesh.new(); lg.top_radius = 0.13; lg.bottom_radius = 0.13; lg.height = 0.24; lg.radial_segments = 8; lg.rings = 1
	var k := 0
	for col in [0xe07a3a, 0xe8c050, 0xc4574a]:
		var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.albedo_color = Color.hex((col << 8) | 0xff).srgb_to_linear()
		m.set_meta("base", m.albedo_color); lantern_mats.append(m)
		var i := k
		while i < 15:
			var u := i / 14.0
			var lm := MeshInstance3D.new(); lm.mesh = lg; lm.material_override = m; lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			lm.position = Vector3(-3.2 + u * 6.4, 2.8 - sin(u * PI) * 0.6, 1.6 - sin(u * PI) * 1.2); hinge.add_child(lm)
			i += 3
		k += 1
	# the lanterns' warm light on the dancers
	light.light_color = Color.hex(0xffb070ff).srgb_to_linear(); light.omni_range = 10.0; light.omni_attenuation = 1.0; light.light_energy = 0.0; light.position = Vector3(0, 2.4, 0.8); add_child(light)
	visible = false

func live(day: int, time: float) -> bool: return is_dance_night(dance_night_of(day, time)) and (time >= DANCE_FROM or time < DANCE_TILL)
func near(pos: Vector3, r := 3.6) -> bool: return shown and up > 0.9 and Vector2(pos.x - at.x, pos.z - at.z).length() < r

func update(dt: float, day: int, time: float, night: float, player: Player) -> void:
	t += dt
	var want := live(day, time)
	if want and not shown: shown = true; up = 0.0; visible = true
	if not shown: return
	up = minf(1.5, up + dt * 0.8) if want else up - dt * 1.2
	var k := Props.spring_rise(up) if want else maxf(0.0, up) ** 2
	hinge.rotation.x = -(1.0 - k) * (PI / 2.0) # (the whole floor folds up off the page, and down again at the end)
	if not want and up <= 0.0: shown = false; visible = false; light.light_energy = 0.0; return
	var glow := minf(1.0, night * 1.4)
	for m in lantern_mats: m.albedo_color = (m.get_meta("base") as Color) * (glow * 1.6 + 0.5)
	light.light_energy = 4.5 * glow * k / PI
	# the couples whirl round the floor, each pair spinning on its own as it goes
	for c in couples:
		var a: float = t * 0.55 + c.ph
		c.pair.position = Vector3(cos(a) * 1.4, absf(sin(t * 4.4 + c.ph)) * 0.06, sin(a) * 1.0 + 0.2)
		c.pair.rotation.y = t * 2.2 + c.ph
		c.man.update(dt, 1.2, "dance"); c.wom.update(dt, 1.2, "dance")
	fiddler.update(dt, 0.0, "sit")
	# the reel, an eighth note every 0.17 s, heard only near the floor
	var d := Vector2(player.pos.x - at.x, player.pos.z - at.z).length()
	if want and d < 28.0:
		beat -= dt
		if beat <= 0.0:
			beat += 0.17
			var m: int = REEL[note % REEL.size()]; note += 1
			if on_note.is_valid(): on_note.call(hz(m), 0.2, maxf(0.0, 1.0 - d / 28.0))
