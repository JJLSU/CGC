extends SceneTree
## The farmer at a sprint (the borrowed run clip), side on: <out>_<n>.png, a few frames apart.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.weather.rain = 0.0; main.weather.target = 0; main.sky.time = 0.45
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000: await process_frame
	main.hud.visible = false; main.post.set_shader_parameter("dof_enabled", 0.0)
	var inp: GameInput = main.input
	inp.keys["KeyW"] = true; inp.keys["ShiftLeft"] = true
	for n in 4:
		for i in 9: await process_frame
		main.rig.yaw = main.player.facing + 1.5708; main.rig.pitch = 0.1; main.rig.dist = 4.0; main.rig.snap()
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_%d.png" % n))
	quit()
