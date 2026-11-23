extends SceneTree
## The play view, with what lies beyond the focus blurred at each far_gain (<out>_<gain>.png): for the distance blur.
func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000.0: await process_frame
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.weather.rain = 0.0; main.weather.target = 0; main.sky.time = 0.45
	var p: Player = main.player
	p.pos = main.spawn + Vector3(2, 0, -10); p.pos.y = Terrain.get_height(p.pos.x, p.pos.z)
	main.rig.yaw = 0.9; main.rig.pitch = 0.3; main.rig.dist = 18.0; main.rig.snap()
	await _wait(3.0)
	main.hud.visible = false
	for g in [1.0, 0.5, 0.3]:
		main.post.set_shader_parameter("far_gain", g)
		await _wait(0.4)
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_%s.png" % str(g)))
	quit()
