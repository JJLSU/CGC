extends SceneTree
## Every town building's front from across the street (<dir>/<id>.png), the whole town mended. Windowed; a throwaway save.
func _initialize() -> void:
	var dir: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp != "" and not sp.contains("paperfjord.builds") and FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45; main.weather.rain = 0.0
	var T: Town = main.town
	for b in main.bosses: b.delivered = true
	for b in Town.BUILDINGS: T.mend(b.id)
	T.mend("church")
	for st in Town.STREETS: for b in st.buildings: T.mend(b.id)
	var ids := []
	for b in Town.BUILDINGS: ids.append(b.id)
	for st in Town.STREETS: for b in st.buildings: ids.append(b.id)
	main.player.avatar.root.visible = false
	for id in ids:
		var d: Vector3 = T.doors[id]; var b := Town.find_b(id)
		var c: Vector3 = T.parts[id].global_position if T.parts.has(id) else d
		var out: Vector3 = Vector3(d.x - c.x, 0, d.z - c.z).normalized() # (from the building's middle out through its door)
		var st: Vector3 = d + out * 1.0
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 1500:
			main.player.pos = Vector3(st.x, Terrain.get_height(st.x, st.z), st.z)
			main.rig.yaw = atan2(out.x, out.z); main.rig.pitch = 0.42; main.rig.dist = 10.0
			await process_frame
		# (then the game held still and the camera set by hand: square on, from across the street, the upper front in view)
		main.set_process(false)
		var cam: Camera3D = main.rig.camera
		var eye: Vector3 = d + out * 8.5; eye.y = T.y0 + 3.0
		var look: Vector3 = d - out * 1.0; look.y = T.y0 + 3.4
		cam.global_position = eye; cam.look_at(look, Vector3.UP); cam.fov = 50.0
		await process_frame; await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_viewport().get_texture().get_image(); img.resize(800, 450)
		cam.fov = 30.0; main.set_process(true)
		img.save_png(dir + "/" + id + ".png")
	quit()
