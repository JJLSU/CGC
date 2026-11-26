extends SceneTree
## Three figures at the work swing with their trade's tool (<out>): a hammer, an axe, a pickaxe. Windowed; a throwaway save.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp != "" and not sp.contains("paperfjord.builds") and FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45; main.weather.rain = 0.0
	var base: Vector3 = main.spawn + Vector3(6, 0, 9)
	main.player.pos = base
	var figs := []
	for e in [["folk_amos", "hammer"], ["folk_silas", "axe"], ["prospectors_1", "pick"]]:
		var f := ModelFigure.new(e[0]); f.work_tool = e[1]; main.add_child(f.root); figs.append(f)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000:
		main.player.pos = base; main.rig.yaw = 0.3; main.rig.pitch = 0.15; main.rig.dist = 7.0
		var cam: Vector3 = main.rig.camera.global_position; var to := Vector3(cam.x - base.x, 0, cam.z - base.z).normalized(); var across := Vector3(-to.z, 0, to.x)
		for i in figs.size():
			var q: Vector3 = base + to * 2.5 + across * (i - 1) * 1.6
			figs[i].root.position = Vector3(q.x, Terrain.get_height(q.x, q.z), q.z); figs[i].root.rotation.y = atan2(across.x, across.z)
			figs[i].update(0.016, 0.0, "work")
		await process_frame
	main.player.avatar.root.visible = false
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
