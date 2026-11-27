extends SceneTree
## Probe: frames per second standing at a fort's gate, looking at it (windowed).
func _initialize() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45
	var f: Dictionary = main.forts.forts[0]
	var fz := Vector3(sin(f.face), 0, cos(f.face)); var gate: Vector3 = f.at + fz * (ArmyForts.SIDE / 2.0 + 12.0)
	for i in 240: main.player.pos = gate; main.rig.yaw = atan2(fz.x, fz.z); await process_frame
	var t0 := Time.get_ticks_msec(); var n := 0
	while Time.get_ticks_msec() - t0 < 4000: main.player.pos = gate; await process_frame; n += 1
	print("FPS at the fort gate: %.0f" % (n / 4.0))
	quit()
