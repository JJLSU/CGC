extends SceneTree
## The new Homestead pieces and a run of palisade, built in a row on the farm (<out>).
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.42; main.weather.rain = 0.0; main.weather.target = 0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000: await process_frame
	var B: BuildSystem = main.build
	var h: Vector3 = main.spawn + Vector3(-30, 0, 46)
	var xs := [0.0, 10.0, 22.0, 31.0, 38.0]
	var i := 0
	for t in ["henhouse", "haybarn", "shaft", "well", "leanto"]:
		var x: float = h.x + xs[i]; var z := h.z
		B.make_mesh(t, true).free()
		B.add({"type": t, "x": x, "y": Terrain.get_height(x, z), "z": z, "rot": 0}, true); i += 1
	for k in 6: var x := h.x + k * 2.0 + 1.0; var z := h.z + 9.0; B.add({"type": "palisade", "x": x, "y": Terrain.get_height(x, z), "z": z, "rot": 0}, true)
	main.hud.visible = false; main.post.set_shader_parameter("dof_enabled", 0.0); main.player.avatar.root.visible = false
	main.player.pos = Vector3(h.x + 19.0, Terrain.get_height(h.x + 19.0, h.z + 4.0), h.z + 4.0)
	main.rig.yaw = PI; main.rig.pitch = 0.45; main.rig.dist = 36.0; main.rig.snap()
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2500: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
