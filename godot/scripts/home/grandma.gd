class_name Grandma
extends Node3D
## grandma.js: Grandma Pell in the window. Of an evening, once the lamps are lit (18:30 till 22:30), the lamplit
## front window shows her shadow: a cut-paper silhouette in her rocking chair, hair in a bun, knitting, rocking
## slowly. Knock at the front door (E) of an evening and she hands out a warm slice of pie, once a night, with a
## word; bring what she's after today and she bakes you something in return.

const PIE_WORDS := [
	"\"There you are! Take this before it goes cold, and wipe your boots.\"",
	"\"I made two, and your grandfather never could finish one. Go on.\"",
	"\"Pumpkin, with a little nutmeg. Don't tell the Grange ladies my secret.\"",
	"\"You work too hard. Sit on the porch a spell and eat that slowly.\"",
]
## What Grandma's after today (one a day, picked by the calendar), and what she bakes you for it.
const WISHES := [
	{"cost": {"egg": 4}, "gives": {"honeycake": 1, "pie": 1}, "ask": "four eggs for a custard", "thanks": "Four lovely brown eggs! Here, a honey cake and a pie for your trouble."},
	{"cost": {"milk": 2}, "gives": {"biscuits": 3}, "ask": "two pails of milk to churn some butter", "thanks": "Fresh from Daisy! Take these biscuits, still warm, with the first of the butter."},
	{"cost": {"wool": 3}, "gives": {"pie": 2, "rope": 1}, "ask": "three fleeces of wool to knit you a muffler", "thanks": "Soft as a cloud. I will have it knitted by first frost. Two pies, and your grandfather’s old rope."},
	{"cost": {"apples": 6}, "gives": {"applecrisp": 2}, "ask": "six good apples for apple butter", "thanks": "These will make a crock of apple butter fit for a fair. Two apple crisps, and mind you share."},
	{"cost": {"honey": 2}, "gives": {"pie": 2, "egg": 2}, "ask": "two jars of honey for her tea", "thanks": "Clover honey! My tea thanks you. Two pies and a couple of eggs."},
	{"cost": {"wheat": 4}, "gives": {"bread": 2, "honeycake": 1}, "ask": "four sheaves of wheat for the flour bin", "thanks": "I will grind it Saturday. Two loaves and a honey cake now, and more to come."},
	{"cost": {"fish": 2}, "gives": {"fishfry": 2, "pie": 1}, "ask": "two fish for a Friday supper", "thanks": "Trout! I will fry these up with cornmeal. Here is yours already, and a pie besides."},
]
## (day * 2654435761) >>> 0, as the web's uint32 hash.
static func wish_for(day: int) -> Dictionary: return WISHES[((day * 2654435761) & 0xffffffff) % WISHES.size()]

var door: Vector3
var pivot := Node3D.new()
var t := 0.0
var pie_day := -1
var wish_day := -1

func _init(window: Vector3, facing: float, door_at: Vector3) -> void:
	door = door_at
	position = window; rotation.y = facing
	var m := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(0.82, 0.82); m.mesh = q; m.position.y = 0.41
	var mat := StandardMaterial3D.new(); mat.albedo_texture = load("res://assets/baked/homestead/grandma.png")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR; mat.alpha_scissor_threshold = 0.5
	m.material_override = mat; m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(m); add_child(pivot)
	pivot.visible = false

func home(sky: DaySky) -> bool: return sky.time > 0.77 and sky.time < 0.94 # (18:30 to 22:30)
func at_door(p: Vector3, r := 1.3) -> bool: return Vector2(p.x - door.x, p.z - door.z).length() < r

func update(dt: float, sky: DaySky) -> void:
	t += dt
	pivot.visible = home(sky)
	if not pivot.visible: return
	# rocking on the chair's runners, and a nod now and then over the knitting
	pivot.rotation.z = sin(t * 1.4) * 0.06
	pivot.position.y = absf(sin(t * 1.4)) * 0.01
