extends SceneTree
## The bosses' trophies over the assay office (every boss's prize home, Cole's too) (<out>), and the wanted board with
## Cole's poster up when he's known and abroad (<out>_board.png). Windowed; a throwaway save.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.42; main.weather.rain = 0.0
	main._dev_town()
	var T: Town = main.town; var b := Town.find_b("assay"); var outw: Vector3 = -T.toward * float(b.side)
	var d: Vector3 = T.doors.assay
	for i in 120: main.player.pos = d + outw * 6.0; await process_frame
	print("Cole known %s, board %s" % [main._boss_known(main.bosses[3]), main.boss_board != null])
	main.set_process(false); main.player.avatar.root.visible = false
	var cam: Camera3D = main.rig.camera
	cam.global_position = d + outw * 9.0 + Vector3(0, T.y0 + 3.0 - d.y, 0) + T.along * 2.0; cam.look_at(d + Vector3(0, T.y0 + 2.4 - d.y, 0) + T.along * 2.0, Vector3.UP); cam.fov = 55.0
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_board.png"))
	main.bosses[3].beaten = true; main.bosses[3].delivered = true; main._trophies()
	cam.global_position = d + outw * 8.0 + Vector3(0, T.y0 + 4.0 - d.y, 0); cam.look_at(d + Vector3(0, T.y0 + 3.6 - d.y, 0), Vector3.UP); cam.fov = 50.0
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	quit()
