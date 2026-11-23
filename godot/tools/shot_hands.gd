extends SceneTree
## Close-ups of the farmer: each tool in hand (<out>_<tool>.png) and sitting in the rocker from the side and the front
## (<out>_sit_side.png, <out>_sit_front.png).

func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000.0: await process_frame

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.weather.rain = 0.0; main.weather.target = 0; main.sky.time = 0.45
	await _wait(3.0)
	main.post.set_shader_parameter("dof_enabled", 0.0)
	main.hud.visible = false
	var p: Player = main.player
	for t in ["axe", "pickaxe", "hammer", "spear", "rod", "bow", "revolver", "rifle"]: main.tools[t] = true
	p.pos = main.spawn + Vector3(6, 0, 8); p.pos.y = Terrain.get_height(p.pos.x, p.pos.z); p.facing = 0.0
	for t in ["axe", "pick", "hammer", "spear", "rod", "bow", "revolver", "rifle"]:
		main.pick_tool("pickaxe" if t == "pick" else t)
		main.rig.yaw = p.facing - 0.9; main.rig.pitch = 0.1; main.rig.dist = 2.2; main.rig.snap()
		await _wait(0.8)
		await _shot(out.replace(".png", "_%s.png" % t))
	main.pick_tool("hands")
	# the rocker
	main.extras.sitting = true
	await _wait(1.5)
	for v in [["side", 1.5708], ["front", 0.0]]:
		main.rig.yaw = main.extras.seat_facing + v[1]; main.rig.pitch = 0.15; main.rig.dist = 3.4; main.rig.snap()
		await _wait(0.6)
		await _shot(out.replace(".png", "_sit_%s.png" % v[0]))
	quit()
