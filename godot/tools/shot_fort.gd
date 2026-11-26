extends SceneTree
## A look at the first army fort: from outside the gate (<out>) and from above (<out>_top). Windowed; CGC_SAVE_PATH a throwaway.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp != "" and not sp.contains("paperfjord.builds") and FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.42; main.weather.rain = 0.0
	var F: ArmyForts = main.forts; var f: Dictionary = F.forts[0]
	print("%d forts: %s" % [F.forts.size(), F.forts.map(func(q): return "%s at %s" % [q.name, Vector2(q.at.x, q.at.z).round()])])
	var fz := Vector3(sin(f.face), 0, cos(f.face))
	for k in [["", 26.0, 0.25, 30.0], ["_top", 2.0, 1.0, 60.0], ["_gate", 21.0, 0.15, 7.0]]:
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < (6000 if k[0] == "" else 2500):
			var st: Vector3 = f.at + fz * k[1]
			main.player.pos = Vector3(st.x, Terrain.get_height(st.x, st.z), st.z); main.rig.yaw = f.face + 0.25; main.rig.pitch = k[2]; main.rig.dist = k[3]
			await process_frame
		print("men at the fort: %d" % f.men.size())
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", k[0] + ".png"))
	# the officer, up close, his prompt showing (<out>_officer)
	var off = f.men.filter(func(q): return q.role == "officer")[0]
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 2500:
		var op: Vector3 = off.fig.root.position + fz * 2.2
		main.player.pos = Vector3(op.x, Terrain.get_height(op.x, op.z), op.z); main.rig.yaw = f.face + 0.6; main.rig.pitch = 0.2; main.rig.dist = 6.0
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_officer.png"))
	quit()
