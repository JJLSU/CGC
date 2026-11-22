class_name CameraRig
extends Node3D
## player.js's camera, as is: entirely the player's. The mouse sets yaw and pitch (free look, from up at the sky to
## straight down), the wheel sets the distance (2.5 to 42, so the world's edge never shows). It rides on the farmer
## at chest height (an anchor eased in fast, an aim offset eased slowly), and lifts smoothly over hills.
## Zoom limits and the free camera are not to be changed.

var camera: Camera3D
var yaw := 0.35
var pitch := 0.46
var dist := 15.0
var anchor := Vector3.ZERO
var focus_offset := Vector3.ZERO
var cam_lift := 0.0
var target_node: Node3D = null          ## what the camera rides on (the farmer)
var height_at: Callable = func(_x: float, _z: float) -> float: return 0.0   ## terrain height lookup (world.getHeight)
var water_level := 0.0
var active := true

func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 30.0
	camera.near = 0.2
	camera.far = 900.0
	add_child(camera)
	camera.current = true

## The way the camera looks along the ground (for walking).
func forward() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))

func update_camera(dt: float) -> void:
	if not active: yaw += dt * 0.05 # (idle orbit on the title screen)
	var zoom := smoothstep(11.0, 40.0, dist)
	var p := target_node.global_position if target_node else Vector3.ZERO
	var want_anchor := Vector3(p.x, p.y + 0.9, p.z)
	var aim := Vector3(0, lerpf(0.35, 0.1, zoom), 0)
	focus_offset = focus_offset.lerp(aim, 1.0 - exp(-dt * 3.0))
	anchor = anchor.lerp(want_anchor, 1.0 - exp(-dt * 18.0))
	var t := anchor + focus_offset
	var cp := cos(pitch)
	var cam := Vector3(t.x + sin(yaw) * cp * dist, t.y + sin(pitch) * dist, t.z + cos(yaw) * cp * dist)
	var floor_y := maxf(height_at.call(cam.x, cam.z), water_level - 0.2) + 0.5
	var want := maxf(0.0, floor_y - cam.y)
	cam_lift += (want - cam_lift) * (1.0 - exp(-dt * (10.0 if want > cam_lift else 4.0)))
	cam.y += cam_lift
	camera.global_position = cam
	if not cam.is_equal_approx(t): camera.look_at(t, Vector3.UP)

## Snap straight to the target (on load, so the first frame doesn't glide in from the origin).
func snap() -> void:
	var p := target_node.global_position if target_node else Vector3.ZERO
	anchor = Vector3(p.x, p.y + 0.9, p.z)
	update_camera(0.0)
