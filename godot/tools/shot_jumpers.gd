extends SceneTree
## A claim jumpers' camp from above (<out>): the tents, the lean-to shack, the fire and clutter, the men and the women.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.weather.rain = 0.0; main.weather.target = 0; main.sky.time = 0.45
	var c: Dictionary = main.jumpers.camps[3]
	var spot: Vector3 = c.at + Vector3(0, 0, 60)
	main.player.pos = Vector3(spot.x, Terrain.get_height(spot.x, spot.z), spot.z) # (out of their sight, the camp built)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3500: await process_frame
	main.hud.visible = false; main.post.set_shader_parameter("dof_enabled", 0.0); main.player.avatar.root.visible = false
	main.jumpers.process_mode = Node.PROCESS_MODE_DISABLED # (held as they stand, for the picture)
	var cam_at: Vector3 = c.at
	main.player.pos = Vector3(cam_at.x, Terrain.get_height(cam_at.x, cam_at.z), cam_at.z)
	main.rig.yaw = 0.4; main.rig.pitch = 0.62; main.rig.dist = 26.0; main.rig.snap()
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	print("men %d women %d pieces %d" % [c.men.size(), c.women.size(), c.nodes.size()])
	var names := []
	for cp in main.jumpers.camps: for m in cp.men: names.append(m.fig.name)
	print("men in the camps: %s (outlaws: %d)" % [names, names.filter(func(n): return String(n).contains("outlaw")).size()])
	quit()
