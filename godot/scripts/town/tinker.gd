class_name Tinker
extends Node3D
## tinker.js: the travelling tinker. Every other day, from breakfast to late afternoon, his covered wagon stands at
## the head of Main Street with the tinker beside it in his long coat and stovepipe; E by it trades surplus for
## sundries (the crafting panel's "Tinker's wagon"). The wagon hinges up off the page when he arrives and folds
## flat when he leaves.

var pos: Vector3
var hinge := Node3D.new()
var man: ModelFigure
var here := false
var t := 0.0
var on_arrive: Callable
var on_leave: Callable

func _init(world: World, spot: Dictionary) -> void:
	var x: float = spot.x; var z: float = spot.z; var look: Vector3 = spot.look
	pos = Vector3(x, Terrain.get_height(x, z), z)
	world.exclusions.append({"x": x, "z": z, "r": 4.8})
	world.colliders.append({"x": x, "z": z, "r": 1.7})
	position = pos; rotation.y = atan2(look.x - x, look.z - z) # (broadside, and the tinker, toward the street)
	add_child(hinge)
	# the covered wagon from the reference art, his painted TINKER & SUNDRIES board hung along the near side
	var scene: PackedScene = load("res://assets/models/props/veh_covered_wagon.glb")
	var m := scene.instantiate() as Node3D
	PaperMats.paperize(m, true)
	var bb := PaperMats._aabb(m, Transform3D.IDENTITY)
	var k := 5.2 / bb.size.x
	m.position = Vector3(-(bb.position.x + bb.size.x * 0.5), -bb.position.y, -(bb.position.z + bb.size.z * 0.5))
	var hold := Node3D.new(); hold.add_child(m); hold.scale = Vector3.ONE * k; hold.rotation.y = PI; hinge.add_child(hold)
	var board := Town.board(2.3, 0.62, "res://assets/baked/homestead/tinker_board", 0.05)
	board.position = Vector3(0, 1.3 - 0.31, bb.size.z * k * 0.36); hinge.add_child(board)
	# the tinker himself
	man = ModelFigure.new("folk_tinker")
	man.root.position = Vector3(-0.6, 0, 1.75); man.root.rotation.y = 0.3
	hinge.add_child(man.root)
	visible = false

## Is he visiting at this time of day? Every second day, 07:00-18:00.
func visiting(sky: DaySky) -> bool: return sky.day % 2 == 0 and sky.time > 0.29 and sky.time < 0.75

func near(p: Vector3, r := 5.0) -> bool: return here and Vector2(p.x - pos.x, p.z - pos.z).length() < r

func update(dt: float, sky: DaySky) -> void:
	var want := visiting(sky)
	if want != here:
		here = want; t = 0.0
		if want:
			visible = true
			if on_arrive.is_valid(): on_arrive.call()
		elif on_leave.is_valid(): on_leave.call()
	t += dt
	if not visible: return
	man.update(dt, 0.0)
	# hinge up with a springy overshoot on arrival, fold back flat when he moves on
	var k: float = Props.spring_rise(t) if here else 1.0 - minf(1.0, pow(t / 0.6, 2))
	hinge.rotation.x = -(1.0 - k) * (PI / 2)
	if not here and t > 0.6: visible = false
